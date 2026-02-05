extends Node

## Manages all game settings: state, persistence via ConfigFile, and engine application.

signal settings_changed
signal settings_loaded

# --- Constants ---

const SETTINGS_PATH: String = "user://settings.cfg"

const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_VOICE: String = "Voice"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const RESOLUTION_LABELS: Array[String] = [
	"1280 x 720",
	"1366 x 768",
	"1600 x 900",
	"1920 x 1080",
	"2560 x 1440",
	"3840 x 2160",
]

const FPS_LIMIT_OPTIONS: Array[int] = [0, 30, 60, 120, 144, 240]
const FPS_LIMIT_LABELS: Array[String] = ["Unlimited", "30", "60", "120", "144", "240"]

const LANGUAGE_CODES: Array[String] = ["sv", "en", "es", "zh", "fr", "de", "tr"]
const LANGUAGE_LABELS: Array[String] = ["Svenska", "English", "Español", "中文", "Français", "Deutsch", "Türkçe"]

const SUBTITLE_SIZE_LABELS: Array[String] = ["Small", "Medium", "Large"]
const SUBTITLE_SIZE_VALUES: Array[int] = [18, 24, 32]

const AA_LABELS: Array[String] = ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "MSAA 8x"]
const ANISO_LABELS: Array[String] = ["1x (Off)", "2x", "4x", "8x", "16x"]
const ANISO_VALUES: Array[int] = [1, 2, 4, 8, 16]

const DISPLAY_MODE_LABELS: Array[String] = ["Fullscreen", "Windowed", "Borderless Windowed"]
const DISPLAY_MODE_VALUES: Array[int] = [
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
]

# Single source of truth for all default values
const DEFAULTS: Dictionary = {
	# Video
	"video/display_mode": DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	"video/resolution_index": 3,  # 1920x1080
	"video/vsync": true,
	"video/fps_limit": 0,
	"video/brightness": 1.0,
	# Graphics
	"graphics/anti_aliasing": 2,  # MSAA 2x
	"graphics/anisotropic_filtering": 4,
	# Audio (linear 0.0 - 1.0)
	"audio/master_volume": 1.0,
	"audio/music_volume": 0.8,
	"audio/sfx_volume": 1.0,
	"audio/voice_volume": 1.0,
	# Subtitles
	"subtitles/enabled": true,
	"subtitles/language": "sv",
	"subtitles/text_size": 1,
}

# --- Runtime State ---

var current_settings: Dictionary = {}
var _config: ConfigFile = null
var _brightness_layer: CanvasLayer = null
var _brightness_rect: ColorRect = null


func _ready() -> void:
	_setup_audio_buses()
	_setup_brightness_overlay()
	_config = ConfigFile.new()
	load_settings()
	apply_all_settings()


# --- Audio Bus Setup ---

func _setup_audio_buses() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_VOICE)


func _ensure_bus(bus_name: String) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, BUS_MASTER)


# --- Brightness Overlay ---

func _setup_brightness_overlay() -> void:
	_brightness_layer = CanvasLayer.new()
	_brightness_layer.layer = 99
	_brightness_layer.name = "BrightnessOverlay"

	_brightness_rect = ColorRect.new()
	_brightness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brightness_rect.color = Color(0, 0, 0, 0)

	var shader: Shader = Shader.new()
	shader.code = "shader_type canvas_item;\nuniform float brightness : hint_range(0.5, 1.5) = 1.0;\nvoid fragment() {\n\tfloat dark = clamp(1.0 - brightness, 0.0, 1.0);\n\tCOLOR = vec4(0.0, 0.0, 0.0, dark);\n}\n"
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	_brightness_rect.material = mat

	_brightness_layer.add_child(_brightness_rect)
	add_child(_brightness_layer)


# --- Load / Save / Reset ---

func load_settings() -> void:
	current_settings = DEFAULTS.duplicate(true)

	var err: Error = _config.load(SETTINGS_PATH)
	if err != OK:
		settings_loaded.emit()
		return

	for key in DEFAULTS.keys():
		var parts: PackedStringArray = key.split("/")
		var section: String = parts[0]
		var property: String = parts[1]
		if _config.has_section_key(section, property):
			current_settings[key] = _config.get_value(section, property)

	settings_loaded.emit()


func save_settings() -> void:
	for key in current_settings.keys():
		var parts: PackedStringArray = key.split("/")
		var section: String = parts[0]
		var property: String = parts[1]
		_config.set_value(section, property, current_settings[key])
	_config.save(SETTINGS_PATH)


func reset_to_defaults() -> void:
	current_settings = DEFAULTS.duplicate(true)
	apply_all_settings()
	save_settings()
	settings_changed.emit()


# --- Getters / Setters ---

func get_setting(key: String) -> Variant:
	if current_settings.has(key):
		return current_settings[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	push_warning("SettingsManager: Unknown setting key: " + key)
	return null


func set_setting(key: String, value: Variant) -> void:
	current_settings[key] = value
	_apply_setting(key, value)
	settings_changed.emit()


# --- Apply Settings to Engine ---

func apply_all_settings() -> void:
	for key in current_settings.keys():
		_apply_setting(key, current_settings[key])


func _apply_setting(key: String, value: Variant) -> void:
	match key:
		"video/display_mode":
			_apply_display_mode(value as int)
		"video/resolution_index":
			_apply_resolution(value as int)
		"video/vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)
		"video/fps_limit":
			Engine.max_fps = value as int
		"video/brightness":
			_apply_brightness(value as float)
		"graphics/anti_aliasing":
			_apply_anti_aliasing(value as int)
		"graphics/anisotropic_filtering":
			_apply_anisotropic_filtering(value as int)
		"audio/master_volume":
			_set_bus_volume(BUS_MASTER, value as float)
		"audio/music_volume":
			_set_bus_volume(BUS_MUSIC, value as float)
		"audio/sfx_volume":
			_set_bus_volume(BUS_SFX, value as float)
		"audio/voice_volume":
			_set_bus_volume(BUS_VOICE, value as float)
		"subtitles/enabled", "subtitles/language", "subtitles/text_size":
			pass  # Consumed via get_setting() by subtitle system later


func _apply_display_mode(mode: int) -> void:
	DisplayServer.window_set_mode(mode)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		_apply_resolution(current_settings.get("video/resolution_index", 3) as int)
		# Center window
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var window_size: Vector2i = DisplayServer.window_get_size()
		DisplayServer.window_set_position((screen_size - window_size) / 2)


func _apply_resolution(index: int) -> void:
	index = clampi(index, 0, RESOLUTIONS.size() - 1)
	var res: Vector2i = RESOLUTIONS[index]
	var current_mode: int = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(res)


func _apply_brightness(value: float) -> void:
	if _brightness_rect and _brightness_rect.material:
		var mat: ShaderMaterial = _brightness_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("brightness", value)


func _apply_anti_aliasing(mode: int) -> void:
	var viewport: Viewport = get_viewport()
	if not viewport:
		return
	match mode:
		0:  # Off
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		1:  # FXAA
			viewport.msaa_3d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		2:  # MSAA 2x
			viewport.msaa_3d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		3:  # MSAA 4x
			viewport.msaa_3d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		4:  # MSAA 8x
			viewport.msaa_3d = Viewport.MSAA_8X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED


func _apply_anisotropic_filtering(level: int) -> void:
	ProjectSettings.set_setting(
		"rendering/textures/default_filters/anisotropic_filtering_level", level
	)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))
