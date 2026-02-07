extends CharacterBody3D

enum PlayerState { IDLE, WALKING, SITTING_DOWN, SEATED, STANDING_UP }

@export_group("Movement")
@export var speed: float = 1.55
@export var acceleration: float = 2.4
@export var deceleration: float = 4.5
@export var gravity: float = 9.8

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -15.0
@export var max_pitch: float = 60.0
@export var camera_inertia: float = 12.0
@export var shoulder_offset: float = 0.49

@export_group("Camera Feel")
@export var head_bob_frequency: float = 2.2  # Steps per second
@export var head_bob_vertical: float = 0.003  # Vertical sway amount
@export var head_bob_horizontal: float = 0.0015  # Horizontal sway amount
@export var idle_sway_speed: float = 0.8  # Breathing rhythm
@export var idle_sway_amount: float = 0.0003  # Breathing sway intensity
@export var cam_distance_idle: float = 0.8  # SpringArm length when still
@export var cam_distance_walk: float = 0.95  # SpringArm length when walking
@export var cam_distance_lerp: float = 3.0  # How fast distance transitions

@export_group("Footsteps")
@export var step_interval: float = 0.582  # Seconds between footsteps
@export var footstep_volume_db: float = -6.0
# Per-surface first-step offset (time pre-filled before first footstep)
var _step_offsets: Dictionary = { "concrete": 0.270 }
var _current_surface: String = "concrete"

@export_group("Model")
@export var model_turn_speed: float = 10.0

@onready var cam_origin: Node3D = $CamOrigin
@onready var spring_arm: SpringArm3D = $CamOrigin/SpringArm3D
@onready var visuals: Node3D = $Visuals
@onready var interact_ray: RayCast3D = $InteractRay

var _state: PlayerState = PlayerState.IDLE
var _seat_marker: Marker3D = null

var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.0
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""
var _bob_timer: float = 0.0
var _idle_timer: float = 0.0
var _current_cam_distance: float = 0.8
var _step_timer: float = 0.0
var _footstep_player: AudioStreamPlayer3D = null
var _footstep_sounds: Array[AudioStream] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_current_cam_distance = cam_distance_idle
	_setup_footsteps()
	_setup_animations()

func _setup_footsteps() -> void:
	_footstep_player = AudioStreamPlayer3D.new()
	_footstep_player.volume_db = footstep_volume_db
	_footstep_player.max_distance = 20.0
	add_child(_footstep_player)

	var stream: AudioStream = load("res://assets/audio/sfx/footsteps/footstep_concrete_03.ogg")
	if stream:
		_footstep_sounds.append(stream)

func _play_footstep() -> void:
	if _footstep_sounds.is_empty() or not _footstep_player:
		return
	_footstep_player.stream = _footstep_sounds[randi() % _footstep_sounds.size()]
	_footstep_player.pitch_scale = randf_range(0.9, 1.1)
	_footstep_player.play()

func _setup_animations() -> void:
	# Debug: print Sven's node tree so we can see the hierarchy
	print("=== Sven model tree ===")
	_print_tree(visuals, 0)

	# Find key nodes in Sven's model
	_anim_player = _find_node_of_type(visuals, "AnimationPlayer") as AnimationPlayer
	var skeleton: Skeleton3D = _find_node_of_type(visuals, "Skeleton3D") as Skeleton3D

	print("AnimationPlayer found: ", _anim_player != null)
	print("Skeleton3D found: ", skeleton != null)

	if _anim_player:
		print("AP root_node: ", _anim_player.root_node)
		print("AP existing anims: ", _anim_player.get_animation_list())

	if not _anim_player and skeleton:
		# Model has no AnimationPlayer - create one
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimPlayer"
		skeleton.get_parent().add_child(_anim_player)
		_anim_player.owner = get_tree().edited_scene_root
		print("Created AnimationPlayer as child of: ", skeleton.get_parent().name)

	if not _anim_player:
		push_warning("No AnimationPlayer or Skeleton3D found - cannot animate")
		return

	# Load animations
	_load_anim("res://assets/animations/sven/sven_idle_stand.fbx", "idle")
	_load_anim("res://assets/animations/sven/sven_walk.fbx", "walk")
	_load_anim("res://assets/animations/sven/sven_walk_backward.fbx", "walk_backward")
	_load_anim("res://assets/animations/sven/sven_strafe_left.fbx", "strafe_left")
	_load_anim("res://assets/animations/sven/sven_strafe_right.fbx", "strafe_right")
	_load_anim("res://assets/animations/sven/sven_sit_down.fbx", "sit_down", false, false)
	_load_anim("res://assets/animations/sven/sven_idle_sit.fbx", "idle_sit", true, false)
	_load_anim("res://assets/animations/sven/sven_stand_from_sit.fbx", "stand_from_sit", false, false)

	print("Final animation list: ", _anim_player.get_animation_list())

	# Debug: compare skeleton bone names vs animation track bone names
	if skeleton:
		print("=== Skeleton bones (first 10) ===")
		for i in range(min(10, skeleton.get_bone_count())):
			print("  bone[", i, "]: ", skeleton.get_bone_name(i))

	if _anim_player.has_animation("idle"):
		var anim: Animation = _anim_player.get_animation("idle")
		print("=== Idle anim track bone names (first 5) ===")
		for i in range(min(5, anim.get_track_count())):
			var path: String = str(anim.track_get_path(i))
			var colon_idx: int = path.find(":")
			if colon_idx >= 0:
				print("  track bone: ", path.substr(colon_idx + 1))

	# Play idle
	_anim_player.play("idle")
	_current_anim = "idle"
	_anim_player.animation_finished.connect(_on_animation_finished)
	print("Playing idle")

