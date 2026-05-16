extends Node2D

const PLATFORM_SCENE := preload("res://platform.tscn")
const Platform := preload("res://platform.gd")
const SPACING_MIN := 85.0
const SPACING_MAX := 125.0
const SPACING_LEVEL_STEP := 10.0
const SPACING_MIN_CAP := 140.0
const SPACING_MAX_CAP := 142.0
const PLATFORM_MARGIN := 65.0
const JUMP_HEIGHT := 178.0
const MAX_LIVES := 5
const REGEN_INTERVAL := 1800.0  # 30 minutes
const ENEMY_SCENE := preload("res://enemy.tscn")
const MAX_ENEMIES := 5
const INVINCIBLE_DURATION := 5.0
const ITEM_SCENE := preload("res://item.tscn")
const ITEM_SPAWN_INTERVAL := 6
const DEV_ENEMY_TEST := false

static var s_lives: int = 5
static var s_regen_elapsed: float = 0.0

@onready var camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = $Player
@onready var platforms_node: Node2D = $Platforms
@onready var background: Sprite2D = $Camera2D/Background
@onready var score_label: Label = $UI/ScoreLabel
@onready var _ui: CanvasLayer = $UI
@onready var game_over_screen: Control = $UI/GameOverScreen
@onready var final_score_label: Label = $UI/GameOverScreen/FinalScoreLabel
@onready var game_over_title: Label = $UI/GameOverScreen/GameOverTitle
@onready var hint_label: Label = $UI/GameOverScreen/HintLabel
@onready var cooldown_label: Label = $UI/GameOverScreen/CooldownLabel
@onready var _restart_btn: Button = $UI/GameOverScreen/RestartButton
@onready var _bgm: AudioStreamPlayer = $BGM
@onready var _enemies_node: Node2D = $Enemies
@onready var _items_node: Node2D = $Items

var _sfx_spin: AudioStreamPlayer
var _sfx_death_shout: AudioStreamPlayer
var _sfx_enemy_crush: AudioStreamPlayer
var _sfx_record_whoop: AudioStreamPlayer
var _sfx_fireworks_loop: AudioStreamPlayer
var hearts: Array[Sprite2D] = []
var next_spawn_y: float = 0.0
var score: int = 0
var start_y: float = 0.0
var combo: int = 0
var last_landing_y: float = 0.0
var _skip_combo_check: bool = false
var combo_base_score: int = 2
var game_over_flag: bool = false
var _last_two_types: Array[int] = []
var _y_since_last_white: float = 0.0
var _last_spawn_y: float = 0.0
var _last_spawn_x: float = 0.0
var _eligible_since_last_enemy: int = 0
var _item_counter: int = 0
var _invincible_timer: float = 0.0
var _current_bg_level: int = 0
var _bg_transitioning: bool = false
var _bg_paths: Array[String] = ["res://assets/backgrounds/BG_01.png", "res://assets/backgrounds/BG_02.png", "res://assets/backgrounds/BG_03.png", "res://assets/backgrounds/BG_04.png"]
var _dev_panel: Control = null
var _dev_input: LineEdit = null
var _status_label: Label = null
var _last_was_double: bool = false
var _score_result_handled: bool = false
var _pending_is_new_record: int = -1  # -1=未知, 0=keep it up, 1=new record
var _fireworks_active: bool = false

