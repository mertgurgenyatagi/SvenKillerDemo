@tool
extends Node3D

## Generates collision shapes for all mesh instances in the house model
## Set generate_on_ready to true to auto-generate at runtime
## Or call generate_collision() manually

@export var generate_on_ready: bool = true
@export var collision_layer: int = 1  # Layer 1: World/Environment
@export var collision_mask: int = 0   # Static objects don't need to detect anything
@export var use_trimesh: bool = true  # Trimesh for accurate collision, or convex for performance

var static_body: StaticBody3D

func _ready() -> void:
	if generate_on_ready:
		generate_collision()

func generate_collision() -> void:
	# Remove any existing collision
	if static_body:
		static_body.queue_free()
		static_body = null

	# Find the HouseModel node
	var house_model: Node3D = get_parent().get_node_or_null("HouseModel")

	if not house_model:
		push_error("HouseModel node not found")
		return

	# Check if HouseModel already has a StaticBody3D
	var existing_static_body: StaticBody3D = null
	for child in house_model.get_children():
		if child is StaticBody3D:
			existing_static_body = child
			break

	# Remove existing collision if present
	if existing_static_body:
		existing_static_body.queue_free()

	# Create a StaticBody3D as a child of HouseModel
	# This way it inherits the HouseModel's transform automatically
	static_body = StaticBody3D.new()
	static_body.name = "HouseCollision"
	static_body.collision_layer = collision_layer
	static_body.collision_mask = collision_mask

	# Add as child of HouseModel so it inherits transform
	house_model.add_child(static_body)

	# Find all MeshInstance3D nodes and create collision for them
	var mesh_instances := get_all_mesh_instances(house_model)
	var collision_count := 0

	print("Generating collision for %d mesh instances..." % mesh_instances.size())

	for mesh_instance in mesh_instances:
		if mesh_instance is MeshInstance3D:
			var mesh_inst: MeshInstance3D = mesh_instance
			var mesh: Mesh = mesh_inst.mesh

			if not mesh:
				continue

			# Create collision shape
			var collision_shape := CollisionShape3D.new()
			collision_shape.name = "Collision_%s" % mesh_inst.name

			# Create shape based on preference
			var shape: Shape3D
			if use_trimesh:
				shape = mesh.create_trimesh_shape()
			else:
				shape = mesh.create_convex_shape()

			if not shape:
				continue

			collision_shape.shape = shape

			# Add to static body
			static_body.add_child(collision_shape)

			# Set transform RELATIVE to the static body (which is inside HouseModel)
			# Calculate the local transform relative to HouseModel
			var local_transform := mesh_inst.transform

			# Walk up the tree to accumulate transforms until we reach HouseModel
			var current_node := mesh_inst.get_parent()
			while current_node != null and current_node != house_model:
				if current_node is Node3D:
					local_transform = current_node.transform * local_transform
				current_node = current_node.get_parent()

			collision_shape.transform = local_transform
			collision_count += 1

	print("Generated %d collision shapes for house" % collision_count)

	# In editor, make sure to set owner so it gets saved
	if Engine.is_editor_hint():
		static_body.owner = get_tree().edited_scene_root

func get_all_mesh_instances(node: Node) -> Array:
	var meshes: Array = []

	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		meshes.append_array(get_all_mesh_instances(child))

	return meshes

## Call this from editor or code to regenerate collision
func regenerate() -> void:
	generate_collision()
