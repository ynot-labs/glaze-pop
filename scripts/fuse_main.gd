extends Node3D

## Master Controller & Page-2 Pixel-Accurate Minimalist Arcade HUD for《合炮大爆破 Fuse Smash!》
## Exact 9:16 Partitioning (GDD 5.1):
##   - Top HUD (10%): Pure white coin pill + Bold Navy LEVEL XX + 5-segment Island Bar + Gear Settings
##   - Upper-Center 3D Stage (50%): Clean floating beveled-cube sculpture on #E8EEF5 -> #F5F8FC sky
##   - Middle Active Bar (11%): 5 Recessed Slots (#CBD5E1) + Cyan Electric Fuse Arc VFX
##   - Lower Queue Grid (20%): Pure white frame housing 5x3 glossy arcade cannons with bold outlined ammo
##   - Bottom Safe Booster Bar (9%): 3 Centered pure-white rounded buttons (Magnet / Shockwave / +1 Slot w/ confirm)

const SAVE_PATH: String = "user://fuse_smash_v1_save.cfg"
const FONT_PATH: String = "res://assets/fonts/studio_cjk.ttf"

const COST_MAGNET: int = 80
const COST_SHOCKWAVE: int = 100
const COST_EXTRA_SLOT: int = 120
const COST_CONTINUE: int = 360 # Healthy 6:1 economy (GDD 6)

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $KeyLight
@onready var camera: Camera3D = $StageCamera
@onready var ui_layer: CanvasLayer = $UILayer

var audio: ArcadeAudio
var stage: FuseStage
var island_view: IslandPaintView
var studio_font: Font

# Persistent progression
var coins: int = 1200 # Start generous for immediate beta testing (matches Page 2 "1.2K" look!)
var current_level: int = 1
var win_streak: int = 0
var island_index: int = 0
var island_painted_steps: int = 0
var island_charges: int = 1
var symbol_mode: bool = false

# UI nodes
var root_ui: Control
var fx_overlay: Control
var orbit_zone: Control

var lbl_coins: Label
var lbl_level: Label
var lbl_gimmick_pill: Label
var island_segs: Array[Panel] = []
var btn_island_icon: Button

var slot_frames: Array[PanelContainer] = []
var slot_tiles: Array[Control] = []
var slot_ammo_labels: Array[Label] = []
var slot_super_badges: Array[Label] = []
var slot_recoil: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

var queue_col_buttons: Array[Button] = []
var queue_tiles: Array = [] # [5][3] Control
var queue_labels: Array = [] # [5][3] Label
var queue_extra_badges: Array[Label] = []

var btn_magnet: Button
var btn_shockwave: Button
var btn_extra_slot: Button

var settings_modal: PanelContainer
var extra_slot_confirm_modal: PanelContainer
var win_modal: PanelContainer
var lbl_win_title: Label
var lbl_win_desc: Label
var btn_win_island: Button
var continue_modal: PanelContainer
var lbl_continue_desc: Label
var btn_continue_pay: Button
var btn_sound_toggle: Button
var btn_symbol_toggle: Button

# Dynamic 2D Juice VFX (Laser Bolts, Electric Fuse Arcs, Flying Energy Orbs, Callout Toast!)
var laser_streaks: Array[Dictionary] = []
var electric_arcs: Array[Dictionary] = []
var energy_orbs: Array[Dictionary] = []
var callout_root: Control
var toast_active_count: int = 0


func _ready() -> void:
	_load_save()
	if ResourceLoader.exists(FONT_PATH):
		studio_font = load(FONT_PATH)

	_setup_clean_arcade_lighting()

	audio = ArcadeAudio.new()
	audio.name = "ArcadeAudio"
	add_child(audio)

	stage = FuseStage.new()
	stage.name = "FuseStage"
	add_child(stage)
	stage.setup(camera, audio)
	stage.set_symbol_mode(symbol_mode)

	_build_page2_arcade_ui()
	_connect_signals()
	_start_level(current_level)


func _setup_clean_arcade_lighting() -> void:
	# GDD 5.1: Clean #E8EEF5 -> #F5F8FC Sky Gradient + 1 Crisp Directional Key Light + Soft Cool-White Ambient!
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky_gradient.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.91, 0.98)
	env.ambient_light_energy = 0.34
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.02
	world_env.environment = env

	# Single crisp key light for locked 60fps mobile/WebGL2 performance with rich 3D volume!
	key_light.rotation_degrees = Vector3(-40.0, -34.0, 0.0)
	key_light.light_color = Color(1.0, 0.99, 0.97)
	key_light.light_energy = 1.45
	key_light.shadow_enabled = true
	key_light.shadow_opacity = 0.42
	key_light.shadow_blur = 1.8
	key_light.shadow_bias = 0.03
	key_light.shadow_normal_bias = 1.1
	key_light.directional_shadow_max_distance = 32.0


