extends StaticBody2D

signal hit_player
signal stomped

enum Type { NORMAL, CRUMBLE, DAMAGE, BRICK }

const CLOUD_W := 120.0
const CLOUD_H := 50.0
const BRICK_W := 110.0
const BRICK_H := 60.0

const _TEX_NORMAL_IDLE: Texture2D = preload("res://assets/platforms/cloud_normal_idle.png")
const _TEX_BROWN_IDLE: Texture2D = preload("res://assets/platforms/cloud_brown_idle.png")
const _TEX_BROWN_CRUMBLE: Texture2D = preload("res://assets/platforms/cloud_brown_crumbling.png")
const _TEX_BRICK_IDLE: Texture2D = preload("res://assets/platforms/cloud_brick_idle.png")
const _TEX_DARK_IDLE: Texture2D = preload("res://assets/platforms/cloud_dark_idle.png")
const _TEX_DARK_HIT: Texture2D = preload("res://assets/platforms/cloud_dark_hit.png")

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
			_sprite.visible = false
			_area.monitoring = false
			_area.collision_mask = 0
			_col.one_way_collision = false
			half_w = BRICK_W * 0.5
			_anim.play("metal")

func _setup_sprite_frames() -> void:
	_anim.scale = Vector2(120.0 / 512.0, 50.0 / 256.0)
	if platform_type == Type.DAMAGE:
		_anim.scale = Vector2(0.125, 0.125)

	var frames := SpriteFrames.new()

	frames.add_animation("normal")
	frames.set_animation_speed("normal", 6.0)
	frames.set_animation_loop("normal", true)
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = _TEX_NORMAL_IDLE
		a.region = Rect2(i * 512, 0, 512, 256)
		frames.add_frame("normal", a)

	frames.add_animation("brown")
	frames.set_animation_speed("brown", 6.0)
	frames.set_animation_loop("brown", true)
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = _TEX_BROWN_IDLE
		a.region = Rect2(i * 512, 0, 512, 256)
		frames.add_frame("brown", a)

	frames.add_animation("crumble")
	frames.set_animation_speed("crumble", 8.0)
	frames.set_animation_loop("crumble", false)
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = _TEX_BROWN_CRUMBLE
		a.region = Rect2(i * 512, 0, 512, 256)
		frames.add_frame("crumble", a)

	frames.add_animation("metal")
	frames.set_animation_speed("metal", 6.0)
	frames.set_animation_loop("metal", true)
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = _TEX_BRICK_IDLE
		a.region = Rect2(i * 512, 0, 512, 256)
		frames.add_frame("metal", a)

	frames.add_animation("dark")
	frames.set_animation_speed("dark", 6.0)
	frames.set_animation_loop("dark", true)
	var atlas_1 := AtlasTexture.new()
	atlas_1.atlas = _TEX_DARK_IDLE
	atlas_1.region = Rect2(0, 0, 512, 512)
	var atlas_2 := AtlasTexture.new()
	atlas_2.atlas = _TEX_DARK_IDLE
	atlas_2.region = Rect2(512, 0, 512, 512)
	frames.add_frame("dark", atlas_1)
	frames.add_frame("dark", atlas_2)

	frames.add_animation("dark_hit")
	frames.set_animation_speed("dark_hit", 6.0)
	frames.set_animation_loop("dark_hit", false)
	var hit_atlas_1 := AtlasTexture.new()
	hit_atlas_1.atlas = _TEX_DARK_HIT
	hit_atlas_1.region = Rect2(0, 0, 512, 512)
	var hit_atlas_2 := AtlasTexture.new()
	hit_atlas_2.atlas = _TEX_DARK_HIT
	hit_atlas_2.region = Rect2(512, 0, 512, 512)
	frames.add_frame("dark_hit", hit_atlas_1)
	frames.add_frame("dark_hit", hit_atlas_2)

	_anim.sprite_frames = frames

func _setup_collision_shapes() -> void:
	var body_shape := RectangleShape2D.new()
	if platform_type == Type.BRICK:
		body_shape.size = Vector2(BRICK_W, BRICK_H)
	else:
		body_shape.size = Vector2(CLOUD_W, 8.0)
	_col.shape = body_shape

	var area_shape := RectangleShape2D.new()
	area_shape.size = Vector2(67.0, 17.0)
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
	if body.global_position.y < global_position.y:
		stomped.emit()
		flash_and_free()
	else:
		_anim.play("dark_hit")
		hit_player.emit()

func flash_and_free() -> void:
	_damage_hit = true
	var tw := create_tween()
	for i in 3:
		tw.tween_property(self, "modulate:a", 0.0, 0.2)
		tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_callback(queue_free)

func start_crumble() -> void:
	if not _crumble_shake and not _crumbling:
		_base_x = position.x
		_crumble_shake = true
		_crumble_timer = 0.0
