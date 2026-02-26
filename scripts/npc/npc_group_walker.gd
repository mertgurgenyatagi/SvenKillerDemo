class_name NPCGroupWalker
extends Node3D

## Three characters walking together in a triangular wedge formation along
## WalkPaths/PathGroup.
##
## Formation (viewed from above, travelling →):
##
##         char1  ← apex / leader (slightly ahead of centre)
##     char2   char3  ← left & right wings (slightly behind)
##
## The fore/aft offset uses the direction-aware forward vector so char1 always
## leads regardless of which way the group is currently walking.
## The lateral offset uses the raw tangent so char2 and char3 keep the same
## absolute sides even after the group turns around at an endpoint.

const _CHAR_SCENE_1: PackedScene = preload(
		"res://assets/npc_assets/npc_group_1.fbx")
const _CHAR_SCENE_2: PackedScene = preload(
		"res://assets/npc_assets/npc_group_2.fbx")
const _CHAR_SCENE_3: PackedScene = preload(
		"res://assets/npc_assets/npc_group_3.fbx")

## Walking speed in metres per second.
@export var walk_speed: float = 1.0

## How far ahead of centre the leader (char1) is placed.
@export var fore_offset: float = 0.5

## How far behind centre the two wing characters are placed.
@export var trail_offset: float = 0.3

## Lateral distance of each wing character from the centre-line.
@export var side_offset: float = 0.5

## Rotation smoothing. Higher = snappier turns.
@export var rotation_smooth: float = 10.0

## Set to 180.0 if the character meshes face backward after Mixamo import.
@export var facing_offset_deg: float = 180.0

# ── private state ─────────────────────────────────────────────────────────────

var _curve: Curve3D = null
var _curve_length: float = 0.0
var _offset: float = 0.0
var _direction: float = 1.0

var _char1: Node3D = null  # apex / leader
var _char2: Node3D = null  # left wing
var _char3: Node3D = null  # right wing

var _anim1: AnimationPlayer = null
var _anim2: AnimationPlayer = null
var _anim3: AnimationPlayer = null

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_curve()
	if not _curve:
		return
	_spawn_characters()
	_start_animations()


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

	_update_world_transforms(delta)

# ── curve construction ────────────────────────────────────────────────────────

func _build_curve() -> void:
	var scene_root: Node = get_parent()
	var marker_root: Node3D = scene_root.get_node_or_null(
			"WalkPaths/PathGroup") as Node3D

	if not marker_root:
		push_error("NPCGroupWalker: WalkPaths/PathGroup not found")
		return

	var positions: Array[Vector3] = []
	for child: Node in marker_root.get_children():
		if child is Node3D:
			positions.append((child as Node3D).global_position)

	if positions.size() < 2:
		push_error("NPCGroupWalker: need at least 2 marker nodes")
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

func _spawn_characters() -> void:
	_char1 = _CHAR_SCENE_1.instantiate() as Node3D
	_char2 = _CHAR_SCENE_2.instantiate() as Node3D
	_char3 = _CHAR_SCENE_3.instantiate() as Node3D
	add_child(_char1)
	add_child(_char2)
	add_child(_char3)
	_anim1 = _find_anim_player(_char1)
	_anim2 = _find_anim_player(_char2)
	_anim3 = _find_anim_player(_char3)
	_update_world_transforms(0.0)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result: AnimationPlayer = _find_anim_player(child)
		if result:
			return result
	return null

# ── animation ─────────────────────────────────────────────────────────────────

func _start_animations() -> void:
	# Each character gets a different random phase so footfalls never sync.
	_play_on(_anim1, 0.0)
	_play_on(_anim2, randf())
	_play_on(_anim3, randf())


func _play_on(ap: AnimationPlayer, time_fraction: float = 0.0) -> void:
	if not ap:
		push_warning("NPCGroupWalker: no AnimationPlayer found in character")
		return
	var anim_name: String = _find_walk_anim_name(ap)
	if anim_name.is_empty():
		push_warning("NPCGroupWalker: no playable animation found")
		return
	var anim_res: Animation = ap.get_animation(anim_name)
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_LINEAR
		_strip_root_motion(anim_res)
	ap.play(anim_name)
	if time_fraction > 0.0 and anim_res:
		ap.seek(anim_res.length * time_fraction, true)


func _find_walk_anim_name(ap: AnimationPlayer) -> String:
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

func _update_world_transforms(delta: float) -> void:
	var center: Vector3 = _curve.sample_baked(_offset)

	const TANGENT_DIST: float = 0.2
	var a: float = clampf(_offset - TANGENT_DIST, 0.0, _curve_length)
	var b: float = clampf(_offset + TANGENT_DIST, 0.0, _curve_length)
	var raw_tangent: Vector3 = (_curve.sample_baked(b) - _curve.sample_baked(a)).normalized()

	if raw_tangent.length_squared() < 0.001:
		return

	# Lateral axis derived from raw tangent — stays stable through reversals
	# so char2 and char3 always hold the same absolute sides of the path.
	var right: Vector3 = Vector3.UP.cross(raw_tangent).normalized()

	# Forward direction is travel-aware so char1 always leads the group.
	var fwd: Vector3 = raw_tangent if _direction > 0.0 else -raw_tangent

	var target_basis: Basis = Basis.looking_at(fwd, Vector3.UP, false)
	if not is_zero_approx(facing_offset_deg):
		target_basis = target_basis.rotated(Vector3.UP, deg_to_rad(facing_offset_deg))

	var blended_basis: Basis
	if delta > 0.0 and rotation_smooth > 0.0 and _char1:
		blended_basis = _char1.global_basis.slerp(
				target_basis, clampf(rotation_smooth * delta, 0.0, 1.0))
	else:
		blended_basis = target_basis

	# ── triangle positions ────────────────────────────────────────────────────
	if _char1:
		_char1.global_position = center + fwd * fore_offset
		_char1.global_basis    = blended_basis
	if _char2:
		_char2.global_position = center - fwd * trail_offset + right * side_offset
		_char2.global_basis    = blended_basis
	if _char3:
		_char3.global_position = center - fwd * trail_offset - right * side_offset
		_char3.global_basis    = blended_basis