# ==============================================================================
# BUILD PIXEL-ACCURATE PAGE 2 MINIMALIST ARCADE UI (9:16 VERTICAL PROPORTIONS)
# ==============================================================================
func _build_page2_arcade_ui() -> void:
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if studio_font:
		var t := Theme.new()
		t.default_font = studio_font
		root_ui.theme = t
	ui_layer.add_child(root_ui)

	# Upper 50% Orbit Touch Area (captures 360° swipe + mouse wheel zoom cleanly)
	orbit_zone = Control.new()
	orbit_zone.anchor_left = 0.0
	orbit_zone.anchor_right = 1.0
	orbit_zone.anchor_top = 0.10
	orbit_zone.anchor_bottom = 0.60
	orbit_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	orbit_zone.gui_input.connect(_on_orbit_input)
	root_ui.add_child(orbit_zone)

	# Main Vertical Layout Container locked to safe centered portrait column
	var main_wrap := CenterContainer.new()
	main_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(main_wrap)

	var col_shell := Control.new()
	col_shell.custom_minimum_size = Vector2(540, 960)
	col_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_wrap.add_child(col_shell)

	# --- 1. TOP HUD (10%: 0..96px) ---
	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 18
	top_bar.offset_right = -18
	top_bar.offset_top = 14
	top_bar.offset_bottom = 86
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_shell.add_child(top_bar)

	# Top-Left: Pure White Coin Pill Capsule ("C 1.2K")
	var coin_pill := PanelContainer.new()
	coin_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_pill.add_theme_stylebox_override("panel", _make_card_box(Color.WHITE, 22, 12, Color(0.84, 0.88, 0.94), 1))
	top_bar.add_child(coin_pill)

	var coin_h := HBoxContainer.new()
	coin_h.add_theme_constant_override("separation", 7)
	coin_pill.add_child(coin_h)

	var coin_badge := PanelContainer.new()
	coin_badge.custom_minimum_size = Vector2(26, 26)
	coin_badge.add_theme_stylebox_override("panel", _make_card_box(Color(1.0, 0.816, 0.078), 13, 0, Color(0.86, 0.58, 0.02), 2))
	coin_h.add_child(coin_badge)
	var c_txt := Label.new()
	c_txt.text = "C"
	c_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	c_txt.add_theme_font_size_override("font_size", 14)
	c_txt.add_theme_color_override("font_color", Color(0.54, 0.30, 0.0))
	coin_badge.add_child(c_txt)

	lbl_coins = Label.new()
	lbl_coins.add_theme_font_size_override("font_size", 18)
	lbl_coins.add_theme_color_override("font_color", Color(0.11, 0.16, 0.28))
	coin_h.add_child(lbl_coins)

	# Top-Center: Bold Navy "LEVEL XX" + 5-Segment Island Progress Bar + Island Icon!
	var center_top := VBoxContainer.new()
	center_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_top.alignment = BoxContainer.ALIGNMENT_CENTER
	center_top.add_theme_constant_override("separation", 4)
	center_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(center_top)

	lbl_level = Label.new()
	lbl_level.text = "LEVEL 1"
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_level.add_theme_font_size_override("font_size", 24)
	lbl_level.add_theme_color_override("font_color", Color(0.11, 0.16, 0.28))
	center_top.add_child(lbl_level)

	var prog_row := HBoxContainer.new()
	prog_row.alignment = BoxContainer.ALIGNMENT_CENTER
	prog_row.add_theme_constant_override("separation", 5)
	center_top.add_child(prog_row)

	for i in range(5):
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(22, 9)
		seg.add_theme_stylebox_override("panel", _make_solid_pill(Color(0.796, 0.835, 0.882), 5))
		prog_row.add_child(seg)
		island_segs.append(seg)

	btn_island_icon = Button.new()
	btn_island_icon.text = "🏝"
	btn_island_icon.custom_minimum_size = Vector2(30, 26)
	_style_flat_icon_btn(btn_island_icon, Color(1.0, 1.0, 1.0, 0.85), Color(0.11, 0.16, 0.28), 10, 15)
	btn_island_icon.pressed.connect(_open_island_view)
	prog_row.add_child(btn_island_icon)

	# Top-Right: Pure White Rounded Square Settings Button (⚙)
	var btn_settings := Button.new()
	btn_settings.text = "⚙"
	btn_settings.custom_minimum_size = Vector2(46, 46)
	btn_settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_flat_icon_btn(btn_settings, Color.WHITE, Color(0.28, 0.35, 0.46), 15, 22)
	btn_settings.pressed.connect(func():
		audio.play_ui_click()
		_refresh_settings_labels()
		settings_modal.visible = not settings_modal.visible
	)
	top_bar.add_child(btn_settings)

	# Tiny ultra-clean Gimmick Pill right below Top HUD (subtle, non-intrusive)
	var gimmick_center := CenterContainer.new()
	gimmick_center.anchor_left = 0.0
	gimmick_center.anchor_right = 1.0
	gimmick_center.offset_top = 86
	gimmick_center.offset_bottom = 112
	gimmick_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_shell.add_child(gimmick_center)

	var g_pill := PanelContainer.new()
	g_pill.add_theme_stylebox_override("panel", _make_card_box(Color(1.0, 1.0, 1.0, 0.78), 12, 4, Color(0.84, 0.88, 0.94), 1))
	gimmick_center.add_child(g_pill)
	lbl_gimmick_pill = Label.new()
	lbl_gimmick_pill.add_theme_font_size_override("font_size", 12)
	lbl_gimmick_pill.add_theme_color_override("font_color", Color(0.24, 0.32, 0.46))
	g_pill.add_child(lbl_gimmick_pill)

	# --- 2. MIDDLE 5-SLOT ACTIVE CANNON BAR (11%: y=572..668) ---
	var slots_center := CenterContainer.new()
	slots_center.anchor_left = 0.0
	slots_center.anchor_right = 1.0
	slots_center.offset_top = 568
	slots_center.offset_bottom = 656
	slots_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_shell.add_child(slots_center)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 12)
	slots_center.add_child(slots_hbox)

	for i in range(FuseStage.MAX_SLOTS):
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(78, 78)
		frame.visible = (i < FuseStage.BASE_SLOTS)
		# GDD 5.1: Light-gray recessed slot #CBD5E1 with subtle crisp rim!
		var slot_sb := StyleBoxFlat.new()
		slot_sb.bg_color = Color(0.796, 0.835, 0.882, 0.92)
		slot_sb.border_color = Color(0.71, 0.76, 0.84, 0.95)
		slot_sb.set_border_width_all(2)
		slot_sb.set_corner_radius_all(16)
		slot_sb.set_content_margin_all(4)
		frame.add_theme_stylebox_override("panel", slot_sb)
		slots_hbox.add_child(frame)
		slot_frames.append(frame)

		var tile_holder := Control.new()
		tile_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		tile_holder.pivot_offset = Vector2(35, 35)
		tile_holder.visible = false
		frame.add_child(tile_holder)
		slot_tiles.append(tile_holder)

		var ammo_lbl := _make_outlined_ammo_label(26)
		tile_holder.add_child(ammo_lbl)
		slot_ammo_labels.append(ammo_lbl)

		var sup_lbl := Label.new()
		sup_lbl.anchor_right = 1.0
		sup_lbl.offset_top = -6
		sup_lbl.offset_right = -4
		sup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sup_lbl.add_theme_font_size_override("font_size", 14)
		sup_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.45))
		sup_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.14, 0.24))
		sup_lbl.add_theme_constant_override("outline_size", 4)
		sup_lbl.visible = false
		tile_holder.add_child(sup_lbl)
		slot_super_badges.append(sup_lbl)

	# --- 3. LOWER 5×3 QUEUE GRID (20%: y=664..868) ---
	var queue_center := CenterContainer.new()
	queue_center.anchor_left = 0.0
	queue_center.anchor_right = 1.0
	queue_center.offset_top = 666
	queue_center.offset_bottom = 868
	col_shell.add_child(queue_center)

	# Pure White Outer Frame (matches Page 2!)
	var queue_card := PanelContainer.new()
	queue_card.custom_minimum_size = Vector2(466, 198)
	queue_card.add_theme_stylebox_override("panel", _make_card_box(Color.WHITE, 22, 14, Color(0.84, 0.89, 0.95), 2))
	queue_center.add_child(queue_card)

	var queue_hbox := HBoxContainer.new()
	queue_hbox.add_theme_constant_override("separation", 8)
	queue_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	queue_card.add_child(queue_hbox)

	for c in range(FuseStage.NUM_COLS):
		var col_rail := PanelContainer.new()
		col_rail.custom_minimum_size = Vector2(82, 180)
		var rail_sb := StyleBoxFlat.new()
		rail_sb.bg_color = Color(0.88, 0.915, 0.955)
		rail_sb.set_corner_radius_all(14)
		rail_sb.set_content_margin_all(4)
		col_rail.add_theme_stylebox_override("panel", rail_sb)
		queue_hbox.add_child(col_rail)

		var col_btn := Button.new()
		col_btn.flat = true
		col_btn.focus_mode = Control.FOCUS_NONE
		col_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		col_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var cap_c: int = c
		col_btn.pressed.connect(func(): _on_column_tapped(cap_c))
		col_rail.add_child(col_btn)
		queue_col_buttons.append(col_btn)

		var col_vbox := VBoxContainer.new()
		col_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		col_vbox.add_theme_constant_override("separation", 4)
		col_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_rail.add_child(col_vbox)

		var row_tiles: Array = []
		var row_lbls: Array = []
		for r in range(3):
			var tile := PanelContainer.new()
			tile.custom_minimum_size = Vector2(74, 54)
			tile.size_flags_vertical = Control.SIZE_EXPAND_FILL
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.visible = false
			col_vbox.add_child(tile)
			row_tiles.append(tile)

			var ql := _make_outlined_ammo_label(22 if r == 0 else 19)
			ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_child(ql)
			row_lbls.append(ql)
		queue_tiles.append(row_tiles)
		queue_labels.append(row_lbls)

		var extra_lbl := Label.new()
		extra_lbl.anchor_left = 0.0
		extra_lbl.anchor_right = 1.0
		extra_lbl.anchor_top = 1.0
		extra_lbl.anchor_bottom = 1.0
		extra_lbl.offset_top = -18
		extra_lbl.offset_bottom = -2
		extra_lbl.offset_right = -6
		extra_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		extra_lbl.add_theme_font_size_override("font_size", 11)
		extra_lbl.add_theme_color_override("font_color", Color.WHITE)
		extra_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.13, 0.22, 0.9))
		extra_lbl.add_theme_constant_override("outline_size", 3)
		extra_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col_rail.add_child(extra_lbl)
		queue_extra_badges.append(extra_lbl)

	# --- 4. BOTTOM CENTERED SAFE BOOSTER BAR (9%: y=876..948, GDD 2.2 & 5.1!) ---
	var bot_center := CenterContainer.new()
	bot_center.anchor_left = 0.0
	bot_center.anchor_right = 1.0
	bot_center.offset_top = 876
	bot_center.offset_bottom = 948
	col_shell.add_child(bot_center)

	var bot_hbox := HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 18)
	bot_center.add_child(bot_hbox)

	btn_magnet = _make_booster_btn("🧲", "%d" % COST_MAGNET)
	btn_magnet.pressed.connect(_on_magnet_pressed)
	bot_hbox.add_child(btn_magnet)

	btn_shockwave = _make_booster_btn("⚡", "%d" % COST_SHOCKWAVE)
	btn_shockwave.pressed.connect(_on_shockwave_pressed)
	bot_hbox.add_child(btn_shockwave)

	# Extra Slot (+1) strictly centered in bottom safe zone + mandatory 2-step confirmation (GDD 2.2!)
	btn_extra_slot = _make_booster_btn("➕", "%d" % COST_EXTRA_SLOT)
	btn_extra_slot.pressed.connect(_on_extra_slot_pressed)
	bot_hbox.add_child(btn_extra_slot)

	# --- 5. DYNAMIC 2D FX OVERLAY (Laser Streaks + Cyan Electric Fuse Arcs + Energy Orbs!) ---
	fx_overlay = Control.new()
	fx_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_overlay.z_index = 15
	fx_overlay.draw.connect(_draw_fx_overlay)
	root_ui.add_child(fx_overlay)

	callout_root = Control.new()
	callout_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	callout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	callout_root.z_index = 20
	root_ui.add_child(callout_root)

	# --- 6. MODALS & PAINT-THE-ISLAND VIEW ---
	_build_modals()

	island_view = IslandPaintView.new()
	island_view.setup(audio, studio_font)
	island_view.closed.connect(_on_island_closed)
	island_view.island_reward_claimed.connect(_on_island_reward)
	root_ui.add_child(island_view)


