extends Control

## Opening Voiceover Sequence
## Video playback (10fps, B&W sepia, 1.5x centered) with synchronized subtitles

@onready var black_screen: ColorRect = $BlackScreen
@onready var subtitle_label: Label = $SubtitleLabel
@onready var transition_curtain: ColorRect = $TransitionCurtain


# Fonts
var subtitle_font: Font = preload("res://assets/fonts/roboto_condensed.ttf")
var title_font: Font = preload("res://assets/fonts/fjalla_one.ttf")

# Video
var voiceover_video: VideoStream = preload("res://assets/video/voiceover/voiceover_video.ogv")
var bw_sepia_shader: Shader = preload("res://assets/shaders/video_bw_sepia.gdshader")

# Noé prompt
var noe_prompt_label: Label = null

# Video display system (built programmatically for SubViewport 10fps cap)
var video_player: VideoStreamPlayer = null
var sub_viewport: SubViewport = null
var viewport_container: SubViewportContainer = null

# Frame blending: render at 12.5fps for smooth motion (10fps perceived + 2.5fps blend)
var frame_timer: float = 0.0
const FRAME_INTERVAL: float = 1.0 / 12.5

# Timing state
var video_playing: bool = false
var video_ended: bool = false
var current_subtitle_index: int = -1

# Subtitle timing data (times relative to video start)
# Voice starts 2.159s into the video
const VO_OFFSET: float = 2.159
var subtitles: Array[Dictionary] = [
	{"start": VO_OFFSET + 0.0, "end": VO_OFFSET + 3.56, "text": "I like to focus on the sensation."},
	{"start": VO_OFFSET + 5.346, "end": VO_OFFSET + 10.086, "text": "It's quite a tremendous thing, how you can just snuff it out."},
	{"start": VO_OFFSET + 11.094, "end": VO_OFFSET + 14.525, "text": "It feels like, I don't know"},
	{"start": VO_OFFSET + 14.915, "end": VO_OFFSET + 20.725, "text": "like being at a beautiful beach with the birds and the sea."},
	{"start": VO_OFFSET + 21.685, "end": VO_OFFSET + 24.903, "text": "That's how it feels like, I focus on that."},
]

func _ready() -> void:
	subtitle_label.visible = false
	_setup_subtitle_label()
	_setup_video_system()
	_setup_noe_prompt()

	# Wait 0.7s after scene load (2.0s total from button click at 1.3s scene load)
	await get_tree().create_timer(0.7).timeout
	transition_curtain.queue_free()
	_start_video()

func _setup_subtitle_label() -> void:
	subtitle_label.add_theme_font_override("font", subtitle_font)
	subtitle_label.add_theme_font_size_override("font_size", 34)
	subtitle_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 1.0))

	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_label.offset_top = -200
	subtitle_label.offset_bottom = -100

func _setup_noe_prompt() -> void:
	# Massive text prompt (Gaspar Noé style)
	noe_prompt_label = Label.new()
	noe_prompt_label.layout_mode = 1
	noe_prompt_label.anchors_preset = Control.PRESET_CENTER
	noe_prompt_label.text = ""  # Will be set when triggered
	noe_prompt_label.visible = false
	noe_prompt_label.add_theme_font_override("font", title_font)
	noe_prompt_label.add_theme_font_size_override("font_size", 80)
	noe_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	noe_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	noe_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(noe_prompt_label)

func _setup_video_system() -> void:
	# SubViewportContainer with scale transform instead of size-based enlargement
	# This centers and scales the video more reliably
	viewport_container = SubViewportContainer.new()
	viewport_container.layout_mode = 3  # Free layout
	viewport_container.stretch = true
	viewport_container.position = Vector2(0, 0)
	viewport_container.size = Vector2(1920, 1080)
	viewport_container.scale = Vector2(1.5, 1.5)  # Scale to 1.5x
	viewport_container.pivot_offset = Vector2(0, 0)  # Center pivot for scaling
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.visible = false

	# Apply B&W + sepia shader
	if bw_sepia_shader:
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = bw_sepia_shader
		viewport_container.material = mat

	# SubViewport renders at 10fps (UPDATE_DISABLED, manually triggered)
	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(1920, 1080)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sub_viewport.transparent_bg = false

	# VideoStreamPlayer inside the viewport
	video_player = VideoStreamPlayer.new()
	video_player.anchor_right = 1.0
	video_player.anchor_bottom = 1.0
	video_player.stream = voiceover_video
	video_player.bus = "SFX"

	# Build hierarchy
	sub_viewport.add_child(video_player)
	viewport_container.add_child(sub_viewport)

	# Insert after BlackScreen, before SubtitleLabel
	add_child(viewport_container)
	move_child(viewport_container, black_screen.get_index() + 1)

