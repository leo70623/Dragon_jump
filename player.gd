extends CharacterBody2D

const JUMP_VELOCITY := -800.0
const GRAVITY := 1800.0
const MOVE_SPEED := 300.0
const LAND_DISPLAY_TIME := 0.1
const PUMP_DURATION := 7.0
const PUMP_RISE_END := 1.5
const PUMP_MAX_END := 5.5
const PUMP_MAX_VEL := -550.0
const PUMP_ACCEL := 600.0

const _TEX_UP: Texture2D = preload("res://assets/characters/jump_up.png")
const _TEX_DOWN: Texture2D = preload("res://assets/characters/jump_down.png")
const _TEX_LAND: Texture2D = preload("res://assets/characters/jump_land.png")
const _TEX_PUMP: Texture2D = preload("res://assets/characters/dragon_pump_sheet.png")
const Platform := preload("res://platform.gd")

signal landed_on(platform: Node)
signal ceiling_hit(platform: Node)
signal damaged
signal enemy_crushed
signal landed(landing_y: float)

@onready var sprite: Sprite2D = $Sprite2D
@onready var _col_shape: CollisionShape2D = $CollisionShape2D

var _land_timer: float = 0.0
var _sfx_jump: AudioStreamPlayer
var _sfx_crumble: AudioStreamPlayer
var _sfx_brick: AudioStreamPlayer
var _sfx_death: AudioStreamPlayer
var _sfx_pump_inflate: AudioStreamPlayer
var _sfx_pump_deflate: AudioStreamPlayer
var _sfx_enemy_crush: AudioStreamPlayer

var _touch_dir: float = 0.0
var _touch_active: Dictionary = {}  # finger index -> bool (true = left half)
var _boost_timer: float = 0.0
var _afterimage_timer: float = 0.0
var _just_landed: bool = false
var _pump_active: bool = false
var _pump_timer: float = 0.0
var _pump_deflate_played: bool = false
var _pump_sprite: AnimatedSprite2D = null
var _original_sprite_scale: Vector2
var _original_shape_radius: float
var _original_shape_height: float

func _ready() -> void:
	collision_mask = collision_mask | 2
	set_collision_mask_value(4, true)
	_original_sprite_scale = sprite.scale
	_original_shape_radius = (_col_shape.shape as CapsuleShape2D).radius
	_original_shape_height = (_col_shape.shape as CapsuleShape2D).height
	var sprite_display := sprite.texture.get_size() * sprite.scale if sprite.texture else Vector2.ZERO
	print("[COLLISION DEBUG] shape radius=", _original_shape_radius, " height=", _original_shape_height)
	print("[COLLISION DEBUG] sprite display size=", sprite_display, " sprite scale=", sprite.scale)
	_sfx_jump          = _make_sfx("res://assets/audio/sfx/jump.wav")
	_sfx_crumble       = _make_sfx("res://assets/audio/sfx/crumble.wav")
	_sfx_brick         = _make_sfx("res://assets/audio/sfx/brick_hit.wav")
	_sfx_death         = _make_sfx("res://assets/audio/sfx/death.wav")
	_sfx_pump_inflate  = _make_sfx("res://assets/audio/sfx/sfx_pump_inflate.wav")
	_sfx_pump_deflate  = _make_sfx("res://assets/audio/sfx/sfx_pump_deflate.wav")
	_sfx_enemy_crush   = _make_sfx("res://assets/audio/sfx/enemy_crush.wav")
	_pump_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("pump")
	frames.set_animation_loop("pump", false)
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = _TEX_PUMP
		a.region = Rect2(i * 512, 0, 512, 512)
		frames.add_frame("pump", a)
	_pump_sprite.sprite_frames = frames
	_pump_sprite.scale = Vector2(0.25, 0.25)
	_pump_sprite.position = Vector2.ZERO
	_pump_sprite.z_index = 10
	_pump_sprite.visible = false
	add_child(_pump_sprite)

func _make_sfx(path: String) -> AudioStreamPlayer:
	var asp := AudioStreamPlayer.new()
	var s = load(path)
	if s:
		asp.stream = s
	add_child(asp)
	return asp

