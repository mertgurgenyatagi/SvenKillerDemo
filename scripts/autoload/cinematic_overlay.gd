extends Node

## CinematicOverlay — persistent game-wide visual effects.
##
## Layer layout (see CLAUDE.md):
##   198 — black letterbox bars (above subtitles at 128, below fade at 200)
##   199 — film grain (on top of bars for authentic film look)
##
## Black bars create a 1920×804 visible frame inside the 1920×1080 window.
## Bar height = (1080 - 804) / 2 = 138 px per bar.

const BAR_HEIGHT: int = 138
const GRAIN_SHADER_PATH: String = "res://assets/shaders/film_grain.gdshader"

var _bar_layer: CanvasLayer
var _grain_layer: CanvasLayer


func _ready() -> void:
	_build_bars()
	_build_grain()


func _build_bars() -> void:
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 198
	_bar_layer.name = "LetterboxBars"
	add_child(_bar_layer)

	var top_bar := ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 0
	top_bar.offset_bottom = BAR_HEIGHT
	_bar_layer.add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.color = Color.BLACK
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top = -BAR_HEIGHT
	bot_bar.offset_bottom = 0
	_bar_layer.add_child(bot_bar)


func _build_grain() -> void:
	_grain_layer = CanvasLayer.new()
	_grain_layer.layer = 199
	_grain_layer.name = "FilmGrain"
	add_child(_grain_layer)

	var grain_rect := ColorRect.new()
	grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader_mat := ShaderMaterial.new()
	var shader: Shader = load(GRAIN_SHADER_PATH)
	shader_mat.shader = shader
	grain_rect.material = shader_mat

	_grain_layer.add_child(grain_rect)