func _ready() -> void:
	var _vp_scale := get_viewport().get_screen_transform().get_scale().y
	if _vp_scale <= 0.0:
		_vp_scale = 1.0
	var safe_top := DisplayServer.get_display_safe_area().position.y / _vp_scale

	var life_tex: Texture2D = load("res://assets/ui/life_01.png")
	var icon_scale := Vector2(0.25, 0.25)
	var tex_size := life_tex.get_size() if life_tex else Vector2(128, 128)
	var display_size := tex_size * icon_scale

	var x_start: float = 16.0 + display_size.x * 0.5
	var icon_y: float = safe_top + 50.0 + display_size.y * 0.5
	var x_step: float = display_size.x + 6.0

	for i in MAX_LIVES:
		var spr := Sprite2D.new()
		spr.texture = life_tex
		spr.scale = icon_scale
		spr.position = Vector2(x_start + i * x_step, icon_y)
		_ui.add_child(spr)
		hearts.append(spr)
	_update_hearts_ui()

	score_label.offset_top = safe_top + 8.0
	score_label.offset_bottom = safe_top + 58.0
	score_label.text = "Score  0"

	var vp := get_viewport_rect().size
	player.position = Vector2(vp.x * 0.5, vp.y - 120.0)
	camera.position = Vector2(vp.x * 0.5, player.position.y - vp.y * 0.15)
	start_y = player.position.y
	score = 0
	start_y = player.position.y
	score_label.text = "Score  " + str(score)

	var combo_label := Label.new()
	combo_label.name = "ComboLabel"
	var dynafont = load("res://assets/ui/DynaPuff-Regular.ttf")
	if dynafont:
		combo_label.add_theme_font_override("font", dynafont)
	combo_label.add_theme_font_size_override("font_size", 32)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.custom_minimum_size = Vector2(190, 0)
	combo_label.position = Vector2(vp.x - 200, safe_top + 8)
	combo_label.visible = false
	combo_label.modulate = Color(1, 0.8, 0, 1)
	$UI.add_child(combo_label)

	if background.texture:
		var bg_tex_size := background.texture.get_size()
		background.scale = Vector2(vp.x / bg_tex_size.x, vp.y / bg_tex_size.y)

	var first_y := player.position.y + 60.0
	var fp := PLATFORM_SCENE.instantiate()
	fp.position = Vector2(player.position.x, first_y)
	fp.platform_type = Platform.Type.NORMAL
	platforms_node.add_child(fp)
	_last_spawn_y = first_y
	_y_since_last_white = 0.0
	_last_two_types = [Platform.Type.NORMAL]

	next_spawn_y = first_y - _get_spacing()
	while next_spawn_y > camera.position.y - vp.y * 1.5:
		_spawn_platform(next_spawn_y)
		next_spawn_y -= _get_spacing()

	player.landed_on.connect(_on_player_landed_on)
	player.damaged.connect(_on_player_damaged)
	player.enemy_crushed.connect(_on_enemy_crushed)
	player.landed.connect(_on_player_landed)
	_restart_btn.pressed.connect(_on_restart_btn_pressed)

	if _bgm.stream is AudioStreamMP3:
		(_bgm.stream as AudioStreamMP3).loop = true
	_bgm.play()

	_sfx_spin = AudioStreamPlayer.new()
	var spin_stream = load("res://assets/audio/sfx/spin.wav")
	if spin_stream:
		_sfx_spin.stream = spin_stream
	add_child(_sfx_spin)

	_sfx_death_shout = AudioStreamPlayer.new()
	var death_shout_stream = load("res://assets/audio/sfx/death_shout.mp3")
	if death_shout_stream:
		_sfx_death_shout.stream = death_shout_stream
	add_child(_sfx_death_shout)

	_sfx_enemy_crush = AudioStreamPlayer.new()
	var crush_stream = load("res://assets/audio/sfx/enemy_crush.wav")
	if crush_stream:
		_sfx_enemy_crush.stream = crush_stream
	add_child(_sfx_enemy_crush)

	_sfx_record_whoop = AudioStreamPlayer.new()
	_sfx_record_whoop.stream = load("res://assets/audio/sfx/record_whoop.wav")
	add_child(_sfx_record_whoop)

	_sfx_fireworks_loop = AudioStreamPlayer.new()
	var fireworks_stream := load("res://assets/audio/sfx/fireworks_loop.wav") as AudioStreamWAV
	if fireworks_stream:
		fireworks_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_sfx_fireworks_loop.stream = fireworks_stream
	_sfx_fireworks_loop.volume_db = 0.0
	add_child(_sfx_fireworks_loop)

	if s_lives == 0:
		game_over_flag = true
		player.set_physics_process(false)
		_update_cooldown_label()
		game_over_screen.visible = true

	_status_label = Label.new()
	_status_label.position = Vector2(8.0, safe_top + 8.0)
	_status_label.add_theme_font_size_override("font_size", 20)
	_ui.add_child(_status_label)

	if OS.is_debug_build():
		_setup_dev_ui()

func _process(delta: float) -> void:
	if s_lives < MAX_LIVES:
		s_regen_elapsed += delta
		if s_regen_elapsed >= REGEN_INTERVAL:
			s_lives += 1
			s_regen_elapsed = 0.0
			_update_hearts_ui()
			if game_over_flag:
				_update_cooldown_label()

	if game_over_flag:
		if s_lives < MAX_LIVES:
			_update_cooldown_label()
		return

	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		player.modulate.a = 0.5 + 0.5 * sin(_invincible_timer * 20.0)
		if _invincible_timer <= 0.0:
			_invincible_timer = 0.0
			player.modulate.a = 1.0

	var _status := ""
	if _invincible_timer > 0.0:
		_status += "無敵 %ds" % ceili(_invincible_timer)
	if player._boost_timer > 0.0:
		if _status != "":
			_status += "  "
		_status += "跳高 %ds" % ceili(player._boost_timer)
	_status_label.text = _status

	var vp_h := get_viewport_rect().size.y

	var new_score: int = int((start_y - player.position.y) / 100.0) * 2
	if new_score > score:
		score = new_score
		score_label.text = "Score  " + str(score)
		_check_bg_switch()

	var target_y := player.position.y - vp_h * 0.15
	if target_y < camera.position.y:
		camera.position.y = target_y

	while next_spawn_y > camera.position.y - vp_h * 1.5:
		_spawn_platform(next_spawn_y)
		next_spawn_y -= _get_spacing()

	var cull_y := camera.position.y + vp_h * 0.65
	var cull_top_y := camera.position.y - vp_h * 1.5
	for p in platforms_node.get_children():
		if p.position.y > cull_y:
			p.queue_free()
	for item in _items_node.get_children():
		if item.position.y > cull_y or item.position.y < cull_top_y:
			item.queue_free()

	if player.position.y > camera.position.y + vp_h * 0.55:
		_show_game_over()

