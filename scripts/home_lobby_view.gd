class_name HomeLobbyView
extends Control

## Store-Ready Commercial Home Lobby for《合炮大爆破 Fuse Smash!》
## Eliminates the "blank white test screen" feel with a complete App-Store-grade landing UI:
##  - Bold Stylized Arcade Logo Banner ("FUSE SMASH! / 合炮大爆破")
##  - Top Status Bar (Coins / Hearts / Win Streak / Settings)
##  - Center Live Rotating 3D Floating Island Showcase (Ch.1 / Ch.2 GLB)
##  - Tactile Glossy 3D-Bevel PLAY CTA Button ("开始闯关 · LEVEL X")
##  - Bottom 4-Tab Pure White Navigation Bar (60关地图 / 浮空岛 / 每日任务 / 商店)

signal play_pressed()
signal open_island_pressed()
signal open_levels_pressed()
signal open_tasks_pressed()
signal open_shop_pressed()
signal open_settings_pressed()

var audio: ArcadeAudio
var services: StoreServices
var repo: LevelRepository
var icons: Dictionary = {}

var lbl_coins: Label
var lbl_lives: Label
var lbl_streak: Label
var lbl_chapter_pill: Label
var lbl_island_prog: Label
var btn_play: Button
var lbl_play_sub: Label

var island_sub_vp: SubViewport
var island_pivot: Node3D
var loaded_chapter_idx: int = -1
var clock: float = 0.0
var gray_mat: StandardMaterial3D


