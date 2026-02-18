extends "res://scenes/player/player.gd"

## House version of player controller with zoom disabled

func _ready() -> void:
	super._ready()
	# Lock zoom to default spring arm length
	zoom_min = spring_arm.spring_length
	zoom_max = spring_arm.spring_length

func _physics_process(delta: float) -> void:
	# Store the target zoom before calling parent
	var default_zoom = spring_arm.spring_length

	# Call parent physics process
	super._physics_process(delta)

	# Force target zoom back to default (disables zoom scrolling)
	target_zoom = default_zoom