func _on_player_landed_on(platform: Node) -> void:
	if game_over_flag or not is_instance_valid(platform):
		return
	if not "platform_type" in platform:
		return
	if platform.platform_type == Platform.Type.CRUMBLE:
		platform.start_crumble()
		score += 1
		_check_bg_switch()
		score_label.text = "Score  " + str(score)
		_spawn_score_popup("+1", player.global_position + Vector2(0, 30), Color(0.4, 0.85, 1.0, 1.0))
		_skip_combo_check = true

func _update_hearts_ui() -> void:
	for i in MAX_LIVES:
		if i < hearts.size():
			hearts[i].modulate = Color(1, 1, 1, 1) if i < s_lives else Color(1, 1, 1, 0.2)

func _update_cooldown_label() -> void:
	if s_lives > 0:
		hint_label.text = "Tap to restart"
		cooldown_label.text = ""
	else:
		hint_label.text = ""
		var remaining := REGEN_INTERVAL - s_regen_elapsed
		var mins := int(remaining) / 60
		var secs := int(remaining) % 60
		cooldown_label.text = "Next life in: %02d:%02d" % [mins, secs]

func _on_damage_cloud_hit_player(platform: Node2D) -> void:
	if game_over_flag:
		return
	if _invincible_timer > 0.0:
		if is_instance_valid(platform):
			platform.flash_and_free()
	else:
		_show_game_over()

func _show_game_over() -> void:
	if game_over_flag:
		return
	game_over_flag = true
	_score_result_handled = false
	_pending_is_new_record = -1
	_fireworks_active = false
	_invincible_timer = 0.0
	player.modulate.a = 1.0
	player.set_physics_process(false)
	if s_lives > 0:
		s_lives -= 1
		s_regen_elapsed = 0.0
		_update_hearts_ui()
	final_score_label.text = "Score: 0"
	_update_cooldown_label()
	Leaderboard.submit_score(score)
	Leaderboard.score_result.connect(_on_score_result, CONNECT_ONE_SHOT)
	var fallback := get_tree().create_timer(3.0)
	fallback.timeout.connect(func():
		if game_over_title.text == "":
			_on_score_result(false)
	)
	var lb_btn := Button.new()
	lb_btn.text = "Leaderboard"
	lb_btn.add_theme_font_size_override("font_size", 16)
	lb_btn.anchor_left = 0.0
	lb_btn.anchor_right = 0.0
	lb_btn.anchor_top = 1.0
	lb_btn.anchor_bottom = 1.0
	lb_btn.offset_left = 24.0
	lb_btn.offset_right = 174.0
	lb_btn.offset_top = -90.0
	lb_btn.offset_bottom = -46.0
	lb_btn.pressed.connect(func(): Leaderboard.show_leaderboard())
	var lb_style := StyleBoxFlat.new()
	lb_style.bg_color = Color("#1D9E75")
	lb_style.corner_radius_top_left = 12
	lb_style.corner_radius_top_right = 12
	lb_style.corner_radius_bottom_left = 12
	lb_style.corner_radius_bottom_right = 12
	lb_btn.add_theme_stylebox_override("normal", lb_style)
	lb_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	game_over_screen.add_child(lb_btn)

	var share_btn := Button.new()
	share_btn.text = "Share"
	share_btn.add_theme_font_size_override("font_size", 16)
	share_btn.anchor_left = 1.0
	share_btn.anchor_right = 1.0
	share_btn.anchor_top = 1.0
	share_btn.anchor_bottom = 1.0
	share_btn.offset_left = -174.0
	share_btn.offset_right = -24.0
	share_btn.offset_top = -90.0
	share_btn.offset_bottom = -46.0
	share_btn.pressed.connect(func(): Leaderboard.share_score(score))
	var share_style := StyleBoxFlat.new()
	share_style.bg_color = Color("#378ADD")
	share_style.corner_radius_top_left = 12
	share_style.corner_radius_top_right = 12
	share_style.corner_radius_bottom_left = 12
	share_style.corner_radius_bottom_right = 12
	share_btn.add_theme_stylebox_override("normal", share_style)
	share_btn.add_theme_color_override("font_color", Color("#FFFFFF"))
	game_over_screen.add_child(share_btn)
	if _sfx_death_shout and _sfx_death_shout.stream:
		_sfx_death_shout.play()
	player.visible = false
	_spawn_death_spin()

