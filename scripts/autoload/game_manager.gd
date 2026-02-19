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
	transition_fade = main.get_node("TransitionLayer/Fade")

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

func set_state(new_state: GameState) -> void:
	current_state = new_state
