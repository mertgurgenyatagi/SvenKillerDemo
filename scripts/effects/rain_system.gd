@tool
class_name RainSystem
extends Node3D

## GPU-particle rain system. Auto-follows the player (or a custom target path).
## Every exported variable is live-editable from the Inspector at runtime.
## @tool makes it render live in the editor — open rain_preview.tscn to tweak.

# ── Intensity ────────────────────────────────────────────────────────────────

## Rain density: 0 = off, 1 = heavy downpour.
@export_range(0.0, 1.0, 0.01) var intensity: float = 0.7:
	set(v): intensity = v; _apply_config()

## Particle budget — scales linearly with intensity.
## Higher values = denser rain but more GPU cost.
@export_range(200, 15000, 100) var max_particles: int = 4000:
	set(v): max_particles = v; _apply_config()

# ── Emitter ───────────────────────────────────────────────────────────────────

@export_group("Emitter")

## Width of the spawning box centred on the player (meters, X-axis).
@export_range(5.0, 60.0, 0.5) var emitter_width: float = 22.0:
	set(v): emitter_width = v; _apply_config()

## Depth of the spawning box centred on the player (meters, Z-axis).
@export_range(5.0, 60.0, 0.5) var emitter_depth: float = 22.0:
	set(v): emitter_depth = v; _apply_config()

## Height above the follow target where drops are spawned.
## Lifetime is derived from this: longer = drops stay visible longer.
@export_range(3.0, 25.0, 0.5) var spawn_height: float = 10.0:
	set(v): spawn_height = v; _apply_config()

# ── Physics ───────────────────────────────────────────────────────────────────

@export_group("Physics")

## Downward fall speed in m/s.
@export_range(5.0, 50.0, 0.5) var drop_speed: float = 18.0:
	set(v): drop_speed = v; _apply_config()

## Wind vector. Only X and Z matter (Y is ignored).
## Adds a horizontal slant to the rain direction.
@export var wind: Vector3 = Vector3(0.8, 0.0, 0.4):
	set(v): wind = v; _apply_config()

## Per-drop speed randomness (± m/s). Adds natural variance.
@export_range(0.0, 8.0, 0.25) var speed_variation: float = 2.0:
	set(v): speed_variation = v; _apply_config()

# ── Appearance ────────────────────────────────────────────────────────────────

@export_group("Appearance")

## Visual length of each rain streak in meters.
@export_range(0.02, 1.5, 0.01) var drop_length: float = 0.28:
	set(v): drop_length = v; _apply_config()

## Visual width of each rain streak in meters.
@export_range(0.001, 0.06, 0.001) var drop_width: float = 0.013:
	set(v): drop_width = v; _apply_config()

## Colour and base opacity of each streak.
## Each drop also fades in at spawn and out at ground impact (via lifetime gradient).
## Lower opacity = semi-transparent, reads better backlit against lights.
@export var drop_color: Color = Color(0.75, 0.88, 1.0, 0.18):
	set(v): drop_color = v; _apply_config()

# ── Target ────────────────────────────────────────────────────────────────────

@export_group("Target")

## Node to follow. Leave empty to auto-detect:
## searches group "player" first, then a node named "Player".
@export var follow_target_path: NodePath = NodePath(""):
	set(v): follow_target_path = v; _resolve_target()

# ── Internals ────────────────────────────────────────────────────────────────

var _particles: GPUParticles3D
var _proc_mat: ParticleProcessMaterial
var _mesh_mat: StandardMaterial3D
var _mesh: QuadMesh
var _target: Node3D
var _ambient_player: AudioStreamPlayer

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_particles()
	_resolve_target()
	_apply_config()
	_setup_ambient_audio()


func _process(_delta: float) -> void:
	# Keep the emitter anchored above the target every frame.
	# local_coords=false means emitted drops stay in world space and fall straight.
	if is_instance_valid(_target):
		global_position = _target.global_position + Vector3(0.0, spawn_height, 0.0)

# ── One-time construction ─────────────────────────────────────────────────────

