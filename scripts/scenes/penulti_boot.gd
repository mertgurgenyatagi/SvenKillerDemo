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

## Outro: all env changes run concurrently over 40 s (cubic easing).
## fog density → 0.2, aerial → 0.0, glow → 8.0, fog light energy → 0.0.
## At 40 s: hide BeachMegaNode + CityMegaNode.
const _OUTRO_DURATION: float = 40.0

## Subtitles for penulti_part_1.ogg. Times are seconds from audio start (= scene visible snap-in).
const _PART1_SUBTITLES: Array[Dictionary] = [
	{start = 1.360,  end = 5.150,  text = "how you can kind of slide into a role\nwithout really noticing it."},
	{start = 6.280,  end = 11.570, text = "You wake up, do what you're supposed to,\nsay the right things, smile at the right moments."},
	{start = 12.650, end = 16.320, text = "It's not fake exactly.\nJust\u2026 rehearsed."},
	{start = 17.180, end = 18.610, text = "Very rehearsed."},
	{start = 19.660, end = 22.890, text = "And suddenly you're good at it.\nAlmost too good."},
	{start = 24.000, end = 27.290, text = "And I don't mean it's tragic.\nIt's not tragic."},
	{start = 27.780, end = 29.470, text = "It's just\u2026 smooth."},
	{start = 30.230, end = 30.970, text = "Practiced."},
	{start = 31.870, end = 33.930, text = "You become efficient at being yourself."},
	{start = 34.710, end = 36.730, text = "Or, well, a version of yourself."},
	{start = 38.310, end = 40.170, text = "I used to think everything\nhad to hold together."},
	{start = 40.950, end = 44.870, text = "That what you feel inside and what you do\non the outside should match perfectly,"},
	{start = 45.430, end = 46.400, text = "otherwise something is wrong."},
	{start = 47.570, end = 48.500, text = "But now I don't know."},
	{start = 49.510, end = 51.730, text = "Maybe it's okay if there's\na space in between."},
	{start = 52.500, end = 53.070, text = "A small one."},
	{start = 53.800, end = 54.690, text = "Or a bigger one."},
]

## Subtitles for the alley auto-walk segment. Times are autowalk-elapsed seconds (t=0 = auto_walk start).
const _ALLEY_SUBTITLES: Array[Dictionary] = [
	{start = 50.0,  end = 53.5,  text = "That was\u2026 I don't know. I had a really good time."},
	{start = 55.0,  end = 57.0,  text = "Like, a really good time."},
	{start = 59.5,  end = 62.0,  text = "Sorry, I'm bad at this."},
	{start = 64.0,  end = 67.5,  text = "I always say the wrong thing at the end of the night."},
	{start = 69.5,  end = 72.0,  text = "You're easy to talk to, though."},
	{start = 73.5,  end = 74.5,  text = "That helps."},
	{start = 77.0,  end = 81.0,  text = "I kept thinking \u2014 halfway through the film \u2014\nthat I was glad you suggested it."},
	{start = 83.5,  end = 85.5,  text = "The cinema, I mean."},
	{start = 87.0,  end = 90.0,  text = "I almost said no, actually."},
	{start = 92.0,  end = 94.5,  text = "I almost said I had plans."},
	{start = 97.0,  end = 100.5, text = "I didn't, obviously."},
	{start = 103.0, end = 106.0, text = "I just get nervous sometimes."},
	{start = 108.0, end = 110.0, text = "Anyway. Thank you."},
]

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
## When non-zero, overrides the player's spawn position in debug_skip_to_beach mode.
@export var debug_player_position: Vector3 = Vector3.ZERO
## Scene to hard-cut to when the alley sequence ends (E key or 205 s timeout).
## Leave empty to simply fade to black.
@export var alley_end_scene: String = ""

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
var _outro_active: bool = false
var _outro_cancelled: bool = false
var _debug_print_timer: float = 0.0
var _elise_companion: Node3D = null

