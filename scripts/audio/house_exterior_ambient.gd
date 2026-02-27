class_name HouseExteriorAmbient
extends Node

## Ambient exterior audio for the house scene.
## Simulates rain, occasional passing cars, and distant NPC chatter
## as heard through walls — muted and low-pass filtered via the HouseExterior bus.
##
## Lifecycle controlled by sven_house_boot.gd:
##   - Rain player is in "house_ambient_audio" group → boot script pauses/resumes it
##   - This node is in "house_ambient_scripts" group → boot script calls start()

const _RAIN: AudioStream = preload("res://assets/audio/sfx/ambient/amb_rain.ogg")

const _CAR_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/vehicles/car_pass_by_01.ogg"),
	preload("res://assets/audio/sfx/vehicles/car_pass_by_02.ogg"),
	preload("res://assets/audio/sfx/vehicles/car_pass_by_03.ogg"),
]

const _CHATTER_STREAMS: Array[AudioStream] = [
	preload("res://assets/audio/sfx/npc/npc_audio_friends.ogg"),
	preload("res://assets/audio/sfx/npc/npc_audio_group.ogg"),
	preload("res://assets/audio/sfx/npc/npc_audio_phone_guy.ogg"),
]

# Intervals in seconds
const CAR_INTERVAL_MIN: float = 12.0
const CAR_INTERVAL_MAX: float = 18.0
const CHATTER_INTERVAL_MIN: float = 30.0
const CHATTER_INTERVAL_MAX: float = 50.0

# Volumes — all on HouseExterior bus which applies further low-pass + attenuation
const RAIN_DB: float = -18.0
const CAR_DB: float = -22.0
const CHATTER_DB: float = -28.0

var _rain_player: AudioStreamPlayer = null
var _car_timer: Timer = null
var _chatter_timer: Timer = null
var _started: bool = false


func _ready() -> void:
	add_to_group("house_ambient_scripts")
	_build_rain_player()
	_build_timers()


func _build_rain_player() -> void:
	_rain_player = AudioStreamPlayer.new()
	_rain_player.stream = _RAIN
	_rain_player.bus = "HouseExterior"
	_rain_player.volume_db = RAIN_DB
	# Boot script manages play/stop via "house_ambient_audio" group
	_rain_player.add_to_group("house_ambient_audio")
	add_child(_rain_player)


func _build_timers() -> void:
	_car_timer = Timer.new()
	_car_timer.one_shot = true
	_car_timer.timeout.connect(_on_car_timer)
	add_child(_car_timer)

	_chatter_timer = Timer.new()
	_chatter_timer.one_shot = true
	_chatter_timer.timeout.connect(_on_chatter_timer)
	add_child(_chatter_timer)


func start() -> void:
	## Called by sven_house_boot._start_ambient_audio() when the scene becomes active.
	if _started:
		return
	_started = true
	if not _rain_player.playing:
		_rain_player.play()
	_schedule_car()
	_schedule_chatter()


# ── Car sounds ─────────────────────────────────────────────────────────────────

func _schedule_car() -> void:
	_car_timer.start(randf_range(CAR_INTERVAL_MIN, CAR_INTERVAL_MAX))


func _on_car_timer() -> void:
	_play_one_shot(_CAR_STREAMS[randi() % _CAR_STREAMS.size()], CAR_DB)
	_schedule_car()


# ── NPC chatter ────────────────────────────────────────────────────────────────

func _schedule_chatter() -> void:
	_chatter_timer.start(randf_range(CHATTER_INTERVAL_MIN, CHATTER_INTERVAL_MAX))


func _on_chatter_timer() -> void:
	_play_one_shot(_CHATTER_STREAMS[randi() % _CHATTER_STREAMS.size()], CHATTER_DB)
	_schedule_chatter()


# ── Shared helper ──────────────────────────────────────────────────────────────

func _play_one_shot(stream: AudioStream, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "HouseExterior"
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