func _spawn_death_spin() -> void:
	var tex: Texture2D = load("res://assets/enemies/game_over_spin.png")
	if not tex:
		game_over_title.text = ""
		game_over_title.visible = false
		game_over_screen.visible = true
		return
	if _sfx_spin and _sfx_spin.stream:
		_sfx_spin.play()
	var spin := Sprite2D.new()
	spin.texture = tex
	var start_pos := player.position
	var end_pos := camera.global_position
	spin.position = start_pos
	spin.modulate.a = 1.0
	spin.scale = Vector2(0.3, 0.3)
	spin.z_index = 100
	add_child(spin)
	var ctrl := Vector2(
		lerpf(start_pos.x, end_pos.x, 0.4) + randf_range(-60.0, 60.0),
		minf(start_pos.y, end_pos.y) - 180.0
	)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(t: float):
		if not is_instance_valid(spin):
			return
		var p: Vector2 = start_pos.lerp(ctrl, t).lerp(ctrl.lerp(end_pos, t), t)
		spin.position = p
	, 0.0, 1.0, 2.0)
	tw.tween_property(spin, "rotation", deg_to_rad(900.0), 2.0)
	tw.tween_property(spin, "scale", Vector2(2.5, 2.5), 2.0)
	tw.chain().tween_callback(func():
		if is_instance_valid(spin):
			spin.rotation = 0.0
			spin.modulate.a = 0.4
		game_over_title.text = ""
		game_over_title.visible = false
		game_over_screen.visible = true
		if _pending_is_new_record == 1:
			final_score_label.text = "Score: 0"
			var target := score
			var tw_s := create_tween()
			tw_s.tween_method(func(v: float):
				final_score_label.text = "Score: " + str(int(v))
			, 0.0, float(target), minf(float(target) / 200.0, 2.0))
		else:
			final_score_label.text = "Score: " + str(score)
		_try_show_result_title()
	)

func _on_restart_btn_pressed() -> void:
	if game_over_flag and s_lives > 0:
		_fireworks_active = false
		if _sfx_fireworks_loop and _sfx_fireworks_loop.is_playing():
			_sfx_fireworks_loop.stop()
		get_tree().reload_current_scene()

func _on_score_result(is_new_record: bool) -> void:
	if _score_result_handled:
		return
	_score_result_handled = true
	_pending_is_new_record = 1 if is_new_record else 0
	_try_show_result_title()

func _try_show_result_title() -> void:
	if _pending_is_new_record == -1:
		return
	if not game_over_screen.visible:
		return
	var is_new_record := _pending_is_new_record == 1
	game_over_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	game_over_title.clip_contents = false
	game_over_title.custom_minimum_size.x = 360.0
	if is_new_record:
		game_over_title.visible = false
		final_score_label.modulate.a = 0.0
		_play_fullscreen_score_animation()
	else:
		game_over_title.text = "Keep it up!"
		game_over_title.visible = true
		game_over_title.add_theme_font_size_override("font_size", 36)
		var tw_swing := create_tween()
		tw_swing.set_loops()
		tw_swing.tween_property(game_over_title, "rotation", deg_to_rad(6.0), 0.3)
		tw_swing.tween_property(game_over_title, "rotation", deg_to_rad(-6.0), 0.3)
		tw_swing.tween_property(game_over_title, "rotation", 0.0, 0.15)

func _play_fullscreen_score_animation() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_screen.add_child(overlay)

	var big_label := Label.new()
	big_label.add_theme_font_size_override("font_size", 72)
	big_label.add_theme_color_override("font_color", Color("#F5C743"))
	big_label.size = Vector2(360, 160)
	big_label.position = Vector2(0, 240)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_label.clip_contents = false
	big_label.text = "0"
	game_over_screen.add_child(big_label)

	_start_fireworks_loop()
	var target := score
	var tw_count := create_tween()
	tw_count.tween_method(func(v: float):
		big_label.text = str(int(v))
	, 0.0, float(target), 2.0)

	tw_count.tween_callback(func():
		var target_pos := Vector2(180, 310)
		var target_scale := Vector2(0.3, 0.3)
		var tw_fly := create_tween()
		tw_fly.set_parallel(true)
		tw_fly.tween_property(big_label, "position", target_pos, 0.5)
		tw_fly.tween_property(big_label, "scale", target_scale, 0.5)
		tw_fly.tween_property(big_label, "modulate:a", 0.0, 0.5)
		tw_fly.tween_property(overlay, "modulate:a", 0.0, 0.5)
		tw_fly.chain().tween_callback(func():
			big_label.queue_free()
			overlay.queue_free()
			game_over_title.modulate.a = 0.0
			final_score_label.modulate.a = 0.0
			var tw_fadein := create_tween()
			tw_fadein.set_parallel(true)
			tw_fadein.tween_property(game_over_title, "modulate:a", 1.0, 0.4)
			tw_fadein.tween_property(final_score_label, "modulate:a", 1.0, 0.4)
			game_over_title.text = "★ New Record! ★"
			game_over_title.add_theme_font_size_override("font_size", 36)
			game_over_title.visible = true
			_play_record_sfx()
			var tw_pulse := create_tween()
			tw_pulse.set_loops()
			tw_pulse.tween_property(game_over_title, "scale", Vector2(1.05, 1.05), 0.5)
			tw_pulse.tween_property(game_over_title, "scale", Vector2(1.0, 1.0), 0.5)
			var rainbow_colors: Array[Color] = [
				Color("#F5C743"),
				Color("#FF6B6B"),
				Color("#FF6BFF"),
				Color("#6B9FFF"),
				Color("#6BFF6B"),
				Color("#F5C743"),
			]
			var tw_color := create_tween()
			tw_color.set_loops()
			for i in range(rainbow_colors.size() - 1):
				tw_color.tween_method(func(c: Color):
					game_over_title.add_theme_color_override("font_color", c)
				, rainbow_colors[i], rainbow_colors[i + 1], 0.3)
		)
	)

