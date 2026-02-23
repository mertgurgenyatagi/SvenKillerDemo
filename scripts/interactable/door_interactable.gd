class_name DoorInteractable
extends Node3D

## Marks an object as an interactable door.
## On interact: plays door SFX, waits 1.5s, then triggers a hard cut to the target scene.

@export var target_scene: String = "res://scenes/street_prototype.tscn"
@export var door_sfx_path: String = "res://assets/audio/sfx/interactions/door_open_front.ogg"

var indicator: InteractableIndicator = null
var can_interact: bool = true


func _ready() -> void:
	if get_parent():
		get_parent().add_to_group("door")
		indicator = get_parent().find_child("InteractableIndicator", false, false)
		if not indicator:
			push_warning("DoorInteractable: No InteractableIndicator found on parent")


func open() -> void:
	if not can_interact:
		return

	can_interact = false

	if indicator and indicator.has_method("fade_out"):
		indicator.fade_out()

	_play_door_sfx()

	# Wait 1.5s before hard cut
	await get_tree().create_timer(1.5).timeout

	# Hand off to GameManager — its coroutine runs independently after this call returns,
	# so it survives the current scene being freed.
	GameManager.hard_cut_to_scene(target_scene)


func _play_door_sfx() -> void:
	if not FileAccess.file_exists(door_sfx_path):
		push_warning("DoorInteractable: SFX not found: %s" % door_sfx_path)
		return

	var stream: AudioStream = load(door_sfx_path)
	if not stream:
		return

	# Local player — the Master bus mute in hard_cut_to_scene() silences it at cut time.
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.play()
