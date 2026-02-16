class_name HouseLightSwitchInteractable
extends Node3D

## Marks an object as a light switch that can be toggled.
## Attach this to a light switch object or invisible interaction point.

@export var light_node_path: NodePath
@export var is_on: bool = false

var light_node: Light3D = null

func _ready() -> void:
	# Add to lightswitch group for easy querying
	if get_parent():
		get_parent().add_to_group("lightswitch")
		var indicator: InteractableIndicator = get_parent().find_child("InteractableIndicator", false, false)
		if indicator:
			indicator.y_offset = 0.3

	# Find the light node if path is set
	if light_node_path and has_node(light_node_path):
		light_node = get_node(light_node_path)

func interact() -> void:
	toggle_light()

func toggle_light() -> void:
	is_on = !is_on

	if light_node:
		light_node.visible = is_on

	# Play light switch sound effect here when available
	print("Light switch toggled: ", "ON" if is_on else "OFF")

func set_light_state(state: bool) -> void:
	is_on = state
	if light_node:
		light_node.visible = is_on