func _start_fireworks_loop() -> void:
	_fireworks_active = true
	_sfx_fireworks_loop.volume_db = 6.0
	print("[DEBUG] fireworks volume: ", _sfx_fireworks_loop.volume_db)
	print("[DEBUG] fireworks bus: ", _sfx_fireworks_loop.bus)
	if _sfx_fireworks_loop and _sfx_fireworks_loop.stream:
		_sfx_fireworks_loop.play()
	_fire_next_firework()

func _fire_next_firework() -> void:
	if not _fireworks_active:
		return
	var vp := get_viewport_rect().size
	var start_x := randf_range(vp.x * 0.1, vp.x * 0.9)
	var start_y := randf_range(vp.y * 0.75, vp.y * 0.95)
	var peak_x := start_x + randf_range(-vp.x * 0.15, vp.x * 0.15)
	var peak_y := randf_range(vp.y * 0.15, vp.y * 0.45)
	var colors := [Color("#F5C743"), Color("#FF6B6B"), Color("#6BFF6B"), Color("#6B9FFF"), Color("#FF6BFF")]
	var color: Color = colors[randi() % colors.size()]
	_launch_one_firework(Vector2(start_x, start_y), Vector2(peak_x, peak_y), color)
	var next_delay := randf_range(0.3, 0.5)
	get_tree().create_timer(next_delay).timeout.connect(func():
		_fire_next_firework()
	)

func _launch_one_firework(start: Vector2, peak: Vector2, color: Color) -> void:
	var rocket := Sprite2D.new()
	rocket.texture = preload("res://assets/characters/jump_up.png")
	var rand_scale := randf_range(0.25, 0.6)
	rocket.scale = Vector2(rand_scale, rand_scale)
	rocket.position = start
	game_over_screen.add_child(rocket)

	var tw := create_tween()
	tw.tween_property(rocket, "position", peak, 0.6)
	tw.parallel().tween_property(rocket, "rotation_degrees", 360.0, 0.6)

	tw.tween_callback(func():
		rocket.queue_free()
		_explode_firework(peak, color)
	)

