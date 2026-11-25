extends Node3D

## V1.0 Store-Ready Master Controller & Version B 9:16 Minimalist Arcade HUD
## Strictly implements RD-SPEC-01, RD-SPEC-02, RD-SPEC-03 & levels_v1_60_config.csv:
##  - Exact 9:16 5-Zone Proportions: 10% Top / 50% 3D Stage / 11% 5-Slot / 20% 5x3 Queue / 9% Safe Bottom
##  - 18 Vector SVG Icons (zero emoji blur), 60 JSON Levels + Post-60 Daily Master Pool
##  - Full First-30-Levels FTUE (Lv.1 finger-guided instant Fuse, Lv.2 360° swipe, Lv.3 Island Paint, etc.)
##  - 6:1 Fair Economy, Lives (5 hearts, 25min regen, free restart <= 3 shots), Daily Tasks
##  - Hybrid Monetization 2.0 (7 IAP SKUs, 6 RV Placements, Smart Lv.31+ Interstitials)
##  - Store Compliance (Privacy Policy, ATT, Restore Purchases, Delete Account, 5-Star Gate, 8 BI Events)

const FONT_PATH: String = "res://assets/fonts/studio_cjk.ttf"
const ICON_DIR: String = "res://assets/fuse/icons/"

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var camera: Camera3D = $StageCamera
@onready var ui_layer: CanvasLayer = $UILayer

var audio: ArcadeAudio
var services: StoreServices
var repo: LevelRepository
var stage: FuseStage
var island_view: IslandPaintView
var home_lobby: HomeLobbyView
var studio_font: Font
var icons: Dictionary = {}

# Per-level session state
var attempt_count: int = 1
var current_level_json: Dictionary = {}
var rv_magnet_used_this_level: bool = false
var extra_slot_confirm_lock: bool = false # Anti-double-tap guard (RD-SPEC-03 5.1 #5!)
var pending_pre_super: bool = false
var pending_pre_double_core: bool = false
var pending_win_summary: Dictionary = {}
var win_double_claimed: bool = false

# UI Nodes
var root_ui: Control
var fx_overlay: Control
var orbit_zone: Control
var callout_root: Control
var ftue_hand_rect: TextureRect
var ftue_swipe_banner: PanelContainer

var lbl_coins: Label
var lbl_lives: Label
var lbl_level: Label
var difficulty_badge: PanelContainer
var lbl_diff_badge: Label
var island_segs: Array[Panel] = []
var btn_island_icon: Button

var slot_frames: Array[PanelContainer] = []
var slot_tiles: Array[Control] = []
var slot_ammo_labels: Array[Label] = []
var slot_tier_badges: Array[Label] = []
var slot_recoil: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var slot_fuse_pop: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

var queue_col_rails: Array[PanelContainer] = []
var queue_col_buttons: Array[Button] = []
var queue_tiles: Array = []
var queue_labels: Array = []
var queue_extra_badges: Array[Label] = []

var btn_magnet: Button
var lbl_magnet_cost: Label
var btn_shockwave: Button
var lbl_shockwave_cost: Label
var btn_extra_slot: Button
var lbl_extra_cost: Label

# Modals
var settings_modal: PanelContainer
var level_scroll_grid: GridContainer
var daily_tasks_box: VBoxContainer
var telemetry_label: Label
var btn_sound_tog: Button
var btn_bgm_tog: Button
var btn_sym_tog: Button

var shop_modal: PanelContainer
var shop_items_box: VBoxContainer
var compliance_modal: PanelContainer
var extra_slot_confirm_modal: PanelContainer
var win_modal: PanelContainer
var lbl_win_title: Label
var lbl_win_desc: Label
var btn_win_double: Button
var btn_win_island: Button
var btn_win_share: Button
var btn_pre_super_tog: Button
var btn_pre_core_tog: Button

var rescue_modal: PanelContainer
var lbl_rescue_desc: Label
var btn_rescue_coins: Button
var btn_rescue_rv: Button

var rate_modal: PanelContainer
var ad_overlay: PanelContainer
var lbl_ad_msg: Label

# Active 2D Juice VFX
var flying_cannons: Array[Dictionary] = [] # 0.18s Quadratic Bezier fly-in!
var laser_streaks: Array[Dictionary] = []
var electric_arcs: Array[Dictionary] = []
var energy_orbs: Array[Dictionary] = []
var toast_active: int = 0
var ui_clock: float = 0.0
var life_tick_accum: float = 0.0


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		studio_font = load(FONT_PATH)
	_preload_svg_icons()
	_setup_version_b_lighting()

	services = StoreServices.new()
	services.name = "StoreServices"
	add_child(services)

	audio = ArcadeAudio.new()
	audio.name = "ArcadeAudio"
	add_child(audio)
	audio.sound_enabled = services.sound_enabled
	audio.bgm_enabled = services.bgm_enabled

	repo = LevelRepository.new()
	repo.load_manifest()

	stage = FuseStage.new()
	stage.name = "FuseStage"
	add_child(stage)
	stage.setup(camera, audio)
	stage.set_symbol_mode(services.symbol_mode)

	_build_version_b_hud()
	_connect_signals()

	# Load current level in background AND present polished Home Lobby on launch!
	_start_level(services.current_level, false)
	_show_home_lobby()


func _preload_svg_icons() -> void:
	var names: Array[String] = [
		"icon_coin", "icon_settings", "icon_island", "icon_magnet",
		"icon_shockwave", "icon_plus_slot", "icon_heart", "icon_heart_empty",
		"icon_video", "icon_super_cannon", "icon_double_core", "icon_crown",
		"icon_streak", "icon_hand", "icon_sound_on", "icon_sound_off",
		"icon_blind", "icon_shop",
	]
	for n in names:
		var p: String = ICON_DIR + n + ".svg"
		if ResourceLoader.exists(p):
			icons[n] = load(p)


func _setup_version_b_lighting() -> void:
	# RD-SPEC-03 2.1: #E8EEF5 -> #F5F8FC sky + 1 DirectionalLight (1024px soft shadow, 30m) + 0.55 cool ambient!
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky_gradient.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.58, 0.95)
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.08
	world_env.environment = env

	key_light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key_light.light_color = Color(1.0, 0.99, 0.96)
	key_light.light_energy = 1.65
	key_light.shadow_enabled = true
	key_light.shadow_opacity = 0.48
	key_light.shadow_blur = 1.6
	key_light.shadow_bias = 0.025
	key_light.shadow_normal_bias = 1.0
	key_light.directional_shadow_max_distance = 30.0