func play_death_sfx() -> void:
	if _sfx_death and _sfx_death.stream:
		_sfx_death.play()

func apply_pump() -> void:
	_pump_active = true
	_pump_timer = 0.0
	_pump_deflate_played = false
	velocity = Vector2.ZERO
	set_collision_mask_value(4, false)
	if _sfx_pump_inflate and _sfx_pump_inflate.stream:
		_sfx_pump_inflate.play()
	sprite.visible = false
	_pump_sprite.visible = true
	_pump_sprite.play("pump")
	_pump_sprite.frame = 0
	print("[PUMP DEBUG] _pump_sprite valid: ", is_instance_valid(_pump_sprite))
	print("[PUMP DEBUG] _pump_sprite in tree: ", _pump_sprite.is_inside_tree() if is_instance_valid(_pump_sprite) else "N/A")
	print("[PUMP DEBUG] _pump_sprite visible=", _pump_sprite.visible, " pos=", _pump_sprite.position, " scale=", _pump_sprite.scale, " z_index=", _pump_sprite.z_index)
	print("[PUMP DEBUG] sprite visible=", sprite.visible, " pos=", sprite.position, " scale=", sprite.scale)
	var sf := _pump_sprite.sprite_frames
	print("[PUMP DEBUG] sprite_frames valid: ", is_instance_valid(sf), " has pump: ", sf.has_animation("pump") if is_instance_valid(sf) else "N/A", " frame_count: ", sf.get_frame_count("pump") if (is_instance_valid(sf) and sf.has_animation("pump")) else "N/A")
	print("[PUMP DEBUG] after play, frame=", _pump_sprite.frame, " is_playing=", _pump_sprite.is_playing())

func _end_pump() -> void:
	_pump_active = false
	_pump_timer = 0.0
	velocity.y = 0.0
	set_collision_mask_value(4, true)
	_pump_sprite.visible = false
	sprite.visible = true
	sprite.scale = _original_sprite_scale
	(_col_shape.shape as CapsuleShape2D).radius = _original_shape_radius
	(_col_shape.shape as CapsuleShape2D).height = _original_shape_height

func _input(event: InputEvent) -> void:
	if OS.has_feature("mobile"):
		return  # 手機平台不處理觸控輸入，改由重力感應控制
	if event is InputEventScreenTouch:
		var half_w := get_viewport_rect().size.x * 0.5
		if event.pressed:
			_touch_active[event.index] = event.position.x < half_w
		else:
			_touch_active.erase(event.index)
		_recalc_touch_dir()
	elif event is InputEventScreenDrag:
		var half_w := get_viewport_rect().size.x * 0.5
		_touch_active[event.index] = event.position.x < half_w
		_recalc_touch_dir()

func _take_damage() -> void:
	damaged.emit()

func bounce() -> void:
	velocity.y = JUMP_VELOCITY

func apply_boost(duration: float = 5.0) -> void:
	_boost_timer = duration
	_afterimage_timer = 0.0

func _spawn_afterimage() -> void:
	if not sprite.texture:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.position = global_position
	ghost.modulate = Color(0.5, 0.8, 1.0, 0.8)
	ghost.z_index = 5
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)

func _recalc_touch_dir() -> void:
	var has_left := false
	var has_right := false
	for is_left: bool in _touch_active.values():
		if is_left:
			has_left = true
		else:
			has_right = true
	if has_left and not has_right:
		_touch_dir = -1.0
	elif has_right and not has_left:
		_touch_dir = 1.0
	else:
		_touch_dir = 0.0

func _get_move_direction() -> float:
	if OS.has_feature("mobile"):
		var gravity := Input.get_accelerometer()
		return clampf(gravity.x / 2.5, -1.0, 1.0)
	return Input.get_axis("ui_left", "ui_right")

