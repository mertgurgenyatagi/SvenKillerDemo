extends "res://scenes/player/player_house.gd"

## Penulti scene player — adds position-based sand footstep detection
## and an E-key block that penulti_boot controls.

## When true, the interact key does nothing. Set by penulti_boot.gd
## at GR and cleared when the worldenv transition finishes.
var e_blocked: bool = false


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var px: float = global_position.x
	var pz: float = global_position.z
	if px > 6.7:
		_on_sand = true
	elif px >= -16.0 and px <= -12.5:
		_on_sand = false
	elif px >= -15.0:
		_on_sand = not (pz >= 23.5 and pz <= 25.0)
	else:
		_on_sand = false


func _handle_interact() -> void:
	if e_blocked:
		return
	super._handle_interact()
