extends Node3D

# Minimal boot helper: press 'E' while scene runs hidden if preloaded.

@export var enabled: bool = true
@export var background_preload: bool = false

var _hidden_visuals: Array = []
var _stopped_audio_players: Array = []

func _ready() -> void:
	# Begin loading the street scene in the background immediately so it's ready by the time
	# the player reaches the front door.
	GameManager.start_background_preload("res://scenes/street_prototype.tscn")

	# When loaded normally (not as a background preload), start ambient audio now.
	if not background_preload:
		_start_ambient_audio()
		_trigger_mission_statement()

	# Small delay so autoloads and child nodes initialize
	if not enabled:
		return
	await get_tree().create_timer(0.12).timeout

	var player = _find_player()
	if not player:
		push_warning("sven_house_boot: Player not found")
		return

	# (No immediate interact here — sequence will press E at step 5)

	# Determine mouse sensitivity (fallback to reasonable default)
	var sens: float = 0.003
	if player.has_method("mouse_sensitivity"):
		# some player variants expose this as a property
		sens = player.mouse_sensitivity if player.mouse_sensitivity != null else sens
	elif player.has_meta("mouse_sensitivity"):
		sens = player.get_meta("mouse_sensitivity")


	# Sequence requested by user:
	# 1) Rotate horizontal 220 degrees over 2 seconds.
	await _send_mouse_motion_over(player, sens, 160.0, 0.0, 2.0)

	# 2) Wait 2 seconds.
	await get_tree().create_timer(2.0).timeout

	# 3) Mouse up 30 degrees over 2 seconds.
	await _send_mouse_motion_over(player, sens, 0.0, 30.0, 2.0)

	# 4) Wait 2 seconds.
	await get_tree().create_timer(2.0).timeout

	# 5) Press "E".
	if player.has_method("_handle_interact"):
		player._handle_interact()
	else:
		if InputMap.has_action("interact"):
			Input.action_press("interact")
			await get_tree().create_timer(0.12).timeout
			Input.action_release("interact")

	# 6) Wait 8 seconds.
	await get_tree().create_timer(8.0).timeout

	# 7) Mouse down 30 degrees over the course of 2 seconds.
	await _send_mouse_motion_over(player, sens, 0.0, -30.0, 2.0)

	# 8) Stop — sequence complete.

	# Disable further player input while scene is hidden/preloading
	if player.has_method("set_process_input"):
		player.set_process_input(false)

	if background_preload:
		_apply_background_hide()

func _find_player() -> Node:
	# Try direct child first
	var p = get_node_or_null("Player")
	if p:
		return p

	# Manual subtree search (scene-local)
	var stack = [self]
	while stack.size() > 0:
		var node = stack.pop_back()
		if node.name == "Player":
			return node
		for child in node.get_children():
			stack.append(child)

	# Search root children safely (Window is root; it doesn't implement find_node)
	for rc in get_tree().get_root().get_children():
		if rc and rc.has_method("find_node"):
			var found = rc.find_node("Player", true, false)
			if found:
				return found

	return null

func _apply_background_hide() -> void:
	_hidden_visuals.clear()
	_stopped_audio_players.clear()

	# Walk this subtree and hide MeshInstance3D nodes and stop Audio players
	var nodes = [self]
	while nodes.size() > 0:
		var n = nodes.pop_back()
		for child in n.get_children():
			nodes.append(child)
		if n is MeshInstance3D:
			if n.visible:
				_hidden_visuals.append(n)
				n.visible = false
		if n is AudioStreamPlayer or n is AudioStreamPlayer3D:
			if n.playing:
				_stopped_audio_players.append(n)
				n.stop()


## Helper: send mouse motion to a player node using a given sensitivity
func _send_mouse_motion_to(player: Node, sens: float, dx_deg: float, dy_deg: float = 0.0) -> void:
	var ev := InputEventMouseMotion.new()
	var dx_rad: float = deg_to_rad(dx_deg)
	var dy_rad: float = deg_to_rad(dy_deg)
	# Convert radians to input relative using sensitivity
	ev.relative = Vector2(dx_rad / sens, dy_rad / sens)
	if player and player.has_method("_input"):
		player._input(ev)


## Smoothly send mouse motion over `duration` seconds by sending incremental relative motions each frame.
func _send_mouse_motion_over(player: Node, sens: float, total_dx_deg: float, total_dy_deg: float, duration: float) -> void:
	if duration <= 0.0:
		_send_mouse_motion_to(player, sens, total_dx_deg, total_dy_deg)
		return

	var elapsed: float = 0.0
	while elapsed < duration:
		# Wait a frame then measure delta
		await get_tree().process_frame
		var dt: float = get_process_delta_time()
		elapsed += dt
		var frac: float = clampf(dt / duration, 0.0, 1.0)
		var step_dx: float = total_dx_deg * frac
		var step_dy: float = total_dy_deg * frac
		_send_mouse_motion_to(player, sens, step_dx, step_dy)


func reveal_scene() -> void:
	# Restore visuals
	for mi in _hidden_visuals:
		if is_instance_valid(mi):
			mi.visible = true
	_hidden_visuals.clear()

	# Restart audio players that were stopped
	for ap in _stopped_audio_players:
		if is_instance_valid(ap):
			ap.play()
	_stopped_audio_players.clear()

	# Start ambient audio now that the scene is visible
	_start_ambient_audio()
	_trigger_mission_statement()

	# Re-enable player input
	var player = _find_player()
	if player and player.has_method("set_process_input"):
		player.set_process_input(true)


func _start_ambient_audio() -> void:
	for node in get_tree().get_nodes_in_group("house_ambient_audio"):
		if (node is AudioStreamPlayer or node is AudioStreamPlayer3D) and not node.playing:
			node.play()

	for node in get_tree().get_nodes_in_group("house_ambient_scripts"):
		if node.has_method("start"):
			node.start()

	background_preload = false


func _trigger_mission_statement() -> void:
	for node in get_tree().get_nodes_in_group("mission_statement"):
		if node.has_method("show_after_delay"):
			node.show_after_delay()
