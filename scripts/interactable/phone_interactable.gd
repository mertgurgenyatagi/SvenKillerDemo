class_name PhoneInteractable
extends Node3D

## Marks an object as a phone that can be interacted with.
## Attach this to a phone object or invisible interaction point.

var is_active: bool = true

func _ready() -> void:
	# Add to phone group for easy querying
	if get_parent():
		get_parent().add_to_group("phone")
		var indicator: InteractableIndicator = get_parent().find_child("InteractableIndicator", false, false)
		if indicator:
			indicator.y_offset = 0.3

func interact() -> void:
	if not is_active:
		return

	# Phone interaction logic will go here
	print("Phone interacted!")

func set_active(active: bool) -> void:
	is_active = active
