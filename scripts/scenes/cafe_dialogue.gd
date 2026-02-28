extends Node

var _subtitle_font: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var _audio_player: AudioStreamPlayer
var _subtitle_canvas: CanvasLayer
var _subtitle_label: Label
var _current_subtitle_index: int = -1
var _cut_triggered: bool = false

# Cut to black midway through the last subtitle (which starts at 50.8s, ends at 53.52s).
const _CUT_TIME: float = 52.2

var _subtitles: Array[Dictionary] = [
	{"start": 1.760, "end": 8.210, "text": "I don't get that stubborn idea that we have\nto marry our – our job and our happiness."},
	{"start": 9.130, "end": 12.310, "text": "I mean, you do something\nto make a living because…"},
	{"start": 12.710, "end": 14.720, "text": "you're good at it, or like –"},
	{"start": 15.170, "end": 17.810, "text": "good enough at it to earn money,"},
	{"start": 18.420, "end": 20.270, "text": "because this is a consumer world,"},
	{"start": 20.690, "end": 23.240, "text": "you need money to live, that's it."},
	{"start": 23.940, "end": 26.810, "text": "And that thing doesn't have to be\nwhat gives you meaning."},
	{"start": 27.710, "end": 29.730, "text": "When I was growing up\neveryone always said:"},
	{"start": 30.250, "end": 32.190, "text": "\"you have to work with something you love,\""},
	{"start": 32.900, "end": 33.490, "text": "and you're just like –"},
	{"start": 34.020, "end": 35.670, "text": "how many accountants or –"},
	{"start": 36.080, "end": 38.740, "text": "or lawyers actually love their jobs?"},
	{"start": 39.450, "end": 41.490, "text": "Sure, you can love your job,"},
	{"start": 41.810, "end": 42.920, "text": "I love my job,"},
	{"start": 43.360, "end": 44.820, "text": "I find a lot of joy in it,"},
	{"start": 45.720, "end": 47.670, "text": "but the thing that really gives me meaning"},
	{"start": 47.980, "end": 50.220, "text": "is like making music or drawing,"},
	{"start": 50.800, "end": 53.520, "text": "and it's not really the same thing –\nI don't know."},
]


func _ready() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = load("res://assets/audio/dialogue/cafe_dialogue.ogg")
	_audio_player.bus = "Voice"
	_audio_player.volume_db = -3.1
	add_child(_audio_player)

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

	_audio_player.play()
	get_tree().create_timer(_CUT_TIME).timeout.connect(_trigger_cut)


func _trigger_cut() -> void:
	if _cut_triggered:
		return
	_cut_triggered = true
	GameManager.hard_cut_to_scene("res://scenes/cinema_interior.tscn")


func _process(_delta: float) -> void:
	if not _audio_player.playing:
		return

	if not SettingsManager.get_setting("subtitles/enabled"):
		_subtitle_label.visible = false
		return

	var time: float = _audio_player.get_playback_position()
	for i in _subtitles.size():
		var sub: Dictionary = _subtitles[i]
		if time >= sub["start"] and time <= sub["end"]:
			if _current_subtitle_index != i:
				var at_bottom: bool = GameManager.claim_subtitle_bottom(self)
				if at_bottom:
					_subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
					_subtitle_label.offset_top = -200
					_subtitle_label.offset_bottom = -100
				else:
					_subtitle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
					_subtitle_label.offset_top = 100
					_subtitle_label.offset_bottom = 200
				_subtitle_label.text = sub["text"]
				_subtitle_label.visible = true
				_current_subtitle_index = i
			return

	if _subtitle_label.visible:
		GameManager.release_subtitle_bottom(self)
		_subtitle_label.visible = false
		_current_subtitle_index = -1