## Visual distress effects (ramp over auto-walk duration).
const _DISTRESS_DURATION: float = 67.0
var _autowalk_elapsed: float = 0.0
var _distress_canvas: CanvasLayer = null
var _red_tint: ColorRect = null
var _grain_rect: ColorRect = null
var _jitter_yaw: float = 0.0
var _fidget_timer: float = 0.0
var _motion_blur: MotionBlurController = null
var _elise_indicator: Sprite3D = null
var _elise_indicator_jitter_timer: float = 0.0
var _hard_cut_triggered: bool = false
var _elise_faded_in: bool = false
var _subtitle_label: Label = null
var _part1_subtitle_index: int = -1
var _alley_subtitle_index: int = -1



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
	_setup_distress_overlay()
	_setup_alley_lighting()
	_setup_elise_companion()

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
	if debug_player_position != Vector3.ZERO:
		_player.global_position = debug_player_position
		_player_start_transform = _player.global_transform
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

func _process(delta: float) -> void:
	_debug_print_timer += delta
	if _debug_print_timer >= 1.0:
		_debug_print_timer = 0.0
		print("player x: ", snappedf(_player.global_position.x, 0.01))

	# Death boundary + auto-walk trigger — active once the player has movement control.
	if _game_ready and not _death_active and not _player.camera_cutscene_active:
		var pos: Vector3 = _player.global_position
		if pos.z > 38.0 or pos.z < -40.0 or pos.y < -2.0:
			_trigger_death()
			return
		if not _outro_active and not _player.auto_walk and pos.x <= -45.0:
			_player.auto_walk = true
			_run_outro()
			_crossfade_to_distress()

		# Accumulate auto-walk time and drive distress effects.
		if _player.auto_walk:
			_autowalk_elapsed += delta
			_update_distress_effects(delta)

		# Elise fade-in at t=67.
		if _player.auto_walk and not _elise_faded_in and _autowalk_elapsed >= 67.0:
			_elise_faded_in = true
			_fade_in_elise_companion()

		# E key triggers the hard cut at t ≥ 70 s.
		if _player.auto_walk and not _hard_cut_triggered and _autowalk_elapsed >= 70.0:
			if Input.is_action_just_pressed("interact"):
				_trigger_alley_hard_cut()

	# Subtitle sync for penulti_part_1.ogg.
	if is_instance_valid(_subtitle_label) and _game_ready and not _death_active:
		if SettingsManager.get_setting("subtitles/enabled") \
				and is_instance_valid(_part1_player) and _part1_player.playing:
			var pos: float = _part1_player.get_playback_position()
			var found: bool = false
			for i in _PART1_SUBTITLES.size():
				var sub: Dictionary = _PART1_SUBTITLES[i]
				if pos >= sub.start and pos <= sub.end:
					if _part1_subtitle_index != i:
						_subtitle_label.text = sub.text
						_subtitle_label.visible = true
						_part1_subtitle_index = i
					found = true
					break
			if not found and _subtitle_label.visible:
				_subtitle_label.visible = false
				_part1_subtitle_index = -1
		elif _subtitle_label.visible:
			_subtitle_label.visible = false
			_part1_subtitle_index = -1

	# Subtitle sync for alley auto-walk (autowalk-elapsed, t=50→110).
	if is_instance_valid(_subtitle_label) and _game_ready and not _death_active \
			and SettingsManager.get_setting("subtitles/enabled") \
			and _player.auto_walk and not _part1_player:
		var found_alley: bool = false
		for i in _ALLEY_SUBTITLES.size():
			var sub: Dictionary = _ALLEY_SUBTITLES[i]
			if _autowalk_elapsed >= sub.start and _autowalk_elapsed <= sub.end:
				if _alley_subtitle_index != i:
					_subtitle_label.text = sub.text
					_subtitle_label.visible = true
					_alley_subtitle_index = i
				found_alley = true
				break
		if not found_alley and _subtitle_label.visible:
			_subtitle_label.visible = false
			_alley_subtitle_index = -1

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



