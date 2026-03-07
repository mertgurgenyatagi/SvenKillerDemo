extends Node

## Centralized audio management system.
## Handles all audio playback with configurable settings from audio_config.tres.
##
## Usage:
##   AudioManager.play_sfx(AudioManager.AudioID.MENU_HOVER)
##   AudioManager.play_3d_sfx(AudioManager.AudioID.FOOTSTEP_WOOD_1, player.global_position)
##   var stream = AudioManager.get_audio_stream(AudioManager.AudioID.HOUSE_HUM)

enum AudioID {
	# UI / Menu
	MENU_HOVER,
	MENU_CLICK,

	# Ambient
	AMBIENT_MAIN_MENU,
	MUSIC_MAIN,
	NOE_PROMPT,
	HOUSE_HUM,
	AMB_RAIN,

	# Footsteps
	FOOTSTEP_WOOD_1,
	FOOTSTEP_WOOD_2,
	FOOTSTEP_WOOD_3,
	FOOTSTEP_WOOD_4,
	FOOTSTEP_WOOD_5,
	FOOTSTEP_WOOD_6,
	FOOTSTEP_WOOD_7,

	# Footsteps (sand)
	FOOTSTEP_SAND_1,
	FOOTSTEP_SAND_2,
	FOOTSTEP_SAND_3,
	FOOTSTEP_SAND_4,
	FOOTSTEP_SAND_5,
	FOOTSTEP_SAND_6,
	FOOTSTEP_SAND_7,

	# Interactions
	PHONE_BUTTON_PRESS,
	VOICEMAIL,
	LIGHTSWITCH,
}

# Preloaded const forces audio_config.tres + its scripts into the export PCK.
# load(variable) is invisible to the export scanner; preload(literal) is not.
const _AUDIO_CONFIG_PRELOADED: AudioConfig = preload("res://resources/audio_config.tres")
var config: AudioConfig = null

# Audio library (preloaded/cached streams)
var _audio_library: Dictionary = {}

# Player pools (reusable instances)
var _player_2d_pool: Array[AudioStreamPlayer] = []
var _player_3d_pool: Array[AudioStreamPlayer3D] = []
const POOL_SIZE: int = 8  # Max concurrent sounds per type


func _ready() -> void:
	print("[AudioManager] _ready() start")
	_load_config()
	_load_audio_library()
	_create_player_pools()
	_setup_standard_buses()
	_setup_noe_prompt_bus()
	_setup_house_exterior_bus()
	print("[AudioManager] _ready() done — library size: %d, bus count: %d" % [_audio_library.size(), AudioServer.bus_count])
	for i in AudioServer.bus_count:
		print("  bus[%d] = '%s'" % [i, AudioServer.get_bus_name(i)])


func _setup_standard_buses() -> void:
	## Create SFX / Music / Voice / Ambient buses if they don't exist.
	## In exported builds there is no default_bus_layout file, so only Master exists.
	var needed: PackedStringArray = ["SFX", "Music", "Voice", "Ambient"]
	for bus_name in needed:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx: int = AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _setup_house_exterior_bus() -> void:
	## Low-pass filtered bus for exterior sounds heard through house walls.
	if AudioServer.get_bus_index("HouseExterior") != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, "HouseExterior")
	AudioServer.set_bus_send(idx, "Master")
	# Low-pass filter: walls block high frequencies (cutoff ~800 Hz)
	var lpf := AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 800.0
	lpf.resonance = 0.3
	AudioServer.add_bus_effect(idx, lpf)
	# Overall bus attenuation on top of per-sound volumes
	AudioServer.set_bus_volume_db(idx, -4.0)


