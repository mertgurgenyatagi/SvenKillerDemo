class_name CarSpawner
extends Node3D

## Car pooling system: reuses car instances instead of instantiating/destroying.
## Pre-place car instances as children of this node with names "Car_1", "Car_2", etc.
## The spawner will manage activation based on player position and recycle via teleporting.

@export var spawn_interval: float = 10.0
@export var car_speed: float = 15.0  # m/s
@export var despawn_z_min: float = -50.0
@export var despawn_z_max: float = 200.0
@export var player_z_threshold: float = 74.0

@onready var spawn_point_1: Node3D = get_node_or_null("../CarSpawnPoint1")
@onready var spawn_point_2: Node3D = get_node_or_null("../CarSpawnPoint2")

## Pooled car data: {node, active, direction}
var car_pool: Array[Dictionary] = []
var spawn_timer: float = 0.0


func _ready() -> void:
	if not spawn_point_1 or not spawn_point_2:
		push_error("CarSpawner: CarSpawnPoint1 or CarSpawnPoint2 not found")
		return

	# Find all existing car children (look for nodes with "Car" in name)
	for child in get_children():
		if child is Node3D and "Car" in child.name:
			# Initialize pooled car
			car_pool.append({
				"node": child,
				"active": false,
				"direction": 0,
			})
			# Park inactive cars at z_max
			child.position.z = despawn_z_max

	if car_pool.is_empty():
		push_warning("CarSpawner: No car nodes found as children. Add car instances with names containing 'Car'")


func _process(delta: float) -> void:
	# Spawn timer
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_activate_car()

	# Update active cars
	for car_data in car_pool:
		if not car_data["active"]:
			continue

		var car: Node3D = car_data["node"]
		var direction: int = car_data["direction"]

		# Move car
		car.position.z += direction * car_speed * delta

		# Recycle: teleport back to opposite boundary when crossing despawn line
		if direction > 0 and car.position.z > despawn_z_max:
			# Moving forward (z+), crossed max boundary — reset to min
			car.position.z = despawn_z_min
		elif direction < 0 and car.position.z < despawn_z_min:
			# Moving backward (z-), crossed min boundary — reset to max
			car.position.z = despawn_z_max


func _activate_car() -> void:
	var player: Node3D = _find_player()
	if not player:
		return

	# Determine spawn point and direction based on player position
	var direction: int
	var spawn_point: Node3D

	if player.global_position.z < player_z_threshold:
		# Player in front half - activate car at point 1, move forward (z+)
		spawn_point = spawn_point_1
		direction = 1
	else:
		# Player in back half - activate car at point 2, move backward (z-)
		spawn_point = spawn_point_2
		direction = -1

	if not spawn_point:
		return

	# Find an inactive car from the pool
	var car_data: Dictionary
	var found: bool = false
	for pool_entry in car_pool:
		if not pool_entry["active"]:
			car_data = pool_entry
			found = true
			break

	if not found:
		return

	# Activate the car
	var car: Node3D = car_data["node"]
	car.global_position = spawn_point.global_position
	car_data["active"] = true
	car_data["direction"] = direction


func _find_player() -> Node3D:
	# Quick search in root children first
	var root: Node = get_tree().get_root()
	for child in root.get_children():
		if child is CharacterBody3D and child.name == "Player":
			return child

	# Fallback: search entire tree
	var stack: Array = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is CharacterBody3D and node.name == "Player":
			return node
		for c in node.get_children():
			stack.append(c)

	return null
