@tool
extends EditorScript

## Tool script to add all house lights to the "house_lights" group
## Run this from Godot Editor: File → Run

func _run():
	var root = get_scene()
	if not root:
		push_error("No scene loaded!")
		return

	var light_names = [
		"MainCeilingLight",
		"corner1",
		"corner2",
		"corner3",
		"corner4",
		"corner5"
	]

	print("=== Adding lights to 'house_lights' group ===")

	for light_name in light_names:
		var light = root.find_child(light_name, true, false)
		if light and light is Light3D:
			if not light.is_in_group("house_lights"):
				light.add_to_group("house_lights")
				print("✓ Added '%s' to house_lights group" % light_name)
			else:
				print("  '%s' already in group" % light_name)
		else:
			push_warning("✗ Light not found: %s" % light_name)

	print("=== Done! ===")
	print("All lights should now be in the 'house_lights' group.")
	print("You can verify by selecting each light and checking the 'Node' tab.")