# ==============================================================================
# BUILD VERSION B 9:16 PIXEL-ACCURATE 5-ZONE HUD (RD-SPEC-03 Section 1.1)
# ==============================================================================
func _build_version_b_hud() -> void:
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if studio_font:
		var t := Theme.new()
		t.default_font = studio_font
		root_ui.theme = t
	ui_layer.add_child(root_ui)

	# Upper-Center 50% 3D Orbit Zone (y = 10%..60%)
	orbit_zone = Control.new()
	orbit_zone.anchor_left = 0.0
	orbit_zone.anchor_right = 1.0
	orbit_zone.anchor_top = 0.10
	orbit_zone.anchor_bottom = 0.60
	orbit_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	orbit_zone.gui_input.connect(_on_orbit_input)
	root_ui.add_child(orbit_zone)

	var main_wrap := CenterContainer.new()
	main_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(main_wrap)

	var shell := Control.new()
	shell.custom_minimum_size = Vector2(540, 960)
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_wrap.add_child(shell)

	# --- ZONE 1: TOP HUD (10% = 0..96px) ---
	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 16
	top_bar.offset_right = -16
	top_bar.offset_top = 12
	top_bar.offset_bottom = 86
	top_bar.add_theme_constant_override("separation", 8)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(top_bar)

	# Top-Left Stack: Pure White Coin Pill + Compact Lives Heart Pill
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 4)
	left_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(left_col)

	var coin_btn := Button.new()
	coin_btn.custom_minimum_size = Vector2(108, 38)
	_style_white_card_btn(coin_btn, 19)
	coin_btn.pressed.connect(_open_shop_modal)
	left_col.add_child(coin_btn)

	var ch_box := HBoxContainer.new()
	ch_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ch_box.add_theme_constant_override("separation", 5)
	ch_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_btn.add_child(ch_box)
	ch_box.add_child(_make_svg_rect("icon_coin", Vector2(22, 22)))
	lbl_coins = Label.new()
	lbl_coins.add_theme_font_size_override("font_size", 16)
	lbl_coins.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	ch_box.add_child(lbl_coins)

	var life_pill := PanelContainer.new()
	life_pill.custom_minimum_size = Vector2(88, 24)
	life_pill.add_theme_stylebox_override("panel", _make_card_box(Color(1, 1, 1, 0.90), 12, 4, Color(0.86, 0.90, 0.95), 1))
	left_col.add_child(life_pill)
	var lh_box := HBoxContainer.new()
	lh_box.alignment = BoxContainer.ALIGNMENT_CENTER
	lh_box.add_theme_constant_override("separation", 4)
	life_pill.add_child(lh_box)
	lh_box.add_child(_make_svg_rect("icon_heart", Vector2(14, 14)))
	lbl_lives = Label.new()
	lbl_lives.add_theme_font_size_override("font_size", 11)
	lbl_lives.add_theme_color_override("font_color", Color(0.24, 0.30, 0.42))
	lh_box.add_child(lbl_lives)

	# Top-Center: Bold Navy LEVEL XX + 5-Segment Island Progress Bar + Vector Island Icon!
	var center_col := VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 4)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(center_col)

	var lv_row := HBoxContainer.new()
	lv_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lv_row.add_theme_constant_override("separation", 6)
	center_col.add_child(lv_row)

	lbl_level = Label.new()
	lbl_level.text = "LEVEL 1"
	lbl_level.add_theme_font_size_override("font_size", 26)
	lbl_level.add_theme_color_override("font_color", Color.WHITE)
	lbl_level.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.28))
	lbl_level.add_theme_constant_override("outline_size", 6)
	lv_row.add_child(lbl_level)

	difficulty_badge = PanelContainer.new()
	difficulty_badge.visible = false
	lv_row.add_child(difficulty_badge)
	lbl_diff_badge = Label.new()
	lbl_diff_badge.add_theme_font_size_override("font_size", 10)
	lbl_diff_badge.add_theme_color_override("font_color", Color.WHITE)
	difficulty_badge.add_child(lbl_diff_badge)

	var prog_row := HBoxContainer.new()
	prog_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prog_row.add_theme_constant_override("separation", 5)
	center_col.add_child(prog_row)

	for i in range(5):
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(21, 9)
		seg.add_theme_stylebox_override("panel", _make_solid_pill(Color(0.796, 0.835, 0.882), 5))
		prog_row.add_child(seg)
		island_segs.append(seg)

	btn_island_icon = Button.new()
	btn_island_icon.custom_minimum_size = Vector2(30, 28)
	_style_white_card_btn(btn_island_icon, 10)
	var isl_ic := _make_svg_rect("icon_island", Vector2(22, 22))
	isl_ic.set_anchors_preset(Control.PRESET_CENTER)
	isl_ic.offset_left = -11; isl_ic.offset_top = -11; isl_ic.offset_right = 11; isl_ic.offset_bottom = 11
	btn_island_icon.add_child(isl_ic)
	btn_island_icon.pressed.connect(func(): _open_island_view(false))
	prog_row.add_child(btn_island_icon)

	# Top-Right: Home Button + Pure White Rounded Square Settings Button (SVG Gear)
	var right_h := HBoxContainer.new()
	right_h.add_theme_constant_override("separation", 6)
	right_h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_bar.add_child(right_h)

	var btn_home := Button.new()
	btn_home.custom_minimum_size = Vector2(42, 46)
	btn_home.text = "⌂"
	_style_white_card_btn(btn_home, 14)
	btn_home.add_theme_font_size_override("font_size", 22)
	btn_home.add_theme_color_override("font_color", Color(0.22, 0.30, 0.42))
	btn_home.pressed.connect(func():
		audio.play_ui_click()
		_show_home_lobby()
	)
	right_h.add_child(btn_home)

	var btn_settings := Button.new()
	btn_settings.custom_minimum_size = Vector2(46, 46)
	_style_white_card_btn(btn_settings, 14)
	var gear_ic := _make_svg_rect("icon_settings", Vector2(24, 24))
	gear_ic.set_anchors_preset(Control.PRESET_CENTER)
	gear_ic.offset_left = -12; gear_ic.offset_top = -12; gear_ic.offset_right = 12; gear_ic.offset_bottom = 12
	btn_settings.add_child(gear_ic)
	btn_settings.pressed.connect(_open_settings_modal)
	right_h.add_child(btn_settings)

	# FTUE Lv.2 Translucent 360° Swipe Arrow Banner (hidden unless Lv.2 FTUE!)
	ftue_swipe_banner = PanelContainer.new()
	ftue_swipe_banner.visible = false
	ftue_swipe_banner.anchor_left = 0.5
	ftue_swipe_banner.anchor_right = 0.5
	ftue_swipe_banner.offset_left = -135
	ftue_swipe_banner.offset_right = 135
	ftue_swipe_banner.offset_top = 486
	ftue_swipe_banner.offset_bottom = 524
	ftue_swipe_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ftue_swipe_banner.add_theme_stylebox_override("panel", _make_card_box(Color(0.118, 0.161, 0.231, 0.72), 18, 6, Color.WHITE, 1))
	shell.add_child(ftue_swipe_banner)
	var sw_lbl := Label.new()
	sw_lbl.text = "←  单指滑动 360° 旋转查看背面  →"
	sw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sw_lbl.add_theme_font_size_override("font_size", 13)
	sw_lbl.add_theme_color_override("font_color", Color.WHITE)
	ftue_swipe_banner.add_child(sw_lbl)

	# --- ZONE 3: MIDDLE 5-SLOT DOCK (11% = y=566..660) ---
	var slots_center := CenterContainer.new()
	slots_center.anchor_left = 0.0
	slots_center.anchor_right = 1.0
	slots_center.offset_top = 564
	slots_center.offset_bottom = 656
	slots_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(slots_center)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 10)
	slots_center.add_child(slots_hbox)

	for i in range(FuseStage.MAX_SLOTS):
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(82, 82)
		frame.visible = (i < FuseStage.BASE_SLOTS)
		# Cube Smash Deep Navy Recessed Slot (high contrast so jewel cannons pop!)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.024, 0.095, 0.285, 0.90)
		sb.border_color = Color(0.180, 0.455, 0.920, 0.85)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(16)
		sb.set_content_margin_all(4)
		frame.add_theme_stylebox_override("panel", sb)
		slots_hbox.add_child(frame)
		slot_frames.append(frame)

		var holder := Control.new()
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.pivot_offset = Vector2(37, 37)
		holder.visible = false
		frame.add_child(holder)
		slot_tiles.append(holder)

		var ammo_l := _make_outlined_ammo_label(24)
		holder.add_child(ammo_l)
		slot_ammo_labels.append(ammo_l)

		var tier_l := Label.new()
		tier_l.anchor_right = 1.0
		tier_l.offset_top = -5
		tier_l.offset_right = -4
		tier_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tier_l.add_theme_font_size_override("font_size", 13)
		tier_l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.35))
		tier_l.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.24))
		tier_l.add_theme_constant_override("outline_size", 4)
		tier_l.visible = false
		holder.add_child(tier_l)
		slot_tier_badges.append(tier_l)

	# --- ZONE 4: LOWER 5×3 QUEUE GRID (20% = y=664..858) ---
	var queue_center := CenterContainer.new()
	queue_center.anchor_left = 0.0
	queue_center.anchor_right = 1.0
	queue_center.offset_top = 664
	queue_center.offset_bottom = 858
	shell.add_child(queue_center)

	var queue_card := PanelContainer.new()
	queue_card.custom_minimum_size = Vector2(466, 192)
	queue_card.add_theme_stylebox_override("panel", _make_card_box(Color(0.032, 0.118, 0.340, 0.92), 20, 14, Color(0.18, 0.46, 0.92, 0.80), 2))
	queue_center.add_child(queue_card)

	var queue_hbox := HBoxContainer.new()
	queue_hbox.add_theme_constant_override("separation", 8)
	queue_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_card.add_child(queue_hbox)

	for c in range(5):
		var rail := PanelContainer.new()
		rail.custom_minimum_size = Vector2(82, 174)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.018, 0.072, 0.225, 0.88)
		rsb.set_corner_radius_all(13)
		rsb.set_content_margin_all(4)
		rail.add_theme_stylebox_override("panel", rsb)
		queue_hbox.add_child(rail)
		queue_col_rails.append(rail)

		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var cap_c: int = c
		btn.pressed.connect(func(): _on_column_tapped(cap_c))
		rail.add_child(btn)
		queue_col_buttons.append(btn)

		var cv := VBoxContainer.new()
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.add_theme_constant_override("separation", 4)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.add_child(cv)

		var rt: Array = []
		var rl: Array = []
		for r in range(3):
			var tile := PanelContainer.new()
			tile.custom_minimum_size = Vector2(74, 52)
			tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.visible = false
			cv.add_child(tile)
			rt.append(tile)

			var ql := _make_outlined_ammo_label(22 if r == 0 else 19)
			ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(ql)
			rl.append(ql)
		queue_tiles.append(rt)
		queue_labels.append(rl)

		var ex := Label.new()
		ex.anchor_left = 0.0; ex.anchor_right = 1.0
		ex.anchor_top = 1.0; ex.anchor_bottom = 1.0
		ex.offset_top = -17; ex.offset_bottom = -2; ex.offset_right = -6
		ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ex.add_theme_font_size_override("font_size", 11)
		ex.add_theme_color_override("font_color", Color.WHITE)
		ex.add_theme_color_override("font_outline_color", Color(0.08, 0.13, 0.22, 0.92))
		ex.add_theme_constant_override("outline_size", 3)
		ex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.add_child(ex)
		queue_extra_badges.append(ex)

	# --- ZONE 5: BOTTOM CENTERED SAFE BOOSTER BAR (9% = y=878..950, >= 20px vertical safe gap!) ---
	var bot_center := CenterContainer.new()
	bot_center.anchor_left = 0.0
	bot_center.anchor_right = 1.0
	bot_center.offset_top = 876
	bot_center.offset_bottom = 948
	shell.add_child(bot_center)

	var bot_hbox := HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 20)
	bot_center.add_child(bot_hbox)

	var m_pair := _make_svg_booster_btn("icon_magnet", "%d" % StoreServices.PRICE_MAGNET)
	btn_magnet = m_pair[0]
	lbl_magnet_cost = m_pair[1]
	btn_magnet.pressed.connect(_on_magnet_clicked)
	bot_hbox.add_child(btn_magnet)

	var s_pair := _make_svg_booster_btn("icon_shockwave", "%d" % StoreServices.PRICE_SHOCKWAVE)
	btn_shockwave = s_pair[0]
	lbl_shockwave_cost = s_pair[1]
	btn_shockwave.pressed.connect(_on_shockwave_clicked)
	bot_hbox.add_child(btn_shockwave)

	var e_pair := _make_svg_booster_btn("icon_plus_slot", "%d" % StoreServices.PRICE_EXTRA_SLOT)
	btn_extra_slot = e_pair[0]
	lbl_extra_cost = e_pair[1]
	btn_extra_slot.pressed.connect(_on_extra_slot_clicked)
	bot_hbox.add_child(btn_extra_slot)

	# --- OVERLAYS: 2D JUICE FX, FTUE FINGER, CALLOUTS, MODALS, 3D ISLAND VIEW ---
	fx_overlay = Control.new()
	fx_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_overlay.z_index = 15
	fx_overlay.draw.connect(_draw_fx_overlay)
	root_ui.add_child(fx_overlay)

	ftue_hand_rect = _make_svg_rect("icon_hand", Vector2(54, 54))
	ftue_hand_rect.visible = false
	ftue_hand_rect.z_index = 22
	ftue_hand_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(ftue_hand_rect)

	callout_root = Control.new()
	callout_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	callout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout_root.z_index = 25
	root_ui.add_child(callout_root)

	_build_all_modals()

	island_view = IslandPaintView.new()
	island_view.setup(audio, services, studio_font)
	island_view.closed.connect(_on_island_closed)
	island_view.module_painted.connect(func(_c, _m, _r, _done):
		_refresh_top_hud()
		if home_lobby and home_lobby.visible:
			home_lobby.refresh()
	)
	root_ui.add_child(island_view)

	home_lobby = HomeLobbyView.new()
	home_lobby.setup(audio, services, repo, icons, studio_font)
	home_lobby.play_pressed.connect(func():
		home_lobby.visible = false
		stage.stage_active = true
		audio.play_chapter_bgm(services.island_chapter)
	)
	home_lobby.open_island_pressed.connect(func(): _open_island_view(false))
	home_lobby.open_levels_pressed.connect(_open_settings_modal)
	home_lobby.open_tasks_pressed.connect(_open_settings_modal)
	home_lobby.open_shop_pressed.connect(_open_shop_modal)
	home_lobby.open_settings_pressed.connect(_open_settings_modal)
	root_ui.add_child(home_lobby)


