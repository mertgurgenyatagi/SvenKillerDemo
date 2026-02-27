extends Node

## Plays car_passing.ogg whenever a car's Z comes within 90 units of the player.
## Stacks: each car triggers its own independent playback.

const STREAM: AudioStream = preload("res://assets/audio/sfx/npc/car_passing.ogg")
const TRIGGER_Z: float = 90.0

var _car_spawner: CarSpawner = null
var _triggered: Dictionary = {}  # car_instance_id → true


func _ready() -> void:
	_car_spawner = get_parent() as CarSpawner


func _process(_delta: float) -> void:
	if not _car_spawner:
		return
	var player: Node3D = _find_player()
	if not player:
		return

	var pz: float = player.global_position.z

	for car_data: Dictionary in _car_spawner._active_cars:
		var car: Node3D = car_data["node"]
		var car_id: int = car.get_instance_id()

		if absf(car.global_position.z - pz) <= TRIGGER_Z:
			if car_id not in _triggered:
				_triggered[car_id] = true
				_play()
		else:
			_triggered.erase(car_id)


func _play() -> void:
	var ap := AudioStreamPlayer.new()
	add_child(ap)
	ap.stream = STREAM
	# Ensure the car passing is heard at desired level
	ap.volume_db = -2.0
	ap.play()
	ap.finished.connect(ap.queue_free)


func _find_player() -> Node3D:
	var group: Array[Node] = get_tree().get_nodes_in_group("player")
	if not group.is_empty():
		return group[0] as Node3D
	return get_tree().root.find_child("Player", true, false) as Node3D
