class_name EliseDialogue
extends Node3D

## Elise NPC dialogue at the bus station.
##
## Attach to the EliseBox CSGBox3D node in the scene root.
## Fires once when the player comes within PROXIMITY_DISTANCE metres of the box centre.
## 1. Dismisses the street mission statement.
## 2. Plays a three-part dialogue sequence with synchronised subtitles.
## 3. Starts cafe scene preload 5 seconds into the sequence.
## 4. Cuts to black at 8.5 seconds (1.5 seconds after cafe subtitle appears).

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
		print("[EliseDialogue] _process: no player found this frame")
		return
	var dx: float = player.global_position.x - global_position.x
	var dz: float = player.global_position.z - global_position.z
	var dist: float = sqrt(dx * dx + dz * dz)
	# Print distance every 60 frames so we can see it closing in without spam
	if Engine.get_process_frames() % 60 == 0:
		print("[EliseDialogue] player dist to EliseBox: %.2f  (trigger at %.1f)  player_pos=%s  box_pos=%s" % [dist, PROXIMITY_DISTANCE, player.global_position, global_position])
	if dist <= PROXIMITY_DISTANCE:
		print("[EliseDialogue] *** PROXIMITY TRIGGERED at dist=%.2f ***" % dist)
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
	_subtitle_label.offset_top = -248
	_subtitle_label.offset_bottom = -148
	_subtitle_label.visible = false
	_subtitle_canvas.add_child(_subtitle_label)


# ── Dialogue sequence ──────────────────────────────────────────────────────────

func _start_dialogue() -> void:
	print("[EliseDialogue] _start_dialogue() entered")

	# Dismiss the street mission statement
	var managers := get_tree().get_nodes_in_group("street_manager")
	print("[EliseDialogue] found %d node(s) in group 'street_manager'" % managers.size())
	for m in managers:
		if m.has_method("dismiss_mission_statement"):
			print("[EliseDialogue] calling dismiss_mission_statement on %s" % m.name)
			m.dismiss_mission_statement()
		else:
			print("[EliseDialogue] WARNING: node %s has no dismiss_mission_statement method" % m.name)

	# Cafe preload is handled by street_manager.gd at scene start (5s delay, 15s window).
	# Nothing to do here.

	# Line 1 — Elise
	print("[EliseDialogue] playing line 1 (Elise 01)")
	await _play_line(_ELISE_01, "Hey. I thought you were going to stand me up.")
	print("[EliseDialogue] line 1 finished")

	# Line 2 — Sven
	print("[EliseDialogue] playing line 2 (Sven 01)")
	await _play_line(_SVEN_01, "Sorry, I slept in.")
	print("[EliseDialogue] line 2 finished")

	# Line 3 — Elise (split subtitle at 7 s) with black cut at 8.5 s
	print("[EliseDialogue] playing line 3 (Elise 02 — will cut to cafe at 8.5s)")
	await _play_elise_02()

	print("[EliseDialogue] _start_dialogue() fell through past _play_elise_02 (should not normally reach here)")
	_hide_subtitle()


func _on_preload_timer() -> void:
	## Called 5 seconds into the dialogue to begin cafe scene preload.
	print("[EliseDialogue] _on_preload_timer fired — calling start_background_preload")
	GameManager.start_background_preload("res://assets/models/environments/cafe_interior.tscn")
	print("[EliseDialogue] start_background_preload returned")


