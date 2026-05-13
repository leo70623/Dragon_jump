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
@onready var hint_label: Label = $UI/GameOverScreen/HintLabel
@onready var cooldown_label: Label = $UI/GameOverScreen/CooldownLabel
@onready var _restart_btn: Button = $UI/GameOverScreen/RestartButton
@onready var _bgm: AudioStreamPlayer = $BGM
@onready var _enemies_node: Node2D = $Enemies
@onready var _items_node: Node2D = $Items

var _sfx_spin: AudioStreamPlayer
var _sfx_death_shout: AudioStreamPlayer
var _sfx_enemy_crush: AudioStreamPlayer
var hearts: Array[Sprite2D] = []
var next_spawn_y: float = 0.0
var score: int = 0
var start_y: float = 0.0
var game_over_flag: bool = false
var _last_two_types: Array[int] = []
var _y_since_last_white: float = 0.0
var _last_spawn_y: float = 0.0
var _eligible_since_last_enemy: int = 0
var _item_counter: int = 0
var _invincible_timer: float = 0.0
var _current_bg_level: int = 0
var _bg_transitioning: bool = false
var _bg_paths: Array[String] = ["res://assets/backgrounds/BG_01.png", "res://assets/backgrounds/BG_02.png", "res://assets/backgrounds/BG_03.png", "res://assets/backgrounds/BG_04.png"]
var _dev_panel: Control = null
var _dev_input: LineEdit = null
var _status_label: Label = null

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
	score = 100
	start_y = player.position.y + float(score) * 100.0
	score_label.text = "Score  " + str(score)

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

	var new_score := int((start_y - player.position.y) / 100.0)
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
	_invincible_timer = 0.0
	player.modulate.a = 1.0
	player.set_physics_process(false)
	if s_lives > 0:
		s_lives -= 1
		s_regen_elapsed = 0.0
		_update_hearts_ui()
	final_score_label.text = "Score: " + str(score)
	_update_cooldown_label()
	Leaderboard.submit_score(score)
	var lb_btn := Button.new()
	lb_btn.text = "Leaderboard"
	lb_btn.add_theme_font_size_override("font_size", 18)
	lb_btn.size = Vector2(120, 38)
	lb_btn.position = Vector2(20.0, 465.0)
	lb_btn.pressed.connect(func(): Leaderboard.show_leaderboard())
	game_over_screen.add_child(lb_btn)

	var share_btn := Button.new()
	share_btn.text = "Share"
	share_btn.add_theme_font_size_override("font_size", 18)
	share_btn.size = Vector2(120, 38)
	share_btn.position = Vector2(220.0, 465.0)
	share_btn.pressed.connect(func(): Leaderboard.share_score(score))
	game_over_screen.add_child(share_btn)
	if _sfx_death_shout and _sfx_death_shout.stream:
		_sfx_death_shout.play()
	player.visible = false
	_spawn_death_spin()

func _spawn_death_spin() -> void:
	var tex: Texture2D = load("res://assets/enemies/game_over_spin.png")
	if not tex:
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
		game_over_screen.visible = true
	)

func _on_restart_btn_pressed() -> void:
	if game_over_flag and s_lives > 0:
		get_tree().reload_current_scene()

func _get_spacing() -> float:
	var level := score / 100
	var sp_min := minf(SPACING_MIN + level * SPACING_LEVEL_STEP, SPACING_MIN_CAP)
	var sp_max := minf(SPACING_MAX + level * SPACING_LEVEL_STEP * 1.3, SPACING_MAX_CAP)
	return minf(randf_range(sp_min, sp_max), JUMP_HEIGHT * 0.8)

func _no_overlap(x: float, y: float) -> bool:
	for child in platforms_node.get_children():
		if not "half_w" in child:
			continue
		var hw: float = child.get("half_w")
		if absf(child.position.x - x) < hw + Platform.CLOUD_W * 0.5 and \
		   absf(child.position.y - y) < Platform.CLOUD_H:
			return false
	return true

