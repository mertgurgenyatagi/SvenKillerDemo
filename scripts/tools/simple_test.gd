@tool
extends EditorScript

func _run() -> void:
	print("=== SIMPLE TEST ===")
	print("If you see this, EditorScript execution is working!")
	print("Current time: ", Time.get_ticks_msec())
	print("===================")
