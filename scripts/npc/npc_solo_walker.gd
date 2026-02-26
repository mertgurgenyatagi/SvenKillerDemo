class_name NPCSoloWalker
extends Node3D

## Generic single-character NPC that follows a smooth curve built from marker
## nodes under WalkPaths/<path_name>.
##
## Assign character_scene and path_name in the Inspector (or scene file).
## Works with any Mixamo-exported FBX that has a skeleton + walk animation.

## The FBX (or packed scene) containing the character mesh + animation.
@export var character_scene: PackedScene = null

## Name of the Node3D under WalkPaths/ that holds the marker spheres.
@export var path_name: String = ""

## Walking speed in metres per second.
@export var walk_speed: float = 1.0

## Rotation smoothing. Higher = snappier turns.
@export var rotation_smooth: float = 10.0

## Set to 180.0 if the character mesh faces backward after Mixamo import.
@export var facing_offset_deg: float = 180.0

# ── private state ─────────────────────────────────────────────────────────────

var _curve: Curve3D = null
var _curve_length: float = 0.0
var _offset: float = 0.0
var _direction: float = 1.0

var _char: Node3D = null
var _anim: AnimationPlayer = null

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not character_scene:
		push_error("NPCSoloWalker: character_scene not assigned")
		return
	if path_name.is_empty():
		push_error("NPCSoloWalker: path_name not set")
		return
	_build_curve()
	if not _curve:
		return
	_spawn_character()
	_start_animation()


func _process(delta: float) -> void:
	if not _curve:
		return

	_offset += walk_speed * _direction * delta

	if _offset >= _curve_length:
		_offset = _curve_length - (_offset - _curve_length)
		_direction = -1.0
	elif _offset < 0.0:
		_offset = -_offset
		_direction = 1.0

	_update_world_transform(delta)

# ── curve construction ────────────────────────────────────────────────────────

func _build_curve() -> void:
	var scene_root: Node = get_parent()
	var marker_root: Node3D = scene_root.get_node_or_null(
			"WalkPaths/" + path_name) as Node3D

	if not marker_root:
		push_error("NPCSoloWalker: WalkPaths/%s not found" % path_name)
		return

	var positions: Array[Vector3] = []
	for child: Node in marker_root.get_children():
		if child is Node3D:
			positions.append((child as Node3D).global_position)

	if positions.size() < 2:
		push_error("NPCSoloWalker: need at least 2 marker nodes in %s" % path_name)
		return

	_curve = Curve3D.new()
	_curve.bake_interval = 0.1

	for i: int in range(positions.size()):
		var prev: Vector3 = positions[maxi(i - 1, 0)]
		var next: Vector3 = positions[mini(i + 1, positions.size() - 1)]
		var tangent: Vector3 = (next - prev) * 0.5
		_curve.add_point(positions[i], -tangent, tangent)

	_curve_length = _curve.get_baked_length()
	_offset = randf() * _curve_length
	_direction = 1.0 if randf() > 0.5 else -1.0

# ── character spawning ────────────────────────────────────────────────────────

func _spawn_character() -> void:
	_char = character_scene.instantiate() as Node3D
	add_child(_char)
	_anim = _find_anim_player(_char)
	_update_world_transform(0.0)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result: AnimationPlayer = _find_anim_player(child)
		if result:
			return result
	return null

# ── animation ─────────────────────────────────────────────────────────────────

func _start_animation() -> void:
	if not _anim:
		push_warning("NPCSoloWalker: no AnimationPlayer found in character")
		return
	var anim_name: String = _find_walk_anim_name()
	if anim_name.is_empty():
		push_warning("NPCSoloWalker: no playable animation found")
		return
	var anim_res: Animation = _anim.get_animation(anim_name)
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_LINEAR
		_strip_root_motion(anim_res)
	_anim.play(anim_name)
	# Random phase so multiple solo walkers don't step in sync with each other.
	if anim_res:
		_anim.seek(anim_res.length * randf(), true)


func _find_walk_anim_name() -> String:
	const SKIP: PackedStringArray = ["RESET", "Take 001"]
	var first_real: String = ""
	for lib_key: StringName in _anim.get_animation_library_list():
		var lib: AnimationLibrary = _anim.get_animation_library(lib_key)
		for anim: StringName in lib.get_animation_list():
			if str(anim) in SKIP:
				continue
			var full: String = (str(lib_key) + "/" if lib_key != &"" else "") + str(anim)
			if first_real.is_empty():
				first_real = full
			if "walk" in str(anim).to_lower():
				return full
	return first_real

# ── root motion stripping ─────────────────────────────────────────────────────

func _strip_root_motion(anim: Animation) -> void:
	for i: int in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		for k: int in range(anim.track_get_key_count(i)):
			var pos: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(0.0, pos.y, 0.0))

# ── movement & rotation ───────────────────────────────────────────────────────

func _update_world_transform(delta: float) -> void:
	var center: Vector3 = _curve.sample_baked(_offset)

	const TANGENT_DIST: float = 0.2
	var a: float = clampf(_offset - TANGENT_DIST, 0.0, _curve_length)
	var b: float = clampf(_offset + TANGENT_DIST, 0.0, _curve_length)
	var raw_tangent: Vector3 = (_curve.sample_baked(b) - _curve.sample_baked(a)).normalized()

	if raw_tangent.length_squared() < 0.001:
		return

	var right: Vector3 = Vector3.UP.cross(raw_tangent).normalized()
	var fwd:   Vector3 = raw_tangent if _direction > 0.0 else -raw_tangent

	var target_basis: Basis = Basis.looking_at(fwd, Vector3.UP, false)
	if not is_zero_approx(facing_offset_deg):
		target_basis = target_basis.rotated(Vector3.UP, deg_to_rad(facing_offset_deg))

	if _char:
		_char.global_position = center
		if delta > 0.0 and rotation_smooth > 0.0:
			_char.global_basis = _char.global_basis.slerp(
					target_basis, clampf(rotation_smooth * delta, 0.0, 1.0))
		else:
			_char.global_basis = target_basis
