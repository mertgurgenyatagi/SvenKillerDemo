class_name CarSpawner
extends Node3D

## Car spawning system for street scene.
## Spawns cars based on player position every 10 seconds.
## Cars move along z-axis and despawn at boundaries.

@export var spawn_interval: float = 10.0
@export var car_speed: float = 15.0  # m/s
@export var despawn_z_min: float = -50.0
@export var despawn_z_max: float = 200.0
@export var player_z_threshold: float = 74.0

@onready var spawn_point_1: Node3D = get_node_or_null("../CarSpawnPoint1")
@onready var spawn_point_2: Node3D = get_node_or_null("../CarSpawnPoint2")

var car_models: Array[PackedScene] = [
	preload("res://assets/models/props/car_1.glb"),
	preload("res://assets/models/props/car_2.glb"),
]

var active_cars: Array[Dictionary] = []  # Track spawned cars: {node, direction}
var spawn_timer: float = 0.0


func _ready() -> void:
	if not spawn_point_1 or not spawn_point_2:
		push_error("CarSpawner: CarSpawnPoint1 or CarSpawnPoint2 not found")


func _process(delta: float) -> void:
	# Spawn timer
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_car()

	# Update car positions and clean up despawned cars
	var i: int = active_cars.size() - 1
	while i >= 0:
		var car_data: Dictionary = active_cars[i]
		var car: Node3D = car_data["node"]

		if not is_instance_valid(car):
			active_cars.remove_at(i)
			i -= 1
			continue

		# Move car
		var direction: int = car_data["direction"]  # 1 for z+, -1 for z-
		car.position.z += direction * car_speed * delta

		# Check despawn boundaries
		if car.position.z < despawn_z_min or car.position.z > despawn_z_max:
			car.queue_free()
			active_cars.remove_at(i)

		i -= 1


func _spawn_car() -> void:
	var player: Node3D = _find_player()
	if not player:
		return

	var spawn_point: Node3D
	var direction: int

	if player.global_position.z < player_z_threshold:
		# Player in front half - spawn at point 1, move forward
		spawn_point = spawn_point_1
		direction = 1
	else:
		# Player in back half - spawn at point 2, move backward
		spawn_point = spawn_point_2
		direction = -1

	if not spawn_point:
		return

	# Pick random car model
	var car_model: PackedScene = car_models[randi() % car_models.size()]
	var car_instance: Node3D = car_model.instantiate()

	# Position and add to scene
	car_instance.global_position = spawn_point.global_position
	add_child(car_instance)

	# Track the car
	active_cars.append({
		"node": car_instance,
		"direction": direction,
	})


func _find_player() -> Node3D:
	# Search for player in the scene tree
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
