class_name NewspaperClipping
extends Node3D

## Newspaper clipping reader.
##
## Triggers timed subtitle text (translation of the clipping) when:
##   1. Player is within PROXIMITY_DISTANCE (0.5m) of the object
##   2. The clipping is visible in the camera frustum
##
## Both conditions must hold continuously for TRIGGER_DURATION (2s)
## before the reading sequence begins.
##
## Reading resets if the player moves beyond CANCEL_DISTANCE during playback.
## The full sequence plays only once per scene load.

const PROXIMITY_DISTANCE: float = 2.2   # Metres — player must be this close
const CANCEL_DISTANCE: float = 1.2      # Metres — abort reading if player walks away
const TRIGGER_DURATION: float = 2.0     # Seconds of sustained proximity + visibility required

# Subtitle display
var subtitle_font: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var subtitle_canvas: CanvasLayer
var subtitle_label: Label
var current_subtitle_index: int = -1

# Trigger state
var trigger_timer: float = 0.0

# Reading state
var reading_active: bool = false
var reading_timer: float = 0.0
var has_been_read: bool = false

# Newspaper text — each block is displayed for its window then cleared.
# Times are in seconds relative to reading_timer.
# Headline shown briefly, then body paragraphs at a comfortable reading pace.
var subtitles: Array[Dictionary] = [
	{
		"start": 0.0, "end": 4.5,
		"text": "\"TWO KILLED IN STABBING ATTACKS ON LINNÉGATAN\""
	},
	{
		"start": 5.5, "end": 12.0,
		"text": "\"Two people have been killed in separate stabbing attacks\non Linnégatan during the past two weeks.\""
	},
	{
		"start": 13.0, "end": 21.0,
		"text": "\"First, a homeless man in his 50s was found seriously injured\noutdoors late in the evening and later died\nfrom his injuries at the hospital.\""
	},
	{
		"start": 22.0, "end": 29.5,
		"text": "\"Earlier this week, a young girl who was reportedly\nbegging in the area was found dead\nnear a building entrance.\""
	},
	{
		"start": 30.5, "end": 37.5,
		"text": "\"Police are investigating the cases and examining\nwhether there is any connection between the incidents,\""
	},
	{
		"start": 38.0, "end": 42.5,
		"text": "\"but no suspect has been arrested yet.\""
	},
]

const READING_TOTAL_TIME: float = 43.5  # Slightly past last subtitle end


func _ready() -> void:
	_setup_subtitles()


func _setup_subtitles() -> void:
	subtitle_canvas = CanvasLayer.new()
	subtitle_canvas.layer = 10
	add_child(subtitle_canvas)

	subtitle_label = Label.new()
	subtitle_label.add_theme_font_override("font", subtitle_font)

	# Honour the player's subtitle size setting
	var size_index: int = SettingsManager.get_setting("subtitles/text_size")
	var font_size: int = SettingsManager.SUBTITLE_SIZE_VALUES[
		clampi(size_index, 0, SettingsManager.SUBTITLE_SIZE_VALUES.size() - 1)
	]
	subtitle_label.add_theme_font_size_override("font_size", font_size)

	# Slightly warm white — distinct from UI elements, matches voicemail style
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


func _process(delta: float) -> void:
	if has_been_read:
		return

	if reading_active:
		_process_reading(delta)
	else:
		_check_trigger(delta)


# --- Trigger ---

func _check_trigger(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		trigger_timer = 0.0
		return

	var player: Node3D = _find_player(camera)
	if not player:
		trigger_timer = 0.0
		return

	var newspaper_pos: Vector3 = global_position
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var paper_xz  := Vector2(newspaper_pos.x, newspaper_pos.z)
	var player_dist: float = player_xz.distance_to(paper_xz)
	var in_frustum: bool = camera.is_position_in_frustum(newspaper_pos)

	if player_dist <= PROXIMITY_DISTANCE and in_frustum:
		trigger_timer += delta
		if trigger_timer >= TRIGGER_DURATION:
			_start_reading()
	else:
		# Reset — player looked away or stepped back
		trigger_timer = 0.0


# --- Reading sequence ---

func _start_reading() -> void:
	reading_active = true
	reading_timer = 0.0
	current_subtitle_index = -1


func _process_reading(delta: float) -> void:
	# Cancel if player walks away
	var camera: Camera3D = get_viewport().get_camera_3d()
	var player: Node3D = _find_player(camera) if camera else null
	if player:
		var player_xz := Vector2(player.global_position.x, player.global_position.z)
		var paper_xz  := Vector2(global_position.x, global_position.z)
		if player_xz.distance_to(paper_xz) > CANCEL_DISTANCE:
			_cancel_reading()
			return

	# Honour subtitle toggle
	if not SettingsManager.get_setting("subtitles/enabled"):
		subtitle_label.visible = false
	else:
		_update_subtitles(reading_timer)

	reading_timer += delta

	if reading_timer >= READING_TOTAL_TIME:
		_finish_reading()


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

	# Between subtitle blocks — hide label
	if subtitle_label.visible:
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


func _cancel_reading() -> void:
	GameManager.release_subtitle_bottom(self)
	reading_active = false
	trigger_timer = 0.0
	reading_timer = 0.0
	subtitle_label.visible = false
	current_subtitle_index = -1


func _finish_reading() -> void:
	GameManager.release_subtitle_bottom(self)
	reading_active = false
	has_been_read = true
	subtitle_label.visible = false
	current_subtitle_index = -1


# --- Helpers ---

func _find_player(camera: Camera3D) -> Node3D:
	## Walk up from the camera until we find the CharacterBody3D player.
	## Matches the pattern used by InteractableIndicator.
	var node: Node = camera
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
