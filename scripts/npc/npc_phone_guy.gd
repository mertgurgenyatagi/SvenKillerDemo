class_name NPCPhoneGuy
extends Node3D

## Attach to the phone-guy standing NPC node.
## Plays npc_audio_phone_guy.ogg as looping 3D positional audio from this node.

const _AUDIO_STREAM: AudioStream = preload(
		"res://assets/audio/sfx/npc/npc_audio_phone_guy.ogg")


func _ready() -> void:
	var ap: AnimationPlayer = _find_anim_player(self)
	if ap:
		_start_animation(ap)
	else:
		push_warning("NPCPhoneGuy: no AnimationPlayer found")

	var audio := AudioStreamPlayer3D.new()
	audio.stream = _AUDIO_STREAM
	audio.volume_db = -16.5  # 1.5x louder than original -20 dB
	audio.finished.connect(audio.play)
	add_child(audio)
	audio.play()


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result: AnimationPlayer = _find_anim_player(child)
		if result:
			return result
	return null


func _start_animation(ap: AnimationPlayer) -> void:
	const SKIP: PackedStringArray = ["RESET", "Take 001"]
	var anim_name: String = ""
	for lib_key: StringName in ap.get_animation_library_list():
		var lib: AnimationLibrary = ap.get_animation_library(lib_key)
		for anim: StringName in lib.get_animation_list():
			if str(anim) in SKIP:
				continue
			var full: String = (str(lib_key) + "/" if lib_key != &"" else "") + str(anim)
			if anim_name.is_empty():
				anim_name = full
			var lower: String = str(anim).to_lower()
			if "idle" in lower or "stand" in lower or "phone" in lower:
				anim_name = full
				break
	if anim_name.is_empty():
		return
	var anim_res: Animation = ap.get_animation(anim_name)
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_LINEAR
	ap.play(anim_name)
	if anim_res:
		ap.seek(anim_res.length * randf(), true)