func _explode_firework(pos: Vector2, color: Color) -> void:
	var directions: Array = []
	for i in range(8):
		var angle := i * (TAU / 8.0)
		directions.append(Vector2(cos(angle), sin(angle)))

	for i in range(8):
		var particle: Node
		if i % 2 == 0:
			var lbl := Label.new()
			lbl.text = "★"
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", color)
			lbl.position = pos
			game_over_screen.add_child(lbl)
			particle = lbl
		else:
			var spr := Sprite2D.new()
			spr.texture = preload("res://assets/characters/jump_land.png")
			var spr_scale := randf_range(0.15, 0.35)
			spr.scale = Vector2(spr_scale, spr_scale)
			spr.position = pos
			game_over_screen.add_child(spr)
			particle = spr

		var end_pos: Vector2 = pos + directions[i] * randf_range(60.0, 100.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(particle, "position", end_pos, 0.5)
		tw.tween_property(particle, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(func(): particle.queue_free())

func _play_record_sfx() -> void:
	if _sfx_record_whoop and _sfx_record_whoop.stream:
		_sfx_record_whoop.play()

func _spawn_stars() -> void:
	var center := Vector2(180, 300)
	var directions := [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1, 1),  Vector2(0, 1),  Vector2(1, 1)
	]
	for dir in directions:
		var star := Label.new()
		star.text = "★"
		star.add_theme_font_size_override("font_size", 24)
		star.add_theme_color_override("font_color", Color("#F5C743"))
		star.position = center
		game_over_screen.add_child(star)
		var tw := create_tween()
		tw.tween_property(star, "position", center + dir * 80, 0.6)
		tw.parallel().tween_property(star, "modulate:a", 0.0, 0.6)

func _get_spacing() -> float:
	if score < 200:
		return randf_range(60.0, 75.0)
	elif score < 600:
		return randf_range(80.0, 100.0)
	elif score < 1000:
		return randf_range(100.0, 120.0)
	else:
		return randf_range(120.0, 140.0)

func _no_overlap(x: float, y: float) -> bool:
	for child in platforms_node.get_children():
		if not "half_w" in child:
			continue
		var hw: float = child.get("half_w")
		if absf(child.position.x - x) < hw + Platform.CLOUD_W * 0.5 and \
		   absf(child.position.y - y) < Platform.CLOUD_H:
			return false
	return true

func _create_platform(x: float, y: float, ptype: int) -> Node2D:
	var p: Node2D = PLATFORM_SCENE.instantiate() as Node2D
	p.position = Vector2(x, y)
	p.platform_type = ptype
	var move_chance: float
	var move_speed: float
	if score < 200:
		move_chance = 0.0; move_speed = 0.0
	elif score < 600:
		move_chance = 0.20; move_speed = 100.0
	elif score < 1000:
		move_chance = 0.30; move_speed = 120.0
	else:
		move_chance = 0.40; move_speed = 140.0
	if randf() < move_chance and ptype != Platform.Type.DAMAGE:
		p.speed = move_speed
		p.direction = 1.0 if randf() > 0.5 else -1.0
	if ptype == Platform.Type.DAMAGE:
		p.hit_player.connect(_on_damage_cloud_hit_player.bind(p))
	platforms_node.add_child(p)
	_try_spawn_enemy(p, ptype)
	return p

func _get_double_params() -> Dictionary:
	if score < 100:
		return {"chance": 0.0, "y_min": 0.0, "y_max": 0.0}
	elif score < 300:
		return {"chance": 0.15, "y_min": 10.0, "y_max": 15.0}
	elif score < 500:
		return {"chance": 0.25, "y_min": 8.0, "y_max": 18.0}
	else:
		return {"chance": 0.35, "y_min": 5.0, "y_max": 20.0}

func _try_spawn_second(y: float, first_x: float, first_type: int) -> void:
	var params := _get_double_params()
	var chance: float = params["chance"]
	if chance == 0.0:
		return
	if _last_was_double:
		_last_was_double = false
		return
	if randf() > chance:
		return
	var vp_w := get_viewport_rect().size.x
	var second_x: float
	if first_x < vp_w / 2.0:
		second_x = randf_range(220.0, 295.0)
	else:
		second_x = randf_range(65.0, 140.0)
	var y_min: float = params["y_min"]
	var y_max: float = params["y_max"]
	var y_offset := randf_range(y_min, y_max)
	if randf() < 0.5:
		y_offset = -y_offset
	var second_y := y + y_offset
	var second_type: int
	var second_p: Node2D
	if score < 200:
		second_type = Platform.Type.NORMAL if randf() < 0.9 else Platform.Type.CRUMBLE
		second_p = _create_platform(second_x, second_y, second_type)
		second_p.speed = 0.0
	else:
		if first_type == Platform.Type.DAMAGE:
			second_type = Platform.Type.NORMAL
		else:
			second_type = _pick_platform_type()
			if second_type == Platform.Type.DAMAGE or second_type == Platform.Type.BRICK:
				second_type = Platform.Type.NORMAL
		_create_platform(second_x, second_y, second_type)
	_last_was_double = true

func _spawn_platform(y: float) -> void:
	var vp_w := get_viewport_rect().size.x
	var ptype := _pick_constrained_type()
	if ptype == Platform.Type.BRICK:
		for child in platforms_node.get_children():
			if "platform_type" in child and absf((child as Node2D).position.y - y) < 80.0:
				ptype = Platform.Type.NORMAL
				break

	var spawn_x: float = randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)
	for _try in 5:
		if _no_overlap(spawn_x, y):
			break
		spawn_x = randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)

	if score < 200:
		var zone := randi() % 3
		if zone == 0:
			spawn_x = randf_range(PLATFORM_MARGIN, 130.0)
		elif zone == 1:
			spawn_x = randf_range(115.0, 245.0)
		else:
			spawn_x = randf_range(230.0, vp_w - PLATFORM_MARGIN)

	if ptype == Platform.Type.BRICK and _last_spawn_x > 0.0:
		var mid := vp_w / 2.0
		if _last_spawn_x < mid:
			spawn_x = randf_range(mid + 20.0, vp_w - PLATFORM_MARGIN)
		else:
			spawn_x = randf_range(PLATFORM_MARGIN, mid - 20.0)

	var p := _create_platform(spawn_x, y, ptype)

	if score >= 100 and ptype == Platform.Type.NORMAL:
		_item_counter += 1
		if _item_counter >= _get_item_interval():
			_item_counter = 0
			_try_spawn_item(Vector2(p.position.x, camera.position.y - randf_range(50.0, 200.0)))

	var has_companion: bool = false
	if ptype == Platform.Type.DAMAGE:
		var px: float = p.position.x
		var comp_x: float = px + 130.0 if px + 130.0 <= vp_w - PLATFORM_MARGIN \
				else maxf(PLATFORM_MARGIN, px - 130.0)
		if not _no_overlap(comp_x, y):
			comp_x = px - 130.0 if px - 130.0 >= PLATFORM_MARGIN else px + 130.0
		_create_platform(comp_x, y, Platform.Type.NORMAL)
		has_companion = true

	if ptype == Platform.Type.BRICK:
		var comp_y := y + 65.0
		var comp_x := randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)
		for _try in 3:
			if _no_overlap(comp_x, comp_y):
				break
			comp_x = randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)
		_create_platform(comp_x, comp_y, Platform.Type.NORMAL)
		has_companion = true

	var spacing := maxf(0.0, _last_spawn_y - y)
	_last_spawn_y = y
	_last_spawn_x = spawn_x
	_last_two_types.append(ptype)
	if _last_two_types.size() > 2:
		_last_two_types.pop_front()
	if ptype == Platform.Type.NORMAL or ptype == Platform.Type.CRUMBLE or has_companion:
		_y_since_last_white = 0.0
	else:
		_y_since_last_white += spacing

	_try_spawn_second(y, spawn_x, ptype)

