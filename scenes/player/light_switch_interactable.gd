class_name LightSwitchInteractable
extends Node3D

## Marks an object as a toggleable light switch

@export var is_on: bool = false

func _ready() -> void:
	# Add parent to light_switch group for easy querying
	if get_parent():
		get_parent().add_to_group("light_switch")
		print("LightSwitchInteractable: Added parent '%s' to light_switch group" % get_parent().name)

		var indicator: InteractableIndicator = get_parent().find_child("InteractableIndicator", false, false)
		if indicator:
			print("LightSwitchInteractable: Found indicator on parent")
		else:
			push_warning("LightSwitchInteractable: No InteractableIndicator found on parent")

func toggle() -> void:
	is_on = !is_on
	print("Light switch toggled: ", "ON" if is_on else "OFF")
