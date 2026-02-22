class_name DoorInteractable
extends Node3D

## Front door interactable. Press E to interact.
## Currently a stub — open/close animation and scene transition implemented later.

var can_interact: bool = true
var indicator: InteractableIndicator = null

func _ready() -> void:
	if get_parent():
		get_parent().add_to_group("door")
		indicator = get_parent().find_child("InteractableIndicator", false, false)
		if not indicator:
			push_warning("DoorInteractable: No InteractableIndicator found on parent")

func activate() -> void:
	if not can_interact:
		return
	# TODO: play door_open_interior SFX, animate door panel, trigger scene transition
	pass
