extends CharacterBody3D

signal sat_down
signal stood_up

@export var speed: float = 1.3
@export var acceleration: float = 2.7
@export var deceleration: float = 4.0
@export var gravity: float = 9.8
@export var turn_lerp: float = 5.0  # How fast character rotates toward input direction while walking
@export var turn_speed: float = 180.0  # Degrees per second for idle turn-in-place
@export var turn_threshold: float = 60.0  # Angle (degrees) to trigger turn-in-place from idle
@export var mouse_sensitivity: float = 0.003
@export var camera_min_pitch: float = -35.0
@export var camera_max_pitch: float = -5.0
@export var camera_rotation_speed: float = 6.0
@export var zoom_speed: float = 0.25
@export var zoom_min: float = 1.3
@export var zoom_max: float = 3.7
@export var zoom_inertia: float = 4.0
@export_group("Footsteps")
@export var footstep_interval: float = 0.6  ## Seconds between footsteps at full walk speed

@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var animation_player: AnimationPlayer = $Visuals/AnimationPlayer
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var skeleton: Skeleton3D
var current_speed: float = 0.0
var footstep_timer: float = 0.0
var last_footstep_index: int = -1
var animation_tree: AnimationTree
var is_turning: bool = false
var turn_target_angle: float = 0.0
var turn_hold_frames: int = 0
var turn_moving: bool = false
const TURN_MOVE_DELAY: int = 5  # Physics frames before movement starts during held turn
var target_camera_yaw: float = 0.0
var target_camera_pitch: float = deg_to_rad(-20.0)
var target_zoom: float = 2.5

# Saved camera baseline for normalization after standing (yaw not stored)
var saved_camera_pitch: float = 0.0
var saved_spring_length: float = 0.0
var saved_spring_arm_pos: Vector3 = Vector3.ZERO

enum PlayerState { MOVING, WALKING_TO_SEAT, APPROACHING_CHAIR, TURNING_TO_SIT, SITTING_DOWN, SEATED, STANDING_UP, WALKING_TO_DOOR, TURNING_TO_DOOR, OPENING_DOOR, AT_DOOR }
var state: PlayerState = PlayerState.MOVING
var target_sittable: Sittable = null
var target_doorable: Doorable = null
var locked_position: Vector3 = Vector3.ZERO
var can_interact_with_seat: bool = false
var camera_cutscene_active: bool = false

# Debug: track hand positions during door opening
@export var debug_track_right_hand: bool = false
var right_hand_bone_idx: int = -1
var left_hand_bone_idx: int = -1
var is_tracking_door_opening: bool = false
var door_opening_elapsed: float = 0.0
var last_print_time: float = 0.0

# Debug: scene time scale
@export var debug_time_scale: float = 1.0

@export_group("Door Walk Through")
@export var end_stand_distance: float = 1.0       ## Meters from DoorCenter along -standing_direction
@export var walk_through_start: float = 5.50      ## Seconds after animation start to begin moving player
@export var walk_through_duration: float = 0.20   ## Duration of the slide, independent of start time
@export_group("")


const ANIM_PATHS: Dictionary = {
	"idle": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Stand_Relaxed_Idle_v2_IPC.fbx",
	"walk": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Walk_F_Loop_IPC.fbx",
	"turn_left": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Stand_Rlx_Turn_In_Place_L_Loop_IPC.fbx",
	"turn_right": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Stand_Rlx_Turn_In_Place_R_Loop_IPC.fbx",
	"sit_down": "res://assets/animations/sven/Stand To Sit.fbx",
	"sitting_idle": "res://assets/animations/sven/Sitting Idle.fbx",
	"sit_to_stand": "res://assets/animations/sven/Sit To Stand.fbx",
	"open_door_inwards": "res://Opening Door Inwards.fbx",
}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_zoom = spring_arm.spring_length
	target_camera_pitch = camera_pivot.rotation.x

	# Find skeleton in MotusMan
	skeleton = _find_skeleton($Visuals/MotusMan)
	if not skeleton:
		push_error("Skeleton not found!")
		return

	# Disable internal AnimationPlayer from FBX import
	var internal_ap: AnimationPlayer = $Visuals/MotusMan.find_child("AnimationPlayer", true, false)
	if internal_ap:
		internal_ap.stop()
		internal_ap.active = false
		for lib_name in internal_ap.get_animation_library_list():
			internal_ap.remove_animation_library(lib_name)

	# Load animations into our AnimationPlayer
	animation_player.root_node = animation_player.get_parent().get_path()
	for anim_name in ANIM_PATHS:
		_load_animation(anim_name, ANIM_PATHS[anim_name])

	# Set up AnimationTree with StateMachine
	_setup_animation_tree()
	print("Animation setup complete. Animations: ", animation_player.get_animation_list())

	# Find hand bones for debug tracking
	if skeleton:
		right_hand_bone_idx = skeleton.find_bone("RightHand")
		if right_hand_bone_idx < 0:
			right_hand_bone_idx = skeleton.find_bone("mixamorig_RightHand")
		if right_hand_bone_idx < 0:
			push_warning("Right hand bone not found.")
		else:
			print("Found right hand bone at index: ", right_hand_bone_idx)

		left_hand_bone_idx = skeleton.find_bone("LeftHand")
		if left_hand_bone_idx < 0:
			left_hand_bone_idx = skeleton.find_bone("mixamorig_LeftHand")
		if left_hand_bone_idx < 0:
			push_warning("Left hand bone not found.")
		else:
			print("Found left hand bone at index: ", left_hand_bone_idx)

