extends CharacterBody2D

const JUMP_VELOCITY := -800.0
const GRAVITY := 1800.0
const MOVE_SPEED := 300.0
const LAND_DISPLAY_TIME := 0.1

const _TEX_UP: Texture2D = preload("res://assets/characters/jump_up.png")
const _TEX_DOWN: Texture2D = preload("res://assets/characters/jump_down.png")
const _TEX_LAND: Texture2D = preload("res://assets/characters/jump_land.png")
const Platform := preload("res://platform.gd")

signal landed_on(platform: Node)
signal ceiling_hit(platform: Node)

@onready var sprite: Sprite2D = $Sprite2D

var _land_timer: float = 0.0
var _sfx_jump: AudioStreamPlayer
var _sfx_crumble: AudioStreamPlayer
var _sfx_brick: AudioStreamPlayer
var _sfx_death: AudioStreamPlayer

var _touch_dir: float = 0.0
var _touch_active: Dictionary = {}  # finger index -> bool (true = left half)

func _ready() -> void:
	_sfx_jump    = _make_sfx("res://assets/audio/sfx/jump.wav")
	_sfx_crumble = _make_sfx("res://assets/audio/sfx/crumble.wav")
	_sfx_brick   = _make_sfx("res://assets/audio/sfx/brick_hit.wav")
	_sfx_death   = _make_sfx("res://assets/audio/sfx/death.wav")

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

func _input(event: InputEvent) -> void:
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

func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta

	var key_dir := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var dir := clampf(_touch_dir + key_dir, -1.0, 1.0)
	velocity.x = dir * MOVE_SPEED

	if dir > 0.05:
		sprite.flip_h = false
	elif dir < -0.05:
		sprite.flip_h = true

	var was_on_floor := is_on_floor()
	move_and_slide()

	var just_landed := false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var n := col.get_normal()
		if n.y < -0.5 and not was_on_floor:
			var collider := col.get_collider()
			landed_on.emit(collider)
			just_landed = true
			if "platform_type" in collider:
				match collider.platform_type:
					Platform.Type.NORMAL:  _sfx_jump.play()
					Platform.Type.CRUMBLE: _sfx_crumble.play()
					Platform.Type.BRICK:   _sfx_brick.play()
		elif n.y > 0.5:
			var collider := col.get_collider()
			ceiling_hit.emit(collider)
			if "platform_type" in collider and collider.platform_type == Platform.Type.BRICK:
				_sfx_brick.play()

	if just_landed:
		_land_timer = LAND_DISPLAY_TIME

	if is_on_floor():
		velocity.y = JUMP_VELOCITY

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
