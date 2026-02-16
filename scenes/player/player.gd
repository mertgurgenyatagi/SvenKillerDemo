extends CharacterBody3D

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

@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var animation_player: AnimationPlayer = $Visuals/AnimationPlayer

var skeleton: Skeleton3D
var current_speed: float = 0.0
var animation_tree: AnimationTree
var is_turning: bool = false
var turn_target_angle: float = 0.0
var turn_hold_frames: int = 0
var turn_moving: bool = false
const TURN_MOVE_DELAY: int = 5  # Physics frames before movement starts during held turn
var target_camera_yaw: float = 0.0
var target_camera_pitch: float = deg_to_rad(-20.0)
var target_zoom: float = 2.5

enum PlayerState { MOVING, WALKING_TO_SEAT, APPROACHING_CHAIR, TURNING_TO_SIT, SITTING_DOWN, SEATED, STANDING_UP }
var state: PlayerState = PlayerState.MOVING
var target_sittable: Sittable = null
var locked_position: Vector3 = Vector3.ZERO
var can_interact_with_seat: bool = false
var saved_spring_arm_pos: Vector3 = Vector3.ZERO


const ANIM_PATHS: Dictionary = {
	"idle": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Stand_Relaxed_Idle_v2_IPC.fbx",
	"walk": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Walk_F_Loop_IPC.fbx",
	"turn_left": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Stand_Rlx_Turn_In_Place_L_Loop_IPC.fbx",
	"turn_right": "res://FBX_Mobility_27B_Starter/FBX_Mobility_27B_Starter/Animation/IPC/MOB1_Stand_Rlx_Turn_In_Place_R_Loop_IPC.fbx",
	"sit_down": "res://assets/animations/sven/Stand To Sit.fbx",
	"sitting_idle": "res://assets/animations/sven/Sitting Idle.fbx",
	"sit_to_stand": "res://assets/animations/sven/Sit To Stand.fbx",
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

	# Transitions (all immediate with short crossfade)
	var xfade: float = 0.2
	var all_states: Array = ["locomotion", "turn_left", "turn_right", "sit_down", "sitting_idle", "sit_to_stand"]
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
	if anim_name in ["sit_down", "sit_to_stand"]:
		anim.loop_mode = Animation.LOOP_NONE
	else:
		anim.loop_mode = Animation.LOOP_LINEAR

	instance.queue_free()

func _input(event: InputEvent) -> void:
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
	camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, target_camera_yaw, camera_rotation_speed * delta)
	camera_pivot.rotation.x = lerpf(camera_pivot.rotation.x, target_camera_pitch, camera_rotation_speed * delta)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_zoom, zoom_inertia * delta)

func _handle_interact() -> void:
	if state == PlayerState.MOVING:
		var nearest_sittable: Sittable = _find_nearest_sittable()
		if nearest_sittable:
			_start_sitting_sequence(nearest_sittable)
		return

	# Cancel during walk or approach phases
	if state in [PlayerState.WALKING_TO_SEAT, PlayerState.APPROACHING_CHAIR]:
		_cancel_sitting_sequence()
		return

	# Stand up from seated (only after cooldown)
	if state == PlayerState.SEATED and can_interact_with_seat:
		_start_standing_sequence()
		return

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

	move_and_slide()