func _setup_animation_tree() -> void:
	animation_tree = AnimationTree.new()
	animation_tree.name = "AnimationTree"

	# Add as child of Visuals so root_node resolves paths the same as AnimationPlayer
	visuals.add_child(animation_tree)
	animation_tree.root_node = NodePath("..")

	# Share animation library from AnimationPlayer
	var lib: AnimationLibrary = animation_player.get_animation_library("")
	animation_tree.add_animation_library("", lib)

	# State machine as root
	var state_machine: AnimationNodeStateMachine = AnimationNodeStateMachine.new()

	# Locomotion state: BlendSpace1D (idle ↔ walk)
	var blend_space: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()
	var idle_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	idle_node.animation = &"idle"
	var walk_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	walk_node.animation = &"walk"
	blend_space.add_blend_point(idle_node, 0.0)
	blend_space.add_blend_point(walk_node, 1.0)
	blend_space.min_space = 0.0
	blend_space.max_space = 1.0
	state_machine.add_node("locomotion", blend_space)

	# Turn states
	var turn_left_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	turn_left_node.animation = &"turn_left"
	state_machine.add_node("turn_left", turn_left_node)

	var turn_right_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	turn_right_node.animation = &"turn_right"
	state_machine.add_node("turn_right", turn_right_node)

	# Sitting states
	var sit_down_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	sit_down_node.animation = &"sit_down"
	state_machine.add_node("sit_down", sit_down_node)

	var sitting_idle_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	sitting_idle_node.animation = &"sitting_idle"
	state_machine.add_node("sitting_idle", sitting_idle_node)

	var sit_to_stand_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	sit_to_stand_node.animation = &"sit_to_stand"
	state_machine.add_node("sit_to_stand", sit_to_stand_node)

	# Door states
	var open_door_inwards_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	open_door_inwards_node.animation = &"open_door_inwards"
	state_machine.add_node("open_door_inwards", open_door_inwards_node)

	# Transitions (all immediate with short crossfade)
	var xfade: float = 0.2
	var all_states: Array = ["locomotion", "turn_left", "turn_right", "sit_down", "sitting_idle", "sit_to_stand", "open_door_inwards"]
	for from_state in all_states:
		for to_state in all_states:
			if from_state == to_state:
				continue
			var transition: AnimationNodeStateMachineTransition = AnimationNodeStateMachineTransition.new()
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			transition.xfade_time = xfade
			state_machine.add_transition(from_state, to_state, transition)

	state_machine.set_graph_offset(Vector2.ZERO)
	animation_tree.tree_root = state_machine
	animation_tree.active = true

	# AnimationTree handles playback now
	animation_player.stop()
	animation_player.active = false

	# Force locomotion state so we don't start in T-pose
	animation_tree.set("parameters/locomotion/blend_position", 0.0)
	call_deferred("_start_locomotion")

func _start_locomotion() -> void:
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	playback.travel("locomotion")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var result: Skeleton3D = _find_skeleton(child)
		if result:
			return result
	return null

func _load_animation(anim_name: String, fbx_path: String) -> void:
	if not FileAccess.file_exists(fbx_path):
		push_error("Animation file not found: ", fbx_path)
		return

	var scene: PackedScene = load(fbx_path)
	if not scene:
		push_error("Failed to load FBX: ", fbx_path)
		return

	var instance: Node = scene.instantiate()

	# Find AnimationPlayer in FBX
	var anim_player: AnimationPlayer = instance.find_child("AnimationPlayer", true, false)
	if not anim_player:
		push_error("No AnimationPlayer in FBX: ", fbx_path)
		instance.queue_free()
		return

	# Get default animation library
	var library: AnimationLibrary = anim_player.get_animation_library("")
	if not library:
		instance.queue_free()
		return

	var anim_list: PackedStringArray = library.get_animation_list()
	if anim_list.is_empty():
		instance.queue_free()
		return

	# Take the first animation, duplicate and retarget bone paths
	var anim: Animation = library.get_animation(anim_list[0]).duplicate()
	var root_node: Node = animation_player.get_parent()
	var skeleton_path: String = root_node.get_path_to(skeleton)

	var matched: int = 0
	var unmatched: int = 0
	for track_idx in anim.get_track_count():
		var track_path_str: String = str(anim.track_get_path(track_idx))
		if "Skeleton3D:" not in track_path_str:
			continue

		var bone_name: String = track_path_str.split("Skeleton3D:")[1]
		# Strip Mixamo prefix for compatibility (Godot converts : to _)
		if bone_name.begins_with("mixamorig_"):
			bone_name = bone_name.substr(10)

		var target_bone_idx: int = skeleton.find_bone(bone_name)
		if target_bone_idx < 0:
			unmatched += 1
			continue

		anim.track_set_path(track_idx, NodePath(skeleton_path + ":" + bone_name))
		matched += 1

	print("[%s] Retarget: %d matched, %d unmatched" % [anim_name, matched, unmatched])

	# Add to our AnimationPlayer
	if not animation_player.has_animation_library(""):
		animation_player.add_animation_library("", AnimationLibrary.new())

	animation_player.get_animation_library("").add_animation(anim_name, anim)
	if anim_name in ["sit_down", "sit_to_stand", "open_door_inwards"]:
		anim.loop_mode = Animation.LOOP_NONE
	else:
		anim.loop_mode = Animation.LOOP_LINEAR

	instance.queue_free()