func _trigger_alley_hard_cut() -> void:
	if _hard_cut_triggered:
		return
	_hard_cut_triggered = true
	if not alley_end_scene.is_empty():
		GameManager.hard_cut_to_scene(alley_end_scene)
	else:
		# No destination configured — just go to black permanently.
		AudioManager.stop_all()
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
		_black_screen.visible = true


func _trigger_death() -> void:
	_death_active = true
	# Cancel any running outro coroutine before going to black.
	_outro_cancelled = true
	_outro_active = false
	_black_screen.visible = true
	var master_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, true)

	await get_tree().create_timer(1.6).timeout

	if is_instance_valid(_elise_companion):
		_elise_companion.visible = false
	_elise_faded_in = false
	# Reset distress effects before restoring player.
	if is_instance_valid(_player):
		_player.target_camera_yaw -= _jitter_yaw
	_jitter_yaw = 0.0
	_fidget_timer = 0.0
	_autowalk_elapsed = 0.0
	if is_instance_valid(_red_tint):
		_red_tint.color = Color(0.6, 0.0, 0.0, 0.0)
	if is_instance_valid(_grain_rect) and _grain_rect.material is ShaderMaterial:
		(_grain_rect.material as ShaderMaterial).set_shader_parameter("strength", 0.0)
	if is_instance_valid(_motion_blur):
		_motion_blur.intensity = 0.0
	if is_instance_valid(_elise_indicator):
		_elise_indicator.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_elise_indicator.position = Vector3(0.0, 1.8, 0.0)
	_elise_indicator_jitter_timer = 0.0
	_hard_cut_triggered = false
	_part1_subtitle_index = -1
	_alley_subtitle_index = -1
	if is_instance_valid(_subtitle_label):
		_subtitle_label.visible = false
	if is_instance_valid(_player):
		_player.global_transform = _player_start_transform
		_player.velocity = Vector3.ZERO
		_player.auto_walk = false

	if not _beach_done:
		_skip_to_beach_immediately()
	else:
		# Outro may have partially modified the env or hidden BeachMegaNode — restore.
		$BeachMegaNode.visible = true
		_apply_beach_env(1.0)
	_restart_loop_audio()

	AudioServer.set_bus_mute(master_idx, false)
	_black_screen.visible = false
	_death_active = false


func _crossfade_to_distress() -> void:
	## Crossfades penulti_loop → amb_distress over 3 s when auto-walk begins.
	var distress_stream := load("res://assets/audio/sfx/ambient/amb_distress.ogg") as AudioStreamOggVorbis
	if not distress_stream:
		push_warning("penulti_boot: amb_distress.ogg not found")
		return
	distress_stream.loop = true

	var distress_player := AudioStreamPlayer.new()
	distress_player.stream = distress_stream
	distress_player.bus = "Ambient"
	distress_player.volume_db = -40.0
	add_child(distress_player)
	distress_player.play()

	# Update _loop_player before the tween so _restart_loop_audio()
	# (called on death) targets the new player immediately.
	var old_loop: AudioStreamPlayer = _loop_player
	_loop_player = distress_player

	var tween := create_tween().set_parallel(true)
	if is_instance_valid(old_loop):
		tween.tween_property(old_loop, "volume_db", -40.0, 3.0)
	tween.tween_property(distress_player, "volume_db", 0.0, 3.0)

	await tween.finished
	if is_instance_valid(old_loop):
		old_loop.queue_free()


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


# ── Outro: fog engulfs the beach ──────────────────────────────────────────────

