class_name Doorable
extends Node3D

## Marks an object as a door and defines where the player stands to use it.
## Attach this to any door's pivot/collision node.
##
## The standing area is computed automatically:
##   1. DoorCenter = XZ center of all MeshInstance3D children of the parent node
##   2. StandingArea = 0.01 × 0.01 m square, 0.2712 m from DoorCenter along
##      the standing_direction axis (the other axis stays at DoorCenter).

@export var standing_direction: Vector3 = Vector3(0, 0, -1)  ## Must be axis-aligned: ±X or ±Z

const STANDING_DISTANCE: float = 0.625
const STANDING_AREA_HALF: float = 0.01  # 0.01 m / 2

var _door_center: Vector3 = Vector3.ZERO  # World-space XZ center (Y = parent Y)


func _ready() -> void:
	if get_parent():
		get_parent().add_to_group("doorable")
		var indicator: InteractableIndicator = get_parent().find_child("InteractableIndicator", false, false)
		if indicator:
			indicator.y_offset = 1.1
		_compute_door_center()


func _compute_door_center() -> void:
	## Derive DoorCenter from the average XZ of all mesh children of the parent.
	var parent: Node = get_parent()
	if not parent:
		_door_center = global_position
		return

	var sum_x: float = 0.0
	var sum_z: float = 0.0
	var count: int = 0

	for child in parent.get_children():
		if child is MeshInstance3D:
			sum_x += child.global_position.x
			sum_z += child.global_position.z
			count += 1

	if count == 0:
		_door_center = parent.global_position
	else:
		_door_center = Vector3(sum_x / count, parent.global_position.y, sum_z / count)


func get_standing_area_position() -> Vector3:
	## Returns the world-space center of the standing area.
	var dir: Vector3 = standing_direction.normalized()
	# Only offset along the standing axis; keep the other axis at DoorCenter.
	if abs(dir.x) > abs(dir.z):
		# Standing side is along X
		return Vector3(_door_center.x + dir.x * STANDING_DISTANCE, _door_center.y, _door_center.z)
	else:
		# Standing side is along Z
		return Vector3(_door_center.x, _door_center.y, _door_center.z + dir.z * STANDING_DISTANCE)


func get_standing_face_angle() -> float:
	## Returns the yaw (radians) the player should face when at the door.
	## Player faces -standing_direction (i.e. toward the door).
	var dir: Vector3 = standing_direction.normalized()
	return atan2(dir.x, dir.z)


func is_in_standing_area(player_pos: Vector3) -> bool:
	## True when the player's XZ position is inside the 0.01 × 0.01 m standing area.
	var center: Vector3 = get_standing_area_position()
	var dx: float = abs(player_pos.x - center.x)
	var dz: float = abs(player_pos.z - center.z)
	return dx <= STANDING_AREA_HALF and dz <= STANDING_AREA_HALF


func get_end_stand_position(distance: float) -> Vector3:
	## DoorCenter shifted 'distance' meters along -standing_direction.
	var dir: Vector3 = standing_direction.normalized()
	return _door_center + (-dir * distance)


func open_door() -> void:
	## Three linear rotation phases. Edit the values below to tune by eye.
	## Each phase: [start_time, end_time, target_degrees_from_initial]
	## -z or -x standing side adds degrees; +z or +x subtracts.
	var phase1_start:  float = 2.65;  var phase1_end:  float = 3.30;  var phase1_deg: float = 40.0
	var phase2_start:  float = 3.70;  var phase2_end:  float = 4.20;  var phase2_deg: float = 90.0
	var phase3_start:  float = 4.45;  var phase3_end:  float = 4.85;  var phase3_deg: float =  50.0
	var phase4_start:  float = 5.20;  var phase4_end:  float = 5.50;  var phase4_deg: float =  0.0

	var pivot: Node3D = get_parent()
	if not pivot:
		return

	# -z or -x → add degrees (rotation_sign = +1)
	# +z or +x → subtract degrees (rotation_sign = -1)
	var dir: Vector3 = standing_direction.normalized()
	var rotation_sign: float
	if abs(dir.x) > abs(dir.z):
		rotation_sign = -sign(dir.x)
	else:
		rotation_sign = -sign(dir.z)

	var initial_y: float = pivot.rotation.y

	# Continuous flow: no gaps, segments connect at phase boundaries.
	# Each segment absorbs the gap after it into its duration.
	# SINE EASE_IN_OUT is the mathematically smoothest curve (no jerk at inflection).
	var tween: Tween = create_tween()
	# Hold at 0° until phase 1 begins
	tween.tween_interval(phase1_start)
	# 0° → 40°  (phase1_start → phase1_end)
	tween.tween_property(pivot, "rotation:y", initial_y + deg_to_rad(phase1_deg) * rotation_sign, phase1_end - phase1_start).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 40° → 90°  (phase1_end → phase2_end, gap absorbed)
	tween.tween_property(pivot, "rotation:y", initial_y + deg_to_rad(phase2_deg) * rotation_sign, phase2_end - phase1_end).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 90° → 50°  (phase2_end → phase3_end, gap absorbed)
	tween.tween_property(pivot, "rotation:y", initial_y + deg_to_rad(phase3_deg) * rotation_sign, phase3_end - phase2_end).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 50° → 0°   (phase3_end → phase4_end, gap absorbed)
	tween.tween_property(pivot, "rotation:y", initial_y + deg_to_rad(phase4_deg) * rotation_sign, phase4_end - phase3_end).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