func setup(p_audio: ArcadeAudio, p_services: StoreServices, p_repo: LevelRepository, p_icons: Dictionary, p_font: Font) -> void:
	audio = p_audio
	services = p_services
	repo = p_repo
	icons = p_icons
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 30

	gray_mat = StandardMaterial3D.new()
	gray_mat.albedo_color = Color(0.76, 0.80, 0.86)
	gray_mat.roughness = 0.62

	# Clean cool-architectural light blue-gray backdrop (#DCE6F2 -> #F4F8FD)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.875, 0.914, 0.957, 1.0)
	add_child(bg)

	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(wrap)

	var shell := VBoxContainer.new()
	shell.custom_minimum_size = Vector2(540, 960)
	shell.add_theme_constant_override("separation", 12)
	wrap.add_child(shell)

	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_right", 18)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 20)
	shell.add_child(pad)

	var root_v := VBoxContainer.new()
	root_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_theme_constant_override("separation", 12)
	pad.add_child(root_v)

	# --- 1. TOP STATUS BAR ---
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 8)
	root_v.add_child(top_h)

	var coin_btn := Button.new()
	coin_btn.custom_minimum_size = Vector2(114, 42)
	_style_white_btn(coin_btn, 21)
	coin_btn.pressed.connect(func():
		audio.play_ui_click()
		open_shop_pressed.emit()
	)
	var ch := HBoxContainer.new()
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_theme_constant_override("separation", 6)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_btn.add_child(ch)
	ch.add_child(_mk_icon("icon_coin", Vector2(24, 24)))
	lbl_coins = _mk_lbl("350", 17, Color(0.118, 0.161, 0.231), p_font)
	ch.add_child(lbl_coins)
	top_h.add_child(coin_btn)

	var life_pill := PanelContainer.new()
	life_pill.custom_minimum_size = Vector2(96, 42)
	life_pill.add_theme_stylebox_override("panel", _mk_box(Color.WHITE, 21, 8, Color(0.85, 0.89, 0.95), 1))
	var lh := HBoxContainer.new()
	lh.alignment = BoxContainer.ALIGNMENT_CENTER
	lh.add_theme_constant_override("separation", 5)
	life_pill.add_child(lh)
	lh.add_child(_mk_icon("icon_heart", Vector2(20, 20)))
	lbl_lives = _mk_lbl("5/5", 15, Color(0.118, 0.161, 0.231), p_font)
	lh.add_child(lbl_lives)
	top_h.add_child(life_pill)

	var streak_pill := PanelContainer.new()
	streak_pill.custom_minimum_size = Vector2(88, 42)
	streak_pill.add_theme_stylebox_override("panel", _mk_box(Color(1.0, 0.96, 0.86), 21, 6, Color(1.0, 0.78, 0.18), 1))
	var sth := HBoxContainer.new()
	sth.alignment = BoxContainer.ALIGNMENT_CENTER
	sth.add_theme_constant_override("separation", 4)
	streak_pill.add_child(sth)
	sth.add_child(_mk_icon("icon_streak", Vector2(20, 20)))
	lbl_streak = _mk_lbl("0连胜", 13, Color(0.68, 0.34, 0.02), p_font)
	sth.add_child(lbl_streak)
	top_h.add_child(streak_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(spacer)

	var set_btn := Button.new()
	set_btn.custom_minimum_size = Vector2(44, 44)
	_style_white_btn(set_btn, 14)
	var sic := _mk_icon("icon_settings", Vector2(24, 24))
	sic.set_anchors_preset(Control.PRESET_CENTER)
	sic.offset_left = -12; sic.offset_top = -12; sic.offset_right = 12; sic.offset_bottom = 12
	set_btn.add_child(sic)
	set_btn.pressed.connect(func():
		audio.play_ui_click()
		open_settings_pressed.emit()
	)
	top_h.add_child(set_btn)

	# --- 2. BOLD ARCADE TITLE BANNER ---
	var logo_box := VBoxContainer.new()
	logo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_box.add_theme_constant_override("separation", 4)
	root_v.add_child(logo_box)

	var lbl_en := Label.new()
	lbl_en.text = "FUSE SMASH!"
	lbl_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_en.add_theme_font_size_override("font_size", 44)
	lbl_en.add_theme_color_override("font_color", Color(0.114, 0.388, 0.929))
	lbl_en.add_theme_color_override("font_outline_color", Color.WHITE)
	lbl_en.add_theme_constant_override("outline_size", 10)
	if p_font:
		lbl_en.add_theme_font_override("font", p_font)
	logo_box.add_child(lbl_en)

	var sub_wrap := CenterContainer.new()
	logo_box.add_child(sub_wrap)
	var sub_pill := PanelContainer.new()
	sub_pill.add_theme_stylebox_override("panel", _mk_box(Color(1.0, 0.816, 0.078), 14, 6, Color(0.86, 0.58, 0.02), 2))
	sub_wrap.add_child(sub_pill)
	var lbl_zh := _mk_lbl("  ⚡ 合炮大爆破 · 同色合炮 × 脉冲核爆破  ", 13, Color(0.38, 0.20, 0.0), p_font)
	sub_pill.add_child(lbl_zh)

	# --- 3. LIVE 3D FLOATING ISLAND HERO SHOWCASE ---
	var island_card := PanelContainer.new()
	island_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	island_card.add_theme_stylebox_override("panel", _mk_box(Color(0.955, 0.975, 1.0, 0.92), 26, 14, Color.WHITE, 2))
	root_v.add_child(island_card)

	var isl_overlay := Control.new()
	isl_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	island_card.add_child(isl_overlay)

	var vp_cont := SubViewportContainer.new()
	vp_cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp_cont.stretch = true
	isl_overlay.add_child(vp_cont)

	island_sub_vp = SubViewport.new()
	island_sub_vp.own_world_3d = true
	island_sub_vp.transparent_bg = true
	island_sub_vp.msaa_3d = Viewport.MSAA_2X
	island_sub_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp_cont.add_child(island_sub_vp)

	var cam := Camera3D.new()
	cam.fov = 34.0
	island_sub_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 4.1, 8.6), Vector3(0.0, 0.85, 0.0), Vector3.UP)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.92, 0.95, 0.98, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.90, 0.94, 1.0)
	env.ambient_light_energy = 0.72
	var we := WorldEnvironment.new()
	we.environment = env
	island_sub_vp.add_child(we)

	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	dl.light_energy = 1.38
	island_sub_vp.add_child(dl)

	island_pivot = Node3D.new()
	island_sub_vp.add_child(island_pivot)

	# Island Top Pill + Bottom Quick-Paint Button
	var isl_top := HBoxContainer.new()
	isl_top.anchor_left = 0.0; isl_top.anchor_right = 1.0
	isl_top.offset_left = 12; isl_top.offset_right = -12; isl_top.offset_top = 10; isl_top.offset_bottom = 44
	isl_overlay.add_child(isl_top)

	var ch_p := PanelContainer.new()
	ch_p.add_theme_stylebox_override("panel", _mk_box(Color(1, 1, 1, 0.92), 14, 4, Color(0.84, 0.89, 0.95), 1))
	lbl_chapter_pill = _mk_lbl("Ch.1 积木启航岛", 13, Color(0.118, 0.161, 0.231), p_font)
	ch_p.add_child(lbl_chapter_pill)
	isl_top.add_child(ch_p)

	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	isl_top.add_child(sp2)

	var paint_btn := Button.new()
	paint_btn.custom_minimum_size = Vector2(116, 34)
	_style_color_btn(paint_btn, Color(1.0, 0.541, 0.122), Color(0.76, 0.34, 0.04), Color.WHITE, 14, 13)
	paint_btn.text = "🎨 喷涂浮空岛"
	paint_btn.pressed.connect(func():
		audio.play_ui_click()
		open_island_pressed.emit()
	)
	isl_top.add_child(paint_btn)

	lbl_island_prog = _mk_lbl("浮空岛地标 0/5 · 能量 0/500", 12, Color(0.32, 0.40, 0.52), p_font)
	lbl_island_prog.anchor_left = 0.0; lbl_island_prog.anchor_right = 1.0
	lbl_island_prog.anchor_top = 1.0; lbl_island_prog.anchor_bottom = 1.0
	lbl_island_prog.offset_top = -30; lbl_island_prog.offset_bottom = -8
	lbl_island_prog.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	isl_overlay.add_child(lbl_island_prog)

	# --- 4. BIG TACTILE GLOSSY PLAY CTA ---
	btn_play = Button.new()
	btn_play.custom_minimum_size = Vector2(0, 82)
	_style_color_btn(btn_play, Color(0.078, 0.722, 0.400), Color(0.035, 0.480, 0.250), Color.WHITE, 24, 24)
	btn_play.pressed.connect(func():
		audio.play_ui_click()
		play_pressed.emit()
	)
	var play_v := VBoxContainer.new()
	play_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	play_v.alignment = BoxContainer.ALIGNMENT_CENTER
	play_v.add_theme_constant_override("separation", 2)
	play_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_play.add_child(play_v)

	var lbl_play_main := Label.new()
	lbl_play_main.name = "PlayMain"
	lbl_play_main.text = "▶  开始闯关 · LEVEL 1"
	lbl_play_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_play_main.add_theme_font_size_override("font_size", 24)
	lbl_play_main.add_theme_color_override("font_color", Color.WHITE)
	lbl_play_main.add_theme_color_override("font_outline_color", Color(0.02, 0.32, 0.16))
	lbl_play_main.add_theme_constant_override("outline_size", 5)
	if p_font:
		lbl_play_main.add_theme_font_override("font", p_font)
	play_v.add_child(lbl_play_main)

	lbl_play_sub = _mk_lbl("迷你小机器人 · 84 块体素", 13, Color(0.90, 1.0, 0.94), p_font)
	lbl_play_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_v.add_child(lbl_play_sub)
	root_v.add_child(btn_play)

	# --- 5. BOTTOM 4-TAB COMMERCIAL NAVIGATION BAR ---
	var nav_card := PanelContainer.new()
	nav_card.custom_minimum_size = Vector2(0, 72)
	nav_card.add_theme_stylebox_override("panel", _mk_box(Color.WHITE, 22, 12, Color(0.84, 0.89, 0.95), 1))
	root_v.add_child(nav_card)

	var nav_h := HBoxContainer.new()
	nav_h.add_theme_constant_override("separation", 8)
	nav_card.add_child(nav_h)

	nav_h.add_child(_mk_nav_tab("icon_crown", "60关地图", p_font, func(): open_levels_pressed.emit()))
	nav_h.add_child(_mk_nav_tab("icon_island", "浮空岛", p_font, func(): open_island_pressed.emit()))
	nav_h.add_child(_mk_nav_tab("icon_super_cannon", "每日任务", p_font, func(): open_tasks_pressed.emit()))
	nav_h.add_child(_mk_nav_tab("icon_shop", "商店礼包", p_font, func(): open_shop_pressed.emit()))


