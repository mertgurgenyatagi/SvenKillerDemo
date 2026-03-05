extends Node

var _subtitle_font: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var _audio_player: AudioStreamPlayer
var _subtitle_canvas: CanvasLayer
var _subtitle_label: Label
var _current_subtitle_index: int = -1
var _cut_triggered: bool = false

# Cut to black midway through the last subtitle (which starts at 50.8s, ends at 53.52s).
const _CUT_TIME: float = 52.2

var _subtitles: Array[Dictionary] = []


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
	_subtitle_label.offset_top = -248
	_subtitle_label.offset_bottom = -148
	_subtitle_label.visible = false
	_subtitle_canvas.add_child(_subtitle_label)

	_audio_player.play()
	_subtitles = LocaleManager.s("cafe_dialogue")
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
					_subtitle_label.offset_top = -248
					_subtitle_label.offset_bottom = -148
					else:
						_subtitle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
						_subtitle_label.offset_top = 148
						_subtitle_label.offset_bottom = 248
				_subtitle_label.text = sub["text"]
				_subtitle_label.visible = true
				_current_subtitle_index = i
			return

	if _subtitle_label.visible:
		GameManager.release_subtitle_bottom(self)
		_subtitle_label.visible = false
		_current_subtitle_index = -1
