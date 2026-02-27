class_name EliseDialogue
extends Node3D

## Elise NPC dialogue at the bus station.
##
## Attach to the EliseBox CSGBox3D node in the scene root.
## Fires once when the player comes within PROXIMITY_DISTANCE metres of the box centre.
## 1. Dismisses the street mission statement.
## 2. Plays a three-part dialogue sequence with synchronised subtitles.

const PROXIMITY_DISTANCE: float = 4.0

const _ELISE_01: AudioStream = preload("res://assets/audio/dialogue/elise_dialogue_001.ogg")
const _SVEN_01:  AudioStream = preload("res://assets/audio/dialogue/sven_dialogue_001.ogg")
const _ELISE_02: AudioStream = preload("res://assets/audio/dialogue/elise_dialogue_002.ogg")

# elise_dialogue_002 is split into two subtitle lines at the 7-second mark
const _ELISE_02_SUBTITLE_A: String = "That's okay! I didn't wait too long.\nSo, are we going to get on the bus or is the cinema close?"
const _ELISE_02_SUBTITLE_B: String = "There's a cafe nearby that I really like."
const _ELISE_02_SPLIT_TIME: float = 7.0

var _triggered: bool = false

var _subtitle_font: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var _subtitle_canvas: CanvasLayer
var _subtitle_label: Label


func _ready() -> void:
	_setup_subtitles()


func _process(_delta: float) -> void:
	if _triggered:
		return
	var player := _find_player()
	if not player:
		return
	var dx: float = player.global_position.x - global_position.x
	var dz: float = player.global_position.z - global_position.z
	if sqrt(dx * dx + dz * dz) <= PROXIMITY_DISTANCE:
		_triggered = true
		_start_dialogue()


# ── Setup ──────────────────────────────────────────────────────────────────────

func _setup_subtitles() -> void:
	_subtitle_canvas = CanvasLayer.new()
	_subtitle_canvas.layer = 128
	add_child(_subtitle_canvas)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_override("font", _subtitle_font)

	var size_index: int = SettingsManager.get_setting("subtitles/text_size")
	var font_size: int = SettingsManager.SUBTITLE_SIZE_VALUES[
		clampi(size_index, 0, SettingsManager.SUBTITLE_SIZE_VALUES.size() - 1)
	]
	_subtitle_label.add_theme_font_size_override("font_size", font_size)
	_subtitle_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 1.0))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_label.offset_top = -200
	_subtitle_label.offset_bottom = -100
	_subtitle_label.visible = false
	_subtitle_canvas.add_child(_subtitle_label)


# ── Dialogue sequence ──────────────────────────────────────────────────────────

func _start_dialogue() -> void:
	# Dismiss the street mission statement
	var managers := get_tree().get_nodes_in_group("street_manager")
	for m in managers:
		if m.has_method("dismiss_mission_statement"):
			m.dismiss_mission_statement()

	# Line 1 — Elise
	await _play_line(_ELISE_01, "Hey. I thought you were going to stand me up.")

	# Line 2 — Sven
	await _play_line(_SVEN_01, "Sorry, I slept in.")

	# Line 3 — Elise (split subtitle at 7 s)
	await _play_elise_02()

	_hide_subtitle()


func _play_line(stream: AudioStream, subtitle_text: String) -> void:
	## Play a single voice line and wait until it finishes.
	if SettingsManager.get_setting("subtitles/enabled"):
		var at_bottom: bool = GameManager.claim_subtitle_bottom(self)
		_position_label(at_bottom)
		_subtitle_label.text = subtitle_text
		_subtitle_label.visible = true

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "Voice"
	player.volume_db = -8.0
	add_child(player)
	player.play()
	await player.finished
	player.queue_free()

	_hide_subtitle()
	# Brief pause between lines
	await get_tree().create_timer(0.3).timeout


func _play_elise_02() -> void:
	## Play elise_dialogue_002 with a subtitle switch at ELISE_02_SPLIT_TIME seconds.
	if SettingsManager.get_setting("subtitles/enabled"):
		var at_bottom: bool = GameManager.claim_subtitle_bottom(self)
		_position_label(at_bottom)
		_subtitle_label.text = _ELISE_02_SUBTITLE_A
		_subtitle_label.visible = true

	var player := AudioStreamPlayer3D.new()
	player.stream = _ELISE_02
	player.bus = "Voice"
	player.volume_db = -8.0
	add_child(player)
	player.play()

	# Wait for the split point then switch subtitle
	await get_tree().create_timer(_ELISE_02_SPLIT_TIME).timeout
	if SettingsManager.get_setting("subtitles/enabled"):
		_subtitle_label.text = _ELISE_02_SUBTITLE_B

	await player.finished
	player.queue_free()


# ── Helpers ────────────────────────────────────────────────────────────────────

func _hide_subtitle() -> void:
	GameManager.release_subtitle_bottom(self)
	_subtitle_label.visible = false


func _position_label(at_bottom: bool) -> void:
	if at_bottom:
		_subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_subtitle_label.offset_top = -200
		_subtitle_label.offset_bottom = -100
	else:
		_subtitle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_subtitle_label.offset_top = 100
		_subtitle_label.offset_bottom = 200


func _find_player() -> Node3D:
	var group := get_tree().get_nodes_in_group("player")
	if not group.is_empty():
		return group[0] as Node3D
	return get_tree().root.find_child("Player", true, false) as Node3D
