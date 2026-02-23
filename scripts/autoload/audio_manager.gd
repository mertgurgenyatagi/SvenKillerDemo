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

	# Footsteps
	FOOTSTEP_WOOD_1,
	FOOTSTEP_WOOD_2,
	FOOTSTEP_WOOD_3,
	FOOTSTEP_WOOD_4,
	FOOTSTEP_WOOD_5,
	FOOTSTEP_WOOD_6,
	FOOTSTEP_WOOD_7,

	# Interactions
	PHONE_BUTTON_PRESS,
	VOICEMAIL,
	LIGHTSWITCH,
}

# Configuration (loaded in _ready() to avoid parse errors if file doesn't exist yet)
var config: AudioConfig = null

# Audio library (preloaded/cached streams)
var _audio_library: Dictionary = {}

# Player pools (reusable instances)
var _player_2d_pool: Array[AudioStreamPlayer] = []
var _player_3d_pool: Array[AudioStreamPlayer3D] = []
const POOL_SIZE: int = 8  # Max concurrent sounds per type


func _ready() -> void:
	_load_config()
	_load_audio_library()
	_create_player_pools()


func _load_config() -> void:
	var config_path: String = "res://resources/audio_config.tres"
	if FileAccess.file_exists(config_path):
		config = load(config_path)
	else:
		push_warning("AudioManager: audio_config.tres not found, using empty config")
		config = AudioConfig.new()


func _load_audio_library() -> void:
	if not config:
		return

	# Preload audio marked for startup
	for audio_id in config.entries.keys():
		var entry: AudioEntry = config.entries[audio_id]
		if entry.preload_on_startup and FileAccess.file_exists(entry.path):
			var stream: AudioStream = load(entry.path)
			if stream:
				_audio_library[audio_id] = stream


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
func _get_entry(audio_id: AudioID) -> AudioEntry:
	if not config or not config.entries.has(audio_id):
		push_error("AudioManager: Unknown audio ID: %d" % audio_id)
		return null
	return config.entries[audio_id]


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
