@tool
extends EditorScript

## One-time script to generate audio_config.tres with all 16 audio entries.
## Run this via: File > Run (with this script open)

func _run() -> void:
	var config: AudioConfig = AudioConfig.new()

	# 0: MENU_HOVER
	var entry_0: AudioEntry = AudioEntry.new()
	entry_0.name = "MENU_HOVER"
	entry_0.path = "res://assets/audio/sfx/interactions/menu_hover.ogg"
	entry_0.volume_db = 0.0
	entry_0.bus = "SFX"
	entry_0.pitch_scale = 1.0
	entry_0.preload_on_startup = true
	entry_0.spatial = false
	config.entries[0] = entry_0

	# 1: MENU_CLICK
	var entry_1: AudioEntry = AudioEntry.new()
	entry_1.name = "MENU_CLICK"
	entry_1.path = "res://assets/audio/sfx/interactions/menu_click.ogg"
	entry_1.volume_db = 0.0
	entry_1.bus = "SFX"
	entry_1.pitch_scale = 1.0
	entry_1.preload_on_startup = true
	entry_1.spatial = false
	config.entries[1] = entry_1

	# 2: AMBIENT_MAIN_MENU
	var entry_2: AudioEntry = AudioEntry.new()
	entry_2.name = "AMBIENT_MAIN_MENU"
	entry_2.path = "res://assets/audio/sfx/ambient/ambient_main_menu.ogg"
	entry_2.volume_db = 0.0
	entry_2.bus = "SFX"
	entry_2.pitch_scale = 1.0
	entry_2.preload_on_startup = false
	entry_2.spatial = false
	config.entries[2] = entry_2

	# 3: MUSIC_MAIN
	var entry_3: AudioEntry = AudioEntry.new()
	entry_3.name = "MUSIC_MAIN"
	entry_3.path = "res://assets/audio/music/sven_killer.ogg"
	entry_3.volume_db = 0.0
	entry_3.bus = "Music"
	entry_3.pitch_scale = 1.0
	entry_3.preload_on_startup = false
	entry_3.spatial = false
	config.entries[3] = entry_3

	# 4: NOE_PROMPT
	var entry_4: AudioEntry = AudioEntry.new()
	entry_4.name = "NOE_PROMPT"
	entry_4.path = "res://assets/audio/sfx/interactions/noe_prompt_sfx.ogg"
	entry_4.volume_db = 4.0
	entry_4.bus = "SFX"
	entry_4.pitch_scale = 1.0
	entry_4.preload_on_startup = true
	entry_4.spatial = false
	config.entries[4] = entry_4

	# 5: HOUSE_HUM
	var entry_5: AudioEntry = AudioEntry.new()
	entry_5.name = "HOUSE_HUM"
	entry_5.path = "res://assets/audio/sfx/ambient/house_hum.ogg"
	entry_5.volume_db = 0.0
	entry_5.bus = "SFX"
	entry_5.pitch_scale = 1.0
	entry_5.preload_on_startup = false
	entry_5.spatial = false
	config.entries[5] = entry_5

	# 6-12: FOOTSTEP_WOOD_1 through FOOTSTEP_WOOD_7
	for i in range(1, 8):
		var entry: AudioEntry = AudioEntry.new()
		entry.name = "FOOTSTEP_WOOD_%d" % i
		entry.path = "res://assets/audio/sfx/footsteps/wood_footstep_%d.ogg" % i
		entry.volume_db = 0.0
		entry.max_distance = 20.0
		entry.bus = "Master"
		entry.pitch_scale = 1.0
		entry.preload_on_startup = false
		entry.spatial = true
		config.entries[5 + i] = entry

	# 13: PHONE_BUTTON_PRESS
	var entry_13: AudioEntry = AudioEntry.new()
	entry_13.name = "PHONE_BUTTON_PRESS"
	entry_13.path = "res://assets/audio/sfx/interactions/phone_button_press_sfx.ogg"
	entry_13.volume_db = 0.0
	entry_13.max_distance = 10.0
	entry_13.bus = "SFX"
	entry_13.pitch_scale = 1.0
	entry_13.preload_on_startup = false
	entry_13.spatial = true
	config.entries[13] = entry_13

	# 14: VOICEMAIL
	var entry_14: AudioEntry = AudioEntry.new()
	entry_14.name = "VOICEMAIL"
	entry_14.path = "res://assets/audio/voiceover/voicemail.ogg"
	entry_14.volume_db = 0.0
	entry_14.max_distance = 8.0
	entry_14.bus = "Voice"
	entry_14.pitch_scale = 1.0
	entry_14.preload_on_startup = false
	entry_14.spatial = true
	config.entries[14] = entry_14

	# 15: LIGHTSWITCH
	var entry_15: AudioEntry = AudioEntry.new()
	entry_15.name = "LIGHTSWITCH"
	entry_15.path = "res://assets/audio/sfx/interactions/lightswitch_sfx.ogg"
	entry_15.volume_db = 0.0
	entry_15.max_distance = 10.0
	entry_15.bus = "SFX"
	entry_15.pitch_scale = 1.0
	entry_15.preload_on_startup = false
	entry_15.spatial = true
	config.entries[15] = entry_15

	# Save the resource
	var save_path: String = "res://resources/audio_config.tres"
	var error: Error = ResourceSaver.save(config, save_path)

	if error == OK:
		print("✓ Successfully created audio_config.tres with 16 entries")
		print("  Location: %s" % save_path)
	else:
		push_error("✗ Failed to save audio_config.tres (Error code: %d)" % error)
