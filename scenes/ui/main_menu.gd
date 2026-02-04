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
var playfair_font: Font = preload("res://assets/fonts/playfair_display.ttf")

# Audio - loaded at runtime (needs Godot import first)
var ambient_audio: AudioStream
var music_audio: AudioStream

func _ready() -> void:
	# Load audio at runtime
	ambient_audio = load("res://assets/audio/sfx/ambient/ambient_main_menu.ogg")
	music_audio = load("res://assets/audio/music/sven_killer.ogg")
	
	setup_vignette()
	setup_video()
	setup_title()
	setup_buttons()
	setup_audio()

func setup_video() -> void:
	background_video.stream = load("res://assets/video/menu/main_menu.ogv")
	background_video.modulate = Color(0.35, 0.33, 0.38, 1.0)  # Cool, desaturated, dark
	background_video.play()

func setup_title() -> void:
	# Stark, imposing title - all caps feeling without being all caps
	var title_settings = LabelSettings.new()
	title_settings.font = fjalla_font
	title_settings.font_size = 160
	# Pale, almost ghostly white with slight
	title_settings.font_color = Color(1.0, 1.0, 1.0, 1.0)  # Pure white
	# Strong shadow for contrast
	title_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.9)
	title_settings.shadow_offset = Vector2(4, 6)
	# Add outline for extra readability
	title_settings.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	title_settings.outline_size = 3
	title_label.label_settings = title_settings
	title_label.text = "SVEN KILLER"  # All caps for impact

func setup_buttons() -> void:
	# Buttons 15% bigger than before
	for button in [new_game_button, settings_button]:
		button.add_theme_font_override("font", playfair_font)
		button.add_theme_font_size_override("font_size", 32)  # 15% bigger
		
		# Tight hit area - only the text, no padding
		button.clip_text = false
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		
		# Bright readable text
		button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
		button.add_theme_color_override("font_focus_color", Color(0.9, 0.9, 0.9, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
		
		# Shadow and outline for readability
		button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		button.add_theme_constant_override("shadow_offset_x", 2)
		button.add_theme_constant_override("shadow_offset_y", 3)
		button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		button.add_theme_constant_override("outline_size", 2)
		
		# Connect hover animations
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_unhover.bind(button))
	
	# Spacing
	menu_container.add_theme_constant_override("separation", 12)

func setup_audio() -> void:
	# Ambient - fade in slowly from silence, looping
	ambient_player.stream = ambient_audio
	ambient_player.volume_db = -80  # Start silent
	ambient_player.finished.connect(_on_ambient_finished)  # Manual loop
	ambient_player.play()
	
	# Fade in over 5 seconds to 8 dB
	var ambient_tween = create_tween()
	ambient_tween.tween_property(ambient_player, "volume_db", 8.0, 5.0).set_ease(Tween.EASE_OUT)
	
	# Music setup - starts after 30 seconds
	music_player.stream = music_audio
	music_delay_timer.timeout.connect(_on_music_timer_timeout)
	music_delay_timer.start()

func _on_ambient_finished() -> void:
	# Loop the ambient audio
	ambient_player.play()

func _on_button_hover(button: Button) -> void:
	var tween = create_tween().set_parallel(true)
	# Subtle rightward drift + slight scale
	tween.tween_property(button, "position:x", button.position.x + 12, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

func _on_button_unhover(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "position:x", button.position.x - 12, 0.2).set_ease(Tween.EASE_OUT)

func _on_music_timer_timeout() -> void:
	music_player.volume_db = -60
	music_player.play()
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -6, 10.0).set_ease(Tween.EASE_IN)

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