func _run_outro() -> void:
	## All env changes run concurrently over _OUTRO_DURATION seconds (cubic easing).
	_outro_active = true
	_outro_cancelled = false

	# Capture starting values at trigger time.
	var start_fog_density:      float = _city_env.fog_density
	var start_fog_aerial:       float = _city_env.fog_aerial_perspective
	var start_fog_light_energy: float = _city_env.fog_light_energy
	var start_amb_energy:       float = _city_env.ambient_light_energy
	var start_bg_energy:        float = _city_env.background_energy_multiplier
	var start_glow:             float = _city_env.glow_intensity
	var start_bloom:            float = _city_env.glow_bloom
	var start_exposure:         float = _city_env.tonemap_exposure
	var start_sky_energy:       float = _sky_mat.sky_energy_multiplier   if _sky_mat else 0.0
	var start_gnd_energy:       float = _sky_mat.ground_energy_multiplier if _sky_mat else 0.0
	var start_sun_energy:       float = _beach_sun.light_energy

	var t0: float = Time.get_ticks_msec() / 1000.0

	while true:
		if _outro_cancelled:
			return
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - t0
		if elapsed >= _OUTRO_DURATION:
			$BeachMegaNode.visible              = false
			$CityMegaNode.visible               = false
			$AlleyMegaNode.visible              = true
			_city_env.ambient_light_source      = Environment.AMBIENT_SOURCE_COLOR
			_city_env.ambient_light_color       = Color(0.0, 0.0, 0.0)
			_city_env.ambient_light_energy      = 0.0
			break
		var lt: float = elapsed / _OUTRO_DURATION          # linear 0→1
		var t2: float = lt * lt                            # ease-in quadratic
		_city_env.fog_density                    = lerpf(start_fog_density,      0.2, t2)
		_city_env.fog_aerial_perspective         = lerpf(start_fog_aerial,       0.0, t2)
		_city_env.fog_light_energy               = lerpf(start_fog_light_energy, 0.0, t2)
		_city_env.ambient_light_energy           = lerpf(start_amb_energy,       0.0, t2)
		_city_env.background_energy_multiplier   = lerpf(start_bg_energy,        0.0, t2)
		_city_env.glow_intensity                 = lerpf(start_glow,             0.0, t2)
		_city_env.glow_bloom                     = lerpf(start_bloom,            0.0, t2)
		_city_env.tonemap_exposure               = lerpf(start_exposure,         0.0, t2)
		_beach_sun.light_energy                  = lerpf(start_sun_energy,       0.0, t2)
		if _sky_mat:
			_sky_mat.sky_energy_multiplier    = lerpf(start_sky_energy, 0.0, t2)
			_sky_mat.ground_energy_multiplier = lerpf(start_gnd_energy, 0.0, t2)
		await get_tree().process_frame

	# Ramp tonemap_exposure 0 → 1 over 5 s, ease-in quadratic.
	var ramp_t0: float = Time.get_ticks_msec() / 1000.0
	while true:
		if _outro_cancelled:
			_outro_active = false
			return
		var ramp_elapsed: float = Time.get_ticks_msec() / 1000.0 - ramp_t0
		if ramp_elapsed >= 5.0:
			_city_env.tonemap_exposure = 1.0
			break
		var rt: float = ramp_elapsed / 5.0
		_city_env.tonemap_exposure = rt * rt
		await get_tree().process_frame

	_outro_active = false


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


# ── Distress overlay ─────────────────────────────────────────────────────────

func _setup_distress_overlay() -> void:
	## CanvasLayer 189 — below the death screen (190) so it vanishes cleanly on death.

	# Motion blur — instantiated at intensity 0; ramped up during the alley walk.
	var mb_packed := preload("res://scenes/effects/motion_blur.tscn") as PackedScene
	if mb_packed:
		_motion_blur = mb_packed.instantiate() as MotionBlurController
		_motion_blur.intensity = 0.0  # stored before _ready so _ready() writes 0 to shader
		add_child(_motion_blur)

	_distress_canvas = CanvasLayer.new()
	_distress_canvas.layer = 189
	add_child(_distress_canvas)

	# Blood-red tint — starts fully transparent, max alpha ≈ 0.07 at t=123 s.
	_red_tint = ColorRect.new()
	_red_tint.color = Color(0.6, 0.0, 0.0, 0.0)
	_red_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_distress_canvas.add_child(_red_tint)

	# Film grain — a sparse noise overlay driven by a tiny inline shader.
	_grain_rect = ColorRect.new()
	_grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grain_shader := Shader.new()
	grain_shader.code = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	// Step time to 24 fps so grain has a cinematic flicker rather than per-frame noise.
	float t = floor(TIME * 24.0) / 24.0;
	float noise = fract(sin(dot(UV + t, vec2(12.9898, 78.233))) * 43758.5453);
	// Only the upper half of the noise range produces visible grain (sparse).
	float g = smoothstep(0.5, 1.0, noise);
	COLOR = vec4(1.0, 1.0, 1.0, g * strength * 0.5);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = grain_shader
	mat.set_shader_parameter("strength", 0.0)
	_grain_rect.material = mat
	_distress_canvas.add_child(_grain_rect)


