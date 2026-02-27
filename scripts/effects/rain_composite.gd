class_name RainCompositeController
extends Node

## Renders rain particles in isolation to a SubViewport, then composites the
## blurred result over the main scene. Nothing outside layer 2 is blurred.
##
## Requirements:
##   - Rain particles must be on visibility_layer 2 (rain_system.gd handles this).
##   - The main Camera3D must have cull_mask that excludes layer 2
##     (set in the scene: cull_mask = 1048573).

# ── Inspector ─────────────────────────────────────────────────────────────────

## Blur strength. 0 = off, 1 = maximum.
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.5:
	set(v):
		intensity = v
		if _mat: _mat.set_shader_parameter("intensity", v)

## UV-space direction of the blur stroke — match to rain wind/fall angle.
@export var blur_direction: Vector2 = Vector2(0.01, 0.04):
	set(v):
		blur_direction = v
		if _mat: _mat.set_shader_parameter("blur_direction", v)

# ── Private ───────────────────────────────────────────────────────────────────

var _main_cam: Camera3D
var _mat: ShaderMaterial

@onready var _viewport: SubViewport = $CanvasLayer/SubViewportContainer/SubViewport
@onready var _rain_cam: Camera3D    = $CanvasLayer/SubViewportContainer/SubViewport/RainCamera
@onready var _container: SubViewportContainer = $CanvasLayer/SubViewportContainer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_mat = _container.material as ShaderMaterial
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("blur_direction", blur_direction)

	# Explicitly share the main viewport's World3D so RainCamera sees the same scene.
	# Setting own_world_3d = true first lets us assign a specific World3D reference.
	_viewport.own_world_3d            = true
	_viewport.world_3d                = get_viewport().world_3d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_rain_cam.cull_mask = 2  # render only layer 2 (rain particles)

	_resize_viewport()
	get_viewport().size_changed.connect(_resize_viewport)


func _resize_viewport() -> void:
	_viewport.size = get_viewport().get_visible_rect().size


func _process(_delta: float) -> void:
	if not is_instance_valid(_main_cam):
		_main_cam = get_viewport().get_camera_3d()

	if is_instance_valid(_main_cam):
		_rain_cam.global_transform = _main_cam.global_transform
		_rain_cam.fov              = _main_cam.fov
		_rain_cam.near             = _main_cam.near
		_rain_cam.far              = _main_cam.far