func _load_anim(fbx_path: String, anim_name: String, loop: bool = true, strip_root_motion: bool = true) -> void:
	var scene: PackedScene = load(fbx_path)
	if not scene:
		print("Failed to load: ", fbx_path)
		return

	var inst: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_node_of_type(inst, "AnimationPlayer") as AnimationPlayer

	if not source_ap:
		print(anim_name, " FBX has no AnimationPlayer")
		print("--- ", anim_name, " FBX tree ---")
		_print_tree(inst, 0)
		inst.queue_free()
		return

	var anim_list := source_ap.get_animation_list()
	print("--- ", anim_name, " FBX: ", anim_list, " ---")

	if anim_list.size() > 0:
		# Prefer "mixamo_com" over "Take 001" (which is typically the T-pose)
		var source_name: String = anim_list[0]
		for name in anim_list:
			if name == "mixamo_com":
				source_name = name
				break
		print(anim_name, " using source animation: '", source_name, "'")
		var anim: Animation = source_ap.get_animation(source_name)
		print(anim_name, " track count: ", anim.get_track_count())
		# Print first few track paths for debugging
		for i in range(min(3, anim.get_track_count())):
			print("  track[", i, "]: ", anim.track_get_path(i))

		# Auto-detect bone prefix and remap to match skeleton (mixamorig_)
		var source_prefix: String = ""
		for i in range(anim.get_track_count()):
			var path: String = str(anim.track_get_path(i))
			var colon_idx: int = path.find(":")
			if colon_idx >= 0:
				var bone_name: String = path.substr(colon_idx + 1)
				var hips_idx: int = bone_name.find("Hips")
				if hips_idx >= 0:
					source_prefix = bone_name.substr(0, hips_idx)
					break
		print(anim_name, " detected bone prefix: '", source_prefix, "'")

		if source_prefix != "mixamorig_" and source_prefix != "":
			for i in range(anim.get_track_count()):
				var track_path: String = str(anim.track_get_path(i))
				var new_path: String = track_path.replace(source_prefix, "mixamorig_")
				anim.track_set_path(i, NodePath(new_path))
			print("Remapped ", anim.get_track_count(), " tracks (", source_prefix, " -> mixamorig_)")

		# Strip root motion (Hips position track) so animation plays in place
		if strip_root_motion:
			for i in range(anim.get_track_count() - 1, -1, -1):
				var path: String = str(anim.track_get_path(i))
				if path.ends_with("mixamorig_Hips") and anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
					anim.remove_track(i)
					print("Removed Hips position track (root motion)")
					break

		if loop:
			anim.loop_mode = Animation.LOOP_LINEAR
		else:
			anim.loop_mode = Animation.LOOP_NONE

		# Add to AnimationPlayer's default library
		var lib: AnimationLibrary
		if _anim_player.has_animation_library(""):
			lib = _anim_player.get_animation_library("")
		else:
			lib = AnimationLibrary.new()
			_anim_player.add_animation_library("", lib)

		if not lib.has_animation(anim_name):
			lib.add_animation(anim_name, anim)
			print("Added '", anim_name, "' animation")

	inst.queue_free()

func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for child in node.get_children():
		var result := _find_node_of_type(child, type_name)
		if result:
			return result
	return null

