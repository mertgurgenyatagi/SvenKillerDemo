@tool
extends EditorScript

## Run this script once to bake collision shapes into the sven_house scene
## This is more efficient than generating at runtime

func _run() -> void:
	print("\n=== BAKING HOUSE COLLISION ===")

	# Load the scene
	var scene_path := "res://scenes/sven_house.tscn"
	var packed_scene: PackedScene = load(scene_path)

	if not packed_scene:
		push_error("Could not load scene: " + scene_path)
		return

	# Instance it
	var scene_root: Node = packed_scene.instantiate()
	var house_model: Node = scene_root.get_node_or_null("HouseModel")

	if not house_model:
		push_error("HouseModel not found in scene")
		scene_root.queue_free()
		return

	# Remove any existing collision
	var existing_collision := scene_root.get_node_or_null("HouseCollision")
	if existing_collision:
		existing_collision.free()

	# Create StaticBody3D
	var static_body := StaticBody3D.new()
	static_body.name = "HouseCollision"
	static_body.collision_layer = 1  # Layer 1: World
	static_body.collision_mask = 0   # Static, doesn't need to detect
	scene_root.add_child(static_body)
	static_body.owner = scene_root

	# Find all meshes and create collision
	var mesh_instances := get_all_mesh_instances(house_model)
	var collision_count := 0

	print("Found %d mesh instances" % mesh_instances.size())

	for mesh_instance in mesh_instances:
		if not (mesh_instance is MeshInstance3D):
			continue

		var mesh_inst: MeshInstance3D = mesh_instance
		var mesh: Mesh = mesh_inst.mesh

		if not mesh:
			continue

		# Create collision shape
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "Col_%s" % mesh_inst.name

		# Create trimesh shape for accurate collision
		var shape: Shape3D = mesh.create_trimesh_shape()

		if not shape:
			push_warning("Could not create shape for: " + mesh_inst.name)
			continue

		collision_shape.shape = shape

		# Calculate transform relative to scene root
		var relative_transform := scene_root.global_transform.inverse() * mesh_inst.global_transform
		collision_shape.transform = relative_transform

		static_body.add_child(collision_shape)
		collision_shape.owner = scene_root
		collision_count += 1

	print("Created %d collision shapes" % collision_count)

	# Save the scene
	var scene_to_save := PackedScene.new()
	var result := scene_to_save.pack(scene_root)

	if result == OK:
		result = ResourceSaver.save(scene_to_save, scene_path)
		if result == OK:
			print("✓ Collision baked and saved to: " + scene_path)
		else:
			push_error("Failed to save scene: " + str(result))
	else:
		push_error("Failed to pack scene: " + str(result))

	scene_root.queue_free()
	print("=== DONE ===\n")

func get_all_mesh_instances(node: Node) -> Array:
	var meshes: Array = []

	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		meshes.append_array(get_all_mesh_instances(child))

	return meshes