func _mk_nav_tab(icon_k: String, label_txt: String, p_font: Font, cb: Callable) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 58)
	_style_white_btn(b, 14)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	var ic := _mk_icon(icon_k, Vector2(26, 26))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var l := _mk_lbl(label_txt, 12, Color(0.18, 0.25, 0.36), p_font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	b.pressed.connect(func():
		audio.play_ui_click()
		cb.call()
	)
	return b


func refresh() -> void:
	services.refresh_lives()
	lbl_coins.text = ("%.1fK" % (float(services.coins) / 1000.0)) if services.coins >= 1000 else ("%d" % services.coins)
	if services.is_infinite_stamina():
		@warning_ignore("integer_division")
		lbl_lives.text = "∞ %dm" % maxi(1, services.get_infinite_stamina_remaining_sec() / 60)
	else:
		lbl_lives.text = "%d/%d" % [services.lives, services.get_max_lives()]
	lbl_streak.text = "%d连胜" % services.win_streak

	var lv: int = services.current_level
	var row: Dictionary = repo.get_manifest_row(lv)
	var mname: String = String(row.get("model_name_zh", "积木模型"))
	var vox_n: String = String(row.get("voxel_count_N", "84"))
	var tier: String = String(row.get("difficulty_tier", "Normal"))
	var play_main: Label = btn_play.find_child("PlayMain", true, false)
	if play_main:
		play_main.text = "▶  开始闯关 · LEVEL %d" % lv
	var tier_tag: String = ""
	if tier == "Hard":
		tier_tag = " · 🔥困难关"
	elif tier == "Super Hard":
		tier_tag = " · 👑超难里程碑"
	elif tier == "Celebration":
		tier_tag = " · ★庆典爽关"
	lbl_play_sub.text = "%s · %s 块体素%s" % [mname, vox_n, tier_tag]

	var ch_i: int = 0 if lv <= 30 else 1
	services.island_chapter = ch_i
	var ch_info: Dictionary = FusePalette.ISLAND_CHAPTERS[ch_i]
	var painted: int = services.island_modules_painted[ch_i]
	lbl_chapter_pill.text = "%s · %s" % [String(ch_info["subtitle"]), String(ch_info["name"])]
	lbl_island_prog.text = "已点亮 3D 地标 %d/5  ·  当前涂装能量 %d / 500" % [painted, services.island_energy]

	_ensure_3d_island(ch_i, painted)


func _ensure_3d_island(ch_i: int, painted: int) -> void:
	if loaded_chapter_idx != ch_i:
		loaded_chapter_idx = ch_i
		for c in island_pivot.get_children():
			c.queue_free()
		var glb_path: String = String(FusePalette.ISLAND_CHAPTERS[ch_i]["glb_path"])
		if ResourceLoader.exists(glb_path):
			var ps: PackedScene = load(glb_path)
			if ps:
				island_pivot.add_child(ps.instantiate())

	var found: Dictionary = {}
	_collect_meshes(island_pivot, found)
	for i in range(5):
		var key: String = "Module_%d" % i
		if found.has(key):
			var mi: MeshInstance3D = found[key]
			if i < painted:
				var pm := StandardMaterial3D.new()
				pm.vertex_color_use_as_albedo = true
				pm.roughness = 0.24
				mi.material_override = pm
			else:
				mi.material_override = gray_mat
	if found.has("IslandBase"):
		var bm := StandardMaterial3D.new()
		bm.vertex_color_use_as_albedo = true
		bm.roughness = 0.36
		(found["IslandBase"] as MeshInstance3D).material_override = bm


func _collect_meshes(n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D:
		out[n.name] = n
	for c in n.get_children():
		_collect_meshes(c, out)


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	if island_pivot:
		island_pivot.rotation.y += delta * 0.42
		island_pivot.position.y = sin(clock * 1.8) * 0.12


func _mk_icon(k: String, sz: Vector2) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = sz
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icons.has(k):
		tex_rect.texture = icons[k]
	return tex_rect


func _mk_lbl(txt: String, fsz: int, col: Color, p_font: Font) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fsz)
	l.add_theme_color_override("font_color", col)
	if p_font:
		l.add_theme_font_override("font", p_font)
	return l


func _mk_box(bg: Color, r: int, sh: int, bc: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(r)
	if bw > 0:
		sb.border_color = bc
		sb.set_border_width_all(bw)
	if sh > 0:
		sb.shadow_color = Color(0.06, 0.09, 0.16, 0.09)
		sb.shadow_size = sh
		sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb


func _style_white_btn(btn: Button, r: int) -> void:
	var sb := _mk_box(Color.WHITE, r, 6, Color(0.86, 0.90, 0.95), 1)
	btn.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat; hv.bg_color = Color(0.96, 0.98, 1.0)
	btn.add_theme_stylebox_override("hover", hv)
	var pr := sb.duplicate() as StyleBoxFlat; pr.bg_color = Color(0.91, 0.94, 0.98)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _style_color_btn(btn: Button, bg: Color, border_dk: Color, fg: Color, r: int, fsz: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(r)
	sb.border_width_top = 3; sb.border_width_left = 2; sb.border_width_right = 2; sb.border_width_bottom = 6
	sb.border_color = border_dk
	sb.shadow_color = Color(0.06, 0.14, 0.24, 0.18)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 5)
	sb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat; hv.bg_color = bg.lightened(0.06)
	btn.add_theme_stylebox_override("hover", hv)
	var pr := sb.duplicate() as StyleBoxFlat; pr.bg_color = bg.darkened(0.06)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_font_size_override("font_size", fsz)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