func _play_line(stream: AudioStream, subtitle_text: String) -> void:
	## Play a single voice line and wait until it finishes.
	print("[EliseDialogue] _play_line: stream=%s  subtitle='%s'" % [stream, subtitle_text.substr(0, 40)])
	if stream == null:
		print("[EliseDialogue] ERROR: stream is null — skipping line")
		return

	if SettingsManager.get_setting("subtitles/enabled"):
		var at_bottom: bool = GameManager.claim_subtitle_bottom(self)
		_position_label(at_bottom)
		_subtitle_label.text = subtitle_text
		_subtitle_label.visible = true
		print("[EliseDialogue] subtitle shown (at_bottom=%s)" % at_bottom)
	else:
		print("[EliseDialogue] subtitles disabled, skipping label")

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = "Voice"
	# Elise: -11 dB, Sven: -5 dB
	player.volume_db = -11.0 if subtitle_text.begins_with("Hey") or subtitle_text.begins_with("That's") else -5.0
	print("[EliseDialogue] AudioStreamPlayer3D created, bus=%s volume_db=%.1f — calling play()" % [player.bus, player.volume_db])
	add_child(player)
	player.play()
	print("[EliseDialogue] awaiting player.finished...")
	await player.finished
	print("[EliseDialogue] player.finished signal received")
	player.queue_free()

	_hide_subtitle()
	# Brief pause between lines
	await get_tree().create_timer(0.3).timeout
	print("[EliseDialogue] inter-line pause done")


func _play_elise_02() -> void:
	## Play elise_dialogue_002 with a subtitle switch at 7s and black cut at 8.5s.
	print("[EliseDialogue] _play_elise_02() entered")
	print("[EliseDialogue] _ELISE_02 stream: %s" % _ELISE_02)
	if _ELISE_02 == null:
		print("[EliseDialogue] ERROR: _ELISE_02 stream is null — cannot play line 3")
		return

	if SettingsManager.get_setting("subtitles/enabled"):
		var at_bottom: bool = GameManager.claim_subtitle_bottom(self)
		_position_label(at_bottom)
		_subtitle_label.text = _ELISE_02_SUBTITLE_A
		_subtitle_label.visible = true
		print("[EliseDialogue] subtitle A shown")

	var player := AudioStreamPlayer3D.new()
	player.stream = _ELISE_02
	player.bus = "Voice"
	player.volume_db = -11.0
	print("[EliseDialogue] Elise 02 AudioStreamPlayer3D created — calling play()")
	add_child(player)
	player.play()
	print("[EliseDialogue] Elise 02 playing. Waiting %.1fs for subtitle split..." % _ELISE_02_SPLIT_TIME)

	# Wait for the split point then switch subtitle
	await get_tree().create_timer(_ELISE_02_SPLIT_TIME).timeout
	print("[EliseDialogue] subtitle split timer fired (%.1fs elapsed)" % _ELISE_02_SPLIT_TIME)
	if SettingsManager.get_setting("subtitles/enabled"):
		_subtitle_label.text = _ELISE_02_SUBTITLE_B
		print("[EliseDialogue] subtitle B shown")

	# Cut to black at 8.5s (1.5s after cafe subtitle appears)
	print("[EliseDialogue] waiting 1.5s before hard cut...")
	await get_tree().create_timer(1.5).timeout
	print("[EliseDialogue] *** CALLING hard_cut_to_scene NOW ***")
	print("[EliseDialogue] GameManager valid: %s" % is_instance_valid(GameManager))
	print("[EliseDialogue] GameManager has hard_cut_to_scene: %s" % GameManager.has_method("hard_cut_to_scene"))
	GameManager.hard_cut_to_scene("res://assets/models/environments/cafe_interior.tscn")
	print("[EliseDialogue] hard_cut_to_scene() call returned (scene swap is async from here)")

	await player.finished
	player.queue_free()


# ── Helpers ────────────────────────────────────────────────────────────────────

func _hide_subtitle() -> void:
	GameManager.release_subtitle_bottom(self)
	_subtitle_label.visible = false


func _position_label(at_bottom: bool) -> void:
	if at_bottom:
		_subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_subtitle_label.offset_top = -248
		_subtitle_label.offset_bottom = -148
	else:
		_subtitle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_subtitle_label.offset_top = 148
		_subtitle_label.offset_bottom = 248


func _find_player() -> Node3D:
	var group := get_tree().get_nodes_in_group("player")
	if not group.is_empty():
		return group[0] as Node3D
	var by_name := get_tree().root.find_child("Player", true, false) as Node3D
	if by_name == null and Engine.get_process_frames() % 300 == 0:
		print("[EliseDialogue] WARNING: player not found by group 'player' or by name 'Player'")
	return by_name
