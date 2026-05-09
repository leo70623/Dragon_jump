extends Node2D

@onready var _bg: Sprite2D = $Background
@onready var _char: AnimatedSprite2D = $Character

var _char_dir: float = 1.0
var _music: AudioStreamPlayer

const CHAR_SPEED := 150.0
const CHAR_HALF_W := 32.0

# Title per-letter animation
var _title_labels: Array[Label] = []
var _base_y: Array[float] = []
var _rot_timer: Array[float] = []
var _rot_angle: Array[float] = []
var _rot_wobbling: Array[bool] = []
var _piano_bounceable: Array[bool] = []

# Piano key state
const LETTER_DUR := 0.3
const PIANO_PAUSE := 0.7
var _piano_idx: int = 0
var _piano_t: float = 0.0
var _piano_pausing: bool = false

const _LINE1 := "Not-so-ugly"
const _LINE2 := "Dragon"

# Welcome label
var _welcome_label: Button = null
var _last_player_name: String = ""

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

	_welcome_label = Button.new()
	_welcome_label.flat = true
	_welcome_label.add_theme_font_size_override("font_size", 17)
	_welcome_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_welcome_label.add_theme_constant_override("outline_size", 3)
	_welcome_label.add_theme_color_override("font_outline_color", Color(0.05, 0.28, 0.05))
	_welcome_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_welcome_label.add_theme_constant_override("shadow_offset_x", 2)
	_welcome_label.add_theme_constant_override("shadow_offset_y", 2)
	_welcome_label.custom_minimum_size = Vector2(180, 32)
	_welcome_label.position = Vector2(vp.x - 188.0, 6.0)
	_welcome_label.pressed.connect(_on_change_name_pressed)
	$UI.add_child(_welcome_label)
	_update_welcome_text()

	_build_title()

func _update_welcome_text() -> void:
	var name := Leaderboard.player_name
	_welcome_label.text = ("Welcome, " + name) if name != "" else "Welcome"
	_last_player_name = name

func _build_title() -> void:
	var font: FontFile = load("res://BubblegumSans-Regular.ttf")
	print("[FONT] 字型大小=%d" % font.get_height(72))
	var vp_w := get_viewport_rect().size.x
	var fs1 := 61
	var fs2 := 68
	var w1 := font.get_string_size(_LINE1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
	if w1 > vp_w * 0.95:
		fs1 = int(float(fs1) * vp_w * 0.95 / w1)
		fs2 = int(float(fs2) * vp_w * 0.95 / w1)
	_add_line(_LINE1, fs1, 60.0, font)
	_add_line(_LINE2, fs2, 150.0, font)

func _add_line(text: String, font_size: int, base_y: float, font: Font) -> void:
	var vp_w := get_viewport_rect().size.x
	var widths: Array[float] = []
	var total_w := 0.0
	for c in text:
		var cw := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(cw)
		total_w += cw
	var x := (vp_w - total_w) * 0.5
	for i in text.length():
		var ch := text[i]
		var lbl := Label.new()
		lbl.text = ch
		lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", font_size)
		var t: float = float(i) / max(float(text.length() - 1), 1.0)
		lbl.add_theme_color_override("font_color", Color(1.0, lerp(0.95, 0.40, t), 0.0))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.28, 0.05))
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
		lbl.add_theme_constant_override("shadow_offset_x", 4)
		lbl.add_theme_constant_override("shadow_offset_y", 4)
		lbl.position = Vector2(x, base_y)
		lbl.pivot_offset = Vector2(widths[i] * 0.5, float(font_size) * 0.5)
		$UI.add_child(lbl)
		_title_labels.append(lbl)
		_base_y.append(base_y)
		_rot_timer.append(randf_range(1.5, 4.0))
		_rot_angle.append(0.0)
		_rot_wobbling.append(false)
		_piano_bounceable.append((ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z"))
		x += widths[i]

func _first_bounceable() -> int:
	for i in _piano_bounceable.size():
		if _piano_bounceable[i]:
			return i
	return _piano_bounceable.size()

func _next_bounceable(from: int) -> int:
	for i in range(from + 1, _piano_bounceable.size()):
		if _piano_bounceable[i]:
			return i
	return _piano_bounceable.size()

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

	if Leaderboard.player_name != _last_player_name:
		_update_welcome_text()

	# Piano key: only letter characters bounce, punctuation is skipped
	_piano_t += delta
	if _piano_pausing:
		if _piano_t >= PIANO_PAUSE:
			_piano_t = 0.0
			_piano_idx = _first_bounceable()
			_piano_pausing = false
	else:
		if _piano_t >= LETTER_DUR:
			_piano_t -= LETTER_DUR
			_piano_idx = _next_bounceable(_piano_idx)
			if _piano_idx >= _title_labels.size():
				_piano_pausing = true
				_piano_t = 0.0

	for i in _title_labels.size():
		var offset := 0.0
		if not _piano_pausing and i == _piano_idx:
			offset = -sin(PI * _piano_t / LETTER_DUR) * 15.0
		_title_labels[i].position.y = _base_y[i] + offset

		_rot_timer[i] -= delta
		if _rot_timer[i] <= 0.0:
			_rot_wobbling[i] = not _rot_wobbling[i]
			if _rot_wobbling[i]:
				_rot_angle[i] = randf_range(-5.0, 5.0)
				_rot_timer[i] = 0.5
			else:
				_rot_angle[i] = 0.0
				_rot_timer[i] = randf_range(3.0, 5.0)
		_title_labels[i].rotation_degrees = lerp(_title_labels[i].rotation_degrees, _rot_angle[i], delta * 8.0)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or \
	   (event is InputEventMouseButton and event.pressed):
		if is_instance_valid(_music):
			_music.stop()
		get_tree().change_scene_to_file("res://main.tscn")

func _on_leaderboard_pressed() -> void:
	Leaderboard.show_leaderboard()

func _on_change_name_pressed() -> void:
	Leaderboard.show_name_dialog(false)
