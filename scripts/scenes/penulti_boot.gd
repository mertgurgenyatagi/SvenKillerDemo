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
##     t=15       Game Ready declared — game_ready_declared emitted;
##                GameManager lifts the curtain on the next frame.
##
##   GR (Game Ready) — player regains camera + movement control on transition_finished.
##   All timeline values below are GR-relative seconds.
##   E key and indicator remain blocked until the worldenv transition is fully complete.
##
## Transition strategy:
##   Phase 1 — t=14.14→52s: fog density ramps up until the scene is fully obscured.
##   Phase 2 — t=52→60s:    mesh transparency fades. Artifacts don't matter;
##                           fog covers everything by this point.
##   t=60s:                  CityMegaNode hidden, fog work done.
## - t=14.14–60s: street lamps fade to zero with 1% noise flicker.
##
## Audio:
##   penulti_part_1.ogg plays non-looping from GR.
##   2 s before it ends, a crossfade begins: part_1 fades out and
##   penulti_loop.ogg fades in over 2 s, then loops indefinitely.

signal game_ready_declared

const _FADE_START:      float = 14.14
const _FOG_END:         float = 52.0
const _FADE_END:        float = 60.0
const _FOG_MAX_DENSITY: float = 12.5
const _BEACH_DURATION:  float = 15.0

## Beach WorldEnvironment targets — ProceduralSkyMaterial (source: beach_test.tscn)
const _BEACH_SKY_TOP:          Color = Color(0.0, 0.596, 0.747)
const _BEACH_SKY_HORIZON:      Color = Color(0.95, 0.38, 0.05)
const _BEACH_SKY_CURVE:        float = 0.078
const _BEACH_SKY_ENERGY:       float = 1.7
const _BEACH_GND_BOTTOM:       Color = Color(0.949, 0.380, 0.051)
const _BEACH_GND_HORIZON:      Color = Color(0.949, 0.380, 0.051)
const _BEACH_GND_CURVE:        float = 0.10
const _BEACH_GND_ENERGY:       float = 1.65
## Beach WorldEnvironment targets — Environment (source: beach_test.tscn)
const _BEACH_BG_ENERGY:        float = 0.47
const _BEACH_AMB_COLOR:        Color = Color(0.911, 0.752, 0.611)
const _BEACH_AMB_ENERGY:       float = 0.16
const _BEACH_TONEMAP_EXPOSURE: float = 0.52
const _BEACH_TONEMAP_WHITE:    float = 1.0
const _BEACH_GLOW_INTENSITY:   float = 0.9
const _BEACH_GLOW_BLOOM:       float = 0.08
const _BEACH_FOG_COLOR:        Color = Color(0.95, 0.50, 0.15)
const _BEACH_FOG_ENERGY:       float = 0.8
const _BEACH_FOG_DENSITY:      float = 0.008
const _BEACH_FOG_AERIAL:       float = 0.7
const _BEACH_FOG_SCATTER:      float = 0.63
const _BEACH_VOL_DENSITY:          float = 0.0015
const _BEACH_VOL_ALBEDO:           Color = Color(1.0, 0.72, 0.45)
const _BEACH_VOL_EMISSION:         Color = Color(0.7, 0.25, 0.03)
const _BEACH_VOL_EMISSION_ENERGY:  float = 0.02
const _BEACH_GLOW_HDR:             float = 1.2

## Downward pitch delta applied during the LR sequence (radians).
const _LR_PITCH_DELTA: float = -0.1745  # ~10°

## Set true in beach_preview.tscn to skip the city phase entirely on F6.
@export var debug_skip_to_beach: bool = false

@onready var _characters: Array[Node3D] = [$CityMegaNode/npc_elise]
@onready var _player = $Player  # player_penulti.gd — accessed via duck-typing
@onready var _beach_sun: DirectionalLight3D = $BeachMegaNode/DirectionalLight3D
@onready var _indicator: Node3D = $SittingBoxPhysics/InteractableIndicator

var _city_env: Environment          = null
var _sky_mat:  ProceduralSkyMaterial = null
var _beach_sun_energy: float         = 0.0

var _lamps: Array[OmniLight3D] = []
var _lamp_base_energies: Array[float] = []
var _noise: FastNoiseLite
var _start_time:  float = 0.0
var _fade_done:   bool  = false
var _beach_done:  bool  = false
var _game_ready:  bool  = false

var _part1_player: AudioStreamPlayer = null
var _loop_player: AudioStreamPlayer = null
var _death_active: bool = false
var _player_start_transform: Transform3D
var _canvas: CanvasLayer = null
var _black_screen: ColorRect = null


