extends Node2D

@onready var _bg: Sprite2D = $Background
@onready var _char: AnimatedSprite2D = $Character

var _char_dir: float = 1.0
var _music: AudioStreamPlayer

const CHAR_SPEED := 150.0
const CHAR_HALF_W := 32.0  # 128px frame * 0.5 scale / 2

func _ready() -> void:
	var vp := get_viewport_rect().size
	if _bg.texture:
		var tex_size := _bg.texture.get_size()
		_bg.scale = Vector2(vp.x / tex_size.x, vp.y / tex_size.y)
	_bg.position = Vector2(vp.x * 0.5, vp.y * 0.5)

	var font: FontFile = load("res://FredokaOne-Regular.ttf")
	if font:
		$UI/TitleLabel.add_theme_font_override("font", font)
		$UI/TapLabel.add_theme_font_override("font", font)

	_char.position = Vector2(CHAR_HALF_W, randf_range(400.0, 530.0))

	_music = AudioStreamPlayer.new()
	var stream = load("res://start_music.mp3")
	if stream:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_music.stream = stream
		add_child(_music)
		_music.play()

func _process(delta: float) -> void:
	var vp_w := get_viewport_rect().size.x
	_char.position.x += CHAR_SPEED * _char_dir * delta

	if _char_dir > 0.0 and _char.position.x >= vp_w - CHAR_HALF_W:
		_char.position.x = vp_w - CHAR_HALF_W
		_char_dir = -1.0
		_char.flip_h = true
		_char.position.y = randf_range(400.0, 530.0)
	elif _char_dir < 0.0 and _char.position.x <= CHAR_HALF_W:
		_char.position.x = CHAR_HALF_W
		_char_dir = 1.0
		_char.flip_h = false
		_char.position.y = randf_range(400.0, 530.0)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed):
		if is_instance_valid(_music):
			_music.stop()
		get_tree().change_scene_to_file("res://main.tscn")