func _play_footstep() -> void:
	# Array of wood footstep audio IDs
	var footstep_ids: Array[AudioManager.AudioID] = [
		AudioManager.AudioID.FOOTSTEP_WOOD_1,
		AudioManager.AudioID.FOOTSTEP_WOOD_2,
		AudioManager.AudioID.FOOTSTEP_WOOD_3,
		AudioManager.AudioID.FOOTSTEP_WOOD_4,
		AudioManager.AudioID.FOOTSTEP_WOOD_5,
		AudioManager.AudioID.FOOTSTEP_WOOD_6,
		AudioManager.AudioID.FOOTSTEP_WOOD_7,
	]

	# Pick a random footstep, avoiding repeating the same one
	var index: int = randi_range(0, footstep_ids.size() - 1)
	while index == last_footstep_index and footstep_ids.size() > 1:
		index = randi_range(0, footstep_ids.size() - 1)

	last_footstep_index = index

	# Play 3D footstep at player position
	var player: AudioStreamPlayer3D = AudioManager.play_3d_sfx(footstep_ids[index], global_position)
	if player:
		# Slight pitch variation for natural feel
		player.pitch_scale = randf_range(0.9, 1.1)

func _input(event: InputEvent) -> void:
	if camera_cutscene_active:
		return

	if event is InputEventMouseMotion:
		target_camera_yaw -= event.relative.x * mouse_sensitivity
		target_camera_pitch -= event.relative.y * mouse_sensitivity
		target_camera_pitch = clampf(
			target_camera_pitch,
			deg_to_rad(camera_min_pitch),
			deg_to_rad(camera_max_pitch)
		)

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom - zoom_speed, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom + zoom_speed, zoom_min, zoom_max)

	if event.is_action_pressed("interact"):
		_handle_interact()

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	# Debug: apply time scale
	Engine.time_scale = debug_time_scale

	# Debug: track hand positions during door opening
	if debug_track_right_hand and is_tracking_door_opening and skeleton:
		door_opening_elapsed += delta
		# Print every 0.1 seconds
		if door_opening_elapsed - last_print_time >= 0.1:
			# Right hand: 1.21s - 1.56s
			if door_opening_elapsed >= 1.21 and door_opening_elapsed <= 1.56 and right_hand_bone_idx >= 0:
				var right_pos: Vector3 = skeleton.get_bone_global_pose(right_hand_bone_idx).origin
				print("Time: %.2fs, RightHand X: %.4f, Z: %.4f" % [door_opening_elapsed, right_pos.x, right_pos.z])
			# Left hand: 1.80s - end of animation
			elif door_opening_elapsed >= 1.80 and left_hand_bone_idx >= 0:
				var left_pos: Vector3 = skeleton.get_bone_global_pose(left_hand_bone_idx).origin
				print("Time: %.2fs, LeftHand X: %.4f, Z: %.4f" % [door_opening_elapsed, left_pos.x, left_pos.z])
			last_print_time = door_opening_elapsed

	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, target_camera_yaw, camera_rotation_speed * delta)
	camera_pivot.rotation.x = lerpf(camera_pivot.rotation.x, target_camera_pitch, camera_rotation_speed * delta)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_zoom, zoom_inertia * delta)

func _handle_interact() -> void:
	if state == PlayerState.MOVING:
		# Check for light switches first (simple toggle interaction)
		var nearest_light_switch: LightSwitch = _find_nearest_light_switch()
		if nearest_light_switch and nearest_light_switch.can_interact:
			nearest_light_switch.toggle()
			return

		# Check for phones (allow interaction when playing to stop voicemail)
		var nearest_phone: PhoneInteractable = _find_nearest_phone()
		if nearest_phone and (nearest_phone.can_interact or nearest_phone.is_playing):
			nearest_phone.activate()
			return

		# Check for doors
		var nearest_doorable: Doorable = _find_nearest_doorable()
		if nearest_doorable:
			_start_door_sequence(nearest_doorable)
			return

		# Then check for sittables (complex sequence interaction)
		var nearest_sittable: Sittable = _find_nearest_sittable()
		if nearest_sittable:
			_start_sitting_sequence(nearest_sittable)
		return

	# Cancel during walk or approach phases
	if state in [PlayerState.WALKING_TO_SEAT, PlayerState.APPROACHING_CHAIR]:
		_cancel_sitting_sequence()
		return

	# Cancel walk-to-door
	if state == PlayerState.WALKING_TO_DOOR:
		_cancel_door_sequence()
		return

	# Leave door position
	if state == PlayerState.AT_DOOR:
		_leave_door()
		return

	# Stand up from seated (only after cooldown)
	if state == PlayerState.SEATED and can_interact_with_seat:
		_start_standing_sequence()
		return

