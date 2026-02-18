class_name Sittable
extends Node3D

## Marks an object as sittable and defines the sitting position.
## Attach this to any chair, bench, or sittable furniture.

@export var seat_position_path: NodePath = NodePath("SeatPosition")
@export var chair_face_direction: Vector3 = Vector3(0, 0, 1)  ## Direction the chair faces (Z+ by default)
@export_group("Sitting Offsets")
@export var sitting_offset: float = -0.5  ## Offset player position along chair-face-direction to counteract character drift
@export var sitting_offset_delay: float = 0.0  ## Seconds after sitting_idle starts before offset begins
@export var sitting_offset_duration: float = 0.2  ## Seconds over which the offset is applied
@export var spring_arm_offset: float = 0.5  ## Offset spring arm along chair-face-direction to counteract camera drift
@export var spring_arm_offset_delay: float = 0.0  ## Seconds after sitting_idle starts before spring arm offset begins
@export var spring_arm_offset_duration: float = 0.2  ## Seconds over which the spring arm offset is applied
@export_group("Standing Offsets")
@export var standing_offset: float = 0.5  ## Offset player position along chair-face-direction when standing up
@export var standing_offset_delay: float = 0.0  ## Seconds after sit_to_stand starts before offset begins
@export var standing_offset_duration: float = 0.2  ## Seconds over which the standing offset is applied
@export var standing_spring_arm_offset: float = -0.5  ## Offset spring arm along chair-face-direction when standing up
@export var standing_spring_arm_offset_delay: float = 0.0  ## Seconds after sit_to_stand starts before spring arm offset begins
@export var standing_spring_arm_offset_duration: float = 0.2  ## Seconds over which the standing spring arm offset is applied

const SITTING_AREA_OFFSET_DEFAULT: float = 1.0  ## Default distance from chair to sitting area (meters)
const SITTING_AREA_SIZE_DEFAULT: float = 0.5  ## Default size of the sitting area (meters)
@export_group("Sitting Area")
@export var sitting_area_offset: float = SITTING_AREA_OFFSET_DEFAULT  ## Distance from chair to sitting area (meters)
@export var sitting_area_size: Vector2 = Vector2(SITTING_AREA_SIZE_DEFAULT, SITTING_AREA_SIZE_DEFAULT)  ## Size of the sitting area (X, Z) in meters

var seat_marker: Marker3D = null

func _ready() -> void:
	# Find the seat position marker
	if has_node(seat_position_path):
		seat_marker = get_node(seat_position_path)
	else:
		push_warning("Sittable: SeatPosition marker not found at path: %s" % seat_position_path)

	# Add to sittable group for easy querying
	if get_parent():
		get_parent().add_to_group("sittable")
		var indicator: InteractableIndicator = get_parent().find_child("InteractableIndicator", false, false)
		if indicator:
			indicator.y_offset = 1.0

	# If a SeatPosition marker exists, derive the chair face direction from its global X axis.
	# This makes it robust when the model is rotated in the editor (e.g., chair forward == +X).
	if seat_marker:
		chair_face_direction = seat_marker.global_transform.basis.x.normalized()
	elif get_parent():
		# Fallback to parent rotation (use parent's +X as forward)
		chair_face_direction = get_parent().global_transform.basis.x.normalized()
	else:
		# Default: Z+ (legacy)
		chair_face_direction = chair_face_direction.normalized()

func get_seat_position() -> Vector3:
	if seat_marker:
		return seat_marker.global_position
	return global_position

func get_seat_rotation() -> float:
	if seat_marker:
		return seat_marker.global_rotation.y
	if get_parent():
		return get_parent().global_rotation.y
	return 0.0

func get_sitting_area_position() -> Vector3:
	## Returns the center of the sitting area where the player should walk to
	var chair_pos: Vector3 = get_parent().global_position if get_parent() else global_position
	return chair_pos + chair_face_direction * sitting_area_offset

func get_chair_face_angle() -> float:
	## Returns the yaw angle (radians) the player should face when sitting
	return atan2(-chair_face_direction.x, -chair_face_direction.z)

func is_in_sitting_area(player_pos: Vector3) -> bool:
	## Check if player is within the sitting area (XZ plane only)
	var area_center: Vector3 = get_sitting_area_position()
	var dx: float = abs(player_pos.x - area_center.x)
	var dz: float = abs(player_pos.z - area_center.z)
	return dx <= sitting_area_size.x / 2.0 and dz <= sitting_area_size.y / 2.0