func _update_distress_effects(delta: float) -> void:
	## Called every frame while auto_walk is true.
	## Uses quadratic ease-in so effects are imperceptible at first and
	## only become noticeable in the final third of the walk.
	var norm: float = clampf(_autowalk_elapsed / _DISTRESS_DURATION, 0.0, 1.0)
	var n2: float = norm * norm  # quadratic ease-in

	# Motion blur — ramps 0 → 1.0 over _DISTRESS_DURATION.
	if is_instance_valid(_motion_blur):
		_motion_blur.intensity = n2 * 1.0

	# Red tint — max alpha ≈ 0.21.
	if is_instance_valid(_red_tint):
		_red_tint.color = Color(0.6, 0.0, 0.0, n2 * 0.105)

	# Grain strength — max 0.27.
	if is_instance_valid(_grain_rect) and _grain_rect.material is ShaderMaterial:
		(_grain_rect.material as ShaderMaterial).set_shader_parameter("strength", n2 * 0.27)

	# Camera fidget — yaw nudge at irregular intervals, max ≈ 4.3°.
	_fidget_timer += delta
	var fidget_rate: float = lerpf(0.12, 0.04, norm)
	if _fidget_timer >= fidget_rate:
		_fidget_timer = 0.0
		var mag: float = n2 * 0.0375
		_player.target_camera_yaw -= _jitter_yaw
		_jitter_yaw = randf_range(-mag, mag)
		_player.target_camera_yaw += _jitter_yaw

	# Elise indicator — fades in from t=67 s over 10 s (final opacity at t=77); jitters at 40 Hz.
	if is_instance_valid(_elise_indicator) and _elise_faded_in:
		var ind_alpha: float = pow(clampf((_autowalk_elapsed - 67.0) / 10.0, 0.0, 1.0), 3.0) * 0.1
		_elise_indicator.modulate = Color(1.0, 1.0, 1.0, ind_alpha)
		if ind_alpha > 0.0:
			_elise_indicator_jitter_timer += delta
			if _elise_indicator_jitter_timer >= 0.025:  # 40 Hz
				_elise_indicator_jitter_timer = 0.0
				var j: float = 0.05
				_elise_indicator.position = Vector3(
					randf_range(-j, j),
					1.8 + randf_range(-j * 0.4, j * 0.4),
					randf_range(-j, j)
				)

	# Auto hard cut at t = 110 s.
	if _autowalk_elapsed >= 110.0 and not _hard_cut_triggered:
		_trigger_alley_hard_cut()


# ── Alley lighting setup ──────────────────────────────────────────────────────

func _setup_alley_lighting() -> void:
	## Render-layer separation so the 100 alley spotlights (A) light the player
	## but not the ground, while a single player-following spotlight (B) lights
	## the ground but not the player.
	##
	## Render layer 1 (default): player and most meshes — lit by spotlights A.
	## Render layer 2:            ground meshes under Grounds — lit only by spotlight B.

	# Spotlights A: exclude render layer 2 (bit mask 0x2) from their cull mask.
	var spots_node := get_node_or_null("AlleyMegaNode/SpotLights")
	if spots_node:
		for child in spots_node.get_children():
			if child is SpotLight3D:
				(child as SpotLight3D).light_cull_mask = 0xFFFFF & ~2

	# Ground meshes: move to render layer 2 so spotlights A ignore them.
	var grounds := get_node_or_null("AlleyMegaNode/GroundNode")
	if grounds:
		_set_render_layer_recursive(grounds, 2)