func _ready() -> void:
	for character in _characters:
		_play_first_animation(character)

	# Cache the beach sun's target energy and zero it out — it ramps up during the beach reveal.
	_beach_sun_energy = _beach_sun.light_energy
	_beach_sun.light_energy = 0.0

	# Duplicate the city environment so fog/sky tweening doesn't dirty the .tres resource.
	_city_env = $WorldEnvironmentCity.environment.duplicate() as Environment
	$WorldEnvironmentCity.environment = _city_env
	_city_env.fog_enabled = true
	_city_env.fog_density = 0.0
	_city_env.fog_aerial_perspective = 0.0

	# Duplicate the sky material chain (shallow env.duplicate() doesn't deep-copy sub-resources).
	if _city_env.sky:
		var sky_dup := _city_env.sky.duplicate() as Sky
		if sky_dup.sky_material is ProceduralSkyMaterial:
			_sky_mat = sky_dup.sky_material.duplicate() as ProceduralSkyMaterial
			sky_dup.sky_material = _sky_mat
			_city_env.sky = sky_dup

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

	# Keep the indicator hidden until the worldenv transition is fully complete.
	if is_instance_valid(_indicator):
		_indicator.call("fade_out")

	_player_start_transform = _player.global_transform
	_build_overlay_ui()

	if debug_skip_to_beach:
		_skip_to_beach_immediately()
		return

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
	# GR declared — but keep input blocked until the curtain lifts (transition_finished).
	# Emitting game_ready_declared tells GameManager to lift the curtain on the next frame.
	_game_ready = true
	_start_time = Time.get_ticks_msec() / 1000.0

	# E key stays blocked until the worldenv transition is fully complete (req #6).
	_player.e_blocked = true

	# Signal GameManager: scene is ready to be revealed.
	# Audio starts in _on_transition_finished to avoid bleeding through cinema's audio.
	game_ready_declared.emit()

	# When the curtain lifts, give player camera + movement control.
	GameManager.transition_finished.connect(_on_transition_finished, CONNECT_ONE_SHOT)


func _on_transition_finished() -> void:
	## Fired by GameManager after the hard-cut curtain has lifted.
	## Gives the player camera and movement control (req #5).
	## E key and indicator remain blocked until worldenv is done (reqs #6, #7).
	_player.camera_cutscene_active = false
	# Start audio now that cinema is gone and Master is unmuted.
	_start_penulti_audio()


# ── Debug skip ────────────────────────────────────────────────────────────────

func _skip_to_beach_immediately() -> void:
	$CityMegaNode.visible  = false
	$BeachMegaNode.visible = true
	_hide_bench_meshes()
	_apply_beach_env(1.0)
	_fade_done  = true
	_beach_done = true
	_game_ready = true  # Enables death boundaries in debug mode.
	_player.camera_cutscene_active = false
	_player.e_blocked = false
	if is_instance_valid(_indicator):
		_indicator.call("fade_in")
	# Start ambient audio so beach_preview.tscn is fully functional on F6.
	_restart_loop_audio()


# ── Per-frame transition (GR-relative) ────────────────────────────────────────

func _process(_delta: float) -> void:
	# Death boundary — active once the player has movement control.
	if _game_ready and not _death_active and not _player.camera_cutscene_active:
		var pos: Vector3 = _player.global_position
		if pos.z > 38.0 or pos.z < -40.0 or pos.y < -2.0:
			_trigger_death()
			return

	if not _game_ready or _beach_done:
		return

	var t: float = Time.get_ticks_msec() / 1000.0 - _start_time

	if not _fade_done:
		# Phase 1: ramp fog density + aerial perspective until the scene is fully obscured.
		# aerial_perspective blends the background into the fog colour, eliminating silhouettes.
		if t < _FADE_START:
			return

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
			# Fog fully covers the scene — swap city for beach invisibly.
			$CityMegaNode.visible  = false
			$BeachMegaNode.visible = true
			_hide_bench_meshes()
	else:
		# Phase 2: transition WorldEnvironment to sunny beach over _BEACH_DURATION seconds.
		var beach_t: float = clamp((t - _FADE_END) / _BEACH_DURATION, 0.0, 1.0)
		_apply_beach_env(beach_t)
		if beach_t >= 1.0:
			_beach_done = true
			_on_worldenv_transition_complete()


# ── Worldenv complete ──────────────────────────────────────────────────────────

