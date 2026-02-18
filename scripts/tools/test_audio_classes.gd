@tool
extends EditorScript

## Diagnostic script to test if AudioConfig and AudioEntry classes are accessible

func _run() -> void:
	print("=== Audio Classes Diagnostic ===")

	# Test 1: Can we create an AudioEntry?
	print("Test 1: Creating AudioEntry...")
	var entry: AudioEntry = AudioEntry.new()
	if entry:
		print("  ✓ AudioEntry created successfully")
		print("  - Type: %s" % entry.get_class())
	else:
		print("  ✗ Failed to create AudioEntry")
		return

	# Test 2: Can we set properties on AudioEntry?
	print("Test 2: Setting AudioEntry properties...")
	entry.path = "res://test.ogg"
	entry.volume_db = -5.0
	entry.bus = "SFX"
	print("  ✓ Properties set successfully")
	print("  - path: %s" % entry.path)
	print("  - volume_db: %f" % entry.volume_db)
	print("  - bus: %s" % entry.bus)

	# Test 3: Can we create an AudioConfig?
	print("Test 3: Creating AudioConfig...")
	var config: AudioConfig = AudioConfig.new()
	if config:
		print("  ✓ AudioConfig created successfully")
		print("  - Type: %s" % config.get_class())
	else:
		print("  ✗ Failed to create AudioConfig")
		return

	# Test 4: Can we add entries to the config?
	print("Test 4: Adding entry to config...")
	config.entries[0] = entry
	print("  ✓ Entry added to config")
	print("  - Entries count: %d" % config.entries.size())

	# Test 5: Can we save the config?
	print("Test 5: Attempting to save config...")
	var save_path: String = "res://resources/audio_config_test.tres"
	var error: Error = ResourceSaver.save(config, save_path)

	if error == OK:
		print("  ✓ Config saved successfully to: %s" % save_path)
	else:
		print("  ✗ Failed to save config (Error code: %d)" % error)
		print("  Error name: %s" % error_string(error))
		return

	print("\n=== All Tests Passed ===")
	print("The AudioConfig and AudioEntry classes are working correctly.")
	print("You can now run create_audio_config.gd to generate the full config.")