func _find_nearest_light_switch() -> LightSwitch:
	var search_radius: float = 2.0  # Same as indicator CLOSE_DISTANCE
	var camera: Camera3D = get_viewport().get_camera_3d()
	var nearest: LightSwitch = null
	var nearest_dist: float = search_radius

	for node in get_tree().get_nodes_in_group("light_switch"):
		var light_switch: LightSwitch = node.find_child("LightSwitchInteractable", false, false)
		if not light_switch:
			continue
		if camera and not camera.is_position_in_frustum(node.global_position):
			continue
		var dist: float = global_position.distance_to(node.global_position)
		if dist < nearest_dist:
			nearest = light_switch
			nearest_dist = dist

	return nearest

func _find_nearest_phone() -> PhoneInteractable:
	var search_radius: float = 2.0  # Same as indicator CLOSE_DISTANCE
	var camera: Camera3D = get_viewport().get_camera_3d()
	var nearest: PhoneInteractable = null
	var nearest_dist: float = search_radius

	for node in get_tree().get_nodes_in_group("phone"):
		var phone: PhoneInteractable = node.find_child("PhoneInteractable", false, false)
		if not phone:
			continue
		if camera and not camera.is_position_in_frustum(node.global_position):
			continue
		var dist: float = global_position.distance_to(node.global_position)
		if dist < nearest_dist:
			nearest = phone
			nearest_dist = dist

	return nearest

func _find_nearest_sittable() -> Sittable:
	var search_radius: float = 3.0
	var nearest: Sittable = null
	var nearest_dist: float = search_radius

	for node in get_tree().get_nodes_in_group("sittable"):
		# Find the Sittable component
		var sittable: Sittable = node.find_child("Sittable", false, false)
		if not sittable:
			continue

		var dist: float = global_position.distance_to(node.global_position)
		if dist < nearest_dist:
			nearest = sittable
			nearest_dist = dist

	return nearest

func _start_sitting_sequence(sittable: Sittable) -> void:
	state = PlayerState.WALKING_TO_SEAT
	target_sittable = sittable
	current_speed = 0.0

	# Fade out the indicator on the sittable object
	var indicator: Node = sittable.get_parent().find_child("InteractableIndicator", false, false)
	if indicator and indicator.has_method("fade_out"):
		indicator.fade_out()

	print("Starting sitting sequence. Target area: ", sittable.get_sitting_area_position())

func _get_sittable_indicator() -> Node:
	if not target_sittable or not target_sittable.get_parent():
		return null
	return target_sittable.get_parent().find_child("InteractableIndicator", false, false)

func _cancel_sitting_sequence() -> void:
	print("Sitting sequence cancelled.")
	state = PlayerState.MOVING
	current_speed = 0.0
	velocity = Vector3.ZERO
	animation_tree.set("parameters/locomotion/blend_position", 0.0)
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	playback.travel("locomotion")

	var indicator: Node = _get_sittable_indicator()
	if indicator and indicator.has_method("fade_in"):
		indicator.fade_in()

	target_sittable = null

func _start_standing_sequence() -> void:
	can_interact_with_seat = false
	state = PlayerState.STANDING_UP

	var indicator: Node = _get_sittable_indicator()
	if indicator and indicator.has_method("fade_out"):
		indicator.fade_out()

	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	playback.travel("sit_to_stand")

	var stand_anim: Animation = animation_player.get_animation_library("").get_animation("sit_to_stand")
	var wait_time: float = stand_anim.length if stand_anim else 2.0
	await get_tree().create_timer(wait_time).timeout

	if state != PlayerState.STANDING_UP:
		return

	# Transition to standing idle
	playback.travel("locomotion")
	animation_tree.set("parameters/locomotion/blend_position", 0.0)
	state = PlayerState.MOVING

	# Apply standing offsets after idle begins
	_apply_standing_offset()
	_apply_standing_spring_arm_offset()

	# Smoothly normalize camera and spring arm back to the saved baseline
	await _normalize_camera_to_saved(0.6)

	# Notify listeners that standing/normalization finished
	emit_signal("stood_up")

	# 1 second cooldown before interaction is possible again
	await get_tree().create_timer(1.0).timeout
	target_sittable = null
	if indicator and indicator.has_method("fade_in"):
		indicator.fade_in()


func _apply_standing_offset() -> void:
	if not target_sittable or target_sittable.standing_offset == 0.0:
		return

	if target_sittable.standing_offset_delay > 0.0:
		await get_tree().create_timer(target_sittable.standing_offset_delay).timeout

	if state != PlayerState.MOVING or not target_sittable:
		return

	var offset_vec: Vector3 = target_sittable.chair_face_direction * target_sittable.standing_offset
	var start_pos: Vector3 = global_position
	var end_pos: Vector3 = global_position + offset_vec
	var duration: float = target_sittable.standing_offset_duration
	var elapsed: float = 0.0

	while elapsed < duration and state == PlayerState.MOVING and target_sittable:
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		global_position = start_pos.lerp(end_pos, t)
		await get_tree().process_frame