func _physics_process(delta: float) -> void:
	if _boost_timer > 0.0:
		_boost_timer -= delta
		_afterimage_timer -= delta
		if _afterimage_timer <= 0.0:
			_afterimage_timer = 0.08
			_spawn_afterimage()

	if _pump_active:
		_pump_timer += delta

		if _pump_timer < PUMP_RISE_END:
			velocity.y = lerpf(0.0, PUMP_MAX_VEL, _pump_timer / PUMP_RISE_END)
			if is_instance_valid(_pump_sprite):
				_pump_sprite.frame = 0
				_pump_sprite.scale = Vector2.ONE * lerpf(0.25, 0.5, _pump_timer / PUMP_RISE_END)
		elif _pump_timer < PUMP_MAX_END:
			velocity.y = PUMP_MAX_VEL
			if is_instance_valid(_pump_sprite):
				_pump_sprite.frame = 1
				_pump_sprite.scale = Vector2(0.5, 0.5)
		else:
			if not _pump_deflate_played:
				_pump_deflate_played = true
				if _sfx_pump_deflate and _sfx_pump_deflate.stream:
					_sfx_pump_deflate.play()
			var t := (_pump_timer - PUMP_MAX_END) / (PUMP_DURATION - PUMP_MAX_END)
			velocity.y = lerpf(PUMP_MAX_VEL, 0.0, t)
			if is_instance_valid(_pump_sprite):
				_pump_sprite.frame = 2
				_pump_sprite.scale = Vector2.ONE * lerpf(0.5, 0.25, t)

		if is_instance_valid(_pump_sprite):
			var ratio := _pump_sprite.scale.x / 0.25
			(_col_shape.shape as CapsuleShape2D).radius = _original_shape_radius * ratio
			(_col_shape.shape as CapsuleShape2D).height = _original_shape_height * ratio

		var dir := _get_move_direction()
		velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, PUMP_ACCEL * delta)
		if is_instance_valid(_pump_sprite):
			if dir > 0.05:
				_pump_sprite.flip_h = false
			elif dir < -0.05:
				_pump_sprite.flip_h = true

		move_and_slide()

		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var collider := col.get_collider()
			if collider.is_in_group("enemy"):
				collider.die()
				enemy_crushed.emit()
				if _sfx_enemy_crush and _sfx_enemy_crush.stream:
					_sfx_enemy_crush.play()

		var w := get_viewport_rect().size.x
		if position.x < -22.0:
			position.x = w + 22.0
		elif position.x > w + 22.0:
			position.x = -22.0

		if _pump_timer >= PUMP_DURATION:
			_end_pump()
		return

	velocity.y += GRAVITY * delta

	var dir := _get_move_direction()
	velocity.x = dir * MOVE_SPEED

	if dir > 0.05:
		sprite.flip_h = false
	elif dir < -0.05:
		sprite.flip_h = true

	var was_on_floor := is_on_floor()
	move_and_slide()

	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		var collider := col.get_collider()
		if collider.is_in_group("enemy"):
			if n.y < -0.5:
				collider.die()
				velocity.y = JUMP_VELOCITY
				enemy_crushed.emit()
			else:
				collider.hit_player.emit()
			continue
		if n.y < -0.5 and not was_on_floor and not _just_landed:
			landed_on.emit(collider)
			landed.emit(global_position.y)
			_just_landed = true
			if "platform_type" in collider:
				match collider.platform_type:
					Platform.Type.NORMAL:  _sfx_jump.play()
					Platform.Type.CRUMBLE: _sfx_crumble.play()
					Platform.Type.BRICK:   _sfx_brick.play()
		elif n.y > 0.5:
			ceiling_hit.emit(collider)
			if "platform_type" in collider and collider.platform_type == Platform.Type.BRICK:
				_sfx_brick.play()

	if _just_landed:
		_land_timer = LAND_DISPLAY_TIME

	if not is_on_floor():
		_just_landed = false

	if is_on_floor():
		velocity.y = JUMP_VELOCITY * (1.4 if _boost_timer > 0.0 else 1.0)

	if _land_timer > 0.0:
		_land_timer -= delta
		sprite.texture = _TEX_LAND
	elif velocity.y < 0.0:
		sprite.texture = _TEX_UP
	else:
		sprite.texture = _TEX_DOWN

	var w := get_viewport_rect().size.x
	if position.x < -22.0:
		position.x = w + 22.0
	elif position.x > w + 22.0:
		position.x = -22.0