func _show_home_lobby() -> void:
	stage.stage_active = false
	home_lobby.refresh()
	home_lobby.visible = true


func _make_svg_rect(icon_key: String, sz: Vector2) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = sz
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icons.has(icon_key):
		tex_rect.texture = icons[icon_key]
	return tex_rect


func _make_svg_booster_btn(icon_key: String, cost_str: String) -> Array:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(78, 64)
	_style_white_card_btn(btn, 16)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	var ic := _make_svg_rect(icon_key, Vector2(28, 28))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ic)
	var cl := Label.new()
	cl.text = cost_str
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_theme_font_size_override("font_size", 11)
	cl.add_theme_color_override("font_color", Color(0.18, 0.25, 0.36))
	vb.add_child(cl)
	return [btn, cl]


func _build_all_modals() -> void:
	# 1. Settings, Daily Tasks, 60-Level Selector & Compliance Modal
	settings_modal = _make_modal(Vector2(476, 650))
	root_ui.add_child(settings_modal)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	settings_modal.add_child(sv)

	var st_head := HBoxContainer.new()
	sv.add_child(st_head)
	var st_lbl := Label.new()
	st_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st_lbl.text = "设置 · 60关总览 · 每日任务"
	st_lbl.add_theme_font_size_override("font_size", 18)
	st_lbl.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	st_head.add_child(st_lbl)
	var btn_sx := Button.new()
	btn_sx.text = "✕"
	btn_sx.custom_minimum_size = Vector2(36, 36)
	_style_pill_btn(btn_sx, Color(0.92, 0.94, 0.97), Color(0.18, 0.24, 0.36), 10, 16)
	btn_sx.pressed.connect(func(): settings_modal.visible = false)
	st_head.add_child(btn_sx)

	var tog_row := HBoxContainer.new()
	tog_row.add_theme_constant_override("separation", 6)
	sv.add_child(tog_row)
	btn_sound_tog = Button.new()
	btn_sound_tog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sound_tog.custom_minimum_size = Vector2(0, 36)
	_style_pill_btn(btn_sound_tog, Color(0.93, 0.96, 1.0), Color(0.11, 0.22, 0.42), 10, 12)
	btn_sound_tog.pressed.connect(func():
		services.sound_enabled = not services.sound_enabled
		audio.sound_enabled = services.sound_enabled
		audio.play_ui_click()
		services.save_state()
		_refresh_settings_modal()
	)
	tog_row.add_child(btn_sound_tog)

	btn_bgm_tog = Button.new()
	btn_bgm_tog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_bgm_tog.custom_minimum_size = Vector2(0, 36)
	_style_pill_btn(btn_bgm_tog, Color(0.93, 0.96, 1.0), Color(0.11, 0.22, 0.42), 10, 12)
	btn_bgm_tog.pressed.connect(func():
		services.bgm_enabled = not services.bgm_enabled
		audio.set_bgm_enabled(services.bgm_enabled)
		audio.play_ui_click()
		services.save_state()
		_refresh_settings_modal()
	)
	tog_row.add_child(btn_bgm_tog)

	btn_sym_tog = Button.new()
	btn_sym_tog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sym_tog.custom_minimum_size = Vector2(0, 36)
	_style_pill_btn(btn_sym_tog, Color(0.93, 0.96, 1.0), Color(0.11, 0.22, 0.42), 10, 12)
	btn_sym_tog.pressed.connect(func():
		services.symbol_mode = not services.symbol_mode
		stage.set_symbol_mode(services.symbol_mode)
		audio.play_ui_click()
		services.save_state()
		_refresh_settings_modal()
		_refresh_dock_and_queue_ui()
	)
	tog_row.add_child(btn_sym_tog)

	# Daily Tasks (4 × 50 = 200 Coins/Day!)
	var dt_title := Label.new()
	dt_title.text = "每日任务（4×50 = 200 金币）"
	dt_title.add_theme_font_size_override("font_size", 13)
	dt_title.add_theme_color_override("font_color", Color(0.32, 0.40, 0.52))
	sv.add_child(dt_title)
	daily_tasks_box = VBoxContainer.new()
	daily_tasks_box.add_theme_constant_override("separation", 4)
	sv.add_child(daily_tasks_box)

	# 60-Level Scrollable Chapter Selector (Ch.1 Lv.1-30 + Ch.2 Lv.31-60!)
	var lv_title := Label.new()
	lv_title.text = "V1.0 全 60 关直达（红=Hard / 紫=Super Hard / 金=庆典关）"
	lv_title.add_theme_font_size_override("font_size", 13)
	lv_title.add_theme_color_override("font_color", Color(0.32, 0.40, 0.52))
	sv.add_child(lv_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 196)
	sv.add_child(scroll)
	level_scroll_grid = GridContainer.new()
	level_scroll_grid.columns = 5
	level_scroll_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_scroll_grid.add_theme_constant_override("h_separation", 6)
	level_scroll_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(level_scroll_grid)

	for lv in range(1, 61):
		var row: Dictionary = repo.get_manifest_row(lv)
		var tier: String = String(row.get("difficulty_tier", "Normal"))
		var lb := Button.new()
		lb.custom_minimum_size = Vector2(74, 34)
		lb.text = "Lv.%d" % lv
		var bg_c := Color(0.93, 0.95, 0.98)
		var fg_c := Color(0.14, 0.22, 0.36)
		if tier == "Hard":
			bg_c = Color(1.0, 0.302, 0.310); fg_c = Color.WHITE
		elif tier == "Super Hard":
			bg_c = Color(0.545, 0.361, 0.965); fg_c = Color.WHITE
		elif tier == "Celebration":
			bg_c = Color(1.0, 0.816, 0.078); fg_c = Color(0.42, 0.24, 0.0)
		_style_pill_btn(lb, bg_c, fg_c, 9, 12)
		var cap_lv: int = lv
		lb.pressed.connect(func():
			audio.play_ui_click()
			settings_modal.visible = false
			_start_level(cap_lv, false)
		)
		level_scroll_grid.add_child(lb)

	# Action Row: Restart, Shop, Compliance & BI Telemetry
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 6)
	sv.add_child(act_row)

	var btn_re := Button.new()
	btn_re.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_re.custom_minimum_size = Vector2(0, 38)
	btn_re.text = "↻ 重开本关"
	_style_pill_btn(btn_re, Color(1.0, 0.94, 0.94), Color(0.84, 0.20, 0.20), 10, 13)
	btn_re.pressed.connect(func():
		audio.play_ui_click()
		settings_modal.visible = false
		_restart_current_level()
	)
	act_row.add_child(btn_re)

	var btn_shop_open := Button.new()
	btn_shop_open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_shop_open.custom_minimum_size = Vector2(0, 38)
	btn_shop_open.text = "🛍 商店 / 通行证"
	_style_pill_btn(btn_shop_open, Color(0.114, 0.388, 0.929), Color.WHITE, 10, 13)
	btn_shop_open.pressed.connect(func():
		settings_modal.visible = false
		_open_shop_modal()
	)
	act_row.add_child(btn_shop_open)

	var btn_comp := Button.new()
	btn_comp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_comp.custom_minimum_size = Vector2(0, 38)
	btn_comp.text = "隐私与合规"
	_style_pill_btn(btn_comp, Color(0.92, 0.94, 0.97), Color(0.24, 0.32, 0.44), 10, 13)
	btn_comp.pressed.connect(func():
		audio.play_ui_click()
		settings_modal.visible = false
		compliance_modal.visible = true
	)
	act_row.add_child(btn_comp)

	telemetry_label = Label.new()
	telemetry_label.add_theme_font_size_override("font_size", 10)
	telemetry_label.add_theme_color_override("font_color", Color(0.45, 0.52, 0.64))
	sv.add_child(telemetry_label)

	# 2. IAP Shopfront Modal (All 7 Exact SKUs + Restore Purchases!)
	shop_modal = _make_modal(Vector2(470, 620))
	root_ui.add_child(shop_modal)
	var sh_v := VBoxContainer.new()
	sh_v.add_theme_constant_override("separation", 8)
	shop_modal.add_child(sh_v)
	var sh_h := HBoxContainer.new()
	sh_v.add_child(sh_h)
	var sh_t := Label.new()
	sh_t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh_t.text = "🛍 商店与赛季通行证（混合变现 2.0）"
	sh_t.add_theme_font_size_override("font_size", 18)
	sh_t.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	sh_h.add_child(sh_t)
	var btn_sh_x := Button.new()
	btn_sh_x.text = "✕"
	btn_sh_x.custom_minimum_size = Vector2(36, 36)
	_style_pill_btn(btn_sh_x, Color(0.92, 0.94, 0.97), Color(0.18, 0.24, 0.36), 10, 16)
	btn_sh_x.pressed.connect(func(): shop_modal.visible = false)
	sh_h.add_child(btn_sh_x)

	var sh_scroll := ScrollContainer.new()
	sh_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sh_v.add_child(sh_scroll)
	shop_items_box = VBoxContainer.new()
	shop_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_items_box.add_theme_constant_override("separation", 8)
	sh_scroll.add_child(shop_items_box)

	var btn_restore := Button.new()
	btn_restore.custom_minimum_size = Vector2(0, 40)
	btn_restore.text = "恢复购买（Restore Purchases）"
	_style_pill_btn(btn_restore, Color(0.93, 0.95, 0.98), Color(0.24, 0.32, 0.44), 12, 13)
	btn_restore.pressed.connect(func():
		audio.play_ui_click()
		_show_toast(services.restore_purchases(), Color(0.114, 0.388, 0.929))
	)
	sh_v.add_child(btn_restore)

	# 3. Store Compliance Modal (Privacy Policy, ATT, Delete Account, Age 4+)
	compliance_modal = _make_modal(Vector2(440, 390))
	root_ui.add_child(compliance_modal)
	var cp_v := VBoxContainer.new()
	cp_v.add_theme_constant_override("separation", 10)
	compliance_modal.add_child(cp_v)
	var cp_t := Label.new()
	cp_t.text = "商店合规与隐私中心（年龄分级 4+）"
	cp_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cp_t.add_theme_font_size_override("font_size", 18)
	cp_t.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	cp_v.add_child(cp_t)
	var cp_txt := Label.new()
	cp_txt.text = "• 离线畅玩：全部 60 关支持断网离线游玩与本地加密存档。\n• 隐私政策与 ATT：本游戏不收集个人身份信息；仅在用户授权 ATT 后用于广告归因优化。\n• 适龄提示：4+ 全年龄段，零赌博、零随机抽卡，公平 6:1 金币经济。"
	cp_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cp_txt.add_theme_font_size_override("font_size", 13)
	cp_txt.add_theme_color_override("font_color", Color(0.30, 0.38, 0.50))
	cp_v.add_child(cp_txt)

	var btn_att := Button.new()
	btn_att.custom_minimum_size = Vector2(0, 42)
	btn_att.text = "管理广告追踪授权（ATT 偏好）"
	_style_pill_btn(btn_att, Color(0.93, 0.96, 1.0), Color(0.11, 0.26, 0.54), 12, 13)
	btn_att.pressed.connect(func():
		services.att_prompted = true
		services.save_state()
		_show_toast("已记录 ATT 隐私偏好设置", Color(0.078, 0.722, 0.400))
	)
	cp_v.add_child(btn_att)

	var btn_del := Button.new()
	btn_del.custom_minimum_size = Vector2(0, 42)
	btn_del.text = "删除账号与清空全部本地存档（不可逆）"
	_style_pill_btn(btn_del, Color(1.0, 0.92, 0.92), Color(0.84, 0.18, 0.18), 12, 13)
	btn_del.pressed.connect(func():
		services.delete_all_account_data()
		compliance_modal.visible = false
		_show_toast("已清空账号与存档数据，重回 Lv.1", Color(1.0, 0.302, 0.310))
		_start_level(1, false)
	)
	cp_v.add_child(btn_del)

	var btn_cp_ok := Button.new()
	btn_cp_ok.custom_minimum_size = Vector2(0, 42)
	btn_cp_ok.text = "返回"
	_style_pill_btn(btn_cp_ok, Color(0.118, 0.161, 0.231), Color.WHITE, 12, 14)
	btn_cp_ok.pressed.connect(func(): compliance_modal.visible = false)
	cp_v.add_child(btn_cp_ok)

	# 4. Mandatory Anti-Misclick +1 Slot Confirmation Modal (RD-SPEC-02 4.2 & RD-SPEC-03 5.1 #5!)
	extra_slot_confirm_modal = _make_modal(Vector2(416, 220))
	root_ui.add_child(extra_slot_confirm_modal)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 12)
	extra_slot_confirm_modal.add_child(ev)
	var et := Label.new()
	et.text = "安全扩容槽（+1 Slot）二次确认"
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	et.add_theme_font_size_override("font_size", 19)
	et.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	ev.add_child(et)
	var ed := Label.new()
	ed.text = "防误触确认：消耗 %d 金币（或 1 枚库存券）在本局临时解锁第 6 个活跃槽位，大幅提升同色合炮容错。" % StoreServices.PRICE_EXTRA_SLOT
	ed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ed.add_theme_font_size_override("font_size", 13)
	ed.add_theme_color_override("font_color", Color(0.34, 0.42, 0.54))
	ev.add_child(ed)
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 12)
	ev.add_child(er)
	var btn_ec := Button.new()
	btn_ec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ec.custom_minimum_size = Vector2(0, 44)
	btn_ec.text = "取消"
	_style_pill_btn(btn_ec, Color(0.92, 0.94, 0.97), Color(0.24, 0.30, 0.42), 14, 15)
	btn_ec.pressed.connect(func():
		audio.play_ui_click()
		extra_slot_confirm_modal.visible = false
		extra_slot_confirm_lock = false
	)
	er.add_child(btn_ec)
	var btn_eo := Button.new()
	btn_eo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_eo.custom_minimum_size = Vector2(0, 44)
	btn_eo.text = "确认解锁"
	_style_pill_btn(btn_eo, Color(0.078, 0.722, 0.400), Color.WHITE, 14, 15)
	btn_eo.pressed.connect(_confirm_extra_slot_unlock)
	er.add_child(btn_eo)

	# 5. Victory Settlement Modal (Base + Core + 2x RV/AdFree + Pre-Level Boosters + Share Highlight!)
	win_modal = _make_modal(Vector2(448, 395))
	root_ui.add_child(win_modal)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 9)
	win_modal.add_child(wv)
	lbl_win_title = Label.new()
	lbl_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_win_title.add_theme_font_size_override("font_size", 22)
	lbl_win_title.add_theme_color_override("font_color", Color(0.114, 0.388, 0.929))
	wv.add_child(lbl_win_title)
	lbl_win_desc = Label.new()
	lbl_win_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_win_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_win_desc.add_theme_font_size_override("font_size", 13)
	lbl_win_desc.add_theme_color_override("font_color", Color(0.28, 0.35, 0.46))
	wv.add_child(lbl_win_desc)

	btn_win_double = Button.new()
	btn_win_double.custom_minimum_size = Vector2(0, 44)
	_style_pill_btn(btn_win_double, Color(1.0, 0.816, 0.078), Color(0.45, 0.24, 0.0), 14, 15)
	btn_win_double.pressed.connect(_on_win_double_clicked)
	wv.add_child(btn_win_double)

	btn_win_island = Button.new()
	btn_win_island.custom_minimum_size = Vector2(0, 44)
	btn_win_island.text = "🎨 能量已满！去 3D 浮空岛一键喷涂"
	_style_pill_btn(btn_win_island, Color(1.0, 0.541, 0.122), Color.WHITE, 14, 15)
	btn_win_island.pressed.connect(func():
		win_modal.visible = false
		_open_island_view(services.current_level == 3)
	)
	wv.add_child(btn_win_island)

	btn_win_share = Button.new()
	btn_win_share.visible = false
	btn_win_share.custom_minimum_size = Vector2(0, 38)
	btn_win_share.text = "🎬 分享 3 秒超爆粉碎高光短片"
	_style_pill_btn(btn_win_share, Color(0.93, 0.95, 0.99), Color(0.114, 0.388, 0.929), 12, 13)
	btn_win_share.pressed.connect(func():
		audio.play_ui_click()
		_show_toast("高光粉碎短片已生成，可一键分享给好友！", Color(0.114, 0.388, 0.929))
	)
	wv.add_child(btn_win_share)

	# Pre-Level Boosters Toggle Strip for Next Level (Lv.15+ Super Cannon / Lv.22+ Double Core)
	var pre_row := HBoxContainer.new()
	pre_row.add_theme_constant_override("separation", 8)
	wv.add_child(pre_row)
	btn_pre_super_tog = Button.new()
	btn_pre_super_tog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pre_super_tog.custom_minimum_size = Vector2(0, 36)
	btn_pre_super_tog.pressed.connect(func():
		audio.play_ui_click()
		pending_pre_super = not pending_pre_super
		_refresh_pre_booster_toggles()
	)
	pre_row.add_child(btn_pre_super_tog)
	btn_pre_core_tog = Button.new()
	btn_pre_core_tog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_pre_core_tog.custom_minimum_size = Vector2(0, 36)
	btn_pre_core_tog.pressed.connect(func():
		audio.play_ui_click()
		pending_pre_double_core = not pending_pre_double_core
		_refresh_pre_booster_toggles()
	)
	pre_row.add_child(btn_pre_core_tog)

	var btn_next := Button.new()
	btn_next.custom_minimum_size = Vector2(0, 50)
	btn_next.text = "下一关 ▶"
	_style_pill_btn(btn_next, Color(0.078, 0.722, 0.400), Color.WHITE, 16, 18)
	btn_next.pressed.connect(_on_win_next_clicked)
	wv.add_child(btn_next)

	# 6. Fair 6:1 Rescue Prompt Modal (360 Coins / Free RV 2/day / Restart)
	rescue_modal = _make_modal(Vector2(436, 300))
	root_ui.add_child(rescue_modal)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 9)
	rescue_modal.add_child(rv)
	var rt := Label.new()
	rt.text = "槽位已满 · 360° 扫描无命中"
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rt.add_theme_font_size_override("font_size", 19)
	rt.add_theme_color_override("font_color", Color(0.92, 0.24, 0.24))
	rv.add_child(rt)
	lbl_rescue_desc = Label.new()
	lbl_rescue_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_rescue_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_rescue_desc.add_theme_font_size_override("font_size", 13)
	lbl_rescue_desc.add_theme_color_override("font_color", Color(0.32, 0.38, 0.48))
	rv.add_child(lbl_rescue_desc)

	btn_rescue_coins = Button.new()
	btn_rescue_coins.custom_minimum_size = Vector2(0, 46)
	btn_rescue_coins.text = "⚡ 公平续关：清 2 槽回队列 (%d 币)" % StoreServices.PRICE_CONTINUE
	_style_pill_btn(btn_rescue_coins, Color(0.114, 0.388, 0.929), Color.WHITE, 14, 15)
	btn_rescue_coins.pressed.connect(func():
		if services.coins >= StoreServices.PRICE_CONTINUE:
			services.coins -= StoreServices.PRICE_CONTINUE
			services.save_state()
			rescue_modal.visible = false
			stage.execute_fair_rescue()
			_refresh_top_hud()
	)
	rv.add_child(btn_rescue_coins)

	btn_rescue_rv = Button.new()
	btn_rescue_rv.custom_minimum_size = Vector2(0, 44)
	btn_rescue_rv.text = "▶ 看激励视频免费救场（今日余 2 次）"
	_style_pill_btn(btn_rescue_rv, Color(0.078, 0.722, 0.400), Color.WHITE, 14, 14)
	btn_rescue_rv.pressed.connect(func():
		if services.can_use_daily_free_rescue():
			rescue_modal.visible = false
			_play_simulated_ad("rewarded", "free_rescue", func():
				services.consume_daily_free_rescue()
				stage.execute_fair_rescue()
			)
	)
	rv.add_child(btn_rescue_rv)

	var btn_r_fail := Button.new()
	btn_r_fail.custom_minimum_size = Vector2(0, 40)
	btn_r_fail.text = "放弃并重新挑战本关"
	_style_pill_btn(btn_r_fail, Color(0.92, 0.94, 0.97), Color(0.26, 0.32, 0.44), 12, 13)
	btn_r_fail.pressed.connect(func():
		rescue_modal.visible = false
		_on_level_failed("dock_full")
	)
	rv.add_child(btn_r_fail)

	# 7. Gentle 5-Star Rating Modal (ONLY streak>=3 + Celebration + unrated!)
	rate_modal = _make_modal(Vector2(400, 215))
	root_ui.add_child(rate_modal)
	var rtv := VBoxContainer.new()
	rtv.add_theme_constant_override("separation", 10)
	rate_modal.add_child(rtv)
	var rtt := Label.new()
	rtt.text = "★★★★★ 爆破体验还爽吗？"
	rtt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rtt.add_theme_font_size_override("font_size", 20)
	rtt.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	rtv.add_child(rtt)
	var rtd := Label.new()
	rtd.text = "恭喜达成连胜并打通庆典大关！如果喜欢《合炮大爆破》，欢迎给个五星好评支持独立研发团队！"
	rtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rtd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtd.add_theme_font_size_override("font_size", 13)
	rtd.add_theme_color_override("font_color", Color(0.34, 0.42, 0.54))
	rtv.add_child(rtd)
	var rtr := HBoxContainer.new()
	rtr.add_theme_constant_override("separation", 10)
	rtv.add_child(rtr)
	var btn_later := Button.new()
	btn_later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_later.custom_minimum_size = Vector2(0, 42)
	btn_later.text = "下次再说"
	_style_pill_btn(btn_later, Color(0.92, 0.94, 0.97), Color(0.28, 0.34, 0.46), 12, 14)
	btn_later.pressed.connect(func(): rate_modal.visible = false)
	rtr.add_child(btn_later)
	var btn_five := Button.new()
	btn_five.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_five.custom_minimum_size = Vector2(0, 42)
	btn_five.text = "给五星好评 ★"
	_style_pill_btn(btn_five, Color(1.0, 0.816, 0.078), Color(0.45, 0.24, 0.0), 12, 14)
	btn_five.pressed.connect(func():
		services.rated_current_version = true
		services.save_state()
		rate_modal.visible = false
		_show_toast("感谢你的五星好评！祝你连胜爆破！", Color(0.078, 0.722, 0.400))
	)
	rtr.add_child(btn_five)

	# 8. Simulated Ad SDK Overlay (AppLovin MAX Hook Ready)
	ad_overlay = _make_modal(Vector2(380, 150))
	ad_overlay.z_index = 60
	root_ui.add_child(ad_overlay)
	lbl_ad_msg = Label.new()
	lbl_ad_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ad_msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_ad_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_ad_msg.add_theme_font_size_override("font_size", 16)
	lbl_ad_msg.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	ad_overlay.add_child(lbl_ad_msg)