func _setup_elise_companion() -> void:
	## Instantiates the elise_walking FBX as a child of the player, offset 1.5 m in -Z.
	## Kept invisible until the alley segment begins.
	var packed := load("res://assets/models/characters/elise_walking.fbx") as PackedScene
	if not packed:
		push_warning("penulti_boot: elise_walking.fbx not found")
		return
	_elise_companion = packed.instantiate() as Node3D
	if not _elise_companion:
		push_warning("penulti_boot: elise_walking.fbx could not be instantiated as Node3D")
		return
	_elise_companion.position         = Vector3(0.0, 0.0, 1.0)
	_elise_companion.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_elise_companion.visible          = false
	_player.add_child(_elise_companion)

	var anim: AnimationPlayer = _elise_find_anim_player(_elise_companion)
	if not anim:
		push_warning("penulti_boot: no AnimationPlayer found in elise_walking.fbx")
		return
	var anim_name: String = _elise_find_anim_name(anim)
	if anim_name.is_empty():
		push_warning("penulti_boot: no animation found in elise_walking.fbx")
		return
	var anim_res: Animation = anim.get_animation(anim_name)
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_LINEAR
		_elise_strip_root_motion(anim_res)
	anim.play(anim_name)

	# Interactable indicator — manually controlled Sprite3D, starts invisible.
	# Fades in from t=100 s and jitters crazily so the player notices it.
	_elise_indicator = Sprite3D.new()
	_elise_indicator.texture = preload("res://assets/textures/ui/interactable_indicator.png")
	_elise_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_elise_indicator.pixel_size = 0.00035
	_elise_indicator.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_elise_indicator.no_depth_test = true
	_elise_indicator.position = Vector3(0.0, 1.8, 0.0)
	_elise_companion.add_child(_elise_indicator)


func _elise_find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result: AnimationPlayer = _elise_find_anim_player(child)
		if result:
			return result
	return null


func _elise_find_anim_name(anim: AnimationPlayer) -> String:
	const SKIP: PackedStringArray = ["RESET", "Take 001"]
	var first_real: String = ""
	for lib_key: StringName in anim.get_animation_library_list():
		var lib: AnimationLibrary = anim.get_animation_library(lib_key)
		for anim_entry: StringName in lib.get_animation_list():
			if str(anim_entry) in SKIP:
				continue
			var full: String = (str(lib_key) + "/" if lib_key != &"" else "") + str(anim_entry)
			if first_real.is_empty():
				first_real = full
			if "walk" in str(anim_entry).to_lower():
				return full
	return first_real


func _elise_strip_root_motion(anim_res: Animation) -> void:
	## Zero out X and Z on all position tracks so the character walks in-place
	## and stays at the offset set on _elise_companion.position.
	for i: int in range(anim_res.get_track_count()):
		if anim_res.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		for k: int in range(anim_res.track_get_key_count(i)):
			var pos: Vector3 = anim_res.track_get_key_value(i, k)
			anim_res.track_set_key_value(i, k, Vector3(0.0, pos.y, 0.0))


func _set_render_layer_recursive(node: Node, layer_mask: int) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = layer_mask
	for child in node.get_children():
		_set_render_layer_recursive(child, layer_mask)


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


# ── Elise fade-in ─────────────────────────────────────────────────────────────

func _fade_in_elise_companion() -> void:
	## Shows _elise_companion and tweens all its MeshInstance3D nodes from
	## fully transparent to opaque over 5 seconds.
	if not is_instance_valid(_elise_companion):
		return
	_elise_companion.visible = true
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes_recursive(_elise_companion, meshes)
	for mesh in meshes:
		mesh.transparency = 1.0
	var tween := create_tween()
	for mesh in meshes:
		tween.parallel().tween_property(mesh, "transparency", 0.0, 5.0)


func _collect_meshes_recursive(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes_recursive(child, result)
