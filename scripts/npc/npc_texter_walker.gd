class_name NPCTexterWalker
extends Node3D

## Texter-walker NPC: spawns on the sidewalk curve at a random point and walks
## in a random direction, ping-ponging at each end of the path.
##
## Attach this script to a Node3D inside StreetPrototype.
## The node must be a direct child of the scene root so that _ready() can reach
## WalkPaths/PathTexterWalker via get_parent().

const _CHAR_SCENE: PackedScene = preload(
		"res://assets/npc_assets/npc_walker_texter.fbx")

@export var walk_speed: float = 1.0

## Rotation smoothing factor. Higher = snappier turning. 0 = instant.
@export var rotation_smooth: float = 10.0

## Set to 180.0 if the character mesh faces backward after import.
## Mixamo characters are often +Z-forward; if so, keep this at 0.
@export var facing_offset_deg: float = 180.0

# ── private state ────────────────────────────────────────────────────────────

var _curve: Curve3D = null
var _curve_length: float = 0.0
var _offset: float = 0.0    # current arc-length position along the baked curve
var _direction: float = 1.0 # +1 = toward curve end, -1 = toward curve start

var _anim_player: AnimationPlayer = null

# ── lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_curve()
	if not _curve:
		return
	_spawn_character()
	_start_animation()


func _process(delta: float) -> void:
	if not _curve:
		return

	_offset += walk_speed * _direction * delta

	# Ping-pong at the ends so the NPC turns around at each endpoint.
	if _offset >= _curve_length:
		_offset = _curve_length - (_offset - _curve_length)
		_direction = -1.0
	elif _offset < 0.0:
		_offset = -_offset
		_direction = 1.0

	_update_world_transform(delta)

# ── curve construction ───────────────────────────────────────────────────────

func _build_curve() -> void:
	# The NPC is a direct child of the scene root, so get_parent() gives us
	# StreetPrototype, where WalkPaths/PathTexterWalker lives.
	var scene_root: Node = get_parent()
	var marker_root: Node3D = scene_root.get_node_or_null(
			"WalkPaths/PathTexterWalker") as Node3D

	if not marker_root:
		push_error("NPCTexterWalker: WalkPaths/PathTexterWalker not found")
		return

	var positions: Array[Vector3] = []
	for child: Node in marker_root.get_children():
		if child is Node3D:
			positions.append((child as Node3D).global_position)

	if positions.size() < 2:
		push_error("NPCTexterWalker: need at least 2 marker spheres")
		return

	_curve = Curve3D.new()
	_curve.bake_interval = 0.1  # fine-grained baking for smooth tangent sampling

	# Catmull-Rom tangents: each point's handle is half the chord to its
	# neighbours, giving a smooth spline through every marker.
	for i: int in range(positions.size()):
		var prev: Vector3 = positions[maxi(i - 1, 0)]
		var next: Vector3 = positions[mini(i + 1, positions.size() - 1)]
		var tangent: Vector3 = (next - prev) * 0.5
		_curve.add_point(positions[i], -tangent, tangent)

	_curve_length = _curve.get_baked_length()

	# Random starting offset and direction.
	_offset = randf() * _curve_length
	_direction = 1.0 if randf() > 0.5 else -1.0

# ── character spawning ───────────────────────────────────────────────────────

func _spawn_character() -> void:
	var model: Node3D = _CHAR_SCENE.instantiate() as Node3D
	add_child(model)
	_anim_player = _find_anim_player(model)
	_update_world_transform(0.0)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var result: AnimationPlayer = _find_anim_player(child)
		if result:
			return result
	return null

# ── animation ────────────────────────────────────────────────────────────────

func _start_animation() -> void:
	if not _anim_player:
		push_warning("NPCTexterWalker: no AnimationPlayer found in character scene")
		return
	var anim_name: String = _find_walk_anim_name()
	if not anim_name.is_empty():
		var anim_res: Animation = _anim_player.get_animation(anim_name)
		if anim_res:
			anim_res.loop_mode = Animation.LOOP_LINEAR
			_strip_root_motion(anim_res)
		_anim_player.play(anim_name)
	else:
		push_warning("NPCTexterWalker: no animation found to play")


func _find_walk_anim_name() -> String:
	if not _anim_player:
		return ""

	# Pose/reset clips that are not real gameplay animations.
	const SKIP: PackedStringArray = ["RESET", "Take 001"]

	# Prefer any animation whose name contains "walk". Fall back to the first
	# clip that isn't a known pose/reset track.
	var first_real: String = ""
	for lib_key: StringName in _anim_player.get_animation_library_list():
		var lib: AnimationLibrary = _anim_player.get_animation_library(lib_key)
		for anim: StringName in lib.get_animation_list():
			if str(anim) in SKIP:
				continue
			var full: String = (str(lib_key) + "/" if lib_key != &"" else "") + str(anim)
			if first_real.is_empty():
				first_real = full
			if "walk" in str(anim).to_lower():
				return full
	return first_real

# ── root motion stripping ────────────────────────────────────────────────────

func _strip_root_motion(anim: Animation) -> void:
	# Zero out X and Z on every position track so the NPC doesn't self-propel.
	# Y is kept so the natural hip-bob of the walk cycle is preserved.
	# Mixamo "in place" exports sometimes still bake XZ translation into the
	# root or hips bone; this removes it regardless of which track carries it.
	for i: int in range(anim.get_track_count()):
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		for k: int in range(anim.track_get_key_count(i)):
			var pos: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(0.0, pos.y, 0.0))

# ── movement & rotation ──────────────────────────────────────────────────────

func _update_world_transform(delta: float) -> void:
	global_position = _curve.sample_baked(_offset)

	# Build the forward direction from a short tangent window around _offset.
	const TANGENT_DIST: float = 0.2
	var a: float = clampf(_offset - TANGENT_DIST, 0.0, _curve_length)
	var b: float = clampf(_offset + TANGENT_DIST, 0.0, _curve_length)
	var fwd: Vector3 = (_curve.sample_baked(b) - _curve.sample_baked(a)).normalized()

	if fwd.length_squared() < 0.001:
		return

	if _direction < 0.0:
		fwd = -fwd

	# Basis.looking_at(fwd, up, use_model_front=false) → local -Z faces fwd.
	# If the mesh faces +Z (common for Mixamo), set facing_offset_deg = 180
	# in the Inspector to flip it.
	var target_basis: Basis = Basis.looking_at(fwd, Vector3.UP, false)

	if not is_zero_approx(facing_offset_deg):
		target_basis = target_basis.rotated(Vector3.UP, deg_to_rad(facing_offset_deg))

	if delta > 0.0 and rotation_smooth > 0.0:
		global_basis = global_basis.slerp(
				target_basis, clampf(rotation_smooth * delta, 0.0, 1.0))
	else:
		global_basis = target_basis
