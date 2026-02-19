class_name PhoneInteractable
extends Node3D

## Marks an object as a phone that can be interacted with.
## Upon activation, plays a button press SFX then the voicemail audio with subtitles.

var indicator: InteractableIndicator = null
var can_interact: bool = true
var is_playing: bool = false
var voicemail_player: AudioStreamPlayer3D

# Subtitle UI
var subtitle_font: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var subtitle_canvas: CanvasLayer
var subtitle_label: Label
var current_subtitle_index: int = -1

var subtitles: Array[Dictionary] = [
	{"start": 0.0, "end": 1.0, "text": "Hey, Sven."},
	{"start": 2.01, "end": 6.55, "text": "I called but you didn't pick up.\nI guess you're sleeping again."},
	{"start": 7.77, "end": 11.58, "text": "Uh… your father sent you\nsome money."},
	{"start": 12.88, "end": 14.89, "text": "It's the twentieth today, right?"},
	{"start": 16.67, "end": 22.72, "text": "So… yeah. If you ever need\nextra money, just call."},
	{"start": 23.86, "end": 29.67, "text": "You can call the house too.\nJohan will probably answer."},
	{"start": 29.67, "end": 31.15, "text": "I sent Erika home\nfor a few days."},
	{"start": 31.2, "end": 37.72, "text": "So yeah. You can tell your father,\nor just call his cell."},
	{"start": 39.59, "end": 45.09, "text": "Anyway, he also said —\nI know you don't want to hear this —"},
	{"start": 46.24, "end": 51.15, "text": "But he wants to talk about you\nmaybe joining the company someday."},
	{"start": 52.33, "end": 56.25, "text": "We both really think\nyou'd fit in there."},
	{"start": 57.32, "end": 62.35, "text": "Karl is retiring soon,\nso maybe… you know…"},
	{"start": 63.73, "end": 65.21, "text": "But, yeah… I guess."},
	{"start": 66.28, "end": 68.16, "text": "Call if you need anything."},
	{"start": 69.41, "end": 69.9, "text": "Bye!"},
]

func _ready() -> void:
	if get_parent():
		get_parent().add_to_group("phone")
		indicator = get_parent().find_child("InteractableIndicator", false, false)
		if indicator:
			indicator.y_offset = 0.3
		else:
			push_warning("PhoneInteractable: No InteractableIndicator found on parent")

	_setup_audio()
	_setup_subtitles()

func _setup_audio() -> void:
	# Create voicemail player (needs local instance for .finished signal and .get_playback_position())
	voicemail_player = AudioStreamPlayer3D.new()
	voicemail_player.stream = AudioManager.get_audio_stream(AudioManager.AudioID.VOICEMAIL)
	voicemail_player.bus = "Voice"
	voicemail_player.max_distance = 8.0
	add_child(voicemail_player)

	voicemail_player.finished.connect(_on_voicemail_finished)

func _setup_subtitles() -> void:
	subtitle_canvas = CanvasLayer.new()
	subtitle_canvas.layer = 10
	add_child(subtitle_canvas)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_override("font", subtitle_font)

	# Apply text size from settings
	var size_index: int = SettingsManager.get_setting("subtitles/text_size")
	var font_size: int = SettingsManager.SUBTITLE_SIZE_VALUES[clampi(size_index, 0, SettingsManager.SUBTITLE_SIZE_VALUES.size() - 1)]
	subtitle_label.add_theme_font_size_override("font_size", font_size)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 1.0))

	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Default to bottom — _position_label() will move it to top if the slot is taken
	subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_label.offset_top = -200
	subtitle_label.offset_bottom = -100

	subtitle_label.visible = false
	subtitle_canvas.add_child(subtitle_label)

func _process(_delta: float) -> void:
	if not is_playing or not voicemail_player.playing:
		return

	var subtitles_enabled: bool = SettingsManager.get_setting("subtitles/enabled")
	if not subtitles_enabled:
		subtitle_label.visible = false
		return

	_update_subtitles(voicemail_player.get_playback_position())

func _update_subtitles(time: float) -> void:
	for i in subtitles.size():
		var sub: Dictionary = subtitles[i]
		if time >= sub["start"] and time <= sub["end"]:
			if current_subtitle_index != i:
				var at_bottom: bool = GameManager.claim_subtitle_bottom(self)
				_position_label(at_bottom)
				subtitle_label.text = sub["text"]
				subtitle_label.visible = true
				current_subtitle_index = i
			return

	if subtitle_label.visible:
		GameManager.release_subtitle_bottom(self)
		subtitle_label.visible = false
		current_subtitle_index = -1

func _hide_subtitles() -> void:
	GameManager.release_subtitle_bottom(self)
	subtitle_label.visible = false
	current_subtitle_index = -1

func _position_label(at_bottom: bool) -> void:
	if at_bottom:
		subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		subtitle_label.offset_top = -200
		subtitle_label.offset_bottom = -100
	else:
		subtitle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		subtitle_label.offset_top = 100
		subtitle_label.offset_bottom = 200

func activate() -> void:
	if is_playing:
		can_interact = false
		AudioManager.play_3d_sfx(AudioManager.AudioID.PHONE_BUTTON_PRESS, global_position)
		voicemail_player.stop()
		is_playing = false
		_hide_subtitles()
		_start_cooldown()
		return

	if not can_interact:
		return

	can_interact = false
	AudioManager.play_3d_sfx(AudioManager.AudioID.PHONE_BUTTON_PRESS, global_position)

	is_playing = true

	if indicator and indicator.has_method("fade_out"):
		indicator.fade_out()

	await get_tree().create_timer(0.3).timeout

	voicemail_player.play()

func _on_voicemail_finished() -> void:
	is_playing = false
	_hide_subtitles()
	_start_cooldown()

func _start_cooldown() -> void:
	if indicator and indicator.has_method("fade_out"):
		indicator.fade_out()

	await get_tree().create_timer(1.0).timeout

	can_interact = true
	if indicator and indicator.has_method("fade_in"):
		indicator.fade_in()
