class_name EndingBoot
extends Node

const _VO_SUBTITLES: Array[Dictionary] = [
	{start = 1.190,  end = 2.010,  text = "So that was..."},
	{start = 4.040,  end = 5.300,  text = "...uh..."},
	{start = 5.520,  end = 6.500,  text = "...the 27th?"},
	{start = 6.740,  end = 8.040,  text = "No that was a week before."},
	{start = 8.330,  end = 8.800,  text = "Okay."},
	{start = 9.910,  end = 12.220, text = "And, what did you-\ndid you just leave--"},
	{start = 12.220, end = 13.820, text = "No no, I, uh..."},
	{start = 14.770, end = 19.000, text = "That was really close to the Slottsskogen.\nSo I just went there, to the marsh."},
	{start = 19.480, end = 19.980, text = "Okay."},
	{start = 21.490, end = 22.110, text = "Uh..."},
	{start = 23.540, end = 25.170, text = "Did you plan that beforehand?"},
	{start = 25.170, end = 25.680, text = "Yeah, yeah."},
	{start = 28.400, end = 30.420, text = "It's not really how you guys think it is."},
	{start = 31.560, end = 33.000, text = "It's not like a compulsion really."},
	{start = 33.910, end = 34.760, text = "It's just really..."},
	{start = 35.340, end = 37.100, text = "It feels fun and interesting."},
	{start = 38.180, end = 39.200, text = "It's exciting."},
	{start = 39.930, end = 41.410, text = "So you just keep doing it."},
]

var _title_label: Label
var _subtitle_label: Label
var _vo_player: AudioStreamPlayer
var _vo_duration: float = 0.0
var _fade_out_started: bool = false
var _sequence_done: bool = false
var _vo_subtitle_index: int = -1


func _ready() -> void:
	_build_black_bg()
	_build_ui()
	GameManager.transition_finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)


func _build_black_bg() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 128
	add_child(canvas)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_override("font", preload("res://assets/fonts/roboto_condensed.ttf"))
	var size_index: int = SettingsManager.get_setting("subtitles/text_size")
	var font_size: int = SettingsManager.SUBTITLE_SIZE_VALUES[
		clampi(size_index, 0, SettingsManager.SUBTITLE_SIZE_VALUES.size() - 1)
	]
	_subtitle_label.add_theme_font_size_override("font_size", font_size)
	_subtitle_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 1.0))
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_label.offset_top    = -200
	_subtitle_label.offset_bottom = -100
	_subtitle_label.visible       = false
	canvas.add_child(_subtitle_label)

	_title_label = Label.new()
	_title_label.text = "SVEN KILLER DEMO"
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font = preload("res://assets/fonts/fjalla_one.ttf")
	ls.font_size = 160
	ls.font_color = Color(0.98, 0.98, 0.98, 1.0)
	ls.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	ls.shadow_offset = Vector2(6.0, 6.0)
	ls.outline_color = Color(0.0, 0.0, 0.0, 0.28)
	ls.outline_size = 3
	_title_label.label_settings = ls
	_title_label.visible = false
	canvas.add_child(_title_label)


func _on_transition_finished() -> void:
	await get_tree().create_timer(3.0).timeout
	_start_vo()


func _start_vo() -> void:
	var stream := load("res://assets/audio/voiceover/vo_final.ogg") as AudioStreamOggVorbis
	if not stream:
		push_warning("EndingBoot: vo_final.ogg not found — skipping to title")
		_on_vo_finished()
		return

	_vo_player = AudioStreamPlayer.new()
	_vo_player.stream = stream
	_vo_player.bus = "Master"
	_vo_player.volume_db = -40.0
	add_child(_vo_player)
	_vo_player.play()

	_vo_duration = stream.get_length()

	var tween := create_tween()
	tween.tween_property(_vo_player, "volume_db", 0.0, 1.0)

	_vo_player.finished.connect(_on_vo_finished, CONNECT_ONE_SHOT)


func _process(_delta: float) -> void:
	if _sequence_done or not is_instance_valid(_vo_player):
		return

	var pos: float = _vo_player.get_playback_position()

	# Subtitle sync.
	if SettingsManager.get_setting("subtitles/enabled"):
		var found: bool = false
		for i in _VO_SUBTITLES.size():
			var sub: Dictionary = _VO_SUBTITLES[i]
			if pos >= sub.start and pos <= sub.end:
				if _vo_subtitle_index != i:
					_subtitle_label.text = sub.text
					_subtitle_label.visible = true
					_vo_subtitle_index = i
				found = true
				break
		if not found and _subtitle_label.visible:
			_subtitle_label.visible = false
			_vo_subtitle_index = -1

	# Fade out 1s before VO ends
	if _vo_duration > 1.0 and not _fade_out_started and pos >= _vo_duration - 1.0:
		_fade_out_started = true
		create_tween().tween_property(_vo_player, "volume_db", -40.0, 1.0)


func _on_vo_finished() -> void:
	_sequence_done = true
	_subtitle_label.visible = false

	await get_tree().create_timer(2.0).timeout
	_title_label.visible = true

	await get_tree().create_timer(5.0).timeout
	_title_label.visible = false

	GameManager.hard_cut_to_scene("res://scenes/ui/main_menu.tscn")