func _build_particles() -> void:
	# Process material — drives particle behaviour
	_proc_mat = ParticleProcessMaterial.new()

	# Fade-in near spawn, fade-out near ground impact
	var grad := Gradient.new()
	grad.colors   = PackedColorArray([Color(1,1,1,0.0), Color(1,1,1,1.0), Color(1,1,1,1.0), Color(1,1,1,0.0)])
	grad.offsets  = PackedFloat32Array([0.0, 0.08, 0.88, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient  = grad
	_proc_mat.color_ramp = ramp

	# Semi-transparent, light-catching material. Distance fade makes far rain disappear smoothly.
	_mesh_mat                        = StandardMaterial3D.new()
	_mesh_mat.transparency           = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_mat.shading_mode           = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh_mat.billboard_mode         = BaseMaterial3D.BILLBOARD_FIXED_Y
	_mesh_mat.cull_mode              = BaseMaterial3D.CULL_DISABLED
	_mesh_mat.depth_draw_mode        = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mesh_mat.vertex_color_use_as_albedo = true  # particle COLOR (lifetime ramp) multiplies albedo
	_mesh_mat.distance_fade          = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA  # far rain fades
	_mesh_mat.albedo_texture         = _make_rain_texture()  # soft Gaussian streak, not solid rectangle

	# Thin vertical quad
	_mesh          = QuadMesh.new()
	_mesh.material = _mesh_mat

	# GPU particles node — BILLBOARD_FIXED_Y handled by the material; no transform_align needed
	_particles                  = GPUParticles3D.new()
	_particles.name             = "RainParticles"
	_particles.local_coords     = false  # world-space: drops fall straight even as emitter moves with player
	_particles.one_shot         = false
	_particles.explosiveness    = 0.0
	_particles.randomness       = 0.5
	_particles.process_material = _proc_mat
	_particles.draw_pass_1      = _mesh
	add_child(_particles)


func _make_rain_texture() -> ImageTexture:
	## Generate a soft Gaussian-blurred streak texture. Each drop is soft at the edges,
	## bright in the middle, elongated vertically. This replaces solid white rectangles.
	var w := 8
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)

	var cx := float(w) * 0.5
	var cy := float(h) * 0.5

	for y in range(h):
		for x in range(w):
			var dx := (float(x) - cx + 0.5) / (float(w) * 0.5)  # -1..1
			var dy := (float(y) - cy + 0.5) / (float(h) * 0.5)  # -1..1

			# Tight Gaussian on X — narrow, soft-edged streak
			var ax := exp(-dx * dx * 6.0)

			# Wider Gaussian on Y — elongated, brighter middle, fades at tips
			var ay := exp(-dy * dy * 1.8)

			var alpha := ax * ay
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(img)


func _setup_ambient_audio() -> void:
	## Play looping rain ambient audio at full volume.
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = AudioManager.get_audio_stream(AudioManager.AudioID.AMB_RAIN)
	_ambient_player.bus = "SFX"
	_ambient_player.volume_db = -14.0  # 2x louder than -20 dB
	_ambient_player.finished.connect(_ambient_player.play)  # loop on finish
	add_child(_ambient_player)
	_ambient_player.play()

# ── Target resolution ─────────────────────────────────────────────────────────

func _resolve_target() -> void:
	if not is_inside_tree():
		return

	# 1. Explicit path set in Inspector
	if follow_target_path != NodePath(""):
		_target = get_node_or_null(follow_target_path) as Node3D
		return

	# 2. Any node in the "player" group
	var group: Array = get_tree().get_nodes_in_group("player")
	if group.size() > 0:
		_target = group[0] as Node3D
		return

	# 3. A node literally named "Player" anywhere in the tree
	_target = get_tree().root.find_child("Player", true, false) as Node3D

# ── Live configuration (called by setters + _ready) ──────────────────────────

func _apply_config() -> void:
	if not is_instance_valid(_particles):
		return  # called by setters before _ready — safe to skip

	# Particle count and emission
	_particles.amount   = maxi(int(float(max_particles) * intensity), 1)
	_particles.emitting = intensity > 0.001

	# Lifetime: time for a drop to fall spawn_height metres at drop_speed
	_particles.lifetime = spawn_height / maxf(drop_speed, 1.0)

	# Generous visibility AABB so Godot never culls the effect mid-frame
	_particles.visibility_aabb = AABB(
		Vector3(-emitter_width, -spawn_height - 2.0, -emitter_depth),
		Vector3(emitter_width * 2.0, spawn_height + 4.0, emitter_depth * 2.0)
	)

	# Emission box: a thin horizontal slab at the top of the spawn column
	_proc_mat.emission_shape       = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_proc_mat.emission_box_extents = Vector3(emitter_width * 0.5, 0.05, emitter_depth * 0.5)

	# Velocity direction = straight down + wind slant
	var fall_dir: Vector3        = Vector3(wind.x, -drop_speed, wind.z).normalized()
	_proc_mat.direction            = fall_dir
	_proc_mat.initial_velocity_min = maxf(drop_speed - speed_variation, 1.0)
	_proc_mat.initial_velocity_max = drop_speed + speed_variation
	_proc_mat.spread               = 1.0   # tiny angle spread for natural variation
	_proc_mat.gravity              = Vector3.ZERO  # velocity already contains all motion

	_proc_mat.color        = Color.WHITE
	_mesh_mat.albedo_color = drop_color

	# Streak dimensions
	_mesh.size = Vector2(drop_width, drop_length)