func _on_worldenv_transition_complete() -> void:
	## Called once when the beach environment has fully faded in.
	## Unblocks E key and reveals the interactable indicator (reqs #6, #7).
	_player.e_blocked = false
	if is_instance_valid(_indicator):
		_indicator.call("fade_in")


# ── Beach environment transition ───────────────────────────────────────────────

func _apply_beach_env(beach_t: float) -> void:
	## Lerps the duplicated WorldEnvironment from foggy night to sunny beach.
	## Fog uses a cubic decay so the beach reveals itself in the final ~4 seconds.

	# Fog: cubic decay keeps scene obscured for the first few seconds of the reveal.
	# Ends at _BEACH_FOG_DENSITY rather than 0 to preserve the distant haze.
	var fog_decay: float = pow(1.0 - beach_t, 3.0)
	_city_env.fog_density            = lerpf(_FOG_MAX_DENSITY * fog_decay, _BEACH_FOG_DENSITY, beach_t)
	_city_env.fog_aerial_perspective = lerpf(1.0,    _BEACH_FOG_AERIAL,   beach_t)
	_city_env.fog_light_color        = lerp(Color(0.2, 0.22, 0.3),  _BEACH_FOG_COLOR,   beach_t)
	_city_env.fog_light_energy       = lerpf(0.3,    _BEACH_FOG_ENERGY,   beach_t)
	_city_env.fog_sun_scatter        = lerpf(0.0,    _BEACH_FOG_SCATTER,  beach_t)
	_city_env.volumetric_fog_density         = lerpf(0.0507, _BEACH_VOL_DENSITY,          beach_t)
	_city_env.volumetric_fog_albedo          = lerp(Color(0.22, 0.24, 0.32), _BEACH_VOL_ALBEDO,    beach_t)
	_city_env.volumetric_fog_emission        = lerp(Color(0.1, 0.1, 0.14),   _BEACH_VOL_EMISSION,  beach_t)
	_city_env.volumetric_fog_emission_energy = lerpf(0.2,   _BEACH_VOL_EMISSION_ENERGY, beach_t)

	# Ambient light + tonemap.
	_city_env.ambient_light_color              = lerp(Color(0.18, 0.20, 0.32), _BEACH_AMB_COLOR,      beach_t)
	_city_env.ambient_light_energy             = lerpf(0.35,  _BEACH_AMB_ENERGY,     beach_t)
	_city_env.background_energy_multiplier     = lerpf(1.0,   _BEACH_BG_ENERGY,      beach_t)
	_city_env.tonemap_mode                     = Environment.TONE_MAPPER_ACES
	_city_env.tonemap_exposure                 = lerpf(1.0,   _BEACH_TONEMAP_EXPOSURE, beach_t)
	_city_env.tonemap_white                    = lerpf(1.2,   _BEACH_TONEMAP_WHITE,  beach_t)
	_city_env.ssr_enabled                      = true
	_city_env.ssao_enabled                     = beach_t > 0.5
	_city_env.ssil_enabled                     = beach_t > 0.5
	_city_env.glow_intensity                   = lerpf(0.4,   _BEACH_GLOW_INTENSITY, beach_t)
	_city_env.glow_bloom                       = lerpf(0.15,  _BEACH_GLOW_BLOOM,     beach_t)
	_city_env.glow_hdr_threshold               = lerpf(1.0,   _BEACH_GLOW_HDR,       beach_t)
	_city_env.sdfgi_read_sky_light             = false

	# Sun: cubic ease-in so it stays dark while fog clears, then floods in.
	_beach_sun.light_energy = _beach_sun_energy * pow(beach_t, 3.0)

	# Sky material.
	if _sky_mat:
		_sky_mat.sky_top_color            = lerp(Color(0.12, 0.14, 0.22), _BEACH_SKY_TOP,     beach_t)
		_sky_mat.sky_horizon_color        = lerp(Color(0.25, 0.22, 0.28), _BEACH_SKY_HORIZON, beach_t)
		_sky_mat.sky_curve                = lerpf(0.08, _BEACH_SKY_CURVE,  beach_t)
		_sky_mat.sky_energy_multiplier    = lerpf(0.3,  _BEACH_SKY_ENERGY, beach_t)
		_sky_mat.ground_bottom_color      = lerp(Color(0.08, 0.08, 0.1),  _BEACH_GND_BOTTOM,  beach_t)
		_sky_mat.ground_horizon_color     = lerp(Color(0.2, 0.18, 0.22),  _BEACH_GND_HORIZON, beach_t)
		_sky_mat.ground_curve             = lerpf(0.05, _BEACH_GND_CURVE,  beach_t)
		_sky_mat.ground_energy_multiplier = lerpf(0.2,  _BEACH_GND_ENERGY, beach_t)


