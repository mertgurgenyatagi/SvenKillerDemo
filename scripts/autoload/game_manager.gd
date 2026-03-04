extends Node

## Handles game state and scene management

signal scene_changed(scene_name: String)
signal transition_started
signal transition_finished

enum GameState { SPLASH, MENU, PLAYING, PAUSED }

var current_state: GameState = GameState.SPLASH
var current_scene: Node = null
var main_node: Node = null
var transition_fade: ColorRect = null
var preloaded_scene: Node = null
var _fallback_black_layer: CanvasLayer = null  # Created if original fade is destroyed

# Background preload tracking
const PRELOAD_MINIMUM_SECONDS: float = 15.0
var _preload_scene_path: String = ""
var _preload_start_time: float = -1.0

# Subtitle slot tracking — ensures overlapping subtitles stack top/bottom
var _subtitle_bottom_owner: Object = null

func claim_subtitle_bottom(owner: Object) -> bool:
	## Returns true if the caller owns the bottom slot (show at bottom).
	## Returns false if another system already owns it (show at top instead).
	if _subtitle_bottom_owner == null or not is_instance_valid(_subtitle_bottom_owner):
		_subtitle_bottom_owner = owner
		return true
	return _subtitle_bottom_owner == owner

func release_subtitle_bottom(owner: Object) -> void:
	if _subtitle_bottom_owner == owner:
		_subtitle_bottom_owner = null

func _ready() -> void:
	# We'll grab references after main.tscn loads
	pass

func initialize(main: Node) -> void:
	## Called by Main scene to set up references.
	main_node = main
	var transition_layer = main.get_node_or_null("TransitionLayer")
	if transition_layer:
		transition_fade = transition_layer.get_node_or_null("Fade")

func change_scene(scene_path: String, fade_duration: float = 0.5) -> void:
	## Change to a new scene with fade transition.
	emit_signal("transition_started")
	
	# Fade out
	await fade_out(fade_duration)
	
	# Remove current scene if exists
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	# Load and add new scene
	var packed_scene = load(scene_path)
	if packed_scene:
		current_scene = packed_scene.instantiate()
		main_node.get_node("CurrentScene").add_child(current_scene)
	
	# Fade in
	await fade_in(fade_duration)
	
	emit_signal("transition_finished")
	emit_signal("scene_changed", scene_path)

func change_scene_no_fade_out(scene_path: String, fade_in_duration: float = 0.5) -> void:
	## Change to a new scene - only fade in (when already on black).
	emit_signal("transition_started")
	
	# Ensure we're on black
	transition_fade.color.a = 1.0
	
	# Remove current scene if exists
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	# Load and add new scene
	var packed_scene = load(scene_path)
	if packed_scene:
		current_scene = packed_scene.instantiate()
		main_node.get_node("CurrentScene").add_child(current_scene)
	
	# Small delay to let scene initialize
	await main_node.get_tree().create_timer(0.1).timeout
	
	# Fade in slowly
	await fade_in(fade_in_duration)
	
	emit_signal("transition_finished")
	emit_signal("scene_changed", scene_path)

func fade_out(duration: float = 0.5) -> void:
	## Fade to black.
	if not transition_fade:
		return
	var tween = create_tween()
	tween.tween_property(transition_fade, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.5) -> void:
	## Fade from black.
	if not transition_fade:
		return
	var tween = create_tween()
	tween.tween_property(transition_fade, "color:a", 0.0, duration)
	await tween.finished

func start_background_preload(scene_path: String) -> void:
	## Begin background loading of a scene as soon as the player has control.
	## Called from the house scene when the player gains control.
	## The preload is intentionally spread over PRELOAD_MINIMUM_SECONDS.
	if _preload_scene_path == scene_path:
		return  # Already started for this same scene
	if not _preload_scene_path.is_empty():
		# A different scene was being preloaded — replace it with the new request.
		_preload_scene_path = ""
		_preload_start_time = -1.0
	_preload_scene_path = scene_path
	_preload_start_time = Time.get_ticks_msec() / 1000.0
	# use_sub_threads=false: single background thread, minimal performance impact
	ResourceLoader.load_threaded_request(scene_path, "", false)