func _connect_signals() -> void:
	stage.dock_updated.connect(_refresh_dock_and_queue_ui)
	stage.cannon_inserted_fx.connect(_on_cannon_inserted_fx)
	stage.fuse_triggered.connect(_on_fuse_triggered)
	stage.shot_fired.connect(_on_shot_fired)
	stage.voxel_cleared_fx.connect(_on_voxel_cleared_fx)
	stage.callout_banner.connect(_show_toast)
	stage.level_completed.connect(_on_level_completed)
	stage.slots_jammed.connect(_on_slots_jammed)
	stage.first_rotate_detected.connect(_on_first_rotate_detected)
	services.economy_updated.connect(_refresh_top_hud)


# ==============================================================================
# LEVEL LAUNCH & FTUE FIRST-30-LEVELS SCRIPTING (RD-SPEC-02 Section 3)
# ==============================================================================
func _start_level(lv: int, is_retry: bool) -> void:
	services.refresh_lives()
	if not is_retry:
		attempt_count = 1
	else:
		attempt_count += 1

	services.current_level = maxi(1, lv)
	services.highest_level = maxi(services.highest_level, services.current_level)
	rv_magnet_used_this_level = false
	extra_slot_confirm_lock = false
	win_double_claimed = false
	win_modal.visible = false
	rescue_modal.visible = false
	extra_slot_confirm_modal.visible = false
	settings_modal.visible = false
	if home_lobby:
		home_lobby.visible = false
	stage.stage_active = true
	ftue_swipe_banner.visible = false
	flying_cannons.clear()
	laser_streaks.clear()
	electric_arcs.clear()
	energy_orbs.clear()

	# Consume pre-level booster selections (free Super Cannon at 3+ win streak!)
	var use_pre_super: bool = false
	var use_pre_core: bool = false
	if services.win_streak >= 3 and services.current_level >= 15:
		use_pre_super = true
	elif pending_pre_super and services.coins >= StoreServices.PRICE_PRE_SUPER:
		services.coins -= StoreServices.PRICE_PRE_SUPER
		use_pre_super = true
	if pending_pre_double_core and services.coins >= StoreServices.PRICE_PRE_DOUBLE_CORE:
		services.coins -= StoreServices.PRICE_PRE_DOUBLE_CORE
		use_pre_core = true
	pending_pre_super = false
	pending_pre_double_core = false

	current_level_json = repo.load_level_json(services.current_level)
	var ch_idx: int = 0 if String(current_level_json.get("chapter", "")).begins_with("Ch1") else 1
	services.island_chapter = ch_idx
	audio.play_chapter_bgm(ch_idx)

	stage.load_level_from_json(current_level_json, use_pre_super, use_pre_core)

	# Grant FTUE Milestone Free Gifts (Lv.12 x2 Magnet, Lv.18 x2 Shockwave!)
	var gift_msg: String = services.grant_ftue_milestone_gifts(services.current_level)
	if gift_msg != "":
		_show_toast(gift_msg, Color(0.078, 0.722, 0.400))

	# FTUE Contextual Hints
	var ftue_d: Dictionary = current_level_json.get("ftue_script", {})
	var hint_key: String = String(ftue_d.get("hint_key", ""))
	if hint_key == "SWIPE_360_ROTATE":
		ftue_swipe_banner.visible = true
	elif hint_key == "BLAST_PULSE_CORE":
		_show_toast("☀ 打通外壳引爆金色脉冲核，一键震飞整片积木！", Color(1.0, 0.58, 0.08))
	elif hint_key == "SPINNER_LAYER_INTRO":
		_show_toast("↻ 自转层解锁！每打空 1 座炮台，白环层自动转 90°", Color(0.114, 0.388, 0.929))
	elif hint_key == "MAGNETIC_SNAP_INTRO":
		_show_toast("🧲 磁吸合拢解锁！掏空整层上下两半啪嗒吸合", Color(1.0, 0.541, 0.122))
	elif hint_key == "CHAIN_LOCK_INTRO":
		_show_toast("⛓ 铁链锁解锁！消除相邻方块即可震碎铁链", Color(0.32, 0.38, 0.50))
	elif services.current_level == 25 and not services.purchased_once_skus.has("starter_pack"):
		_show_toast("🎁 Lv.25 解锁 $0.99 新手起航包（可在商店查看）", Color(0.114, 0.388, 0.929))

	# BI Event #2: level_start
	services.log_event("level_start", {
		"level_id": services.current_level,
		"attempt_num": attempt_count,
		"pre_boosters": ("super," if use_pre_super else "") + ("core" if use_pre_core else ""),
		"lives_left": services.lives,
	})
	services.save_state()
	_refresh_top_hud()
	_refresh_dock_and_queue_ui()
	_refresh_booster_bar()