# ── Audio ──────────────────────────────────────────────────────────────────────

func _start_penulti_audio() -> void:
	## Plays penulti_part_1.ogg non-looping. Schedules a 2-second crossfade into
	## penulti_loop.ogg so the two tracks overlap cleanly at the transition point.

	var part1_stream := load("res://assets/audio/sfx/ambient/penulti_part_1.ogg") as AudioStreamOggVorbis
	if not part1_stream:
		push_warning("penulti_boot: penulti_part_1.ogg not found")
		return
	part1_stream.loop = false

	_part1_player = AudioStreamPlayer.new()
	_part1_player.stream = part1_stream
	_part1_player.bus = "Ambient"
	add_child(_part1_player)
	_part1_player.play()

	# Schedule the crossfade so it starts 2 s before part_1 ends.
	var part1_length: float = part1_stream.get_length()
	var crossfade_start: float = maxf(0.0, part1_length - 2.0)
	get_tree().create_timer(crossfade_start).timeout.connect(_start_crossfade_to_loop)


func _start_crossfade_to_loop() -> void:
	## Fades out part_1 and fades in the looping track simultaneously over 2 seconds.
	if not is_instance_valid(_part1_player):
		return

	var loop_stream := load("res://assets/audio/sfx/ambient/penulti_loop.ogg") as AudioStreamOggVorbis
	if not loop_stream:
		push_warning("penulti_boot: penulti_loop.ogg not found")
		return
	loop_stream.loop = true

	var loop_player := AudioStreamPlayer.new()
	loop_player.stream = loop_stream
	loop_player.bus = "Ambient"
	loop_player.volume_db = -40.0  # Start silent
	_loop_player = loop_player
	add_child(loop_player)
	loop_player.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_part1_player, "volume_db", -40.0, 2.0)
	tween.tween_property(loop_player, "volume_db", 0.0, 2.0)

	# Free part_1 player after the crossfade completes.
	var p1_ref := _part1_player
	tween.set_parallel(false)
	tween.tween_callback(p1_ref.queue_free)


# ── Death boundary ────────────────────────────────────────────────────────────

func _build_overlay_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 190
	add_child(_canvas)
	_black_screen = ColorRect.new()
	_black_screen.color = Color.BLACK
	_black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black_screen.visible = false
	_canvas.add_child(_black_screen)


func _trigger_death() -> void:
	_death_active = true
	_black_screen.visible = true
	var master_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, true)

	await get_tree().create_timer(1.6).timeout

	if is_instance_valid(_player):
		_player.global_transform = _player_start_transform
		_player.velocity = Vector3.ZERO

	if not _beach_done:
		_skip_to_beach_immediately()
	_restart_loop_audio()

	AudioServer.set_bus_mute(master_idx, false)
	_black_screen.visible = false
	_death_active = false


func _restart_loop_audio() -> void:
	if is_instance_valid(_part1_player):
		_part1_player.queue_free()
		_part1_player = null
	if is_instance_valid(_loop_player):
		_loop_player.queue_free()
		_loop_player = null

	var loop_stream := load("res://assets/audio/sfx/ambient/penulti_loop.ogg") as AudioStreamOggVorbis
	if not loop_stream:
		push_warning("penulti_boot: penulti_loop.ogg not found on respawn")
		return
	loop_stream.loop = true
	_loop_player = AudioStreamPlayer.new()
	_loop_player.stream = loop_stream
	_loop_player.bus = "Ambient"
	add_child(_loop_player)
	_loop_player.play()


# ── Bench cleanup ─────────────────────────────────────────────────────────────

func _hide_bench_meshes() -> void:
	## At the city→beach swap, hide every mesh in the bench node except the
	## armrest and lantern subtrees, which remain visible as foreground props.
	var bench_root := $BenchParent/penulti_bench
	var fbx_root   := "Sketchfab_model/bdd4514fc2284e5299ff864f57e18f27_fbx/RootNode"
	var armrest := bench_root.get_node_or_null(fbx_root + "/bench_armrest_R")
	var lantern  := bench_root.get_node_or_null(fbx_root + "/Lantern")
	_hide_mesh_recursive(bench_root, armrest, lantern)


func _hide_mesh_recursive(node: Node, keep_a: Node, keep_b: Node) -> void:
	## Recursively hides MeshInstance3D nodes, skipping the keep_a and keep_b subtrees.
	if node == keep_a or node == keep_b:
		return
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		_hide_mesh_recursive(child, keep_a, keep_b)


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