func _pick_constrained_type() -> int:
	if _y_since_last_white >= JUMP_HEIGHT * 0.6:
		return Platform.Type.NORMAL
	if _last_two_types.size() == 2:
		var a := _last_two_types[0]
		var b := _last_two_types[1]
		var a_haz := a == Platform.Type.CRUMBLE or a == Platform.Type.DAMAGE
		var b_haz := b == Platform.Type.CRUMBLE or b == Platform.Type.DAMAGE
		if a_haz and b_haz:
			return Platform.Type.NORMAL if randf() < 0.85 else Platform.Type.BRICK
	if score < 200:
		return Platform.Type.NORMAL if randf() < 0.9 else Platform.Type.CRUMBLE
	if _last_two_types.size() > 0 and _last_two_types.back() == Platform.Type.BRICK:
		var candidate := _pick_platform_type()
		return candidate if candidate != Platform.Type.BRICK else Platform.Type.NORMAL
	return _pick_platform_type()

func _pick_platform_type() -> int:
	var n: float
	var c: float
	var d: float
	if score < 200:
		n = 0.90; c = 0.10; d = 0.0
	elif score < 600:
		n = 0.70; c = 0.15; d = 0.05
	elif score < 1000:
		n = 0.55; c = 0.25; d = 0.10
	else:
		n = 0.45; c = 0.25; d = 0.15
	var r := randf()
	if r < n:
		return Platform.Type.NORMAL
	elif r < n + c:
		return Platform.Type.CRUMBLE
	elif r < n + c + d:
		return Platform.Type.DAMAGE
	else:
		return Platform.Type.BRICK

func _get_enemy_threshold() -> int:
	if score < 200:
		return 9999
	elif score < 600:
		return 10
	elif score < 1000:
		return 8
	else:
		return 6

func _try_spawn_enemy(p: Node2D, ptype: int) -> void:
	if ptype != Platform.Type.NORMAL and ptype != Platform.Type.BRICK:
		return
	if p.speed != 0.0:
		return
	_eligible_since_last_enemy += 1
	var threshold := 2 if DEV_ENEMY_TEST else _get_enemy_threshold()
	if _eligible_since_last_enemy < threshold:
		return
	if _enemies_node.get_child_count() >= MAX_ENEMIES:
		return
	_eligible_since_last_enemy = 0
	var moving := score >= 600
	var spd := 70.0 if score >= 1000 else 50.0
	var e := ENEMY_SCENE.instantiate()
	e.cloud_ref = p
	e.cloud_ref_half_h = Platform.BRICK_H * 0.5 if ptype == Platform.Type.BRICK else Platform.CLOUD_H * 0.5
	e.speed = spd if moving else 0.0
	e.direction = 1.0 if randf() > 0.5 else -1.0
	var cloud_half_h: float = e.cloud_ref_half_h
	_enemies_node.add_child(e)
	e.global_position = Vector2(p.global_position.x, p.global_position.y - cloud_half_h - 32.0)
	e.stomped.connect(_on_enemy_stomped)
	e.hit_player.connect(_on_player_damaged)

func _on_player_damaged() -> void:
	if game_over_flag or _invincible_timer > 0.0:
		return
	combo = 0
	_hide_combo()
	_show_game_over()

