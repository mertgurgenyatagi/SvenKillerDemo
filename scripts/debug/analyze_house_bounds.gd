extends Node

func _ready() -> void:
	analyze_house_bounds()

func analyze_house_bounds() -> void:
	# Get the HouseModel node
	var house_model: Node3D = get_node("/root/SvenHouse/HouseModel")

	if not house_model:
		print("ERROR: HouseModel not found")
		return

	# Calculate combined AABB from all child MeshInstance3D nodes
	var combined_aabb: AABB = AABB()
	var first_mesh := true
	var mesh_count := 0

	# Recursively find all MeshInstance3D nodes
	var meshes := get_all_mesh_instances(house_model)

	print("=== HOUSE MODEL ANALYSIS ===")
	print("Found %d mesh instances" % meshes.size())

	for mesh_instance in meshes:
		if mesh_instance is MeshInstance3D:
			mesh_count += 1
			var mesh: MeshInstance3D = mesh_instance
			var aabb := mesh.get_aabb()

			# Transform AABB to global space
			var global_transform := mesh.global_transform
			var global_aabb := aabb.abs()

			if first_mesh:
				combined_aabb = global_aabb
				first_mesh = false
			else:
				combined_aabb = combined_aabb.merge(global_aabb)

	if mesh_count == 0:
		print("ERROR: No mesh instances found")
		return

	print("\n=== BOUNDING BOX ===")
	print("Position: ", combined_aabb.position)
	print("Size: ", combined_aabb.size)
	print("End: ", combined_aabb.end)
	print("Center: ", combined_aabb.get_center())

	print("\n=== CURRENT TRANSFORM ===")
	print("Position: ", house_model.position)
	print("Rotation: ", house_model.rotation_degrees)
	print("Scale: ", house_model.scale)

	print("\n=== RECOMMENDATIONS ===")
	var center := combined_aabb.get_center()
	var offset_to_origin := -center
	print("To center at origin, offset by: ", offset_to_origin)

	var max_dimension := max(combined_aabb.size.x, max(combined_aabb.size.y, combined_aabb.size.z))
	print("Largest dimension: ", max_dimension, " meters")

	if max_dimension > 20:
		var suggested_scale := 10.0 / max_dimension
		print("Model might be too large. Suggested scale: ", suggested_scale)

	print("\n======================")

func get_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		meshes.append_array(get_all_mesh_instances(child))

	return meshes