func hard_cut_to_scene(scene_path: String) -> void:
	## Hard cut to a new scene with no fade.
	## Blacks out instantly, waits for the preload window to elapse (minimum 20s from
	## when the player gained control, minimum 2s from the cut), then pops scene in.
	emit_signal("transition_started")

	# Stop all pooled audio immediately, then mute Master to catch anything else
	AudioManager.stop_all()
	var master_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, true)

	# Clear subtitle slot so new scene starts with a clean state
	_subtitle_bottom_owner = null

	# If stored references are invalid, try to recover or create fallback
	if not is_instance_valid(transition_fade) or not is_instance_valid(main_node):
		_recover_main_references()

	# Instant black — use existing fade or create fallback
	if is_instance_valid(transition_fade):
		var transition_layer = transition_fade.get_parent()
		if transition_layer:
			transition_layer.visible = true
		transition_fade.color = Color.BLACK
		transition_fade.color.a = 1.0
	else:
		_create_fallback_black_overlay()

	# If a preload was started for a DIFFERENT scene (e.g. street was preloaded from the
	# house, but now we need the cafe), reset the stale tracking so we start fresh here.
	if not _preload_scene_path.is_empty() and _preload_scene_path != scene_path:
		_preload_scene_path = ""
		_preload_start_time = -1.0

	# If preload wasn't started proactively (e.g. testing directly), kick it off now.
	# Track whether we started late so we can skip the long minimum-wait below.
	var late_start: bool = _preload_scene_path.is_empty()
	if late_start:
		start_background_preload(scene_path)

	# Free the old scene immediately (we're behind black).
	# Always free both GameManager.current_scene AND get_tree().current_scene when they
	# differ — they can diverge if the native scene switcher (get_tree().change_scene_to_*)
	# was used, leaving GameManager's tracked scene and Godot's tracked scene out of sync.
	var gm_scene: Node = current_scene if is_instance_valid(current_scene) else null
	var tree_scene: Node = get_tree().current_scene

	if gm_scene:
		gm_scene.queue_free()
	if is_instance_valid(tree_scene) and tree_scene != gm_scene:
		tree_scene.queue_free()
	current_scene = null

	# Calculate blackout duration:
	# - Early preload: honour the PRELOAD_MINIMUM_SECONDS window (scene is already loaded)
	# - Late/on-demand start: use minimum 2s — then poll until the load actually finishes
	var blackout_duration: float
	if late_start:
		blackout_duration = 2.0
	else:
		var elapsed: float = Time.get_ticks_msec() / 1000.0 - _preload_start_time
		var remaining: float = maxf(0.0, PRELOAD_MINIMUM_SECONDS - elapsed)
		blackout_duration = maxf(2.0, remaining)

	# Add scene to tree 1 second before the curtain lifts — hidden behind black overlay
	await get_tree().create_timer(blackout_duration - 1.0).timeout

	# Ensure the threaded load has finished before instantiating
	while ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame

	var packed: PackedScene = ResourceLoader.load_threaded_get(scene_path)
	_preload_scene_path = ""
	_preload_start_time = -1.0
	if packed:
		current_scene = packed.instantiate()
		var scene_added: bool = false

		if is_instance_valid(main_node):
			var scene_parent = main_node.get_node_or_null("CurrentScene")
			if scene_parent:
				scene_parent.add_child(current_scene)
				scene_added = true

		if not scene_added:
			get_tree().get_root().add_child(current_scene)

	# Wait the final second, then lift the curtain and restore audio together
	await get_tree().create_timer(1.0).timeout

	AudioServer.set_bus_mute(master_idx, false)
	if is_instance_valid(transition_fade):
		var transparent = Color.BLACK
		transparent.a = 0.0
		transition_fade.color = transparent
	elif is_instance_valid(_fallback_black_layer):
		_fallback_black_layer.visible = false

	emit_signal("transition_finished")
	emit_signal("scene_changed", scene_path)


func _recover_main_references() -> void:
	## Recover Main node and transition_fade if they've been freed.
	## Searches the tree dynamically.
	if not is_instance_valid(main_node):
		var root = get_tree().get_root()
		# Main should be a direct child of root
		for child in root.get_children():
			if child.name == "Main":
				main_node = child
				break

	if not is_instance_valid(transition_fade) and is_instance_valid(main_node):
		var transition_layer = main_node.get_node_or_null("TransitionLayer")
		if transition_layer:
			transition_fade = transition_layer.get_node_or_null("Fade")


func _create_fallback_black_overlay() -> void:
	## Create a temporary black CanvasLayer when the original fade is destroyed.
	if is_instance_valid(_fallback_black_layer):
		# Already created, just ensure it's visible
		_fallback_black_layer.visible = true
		return

	# Create new overlay
	_fallback_black_layer = CanvasLayer.new()
	_fallback_black_layer.layer = 100  # High layer so it's on top

	var black_rect = ColorRect.new()
	black_rect.color = Color.BLACK
	black_rect.anchor_left = 0.0
	black_rect.anchor_top = 0.0
	black_rect.anchor_right = 1.0
	black_rect.anchor_bottom = 1.0
	_fallback_black_layer.add_child(black_rect)

	get_tree().get_root().add_child(_fallback_black_layer)


func hard_cut_to_preinstantiated(scene_node: Node, scene_path: String) -> void:
	## Hard cut to a scene that was pre-instantiated and running hidden in the tree.
	## Identical to hard_cut_to_scene but skips ResourceLoader — the scene_node is
	## already in the tree with visible=false. Reveals it with a standard 1-second blackout.
	if not is_instance_valid(scene_node):
		push_error("GameManager.hard_cut_to_preinstantiated: scene_node is invalid")
		return

	emit_signal("transition_started")

	AudioManager.stop_all()
	var master_idx: int = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, true)

	_subtitle_bottom_owner = null
	_preload_scene_path = ""
	_preload_start_time = -1.0

	if not is_instance_valid(transition_fade) or not is_instance_valid(main_node):
		_recover_main_references()

	if is_instance_valid(transition_fade):
		var transition_layer = transition_fade.get_parent()
		if transition_layer:
			transition_layer.visible = true
		transition_fade.color = Color.BLACK
		transition_fade.color.a = 1.0
	else:
		_create_fallback_black_overlay()

	# Free the old scene (cinema) while we're behind black.
	# Unlike hard_cut_to_scene we deliberately do NOT touch get_tree().current_scene —
	# this game uses GameManager's custom scene system, so current_scene is the only
	# tracked reference. Freeing get_tree().current_scene would free Main's root node.
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	current_scene = scene_node

	# Reveal the pre-instantiated scene and re-enable its camera.
	scene_node.visible = true
	var cam := scene_node.find_child("Camera3D", true, false) as Camera3D
	if cam:
		cam.current = true

	# 2-second curtain — matches the minimum blackout of hard_cut_to_scene.
	await get_tree().create_timer(2.0).timeout

	AudioServer.set_bus_mute(master_idx, false)
	if is_instance_valid(transition_fade):
		var transparent = Color.BLACK
		transparent.a = 0.0
		transition_fade.color = transparent
	elif is_instance_valid(_fallback_black_layer):
		_fallback_black_layer.visible = false

	emit_signal("transition_finished")
	emit_signal("scene_changed", scene_path)


func set_state(new_state: GameState) -> void:
	current_state = new_state