func _make_booster_btn(icon_str: String, price_str: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(72, 62)
	btn.text = "%s\n%s" % [icon_str, price_str]
	_style_flat_icon_btn(btn, Color.WHITE, Color(0.14, 0.22, 0.36), 16, 15)
	return btn


func _build_modals() -> void:
	# A. Settings & Level Selector Modal
	settings_modal = _make_modal_panel(Vector2(440, 390))
	root_ui.add_child(settings_modal)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	settings_modal.add_child(sv)

	var st_title := Label.new()
	st_title.text = "⚙ 设置与关卡直达（Beta 6 关全开）"
	st_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st_title.add_theme_font_size_override("font_size", 18)
	st_title.add_theme_color_override("font_color", Color(0.11, 0.16, 0.28))
	sv.add_child(st_title)

	var tog_row := HBoxContainer.new()
	tog_row.add_theme_constant_override("separation", 10)
	sv.add_child(tog_row)

	btn_sound_toggle = Button.new()
	btn_sound_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_sound_toggle.custom_minimum_size = Vector2(0, 42)
	_style_flat_icon_btn(btn_sound_toggle, Color(0.93, 0.96, 1.0), Color(0.11, 0.22, 0.42), 12, 14)
	btn_sound_toggle.pressed.connect(func():
		audio.sound_enabled = not audio.sound_enabled
		audio.play_ui_click()
		_refresh_settings_labels()
	)
	tog_row.add_child(btn_sound_toggle)

	btn_symbol_toggle = Button.new()
	btn_symbol_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_symbol_toggle.custom_minimum_size = Vector2(0, 42)
	_style_flat_icon_btn(btn_symbol_toggle, Color(0.93, 0.96, 1.0), Color(0.11, 0.22, 0.42), 12, 14)
	btn_symbol_toggle.pressed.connect(func():
		symbol_mode = not symbol_mode
		audio.play_ui_click()
		stage.set_symbol_mode(symbol_mode)
		_refresh_settings_labels()
		_refresh_slots_and_queue_ui()
		_save_progress()
	)
	tog_row.add_child(btn_symbol_toggle)

	var lv_grid := GridContainer.new()
	lv_grid.columns = 2
	lv_grid.add_theme_constant_override("h_separation", 8)
	lv_grid.add_theme_constant_override("v_separation", 8)
	sv.add_child(lv_grid)

	var lv_labels: Array[String] = [
		"Lv.1 积木机器人 (合炮)",
		"Lv.2 太空火箭 (脉冲核★)",
		"Lv.3 复古游戏机 (磁吸)",
		"Lv.4 皇冠小鸭 (自转层)",
		"Lv.5 像素超跑 (双色炮)",
		"Lv.6 扭蛋城堡 (终极三核)",
	]
	for idx in range(6):
		var lb := Button.new()
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.custom_minimum_size = Vector2(0, 40)
		lb.text = lv_labels[idx]
		var is_hero: bool = (idx == 1)
		_style_flat_icon_btn(lb, Color(0.114, 0.388, 0.929) if is_hero else Color(0.94, 0.96, 0.99), Color.WHITE if is_hero else Color(0.14, 0.22, 0.36), 12, 13)
		var t_lv: int = idx + 1
		lb.pressed.connect(func():
			audio.play_ui_click()
			settings_modal.visible = false
			_start_level(t_lv)
		)
		lv_grid.add_child(lb)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 10)
	sv.add_child(util_row)

	var btn_restart := Button.new()
	btn_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_restart.custom_minimum_size = Vector2(0, 42)
	btn_restart.text = "↻ 重开本关"
	_style_flat_icon_btn(btn_restart, Color(1.0, 0.94, 0.92), Color(0.84, 0.20, 0.20), 12, 14)
	btn_restart.pressed.connect(func():
		audio.play_ui_click()
		settings_modal.visible = false
		_start_level(current_level)
	)
	util_row.add_child(btn_restart)

	var btn_open_isl := Button.new()
	btn_open_isl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_open_isl.custom_minimum_size = Vector2(0, 42)
	btn_open_isl.text = "🏝 浮空岛喷涂"
	_style_flat_icon_btn(btn_open_isl, Color(0.90, 0.98, 0.94), Color(0.05, 0.50, 0.28), 12, 14)
	btn_open_isl.pressed.connect(func():
		settings_modal.visible = false
		_open_island_view()
	)
	util_row.add_child(btn_open_isl)

	var btn_close_s := Button.new()
	btn_close_s.custom_minimum_size = Vector2(0, 40)
	btn_close_s.text = "关闭"
	_style_flat_icon_btn(btn_close_s, Color(0.11, 0.16, 0.28), Color.WHITE, 12, 14)
	btn_close_s.pressed.connect(func():
		audio.play_ui_click()
		settings_modal.visible = false
	)
	sv.add_child(btn_close_s)

	# B. Mandatory Anti-Misclick Confirmation for Extra Slot (+1) (GDD 2.2!)
	extra_slot_confirm_modal = _make_modal_panel(Vector2(410, 210))
	root_ui.add_child(extra_slot_confirm_modal)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 12)
	extra_slot_confirm_modal.add_child(ev)

	var et := Label.new()
	et.text = "➕ 解锁临时第 6 槽位？"
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	et.add_theme_font_size_override("font_size", 20)
	et.add_theme_color_override("font_color", Color(0.11, 0.16, 0.28))
	ev.add_child(et)

	var ed := Label.new()
	ed.text = "防误触二次确认：消耗 %d 金币为本关开启第 6 个激活槽位，让同色合炮更轻松。" % COST_EXTRA_SLOT
	ed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ed.add_theme_font_size_override("font_size", 14)
	ed.add_theme_color_override("font_color", Color(0.36, 0.42, 0.54))
	ev.add_child(ed)

	var e_row := HBoxContainer.new()
	e_row.add_theme_constant_override("separation", 12)
	ev.add_child(e_row)

	var btn_e_cancel := Button.new()
	btn_e_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_e_cancel.custom_minimum_size = Vector2(0, 46)
	btn_e_cancel.text = "取消"
	_style_flat_icon_btn(btn_e_cancel, Color(0.92, 0.94, 0.97), Color(0.24, 0.30, 0.42), 14, 15)
	btn_e_cancel.pressed.connect(func():
		audio.play_ui_click()
		extra_slot_confirm_modal.visible = false
	)
	e_row.add_child(btn_e_cancel)

	var btn_e_ok := Button.new()
	btn_e_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_e_ok.custom_minimum_size = Vector2(0, 46)
	btn_e_ok.text = "确认解锁 (-%d)" % COST_EXTRA_SLOT
	_style_flat_icon_btn(btn_e_ok, Color(0.078, 0.722, 0.400), Color.WHITE, 14, 15)
	btn_e_ok.pressed.connect(func():
		extra_slot_confirm_modal.visible = false
		if coins >= COST_EXTRA_SLOT and stage.unlock_extra_slot():
			coins -= COST_EXTRA_SLOT
			_update_top_hud()
			_save_progress()
	)
	e_row.add_child(btn_e_ok)

	# C. Crisp Victory Celebration Modal
	win_modal = _make_modal_panel(Vector2(430, 275))
	root_ui.add_child(win_modal)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 12)
	win_modal.add_child(wv)

	lbl_win_title = Label.new()
	lbl_win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_win_title.add_theme_font_size_override("font_size", 24)
	lbl_win_title.add_theme_color_override("font_color", Color(0.114, 0.388, 0.929))
	wv.add_child(lbl_win_title)

	lbl_win_desc = Label.new()
	lbl_win_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_win_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_win_desc.add_theme_font_size_override("font_size", 14)
	lbl_win_desc.add_theme_color_override("font_color", Color(0.28, 0.35, 0.46))
	wv.add_child(lbl_win_desc)

	btn_win_island = Button.new()
	btn_win_island.custom_minimum_size = Vector2(0, 48)
	btn_win_island.text = "🎨 能量已满！去喷涂浮空小岛"
	_style_flat_icon_btn(btn_win_island, Color(1.0, 0.541, 0.122), Color.WHITE, 16, 16)
	btn_win_island.pressed.connect(func():
		win_modal.visible = false
		_open_island_view()
	)
	wv.add_child(btn_win_island)

	var btn_next_lv := Button.new()
	btn_next_lv.custom_minimum_size = Vector2(0, 52)
	btn_next_lv.text = "下一关 ▶"
	_style_flat_icon_btn(btn_next_lv, Color(0.078, 0.722, 0.400), Color.WHITE, 16, 18)
	btn_next_lv.pressed.connect(func():
		audio.play_ui_click()
		win_modal.visible = false
		_start_level(current_level + 1)
	)
	wv.add_child(btn_next_lv)

	# D. Fair 6:1 Continue Modal (360 Coins, GDD 6!)
	continue_modal = _make_modal_panel(Vector2(420, 265))
	root_ui.add_child(continue_modal)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	continue_modal.add_child(cv)

	var ct := Label.new()
	ct.text = "槽位已满 · 差一点就爆破成功！"
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct.add_theme_font_size_override("font_size", 19)
	ct.add_theme_color_override("font_color", Color(0.92, 0.24, 0.24))
	cv.add_child(ct)

	lbl_continue_desc = Label.new()
	lbl_continue_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_continue_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_continue_desc.add_theme_font_size_override("font_size", 13)
	lbl_continue_desc.add_theme_color_override("font_color", Color(0.32, 0.38, 0.48))
	cv.add_child(lbl_continue_desc)

	btn_continue_pay = Button.new()
	btn_continue_pay.custom_minimum_size = Vector2(0, 48)
	btn_continue_pay.text = "⚡ 公平续关：开第 6 槽 + 清 2 槽 (%d 币)" % COST_CONTINUE
	_style_flat_icon_btn(btn_continue_pay, Color(0.114, 0.388, 0.929), Color.WHITE, 14, 15)
	btn_continue_pay.pressed.connect(func():
		if coins >= COST_CONTINUE:
			coins -= COST_CONTINUE
			continue_modal.visible = false
			stage.execute_fair_continue()
			_update_top_hud()
			_save_progress()
	)
	cv.add_child(btn_continue_pay)

	var btn_c_retry := Button.new()
	btn_c_retry.custom_minimum_size = Vector2(0, 42)
	btn_c_retry.text = "重新挑战本关"
	_style_flat_icon_btn(btn_c_retry, Color(0.93, 0.95, 0.98), Color(0.24, 0.30, 0.42), 14, 14)
	btn_c_retry.pressed.connect(func():
		audio.play_ui_click()
		continue_modal.visible = false
		win_streak = 0
		_start_level(current_level)
	)
	cv.add_child(btn_c_retry)