func _restart_current_level() -> void:
	# Free restart within first 3 shots (RD-SPEC-01 2.2!)
	if stage.shots_fired_total > 3:
		_on_level_failed("quit")
	else:
		_show_toast("前 3 步免费重开，不扣体力！", Color(0.078, 0.722, 0.400))
		_start_level(services.current_level, true)


func _on_level_failed(reason: String) -> void:
	services.win_streak = 0
	services.consecutive_fails += 1
	services.consume_life_on_fail(stage.shots_fired_total)
	services.log_event("level_fail", {
		"level_id": services.current_level,
		"fail_reason": reason,
		"remaining_cubes": stage.voxels.size(),
		"dock_state": stage.get_occupied_slot_count(),
		"continue_offered": (reason == "dock_full"),
	})
	services.save_state()
	_refresh_top_hud()
	if services.lives <= 0 and not services.is_infinite_stamina():
		_show_toast("体力已耗尽！观看激励视频可立即恢复 1 颗心", Color(1.0, 0.302, 0.310))
		_play_simulated_ad("rewarded", "refill_life", func():
			services.add_life(1)
			_start_level(services.current_level, true)
		)
	else:
		_start_level(services.current_level, true)


# ==============================================================================
# INPUT & SAFE BOOSTER LOGIC (Exact Unlocks, Pricing & Anti-Double-Tap Guard!)
# ==============================================================================
func _on_orbit_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		stage.apply_orbit_drag((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenDrag:
		stage.apply_orbit_drag((event as InputEventScreenDrag).relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			stage.apply_zoom_factor(1.07)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			stage.apply_zoom_factor(0.93)
		elif not mb.pressed:
			stage.end_orbit_drag()
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		stage.end_orbit_drag()


func _on_first_rotate_detected() -> void:
	if ftue_swipe_banner.visible:
		ftue_swipe_banner.visible = false
		services.log_event("ftue_step_complete", {"step_id": "lv2_rotate_360", "level_id": services.current_level, "elapsed_sec": snappedf(ui_clock, 0.1)})


func _on_column_tapped(col_idx: int) -> void:
	var was_lv1_ftue: bool = (stage.forced_first_tap_col == col_idx and col_idx >= 0)
	if stage.try_pick_column(col_idx):
		if was_lv1_ftue:
			ftue_hand_rect.visible = false
			services.log_event("ftue_step_complete", {"step_id": "lv1_first_fuse", "level_id": 1, "elapsed_sec": snappedf(ui_clock, 0.1)})


func _on_magnet_clicked() -> void:
	audio.play_ui_click()
	if services.inv_magnet > 0:
		if stage.use_booster_magnet():
			services.inv_magnet -= 1
			services.log_event("booster_used", {"level_id": services.current_level, "booster_type": "magnet", "cost_type": "free"})
			services.save_state()
			_refresh_booster_bar()
		return
	if services.coins >= StoreServices.PRICE_MAGNET:
		if stage.use_booster_magnet():
			services.coins -= StoreServices.PRICE_MAGNET
			services.log_event("booster_used", {"level_id": services.current_level, "booster_type": "magnet", "cost_type": "coin"})
			services.save_state()
			_refresh_top_hud()
			_refresh_booster_bar()
	elif not rv_magnet_used_this_level:
		_play_simulated_ad("rewarded", "free_magnet", func():
			rv_magnet_used_this_level = true
			stage.use_booster_magnet()
			services.log_event("booster_used", {"level_id": services.current_level, "booster_type": "magnet", "cost_type": "rv"})
			_refresh_booster_bar()
		)
	else:
		_show_toast("金币不足 (%d 币)" % StoreServices.PRICE_MAGNET, Color(1.0, 0.302, 0.310))


func _on_shockwave_clicked() -> void:
	audio.play_ui_click()
	if services.inv_shockwave > 0:
		if stage.use_booster_shockwave():
			services.inv_shockwave -= 1
			services.log_event("booster_used", {"level_id": services.current_level, "booster_type": "shockwave", "cost_type": "free"})
			services.save_state()
			_refresh_booster_bar()
		return
	if services.coins >= StoreServices.PRICE_SHOCKWAVE:
		if stage.use_booster_shockwave():
			services.coins -= StoreServices.PRICE_SHOCKWAVE
			services.log_event("booster_used", {"level_id": services.current_level, "booster_type": "shockwave", "cost_type": "coin"})
			services.save_state()
			_refresh_top_hud()
			_refresh_booster_bar()
	else:
		_show_toast("金币不足 (%d 币)" % StoreServices.PRICE_SHOCKWAVE, Color(1.0, 0.302, 0.310))


func _on_extra_slot_clicked() -> void:
	audio.play_ui_click()
	if stage.extra_slot_unlocked:
		_show_toast("本关第 6 扩容槽已开启！", Color(0.078, 0.722, 0.400))
		return
	if services.inv_extra_slot <= 0 and services.coins < StoreServices.PRICE_EXTRA_SLOT:
		_show_toast("金币不足 (%d 币)" % StoreServices.PRICE_EXTRA_SLOT, Color(1.0, 0.302, 0.310))
		return
	extra_slot_confirm_lock = false
	extra_slot_confirm_modal.visible = true


func _confirm_extra_slot_unlock() -> void:
	# RD-SPEC-03 5.1 #5: Strict anti-double-tap lock so rapid clicks NEVER double-charge!
	if extra_slot_confirm_lock or stage.extra_slot_unlocked:
		return
	extra_slot_confirm_lock = true
	extra_slot_confirm_modal.visible = false
	if services.inv_extra_slot > 0 and stage.unlock_extra_slot():
		services.inv_extra_slot -= 1
		services.log_event("booster_used", {"level_id": services.current_level, "booster_type": "extra_slot", "cost_type": "free"})
		services.save_state()
	elif services.coins >= StoreServices.PRICE_EXTRA_SLOT and stage.unlock_extra_slot():
		services.coins -= StoreServices.PRICE_EXTRA_SLOT
		services.log_event("booster_used", {"level_id": services.current_level, "booster_type": "extra_slot", "cost_type": "coin"})
		services.save_state()
	_refresh_top_hud()
	_refresh_booster_bar()


# ==============================================================================
# VICTORY, RESCUE, AD LAYERING & JUICE FX
# ==============================================================================
func _on_level_completed(summary: Dictionary) -> void:
	pending_win_summary = summary
	services.win_streak += 1
	services.consecutive_fails = 0
	services.coins += int(summary["total_coins"])
	services.island_energy += int(summary["paint_energy"])
	services.daily_wins += 1
	services.daily_fuses += int(summary["fuse_count"])
	services.daily_cubes += int(summary["total_cubes"])
	services.daily_cores += int(summary["cores_popped"])
	services.save_state()

	services.log_event("level_complete", {
		"level_id": int(summary["level_id"]),
		"duration_sec": float(summary["duration_sec"]),
		"fuse_count": int(summary["fuse_count"]),
		"cores_popped": int(summary["cores_popped"]),
		"boosters_used": int(summary["boosters_used"]),
		"coins_earned": int(summary["total_coins"]),
	})
	audio.play_coin_clink()
	_refresh_top_hud()

	lbl_win_title.text = "LEVEL %d 通关！" % int(summary["level_id"])
	lbl_win_desc.text = (
		"《%s》完美粉碎！\n"
		+ "通关 +%d 币 · 脉冲核 +%d 币 · 浮空岛能量 +%d\n"
		+ "合炮 ×%d 次 · 最高连击 ×%d · 当前连胜 %d 场"
	) % [
		String(summary["title"]),
		int(summary["base_coins"]),
		int(summary["core_bonus"]),
		int(summary["paint_energy"]),
		int(summary["fuse_count"]),
		int(summary["max_combo"]),
		services.win_streak,
	]

	if services.can_use_adfree_double():
		btn_win_double.text = "👑 尊享免广告 2× 双倍领奖 (+%d 币)" % int(summary["total_coins"])
	else:
		btn_win_double.text = "▶ 看激励视频 2× 双倍领奖 (+%d 币)" % int(summary["total_coins"])
	btn_win_double.disabled = false
	btn_win_double.visible = true

	var island_ready: bool = (services.island_energy >= IslandPaintView.ENERGY_PER_PAINT) or (services.current_level == 3 and services.island_modules_painted[0] == 0)
	btn_win_island.visible = island_ready
	# RD-SPEC-03 4.2: Show 3s Highlight Share Button when a single Pulse Core blasts >= 25 cubes!
	btn_win_share.visible = (int(summary["max_core_blast"]) >= 25)

	_refresh_pre_booster_toggles()
	win_modal.visible = true

	# Gentle 5-Star Rating Gate (ONLY streak >= 3 + Celebration + unrated!)
	if services.should_show_five_star_prompt(bool(summary["is_celebration"])):
		rate_modal.visible = true


func _on_win_double_clicked() -> void:
	if win_double_claimed:
		return
	var extra: int = int(pending_win_summary.get("total_coins", 50))
	if services.use_adfree_double():
		win_double_claimed = true
		services.coins += extra
		services.save_state()
		audio.play_coin_clink()
		btn_win_double.disabled = true
		btn_win_double.text = "✓ 已免广告领取双倍 (+%d 币)" % extra
		_refresh_top_hud()
		return
	_play_simulated_ad("rewarded", "victory_double", func():
		win_double_claimed = true
		services.coins += extra
		services.save_state()
		audio.play_coin_clink()
		btn_win_double.disabled = true
		btn_win_double.text = "✓ 已领取双倍奖励 (+%d 币)" % extra
		_refresh_top_hud()
	)


func _on_win_next_clicked() -> void:
	audio.play_ui_click()
	win_modal.visible = false
	var next_lv: int = services.current_level + 1
	var inter_flag: bool = bool(current_level_json.get("interstitial_enabled", false))
	if services.should_show_interstitial(services.current_level, inter_flag):
		_play_simulated_ad("interstitial", "level_transition", func(): _start_level(next_lv, false))
	else:
		_start_level(next_lv, false)


func _on_slots_jammed(rem_cubes: int, _dock_snap: Array) -> void:
	lbl_rescue_desc.text = "剩余 %d 块体素。当前金币 %d 币（公平 6:1 经济，仅需 ~5 关即可攒出 1 次续关）。" % [rem_cubes, services.coins]
	btn_rescue_coins.disabled = (services.coins < StoreServices.PRICE_CONTINUE)
	var rem_rv: int = maxi(0, 2 - services.daily_free_rescues_used)
	btn_rescue_rv.visible = rem_rv > 0
	btn_rescue_rv.text = "▶ 看激励视频免费救场（今日余 %d 次）" % rem_rv
	rescue_modal.visible = true


func _play_simulated_ad(ad_type: String, placement: String, on_complete: Callable) -> void:
	services.log_event("ad_impression", {
		"ad_type": ad_type,
		"placement": placement,
		"level_id": services.current_level,
		"user_segment": "payer" if services.is_payer else "non_payer",
	})
	lbl_ad_msg.text = ("▶ 正在播放激励视频广告 (%s)...\n完成后立即发放奖励！" % placement) if ad_type == "rewarded" else "正在展示温和插屏广告 (Lv.31+ 非付费分层)..."
	ad_overlay.visible = true
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func():
		ad_overlay.visible = false
		on_complete.call()
	)


# ==============================================================================
# FRAME UPDATE: Squash/Stretch, Fuse Pop, Bezier Fly-In, Arcs, Lasers, Orbs, FTUE!
# ==============================================================================
func _process(delta: float) -> void:
	ui_clock += delta
	life_tick_accum += delta
	if life_tick_accum >= 5.0:
		life_tick_accum = 0.0
		services.refresh_lives()
		_refresh_top_hud()

	# FTUE Lv.1 Animated Finger Pointer pulsing over Column 0 Row 0!
	if stage.forced_first_tap_col >= 0 and stage.forced_first_tap_col < queue_tiles.size():
		var target_tile: Control = queue_tiles[stage.forced_first_tap_col][0]
		if target_tile.visible:
			ftue_hand_rect.visible = true
			var center_p: Vector2 = target_tile.global_position + target_tile.size * 0.5
			ftue_hand_rect.position = center_p + Vector2(-8, 4 + sin(ui_clock * 7.5) * 9.0)
	else:
		ftue_hand_rect.visible = false

	# Slot Squash & Stretch (0.82 -> 1.05 -> 1.0) & Fuse Pop (1.35 -> 1.12 -> 1.0)
	for i in range(FuseStage.MAX_SLOTS):
		var sx: float = 1.0
		var sy: float = 1.0
		if slot_recoil[i] > 0.001:
			slot_recoil[i] = maxf(0.0, slot_recoil[i] - delta / 0.08)
			var sq: float = slot_recoil[i]
			sx += sq * 0.14
			sy -= sq * 0.18
		if slot_fuse_pop[i] > 0.001:
			slot_fuse_pop[i] = maxf(0.0, slot_fuse_pop[i] - delta / 0.28)
			var fp: float = sin(slot_fuse_pop[i] * PI) * 0.35
			sx += fp
			sy += fp
		slot_tiles[i].scale = Vector2(sx, sy)

	var dirty_fx: bool = false
	for arr in [flying_cannons, laser_streaks, electric_arcs, energy_orbs]:
		for i in range(arr.size() - 1, -1, -1):
			arr[i]["t"] = float(arr[i]["t"]) + delta
			dirty_fx = true
			if float(arr[i]["t"]) >= float(arr[i]["dur"]):
				arr.remove_at(i)
	if dirty_fx or not flying_cannons.is_empty() or not laser_streaks.is_empty() or not electric_arcs.is_empty() or not energy_orbs.is_empty():
		fx_overlay.queue_redraw()


func _on_cannon_inserted_fx(col_idx: int, slot_idx: int, cid: int, ammo: int) -> void:
	var start_p: Vector2 = queue_tiles[col_idx][0].global_position + queue_tiles[col_idx][0].size * 0.5
	var end_p: Vector2 = _get_slot_center(slot_idx)
	flying_cannons.append({
		"start": start_p,
		"end": end_p,
		"t": 0.0,
		"dur": 0.18, # Exact 0.18s Quadratic Bezier jump (RD-SPEC-02 1.1!)
		"cid": cid,
		"ammo": ammo,
	})


func _on_fuse_triggered(left_s: int, right_s: int, _cid: int, _ammo: int, tier: int) -> void:
	if left_s >= 0 and left_s < slot_fuse_pop.size():
		slot_fuse_pop[left_s] = 1.0
	electric_arcs.append({
		"p1": _get_slot_center(left_s),
		"p2": _get_slot_center(right_s),
		"t": 0.0,
		"dur": 0.45 if tier >= 2 else 0.34,
		"tier": tier,
	})


func _on_shot_fired(slot_idx: int, target_sp: Vector2, cid: int, tier: int) -> void:
	if slot_idx >= 0 and slot_idx < slot_recoil.size():
		slot_recoil[slot_idx] = 1.0
	laser_streaks.append({
		"start": _get_slot_center(slot_idx) + Vector2(0, -24),
		"end": target_sp,
		"t": 0.0,
		"dur": 0.10,
		"col": Color(0.55, 0.36, 0.96) if tier >= 2 else (Color(0.35, 0.92, 1.0) if tier == 1 else FusePalette.get_light(cid)),
		"width": 6.0 if tier >= 2 else (4.6 if tier == 1 else 3.0),
	})


func _on_voxel_cleared_fx(sp: Vector2, cid: int, is_core: bool) -> void:
	if not is_core and randf() > 0.26:
		return
	var target: Vector2 = btn_island_icon.global_position + btn_island_icon.size * 0.5
	energy_orbs.append({
		"start": sp,
		"end": target,
		"t": 0.0,
		"dur": randf_range(0.45, 0.65),
		"col": Color(1.0, 0.816, 0.078) if is_core else FusePalette.get_color(cid),
		"ctrl_x": randf_range(-85.0, 85.0),
	})


func _draw_fx_overlay() -> void:
	# 1. Quadratic Bezier Flying Cannons (0.18s jump!)
	for fc in flying_cannons:
		var u: float = clampf(float(fc["t"]) / float(fc["dur"]), 0.0, 1.0)
		var s: Vector2 = fc["start"]
		var e: Vector2 = fc["end"]
		var ctrl: Vector2 = (s + e) * 0.5 + Vector2(0, -56.0)
		var p: Vector2 = s.lerp(ctrl, u).lerp(ctrl.lerp(e, u), u)
		var sz: float = lerpf(52.0, 66.0, u)
		var col: Color = FusePalette.get_color(int(fc["cid"]))
		fx_overlay.draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col, true)

	# 2. Bright White-Core Arcade Laser Trails
	for ls in laser_streaks:
		var u: float = clampf(float(ls["t"]) / float(ls["dur"]), 0.0, 1.0)
		var a: float = 1.0 - u
		var s: Vector2 = ls["start"]
		var e: Vector2 = ls["end"]
		var head: Vector2 = s.lerp(e, minf(1.0, u * 1.45))
		var tail: Vector2 = s.lerp(e, maxf(0.0, u * 1.45 - 0.55))
		var col: Color = ls["col"]
		fx_overlay.draw_line(tail, head, Color(col.r, col.g, col.b, a * 0.65), float(ls["width"]) * 2.0, true)
		fx_overlay.draw_line(tail, head, Color(1, 1, 1, a * 0.95), float(ls["width"]), true)

	# 3. Cyan/Violet Electric Arc Fuse Burst ("22 ⚡ 22")
	for arc in electric_arcs:
		var u: float = clampf(float(arc["t"]) / float(arc["dur"]), 0.0, 1.0)
		var alpha: float = 1.0 - smoothstep(0.42, 1.0, u)
		var p1: Vector2 = arc["p1"]
		var p2: Vector2 = arc["p2"]
		var mid: Vector2 = (p1 + p2) * 0.5
		var is_mega: bool = int(arc["tier"]) >= 2
		var glow_c: Color = Color(0.65, 0.35, 1.0) if is_mega else Color(0.22, 0.88, 1.0)
		fx_overlay.draw_circle(mid, lerpf(16.0, 62.0 if is_mega else 48.0, u), Color(glow_c.r, glow_c.g, glow_c.b, alpha * 0.34))
		for _b in range(4 if is_mega else 3):
			var pts := PackedVector2Array()
			pts.append(p1)
			for k in range(1, 6):
				var pt: Vector2 = p1.lerp(p2, float(k) / 6.0) + Vector2(randf_range(-6, 6), randf_range(-18, 18))
				pts.append(pt)
			pts.append(p2)
			fx_overlay.draw_polyline(pts, Color(glow_c.r, glow_c.g, glow_c.b, alpha * 0.88), 5.5, true)
			fx_overlay.draw_polyline(pts, Color(1, 1, 1, alpha), 2.4, true)

	# 4. Colored Energy Orbs -> Top Island Icon
	for orb in energy_orbs:
		var u: float = clampf(float(orb["t"]) / float(orb["dur"]), 0.0, 1.0)
		var s: Vector2 = orb["start"]
		var e: Vector2 = orb["end"]
		var ctrl: Vector2 = (s + e) * 0.5 + Vector2(float(orb["ctrl_x"]), -60.0)
		var p: Vector2 = s.lerp(ctrl, u).lerp(ctrl.lerp(e, u), u)
		var c: Color = orb["col"]
		fx_overlay.draw_circle(p, 7.0 * (1.0 - u * 0.35), Color(c.r, c.g, c.b, 0.45))
		fx_overlay.draw_circle(p, 4.0 * (1.0 - u * 0.30), Color(1, 1, 1, 0.95))


func _get_slot_center(idx: int) -> Vector2:
	if idx < 0 or idx >= slot_frames.size():
		return Vector2(270, 610)
	return slot_frames[idx].global_position + slot_frames[idx].size * 0.5


# ==============================================================================
# UI REFRESHERS (Top HUD, Dock, 5x3 Queue, Boosters, Settings, Shop)
# ==============================================================================
func _refresh_top_hud() -> void:
	lbl_coins.text = ("%.1fK" % (float(services.coins) / 1000.0)) if services.coins >= 1000 else ("%d" % services.coins)
	if services.is_infinite_stamina():
		@warning_ignore("integer_division")
		var mins: int = maxi(1, services.get_infinite_stamina_remaining_sec() / 60)
		lbl_lives.text = "∞ %dm" % mins
	else:
		lbl_lives.text = "%d/%d" % [services.lives, services.get_max_lives()]

	var disp_lv: int = int(current_level_json.get("display_level_id", services.current_level))
	lbl_level.text = ("MASTER %d" % (disp_lv - 60)) if bool(current_level_json.get("is_endless_master", false)) else ("LEVEL %d" % disp_lv)

	var tier: String = String(current_level_json.get("difficulty_tier", "Normal"))
	if tier == "Hard":
		difficulty_badge.visible = true
		lbl_diff_badge.text = " HARD "
		difficulty_badge.add_theme_stylebox_override("panel", _make_solid_pill(Color(1.0, 0.302, 0.310), 8))
	elif tier == "Super Hard":
		difficulty_badge.visible = true
		lbl_diff_badge.text = " SUPER HARD "
		difficulty_badge.add_theme_stylebox_override("panel", _make_solid_pill(Color(0.545, 0.361, 0.965), 8))
	elif tier == "Celebration":
		difficulty_badge.visible = true
		lbl_diff_badge.text = " ★ 庆典 "
		difficulty_badge.add_theme_stylebox_override("panel", _make_solid_pill(Color(1.0, 0.72, 0.08), 8))
	else:
		difficulty_badge.visible = false

	var ch_i: int = services.island_chapter
	var painted: int = services.island_modules_painted[ch_i]
	for i in range(5):
		var col: Color = Color(1.0, 0.839, 0.0) if i < painted else Color(0.18, 0.36, 0.72, 0.78)
		island_segs[i].add_theme_stylebox_override("panel", _make_solid_pill(col, 5))


func _refresh_dock_and_queue_ui() -> void:
	var limit: int = stage.get_active_slot_limit()
	for i in range(FuseStage.MAX_SLOTS):
		slot_frames[i].visible = (i < limit)
		slot_frames[i].custom_minimum_size = Vector2(70, 74) if limit == 6 else Vector2(82, 82)
		var sl = stage.slots[i]
		if sl == null:
			slot_tiles[i].visible = false
		else:
			slot_tiles[i].visible = true
			var cid: int = int(sl["cid"])
			var tier: int = int(sl["tier"])
			_apply_arcade_tile_style(slot_tiles[i], cid, tier, false)
			var sym: String = (FusePalette.get_symbol(cid) + " ") if services.symbol_mode else ""
			slot_ammo_labels[i].text = "%s%d" % [sym, int(sl["ammo"])]
			slot_tier_badges[i].visible = (tier >= 1)
			slot_tier_badges[i].text = "⚡⚡" if tier >= 2 else "⚡"

	var active_cols: int = stage.columns.size()
	for c in range(5):
		var show_c: bool = (c < active_cols)
		queue_col_rails[c].visible = show_c
		if not show_c:
			continue
		var col_arr: Array = stage.columns[c]
		queue_col_buttons[c].disabled = col_arr.is_empty()
		for r in range(3):
			var tile: PanelContainer = queue_tiles[c][r]
			var lbl: Label = queue_labels[c][r]
			if r < col_arr.size():
				tile.visible = true
				var it: Dictionary = col_arr[r]
				var is_hid: bool = bool(it.get("hidden", false)) and r >= 2
				if is_hid:
					_apply_hidden_tile_style(tile)
					lbl.text = "?"
				else:
					var cid: int = int(it["color_id"])
					_apply_arcade_tile_style(tile, cid, 0, r > 0)
					var sym: String = (FusePalette.get_symbol(cid) + " ") if services.symbol_mode else ""
					lbl.text = "%s%d" % [sym, int(it["ammo"])]
			else:
				tile.visible = false
		if col_arr.size() > 3:
			queue_extra_badges[c].visible = true
			queue_extra_badges[c].text = "+%d" % (col_arr.size() - 3)
		else:
			queue_extra_badges[c].visible = false


func _refresh_booster_bar() -> void:
	lbl_magnet_cost.text = ("免费×%d" % services.inv_magnet) if services.inv_magnet > 0 else (("%d" % StoreServices.PRICE_MAGNET) if (services.coins >= StoreServices.PRICE_MAGNET or rv_magnet_used_this_level) else "▶免费")
	lbl_shockwave_cost.text = ("免费×%d" % services.inv_shockwave) if services.inv_shockwave > 0 else ("%d" % StoreServices.PRICE_SHOCKWAVE)
	lbl_extra_cost.text = ("已开启" if stage.extra_slot_unlocked else (("免费×%d" % services.inv_extra_slot) if services.inv_extra_slot > 0 else ("%d" % StoreServices.PRICE_EXTRA_SLOT)))


func _refresh_pre_booster_toggles() -> void:
	var free_sup: bool = services.win_streak >= 3
	btn_pre_super_tog.text = "🔥 3连胜免费超级炮" if free_sup else ("✓ 开局超级炮 (200)" if pending_pre_super else "开局超级炮 200")
	_style_pill_btn(btn_pre_super_tog, Color(0.114, 0.388, 0.929) if (free_sup or pending_pre_super) else Color(0.93, 0.95, 0.98), Color.WHITE if (free_sup or pending_pre_super) else Color(0.22, 0.30, 0.42), 11, 12)
	btn_pre_core_tog.text = "✓ 双倍脉冲核 (200)" if pending_pre_double_core else "双倍脉冲核 200"
	_style_pill_btn(btn_pre_core_tog, Color(1.0, 0.541, 0.122) if pending_pre_double_core else Color(0.93, 0.95, 0.98), Color.WHITE if pending_pre_double_core else Color(0.22, 0.30, 0.42), 11, 12)


func _open_settings_modal() -> void:
	audio.play_ui_click()
	_refresh_settings_modal()
	settings_modal.visible = true


func _refresh_settings_modal() -> void:
	btn_sound_tog.text = "🔊 音效：开" if services.sound_enabled else "🔇 音效：关"
	btn_bgm_tog.text = "🎵 音乐：开" if services.bgm_enabled else "🎵 音乐：关"
	btn_sym_tog.text = "◎ 色盲符号：开" if services.symbol_mode else "◎ 色盲符号：关"

	for c in daily_tasks_box.get_children():
		c.queue_free()
	for t in services.get_daily_tasks():
		var row := HBoxContainer.new()
		var tl := Label.new()
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.text = "%s (%d/%d)" % [String(t["title"]), mini(int(t["cur"]), int(t["goal"])), int(t["goal"])]
		tl.add_theme_font_size_override("font_size", 12)
		tl.add_theme_color_override("font_color", Color(0.22, 0.30, 0.42))
		row.add_child(tl)
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(76, 28)
		var can_claim: bool = (not bool(t["claimed"])) and int(t["cur"]) >= int(t["goal"])
		cb.text = "已领" if bool(t["claimed"]) else ("领+50" if can_claim else "进行中")
		cb.disabled = not can_claim
		_style_pill_btn(cb, Color(0.078, 0.722, 0.400) if can_claim else Color(0.92, 0.94, 0.97), Color.WHITE if can_claim else Color(0.45, 0.52, 0.64), 8, 11)
		var tidx: int = int(t["idx"])
		cb.pressed.connect(func():
			var rew: int = services.claim_daily_task(tidx)
			if rew > 0:
				audio.play_coin_clink()
				_show_toast("每日任务达成！获得 +%d 金币" % rew, Color(0.078, 0.722, 0.400))
				_refresh_settings_modal()
		)
		row.add_child(cb)
		daily_tasks_box.add_child(row)

	telemetry_label.text = "BI 埋点已实时记录 %d 条事件（8 类标准事件齐全 · V1.0 Store-Ready）" % services.telemetry_log.size()


func _open_shop_modal() -> void:
	audio.play_ui_click()
	for c in shop_items_box.get_children():
		c.queue_free()
	for s in StoreServices.IAP_SKUS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_card_box(Color(0.96, 0.98, 1.0), 14, 4, Color(0.84, 0.89, 0.95), 1))
		var hb := HBoxContainer.new()
		card.add_child(hb)
		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(vb)
		var nl := Label.new()
		nl.text = String(s["name"])
		nl.add_theme_font_size_override("font_size", 15)
		nl.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
		vb.add_child(nl)
		var dl := Label.new()
		dl.text = String(s["desc"])
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", 11)
		dl.add_theme_color_override("font_color", Color(0.38, 0.46, 0.58))
		vb.add_child(dl)

		var pb := Button.new()
		pb.custom_minimum_size = Vector2(88, 40)
		var owned: bool = bool(s["once"]) and services.purchased_once_skus.has(String(s["sku"]))
		pb.text = "已拥有" if owned else ("$%.2f" % float(s["price"]))
		pb.disabled = owned
		_style_pill_btn(pb, Color(0.078, 0.722, 0.400) if not owned else Color(0.82, 0.86, 0.92), Color.WHITE if not owned else Color(0.45, 0.52, 0.62), 12, 14)
		var sku_cap: String = String(s["sku"])
		pb.pressed.connect(func():
			var res: Dictionary = services.purchase_sku(sku_cap)
			audio.play_coin_clink()
			_show_toast(String(res["msg"]), Color(0.078, 0.722, 0.400) if bool(res["ok"]) else Color(1.0, 0.302, 0.310))
			_open_shop_modal()
			_refresh_booster_bar()
		)
		hb.add_child(pb)
		shop_items_box.add_child(card)
	shop_modal.visible = true


