extends Control

## Main Menu - Cinematic atmosphere with refined typography

@onready var background_video: VideoStreamPlayer = $BackgroundVideo
@onready var left_vignette: ColorRect = $LeftVignette
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var title_label: Label = $MenuContainer/TitleLabel
@onready var new_game_button: Button = $MenuContainer/NewGameButton
@onready var settings_button: Button = $MenuContainer/SettingsButton
@onready var ambient_player: AudioStreamPlayer = $AmbientPlayer
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var music_delay_timer: Timer = $MusicDelayTimer

# Fonts
var fjalla_font: Font = preload("res://assets/fonts/fjalla_one.ttf")
var roboto_condensed_font: Font = preload("res://assets/fonts/roboto_condensed_medium.ttf")

# Hover effect state
var hover_tweens: Dictionary = {}
var hover_panels: Dictionary = {}
var new_game_locked: bool = false

# Settings overlay
var settings_overlay: Control = null

# Audio - loaded at runtime (needs Godot import first)
var ambient_audio: AudioStream
var music_audio: AudioStream

# Config values
var ambient_volume_db: float = 4.0 # Remove config usage, use direct values
var music_volume_db: float = -4.0
var background_video_scale: float = 1.0

func _ready() -> void:
	# Load audio at runtime
	ambient_audio = load("res://assets/audio/sfx/ambient/ambient_main_menu.ogg")
	music_audio = load("res://assets/audio/music/sven_killer.ogg")

	setup_video()
	setup_dust_particles()
	setup_title()
	setup_buttons()
	setup_audio()

	# Disable the left vignette (remove visual vignette)
	left_vignette.visible = false
	left_vignette.material = null

	# Push the entire menu up by 300px originally; adjust down 125px (net -175)
	menu_container.position = menu_container.position + Vector2(0, -175)

	# Add initial black overlay that fades out (prevents white flash on menu load)
	var initial_overlay = ColorRect.new()
	initial_overlay.color = Color(0, 0, 0, 1)
	initial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	initial_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	initial_overlay.z_index = 100000
	add_child(initial_overlay)

	# Fade out over 0.3 seconds
	var fade_tween = create_tween()
	fade_tween.tween_property(initial_overlay, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_OUT)
	await fade_tween.finished
	initial_overlay.queue_free()

func setup_video() -> void:
	background_video.stream = load("res://assets/video/menu/main_menu.ogv")
	background_video.modulate = Color(0.45, 0.43, 0.48, 1.0)  # Cool, desaturated, slightly brighter
	# Set scale explicitly and play
	background_video.scale = Vector2(background_video_scale, background_video_scale)
	background_video.play()

	# VideoStreamPlayer doesn't support material shaders, use overlay ColorRect instead
	var overlay = ColorRect.new()
	overlay.name = "VideoShaderOverlay"
	overlay.color = Color(1, 1, 1, 1)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Match video size and position
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Apply dreamscape shader to overlay
	var shader = load("res://assets/shaders/video_dreamscape.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		# Set vignette to 0.5 for testing
		mat.set_shader_parameter("vignette_intensity", 0.5)
		overlay.material = mat
		print("Video overlay shader applied")

	# Add overlay right after video
	add_child(overlay)
	move_child(overlay, background_video.get_index() + 1)

# Note: centering handled by node anchors/preset; resize handler removed

func setup_dust_particles() -> void:
	var particles = GPUParticles2D.new()
	particles.name = "DustParticles"
	particles.amount = 50  # Sparse, cinematic
	particles.lifetime = 12.0  # Long-lived particles
	particles.preprocess = 5.0  # Pre-warm so particles exist at start
	particles.z_index = 1  # Above video, below menu

	# Create process material
	var material = ParticleProcessMaterial.new()

	# Emission: full screen area
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(960, 540, 0)  # Half of 1920x1080

	# Movement: very slow drift
	material.direction = Vector3(0.2, -0.1, 0)  # Slight diagonal drift
	material.spread = 30.0
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 15.0

	# Gravity: slight upward (dust floats)
	material.gravity = Vector3(0, -2, 0)

	# Size
	material.scale_min = 0.5
	material.scale_max = 2.0

	# Alpha fade in/out over lifetime
	var alpha_curve = Curve.new()
	alpha_curve.add_point(Vector2(0.0, 0.0))  # Fade in
	alpha_curve.add_point(Vector2(0.1, 1.0))
	alpha_curve.add_point(Vector2(0.9, 1.0))
	alpha_curve.add_point(Vector2(1.0, 0.0))  # Fade out
	var alpha_curve_tex = CurveTexture.new()
	alpha_curve_tex.curve = alpha_curve
	material.alpha_curve = alpha_curve_tex

	particles.process_material = material

	# Create soft circle texture procedurally
	particles.texture = _create_dust_texture()

	# Position at center of screen
	particles.position = Vector2(960, 540)

	# Add to scene (after BackgroundVideo)
	add_child(particles)
	move_child(particles, 1)  # Position after BackgroundVideo

	particles.emitting = true

func _create_dust_texture() -> ImageTexture:
	# Create a simple soft circle procedurally
	var size = 32
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2.0, size / 2.0)
	var radius = size / 2.0

	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			var alpha = clampf(1.0 - (dist / radius), 0.0, 1.0)
			alpha = pow(alpha, 2.0)  # Softer falloff
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * 0.25))  # 25% max opacity

	return ImageTexture.create_from_image(image)

