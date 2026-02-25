class_name InteractableIndicator
extends Node3D

@export var y_offset: float = 0.3
@export var pixel_size: float = 0.0007

const FADE_DISTANCE: float = 10.0
const CLOSE_DISTANCE: float = 2.0
const FAR_OPACITY: float = 0.1
const CLOSE_OPACITY: float = 1.0
const OPACITY_LERP_SPEED: float = 8.0
const SIDE_LERP_SPEED: float = 6.0
const ANGLE_FAR: float = 3.5
const ANGLE_CLOSE: float = 10.0

var sprite: Sprite3D
var current_opacity: float = 0.0
# -1.0 = left point, +1.0 = right point; fades through 0 during crossover
var side_factor: float = -1.0
var is_fading_out: bool = false



func _ready() -> void:
	# Create main sprite
	sprite = Sprite3D.new()
	sprite.texture = preload("res://assets/textures/ui/interactable_indicator.png")
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.pixel_size = pixel_size
	sprite.modulate = Color(1, 1, 1, 0)
	sprite.no_depth_test = true
	sprite.visible = false
	add_child(sprite)


func fade_out() -> void:
	is_fading_out = true

func fade_in() -> void:
	is_fading_out = false

func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		sprite.visible = false
		return

	var object_pos: Vector3 = get_parent().global_position

	if not camera.is_position_in_frustum(object_pos):
		sprite.visible = false
		return

	var player: Node3D = _find_player(camera)
	var camera_pos: Vector3 = camera.global_position
	var cam_distance: float = camera_pos.distance_to(object_pos)

	# Opacity: 10% when camera within 10m, 100% when player within 1m
	var target_opacity: float = 0.0
	if is_fading_out:
		target_opacity = 0.0
	else:
		if cam_distance <= FADE_DISTANCE:
			target_opacity = FAR_OPACITY
		if player:
			var player_2d := Vector2(player.global_position.x, player.global_position.z)
			var object_2d := Vector2(object_pos.x, object_pos.z)
			if player_2d.distance_to(object_2d) <= CLOSE_DISTANCE:
				target_opacity = CLOSE_OPACITY

	current_opacity = lerpf(current_opacity, target_opacity, OPACITY_LERP_SPEED * delta)

	if current_opacity < 0.01:
		sprite.visible = false
		return

	sprite.visible = true

	if not player:
		sprite.global_position = Vector3(object_pos.x, object_pos.y + y_offset, object_pos.z)
		sprite.modulate = Color(1, 1, 1, current_opacity)
		return

	# Side crossover: lerp side_factor, use abs() as opacity multiplier so it fades through 0
	var player_pos: Vector3 = player.global_position
	var cam_2d := Vector2(camera_pos.x, camera_pos.z)
	var obj_2d := Vector2(object_pos.x, object_pos.z)
	var player_2d := Vector2(player_pos.x, player_pos.z)

	var to_obj := obj_2d - cam_2d
	var dist_2d := to_obj.length()

	if dist_2d < 0.001:
		sprite.global_position = Vector3(object_pos.x, object_pos.y + y_offset, object_pos.z)
		sprite.modulate = Color(1, 1, 1, current_opacity)
		return

	var dir := to_obj / dist_2d
	var to_player := player_2d - cam_2d
	var cross := to_player.x * dir.y - to_player.y * dir.x

	# Flipped: player on left (cross > 0) -> indicator on left (+1), and vice versa
	var target_side: float = 1.0 if cross > 0.0 else -1.0
	side_factor = lerpf(side_factor, target_side, SIDE_LERP_SPEED * delta)

	# abs(side_factor) fades to 0 during crossover, creating a natural fade transition
	var side_opacity: float = absf(side_factor)
	var final_opacity: float = current_opacity * side_opacity
	sprite.modulate = Color(1, 1, 1, final_opacity)

	# Dynamic angle: 5 deg at 10m, 10 deg at <=1m
	var t := clampf(1.0 - (cam_distance - CLOSE_DISTANCE) / (FADE_DISTANCE - CLOSE_DISTANCE), 0.0, 1.0)
	var angle := lerpf(ANGLE_FAR, ANGLE_CLOSE, t)

	# Dynamic size: full at 10m, half at <=1m
	var dynamic_pixel_size: float = lerpf(pixel_size, pixel_size * 0.5, t)
	sprite.pixel_size = dynamic_pixel_size

	# Position
	var perp := Vector2(-dir.y, dir.x)
	var offset_dist := dist_2d * tan(deg_to_rad(angle))
	var point_left := obj_2d + perp * offset_dist
	var point_right := obj_2d - perp * offset_dist

	var chosen: Vector2
	if side_factor > 0.0:
		chosen = point_left
	else:
		chosen = point_right

	sprite.global_position = Vector3(chosen.x, object_pos.y + y_offset, chosen.y)


func _find_player(camera: Camera3D) -> Node3D:
	var node: Node = camera
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