func _setup_dev_ui() -> void:
	var vp := get_viewport_rect().size
	var btn := Button.new()
	btn.text = "DEV"
	btn.size = Vector2(50, 28)
	btn.position = Vector2(vp.x - 58, vp.y - 36)
	btn.pressed.connect(_on_dev_button_pressed)
	_ui.add_child(btn)

	_dev_panel = PanelContainer.new()
	_dev_panel.visible = false
	_dev_panel.position = Vector2(vp.x * 0.5 - 90, vp.y * 0.5 - 50)
	_dev_panel.size = Vector2(180, 100)
	_ui.add_child(_dev_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dev_panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Set Score"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lbl)

	_dev_input = LineEdit.new()
	_dev_input.placeholder_text = "0"
	vbox.add_child(_dev_input)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.pressed.connect(_on_dev_ok_pressed)
	vbox.add_child(ok_btn)

func _on_dev_button_pressed() -> void:
	if _dev_panel:
		_dev_panel.visible = not _dev_panel.visible
		if _dev_panel.visible and _dev_input:
			_dev_input.text = str(score)

func _on_dev_ok_pressed() -> void:
	if not _dev_input:
		return
	var new_score := _dev_input.text.to_int()
	if new_score >= 0:
		score = new_score
		_check_bg_switch()
		start_y = player.position.y + float(score) * 100.0
		score_label.text = "Score  " + str(score)
	if _dev_panel:
		_dev_panel.visible = false

func _on_enemy_stomped() -> void:
	if _sfx_enemy_crush and _sfx_enemy_crush.stream:
		_sfx_enemy_crush.play()

func _on_enemy_crushed() -> void:
	score += 10
	_check_bg_switch()
	score_label.text = "Score  " + str(score)
	_spawn_score_popup("+10", player.global_position, Color(0.4, 0.85, 1.0, 1.0))
	_invincible_timer = 0.3

func _on_player_landed(landing_y: float) -> void:
	if _skip_combo_check:
		_skip_combo_check = false
		combo += 1
		_show_combo()
		var bonus: int = max(0, combo - 2)
		if bonus > 0:
			score += bonus
			_check_bg_switch()
			score_label.text = "Score  " + str(score)
			_spawn_score_popup("+" + str(bonus), player.global_position, Color(1.0, 0.9, 0.1, 1.0))
		last_landing_y = landing_y
		return
	if last_landing_y == 0.0:
		last_landing_y = landing_y
		return
	if landing_y < last_landing_y - 10.0:
		combo += 1
		_show_combo()
		var bonus: int = max(0, combo - 2)
		if bonus > 0:
			score += bonus
			_check_bg_switch()
			score_label.text = "Score  " + str(score)
			_spawn_score_popup("+" + str(bonus), player.global_position, Color(1.0, 0.9, 0.1, 1.0))
	else:
		combo = 0
		_hide_combo()
	last_landing_y = landing_y

func _show_combo() -> void:
	if combo < 3:
		_hide_combo()
		return
	var lbl := $UI/ComboLabel as Label
	lbl.text = "COMBO " + str(combo)
	lbl.visible = true
	var tween := create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
	var colors := [Color(1, 0.2, 0.2), Color(1, 0.8, 0), Color(0.2, 1, 0.2), Color(0.2, 0.8, 1), Color(0.8, 0.2, 1)]
	lbl.modulate = colors[combo % colors.size()]

func _hide_combo() -> void:
	var lbl := $UI/ComboLabel as Label
	if lbl:
		lbl.visible = false

func _get_item_interval() -> int:
	if score < 200:
		return 15
	elif score < 600:
		return 10
	elif score < 1000:
		return 8
	else:
		return 6

func _try_spawn_item(pos: Vector2) -> void:
	var item := ITEM_SCENE.instantiate()
	item.item_type = 0 if randf() < 0.15 else 1
	item.position = pos
	_items_node.add_child(item)
	item.collected.connect(_on_item_collected)

func _on_item_collected(type: int) -> void:
	match type:
		0:  # EXTRA_LIFE / 無敵
			_invincible_timer = INVINCIBLE_DURATION
			if s_lives < MAX_LIVES:
				s_lives += 1
				_update_hearts_ui()
		1:  # BOOST
			player.apply_boost()

func _check_bg_switch() -> void:
	var level: int
	if score < 200:
		level = 0
	elif score < 600:
		level = 1
	elif score < 1000:
		level = 2
	else:
		level = 3
	if level != _current_bg_level and not _bg_transitioning:
		_current_bg_level = level
		_transition_background(level)

func _spawn_score_popup(text: String, world_pos: Vector2, color: Color) -> void:
	var vp := get_viewport_rect().size
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.modulate = color
	lbl.z_index = 10
	var ui_pos := world_pos - camera.position + Vector2(vp.x * 0.5, vp.y * 0.5)
	lbl.position = ui_pos
	$UI.add_child(lbl)
	lbl.add_theme_constant_override("outline_size", 6)
	var outline_color: Color
	if color.r > 0.8 and color.g > 0.7:
		outline_color = Color(0.6, 0.3, 0.0, 0.8)
	else:
		outline_color = Color(0.0, 0.2, 0.5, 0.8)
	lbl.add_theme_color_override("font_outline_color", outline_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.scale = Vector2(1.4, 1.4)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "position", lbl.position + Vector2(0, -60), 0.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.tween_callback(lbl.queue_free).set_delay(0.8)

func _transition_background(level: int) -> void:
	_bg_transitioning = true
	var vp := get_viewport_rect().size
	var tw := create_tween()
	tw.tween_property(background, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		var tex: Texture2D = load(_bg_paths[level])
		if tex:
			background.texture = tex
			var bg_tex_size := tex.get_size()
			background.scale = Vector2(vp.x / bg_tex_size.x, vp.y / bg_tex_size.y)
	)
	tw.tween_property(background, "modulate:a", 1.0, 0.25)
	tw.tween_callback(func():
		_bg_transitioning = false
	)
