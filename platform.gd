extends StaticBody2D

signal hit_player

enum Type { NORMAL, CRUMBLE, DAMAGE, BRICK }

const CLOUD_W := 120.0
const CLOUD_H := 50.0
const BRICK_W := 110.0
const BRICK_H := 60.0

const _TEX_CLOUD_01: Texture2D = preload("res://assets/platforms/cloud_01.png")
const _TEX_CLOUD_02: Texture2D = preload("res://assets/platforms/cloud_02.png")
const _TEX_CLOUD_03: Texture2D = preload("res://assets/platforms/cloud_03.png")
const _TEX_BROWN_01: Texture2D = preload("res://assets/platforms/brown_cloud_01.png")
const _TEX_BROWN_02: Texture2D = preload("res://assets/platforms/brown_cloud_02.png")
const _TEX_BROWN_03: Texture2D = preload("res://assets/platforms/brown_cloud_03.png")
const _TEX_CRUMBLE_01: Texture2D = preload("res://assets/platforms/cloud_crumbling_01.png")
const _TEX_CRUMBLE_02: Texture2D = preload("res://assets/platforms/cloud_crumbling_02.png")
const _TEX_DARK_01: Texture2D = preload("res://assets/platforms/dark_cloud_01.png")
const _TEX_DARK_02: Texture2D = preload("res://assets/platforms/dark_cloud_02.png")
const _TEX_DARK_HIT: Texture2D = preload("res://assets/platforms/dark_cloud_hit.png")
const _TEX_METAL: Texture2D = preload("res://assets/platforms/metal_cloud.png")

var platform_type: Type = Type.NORMAL
var speed: float = 0.0
var direction: float = 1.0
var half_w: float = CLOUD_W * 0.5

var _crumble_shake: bool = false
var _crumbling: bool = false
var _crumble_timer: float = 0.0
var _base_x: float = 0.0

var _damage_hit: bool = false
var _vp_w: float = 0.0

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _col: CollisionShape2D = $CollisionShape2D
@onready var _area: Area2D = $Area2D
@onready var _area_col: CollisionShape2D = $Area2D/CollisionShape2D

func _ready() -> void:
	_vp_w = get_viewport_rect().size.x
	_setup_sprite_frames()
	_setup_collision_shapes()
	match platform_type:
		Type.NORMAL:
			_sprite.visible = false
			_area.monitoring = false
			_area.collision_mask = 0
			_col.one_way_collision = true
			_anim.play("normal")
		Type.CRUMBLE:
			_sprite.visible = false
			_area.monitoring = false
			_area.collision_mask = 0
			_col.one_way_collision = true
			_anim.modulate = Color(1, 1, 1, 1)
			_anim.play("brown")
		Type.DAMAGE:
			_sprite.visible = false
			_col.disabled = true
			_area.monitoring = true
			_area.body_entered.connect(_on_area_body_entered)
			_anim.play("dark")
		Type.BRICK:
			_anim.visible = false
			_sprite.visible = true
			_area.monitoring = false
			_area.collision_mask = 0
			_col.one_way_collision = false
			half_w = BRICK_W * 0.5
			_sprite.texture = _TEX_METAL
			if _sprite.texture:
				var tex_size: Vector2 = _sprite.texture.get_size()
				_sprite.scale = Vector2(BRICK_W / tex_size.x, BRICK_H / tex_size.y)
			else:
				push_error("[BRICK] metal_cloud.png failed to load at res://assets/platforms/metal_cloud.png")

func _setup_sprite_frames() -> void:
	var tex_w: float = _TEX_CLOUD_01.get_width()
	var tex_h: float = _TEX_CLOUD_01.get_height()
	_anim.scale = Vector2(CLOUD_W / tex_w, CLOUD_H / tex_h)

	var frames := SpriteFrames.new()

	frames.add_animation("normal")
	frames.set_animation_speed("normal", 6.0)
	frames.set_animation_loop("normal", true)
	frames.add_frame("normal", _TEX_CLOUD_01)
	frames.add_frame("normal", _TEX_CLOUD_02)
	frames.add_frame("normal", _TEX_CLOUD_03)

	frames.add_animation("brown")
	frames.set_animation_speed("brown", 6.0)
	frames.set_animation_loop("brown", true)
	frames.add_frame("brown", _TEX_BROWN_01)
	frames.add_frame("brown", _TEX_BROWN_02)
	frames.add_frame("brown", _TEX_BROWN_03)

	frames.add_animation("crumble")
	frames.set_animation_speed("crumble", 8.0)
	frames.set_animation_loop("crumble", false)
	frames.add_frame("crumble", _TEX_CRUMBLE_01)
	frames.add_frame("crumble", _TEX_CRUMBLE_02)

	frames.add_animation("dark")
	frames.set_animation_speed("dark", 6.0)
	frames.set_animation_loop("dark", true)
	frames.add_frame("dark", _TEX_DARK_01)
	frames.add_frame("dark", _TEX_DARK_02)

	frames.add_animation("dark_hit")
	frames.set_animation_speed("dark_hit", 1.0)
	frames.set_animation_loop("dark_hit", false)
	frames.add_frame("dark_hit", _TEX_DARK_HIT)

	_anim.sprite_frames = frames

func _setup_collision_shapes() -> void:
	var body_shape := RectangleShape2D.new()
	if platform_type == Type.BRICK:
		body_shape.size = Vector2(BRICK_W, BRICK_H)
	else:
		body_shape.size = Vector2(CLOUD_W, 8.0)
	_col.shape = body_shape

	var area_shape := RectangleShape2D.new()
	area_shape.size = Vector2(80.0, 20.0)
	_area_col.shape = area_shape

func _process(delta: float) -> void:
	if platform_type == Type.DAMAGE:
		if not _damage_hit:
			position.y += 150.0 * delta
		return

	if speed != 0.0 and not _crumble_shake and not _crumbling:
		position.x += speed * direction * delta
		if position.x > _vp_w - 20.0:
			direction = -1.0
		elif position.x < 20.0:
			direction = 1.0

	if _crumble_shake:
		_crumble_timer += delta
		position.x = _base_x + 5.0 * sin(_crumble_timer * 80.0)
		if _crumble_timer >= 0.1:
			_crumble_shake = false
			_crumbling = true
			_crumble_timer = 0.0
			_anim.animation_finished.connect(_on_crumble_finished, CONNECT_ONE_SHOT)
			_anim.play("crumble")

func _on_crumble_finished() -> void:
	queue_free()

func _on_area_body_entered(body: Node2D) -> void:
	if _damage_hit or body is not CharacterBody2D:
		return
	_damage_hit = true
	_anim.play("dark_hit")
	hit_player.emit()

func start_crumble() -> void:
	if not _crumble_shake and not _crumbling:
		_base_x = position.x
		_crumble_shake = true
		_crumble_timer = 0.0
