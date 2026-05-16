extends Node

const API_KEY := "AIzaSyDfMRL--8qTzpKIxbfdbJL0Ifzg8NYP1II"
const FIRESTORE_BASE := "https://firestore.googleapis.com/v1/projects/dragon-jump-f2b22/databases/(default)/documents"
const CFG_PATH := "user://player.cfg"
const CFG_SECTION := "player"

var player_name: String = ""
var player_country: String = "XX"

var _pending_lb: bool = false

signal score_result(is_new_record: bool)

# HTTP nodes
var _http_fetch: HTTPRequest
var _http_check: HTTPRequest
var _http_patch: HTTPRequest

# Canvas layer (keeps UI above all game CanvasLayers)
var _canvas: CanvasLayer = null

# UI nodes
var _name_dialog: Control = null
var _name_input: LineEdit = null
var _lb_overlay: Control = null
var _lb_vbox: VBoxContainer = null
var _lb_panel: PanelContainer = null

# Score to submit (set before check/patch flow)
var _submit_score_value: int = 0

# Holds JavaScriptObject reference so GC doesn't collect it
var _js_keyboard_cb = null

func _ready() -> void:

	# Load config
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		player_name = cfg.get_value(CFG_SECTION, "name", "")
		player_country = cfg.get_value(CFG_SECTION, "country", "XX")

	# Fetch country if not saved
	if player_country == "XX" or player_country == "":
		_fetch_country()

	# Build HTTP nodes
	_http_fetch = HTTPRequest.new()
	_http_fetch.name = "HttpFetch"
	add_child(_http_fetch)
	_http_fetch.request_completed.connect(_on_fetch_completed)

	_http_check = HTTPRequest.new()
	_http_check.name = "HttpCheck"
	add_child(_http_check)
	_http_check.request_completed.connect(_on_check_completed)

	_http_patch = HTTPRequest.new()
	_http_patch.name = "HttpPatch"
	add_child(_http_patch)
	_http_patch.request_completed.connect(_on_patch_completed)

	# CanvasLayer so UI renders above all game CanvasLayers (layer 1)
	_canvas = CanvasLayer.new()
	_canvas.layer = 10
	add_child(_canvas)

	# Build UI
	_build_name_dialog()
	_build_leaderboard_screen()

	# Show name dialog on first run
	if player_name == "":
		show_name_dialog(true)

# ─────────────────────────────────────────────
# Country fetch via ipapi.co
# ─────────────────────────────────────────────
var _http_country: HTTPRequest = null

func _fetch_country() -> void:
	_http_country = HTTPRequest.new()
	_http_country.name = "HttpCountry"
	add_child(_http_country)
	_http_country.request_completed.connect(_on_country_completed)
	_http_country.request("https://ipapi.co/json/")

func _on_country_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("country_code"):
				player_country = data["country_code"]
				_save_config()
	if is_instance_valid(_http_country):
		_http_country.queue_free()
		_http_country = null

# ─────────────────────────────────────────────
# Config save / load
# ─────────────────────────────────────────────
func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(CFG_SECTION, "name", player_name)
	cfg.set_value(CFG_SECTION, "country", player_country)
	cfg.save(CFG_PATH)

# ─────────────────────────────────────────────
# Country flag emoji helper
# ─────────────────────────────────────────────
func _flag_emoji(code: String) -> String:
	if code.length() != 2:
		return "🌍"
	var upper := code.to_upper()
	var a := upper.unicode_at(0)
	var b := upper.unicode_at(1)
	if a < 65 or a > 90 or b < 65 or b > 90:
		return "🌍"
	return String.chr(0x1F1E6 + a - 65) + String.chr(0x1F1E6 + b - 65)

# ─────────────────────────────────────────────
# Build Name Dialog UI
# ─────────────────────────────────────────────
func _build_name_dialog() -> void:
	# Full-screen overlay
	_name_dialog = ColorRect.new()
	(_name_dialog as ColorRect).color = Color(0, 0, 0, 0.85)
	_name_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_name_dialog.visible = false
	_canvas.add_child(_name_dialog)

	# Centered panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 210)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_name_dialog.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Dragon Jump"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "Enter your player name"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	vbox.add_child(sub)

	# LineEdit
	_name_input = LineEdit.new()
	_name_input.max_length = 20
	_name_input.placeholder_text = "Your name"
	_name_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_name_input)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.name = "CancelBtn"
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(_on_name_cancel)
	btn_row.add_child(cancel_btn)

	var ok_btn := Button.new()
	ok_btn.text = "OK"
	ok_btn.add_theme_font_size_override("font_size", 16)
	ok_btn.pressed.connect(_on_name_ok)
	btn_row.add_child(ok_btn)

