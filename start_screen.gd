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

	_char.position = Vector2(CHAR_HALF_W, randf_range(400.0, 530.0))

	_music = AudioStreamPlayer.new()
	var stream = load("res://assets/audio/music/start_music.mp3")
	if stream:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		_music.stream = stream
		add_child(_music)
		_music.play()

	var lb_btn := Button.new()
	lb_btn.text = "排行榜"
	lb_btn.add_theme_font_size_override("font_size", 18)
	lb_btn.custom_minimum_size = Vector2(110, 36)
	lb_btn.position = Vector2(vp.x * 0.5 - 55.0, vp.y - 72.0)
	lb_btn.pressed.connect(_on_leaderboard_pressed)
	$UI.add_child(lb_btn)

	var nm_btn := Button.new()
	nm_btn.text = "改名"
	nm_btn.add_theme_font_size_override("font_size", 14)
	nm_btn.custom_minimum_size = Vector2(68, 28)
	nm_btn.position = Vector2(vp.x - 76.0, 8.0)
	nm_btn.pressed.connect(_on_change_name_pressed)
	$UI.add_child(nm_btn)

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

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed):
		if is_instance_valid(_music):
			_music.stop()
		get_tree().change_scene_to_file("res://main.tscn")

func _on_leaderboard_pressed() -> void:
	print("排行榜按鈕點擊")
	Leaderboard.show_leaderboard()

func _on_change_name_pressed() -> void:
	Leaderboard.show_name_dialog(false)
