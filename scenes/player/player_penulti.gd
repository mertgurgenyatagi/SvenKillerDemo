extends "res://scenes/player/player_house.gd"

## Penulti scene player — adds position-based sand footstep detection
## and an E-key block that penulti_boot controls.

## When true, the interact key does nothing. Set by penulti_boot.gd
## at GR and cleared when the worldenv transition finishes.
var e_blocked: bool = false

## When true, WASD is disabled and the player walks automatically in -x.
## Set by penulti_boot.gd when the player crosses x = -64.
var auto_walk: bool = false


func _physics_process(delta: float) -> void:
	if auto_walk:
		_do_auto_walk(delta)
		return

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


func _do_auto_walk(delta: float) -> void:
	## Drives the player forward in -x at full walk speed, ignoring all WASD input.
	## Mouse look continues to work because _input() is untouched.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Face precisely in the -x world direction (visuals yaw = PI/2).
	visuals.rotation.y = lerp_angle(visuals.rotation.y, PI / 2.0, turn_lerp * delta)

	current_speed = speed
	velocity.x = -speed
	velocity.z = 0.0

	if animation_tree:
		var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
		if playback.get_current_node() != "locomotion":
			playback.travel("locomotion")
		animation_tree.set("parameters/locomotion/blend_position", 1.0)

	footstep_timer += delta
	if footstep_timer >= footstep_interval:
		footstep_timer = 0.0
		_play_footstep()

	move_and_slide()


func _handle_interact() -> void:
	if e_blocked:
		return
	super._handle_interact()
