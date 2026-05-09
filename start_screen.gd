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
var _wave_phase: Array[float] = []
var _rot_timer: Array[float] = []
var _rot_angle: Array[float] = []
var _rot_wobbling: Array[bool] = []
var _anim_time: float = 0.0

const _LINE1 := "Not-so-ugly"
const _LINE2 := "Dragon"

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

	_build_title()

func _build_title() -> void:
	var font: Font = ThemeDB.fallback_font
	var vp_w := get_viewport_rect().size.x
	var fs1 := 36
	var fs2 := 28
	# Scale down line 1 font size if it doesn't fit
	var w1 := font.get_string_size(_LINE1, HORIZONTAL_ALIGNMENT_LEFT, -1, fs1).x
	if w1 > vp_w * 0.95:
		fs1 = int(float(fs1) * vp_w * 0.95 / w1)
		fs2 = int(float(fs1) * 28.0 / 36.0)
	_add_line(_LINE1, fs1, 90.0, font, 0)
	_add_line(_LINE2, fs2, 148.0, font, _LINE1.length())

func _add_line(text: String, font_size: int, base_y: float, font: Font, phase_start: int) -> void:
	var vp_w := get_viewport_rect().size.x
	var widths: Array[float] = []
	var total_w := 0.0
	for c in text:
		var cw := font.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(cw)
		total_w += cw
	var x := (vp_w - total_w) * 0.5
	for i in text.length():
		var lbl := Label.new()
		lbl.text = text[i]
		lbl.add_theme_font_size_override("font_size", font_size)
		# Yellow-to-orange gradient across the line
		var t: float = float(i) / max(float(text.length() - 1), 1.0)
		lbl.add_theme_color_override("font_color", Color(1.0, lerp(0.95, 0.40, t), 0.0))
		# Dark green outline 3 px
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.28, 0.05))
		# Light shadow offset (3, 3)
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
		lbl.add_theme_constant_override("shadow_offset_x", 3)
		lbl.add_theme_constant_override("shadow_offset_y", 3)
		lbl.position = Vector2(x, base_y)
		lbl.pivot_offset = Vector2(widths[i] * 0.5, float(font_size) * 0.5)
		$UI.add_child(lbl)
		_title_labels.append(lbl)
		_base_y.append(base_y)
		_wave_phase.append(float(phase_start + i) * 0.5)
		_rot_timer.append(randf_range(1.5, 4.0))
		_rot_angle.append(0.0)
		_rot_wobbling.append(false)
		x += widths[i]

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

	_anim_time += delta
	for i in _title_labels.size():
		var lbl := _title_labels[i]
		# Staggered bounce — abs(sin) 模擬真實彈跳落地感
		lbl.position.y = _base_y[i] + abs(sin(_anim_time * 4.0 + _wave_phase[i])) * -20.0
		# Occasional rotation: timer alternates between wobble (0.5 s) and idle (3–5 s)
		_rot_timer[i] -= delta
		if _rot_timer[i] <= 0.0:
			_rot_wobbling[i] = not _rot_wobbling[i]
			if _rot_wobbling[i]:
				_rot_angle[i] = randf_range(-5.0, 5.0)
				_rot_timer[i] = 0.5
			else:
				_rot_angle[i] = 0.0
				_rot_timer[i] = randf_range(3.0, 5.0)
		lbl.rotation_degrees = lerp(lbl.rotation_degrees, _rot_angle[i], delta * 8.0)

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
