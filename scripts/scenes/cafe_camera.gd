extends Node3D

## Cafe-scene camera controller.
## Drives the CameraCafe pivot's Y rotation with inertia.
## Vertical rotation is intentionally locked — the SpringArm3D's fixed rotation
## already sets the viewing angle toward the table.

@export var mouse_sensitivity: float = 0.003
@export var camera_rotation_speed: float = 6.0
@export var yaw_min_deg: float = -5.0
@export var yaw_max_deg: float = 5.0
@export var zoom_speed: float = 0.05
@export var zoom_min: float = 0.25
@export var zoom_max: float = 0.25
@export var zoom_inertia: float = 4.0

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var _target_yaw: float = deg_to_rad(0.0)
var _target_zoom: float = 0.25


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_target_zoom = spring_arm.spring_length
	rotation.y = _target_yaw
	camera.make_current()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_target_yaw -= event.relative.x * mouse_sensitivity
		_target_yaw = clampf(_target_yaw, deg_to_rad(yaw_min_deg), deg_to_rad(yaw_max_deg))

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom - zoom_speed, zoom_min, zoom_max)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom + zoom_speed, zoom_min, zoom_max)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, _target_yaw, camera_rotation_speed * delta)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, _target_zoom, zoom_inertia * delta)
