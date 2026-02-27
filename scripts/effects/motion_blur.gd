class_name MotionBlurController
extends CanvasLayer

## Screen-space motion blur driven by camera angular velocity.
## Lives as a CanvasLayer (layer 127) so it composites on top of all 3D content.
## Add the motion_blur.tscn to any scene that contains a Camera3D.

# ── Inspector ─────────────────────────────────────────────────────────────────

## Blur strength. 0 = off, 0.5 = cinematic, 1.0+ = extreme.
@export_range(0.0, 2.0, 0.01) var intensity: float = 0.5:
	set(v):
		intensity = v
		if _mat:
			_mat.set_shader_parameter("intensity", v)

## Temporal smoothing. Higher = trails linger longer; lower = snappier.
## 0.0 = no smoothing (raw per-frame delta), 0.99 = very slow decay.
@export_range(0.0, 0.99, 0.01) var smoothing: float = 0.55

## Maximum blur offset as a fraction of screen size (caps extreme snaps).
@export_range(0.01, 0.3, 0.005) var max_blur: float = 0.08

# ── Private ───────────────────────────────────────────────────────────────────

var _camera: Camera3D
var _prev_basis: Basis
var _smoothed_vel: Vector2 = Vector2.ZERO
var _mat: ShaderMaterial

@onready var _rect: ColorRect = $ColorRect

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 127
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = _rect.material as ShaderMaterial
	_mat.set_shader_parameter("intensity", intensity)
	_resolve_camera()


func _process(_delta: float) -> void:
	if not is_instance_valid(_camera):
		_resolve_camera()
		return

	var curr_basis := _camera.global_basis

	# Angular delta between this frame and last (Euler, handles wrap-around)
	var prev_euler := _prev_basis.get_euler()
	var curr_euler := curr_basis.get_euler()
	var d_yaw   := wrapf(curr_euler.y - prev_euler.y, -PI, PI)
	var d_pitch := wrapf(curr_euler.x - prev_euler.x, -PI, PI)

	# Convert rotation delta to screen-space UV offset.
	# fov gives how many radians of world the screen spans vertically;
	# fov_h is the horizontal equivalent.
	var fov_v := deg_to_rad(_camera.fov)
	var size  := get_viewport().get_visible_rect().size
	var fov_h := 2.0 * atan(tan(fov_v * 0.5) * (size.x / maxf(size.y, 1.0)))

	var raw_vel := Vector2(d_yaw / fov_h, d_pitch / fov_v)
	raw_vel = raw_vel.limit_length(max_blur)

	# Smooth to prevent single-frame spikes from looking like flashes
	_smoothed_vel = _smoothed_vel.lerp(raw_vel, 1.0 - smoothing)

	_mat.set_shader_parameter("velocity", _smoothed_vel)
	_prev_basis = curr_basis

# ── Helpers ───────────────────────────────────────────────────────────────────

func _resolve_camera() -> void:
	# Always use whatever Camera3D is currently active in the viewport
	_camera = get_viewport().get_camera_3d()
	if _camera:
		_prev_basis = _camera.global_basis