func _apply_standing_spring_arm_offset() -> void:
	if not target_sittable or target_sittable.standing_spring_arm_offset == 0.0:
		return

	if target_sittable.standing_spring_arm_offset_delay > 0.0:
		await get_tree().create_timer(target_sittable.standing_spring_arm_offset_delay).timeout

	if state != PlayerState.MOVING or not target_sittable:
		return

	var world_offset: Vector3 = target_sittable.chair_face_direction * target_sittable.standing_spring_arm_offset
	var offset_vec: Vector3 = camera_pivot.global_transform.basis.inverse() * world_offset
	var start_pos: Vector3 = spring_arm.position
	var end_pos: Vector3 = spring_arm.position + offset_vec
	var duration: float = target_sittable.standing_spring_arm_offset_duration
	var elapsed: float = 0.0

	while elapsed < duration and state == PlayerState.MOVING and target_sittable:
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		spring_arm.position = start_pos.lerp(end_pos, t)
		await get_tree().process_frame

func _normalize_camera_to_saved(duration: float = 0.6) -> void:
	var elapsed: float = 0.0
	var start_pitch: float = target_camera_pitch
	var start_zoom: float = target_zoom
	var start_spring_pos: Vector3 = spring_arm.position

	# If no meaningful baseline saved, bail early
	if duration <= 0.0:
		return

	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		target_camera_pitch = lerp(start_pitch, saved_camera_pitch, t)
		target_zoom = lerp(start_zoom, saved_spring_length, t)
		spring_arm.position = start_spring_pos.lerp(saved_spring_arm_pos, t)
		await get_tree().process_frame

func _handle_walk_to_seat(delta: float) -> void:
	if not target_sittable:
		state = PlayerState.MOVING
		return

	var target_pos: Vector3 = target_sittable.get_sitting_area_position()
	var direction: Vector3 = (target_pos - global_position).normalized()
	direction.y = 0.0

	# Check if reached sitting area
	if target_sittable.is_in_sitting_area(global_position):
		print("Reached sitting area. Approaching chair.")
		state = PlayerState.APPROACHING_CHAIR
		return

	# Walk toward sitting area
	current_speed = speed
	var target_rotation: float = atan2(-direction.x, -direction.z)
	visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation, turn_lerp * delta)

	var angle: float = visuals.rotation.y
	var facing: Vector3 = Vector3(-sin(angle), 0.0, -cos(angle))
	velocity.x = facing.x * current_speed
	velocity.z = facing.z * current_speed

	# Update animation blend
	animation_tree.set("parameters/locomotion/blend_position", 1.0)

	move_and_slide()

func _handle_approach_chair(delta: float) -> void:
	if not target_sittable:
		state = PlayerState.MOVING
		return

	# Walk forward toward the chair
	var chair_pos: Vector3 = target_sittable.get_parent().global_position if target_sittable.get_parent() else target_sittable.global_position
	var direction: Vector3 = (chair_pos - global_position).normalized()
	direction.y = 0.0

	current_speed = speed
	var target_rotation: float = atan2(-direction.x, -direction.z)
	visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation, turn_lerp * delta)

	var angle: float = visuals.rotation.y
	var facing: Vector3 = Vector3(-sin(angle), 0.0, -cos(angle))
	velocity.x = facing.x * current_speed
	velocity.z = facing.z * current_speed

	# Update animation blend
	animation_tree.set("parameters/locomotion/blend_position", 1.0)

	move_and_slide()

	# Check for collision with chair
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var collision: KinematicCollision3D = get_slide_collision(i)
			if collision.get_collider() == target_sittable.get_parent():
				print("Collided with chair. Starting turn.")
				locked_position = global_position
				state = PlayerState.TURNING_TO_SIT
				current_speed = 0.0
				return

func _handle_turn_to_sit(delta: float) -> void:
	if not target_sittable:
		state = PlayerState.MOVING
		return

	var target_angle: float = target_sittable.get_chair_face_angle()
	var angle_diff: float = angle_difference(visuals.rotation.y, target_angle)

	# Check if facing the chair
	if abs(angle_diff) < deg_to_rad(5.0):
		print("Facing chair. Playing sit animation.")
		visuals.rotation.y = target_angle
		state = PlayerState.SITTING_DOWN
		_play_sit_down_animation()
		return

	# Perform turn-in-place
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	if angle_diff > 0:
		playback.travel("turn_left")
	else:
		playback.travel("turn_right")

	var effective_speed: float = turn_speed * max(1.0, abs(angle_diff) / deg_to_rad(90.0))
	var step: float = sign(angle_diff) * min(abs(angle_diff), deg_to_rad(effective_speed) * delta)
	visuals.rotation.y += step

	global_position = locked_position
	velocity = Vector3.ZERO

