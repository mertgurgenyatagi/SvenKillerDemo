extends MeshInstance3D

## Emissive cinema screen with noise-based flicker.
## Attach to the MeshInstance3D that represents the projection surface.

@export var base_energy: float = 5.0
@export var flicker_intensity: float = 0.4
@export var flicker_speed: float = 20.0

var _noise: FastNoiseLite
var _mat: StandardMaterial3D


func _ready() -> void:
	# Ensure a mesh exists so the material has a surface to bind to.
	if not mesh:
		var q := QuadMesh.new()
		q.size = Vector2(0.01, 0.01)
		mesh = q

	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.0, 0.0, 0.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.90, 0.94, 1.0)
	_mat.emission_energy_multiplier = base_energy
	set_surface_override_material(0, _mat)

	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = randi()


func _process(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0 * flicker_speed
	var n: float = _noise.get_noise_1d(t)            # -1.0 … 1.0
	_mat.emission_energy_multiplier = base_energy + n * flicker_intensity