# ─────────────────────────────────────────────
# Build Leaderboard Screen UI
# ─────────────────────────────────────────────
func _build_leaderboard_screen() -> void:
	# Full-screen dark overlay (blocks game canvas when visible)
	_lb_overlay = ColorRect.new()
	(_lb_overlay as ColorRect).color = Color(0, 0, 0, 0.85)
	_lb_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lb_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_lb_overlay.visible = false
	_canvas.add_child(_lb_overlay)

	# Centered panel
	_lb_panel = PanelContainer.new()
	_lb_panel.custom_minimum_size = Vector2(320, 530)
	_lb_panel.set_anchors_preset(Control.PRESET_CENTER)
	_lb_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lb_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_lb_overlay.add_child(_lb_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_lb_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Leaderboard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# ScrollContainer
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 420)
	vbox.add_child(scroll)

	_lb_vbox = VBoxContainer.new()
	_lb_vbox.custom_minimum_size = Vector2(300, 0)
	_lb_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_lb_vbox)

	# Share button
	var share_btn := Button.new()
	share_btn.text = "分享成績"
	share_btn.add_theme_font_size_override("font_size", 18)
	share_btn.pressed.connect(func(): share_score(_submit_score_value))
	vbox.add_child(share_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(_on_lb_close)
	vbox.add_child(close_btn)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────
func show_name_dialog(first_time: bool) -> void:
	if not is_instance_valid(_name_dialog):
		return
	_name_input.text = player_name
	var cancel_btn := _name_dialog.find_child("CancelBtn", true, false)
	if is_instance_valid(cancel_btn):
		cancel_btn.visible = not first_time
	_name_dialog.visible = true
	_name_input.grab_focus()
	_open_mobile_keyboard()

func show_leaderboard() -> void:
	if player_name == "":
		_pending_lb = true
		show_name_dialog(true)
		return
	if not is_instance_valid(_lb_overlay):
		return
	_lb_overlay.visible = true
	_clear_lb_entries()
	var loading := Label.new()
	loading.text = "Loading..."
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_vbox.add_child(loading)
	_do_fetch_leaderboard()

func submit_score(score: int) -> void:
	if player_name == "":
		return
	_submit_score_value = score
	_do_check_score()

# ─────────────────────────────────────────────
# Name dialog callbacks
# ─────────────────────────────────────────────
func _on_name_ok() -> void:
	print("[DEBUG] _on_name_ok() called")
	var raw: String = _name_input.text
	print("[DEBUG] _name_input.text = '%s'" % raw)
	if OS.get_name() == "Web":
		var elem = JavaScriptBridge.eval("document.getElementById('_gkb')")
		if elem != null:
			var val = JavaScriptBridge.eval("document.getElementById('_gkb').value")
			print("[DEBUG] JS _gkb value = '%s' (type: %s)" % [val, typeof(val)])
			if val is String:
				raw = val
				print("[DEBUG] Using JS value: '%s'" % raw)
	var name := raw.strip_edges().substr(0, 20)
	print("[DEBUG] Final name after strip/substr = '%s'" % name)
	if name == "":
		print("[DEBUG] Name is empty, returning")
		return
	player_name = name
	print("[DEBUG] player_name set to '%s'" % player_name)
	_save_config()
	print("[DEBUG] Config saved, removing focus from _name_input")
	if is_instance_valid(_name_input):
		_name_input.release_focus()
	print("[DEBUG] Focus released, calling _close_mobile_keyboard()")
	_close_mobile_keyboard()
	print("[DEBUG] _close_mobile_keyboard() done, hiding dialog")
	_name_dialog.visible = false
	print("[DEBUG] Dialog hidden")
	if _pending_lb:
		print("[DEBUG] _pending_lb is true, showing leaderboard")
		_pending_lb = false
		show_leaderboard()
	print("[DEBUG] _on_name_ok() complete")

func _on_name_cancel() -> void:
	_close_mobile_keyboard()
	_name_dialog.visible = false

# ─────────────────────────────────────────────
# Leaderboard close
# ─────────────────────────────────────────────
func _on_lb_close() -> void:
	if is_instance_valid(_lb_overlay):
		_lb_overlay.visible = false

# ─────────────────────────────────────────────
# Firebase: Fetch leaderboard (POST runQuery)
# ─────────────────────────────────────────────
func _do_fetch_leaderboard() -> void:
	var url := FIRESTORE_BASE + ":runQuery?key=" + API_KEY
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := '{"structuredQuery":{"from":[{"collectionId":"leaderboard"}],"orderBy":[{"field":{"fieldPath":"score"},"direction":"DESCENDING"}],"limit":20}}'
	_http_fetch.request(url, headers, HTTPClient.METHOD_POST, body)

func _on_fetch_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_clear_lb_entries()
	if response_code != 200:
		_add_lb_message("Error loading scores (" + str(response_code) + ")")
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_add_lb_message("Parse error")
		return
	var data = json.get_data()
	if not data is Array or data.size() == 0:
		_add_lb_message("No scores yet!")
		return

	var rank: int = 0
	for item in data:
		if not item is Dictionary:
			continue
		if not item.has("document"):
			continue
		var doc = item["document"]
		if not doc is Dictionary or not doc.has("fields"):
			continue
		var fields = doc["fields"]
		var name_val: String = ""
		var score_val: int = 0
		var country_val: String = "XX"
		var date_val: String = ""
		if fields.has("name") and fields["name"].has("stringValue"):
			name_val = fields["name"]["stringValue"]
		if fields.has("score"):
			var sv = fields["score"]
			if sv.has("integerValue"):
				score_val = int(str(sv["integerValue"]))
		if fields.has("country") and fields["country"].has("stringValue"):
			country_val = fields["country"]["stringValue"]
		if fields.has("date") and fields["date"].has("stringValue"):
			date_val = fields["date"]["stringValue"]
		rank += 1
		_add_lb_entry(rank, name_val, country_val, score_val, date_val)

func _add_lb_message(msg: String) -> void:
	var lbl := Label.new()
	lbl.text = msg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_vbox.add_child(lbl)

func _add_lb_entry(rank: int, name_val: String, country_val: String, score_val: int, date_val: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_lb_vbox.add_child(row)

	# Rank medal or number
	var rank_lbl := Label.new()
	if rank == 1:
		rank_lbl.text = "1"
	elif rank == 2:
		rank_lbl.text = "2"
	elif rank == 3:
		rank_lbl.text = "3"
	else:
		rank_lbl.text = str(rank)
	rank_lbl.custom_minimum_size = Vector2(30, 0)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(rank_lbl)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = name_val
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	if name_val == player_name:
		name_lbl.add_theme_color_override("font_color", Color(0.36, 0.78, 0.96, 1.0))
	row.add_child(name_lbl)

	# Country flag
	var flag_lbl := Label.new()
	flag_lbl.text = _flag_emoji(country_val)
	flag_lbl.custom_minimum_size = Vector2(28, 0)
	flag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flag_lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(flag_lbl)

	# Score
	var score_lbl := Label.new()
	score_lbl.text = str(score_val)
	score_lbl.custom_minimum_size = Vector2(50, 0)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_lbl.add_theme_font_size_override("font_size", 15)
	score_lbl.add_theme_color_override("font_color", Color(0.96, 0.78, 0.26, 1.0))
	row.add_child(score_lbl)

	# Date
	var date_lbl := Label.new()
	date_lbl.text = date_val.substr(0, 10) if date_val.length() >= 10 else date_val
	date_lbl.custom_minimum_size = Vector2(70, 0)
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	date_lbl.add_theme_font_size_override("font_size", 12)
	date_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	row.add_child(date_lbl)

func _clear_lb_entries() -> void:
	if is_instance_valid(_lb_vbox):
		for child in _lb_vbox.get_children():
			child.queue_free()

# ─────────────────────────────────────────────
# Firebase: Check existing score (GET)
# ─────────────────────────────────────────────
func _do_check_score() -> void:
	var url := FIRESTORE_BASE + "/leaderboard/" + player_name.uri_encode() + "?key=" + API_KEY
	_http_check.request(url, PackedStringArray(), HTTPClient.METHOD_GET, "")

func _on_check_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 404:
		# No existing doc — submit directly
		score_result.emit(true)
		_do_patch_score()
		return
	if response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("fields"):
				var fields = data["fields"]
				if fields.has("score") and fields["score"].has("integerValue"):
					var existing: int = int(str(fields["score"]["integerValue"]))
					if _submit_score_value > existing:
						score_result.emit(true)
						_do_patch_score()
					else:
						score_result.emit(false)
					return
		# Parse failed — submit anyway
		score_result.emit(true)
		_do_patch_score()
	else:
		push_warning("[Leaderboard] Check score error code: %d — skipping submit." % response_code)

# ─────────────────────────────────────────────
# Firebase: Patch/update score (PATCH)
# ─────────────────────────────────────────────
func _do_patch_score() -> void:
	var today := Time.get_datetime_string_from_system().substr(0, 10)
	var url := FIRESTORE_BASE + "/leaderboard/" + player_name.uri_encode() \
		+ "?key=" + API_KEY \
		+ "&updateMask.fieldPaths=name&updateMask.fieldPaths=score&updateMask.fieldPaths=country&updateMask.fieldPaths=date"
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := '{"fields":{"name":{"stringValue":"' + player_name.replace('"', '\\"') \
		+ '"},"score":{"integerValue":"' + str(_submit_score_value) \
		+ '"},"country":{"stringValue":"' + player_country.replace('"', '\\"') \
		+ '"},"date":{"stringValue":"' + today + '"}}}'
	_http_patch.request(url, headers, HTTPClient.METHOD_PATCH, body)

func _on_patch_completed(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if response_code != 200 and response_code != 201:
		push_error("[Leaderboard] Score submit error code: %d" % response_code)

# ─────────────────────────────────────────────
# Mobile keyboard helpers (Web only)
# ─────────────────────────────────────────────
func _open_mobile_keyboard() -> void:
	print("[DEBUG] _open_mobile_keyboard() called")
	if OS.get_name() != "Web":
		print("[DEBUG] Not Web, returning")
		return

	_js_keyboard_cb = JavaScriptBridge.create_callback(func(_args: Array):
		print("[DEBUG] JS callback triggered with args: %s" % _args)
		if is_instance_valid(_name_input):
			var val = JavaScriptBridge.eval("document.getElementById('_gkb')?.value??''")
			if val is String:
				print("[DEBUG] JS callback: setting _name_input.text to '%s'" % val)
				_name_input.text = val
				_name_input.caret_column = _name_input.text.length()
	)
	var window := JavaScriptBridge.get_interface("window")
	window._godotKbCb = _js_keyboard_cb

	var safe_val := _name_input.text.replace("\\", "\\\\").replace("'", "\\'")
	var js := "(function(){"
	js += "var o=document.getElementById('_gkb');if(o)o.remove();"
	js += "var e=document.createElement('input');"
	js += "e.id='_gkb';e.type='text';e.maxLength=20;e.value='" + safe_val + "';"
	# opacity:0.01 (not 0) — iOS won't focus invisible elements
	js += "e.style.cssText='position:fixed;opacity:0.01;top:50%;left:50%;width:1px;height:1px;border:none;outline:none;z-index:9999;';"
	js += "document.body.appendChild(e);"
	js += "e.focus();"
	# Canvas touchstart handler: iOS requires focus() inside a user-gesture callback
	js += "var c=document.querySelector('canvas');"
	js += "if(c){e._th=function(){e.focus();};c.addEventListener('touchstart',e._th,{passive:true});}"
	js += "e.addEventListener('input',function(){window._godotKbCb([e.value]);});"
	js += "e.addEventListener('blur',function(){console.log('[JS] blur event fired'); window._godotKbCb([e.value]);});"
	js += "})();"
	JavaScriptBridge.eval(js)
	print("[DEBUG] _open_mobile_keyboard() complete")

func _close_mobile_keyboard() -> void:
	print("[DEBUG] _close_mobile_keyboard() called")
	if OS.get_name() != "Web":
		print("[DEBUG] Not Web, returning")
		return
	var js := "var e=document.getElementById('_gkb');"
	js += "if(e){"
	js += "console.log('[JS] blur and removing _gkb input');"
	js += "e.blur();"
	js += "var c=document.querySelector('canvas');"
	js += "if(c&&e._th){console.log('[JS] removing touchstart listener'); c.removeEventListener('touchstart',e._th);}"
	js += "e.remove();"
	js += "console.log('[JS] focusing canvas to prevent keyboard reopening');"
	js += "if(c){c.focus();}}"
	js += "else{console.log('[JS] _gkb not found');}"
	JavaScriptBridge.eval(js)
	_js_keyboard_cb = null
	print("[DEBUG] _close_mobile_keyboard() complete")

# ─────────────────────────────────────────────
# Share
# ─────────────────────────────────────────────
func share_score(score_val: int) -> void:
	var share_text := "我在 Not-so-ugly Dragon 跳了 %d 分！來挑戰我！" % score_val
	var share_url := "https://leo70623.github.io/Dragon_jump/"
	if OS.get_name() == "Web":
		var safe_text := share_text.replace("\\", "\\\\").replace("'", "\\'")
		var js := "var t='" + safe_text + "';var u='" + share_url + "';"
		js += "if(navigator.share){navigator.share({title:'Not-so-ugly Dragon',text:t,url:u})}"
		js += "else{navigator.clipboard.writeText(t+' '+u).then(function(){alert('已複製！')})}"
		JavaScriptBridge.eval(js)
	else:
		DisplayServer.clipboard_set(share_text + " " + share_url)
		_show_copy_toast()

func _show_copy_toast() -> void:
	var toast := Label.new()
	toast.text = "已複製！"
	toast.add_theme_font_size_override("font_size", 22)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BOTH
	toast.offset_top = -30.0
	_canvas.add_child(toast)
	var tw := toast.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): if is_instance_valid(toast): toast.queue_free())