func _setup_noe_prompt_bus() -> void:
	## Create a dedicated "NoePrompt" audio bus with reverb if it doesn't exist.
	## Using a separate bus keeps the reverb isolated from other SFX.
	if AudioServer.get_bus_index("NoePrompt") != -1:
		return  # Already configured (e.g., via project bus layout)
	AudioServer.add_bus()
	var idx: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, "NoePrompt")
	AudioServer.set_bus_send(idx, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.3
	reverb.damping = 0.8
	reverb.spread = 0.5
	reverb.wet = 0.12
	reverb.dry = 1.0
	AudioServer.add_bus_effect(idx, reverb)


func _load_config() -> void:
	config = _AUDIO_CONFIG_PRELOADED
	if config:
		print("[AudioManager] config loaded OK — %d entries" % config.entries.size())
	else:
		push_error("[AudioManager] audio_config.tres preload returned null — all volume/bus settings will use fallbacks")
		config = AudioConfig.new()


func _load_audio_library() -> void:
	# Pre-populate library with every stream via preload() literals.
	# This is the ONLY way the Godot export scanner detects .ogg files:
	# load(variable) is invisible; only literal preload() / load("string") are scanned.
	var _preloads: Dictionary = {
		AudioID.MENU_HOVER:         preload("res://assets/audio/sfx/interactions/menu_hover.ogg"),
		AudioID.MENU_CLICK:         preload("res://assets/audio/sfx/interactions/menu_click.ogg"),
		AudioID.AMBIENT_MAIN_MENU:  preload("res://assets/audio/sfx/ambient/ambient_main_menu.ogg"),
		AudioID.MUSIC_MAIN:         preload("res://assets/audio/music/sven_killer.ogg"),
		AudioID.NOE_PROMPT:         preload("res://assets/audio/sfx/interactions/noe_prompt_sfx.ogg"),
		AudioID.HOUSE_HUM:          preload("res://assets/audio/sfx/ambient/house_hum.ogg"),
		AudioID.AMB_RAIN:           preload("res://assets/audio/sfx/ambient/amb_rain.ogg"),
		AudioID.FOOTSTEP_WOOD_1:    preload("res://assets/audio/sfx/footsteps/wood_footstep_1.ogg"),
		AudioID.FOOTSTEP_WOOD_2:    preload("res://assets/audio/sfx/footsteps/wood_footstep_2.ogg"),
		AudioID.FOOTSTEP_WOOD_3:    preload("res://assets/audio/sfx/footsteps/wood_footstep_3.ogg"),
		AudioID.FOOTSTEP_WOOD_4:    preload("res://assets/audio/sfx/footsteps/wood_footstep_4.ogg"),
		AudioID.FOOTSTEP_WOOD_5:    preload("res://assets/audio/sfx/footsteps/wood_footstep_5.ogg"),
		AudioID.FOOTSTEP_WOOD_6:    preload("res://assets/audio/sfx/footsteps/wood_footstep_6.ogg"),
		AudioID.FOOTSTEP_WOOD_7:    preload("res://assets/audio/sfx/footsteps/wood_footstep_7.ogg"),
		AudioID.FOOTSTEP_SAND_1:    preload("res://assets/audio/sfx/footsteps/sand_footstep_1.ogg"),
		AudioID.FOOTSTEP_SAND_2:    preload("res://assets/audio/sfx/footsteps/sand_footstep_2.ogg"),
		AudioID.FOOTSTEP_SAND_3:    preload("res://assets/audio/sfx/footsteps/sand_footstep_3.ogg"),
		AudioID.FOOTSTEP_SAND_4:    preload("res://assets/audio/sfx/footsteps/sand_footstep_4.ogg"),
		AudioID.FOOTSTEP_SAND_5:    preload("res://assets/audio/sfx/footsteps/sand_footstep_5.ogg"),
		AudioID.FOOTSTEP_SAND_6:    preload("res://assets/audio/sfx/footsteps/sand_footstep_6.ogg"),
		AudioID.FOOTSTEP_SAND_7:    preload("res://assets/audio/sfx/footsteps/sand_footstep_7.ogg"),
		AudioID.PHONE_BUTTON_PRESS: preload("res://assets/audio/sfx/interactions/phone_button_press_sfx.ogg"),
		AudioID.VOICEMAIL:          preload("res://assets/audio/voiceover/voicemail.ogg"),
		AudioID.LIGHTSWITCH:        preload("res://assets/audio/sfx/interactions/lightswitch_sfx.ogg"),
	}
	for id in _preloads:
		_audio_library[id] = _preloads[id]


func _create_player_pools() -> void:
	# Create reusable 2D players
	for i in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "AudioPool2D_%d" % i
		add_child(player)
		_player_2d_pool.append(player)

	# Create reusable 3D players
	for i in POOL_SIZE:
		var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		player.name = "AudioPool3D_%d" % i
		add_child(player)
		_player_3d_pool.append(player)


## Play 2D sound effect (non-spatial, UI/ambient).
## Returns the AudioStreamPlayer instance (null if unavailable).
## volume_override: Optional volume in dB (-80 to +24). Pass -999.0 to use config default.
func play_sfx(audio_id: AudioID, volume_override: float = -999.0) -> AudioStreamPlayer:
	var entry: AudioEntry = _get_entry(audio_id)
	if not entry:
		return null

	if entry.spatial:
		push_error("AudioManager: AudioID %d is spatial, use play_3d_sfx()" % audio_id)
		return null

	var stream: AudioStream = _get_audio_stream(audio_id, entry)
	if not stream:
		return null

	var player: AudioStreamPlayer = _get_available_2d_player()
	if not player:
		push_warning("AudioManager: All 2D audio players busy for AudioID %d" % audio_id)
		return null

	player.stream = stream
	player.bus = entry.bus
	player.volume_db = volume_override if volume_override > -999.0 else entry.volume_db
	player.pitch_scale = entry.pitch_scale
	player.play()
	return player


## Play 3D spatial sound effect.
## Returns the AudioStreamPlayer3D instance (null if unavailable).
## position: Global 3D position for the sound.
## volume_override: Optional volume in dB. Pass -999.0 to use config default.
func play_3d_sfx(audio_id: AudioID, position: Vector3, volume_override: float = -999.0) -> AudioStreamPlayer3D:
	var entry: AudioEntry = _get_entry(audio_id)
	if not entry:
		return null

	if not entry.spatial:
		push_error("AudioManager: AudioID %d is not spatial, use play_sfx()" % audio_id)
		return null

	var stream: AudioStream = _get_audio_stream(audio_id, entry)
	if not stream:
		return null

	var player: AudioStreamPlayer3D = _get_available_3d_player()
	if not player:
		push_warning("AudioManager: All 3D audio players busy for AudioID %d" % audio_id)
		return null

	player.stream = stream
	player.bus = entry.bus
	player.volume_db = volume_override if volume_override > -999.0 else entry.volume_db
	player.pitch_scale = entry.pitch_scale
	player.max_distance = entry.max_distance
	player.global_position = position
	player.play()
	return player


## Get audio stream directly (for manual player setup, e.g., looping ambient).
## Returns AudioStream or null if not found.
func get_audio_stream(audio_id: AudioID) -> AudioStream:
	var entry: AudioEntry = _get_entry(audio_id)
	if not entry:
		return null
	return _get_audio_stream(audio_id, entry)


## Get entry config for an audio ID.
## Returns a fallback entry if config is missing so audio still plays.
func _get_entry(audio_id: AudioID) -> AudioEntry:
	if config and config.entries.has(audio_id):
		return config.entries[audio_id]
	# Config missing or ID not found — build a minimal fallback entry so the
	# preloaded stream can still play.  Spatial IDs get a 3D fallback.
	var spatial_ids: Array = [
		AudioID.FOOTSTEP_WOOD_1, AudioID.FOOTSTEP_WOOD_2, AudioID.FOOTSTEP_WOOD_3,
		AudioID.FOOTSTEP_WOOD_4, AudioID.FOOTSTEP_WOOD_5, AudioID.FOOTSTEP_WOOD_6,
		AudioID.FOOTSTEP_WOOD_7, AudioID.FOOTSTEP_SAND_1, AudioID.FOOTSTEP_SAND_2,
		AudioID.FOOTSTEP_SAND_3, AudioID.FOOTSTEP_SAND_4, AudioID.FOOTSTEP_SAND_5,
		AudioID.FOOTSTEP_SAND_6, AudioID.FOOTSTEP_SAND_7,
		AudioID.PHONE_BUTTON_PRESS, AudioID.VOICEMAIL, AudioID.LIGHTSWITCH,
	]
	var fallback := AudioEntry.new()
	fallback.volume_db = 0.0
	fallback.pitch_scale = 1.0
	fallback.max_distance = 20.0
	fallback.spatial = audio_id in spatial_ids
	fallback.bus = "SFX"
	push_warning("[AudioManager] No config entry for AudioID %d — using fallback (0 dB, SFX bus)" % audio_id)
	return fallback


## Get audio stream from library or load on-demand.
func _get_audio_stream(audio_id: AudioID, entry: AudioEntry) -> AudioStream:
	# Check library first (preloaded or cached)
	if _audio_library.has(audio_id):
		return _audio_library[audio_id]

	# Load on-demand
	if not FileAccess.file_exists(entry.path):
		push_error("AudioManager: Audio file not found: %s" % entry.path)
		return null

	var stream: AudioStream = load(entry.path)
	if not stream:
		push_error("AudioManager: Failed to load audio: %s" % entry.path)
		return null

	# Cache for future use
	_audio_library[audio_id] = stream
	return stream


## Stop all pooled audio players immediately.
func stop_all() -> void:
	for player in _player_2d_pool:
		if player.playing:
			player.stop()
	for player in _player_3d_pool:
		if player.playing:
			player.stop()


## Get first available 2D player from pool.
func _get_available_2d_player() -> AudioStreamPlayer:
	for player in _player_2d_pool:
		if not player.playing:
			return player
	return null


## Get first available 3D player from pool.
func _get_available_3d_player() -> AudioStreamPlayer3D:
	for player in _player_3d_pool:
		if not player.playing:
			return player
	return null
