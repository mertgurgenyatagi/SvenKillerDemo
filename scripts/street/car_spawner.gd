class_name CarSpawner
extends Node3D

## Simple car spawner: pick a car from the player's current spawn point every 10 seconds.
## 4 pre-placed cars: 2 at SpawnPoint1, 2 at SpawnPoint2.
## Cars move along z-axis and recycle when crossing boundaries.

@export var spawn_interval: float = 10.0
@export var car_speed: float = 15.0
@export var despawn_z_min: float = -200.0
@export var despawn_z_max: float = 100.0
@export var player_z_threshold: float = 74.0

@onready var spawn_point_1: Node3D = get_node_or_null("../CarSpawnPoint1")
@onready var spawn_point_2: Node3D = get_node_or_null("../CarSpawnPoint2")

## Cars at each spawn point: [car1, car2] for point 1, [car1, car2] for point 2
var cars_at_point_1: Array[Node3D] = []
var cars_at_point_2: Array[Node3D] = []

## Active cars: {node, direction}
var active_cars: Array[Dictionary] = []
var spawn_timer: float = 0.0


func _ready() -> void:
	if not spawn_point_1 or not spawn_point_2:
		push_error("CarSpawner: CarSpawnPoint1 or CarSpawnPoint2 not found")
		return

	# Directly reference named car nodes (nested under CarPool)
	var car1_sp1 = get_node_or_null("CarPool/Car1SP1")
	var car2_sp1 = get_node_or_null("CarPool/Car2SP1")
	var car1_sp2 = get_node_or_null("CarPool/Car1SP2")
	var car2_sp2 = get_node_or_null("CarPool/Car2SP2")

	if car1_sp1:
		cars_at_point_1.append(car1_sp1)
	else:
		push_warning("CarSpawner: Car1SP1 not found")

	if car2_sp1:
		cars_at_point_1.append(car2_sp1)
	else:
		push_warning("CarSpawner: Car2SP1 not found")

	if car1_sp2:
		cars_at_point_2.append(car1_sp2)
	else:
		push_warning("CarSpawner: Car1SP2 not found")

	if car2_sp2:
		cars_at_point_2.append(car2_sp2)
	else:
		push_warning("CarSpawner: Car2SP2 not found")


func _process(delta: float) -> void:
	# Spawn timer
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_activate_car()

	# Update active cars
	for car_data in active_cars:
		var car: Node3D = car_data["node"]
		var direction: int = car_data["direction"]

		# Move car
		car.position.z += direction * car_speed * delta

		# Recycle: teleport back when crossing boundaries
		if direction > 0 and car.position.z > despawn_z_max:
			car.position.z = despawn_z_min
		elif direction < 0 and car.position.z < despawn_z_min:
			car.position.z = despawn_z_max


func _activate_car() -> void:
	var player: Node3D = _find_player()
	if not player:
		return

	var spawn_point: Node3D
	var direction: int
	var available_cars: Array[Node3D]

	if player.global_position.z < player_z_threshold:
		# Player in front — spawn from point 1, move forward (z+)
		spawn_point = spawn_point_1
		direction = 1
		available_cars = cars_at_point_1
	else:
		# Player in back — spawn from point 2, move backward (z-)
		spawn_point = spawn_point_2
		direction = -1
		available_cars = cars_at_point_2

	if available_cars.is_empty():
		return

	# Pick a random car from the available cars
	var car: Node3D = available_cars[randi() % available_cars.size()]
	car.global_position = spawn_point.global_position

	# Track as active
	active_cars.append({
		"node": car,
		"direction": direction,
	})


func _find_player() -> Node3D:
	var root: Node = get_tree().get_root()
	for child in root.get_children():
		if child is CharacterBody3D and child.name == "Player":
			return child

	var stack: Array = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		if node is CharacterBody3D and node.name == "Player":
			return node
		for c in node.get_children():
			stack.append(c)

	return null
