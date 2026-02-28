extends Node3D

## Cinema scene boot.
## npc_sitting_1.glb and npc_sitting_2.glb are Sketchfab models with sitting poses baked in.
## Play their first animation on ready so the pose is applied.

@onready var _npcs: Array[Node3D] = [
	$Player,
	$CinemaParent/npc_sitting_1,
	$CinemaParent/npc_sitting_2,
	$CinemaParent/npc_sitting_3,
	$CinemaParent/npc_sitting_5,
	$CinemaParent/npc_sitting_7,
	$CinemaParent/npc_sitting_8,
	$CinemaParent/npc_sitting_9,
	$CinemaParent/npc_sitting_10,
	$CinemaParent/npc_sitting_11,
	$CinemaParent/npc_sitting_14,
	$CinemaParent/npc_sitting_15,
	$CinemaParent/npc_sitting_16,
]


# These NPCs are locked to the first frame rather than playing the full animation.
const _FREEZE_NPCS: Array[StringName] = [&"npc_sitting_3", &"npc_sitting_10", &"npc_sitting_16"]

var _projector: SpotLight3D = null
var _noise: FastNoiseLite = null


func _ready() -> void:
	for npc in _npcs:
		_play_first_animation(npc, npc.name in _FREEZE_NPCS)
	_make_screen_emissive()
	_start_ambient_audio()
	_projector = find_child("ProjectorLight", true, false) as SpotLight3D
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = randi()


func _process(_delta: float) -> void:
	# Projector light flickers in sync with the screen shader (which drives its own flicker via TIME).
	if _noise == null or not is_instance_valid(_projector):
		return
	var t: float = Time.get_ticks_msec() / 1000.0 * 12.0
	var n: float = _noise.get_noise_1d(t)  # -1.0 .. 1.0
	_projector.light_energy = 4.25 + n * 2.5


func _start_ambient_audio() -> void:
	# CinemaFilm bus: low-pass filter so the movie sounds like it's behind the screen.
	if AudioServer.get_bus_index("CinemaFilm") == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "CinemaFilm")
		AudioServer.set_bus_send(idx, "Master")
		var lpf := AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 2200.0
		lpf.resonance = 0.5
		AudioServer.add_bus_effect(idx, lpf)

	var tracks: Array[Dictionary] = [
		{"path": "res://assets/audio/sfx/ambient/amb_cinema_ambience.ogg", "bus": "Ambient",    "volume_db":  0.0},
		{"path": "res://assets/audio/sfx/ambient/amb_cinema_film.ogg",     "bus": "CinemaFilm", "volume_db": -14.0},
	]
	for track in tracks:
		var stream := load(track["path"]) as AudioStreamOggVorbis
		if stream == null:
			push_warning("cinema_boot: could not load %s" % track["path"])
			continue
		stream.loop = true
		var player_node := AudioStreamPlayer.new()
		player_node.stream = stream
		player_node.bus = track["bus"]
		player_node.volume_db = track["volume_db"]
		add_child(player_node)
		player_node.play()


func _make_screen_emissive() -> void:
	var box := find_child("ScreenBox", true, false) as CSGBox3D
	if not box:
		push_warning("cinema_boot: ScreenBox not found")
		return
	var shader := load("res://assets/shaders/cinema_screen.gdshader") as Shader
	if not shader:
		push_warning("cinema_boot: cinema_screen.gdshader not found")
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	box.material = mat


func _play_first_animation(character: Node3D, freeze: bool = false) -> void:
	if not is_instance_valid(character):
		push_warning("cinema_boot: character node not found")
		return
	var anim_player: AnimationPlayer = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		push_warning("cinema_boot: no AnimationPlayer found under %s" % character.name)
		return
	var list: PackedStringArray = anim_player.get_animation_list()
	if list.is_empty():
		push_warning("cinema_boot: no animations on %s" % character.name)
		return
	# Prefer "mixamo_com" (Mixamo default export name), fall back to first available
	var target: String = list[0]
	for anim_name in list:
		if anim_name == "mixamo_com":
			target = anim_name
			break
	anim_player.play(target)
	if freeze:
		anim_player.seek(0.0, true)
		anim_player.pause()
