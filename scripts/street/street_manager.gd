extends Node

## Street scene manager.
## Handles:
##   1. Mission statement (1s after load)
##   2. Out-of-bounds death boundary → instant black, audio cut, respawn
##   3. Second Noé prompt at z=60 (controls locked, audio continues)

const BOUNDARY_Z_MAX: float = 127.0
const BOUNDARY_Z_MIN: float = 24.0
const BOUNDARY_X_MAX: float = 17.79
const BOUNDARY_X_MIN: float = -2.35

const NOE_TRIGGER_Z: float = 60.0
const NOE_DURATION: float = 2.25

# ── Private vars ───────────────────────────────────────────────────────────────

var _player: CharacterBody3D = null
var _player_start_transform: Transform3D

var _death_active: bool = false
var _noe_active: bool = false
var _noe_triggered: bool = false

# Overlay UI (black screen + Noé prompt)
var _canvas: CanvasLayer
var _black_screen: ColorRect
var _noe_label: Label
var _subtitle_label: Label

var _title_font: Font = preload("res://assets/fonts/fjalla_one.ttf")
var _body_font: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var _mission_font: Font = preload("res://assets/fonts/roboto_condensed_medium.ttf")


# ── Lifecycle ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	_find_player()
	_build_overlay_ui()
	_show_mission_after_delay()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if _death_active or _noe_active:
		return

	var pos: Vector3 = _player.global_position

	# Out-of-bounds check
	if pos.x < BOUNDARY_X_MIN or pos.x > BOUNDARY_X_MAX \
			or pos.z < BOUNDARY_Z_MIN or pos.z > BOUNDARY_Z_MAX:
		_trigger_death()
		return

	# Noé prompt fires the first time the player's z drops to or below 60
	if not _noe_triggered and pos.z <= NOE_TRIGGER_Z:
		_noe_triggered = true
		_trigger_noe_prompt()


# ── Setup helpers ──────────────────────────────────────────────────────────────

func _find_player() -> void:
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if not _player:
		var nodes := get_tree().get_nodes_in_group("player")
		if not nodes.is_empty():
			_player = nodes[0] as CharacterBody3D
	if _player:
		_player_start_transform = _player.global_transform


func _build_overlay_ui() -> void:
	## High-layer canvas covers motion blur (127) and subtitles (128).
	_canvas = CanvasLayer.new()
	_canvas.layer = 190
	add_child(_canvas)

	# Full-screen black overlay
	_black_screen = ColorRect.new()
	_black_screen.color = Color.BLACK
	_black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black_screen.visible = false
	_canvas.add_child(_black_screen)

	# Noé prompt label — centre of screen
	_noe_label = Label.new()
	_noe_label.add_theme_font_override("font", _title_font)
	_noe_label.add_theme_font_size_override("font_size", 80)
	_noe_label.add_theme_color_override("font_color", Color.WHITE)
	_noe_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_noe_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_noe_label.visible = false
	_canvas.add_child(_noe_label)

	# Subtitle label — bottom of screen
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_override("font", _body_font)
	_subtitle_label.add_theme_font_size_override("font_size", 34)
	_subtitle_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 1.0))
	_subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_label.offset_top = -200
	_subtitle_label.offset_bottom = -100
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.visible = false
	_canvas.add_child(_subtitle_label)


# ── Mission statement ──────────────────────────────────────────────────────────

func _show_mission_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return

	var canvas := CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)

	var label := Label.new()
	label.text = "○  Go left to the bus station. Don't keep her waiting."
	label.add_theme_font_override("font", _mission_font)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.89, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.anchor_left   = 0.35
	label.anchor_top    = 0.0
	label.anchor_right  = 1.0
	label.anchor_bottom = 0.0
	label.offset_left   = 0
	label.offset_top    = 295
	label.offset_right  = -50
	label.offset_bottom = 345
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	canvas.add_child(label)

	AudioManager.play_sfx(AudioManager.AudioID.MENU_HOVER, linear_to_db(0.35))
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 1.2)


# ── Death boundary ─────────────────────────────────────────────────────────────

func _trigger_death() -> void:
	_death_active = true

	# Instant black
	_black_screen.visible = true

	# Cut all audio via Master bus mute
	var master_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, true)

	await get_tree().create_timer(1.0).timeout

	# Teleport player back to scene start
	if is_instance_valid(_player):
		_player.global_transform = _player_start_transform
		_player.velocity = Vector3.ZERO

	# Restore audio and lift black
	AudioServer.set_bus_mute(master_idx, false)
	_black_screen.visible = false
	_death_active = false


# ── Second Noé prompt ──────────────────────────────────────────────────────────

func _trigger_noe_prompt() -> void:
	_noe_active = true

	# Freeze player — audio continues
	if is_instance_valid(_player):
		_player.set_process_input(false)
		_player.set_physics_process(false)
		_player.velocity = Vector3.ZERO

	# Instant black
	_black_screen.visible = true

	# Start SFX (reverb bus, fade in from silence)
	_play_noe_sfx()

	# Show text + subtitle immediately
	_noe_label.text = "LUGNA NER DIG. DET ÄR BARA EN DEJT."
	_subtitle_label.text = "\"CALM DOWN. IT'S JUST A DATE.\""
	_noe_label.visible = true
	_subtitle_label.visible = true

	# Wait, then play exit SFX 0.16s before lifting
	await get_tree().create_timer(NOE_DURATION - 0.16).timeout
	_play_noe_sfx()
	await get_tree().create_timer(0.16).timeout

	# Restore
	_noe_label.visible = false
	_subtitle_label.visible = false
	_black_screen.visible = false

	if is_instance_valid(_player):
		_player.set_process_input(true)
		_player.set_physics_process(true)

	_noe_active = false


func _play_noe_sfx() -> void:
	var stream: AudioStream = AudioManager.get_audio_stream(AudioManager.AudioID.NOE_PROMPT)
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "NoePrompt"
	player.volume_db = -80.0
	add_child(player)
	player.play()
	var t := create_tween()
	t.tween_property(player, "volume_db", 4.0, 0.14).set_ease(Tween.EASE_IN)
	player.finished.connect(player.queue_free)