func _play_sit_down_animation() -> void:
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

	# Save camera baseline (no yaw) so we can return to it after standing
	saved_camera_pitch = target_camera_pitch
	saved_spring_length = target_zoom
	saved_spring_arm_pos = spring_arm.position

	playback.travel("sit_down")

	# Wait for sit_down animation to finish, then transition to sitting_idle
	var sit_anim: Animation = animation_player.get_animation_library("").get_animation("sit_down")
	if sit_anim:
		await get_tree().create_timer(sit_anim.length).timeout
	else:
		await get_tree().create_timer(2.0).timeout

	if state == PlayerState.SITTING_DOWN:
		print("Sit animation complete. Now seated.")
		playback.travel("sitting_idle")
		state = PlayerState.SEATED
		can_interact_with_seat = false
		saved_spring_arm_pos = spring_arm.position
		_apply_sitting_offset()
		_apply_spring_arm_offset()
		_enable_seated_interaction()
		# Notify listeners that we've finished sitting
		emit_signal("sat_down")


func _apply_sitting_offset() -> void:
	if not target_sittable or target_sittable.sitting_offset == 0.0:
		return

	if target_sittable.sitting_offset_delay > 0.0:
		await get_tree().create_timer(target_sittable.sitting_offset_delay).timeout

	if state != PlayerState.SEATED:
		return

	var start_pos: Vector3 = locked_position
	var end_pos: Vector3 = locked_position + target_sittable.chair_face_direction * target_sittable.sitting_offset
	var duration: float = target_sittable.sitting_offset_duration
	var elapsed: float = 0.0

	while elapsed < duration and state == PlayerState.SEATED:
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		locked_position = start_pos.lerp(end_pos, t)
		await get_tree().process_frame

	if state == PlayerState.SEATED:
		locked_position = end_pos

func _apply_spring_arm_offset() -> void:
	if not target_sittable or target_sittable.spring_arm_offset == 0.0:
		return

	if target_sittable.spring_arm_offset_delay > 0.0:
		await get_tree().create_timer(target_sittable.spring_arm_offset_delay).timeout

	if state != PlayerState.SEATED:
		return

	var world_offset: Vector3 = target_sittable.chair_face_direction * target_sittable.spring_arm_offset
	var offset_vec: Vector3 = camera_pivot.global_transform.basis.inverse() * world_offset
	var start_pos: Vector3 = spring_arm.position
	var end_pos: Vector3 = spring_arm.position + offset_vec
	var duration: float = target_sittable.spring_arm_offset_duration
	var elapsed: float = 0.0

	while elapsed < duration and state == PlayerState.SEATED:
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		spring_arm.position = start_pos.lerp(end_pos, t)
		await get_tree().process_frame

	if state == PlayerState.SEATED:
		spring_arm.position = end_pos

func _enable_seated_interaction() -> void:
	await get_tree().create_timer(1.0).timeout
	if state != PlayerState.SEATED:
		return
	can_interact_with_seat = true
	var indicator: Node = _get_sittable_indicator()
	if indicator and indicator.has_method("fade_in"):
		indicator.fade_in()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle automatic sitting sequence
	if state == PlayerState.WALKING_TO_SEAT:
		_handle_walk_to_seat(delta)
		return
	elif state == PlayerState.APPROACHING_CHAIR:
		_handle_approach_chair(delta)
		return
	elif state == PlayerState.TURNING_TO_SIT:
		_handle_turn_to_sit(delta)
		return
	elif state in [PlayerState.SITTING_DOWN, PlayerState.SEATED, PlayerState.STANDING_UP]:
		global_position = locked_position
		velocity = Vector3.ZERO
		return

	# Handle door sequence
	if state == PlayerState.WALKING_TO_DOOR:
		_handle_walk_to_door(delta)
		return
	elif state == PlayerState.TURNING_TO_DOOR:
		_handle_turn_to_door(delta)
		return
	elif state in [PlayerState.OPENING_DOOR, PlayerState.AT_DOOR]:
		global_position = locked_position
		velocity = Vector3.ZERO
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var has_input: bool = input_dir.length() > 0.0

	# Camera-relative direction
	var camera_forward: Vector3 = -camera_pivot.global_transform.basis.z
	var camera_right: Vector3 = camera_pivot.global_transform.basis.x
	camera_forward.y = 0
	camera_right.y = 0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	var direction: Vector3 = (camera_forward * -input_dir.y + camera_right * input_dir.x).normalized()

	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")

	# Turn-in-place from idle
	if is_turning:
		if has_input:
			turn_target_angle = atan2(-direction.x, -direction.z)
			turn_hold_frames += 1
			if turn_hold_frames > TURN_MOVE_DELAY:
				turn_moving = true

		var angle_diff: float = angle_difference(visuals.rotation.y, turn_target_angle)
		var done_angle: float = deg_to_rad(30.0) if turn_moving else deg_to_rad(5.0)
		var should_end: bool = (turn_moving and not has_input) or abs(angle_diff) < done_angle

		if should_end:
			if abs(angle_diff) < deg_to_rad(5.0):
				visuals.rotation.y = turn_target_angle
			is_turning = false
			turn_moving = false
			turn_hold_frames = 0
			playback.travel("locomotion")
		else:
			var effective_speed: float = turn_speed * max(1.0, abs(angle_diff) / deg_to_rad(90.0))
			var step: float = sign(angle_diff) * min(abs(angle_diff), deg_to_rad(effective_speed) * delta)
			visuals.rotation.y += step
	elif has_input and current_speed < 0.1:
		# Starting from idle — check if we need a turn-in-place
		var target_rotation: float = atan2(-direction.x, -direction.z)
		var angle_diff: float = angle_difference(visuals.rotation.y, target_rotation)
		if abs(angle_diff) > deg_to_rad(turn_threshold):
			is_turning = true
			turn_moving = false
			turn_hold_frames = 0
			turn_target_angle = target_rotation
			if angle_diff > 0:
				playback.travel("turn_left")
			else:
				playback.travel("turn_right")

	# Accelerate or decelerate
	if is_turning and not turn_moving:
		current_speed = 0.0
	elif has_input:
		var accel: float = acceleration * 0.3 if is_turning else acceleration
		current_speed = min(speed, current_speed + accel * delta)
	else:
		current_speed = max(0.0, current_speed - deceleration * delta)

	# Drive animation blend: 0.0 = idle, 1.0 = walk
	animation_tree.set("parameters/locomotion/blend_position", current_speed / speed)

	# Rotate toward input direction (arc turning while walking)
	if has_input and not is_turning:
		var target_rotation: float = atan2(-direction.x, -direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation, turn_lerp * delta)

	# Move in facing direction (creates natural arcs when turning)
	if current_speed > 0.0:
		var angle: float = visuals.rotation.y
		var facing: Vector3 = Vector3(-sin(angle), 0.0, -cos(angle))
		velocity.x = facing.x * current_speed
		velocity.z = facing.z * current_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# Footstep audio: play at intervals proportional to walking speed
	if current_speed > 0.1 and is_on_floor():
		footstep_timer += delta
		var interval: float = footstep_interval / (current_speed / speed)
		if footstep_timer >= interval:
			footstep_timer = 0.0
			_play_footstep()
	else:
		footstep_timer = 0.0

	move_and_slide()


