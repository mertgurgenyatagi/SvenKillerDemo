class_name CarSpawner
extends Node3D

## Attach to the scene root (StreetPrototype). Cars live under CarPool/.
##
## Every spawn_interval seconds, checks the player's Z position:
##   Z < player_z_threshold  → activates a random SP2 car (z ≈ 192), travels in −Z.
##   Z ≥ player_z_threshold  → activates a random SP1 car (z ≈ −64), travels in +Z.
##
## SP2 cars begin a continuous right-hand curve once they cross turn_trigger_z.
## All active cars are recycled (full transform reset) after car_lifetime seconds.

@export var spawn_interval: float = 10.0
@export var car_speed: float = 15.0
@export var car_lifetime: float = 20.0
@export var player_z_threshold: float = 74.0

## Z value at which SP2 cars (travelling in −Z) begin their right-hand curve.
@export var turn_trigger_z: float = 30
## Continuous turn rate in degrees per second once the curve begins.
@export var turn_rate_deg: float = 13.0

@onready var _car1_sp1: Node3D = $CarPool/Car1SP1
@onready var _car2_sp1: Node3D = $CarPool/Car2SP1
@onready var _car1_sp2: Node3D = $CarPool/Car1SP2
@onready var _car2_sp2: Node3D = $CarPool/Car2SP2

# Full initial transforms — restoring these on expiry resets position, rotation, and scale.
var _spawn_transforms: Dictionary = {}

# Active cars. Each entry: { node: Node3D, dir_vec: Vector3, turning: bool, elapsed: float }
var _active_cars: Array[Dictionary] = []
var _active_nodes: Array[Node3D] = []

var _spawn_timer: float = 0.0


func _ready() -> void:
	for car: Node3D in [_car1_sp1, _car2_sp1, _car1_sp2, _car2_sp2]:
		if not car:
			push_error("CarSpawner: one or more car nodes not found under CarPool/")
			return
		_spawn_transforms[car] = car.transform


func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= spawn_interval:
		_spawn_timer = 0.0
		_try_activate_car()

	_step_cars(delta)


func _try_activate_car() -> void:
	var player: Node3D = _find_player()
	if not player:
		push_warning("CarSpawner: player not found — skipping spawn tick")
		return

	var pz: float = player.global_position.z
	var candidates: Array[Node3D]
	var initial_dir: Vector3

	if pz < player_z_threshold:
		# Player in the lower-Z half — send an SP2 car from z ≈ 192, moving in −Z.
		candidates = [_car1_sp2, _car2_sp2]
		initial_dir = Vector3(0.0, 0.0, -1.0)
	else:
		# Player in the upper-Z half — send an SP1 car from z ≈ −64, moving in +Z.
		candidates = [_car1_sp1, _car2_sp1]
		initial_dir = Vector3(0.0, 0.0, 1.0)

	# Only pick from cars not already in motion.
	var available: Array[Node3D] = []
	for car: Node3D in candidates:
		if car not in _active_nodes:
			available.append(car)

	if available.is_empty():
		return

	var car: Node3D = available[randi() % available.size()]
	_active_nodes.append(car)
	_active_cars.append({
		"node":     car,
		"dir_vec":  initial_dir,
		"turning":  false,
		"elapsed":  0.0,
	})


func _step_cars(delta: float) -> void:
	var turn_step: float = deg_to_rad(turn_rate_deg) * delta
	var to_remove: Array[Dictionary] = []

	for car_data: Dictionary in _active_cars:
		var car: Node3D = car_data["node"]
		car_data["elapsed"] += delta

		if car_data["elapsed"] >= car_lifetime:
			to_remove.append(car_data)
			continue

		var dir_vec: Vector3 = car_data["dir_vec"]

		if not car_data["turning"]:
			car.position += dir_vec * car_speed * delta

			# SP2 cars (dir_vec.z < 0) begin curving once they cross turn_trigger_z.
			if dir_vec.z < 0.0 and car.position.z <= turn_trigger_z:
				car_data["turning"] = true
		else:
			# Rotate movement vector clockwise around Y = right-hand turn.
			# Negative angle on Vector3.rotated = clockwise for a −Z-facing car.
			dir_vec = dir_vec.rotated(Vector3.UP, -turn_step)
			car_data["dir_vec"] = dir_vec
			car.position += dir_vec * car_speed * delta

			# Match the car's visual orientation to the updated heading.
			# Positive rotate_y is consistent with the negative rotated() above —
			# both resolve to the same world-space direction.
			car.rotate_y(-turn_step)

	for item: Dictionary in to_remove:
		var car: Node3D = item["node"]
		car.transform = _spawn_transforms[car]
		_active_nodes.erase(car)
		_active_cars.erase(item)


func _find_player() -> Node3D:
	var group: Array[Node] = get_tree().get_nodes_in_group("player")
	if not group.is_empty():
		return group[0] as Node3D
	return get_tree().root.find_child("Player", true, false) as Node3D
