extends Node3D

const HDRI_PATH   := "res://assets/textures/hdri/kloofendal_48d_partly_cloudy_1k.hdr"
const SKY_SH_PATH := "res://assets/shaders/sky_hdri.gdshader"


func _ready() -> void:
	print("=== BEACH HDRI PROBE START ===")
	print("Godot version: ", Engine.get_version_info())
	print("Renderer: ", RenderingServer.get_rendering_device().get_device_name() \
			if RenderingServer.get_rendering_device() else "no RD")

	_list_sky_classes()
	_probe_hdri()
	_probe_world_environment()
	_probe_water_shader()

	print("=== PROBE COMPLETE — scene is alive ===")


func _list_sky_classes() -> void:
	print("\n--- Registered sky-related classes ---")
	for cls: String in ClassDB.get_class_list():
		if "Sky" in cls or "sky" in cls:
			print("  ", cls)


func _probe_hdri() -> void:
	print("\n--- HDR texture probe ---")
	print("ResourceLoader can load: ", ResourceLoader.exists(HDRI_PATH))

	var tex: Resource = ResourceLoader.load(HDRI_PATH, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)
	if tex == null:
		print("ERROR: HDR texture loaded as NULL")
		return

	print("Loaded OK, class: ", tex.get_class())

	if tex is Texture2D:
		var img: Image = (tex as Texture2D).get_image()
		if img == null:
			print("WARNING: get_image() returned null — VRAM-compressed (OK)")
		else:
			print("Image size: ", img.get_width(), "x", img.get_height())
			var fmt: int = img.get_format()
			print("Image format int: ", fmt, " (RGBF=18, RGBAF=19, RGBH=24, RGBAH=25)")
			print("Is float/half HDR: ", fmt in [18, 19, 24, 25])

	print("\nClassDB has PanoramaSkyMaterial: ", ClassDB.class_exists("PanoramaSkyMaterial"))

	if not ClassDB.class_exists("PanoramaSkyMaterial"):
		print("FATAL: PanoramaSkyMaterial not in ClassDB")
		return

	print("Instantiating PanoramaSkyMaterial...")
	var sky_mat: Resource = ClassDB.instantiate("PanoramaSkyMaterial")
	if sky_mat == null:
		print("ERROR: ClassDB.instantiate(PanoramaSkyMaterial) returned null")
		return
	print("Instantiated OK, class: ", sky_mat.get_class())

	sky_mat.set("panorama", tex)
	print("panorama set OK")

	var sky := Sky.new()
	sky.sky_material = sky_mat
	print("Sky resource created OK")

	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		print("ERROR: WorldEnvironment node not found")
		return
	var env: Environment = env_node.environment
	if env == null:
		print("ERROR: WorldEnvironment.environment is null")
		return

	print("Swapping sky...")
	env.sky = sky
	print("=== SKY SWAP COMPLETE — HDRI shader sky is live ===")


func _probe_world_environment() -> void:
	print("\n--- WorldEnvironment probe ---")
	var env_node := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node == null:
		print("ERROR: WorldEnvironment node missing")
		return
	print("WorldEnvironment found")
	var env := env_node.environment
	if env == null:
		print("ERROR: environment resource is null")
		return
	print("background_mode: ",      env.background_mode)
	print("ambient_light_source: ", env.ambient_light_source)
	print("ambient_light_energy: ", env.ambient_light_energy)
	print("tonemap_mode: ",         env.tonemap_mode)
	print("tonemap_white: ",        env.tonemap_white)


func _probe_water_shader() -> void:
	print("\n--- Water shader probe ---")
	var water := get_node_or_null("OceanWater") as MeshInstance3D
	if water == null:
		print("WARNING: OceanWater node not found")
		return
	print("OceanWater found, mesh: ", water.mesh.get_class() if water.mesh else "NULL")
	var mat := water.get_surface_override_material(0)
	if mat == null:
		print("ERROR: OceanWater surface material is null")
		return
	print("Material class: ", mat.get_class())
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		print("Shader null? ", sm.shader == null)
		var na:   Texture2D = sm.get_shader_parameter("normalmap_a_sampler")
		var nb:   Texture2D = sm.get_shader_parameter("normalmap_b_sampler")
		var uv_s: Texture2D = sm.get_shader_parameter("uv_sampler")
		var foam: Texture2D = sm.get_shader_parameter("foam_sampler")
		print("normalmap_a: ", "OK " + na.get_class()   if na   else "NULL")
		print("normalmap_b: ", "OK " + nb.get_class()   if nb   else "NULL")
		print("uv_sampler:  ", "OK " + uv_s.get_class() if uv_s else "NULL")
		print("foam:        ", "OK " + foam.get_class() if foam else "NULL")