func setup_title() -> void:
	# Stark, imposing title - all caps feeling without being all caps
	var title_settings = LabelSettings.new()
	title_settings.font = fjalla_font
	title_settings.font_size = 160
	# Base color: near-pure white
	title_settings.font_color = Color(0.98, 0.98, 0.98, 1)
	# Darker shadow for better readability
	title_settings.shadow_color = Color(0, 0, 0, 0.5)
	title_settings.shadow_offset = Vector2(6, 6)
	title_settings.outline_color = Color(0, 0, 0, 0.28)
	title_settings.outline_size = 3
	title_label.label_settings = title_settings
	title_label.text = "SVEN KILLER"

func setup_buttons() -> void:
	# Buttons 15% bigger than before
	for button in [new_game_button, settings_button]:
		button.add_theme_font_override("font", roboto_condensed_font)
		button.add_theme_font_size_override("font_size", 34)
		button.clip_text = false
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Soft outline + bold shadow + consistent color
		button.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98, 1))
		button.add_theme_color_override("font_hover_color", Color(0.98, 0.98, 0.98, 1))
		button.add_theme_color_override("font_focus_color", Color(0.98, 0.98, 0.98, 1))
		button.add_theme_color_override("font_pressed_color", Color(0.98, 0.98, 0.98, 1))
		button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		button.add_theme_constant_override("shadow_offset_x", 8)
		button.add_theme_constant_override("shadow_offset_y", 8)
		# Remove outline - using shadow instead
		button.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
		button.add_theme_constant_override("outline_size", 0)

		# Create hover panel background
		var panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Create dark gray StyleBox for panel
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.0)  # Very dark gray (0.9 darkness), start transparent
		panel.add_theme_stylebox_override("panel", style)

		# Add panel as child BEFORE button (so it renders behind)
		button.get_parent().add_child(panel)
		button.get_parent().move_child(panel, button.get_index())

		hover_panels[button] = panel

		# Connect hover signals
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))
		button.pressed.connect(_on_button_pressed)

	menu_container.add_theme_constant_override("separation", 12)

	# Connect button actions
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

	# Defer panel sizing until layout is done
	await get_tree().process_frame
	_update_hover_panels()

func _update_hover_panels() -> void:
	for button in hover_panels.keys():
		var panel = hover_panels[button]
		var padding_left = 10
		var padding_right = 10
		var padding_vertical = 4
		panel.position = button.position - Vector2(padding_left, padding_vertical)
		panel.size = button.size + Vector2(padding_left + padding_right, padding_vertical * 2)

func setup_audio() -> void:
	# Assign to proper audio buses (created by SettingsManager autoload)
	ambient_player.bus = "SFX"
	music_player.bus = "Music"

	# Ambient - fade in from silence over 1.5 seconds, looping
	ambient_player.stream = ambient_audio
	ambient_player.volume_db = -60
	ambient_player.finished.connect(_on_ambient_finished)
	ambient_player.play()
	var ambient_tween = create_tween()
	ambient_tween.tween_property(ambient_player, "volume_db", ambient_volume_db, 1.5).set_ease(Tween.EASE_OUT)
	music_player.stream = music_audio
	music_delay_timer.timeout.connect(_on_music_timer_timeout)
	music_delay_timer.start()

func _on_ambient_finished() -> void:
	# Loop the ambient audio
	ambient_player.play()