func _start_video() -> void:
	viewport_container.visible = true
	video_player.play()
	video_playing = true
	frame_timer = 0.0

	# Render first frame immediately
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Instantiate the house scene at voiceover START so hidden boot logic runs while the video plays
	var house_packed: PackedScene = load("res://scenes/sven_house.tscn")
	if house_packed:
		var house_inst = house_packed.instantiate()
		if house_inst:
			if house_inst.has_method("reveal_scene"):
				house_inst.background_preload = true
			GameManager.preloaded_scene = house_inst
			# Add to GameManager autoload so it persists until we reparent into Main/CurrentScene
			GameManager.add_child(house_inst)

	# Schedule Noé prompt: video is ~28.5 seconds
	await get_tree().create_timer(29.5).timeout
	video_ended = true
	video_playing = false  # Stop processing subtitles so prompt subtitle persists
	viewport_container.visible = false
	subtitle_label.visible = false

	# Play SFX 0.16 seconds before prompt appears with 0.14s fade in
	var noe_sfx_player: AudioStreamPlayer = AudioManager.play_sfx(AudioManager.AudioID.NOE_PROMPT, -80.0)
	if noe_sfx_player:
		var sfx_tween: Tween = create_tween()
		sfx_tween.tween_property(noe_sfx_player, "volume_db", 4.0, 0.14).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.16).timeout

	# Show Noé prompt
	_show_noe_prompt()

func _process(delta: float) -> void:
	if not video_playing:
		return

	# 10fps frame cap: only render a new frame every 0.1 seconds
	frame_timer += delta
	if frame_timer >= FRAME_INTERVAL:
		frame_timer -= FRAME_INTERVAL
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	# Update subtitles using actual video position
	var video_time: float = video_player.stream_position
	_update_subtitles(video_time)

func _update_subtitles(video_time: float) -> void:
	for i in subtitles.size():
		var sub: Dictionary = subtitles[i]
		if video_time >= sub["start"] and video_time <= sub["end"]:
			if current_subtitle_index != i:
				subtitle_label.text = sub["text"]
				subtitle_label.visible = true
				current_subtitle_index = i
			return

	if subtitle_label.visible:
		subtitle_label.visible = false
		current_subtitle_index = -1

func _show_noe_prompt() -> void:
	# Display massive Noé-style prompt
	noe_prompt_label.text = "VI KOMMER ATT TRÄFFAS VID BUSSTATIONEN"
	noe_prompt_label.visible = true

	# Show subtitle with English translation
	subtitle_label.text = "\"WE WILL MEET AT THE BUS STATION\""
	subtitle_label.visible = true

	# After 3 seconds, snap out the prompt and reveal preloaded house scene
	# Start the second Noé SFX slightly before the reveal (same offset as the first: 0.16s)
	var pre_reveal_delay: float = 3.0 - 0.16
	if pre_reveal_delay > 0.0:
		await get_tree().create_timer(pre_reveal_delay).timeout

	# Play the prompt SFX 0.16s before revealing, fade in over 0.14s
	var noe_sfx_player2: AudioStreamPlayer = AudioManager.play_sfx(AudioManager.AudioID.NOE_PROMPT, -80.0)
	if noe_sfx_player2:
		var sfx_tween2: Tween = create_tween()
		sfx_tween2.tween_property(noe_sfx_player2, "volume_db", 4.0, 0.14).set_ease(Tween.EASE_IN)

	# Wait the same offset used earlier so sfx leads the reveal by ~0.16s
	await get_tree().create_timer(0.16).timeout

	# Stop showing prompt and subtitle and hide black screen
	noe_prompt_label.visible = false
	subtitle_label.visible = false
	black_screen.visible = false

	# Reveal the preloaded house scene if present
	if GameManager.preloaded_scene:
		var house = GameManager.preloaded_scene
		print("opening_sequence: preloaded house parent=", house.get_parent(), " GameManager.main_node=", GameManager.main_node)

		var main_node = GameManager.main_node
		if not main_node:
			# SceneTree root (Window) does not provide find_node; search children for Main
			for root_child in get_tree().get_root().get_children():
				if root_child and root_child.has_method("find_node"):
					var found_main = root_child.find_node("Main", true, false)
					if found_main:
						main_node = found_main
						break
			print("opening_sequence: located Main via search=", main_node)

		if main_node and main_node.has_node("CurrentScene"):
			var current_scene_node = main_node.get_node("CurrentScene")
			# Reparent if needed
			if house.get_parent() != current_scene_node:
				if is_instance_valid(house.get_parent()):
					house.get_parent().remove_child(house)
				current_scene_node.add_child(house)
				GameManager.current_scene = house
				print("opening_sequence: reparented house into Main/CurrentScene")
		else:
			print("opening_sequence: ERROR - cannot find Main/CurrentScene to reparent house")

		# Call reveal helper if available
		if house.has_method("reveal_scene"):
			house.reveal_scene()
			print("opening_sequence: called reveal_scene() on house")
