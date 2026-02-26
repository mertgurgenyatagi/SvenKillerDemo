class_name NPCStandingActivator
extends Node3D

## Attach to the StandingNPCs node. Iterates every direct child instance,
## finds its AnimationPlayer, and starts a looping idle/standing animation
## at a random phase so the characters are never in sync.

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	for child: Node in get_children():
		var ap: AnimationPlayer = _find_anim_player(child)
		if ap:
			_play_on(ap)
		else:
			push_warning("NPCStandingActivator: no AnimationPlayer in '%s'" % child.name)

# ── helpers ───────────────────────────────────────────────────────────────────

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result: AnimationPlayer = _find_anim_player(child)
		if result:
			return result
	return null


func _play_on(ap: AnimationPlayer) -> void:
	var anim_name: String = _pick_anim_name(ap)
	if anim_name.is_empty():
		push_warning("NPCStandingActivator: no playable animation in '%s'" % ap.get_parent().name)
		return
	var anim_res: Animation = ap.get_animation(anim_name)
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_LINEAR
	ap.play(anim_name)
	if anim_res:
		ap.seek(anim_res.length * randf(), true)


func _pick_anim_name(ap: AnimationPlayer) -> String:
	const SKIP: PackedStringArray = ["RESET", "Take 001"]
	var first_real: String = ""
	for lib_key: StringName in ap.get_animation_library_list():
		var lib: AnimationLibrary = ap.get_animation_library(lib_key)
		for anim: StringName in lib.get_animation_list():
			if str(anim) in SKIP:
				continue
			var full: String = (str(lib_key) + "/" if lib_key != &"" else "") + str(anim)
			if first_real.is_empty():
				first_real = full
			# Prefer clips with "idle" or "stand" in the name.
			var lower: String = str(anim).to_lower()
			if "idle" in lower or "stand" in lower:
				return full
	return first_real