func _connect_signals() -> void:
	stage.state_updated.connect(_refresh_slots_and_queue_ui)
	stage.fuse_triggered.connect(_on_fuse_triggered)
	stage.shot_fired.connect(_on_shot_fired)
	stage.voxel_cleared_fx.connect(_on_voxel_cleared_fx)
	stage.callout_banner.connect(_show_toast)
	stage.level_completed.connect(_on_level_completed)
	stage.slots_jammed.connect(_on_slots_jammed)


func _start_level(lv: int) -> void:
	current_level = maxi(1, lv)
	win_modal.visible = false
	continue_modal.visible = false
	extra_slot_confirm_modal.visible = false
	settings_modal.visible = false
	laser_streaks.clear()
	electric_arcs.clear()
	energy_orbs.clear()

	stage.load_level(current_level, win_streak)
	lbl_level.text = "LEVEL %d" % current_level
	var g_tag: String = String(stage.level_data.get("gimmick_tag", "⚡ 同色合炮"))
	var lv_name: String = String(stage.level_data.get("title", ""))
	var streak_txt: String = ("  · 🔥%d连胜" % win_streak) if win_streak >= 2 else ""
	lbl_gimmick_pill.text = "%s · %s%s" % [lv_name, g_tag, streak_txt]
	_update_top_hud()
	_refresh_slots_and_queue_ui()
	_save_progress()


