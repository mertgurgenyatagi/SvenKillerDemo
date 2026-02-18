class_name LightSwitch
extends Node3D

## Marks an object as a toggleable light switch

@export var is_on: bool = true  # Lights start on by default
@export var light_group: String = "house_lights"  ## Which group of lights this switch controls
@export var hum_volume_on: float = 0.0  ## Volume in dB when lights are on
@export var hum_volume_off: float = -12.0  ## Volume in dB when lights are off (~25%)
@export var hum_fade_time: float = 0.2  ## Seconds to fade hum volume

var indicator: InteractableIndicator = null
var can_interact: bool = true
var controlled_lights: Array[Light3D] = []
var original_light_energies: Dictionary = {}  # Store original energy values
var hum_player: AudioStreamPlayer
var hum_tween: Tween

func _ready() -> void:
	# Add parent to light_switch group for easy querying
	if get_parent():
		get_parent().add_to_group("light_switch")
		indicator = get_parent().find_child("InteractableIndicator", false, false)
		if not indicator:
			push_warning("LightSwitch: No InteractableIndicator found on parent")

	# Set up audio
	_setup_audio()

	# Find all lights in the specified group
	_find_controlled_lights()

	# Set initial light state
	_update_lights()

func _setup_audio() -> void:
	# House hum ambient loop (non-spatial, heard everywhere)
	hum_player = AudioStreamPlayer.new()
	hum_player.stream = AudioManager.get_audio_stream(AudioManager.AudioID.HOUSE_HUM)
	hum_player.bus = "SFX"
	hum_player.volume_db = hum_volume_on if is_on else hum_volume_off
	hum_player.autoplay = true
	add_child(hum_player)

	# Ensure the hum loops
	var hum_stream = hum_player.stream
	if hum_stream is AudioStreamOggVorbis:
		hum_stream.loop = true

func _find_controlled_lights() -> void:
	controlled_lights.clear()
	original_light_energies.clear()

	for node in get_tree().get_nodes_in_group(light_group):
		if node is Light3D:
			controlled_lights.append(node)
			# Store original energy value
			original_light_energies[node] = node.light_energy

func _update_lights() -> void:
	for light in controlled_lights:
		if is_on:
			# Restore original energy
			if light in original_light_energies:
				light.light_energy = original_light_energies[light]
		else:
			# Turn off light
			light.light_energy = 0.0

func _flicker_on() -> void:
	# Brief flicker sequence before lights settle on
	var flicker_steps: Array = [
		{"energy_mult": 0.3, "duration": 0.04},
		{"energy_mult": 0.3, "duration": 0.04},
		{"energy_mult": 0.1, "duration": 0.04},
		{"energy_mult": 0.8, "duration": 0.04},
		{"energy_mult": 0.4, "duration": 0.04},
		{"energy_mult": 1.0, "duration": 0.0},
	]

	for step in flicker_steps:
		for light in controlled_lights:
			if light in original_light_energies:
				light.light_energy = original_light_energies[light] * step["energy_mult"]
		if step["duration"] > 0.0:
			await get_tree().create_timer(step["duration"]).timeout

func toggle() -> void:
	if not can_interact:
		return

	can_interact = false
	is_on = !is_on

	# Play switch click SFX
	AudioManager.play_3d_sfx(AudioManager.AudioID.LIGHTSWITCH, global_position)

	# Update lights (with flicker on turn-on)
	if is_on:
		await _flicker_on()
	else:
		_update_lights()

	# Tween hum volume over 0.2 seconds
	if hum_tween:
		hum_tween.kill()
	hum_tween = create_tween()
	var target_db: float = hum_volume_on if is_on else hum_volume_off
	hum_tween.tween_property(hum_player, "volume_db", target_db, hum_fade_time)

	# Fade out indicator
	if indicator and indicator.has_method("fade_out"):
		indicator.fade_out()

	# Wait 1 second, then fade back in
	await get_tree().create_timer(1.0).timeout

	can_interact = true
	if indicator and indicator.has_method("fade_in"):
		indicator.fade_in()