# ---------------------------------------------------------------------------
# Door sequence
# ---------------------------------------------------------------------------

func _find_nearest_doorable() -> Doorable:
	var search_radius: float = 3.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	var nearest: Doorable = null
	var nearest_dist: float = search_radius

	for node in get_tree().get_nodes_in_group("doorable"):
		var doorable: Doorable = node.find_child("Doorable", false, false)
		if not doorable:
			continue
		if camera and not camera.is_position_in_frustum(node.global_position):
			continue
		var dist: float = global_position.distance_to(node.global_position)
		if dist < nearest_dist:
			nearest = doorable
			nearest_dist = dist

	return nearest


func _start_door_sequence(doorable: Doorable) -> void:
	state = PlayerState.WALKING_TO_DOOR
	target_doorable = doorable
	current_speed = 0.0

	var indicator: Node = _get_doorable_indicator()
	if indicator and indicator.has_method("fade_out"):
		indicator.fade_out()


func _cancel_door_sequence() -> void:
	state = PlayerState.MOVING
	current_speed = 0.0
	velocity = Vector3.ZERO
	animation_tree.set("parameters/locomotion/blend_position", 0.0)
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	playback.travel("locomotion")

	var indicator: Node = _get_doorable_indicator()
	if indicator and indicator.has_method("fade_in"):
		indicator.fade_in()

	target_doorable = null


func _get_doorable_indicator() -> Node:
	if not target_doorable or not target_doorable.get_parent():
		return null
	return target_doorable.get_parent().find_child("InteractableIndicator", false, false)


func _handle_walk_to_door(delta: float) -> void:
	if not target_doorable:
		state = PlayerState.MOVING
		return

	var target_pos: Vector3 = target_doorable.get_standing_area_position()
	var direction: Vector3 = (target_pos - global_position)
	direction.y = 0.0

	if target_doorable.is_in_standing_area(global_position):
		_arrive_at_door()
		return

	direction = direction.normalized()
	current_speed = speed
	var target_rotation: float = atan2(-direction.x, -direction.z)
	visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rotation, turn_lerp * delta)

	var angle: float = visuals.rotation.y
	var facing: Vector3 = Vector3(-sin(angle), 0.0, -cos(angle))
	velocity.x = facing.x * current_speed
	velocity.z = facing.z * current_speed

	animation_tree.set("parameters/locomotion/blend_position", 1.0)
	move_and_slide()


func _arrive_at_door() -> void:
	state = PlayerState.TURNING_TO_DOOR
	current_speed = 0.0
	velocity = Vector3.ZERO
	locked_position = global_position

	animation_tree.set("parameters/locomotion/blend_position", 0.0)
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	playback.travel("locomotion")


func _handle_turn_to_door(delta: float) -> void:
	if not target_doorable:
		state = PlayerState.MOVING
		return

	var target_angle: float = target_doorable.get_standing_face_angle()
	var angle_diff: float = angle_difference(visuals.rotation.y, target_angle)

	if abs(angle_diff) < deg_to_rad(5.0):
		visuals.rotation.y = target_angle
		state = PlayerState.OPENING_DOOR
		_play_open_door_animation()
		return

	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	if angle_diff > 0:
		playback.travel("turn_left")
	else:
		playback.travel("turn_right")

	var effective_speed: float = turn_speed * max(1.0, abs(angle_diff) / deg_to_rad(90.0))
	var step: float = sign(angle_diff) * min(abs(angle_diff), deg_to_rad(effective_speed) * delta)
	visuals.rotation.y += step

	global_position = locked_position
	velocity = Vector3.ZERO