# ==============================================================================
# INPUT & BOOSTER HANDLERS
# ==============================================================================
func _on_orbit_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		stage.apply_orbit_drag((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenDrag:
		stage.apply_orbit_drag((event as InputEventScreenDrag).relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			stage.apply_zoom_delta(-0.85)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			stage.apply_zoom_delta(0.85)
		elif not mb.pressed:
			stage.end_orbit_drag()
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		stage.end_orbit_drag()


func _on_column_tapped(col_idx: int) -> void:
	stage.try_pick_column(col_idx)


func _on_magnet_pressed() -> void:
	if coins < COST_MAGNET:
		_show_toast("金币不足 (%d 币)" % COST_MAGNET, Color(1.0, 0.30, 0.31))
		return
	if stage.use_booster_magnet():
		coins -= COST_MAGNET
		_update_top_hud()
		_save_progress()


func _on_shockwave_pressed() -> void:
	if coins < COST_SHOCKWAVE:
		_show_toast("金币不足 (%d 币)" % COST_SHOCKWAVE, Color(1.0, 0.30, 0.31))
		return
	if stage.use_booster_shockwave():
		coins -= COST_SHOCKWAVE
		_update_top_hud()
		_save_progress()


func _on_extra_slot_pressed() -> void:
	audio.play_ui_click()
	if stage.extra_slot_unlocked:
		_show_toast("第 6 槽位本关已开启！", Color(0.08, 0.72, 0.40))
		return
	if coins < COST_EXTRA_SLOT:
		_show_toast("金币不足 (%d 币)" % COST_EXTRA_SLOT, Color(1.0, 0.30, 0.31))
		return
	# GDD 2.2 Mandatory Lightweight Confirmation!
	extra_slot_confirm_modal.visible = true


# ==============================================================================
# VISUAL JUICE & UI REFRESH (Glossy Beveled Tiles, Electric Arcs, Laser Bolts!)
# ==============================================================================
func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Slot Squash & Stretch recoil animation (GDD 5.3: 0.82 compress -> elastic rebound!)
	for i in range(FuseStage.MAX_SLOTS):
		if slot_recoil[i] > 0.001:
			slot_recoil[i] = maxf(0.0, slot_recoil[i] - delta * 8.5)
			var sq: float = slot_recoil[i]
			slot_tiles[i].scale = Vector2(1.0 + sq * 0.14, 1.0 - sq * 0.18)
		else:
			slot_tiles[i].scale = Vector2.ONE

	# Laser bullet streaks
	for i in range(laser_streaks.size() - 1, -1, -1):
		laser_streaks[i]["t"] = float(laser_streaks[i]["t"]) + delta
		needs_redraw = true
		if float(laser_streaks[i]["t"]) >= float(laser_streaks[i]["dur"]):
			laser_streaks.remove_at(i)

	# Crackling cyan-white Electric Fuse Arcs
	for i in range(electric_arcs.size() - 1, -1, -1):
		electric_arcs[i]["t"] = float(electric_arcs[i]["t"]) + delta
		needs_redraw = true
		if float(electric_arcs[i]["t"]) >= float(electric_arcs[i]["dur"]):
			electric_arcs.remove_at(i)

	# Flying Colored Energy Orbs -> Top Island Progress Bar!
	for i in range(energy_orbs.size() - 1, -1, -1):
		energy_orbs[i]["t"] = float(energy_orbs[i]["t"]) + delta
		needs_redraw = true
		if float(energy_orbs[i]["t"]) >= float(energy_orbs[i]["dur"]):
			energy_orbs.remove_at(i)

	if needs_redraw or not laser_streaks.is_empty() or not electric_arcs.is_empty() or not energy_orbs.is_empty():
		fx_overlay.queue_redraw()


func _refresh_slots_and_queue_ui() -> void:
	var limit: int = stage.get_active_slot_limit()
	for i in range(FuseStage.MAX_SLOTS):
		slot_frames[i].visible = (i < limit)
		slot_frames[i].custom_minimum_size = Vector2(68, 74) if limit == 6 else Vector2(78, 78)
		var sl = stage.slots[i]
		if sl == null:
			slot_tiles[i].visible = false
		else:
			slot_tiles[i].visible = true
			var ch: int = int(sl["ch"])
			var ch2: int = int(sl.get("ch2", -1))
			var is_sup: bool = bool(sl["is_super"])
			_apply_cannon_tile_style(slot_tiles[i], ch, is_sup, ch2)
			var sym_p: String = (FusePalette.get_symbol(ch) + " ") if symbol_mode else ""
			slot_ammo_labels[i].text = "%s%d" % [sym_p, int(sl["ammo"])]
			if is_sup:
				slot_super_badges[i].visible = true
				slot_super_badges[i].text = "⚡"
			elif ch2 != -1:
				slot_super_badges[i].visible = true
				slot_super_badges[i].text = "⇄"
			else:
				slot_super_badges[i].visible = false

	for c in range(FuseStage.NUM_COLS):
		var col_arr: Array = stage.columns[c]
		queue_col_buttons[c].disabled = col_arr.is_empty()
		for r in range(3):
			var tile: PanelContainer = queue_tiles[c][r]
			var lbl: Label = queue_labels[c][r]
			if r < col_arr.size():
				tile.visible = true
				var item: Dictionary = col_arr[r]
				var ch: int = int(item["ch"])
				var ch2: int = int(item.get("ch2", -1))
				var is_sup: bool = bool(item.get("is_super", false))
				_apply_cannon_tile_style(tile, ch, is_sup, ch2, r > 0)
				var sym_p: String = (FusePalette.get_symbol(ch) + " ") if symbol_mode else ""
				var dual_p: String = "⇄" if ch2 != -1 else ("⚡" if is_sup else "")
				lbl.text = "%s%s%d" % [sym_p, dual_p, int(item["ammo"])]
			else:
				tile.visible = false
		if col_arr.size() > 3:
			queue_extra_badges[c].visible = true
			queue_extra_badges[c].text = "+%d" % (col_arr.size() - 3)
		else:
			queue_extra_badges[c].visible = false


func _apply_cannon_tile_style(ctrl: Control, ch: int, is_super: bool, ch2: int = -1, dimmed: bool = false) -> void:
	var c: Color = FusePalette.get_color(ch)
	var dk: Color = FusePalette.get_dark(ch)
	if dimmed:
		c = c.lerp(Color(0.95, 0.97, 1.0), 0.08)
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(13)
	# Crisp 3D arcade plastic bevel illusion: bright top rim + darker bottom depth edge!
	sb.border_width_top = 3
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 5
	sb.border_color = Color(0.45, 0.94, 1.0) if is_super else (FusePalette.get_color(ch2) if ch2 != -1 else dk)
	sb.shadow_color = Color(0.10, 0.65, 1.0, 0.45) if is_super else Color(0.08, 0.14, 0.24, 0.18)
	sb.shadow_size = 10 if is_super else 5
	sb.shadow_offset = Vector2(0, 3)

	# Ensure panel child or PanelContainer gets the style
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


func _on_shot_fired(slot_idx: int, target_sp: Vector2, ch: int, is_super: bool) -> void:
	if slot_idx >= 0 and slot_idx < slot_recoil.size():
		slot_recoil[slot_idx] = 1.0
	var start_sp: Vector2 = _get_slot_center(slot_idx)
	laser_streaks.append({
		"start": start_sp + Vector2(0, -24),
		"end": target_sp,
		"t": 0.0,
		"dur": 0.11 if is_super else 0.09,
		"color": Color(0.45, 0.94, 1.0) if is_super else FusePalette.get_light(ch),
		"width": 5.5 if is_super else 3.2,
	})


func _on_fuse_triggered(left_slot: int, right_slot: int, _ch: int, _new_ammo: int) -> void:
	var p1: Vector2 = _get_slot_center(left_slot)
	var p2: Vector2 = _get_slot_center(right_slot)
	electric_arcs.append({
		"p1": p1,
		"p2": p2,
		"t": 0.0,
		"dur": 0.52,
	})


func _on_voxel_cleared_fx(sp: Vector2, ch: int, is_core: bool) -> void:
	# GDD 4: Every few cleared blocks send a glowing colored energy orb arcing into the top Island Bar!
	if not is_core and randf() > 0.28:
		return
	var target: Vector2 = btn_island_icon.global_position + btn_island_icon.size * 0.5
	energy_orbs.append({
		"start": sp,
		"end": target,
		"t": 0.0,
		"dur": randf_range(0.48, 0.68),
		"color": Color(1.0, 0.82, 0.14) if is_core else FusePalette.get_color(ch),
		"ctrl_x": randf_range(-90.0, 90.0),
	})


func _draw_fx_overlay() -> void:
	# 1. Bright White-Core Arcade Bullet Streaks (matching Page 2 glowing vertical trails!)
	for ls in laser_streaks:
		var u: float = clampf(float(ls["t"]) / float(ls["dur"]), 0.0, 1.0)
		var a: float = 1.0 - u
		var s: Vector2 = ls["start"]
		var e: Vector2 = ls["end"]
		var head: Vector2 = s.lerp(e, minf(1.0, u * 1.45))
		var tail: Vector2 = s.lerp(e, maxf(0.0, u * 1.45 - 0.55))
		var col: Color = ls["color"]
		fx_overlay.draw_line(tail, head, Color(col.r, col.g, col.b, a * 0.65), float(ls["width"]) * 2.1, true)
		fx_overlay.draw_line(tail, head, Color(1.0, 1.0, 1.0, a * 0.95), float(ls["width"]), true)
		fx_overlay.draw_circle(head, float(ls["width"]) * 1.6, Color(1.0, 0.98, 0.92, a))

	# 2. Crackling Cyan-White Electric Fuse Arcs ("22 ⚡ 22", Page 2 signature!)
	for arc in electric_arcs:
		var u: float = clampf(float(arc["t"]) / float(arc["dur"]), 0.0, 1.0)
		var alpha: float = 1.0 - smoothstep(0.45, 1.0, u)
		var p1: Vector2 = arc["p1"]
		var p2: Vector2 = arc["p2"]
		var mid: Vector2 = (p1 + p2) * 0.5
		# Bright cyan energy burst rings
		fx_overlay.draw_circle(mid, lerpf(16.0, 56.0, u), Color(0.28, 0.88, 1.0, alpha * 0.32))
		fx_overlay.draw_circle(p1, 22.0 * alpha, Color(0.55, 0.96, 1.0, alpha * 0.45))
		# 3 jagged lightning bolts between adjacent slots
		for b in range(3):
			var pts := PackedVector2Array()
			pts.append(p1)
			for k in range(1, 6):
				var t: float = float(k) / 6.0
				var pt: Vector2 = p1.lerp(p2, t)
				pt.y += randf_range(-18.0, 18.0)
				pt.x += randf_range(-6.0, 6.0)
				pts.append(pt)
			pts.append(p2)
			fx_overlay.draw_polyline(pts, Color(0.22, 0.86, 1.0, alpha * 0.85), 5.5, true)
			fx_overlay.draw_polyline(pts, Color(1.0, 1.0, 1.0, alpha), 2.4, true)

	# 3. Energy Orbs flying into Top Island Progress Bar!
	for orb in energy_orbs:
		var u: float = clampf(float(orb["t"]) / float(orb["dur"]), 0.0, 1.0)
		var s: Vector2 = orb["start"]
		var e: Vector2 = orb["end"]
		var ctrl: Vector2 = (s + e) * 0.5 + Vector2(float(orb["ctrl_x"]), -60.0)
		var p: Vector2 = s.lerp(ctrl, u).lerp(ctrl.lerp(e, u), u)
		var c: Color = orb["color"]
		fx_overlay.draw_circle(p, 7.5 * (1.0 - u * 0.35), Color(c.r, c.g, c.b, 0.45))
		fx_overlay.draw_circle(p, 4.5 * (1.0 - u * 0.30), Color(1.0, 1.0, 1.0, 0.95))


func _get_slot_center(idx: int) -> Vector2:
	if idx < 0 or idx >= slot_frames.size():
		return Vector2(270, 610)
	return slot_frames[idx].global_position + slot_frames[idx].size * 0.5


func _on_level_completed(summary: Dictionary) -> void:
	win_streak += 1
	coins += int(summary["total_coins"])
	island_charges += 1
	_update_top_hud()
	_save_progress()

	lbl_win_title.text = "🎉 LEVEL %d 爆破通关！" % int(summary["level"])
	lbl_win_desc.text = (
		"《%s》已完美粉碎！\n"
		+ "通关奖励 +%d 币 · 脉冲核额外 +%d 币\n"
		+ "本局合炮 ×%d 次 · 最高连击 ×%d · 连胜 %d 场"
	) % [
		String(summary["title"]),
		int(summary["base_coins"]),
		int(summary["core_bonus"]),
		int(summary["fuses"]),
		int(summary["max_combo"]),
		win_streak,
	]
	btn_win_island.visible = (island_charges > 0)
	win_modal.visible = true


func _on_slots_jammed() -> void:
	var rem: int = stage.voxels.size()
	lbl_continue_desc.text = "360° 自动扫描已完成，仍余 %d 块。当前金币 %d 币（公平 6:1 经济，连赢 6 关即可免费攒出 1 次续关）。" % [rem, coins]
	btn_continue_pay.disabled = (coins < COST_CONTINUE)
	continue_modal.visible = true


func _open_island_view() -> void:
	audio.play_ui_click()
	stage.stage_active = false
	island_view.open_view(island_index, island_painted_steps, island_charges)


func _on_island_closed(proceed_next: bool) -> void:
	stage.stage_active = true
	island_index = island_view.island_index
	island_painted_steps = island_view.painted_steps
	island_charges = island_view.available_charges
	_update_top_hud()
	_save_progress()
	if proceed_next:
		_start_level(current_level + 1)


func _on_island_reward(reward_coins: int, _isl_idx: int) -> void:
	coins += reward_coins
	island_index = island_view.island_index
	island_painted_steps = island_view.painted_steps
	island_charges = island_view.available_charges
	_update_top_hud()
	_save_progress()


func _update_top_hud() -> void:
	if coins >= 1000:
		lbl_coins.text = "%.1fK" % (float(coins) / 1000.0)
	else:
		lbl_coins.text = "%d" % coins

	for i in range(5):
		var filled: bool = i < island_painted_steps
		var col: Color = Color(0.11, 0.16, 0.28) if filled else Color(0.796, 0.835, 0.882)
		island_segs[i].add_theme_stylebox_override("panel", _make_solid_pill(col, 5))

	btn_island_icon.text = "🏝!" if island_charges > 0 else "🏝"


func _refresh_settings_labels() -> void:
	btn_sound_toggle.text = "🔊 音效：开" if audio.sound_enabled else "🔇 音效：关"
	btn_symbol_toggle.text = "◎ 色盲微符号：开" if symbol_mode else "◎ 色盲微符号：关"


func _show_toast(text: String, accent: Color) -> void:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _make_card_box(Color(0.11, 0.16, 0.28, 0.92), 16, 8, accent, 2))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)
	callout_root.add_child(p)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sy: float = 118.0 + float(toast_active_count % 2) * 40.0
	toast_active_count += 1
	p.position = Vector2(vp.x * 0.5 - 155.0, sy)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(p, "position:y", sy - 10.0, 0.95).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(p, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		toast_active_count = maxi(0, toast_active_count - 1)
		p.queue_free()
	)


# ==============================================================================
# STYLE HELPERS & PERSISTENCE
# ==============================================================================
func _make_card_box(bg: Color, radius: int, shadow_sz: int, border_c: Color, border_w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border_c
		sb.set_border_width_all(border_w)
	if shadow_sz > 0:
		sb.shadow_color = Color(0.12, 0.20, 0.34, 0.12)
		sb.shadow_size = shadow_sz
		sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
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
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.13, 0.22, 0.92))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _make_modal_panel(min_sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.visible = false
	p.z_index = 32
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -min_sz.x * 0.5
	p.offset_right = min_sz.x * 0.5
	p.offset_top = -min_sz.y * 0.5
	p.offset_bottom = min_sz.y * 0.5
	var sb := _make_card_box(Color.WHITE, 24, 22, Color(0.84, 0.89, 0.95), 2)
	sb.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _style_flat_icon_btn(btn: Button, bg: Color, fg: Color, radius: int, fsz: int) -> void:
	var sb := _make_card_box(bg, radius, 8, Color(0.84, 0.88, 0.94), 1)
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


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("fuse", "coins", coins)
	cfg.set_value("fuse", "level", current_level)
	cfg.set_value("fuse", "streak", win_streak)
	cfg.set_value("fuse", "island_idx", island_index)
	cfg.set_value("fuse", "island_steps", island_painted_steps)
	cfg.set_value("fuse", "island_charges", island_charges)
	cfg.set_value("fuse", "symbols", symbol_mode)
	cfg.save(SAVE_PATH)


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = int(cfg.get_value("fuse", "coins", 1200))
	current_level = int(cfg.get_value("fuse", "level", 1))
	win_streak = int(cfg.get_value("fuse", "streak", 0))
	island_index = int(cfg.get_value("fuse", "island_idx", 0))
	island_painted_steps = int(cfg.get_value("fuse", "island_steps", 0))
	island_charges = int(cfg.get_value("fuse", "island_charges", 1))
	symbol_mode = bool(cfg.get_value("fuse", "symbols", false))
