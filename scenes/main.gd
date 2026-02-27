extends Node

## Main scene - handles splash screen and initializes game

@onready var splash_screen: CanvasLayer = $SplashScreen
@onready var splash_background: ColorRect = $SplashScreen/Background
@onready var splash_logo: TextureRect = $SplashScreen/Logo
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var transition_fade: ColorRect = $TransitionLayer/Fade

const MAIN_MENU_PATH = "res://scenes/ui/main_menu.tscn"

func _ready() -> void:
	# Initialize GameManager
	GameManager.initialize(self)
	
	# Set up initial state - everything black, logo invisible
	splash_screen.visible = true
	splash_screen.layer = 10  # Above everything
	splash_background.color = Color.BLACK
	splash_logo.modulate.a = 0.0
	splash_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	# Hide the transition layer during splash (we'll use it later)
	transition_layer.visible = false
	
	# Start the sequence
	run_splash_sequence()

func run_splash_sequence() -> void:
	# Wait a moment in darkness
	await get_tree().create_timer(0.8).timeout
	
	# Fade in logo
	var tween1 = create_tween()
	tween1.tween_property(splash_logo, "modulate:a", 1.0, 2.0).set_ease(Tween.EASE_IN_OUT)
	await tween1.finished
	
	# Hold on logo
	await get_tree().create_timer(2.5).timeout
	
	# Fade out logo
	var tween2 = create_tween()
	tween2.tween_property(splash_logo, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN_OUT)
	await tween2.finished
	
	# Brief pause in darkness
	await get_tree().create_timer(0.5).timeout
	
	# Now load the main menu BEFORE we transition
	var menu_scene = load(MAIN_MENU_PATH).instantiate()
	$CurrentScene.add_child(menu_scene)
	GameManager.current_scene = menu_scene
	
	# Hide splash screen to reveal the menu underneath
	# But first set up transition layer to be black
	transition_fade.color = Color(0, 0, 0, 1)
	transition_layer.visible = true
	transition_layer.layer = 200  # Above all UI, subtitles, and effects
	
	# Now hide splash
	splash_screen.visible = false
	
	# Slowly fade out the black to reveal menu
	var tween3 = create_tween()
	tween3.tween_property(transition_fade, "color:a", 0.0, 2.5).set_ease(Tween.EASE_OUT)
	await tween3.finished