func _walk_through_door(doorable: Doorable) -> void:
	## Completely independent of animation state.
	## Waits walk_through_start seconds, then slides the player forward
	## over walk_through_duration seconds regardless of what else is happening.
	await get_tree().create_timer(walk_through_start).timeout

	var start_pos: Vector3 = locked_position
	var end_pos: Vector3 = doorable.get_end_stand_position(end_stand_distance)
	end_pos.y = locked_position.y
	var elapsed: float = 0.0

	while elapsed < walk_through_duration:
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / walk_through_duration, 0.0, 1.0)
		locked_position = start_pos.lerp(end_pos, t)
		global_position = locked_position
		await get_tree().process_frame

	locked_position = end_pos
	global_position = locked_position


func _door_camera_sequence() -> void:
	## Cinematic camera arc during door opening. Runs fully independent.
	## ---- CONFIGURATION (edit these) ----
	# Normalize: snap camera behind the player before starting
	var normalize_pitch: float      = 0.0   # degrees
	var normalize_zoom: float       =  1.0    # spring length
	var normalize_time: float       =  2.0    # seconds to smooth into position
	var normalize_yaw_offset: float =   -30.0   # degrees left of directly behind

	# Phase 1: Creep in close + begin drift sideways
	var p1_zoom: float          =   0.3  # target zoom
	var p1_pitch: float         = 0.0   # degrees
	var p1_yaw_offset: float    =  135  # degrees from behind — drifts sideways as it zooms in
	var p1_duration: float      =  1.8    # seconds

	# Phase 3: Sweep around to face the player + pull back wide simultaneously
	var p3_yaw_offset: float    = 210.0   # degrees from behind
	var p3_pitch: float         = -10.0   # degrees (final pitch)
	var p3_zoom: float          =  4.0    # target zoom (final zoom)
	var p3_duration: float      =  2.5    # seconds
	## ---- END CONFIGURATION ----

	camera_cutscene_active = true

	# Sync target_camera_yaw to the actual camera angle to eliminate accumulated
	# mouse drift — prevents the tween from unwinding a large accumulated value.
	target_camera_yaw = camera_pivot.rotation.y

	# Compute behind_yaw as the shortest arc from current camera to behind-the-player.
	var behind_yaw: float = target_camera_yaw + angle_difference(target_camera_yaw, visuals.rotation.y + PI + deg_to_rad(normalize_yaw_offset))

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "target_camera_yaw", behind_yaw, normalize_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "target_camera_pitch", deg_to_rad(normalize_pitch), normalize_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "target_zoom", normalize_zoom, normalize_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "h_offset", -0.3, normalize_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	# Phase 1: Creep in close + drift sideways + shift h_offset simultaneously
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "target_zoom", p1_zoom, p1_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "target_camera_pitch", deg_to_rad(p1_pitch), p1_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "target_camera_yaw", behind_yaw + deg_to_rad(p1_yaw_offset), p1_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "h_offset", 0.6, p1_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	# Phase 3: Sweep around to face the player + pull back wide simultaneously
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "target_camera_yaw", behind_yaw + deg_to_rad(p3_yaw_offset), p3_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "target_camera_pitch", deg_to_rad(p3_pitch), p3_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "target_zoom", p3_zoom, p3_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	# Aggressive correction: normalize pitch and zoom back to neutral state over 0.6 seconds.
	# Yaw is left alone — player keeps their current view direction.
	var correction_duration: float = 0.6
	var final_pitch: float = deg_to_rad(-20.0)  # neutral looking angle
	var final_zoom: float = 2.5  # standard distance

	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "target_camera_pitch", final_pitch, correction_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "target_zoom", final_zoom, correction_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	camera_cutscene_active = false


func _play_open_door_animation() -> void:
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	playback.travel("open_door_inwards")

	if target_doorable:
		target_doorable.open_door()
		_walk_through_door(target_doorable)  # fire and forget — runs in parallel

	_door_camera_sequence()  # fire and forget — runs in parallel

	# Start right hand tracking if enabled
	if debug_track_right_hand:
		is_tracking_door_opening = true
		door_opening_elapsed = 0.0
		last_print_time = 0.0
		print("=== Door opening animation started ===")

	var anim: Animation = animation_player.get_animation_library("").get_animation("open_door_inwards") if animation_player.has_animation_library("") else null
	var wait_time: float = anim.length if anim else 2.0
	await get_tree().create_timer(wait_time).timeout

	# Stop tracking
	if debug_track_right_hand and is_tracking_door_opening:
		print("=== Door opening animation ended (%.2fs) ===" % door_opening_elapsed)
		is_tracking_door_opening = false

	if state != PlayerState.OPENING_DOOR:
		return

	playback.travel("locomotion")
	animation_tree.set("parameters/locomotion/blend_position", 0.0)
	state = PlayerState.AT_DOOR

	# Unlock input immediately; camera sequence continues correcting in the background
	camera_cutscene_active = false


func _leave_door() -> void:
	state = PlayerState.MOVING

	var indicator: Node = _get_doorable_indicator()
	if indicator and indicator.has_method("fade_in"):
		indicator.fade_in()

	target_doorable = null