func _print_tree(node: Node, depth: int) -> void:
	var indent := ""
	for i in range(depth):
		indent += "  "
	print(indent, node.name, " (", node.get_class(), ")")
	for child in node.get_children():
		_print_tree(child, depth + 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_target_yaw -= event.relative.x * mouse_sensitivity
		_target_pitch -= event.relative.y * mouse_sensitivity
		_target_pitch = clamp(_target_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event.is_action_pressed("interact"):
		_handle_interact()

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Camera inertia - lerp toward target angles
	_camera_yaw = lerp_angle(_camera_yaw, _target_yaw, camera_inertia * delta)
	_camera_pitch = lerp(_camera_pitch, _target_pitch, camera_inertia * delta)

	# Position camera origin with rotated shoulder offset
	var offset := Vector3(shoulder_offset, 0, 0).rotated(Vector3.UP, _camera_yaw)
	cam_origin.global_position = global_position + offset
	cam_origin.global_rotation = Vector3(0, _camera_yaw, 0)
	spring_arm.rotation.x = _camera_pitch

	# Aim interact ray in camera look direction at chest height
	interact_ray.position = Vector3(0, 0.8, 0)
	interact_ray.rotation = Vector3(_camera_pitch, _camera_yaw, 0)

	var can_move: bool = (_state == PlayerState.IDLE or _state == PlayerState.WALKING)

	# Movement relative to camera direction
	var input_dir: Vector2 = Vector2.ZERO
	var direction: Vector3 = Vector3.ZERO
	var has_lateral: bool = false
	var has_forward: bool = false
	var has_backward: bool = false

	if can_move:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var cam_basis := Basis(Vector3.UP, _camera_yaw)
		direction = (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		has_lateral = absf(input_dir.x) > 0.1
		has_forward = input_dir.y < -0.1
		has_backward = input_dir.y > 0.1

	if can_move and direction:
		velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)

		if has_lateral or has_backward:
			visuals.rotation.y = lerp_angle(visuals.rotation.y, _camera_yaw, model_turn_speed * delta)
		else:
			var target_angle: float = atan2(-direction.x, -direction.z)
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, model_turn_speed * delta)

		_state = PlayerState.WALKING
	elif can_move:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
		if _state == PlayerState.WALKING:
			_state = PlayerState.IDLE

	# Idle breathing sway
	if can_move and not direction:
		_idle_timer += delta * idle_sway_speed
		var sway_y: float = sin(_idle_timer * TAU) * idle_sway_amount
		var sway_x: float = sin(_idle_timer * TAU * 0.5) * idle_sway_amount * 0.5
		spring_arm.rotation.x += sway_x
		cam_origin.rotation.y += sway_y
	elif can_move:
		_idle_timer = 0.0

	# Animation selection based on movement direction
	if _anim_player and can_move:
		var target_anim: String = "idle"
		if direction:
			if has_forward:
				target_anim = "walk"
			elif has_backward:
				target_anim = "walk_backward"
			else:
				target_anim = "strafe_left" if input_dir.x < 0.0 else "strafe_right"

		if target_anim != _current_anim and _anim_player.has_animation(target_anim):
			_anim_player.play(target_anim, 0.3)
			_current_anim = target_anim

	# Footstep sounds
	if can_move and direction and is_on_floor():
		_step_timer += delta
		if _step_timer >= step_interval:
			_step_timer -= step_interval
			_play_footstep()
	elif can_move:
		var step_offset: float = _step_offsets.get(_current_surface, 0.0)
		_step_timer = step_interval - step_offset

	move_and_slide()

func _handle_interact() -> void:
	if _state == PlayerState.SITTING_DOWN or _state == PlayerState.STANDING_UP:
		return

	if _state == PlayerState.SEATED:
		_begin_stand()
		return

	# Check raycast for sittable objects
	if interact_ray.is_colliding():
		var collider: Node = interact_ray.get_collider()
		if collider and collider.is_in_group("sittable"):
			var seat: Marker3D = collider.get_node_or_null("SeatPosition") as Marker3D
			if seat:
				_begin_sit(seat)

func _begin_sit(seat: Marker3D) -> void:
	_state = PlayerState.SITTING_DOWN
	_seat_marker = seat
	velocity = Vector3.ZERO

	# Snap player to seat position and rotate model to face chair's forward direction
	global_position = seat.global_position
	# Get the chair's parent (the Chair node) to determine facing direction
	var chair: Node3D = seat.get_parent() as Node3D
	if chair:
		# Chair's +Z axis is its forward direction (where backrest faces)
		var chair_forward: Vector3 = -chair.global_basis.z
		visuals.rotation.y = atan2(chair_forward.x, chair_forward.z)
	else:
		visuals.rotation.y = seat.global_rotation.y

	if _anim_player and _anim_player.has_animation("sit_down"):
		_anim_player.play("sit_down", 0.15)
		_current_anim = "sit_down"

func _begin_stand() -> void:
	_state = PlayerState.STANDING_UP

	if _anim_player and _anim_player.has_animation("stand_from_sit"):
		_anim_player.play("stand_from_sit", 0.15)
		_current_anim = "stand_from_sit"

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "sit_down":
		_state = PlayerState.SEATED
		if _anim_player and _anim_player.has_animation("idle_sit"):
			_anim_player.play("idle_sit", 0.15)
			_current_anim = "idle_sit"

	elif anim_name == "stand_from_sit":
		_state = PlayerState.IDLE
		# Nudge player slightly forward from seat so they don't clip back into it
		if _seat_marker:
			var forward_dir: Vector3 = -_seat_marker.global_basis.z
			global_position = _seat_marker.global_position + forward_dir * 0.5
		_seat_marker = null
		if _anim_player and _anim_player.has_animation("idle"):
			_anim_player.play("idle", 0.15)
			_current_anim = "idle"