func _spawn_platform(y: float) -> void:
	var vp_w := get_viewport_rect().size.x
	var ptype := _pick_constrained_type()
	if ptype == Platform.Type.BRICK:
		for child in platforms_node.get_children():
			if "platform_type" in child and absf((child as Node2D).position.y - y) < 80.0:
				ptype = Platform.Type.NORMAL
				break
	var p := PLATFORM_SCENE.instantiate()

	var spawn_x: float = randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)
	for _try in 5:
		if _no_overlap(spawn_x, y):
			break
		spawn_x = randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)
	p.position = Vector2(spawn_x, y)
	p.platform_type = ptype

	var level := score / 100
	var move_chance := minf(0.30 + level * 0.15, 0.85)
	if randf() < move_chance and ptype != Platform.Type.DAMAGE:
		p.speed = minf(80.0 + level * 25.0, 220.0)
		p.direction = 1.0 if randf() > 0.5 else -1.0

	if ptype == Platform.Type.DAMAGE:
		p.hit_player.connect(_on_damage_cloud_hit_player.bind(p))
	platforms_node.add_child(p)

	if score >= 100 and ptype == Platform.Type.NORMAL:
		_item_counter += 1
		if _item_counter >= ITEM_SPAWN_INTERVAL:
			_item_counter = 0
			_try_spawn_item(Vector2(p.position.x, camera.position.y - randf_range(50.0, 200.0)))

	_try_spawn_enemy(p, ptype)

	var has_companion: bool = false
	if ptype == Platform.Type.DAMAGE:
		var px: float = (p as Node2D).position.x
		var comp_x: float = px + 130.0 if px + 130.0 <= vp_w - PLATFORM_MARGIN \
				else maxf(PLATFORM_MARGIN, px - 130.0)
		if not _no_overlap(comp_x, y):
			comp_x = px - 130.0 if px - 130.0 >= PLATFORM_MARGIN else px + 130.0
		var pw := PLATFORM_SCENE.instantiate()
		pw.position = Vector2(comp_x, y)
		pw.platform_type = Platform.Type.NORMAL
		platforms_node.add_child(pw)
		_try_spawn_enemy(pw, Platform.Type.NORMAL)
		has_companion = true

	if ptype == Platform.Type.BRICK:
		var comp_y := y + 65.0
		var comp_x := randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)
		for _try in 3:
			if _no_overlap(comp_x, comp_y):
				break
			comp_x = randf_range(PLATFORM_MARGIN, vp_w - PLATFORM_MARGIN)
		var pw := PLATFORM_SCENE.instantiate()
		pw.position = Vector2(comp_x, comp_y)
		pw.platform_type = Platform.Type.NORMAL
		platforms_node.add_child(pw)
		has_companion = true

	var spacing := maxf(0.0, _last_spawn_y - y)
	_last_spawn_y = y
	_last_two_types.append(ptype)
	if _last_two_types.size() > 2:
		_last_two_types.pop_front()
	if ptype == Platform.Type.NORMAL or ptype == Platform.Type.CRUMBLE or has_companion:
		_y_since_last_white = 0.0
	else:
		_y_since_last_white += spacing

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
	if _last_two_types.size() > 0 and _last_two_types.back() == Platform.Type.BRICK:
		var candidate := _pick_platform_type()
		return candidate if candidate != Platform.Type.BRICK else Platform.Type.NORMAL
	return _pick_platform_type()

func _pick_platform_type() -> int:
	var level := score / 100
	var normal_prob := maxf(0.60 - level * 0.07, 0.28)
	var crumble_prob := minf(0.20 + level * 0.03, 0.32)
	var damage_prob: float = 0.0
	if score >= 50:
		damage_prob = minf(0.10 + int((score - 50) / 100) * 0.05, 0.40)
	var r := randf()
	if r < normal_prob:
		return Platform.Type.NORMAL
	elif r < normal_prob + crumble_prob:
		return Platform.Type.CRUMBLE
	elif r < normal_prob + crumble_prob + damage_prob:
		return Platform.Type.DAMAGE
	else:
		return Platform.Type.BRICK

func _get_enemy_threshold() -> int:
	if score < 100:
		return 9999
	elif score < 200:
		return 5
	elif score < 400:
		return 4
	else:
		return 3

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
	var moving := score >= 300
	var spd := 100.0 if score >= 400 else 60.0
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
		start_y = player.position.y + float(score) * 100.0
		score_label.text = "Score  " + str(score)
	if _dev_panel:
		_dev_panel.visible = false

func _on_enemy_stomped() -> void:
	if _sfx_enemy_crush and _sfx_enemy_crush.stream:
		_sfx_enemy_crush.play()

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
	var level := mini(score / 200, 3)
	if level != _current_bg_level and not _bg_transitioning:
		_current_bg_level = level
		_transition_background(level)

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