func _open_island_view(free_ftue: bool) -> void:
	audio.play_ui_click()
	stage.stage_active = false
	island_view.open_view(services.island_chapter, free_ftue)


func _on_island_closed(proceed_next: bool) -> void:
	_refresh_top_hud()
	if proceed_next:
		if home_lobby:
			home_lobby.visible = false
		_start_level(services.current_level + 1, false)
	else:
		stage.stage_active = (home_lobby == null or not home_lobby.visible)
		if home_lobby and home_lobby.visible:
			home_lobby.refresh()


# ==============================================================================
# STYLE HELPERS
# ==============================================================================
func _apply_arcade_tile_style(ctrl: Control, cid: int, tier: int, dimmed: bool) -> void:
	var c: Color = FusePalette.get_color(cid)
	var dk: Color = FusePalette.get_dark(cid)
	if dimmed:
		c = c.lerp(Color(0.95, 0.97, 1.0), 0.06)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(13)
	sb.border_width_top = 3
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 5
	sb.border_color = Color(0.68, 0.42, 1.0) if tier >= 2 else (Color(0.38, 0.94, 1.0) if tier == 1 else dk)
	sb.shadow_color = Color(0.10, 0.65, 1.0, 0.42) if tier >= 1 else Color(0.06, 0.09, 0.16, 0.16)
	sb.shadow_size = 10 if tier >= 1 else 5
	sb.shadow_offset = Vector2(0, 3)

	if ctrl is PanelContainer:
		(ctrl as PanelContainer).add_theme_stylebox_override("panel", sb)
	else:
		var bg_p: Panel = ctrl.get_node_or_null("TileBG")
		if bg_p == null:
			bg_p = Panel.new()
			bg_p.name = "TileBG"
			bg_p.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg_p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ctrl.add_child(bg_p)
			ctrl.move_child(bg_p, 0)
		bg_p.add_theme_stylebox_override("panel", sb)

		var gloss: ColorRect = ctrl.get_node_or_null("TopGloss")
		if gloss == null:
			gloss = ColorRect.new()
			gloss.name = "TopGloss"
			gloss.anchor_left = 0.14; gloss.anchor_right = 0.86
			gloss.anchor_top = 0.08; gloss.anchor_bottom = 0.22
			gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ctrl.add_child(gloss)
		gloss.color = Color(1.0, 1.0, 1.0, 0.26 if tier == 0 else 0.42)


