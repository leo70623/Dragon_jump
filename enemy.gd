extends Area2D

signal stomped
signal hit_player

const Platform := preload("res://platform.gd")
const ENEMY_SIZE := 32.0
const FRAME_RATE := 8.0

var platform: Node2D = null
var can_move: bool = false
var move_speed: float = 60.0
var _move_dir: float = 1.0
var _dying: bool = false
var _frame_timer: float = 0.0

@onready var _sprite: Sprite2D = $AnimatedSprite2D

func setup(p: Node2D, moving: bool, spd: float) -> void:
	platform = p
	can_move = moving
	move_speed = spd
	_move_dir = 1.0 if randf() > 0.5 else -1.0
	var surf_y := Platform.CLOUD_H * 0.5
	if "platform_type" in p and p.platform_type == Platform.Type.BRICK:
		surf_y = Platform.BRICK_H * 0.5
	position = Vector2(p.position.x, p.position.y - surf_y - ENEMY_SIZE * 0.5)

func _ready() -> void:
	print("[Enemy] --- node tree ---")
	for child in get_children():
		print("  name='", child.name, "'  class=", child.get_class())

	var anim_node := get_node_or_null("AnimatedSprite2D")
	if anim_node:
		print("[Enemy] $AnimatedSprite2D FOUND  scale=", (anim_node as Node2D).scale)
		if anim_node is Sprite2D and (anim_node as Sprite2D).texture:
			print("[Enemy] texture size=", (anim_node as Sprite2D).texture.get_size())
		$AnimatedSprite2D.scale = Vector2(0.3, 0.3)
		print("[Enemy] scale forced -> ", $AnimatedSprite2D.scale)
	else:
		print("[Enemy] ERROR: $AnimatedSprite2D NOT FOUND")

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _dying:
		return
	if not is_instance_valid(platform):
		queue_free()
		return

	var surf_y := Platform.CLOUD_H * 0.5
	if "platform_type" in platform and platform.platform_type == Platform.Type.BRICK:
		surf_y = Platform.BRICK_H * 0.5
	position.y = platform.position.y - surf_y - ENEMY_SIZE * 0.5

	if can_move:
		var hw: float = platform.get("half_w") if "half_w" in platform else Platform.CLOUD_W * 0.5
		var left_bound := platform.position.x - hw + ENEMY_SIZE * 0.5
		var right_bound := platform.position.x + hw - ENEMY_SIZE * 0.5
		position.x += move_speed * _move_dir * delta
		if position.x >= right_bound:
			position.x = right_bound
			_move_dir = -1.0
		elif position.x <= left_bound:
			position.x = left_bound
			_move_dir = 1.0
	else:
		position.x = platform.position.x

	_frame_timer += delta
	_sprite.frame = int(_frame_timer * FRAME_RATE) % 4
	_sprite.flip_h = _move_dir < 0.0

func _on_body_entered(body: Node) -> void:
	if _dying or not body is CharacterBody2D:
		return
	var player := body as CharacterBody2D
	if player.velocity.y > 0.0 and player.global_position.y < global_position.y:
		_die_stomped(player)
	else:
		hit_player.emit()

func _die_stomped(player: CharacterBody2D) -> void:
	_dying = true
	monitoring = false
	player.velocity.y = -600.0
	stomped.emit()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation", deg_to_rad(360.0), 0.5)
	tw.tween_property(self, "position:y", position.y + 80.0, 0.5)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tw.chain().tween_callback(queue_free)