func _on_button_hover(button: Button) -> void:
	if not hover_panels.has(button):
		return

	# Play hover sound (35% volume)
	AudioManager.play_sfx(AudioManager.AudioID.MENU_HOVER, linear_to_db(0.35))

	# Kill existing tween if any
	if hover_tweens.has(button) and hover_tweens[button] != null and hover_tweens[button].is_valid():
		hover_tweens[button].kill()

	var panel = hover_panels[button]
	var style = panel.get_theme_stylebox("panel")

	if style is StyleBoxFlat:
		var tween = create_tween()
		tween.tween_property(style, "bg_color:a", 0.45, 0.15).set_ease(Tween.EASE_OUT)
		hover_tweens[button] = tween

func _on_button_unhover(button: Button) -> void:
	if not hover_panels.has(button):
		return

	# Don't unhover if New Game is locked (during transition)
	if button == new_game_button and new_game_locked:
		return

	# Kill existing tween if any
	if hover_tweens.has(button) and hover_tweens[button] != null and hover_tweens[button].is_valid():
		hover_tweens[button].kill()

	var panel = hover_panels[button]
	var style = panel.get_theme_stylebox("panel")

	if style is StyleBoxFlat:
		var tween = create_tween()
		tween.tween_property(style, "bg_color:a", 0.0, 0.15).set_ease(Tween.EASE_IN)
		hover_tweens[button] = tween

func _on_button_pressed() -> void:
	# Play click sound (15% volume)
	AudioManager.play_sfx(AudioManager.AudioID.MENU_CLICK, linear_to_db(0.15))

func _on_new_game_pressed() -> void:
	# Lock the hover rectangle (prevent unhover)
	new_game_locked = true

	# Ensure hover panel stays at full opacity
	if hover_panels.has(new_game_button):
		var panel = hover_panels[new_game_button]
		var style = panel.get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			# Kill any existing tween
			if hover_tweens.has(new_game_button) and hover_tweens[new_game_button] != null and hover_tweens[new_game_button].is_valid():
				hover_tweens[new_game_button].kill()
			# Set to full opacity
			style.bg_color.a = 0.45

	# NOTE: house preload moved to opening sequence (instantiate when voiceover ends)

	# Wait 0.85 seconds
	await get_tree().create_timer(0.85).timeout

	# Stop all audio and video immediately at 0.85s
	ambient_player.stop()
	music_player.stop()
	background_video.stop()
	background_video.visible = false

	# Hide dust particles
	var dust_particles = get_node_or_null("DustParticles")
	if dust_particles:
		dust_particles.emitting = false
		dust_particles.visible = false

	# Hide the white video shader overlay (this was causing the flash!)
	var shader_overlay = get_node_or_null("VideoShaderOverlay")
	if shader_overlay:
		shader_overlay.visible = false

	# Instant black overlay (giant black box covering everything)
	var black_overlay = ColorRect.new()
	black_overlay.color = Color(0, 0, 0, 1)
	black_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_overlay.z_index = 10000  # Extremely high z-index to ensure it's on top
	add_child(black_overlay)

	# Wait longer before scene change (0.45s more, total 1.3s from click)
	await get_tree().create_timer(0.45).timeout

	# Now change scenes (everything is already black, no flash possible)
	get_tree().change_scene_to_file("res://scenes/gameplay/opening_sequence.tscn")

func _on_music_timer_timeout() -> void:
		music_player.volume_db = -60
		music_player.play()
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", music_volume_db, 10.0).set_ease(Tween.EASE_IN)

func _on_settings_pressed() -> void:
	if settings_overlay != null:
		return
	var settings_scene: PackedScene = load("res://scenes/ui/settings_menu.tscn")
	settings_overlay = settings_scene.instantiate()
	settings_overlay.closed.connect(_on_settings_closed)
	add_child(settings_overlay)
	new_game_button.disabled = true
	settings_button.disabled = true


func _on_settings_closed() -> void:
	settings_overlay = null
	new_game_button.disabled = false
	settings_button.disabled = false


func setup_vignette() -> void:
	var shader_code = """
shader_type canvas_item;

void fragment() {
	// Stronger, wider gradient from left
	float grad = smoothstep(0.0, 0.8, UV.x);
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - grad) * 0.88);
}
"""
	var shader = Shader.new()
	shader.code = shader_code
	var material = ShaderMaterial.new()
	material.shader = shader
	left_vignette.material = material
