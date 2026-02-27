class_name RainBlurController
extends CanvasLayer

## Directional post-process blur that simulates rain motion.
## Sits at CanvasLayer 126 (just below the camera motion blur at 127).
## Add rain_blur.tscn to any scene that has visible rain.

# ── Inspector ─────────────────────────────────────────────────────────────────

## Blur strength. 0 = off, 1 = maximum.
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.5:
	set(v):
		intensity = v
		if _mat:
			_mat.set_shader_parameter("intensity", v)

## UV-space direction of the blur stroke.
## X = horizontal slant (wind), Y = vertical fall.
## Typical rain: Vector2(0.01, 0.04). Heavier: Vector2(0.02, 0.08).
@export var blur_direction: Vector2 = Vector2(0.01, 0.04):
	set(v):
		blur_direction = v
		if _mat:
			_mat.set_shader_parameter("blur_direction", v)

# ── Private ───────────────────────────────────────────────────────────────────

var _mat: ShaderMaterial

@onready var _rect: ColorRect = $ColorRect

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 126
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = _rect.material as ShaderMaterial
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("blur_direction", blur_direction)
