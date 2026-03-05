class_name MissionStatement
extends Node

## Persistent right-side mission statement overlay.
##
## Appears DELAY seconds after show_after_delay() is called (invoked by the
## boot script once the house scene is fully visible). Fades in over
## FADE_IN_DURATION seconds and plays a soft MENU_HOVER cue on reveal.
##
## Usage (from boot script):
##   for node in get_tree().get_nodes_in_group("mission_statement"):
##       node.show_after_delay()

const DELAY: float = 15.0
const FADE_IN_DURATION: float = 1.2

var _canvas: CanvasLayer
var _label: Label
var _font: Font = preload("res://assets/fonts/roboto_condensed_medium.ttf")

var _triggered: bool = false


func _ready() -> void:
	add_to_group("mission_statement")
	_build_ui()


func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 128  # Above motion blur (127) so text is never blurred
	add_child(_canvas)

	_label = Label.new()
	_label.text = LocaleManager.g("mission_house")
	_label.add_theme_font_override("font", _font)
	_label.add_theme_font_size_override("font_size", 24)
	# Warm off-white — reads clearly against dark interiors without drawing the eye
	_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.89, 1.0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Right side of screen, positioned about 300 px from the top.
	# At 1920 × 1080 this gives a single-line rect in the upper-right corner.
	_label.anchor_left   = 0.35
	_label.anchor_top    = 0.0
	_label.anchor_right  = 1.0
	_label.anchor_bottom = 0.0
	_label.offset_left   = 0
	_label.offset_top    = 295
	_label.offset_right  = -50   # 50 px margin from the right edge
	_label.offset_bottom = 345   # height = 50 px (one line at 24 px)

	# Start fully transparent; tween brings it in
	_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_label.visible = false
	_canvas.add_child(_label)


func show_after_delay() -> void:
	## Called by the boot script once the scene is visible.
	## Guards against double-calls (e.g. preloaded + reveal).
	if _triggered:
		return
	_triggered = true
	await get_tree().create_timer(DELAY).timeout
	_show()


func _show() -> void:
	_label.visible = true
	AudioManager.play_sfx(AudioManager.AudioID.MENU_HOVER, linear_to_db(0.35))
	var tween := create_tween()
	tween.tween_property(_label, "modulate:a", 1.0, FADE_IN_DURATION)
