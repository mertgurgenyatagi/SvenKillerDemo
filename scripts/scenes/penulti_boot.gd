extends Node3D

## Penulti scene boot.
##
## Two-phase initialisation:
##
##   LR (Load Ready) — starts immediately on scene load.
##   The player's input is suppressed (camera_cutscene_active = true).
##   A scripted camera sequence plays, ending with the player sitting on the bench.
##
##   LR timeline  (t = seconds after scene load)
##     t=0        LR Start — input blocked
##     t=2→3      Camera sweeps right 90° (yaw)
##     t=3→4      Pause
##     t=4→5      Camera tilts down ~10° (pitch)
##     t=5→6      Pause
##     t=6        E-key simulated — sitting sequence begins
##     t=6→11     5-second wait (animation runs in background)
##     t=11→12    Pause
##     t=12→14    Camera sweeps right 180° (yaw)
##     t=14→15    Pause
##     t=15       Game Ready declared
##
##   GR (Game Ready) — player regains input, audio starts, fade timers begin.
##   All timeline values below are GR-relative seconds.
##
## Transition strategy:
##   Phase 1 — t=14.14→52s: fog density ramps up until the scene is fully obscured.
##   Phase 2 — t=52→60s:    mesh transparency fades. Artifacts don't matter;
##                           fog covers everything by this point.
##   t=60s:                  CityMegaNode hidden, fog work done.
## - t=14.14–60s: street lamps fade to zero with 1% noise flicker.

const _FADE_START:      float = 14.14
const _FOG_END:         float = 52.0
const _FADE_END:        float = 60.0
const _FOG_MAX_DENSITY: float = 12.5

## Downward pitch delta applied during the LR sequence (radians).
const _LR_PITCH_DELTA: float = -0.1745  # ~10°

@onready var _characters: Array[Node3D] = [$CityMegaNode/npc_elise]
@onready var _player = $Player  # player_house.gd / player.gd — accessed via duck-typing

var _city_env: Environment = null

var _lamps: Array[OmniLight3D] = []
var _lamp_base_energies: Array[float] = []
var _noise: FastNoiseLite
var _start_time: float = 0.0
var _fade_done: bool   = false
var _game_ready: bool  = false


func _ready() -> void:
	for character in _characters:
		_play_first_animation(character)

	# Duplicate the city environment so fog tweening doesn't dirty the .tres resource.
	_city_env = $WorldEnvironmentCity.environment.duplicate() as Environment
	$WorldEnvironmentCity.environment = _city_env
	_city_env.fog_enabled = true
	_city_env.fog_density = 0.0
	_city_env.fog_aerial_perspective = 0.0

	# Exempt the armrest and lantern from fog so they stay crisp.
	var bench_root := $BenchParent/penulti_bench
	var fbx_root   := "Sketchfab_model/bdd4514fc2284e5299ff864f57e18f27_fbx/RootNode"
	var armrest := bench_root.get_node_or_null(fbx_root + "/bench_armrest_R/bench_armrest_R_Bench_0")
	var lantern  := bench_root.get_node_or_null(fbx_root + "/Lantern")
	_disable_fog_recursive($Player)
	if armrest:
		_disable_fog_recursive(armrest)
	if lantern:
		_disable_fog_recursive(lantern)

	for child in $CityMegaNode/StreetLamps.get_children():
		if child is OmniLight3D:
			_lamps.append(child as OmniLight3D)
			_lamp_base_energies.append((child as OmniLight3D).light_energy)

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.5
	_noise.seed = randi()

	_player.camera_cutscene_active = true
	_run_lr_sequence()


# ── LR sequence ────────────────────────────────────────────────────────────────

func _run_lr_sequence() -> void:
	# t=0  LR Start — input already blocked in _ready().

	# t=2→3  Camera sweeps right 90°.
	await get_tree().create_timer(2.0).timeout
	await _tween_yaw(PI / 2.0, 1.0)

	# t=3→4  Pause.
	await get_tree().create_timer(1.0).timeout

	# t=4→5  Camera tilts down ~10°.
	await _tween_pitch(_LR_PITCH_DELTA, 1.0)

	# t=5→6  Pause.
	await get_tree().create_timer(1.0).timeout

	# t=6  Simulate E-key — triggers the sitting sequence via physics_process.
	_player._handle_interact()

	# t=6→11  Wait 5 s (walk-to-seat + sit-down animation run in background).
	await get_tree().create_timer(5.0).timeout

	# t=11→12  Pause.
	await get_tree().create_timer(1.0).timeout

	# t=12→14  Camera sweeps right 180°.
	await _tween_yaw(-PI, 2.0)

	# t=14→15  Pause.
	await get_tree().create_timer(1.0).timeout

	# t=15  Game Ready.
	_declare_game_ready()


