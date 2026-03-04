extends Node3D

## Cafe scene boot.
## sven_sitting.fbx and elise_sitting.fbx are pre-posed with sitting_idle baked in.
## Only movement needs to be disabled; mouse look remains active.

@onready var player: Node3D = $Player
@onready var npc_elise: Node3D = $npc_elise


func _ready() -> void:
	# Disable movement — camera rotation (_input) stays active
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)

	_play_first_animation(player)
	_play_first_animation(npc_elise)
	_start_ambient_audio()
	# Begin cinema preload 1 second after cafe loads — dialogue runs ~52s so
	# this gives ~51 seconds of background load time before the hard cut.
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		GameManager.start_background_preload("res://scenes/cinema_interior.tscn")
		# Penulti preload runs concurrently — gives it the full cafe + cinema window
		# (~63 s) before the cinema hard cut, well above the 20-second minimum.
		ResourceLoader.load_threaded_request("res://scenes/penulti.tscn", "", false)
	)


func _start_ambient_audio() -> void:
	_setup_rain_bus()

	var tracks: Array[Dictionary] = [
		{"path": "res://assets/audio/sfx/ambient/amb_cafe.ogg",       "bus": "Ambient",     "volume_db":  1.2},
		{"path": "res://assets/audio/sfx/ambient/amb_rain.ogg",        "bus": "RainMuffled", "volume_db": -22.0},
		{"path": "res://assets/audio/sfx/ambient/amb_cafe_music.ogg",  "bus": "Music",       "volume_db": -10.5},
	]
	for track in tracks:
		var stream := load(track["path"]) as AudioStreamOggVorbis
		if stream == null:
			push_warning("cafe_boot: could not load %s" % track["path"])
			continue
		stream.loop = true
		var player_node := AudioStreamPlayer.new()
		player_node.stream = stream
		player_node.bus = track["bus"]
		player_node.volume_db = track["volume_db"]
		add_child(player_node)
		player_node.play()


func _setup_rain_bus() -> void:
	# Temporary bus that muffles outdoor rain as heard through cafe walls/windows
	if AudioServer.get_bus_index("RainMuffled") != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "RainMuffled")
	AudioServer.set_bus_send(idx, "Master")
	var lpf := AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 700.0
	lpf.resonance = 0.3
	AudioServer.add_bus_effect(idx, lpf)


func _play_first_animation(character: Node3D) -> void:
	var anim_player: AnimationPlayer = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		push_warning("cafe_boot: no AnimationPlayer found under %s" % character.name)
		return
	var list: PackedStringArray = anim_player.get_animation_list()
	print("cafe_boot: %s animations = %s" % [character.name, list])
	if list.is_empty():
		return
	# mixamo_com is the sitting animation on both FBX files
	var target: String = list[0]
	for anim_name in list:
		if anim_name == "mixamo_com":
			target = anim_name
			break
	print("cafe_boot: playing '%s' on %s" % [target, character.name])
	anim_player.play(target)
