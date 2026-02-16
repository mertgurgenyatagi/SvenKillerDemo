@tool
extends EditorScript

func _run() -> void:
	# Load the house scene
	var house_scene: PackedScene = load("res://scenes/sven_house.tscn")

	if not house_scene:
		print("ERROR: Could not load sven_house.tscn")
		return

	# Instance the scene
	var instance := house_scene.instantiate()
	var house_model: Node = instance.get_node_or_null("HouseModel")

	if not house_model:
		print("ERROR: HouseModel not found in scene")
		instance.free()
		return

	# Calculate combined AABB from all child MeshInstance3D nodes
	var combined_aabb: AABB = AABB()
	var first_mesh := true
	var mesh_count := 0

	# Recursively find all MeshInstance3D nodes
	var meshes := get_all_mesh_instances(house_model)

	print("\n=== HOUSE MODEL ANALYSIS ===")
	print("Found %d mesh instances" % meshes.size())

	for mesh_instance in meshes:
		if mesh_instance is MeshInstance3D:
			mesh_count += 1
			var mesh: MeshInstance3D = mesh_instance
			var aabb := mesh.get_aabb()
			var mesh_transform := mesh.transform

			# Transform AABB to parent space
			var corners := [
				mesh_transform * Vector3(aabb.position.x, aabb.position.y, aabb.position.z),
				mesh_transform * Vector3(aabb.end.x, aabb.position.y, aabb.position.z),
				mesh_transform * Vector3(aabb.position.x, aabb.end.y, aabb.position.z),
				mesh_transform * Vector3(aabb.end.x, aabb.end.y, aabb.position.z),
				mesh_transform * Vector3(aabb.position.x, aabb.position.y, aabb.end.z),
				mesh_transform * Vector3(aabb.end.x, aabb.position.y, aabb.end.z),
				mesh_transform * Vector3(aabb.position.x, aabb.end.y, aabb.end.z),
				mesh_transform * Vector3(aabb.end.x, aabb.end.y, aabb.end.z),
			]

			for corner in corners:
				if first_mesh:
					combined_aabb = AABB(corner, Vector3.ZERO)
					first_mesh = false
				else:
					combined_aabb = combined_aabb.expand(corner)

	if mesh_count == 0:
		print("ERROR: No mesh instances found")
		instance.free()
		return

	print("\n=== BOUNDING BOX ===")
	print("Position: ", combined_aabb.position)
	print("Size: ", combined_aabb.size)
	print("End: ", combined_aabb.end)
	print("Center: ", combined_aabb.get_center())

	print("\n=== CURRENT TRANSFORM ===")
	if house_model is Node3D:
		var node3d: Node3D = house_model
		print("Position: ", node3d.position)
		print("Rotation (degrees): ", node3d.rotation_degrees)
		print("Scale: ", node3d.scale)

	print("\n=== RECOMMENDATIONS ===")
	var center := combined_aabb.get_center()
	var offset_to_origin := -center
	print("To center at origin, offset by: ", offset_to_origin)

	var max_dimension := max(combined_aabb.size.x, max(combined_aabb.size.y, combined_aabb.size.z))
	print("Largest dimension: %.2f meters" % max_dimension)

	if max_dimension > 20:
		var suggested_scale := 10.0 / max_dimension
		print("Model is large. Suggested scale for ~10m size: %.3f" % suggested_scale)
	elif max_dimension < 5:
		var suggested_scale := 10.0 / max_dimension
		print("Model is small. Suggested scale for ~10m size: %.3f" % suggested_scale)

	print("\n=== WRITE TO FILE ===")
	var file := FileAccess.open("res://house_analysis.txt", FileAccess.WRITE)
	if file:
		file.store_line("=== HOUSE MODEL ANALYSIS ===")
		file.store_line("Mesh count: %d" % mesh_count)
		file.store_line("\n=== BOUNDING BOX ===")
		file.store_line("Position: %s" % str(combined_aabb.position))
		file.store_line("Size: %s" % str(combined_aabb.size))
		file.store_line("Center: %s" % str(combined_aabb.get_center()))
		file.store_line("\n=== RECOMMENDATIONS ===")
		file.store_line("Offset to center: %s" % str(offset_to_origin))
		file.store_line("Largest dimension: %.2f meters" % max_dimension)
		file.close()
		print("Analysis written to res://house_analysis.txt")

	print("\n======================")

	instance.free()

func get_all_mesh_instances(node: Node) -> Array:
	var meshes: Array = []

	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		meshes.append_array(get_all_mesh_instances(child))

	return meshes