func _tween_yaw(delta_yaw: float, duration: float) -> void:
	## Smoothly adds delta_yaw (radians) to target_camera_yaw over duration seconds.
	var start_yaw: float = _player.target_camera_yaw
	var end_yaw: float   = start_yaw + delta_yaw
	var t0: float = Time.get_ticks_msec() / 1000.0
	while true:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - t0
		if elapsed >= duration:
			break
		_player.target_camera_yaw = lerpf(start_yaw, end_yaw, elapsed / duration)
		await get_tree().process_frame
	_player.target_camera_yaw = end_yaw


func _tween_pitch(delta_pitch: float, duration: float) -> void:
	## Smoothly adds delta_pitch (radians) to target_camera_pitch over duration seconds,
	## clamped to the player's configured pitch limits.
	var start_pitch: float = _player.target_camera_pitch
	var end_pitch: float = clampf(
		start_pitch + delta_pitch,
		deg_to_rad(_player.camera_min_pitch),
		deg_to_rad(_player.camera_max_pitch)
	)
	var t0: float = Time.get_ticks_msec() / 1000.0
	while true:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - t0
		if elapsed >= duration:
			break
		_player.target_camera_pitch = lerpf(start_pitch, end_pitch, elapsed / duration)
		await get_tree().process_frame
	_player.target_camera_pitch = end_pitch


func _declare_game_ready() -> void:
	# Return input control to the player.
	_player.camera_cutscene_active = false

	# Mark GR=t=0 for the fade system.
	_game_ready = true
	_start_time = Time.get_ticks_msec() / 1000.0

	# Start non-looping ambient audio.
	var stream := load("res://assets/audio/sfx/ambient/penulti_part_1.ogg") as AudioStreamOggVorbis
	if stream:
		stream.loop = false
		var audio := AudioStreamPlayer.new()
		audio.stream = stream
		audio.bus = "Ambient"
		add_child(audio)
		audio.play()


# ── Per-frame transition (GR-relative) ────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _game_ready or _fade_done:
		return

	var t: float = Time.get_ticks_msec() / 1000.0 - _start_time
	if t < _FADE_START:
		return

	# Phase 1: ramp fog density + aerial perspective until the scene is fully obscured.
	# aerial_perspective blends the background into the fog colour, eliminating silhouettes.
	var fog_t: float = clamp((t - _FADE_START) / (_FOG_END - _FADE_START), 0.0, 1.0)
	_city_env.fog_density             = pow(fog_t, 6.0) * _FOG_MAX_DENSITY
	_city_env.fog_aerial_perspective  = fog_t

	# Street lamps: fade energy + 1% noise flicker over the full duration.
	var lamp_t: float = clamp((t - _FADE_START) / (_FADE_END - _FADE_START), 0.0, 1.0)
	for i in _lamps.size():
		var base: float = lerp(_lamp_base_energies[i], 0.0, lamp_t)
		var noise_val: float = _noise.get_noise_2d(t * 4.0, float(i) * 17.3)  # -1..1
		var energy: float = maxf(0.0, base + noise_val * lamp_t * _lamp_base_energies[i] * 0.01)
		_lamps[i].light_energy = energy

	if t >= _FADE_END:
		_fade_done = true
		$CityMegaNode.visible = false


# ── Fog helpers ───────────────────────────────────────────────────────────────

func _disable_fog_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var mat: Material = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				if mat is BaseMaterial3D:
					var dup := mat.duplicate() as BaseMaterial3D
					dup.disable_fog = true
					mi.set_surface_override_material(s, dup)
	for child in node.get_children():
		_disable_fog_recursive(child)


# ── Animation helpers ─────────────────────────────────────────────────────────

func _play_first_animation(character: Node3D) -> void:
	if not is_instance_valid(character):
		push_warning("penulti_boot: character node not found")
		return
	var anim_player: AnimationPlayer = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not anim_player:
		push_warning("penulti_boot: no AnimationPlayer found under %s" % character.name)
		return
	var list: PackedStringArray = anim_player.get_animation_list()
	if list.is_empty():
		push_warning("penulti_boot: no animations on %s" % character.name)
		return
	var target: String = list[0]
	for anim_name in list:
		if anim_name == "mixamo_com":
			target = anim_name
			break
	anim_player.play(target)