func _apply_hidden_tile_style(tile: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.46, 0.53, 0.64)
	sb.set_corner_radius_all(13)
	sb.border_width_bottom = 5
	sb.border_color = Color(0.32, 0.38, 0.48)
	tile.add_theme_stylebox_override("panel", sb)


func _make_card_box(bg: Color, radius: int, shadow_sz: int, border_c: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border_c
		sb.set_border_width_all(border_w)
	if shadow_sz > 0:
		sb.shadow_color = Color(0.059, 0.090, 0.165, 0.09) # rgba(15,23,42,0.08+)
		sb.shadow_size = shadow_sz
		sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb


func _make_solid_pill(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	return sb


func _make_outlined_ammo_label(fsz: int) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsz)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.13, 0.22, 0.94))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _make_modal(min_sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	p.z_index = 35
	p.anchor_left = 0.5; p.anchor_right = 0.5
	p.anchor_top = 0.5; p.anchor_bottom = 0.5
	p.offset_left = -min_sz.x * 0.5; p.offset_right = min_sz.x * 0.5
	p.offset_top = -min_sz.y * 0.5; p.offset_bottom = min_sz.y * 0.5
	var sb := _make_card_box(Color.WHITE, 22, 20, Color(0.84, 0.89, 0.95), 2)
	sb.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _style_white_card_btn(btn: Button, radius: int) -> void:
	var sb := _make_card_box(Color.WHITE, radius, 8, Color(0.86, 0.90, 0.95), 1)
	btn.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = Color(0.97, 0.985, 1.0)
	btn.add_theme_stylebox_override("hover", hv)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = Color(0.92, 0.95, 0.98)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _style_pill_btn(btn: Button, bg: Color, fg: Color, radius: int, fsz: int) -> void:
	var sb := _make_card_box(bg, radius, 6, Color(0.84, 0.88, 0.94), 1)
	btn.add_theme_stylebox_override("normal", sb)
	var hv := sb.duplicate() as StyleBoxFlat
	hv.bg_color = bg.lightened(0.05)
	btn.add_theme_stylebox_override("hover", hv)
	var pr := sb.duplicate() as StyleBoxFlat
	pr.bg_color = bg.darkened(0.06)
	btn.add_theme_stylebox_override("pressed", pr)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_font_size_override("font_size", fsz)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _show_toast(text: String, accent: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _make_card_box(Color(0.118, 0.161, 0.231, 0.94), 16, 8, accent, 2))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)
	callout_root.add_child(p)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sy: float = 104.0 + float(toast_active % 2) * 38.0
	toast_active += 1
	p.position = Vector2(vp.x * 0.5 - 160.0, sy)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(p, "position:y", sy - 8.0, 1.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(p, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		toast_active = maxi(0, toast_active - 1)
		p.queue_free()
	)
