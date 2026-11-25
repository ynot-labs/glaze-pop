extends Node3D

## Master Controller v2 for《釉裂工坊 Glaze Pop!》
## Features 5-Column Mystery Queue HUD, Direct 800+ Cube Pinch-Gate Shortcut,
## High-Urgency Jammed-Slot Booster Conversion Modal, Simulated IAP Top-Up, and Diorama Shelf.

const SAVE_PATH: String = "user://glaze_pop_v2_save.cfg"
const FONT_PATH: String = "res://assets/fonts/studio_cjk.ttf"

const BOOSTER_COSTS: Dictionary = {
	"hammer": 120,
	"magnet": 140,
	"shuffle": 90,
}
const FAIR_RESCUE_COST: int = 260

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var key_light: DirectionalLight3D = $StudioKeyLight
@onready var fill_light: DirectionalLight3D = $StudioFillLight
@onready var camera: Camera3D = $StudioCamera
@onready var ui_layer: CanvasLayer = $UILayer

var audio: AsmrAudio
var stage: VoxelStage
var shelf: DioramaShelf
var ui_theme: Theme
var studio_font: Font

# Tight starting coins (280 = enough for ~2 boosters so Pinch Gate creates real scarcity & urge!)
var coins: int = 280
var current_level: int = 1
var highest_level: int = 1
var unlocked_keepsakes: Dictionary = {}
var symbol_mode: bool = false

var armed_booster: String = ""
var armed_timer: float = 0.0
var _last_minor_callout_ms: int = 0

var root_ui: Control
var gameplay_hud: Control
var shelf_hud: Control

var lbl_chapter: Label
var lbl_title: Label
var lbl_coins: Label
var btn_pinch_shortcut: Button
var btn_shelf: Button
var btn_symbols: Button
var btn_sound: Button
var btn_levels: Button
var progress_bar: ProgressBar
var lbl_progress: Label
var lbl_combo: Label
var lbl_tip: Label

var orbit_zone: Control
var dynamic_badges_root: Control
var slot_badges: Array[PanelContainer] = []
var slot_labels: Array[Label] = []
var lbl_overdrive_tag: Label

var col_hit_buttons: Array[Button] = []
var col_row_badges: Array = [[], [], [], [], []]
var col_row_labels: Array = [[], [], [], [], []]
var col_extra_labels: Array[Label] = []

var booster_buttons: Dictionary = {}
var callout_container: Control

var win_modal: PanelContainer
var lbl_win_keepsake: Label
var lbl_win_breakdown: Label

var rescue_modal: PanelContainer
var lbl_rescue_status: Label
var btn_rescue_hammer: Button
var btn_rescue_magnet: Button
var btn_coin_rescue: Button
var btn_sim_iap: Button

var level_picker_modal: PanelContainer
var lbl_shelf_selected_title: Label
var lbl_shelf_selected_desc: Label
var shelf_bay_buttons: Array[Button] = []


func _ready() -> void:
	_load_save()
	_setup_font_and_theme()
	_setup_studio_lighting()

	audio = AsmrAudio.new()
	audio.name = "AsmrAudio"
	add_child(audio)

	stage = VoxelStage.new()
	stage.name = "VoxelStage"
	add_child(stage)
	stage.setup(camera, audio)
	stage.set_symbol_mode(symbol_mode)

	shelf = DioramaShelf.new()
	shelf.name = "DioramaShelf"
	add_child(shelf)
	shelf.setup(camera)

	_build_responsive_ui()
	_connect_stage_signals()
	_start_level(current_level)


func _setup_font_and_theme() -> void:
	ui_theme = Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		studio_font = load(FONT_PATH)
		ui_theme.default_font = studio_font
	ui_theme.default_font_size = 15


func _setup_studio_lighting() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.87, 0.85, 0.82)
	sky_mat.sky_horizon_color = Color(0.835, 0.812, 0.78)
	sky_mat.ground_horizon_color = Color(0.77, 0.74, 0.70)
	sky_mat.ground_bottom_color = Color(0.69, 0.66, 0.62)

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.73)
	env.ambient_light_energy = 0.44
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.92
	world_env.environment = env

	key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	key_light.light_color = Color(1.0, 0.968, 0.915)
	key_light.light_energy = 0.76
	key_light.shadow_enabled = true
	key_light.shadow_opacity = 0.50
	key_light.shadow_blur = 1.5
	key_light.directional_shadow_max_distance = 34.0

	fill_light.rotation_degrees = Vector3(-32.0, 138.0, 0.0)
	fill_light.light_color = Color(0.90, 0.95, 1.0)
	fill_light.light_energy = 0.24
	fill_light.shadow_enabled = false


func _make_stylebox(bg: Color, radius: int = 14, border_col: Color = Color(0,0,0,0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	if border_w > 0:
		sb.border_color = border_col
		sb.border_width_left = border_w
		sb.border_width_right = border_w
		sb.border_width_top = border_w
		sb.border_width_bottom = border_w
	sb.shadow_color = Color(0.16, 0.12, 0.08, 0.12)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


func _style_btn(btn: Button, bg: Color, fg: Color, radius: int = 11, font_sz: int = 13) -> void:
	btn.add_theme_stylebox_override("normal", _make_stylebox(bg, radius, fg.darkened(0.08) * Color(1,1,1,0.25), 1))
	btn.add_theme_stylebox_override("hover", _make_stylebox(bg.lightened(0.06), radius, fg * Color(1,1,1,0.38), 1))
	btn.add_theme_stylebox_override("pressed", _make_stylebox(bg.darkened(0.08), radius, fg * Color(1,1,1,0.48), 1))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _build_responsive_ui() -> void:
	root_ui = Control.new()
	root_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ui.theme = ui_theme
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root_ui)

	gameplay_hud = Control.new()
	gameplay_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	gameplay_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(gameplay_hud)

	orbit_zone = Control.new()
	orbit_zone.anchor_left = 0.0
	orbit_zone.anchor_right = 1.0
	orbit_zone.anchor_top = 0.17
	orbit_zone.anchor_bottom = 0.55
	orbit_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	orbit_zone.gui_input.connect(_on_orbit_gui_input)
	gameplay_hud.add_child(orbit_zone)

	dynamic_badges_root = Control.new()
	dynamic_badges_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dynamic_badges_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(dynamic_badges_root)

	for i in range(VoxelStage.TOTAL_SLOTS):
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		dynamic_badges_root.add_child(badge)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color.WHITE)
		badge.add_child(l)
		slot_badges.append(badge)
		slot_labels.append(l)

	lbl_overdrive_tag = Label.new()
	lbl_overdrive_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_overdrive_tag.add_theme_font_size_override("font_size", 11)
	lbl_overdrive_tag.add_theme_color_override("font_color", Color(0.42, 0.34, 0.24))
	dynamic_badges_root.add_child(lbl_overdrive_tag)

	for c in range(VoxelStage.NUM_COLS):
		var hit_btn := Button.new()
		hit_btn.flat = true
		hit_btn.focus_mode = Control.FOCUS_NONE
		hit_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var col_capture: int = c
		hit_btn.pressed.connect(func(): _on_column_pressed(col_capture))
		dynamic_badges_root.add_child(hit_btn)
		col_hit_buttons.append(hit_btn)

		for r in range(VoxelStage.VISIBLE_ROWS):
			var p := PanelContainer.new()
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.visible = false
			dynamic_badges_root.add_child(p)
			var rl := Label.new()
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rl.add_theme_font_size_override("font_size", 13 if r == 0 else 11)
			rl.add_theme_color_override("font_color", Color.WHITE)
			p.add_child(rl)
			col_row_badges[c].append(p)
			col_row_labels[c].append(rl)

		var ex := Label.new()
		ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ex.add_theme_font_size_override("font_size", 11)
		ex.add_theme_color_override("font_color", Color(0.36, 0.32, 0.28))
		dynamic_badges_root.add_child(ex)
		col_extra_labels.append(ex)

	# Top Studio Header Card
	var top_center := CenterContainer.new()
	top_center.anchor_left = 0.0
	top_center.anchor_right = 1.0
	top_center.offset_top = 8
	top_center.offset_bottom = 136
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(top_center)

	var top_card := PanelContainer.new()
	top_card.custom_minimum_size = Vector2(522, 0)
	top_card.add_theme_stylebox_override("panel", _make_stylebox(Color(0.99, 0.98, 0.96, 0.94), 18, Color(0.84, 0.79, 0.72), 1))
	top_center.add_child(top_card)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 5)
	top_card.add_child(top_vbox)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 5)
	top_vbox.add_child(row1)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	row1.add_child(title_box)

	lbl_chapter = Label.new()
	lbl_chapter.add_theme_font_size_override("font_size", 11)
	lbl_chapter.add_theme_color_override("font_color", Color(0.58, 0.34, 0.18))
	title_box.add_child(lbl_chapter)

	lbl_title = Label.new()
	lbl_title.add_theme_font_size_override("font_size", 17)
	lbl_title.add_theme_color_override("font_color", Color(0.18, 0.16, 0.14))
	title_box.add_child(lbl_title)

	# Direct 1-Tap Shortcut to the 800+ Cube Pinch Gate!
	btn_pinch_shortcut = Button.new()
	btn_pinch_shortcut.text = "★ 直达800+格绝境关"
	_style_btn(btn_pinch_shortcut, Color(0.86, 0.28, 0.22), Color.WHITE, 11, 12)
	btn_pinch_shortcut.pressed.connect(func():
		audio.play_ui_confirm()
		_start_level(2)
	)
	row1.add_child(btn_pinch_shortcut)

	var coin_pill := PanelContainer.new()
	coin_pill.add_theme_stylebox_override("panel", _make_stylebox(Color(0.98, 0.93, 0.80), 11, Color(0.88, 0.74, 0.42), 1))
	row1.add_child(coin_pill)
	lbl_coins = Label.new()
	lbl_coins.add_theme_font_size_override("font_size", 13)
	lbl_coins.add_theme_color_override("font_color", Color(0.54, 0.36, 0.06))
	coin_pill.add_child(lbl_coins)

	btn_levels = Button.new()
	btn_levels.text = "选关"
	_style_btn(btn_levels, Color(0.93, 0.91, 0.87), Color(0.30, 0.26, 0.22), 10, 12)
	btn_levels.pressed.connect(func():
		audio.play_ui_click()
		level_picker_modal.visible = not level_picker_modal.visible
	)
	row1.add_child(btn_levels)

	btn_shelf = Button.new()
	_style_btn(btn_shelf, Color(0.90, 0.95, 0.93), Color(0.18, 0.40, 0.34), 10, 12)
	btn_shelf.pressed.connect(func():
		audio.play_ui_click()
		_open_diorama_shelf(-1)
	)
	row1.add_child(btn_shelf)

	btn_symbols = Button.new()
	_style_btn(btn_symbols, Color(0.93, 0.91, 0.87), Color(0.30, 0.26, 0.22), 10, 11)
	btn_symbols.pressed.connect(_toggle_symbol_mode)
	row1.add_child(btn_symbols)

	btn_sound = Button.new()
	_style_btn(btn_sound, Color(0.93, 0.91, 0.87), Color(0.30, 0.26, 0.22), 10, 11)
	btn_sound.pressed.connect(_toggle_sound)
	row1.add_child(btn_sound)

	var btn_retry := Button.new()
	btn_retry.text = "重开"
	_style_btn(btn_retry, Color(0.93, 0.91, 0.87), Color(0.34, 0.28, 0.24), 10, 11)
	btn_retry.pressed.connect(func():
		audio.play_ui_click()
		_start_level(current_level)
	)
	row1.add_child(btn_retry)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	top_vbox.add_child(row2)

	progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(0, 13)
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _make_stylebox(Color(0.89, 0.87, 0.83), 6))
	progress_bar.add_theme_stylebox_override("fill", _make_stylebox(Color(0.38, 0.66, 0.56), 6))
	row2.add_child(progress_bar)

	lbl_progress = Label.new()
	lbl_progress.add_theme_font_size_override("font_size", 12)
	lbl_progress.add_theme_color_override("font_color", Color(0.32, 0.28, 0.24))
	row2.add_child(lbl_progress)

	lbl_combo = Label.new()
	lbl_combo.add_theme_font_size_override("font_size", 13)
	lbl_combo.add_theme_color_override("font_color", Color(0.86, 0.38, 0.18))
	row2.add_child(lbl_combo)

	lbl_tip = Label.new()
	lbl_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_tip.add_theme_font_size_override("font_size", 11)
	lbl_tip.add_theme_color_override("font_color", Color(0.42, 0.38, 0.32))
	top_vbox.add_child(lbl_tip)

	# Bottom Safe-Zone Tactical Boosters Bar
	var bot_center := CenterContainer.new()
	bot_center.anchor_left = 0.0
	bot_center.anchor_right = 1.0
	bot_center.anchor_top = 1.0
	bot_center.anchor_bottom = 1.0
	bot_center.offset_top = -62
	bot_center.offset_bottom = -8
	bot_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(bot_center)

	var bot_card := PanelContainer.new()
	bot_card.custom_minimum_size = Vector2(520, 48)
	bot_card.add_theme_stylebox_override("panel", _make_stylebox(Color(0.99, 0.98, 0.96, 0.95), 16, Color(0.84, 0.79, 0.72), 1))
	bot_center.add_child(bot_card)

	var bot_hbox := HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 8)
	bot_card.add_child(bot_hbox)

	var b_specs: Array[Dictionary] = [
		{"id": "hammer", "label": "▣ 破城重锤 120"},
		{"id": "magnet", "label": "◎ 强力磁吸 140"},
		{"id": "shuffle", "label": "◆ 透视洗牌 90"},
	]
	for sp in b_specs:
		var b := Button.new()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bid: String = sp["id"]
		b.pressed.connect(func(): _on_booster_clicked(bid))
		bot_hbox.add_child(b)
		booster_buttons[bid] = b

	_refresh_booster_buttons()
	_refresh_header_toggles()

	callout_container = Control.new()
	callout_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	callout_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay_hud.add_child(callout_container)

	_build_modals()
	_build_shelf_hud()


func _build_modals() -> void:
	level_picker_modal = PanelContainer.new()
	level_picker_modal.visible = false
	level_picker_modal.z_index = 25
	level_picker_modal.anchor_left = 0.5
	level_picker_modal.anchor_right = 0.5
	level_picker_modal.offset_left = -258
	level_picker_modal.offset_right = 258
	level_picker_modal.offset_top = 140
	level_picker_modal.offset_bottom = 224
	level_picker_modal.add_theme_stylebox_override("panel", _make_stylebox(Color(0.99, 0.98, 0.95, 0.98), 16, Color(0.82, 0.76, 0.68), 1))
	gameplay_hud.add_child(level_picker_modal)

	var lp_vbox := VBoxContainer.new()
	level_picker_modal.add_child(lp_vbox)
	var lp_lbl := Label.new()
	lp_lbl.text = "选择开源 .vox 高密度关卡（红色为 700~850+ 格商业逼买道具卡点关）："
	lp_lbl.add_theme_font_size_override("font_size", 12)
	lp_lbl.add_theme_color_override("font_color", Color(0.40, 0.34, 0.28))
	lp_vbox.add_child(lp_lbl)

	var l_hbox := HBoxContainer.new()
	l_hbox.add_theme_constant_override("separation", 6)
	lp_vbox.add_child(l_hbox)
	var lv_names: Array[String] = ["Lv.1 灵猫", "★Lv.2 天守800+", "Lv.3 圣殿", "★Lv.4 巨壶", "★Lv.5 高塔", "★Lv.6 王城"]
	for idx in range(6):
		var lv: int = idx + 1
		var lb := Button.new()
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.text = lv_names[idx]
		var is_pinch: bool = lv in [2, 4, 5, 6]
		_style_btn(lb, Color(0.88, 0.32, 0.25) if is_pinch else Color(0.90, 0.94, 0.92), Color.WHITE if is_pinch else Color(0.20, 0.36, 0.32), 10, 12)
		var target_lv: int = lv
		lb.pressed.connect(func():
			audio.play_ui_click()
			level_picker_modal.visible = false
			_start_level(target_lv)
		)
		l_hbox.add_child(lb)

	# Victory Modal
	win_modal = PanelContainer.new()
	win_modal.visible = false
	win_modal.anchor_left = 0.5
	win_modal.anchor_right = 0.5
	win_modal.anchor_top = 1.0
	win_modal.anchor_bottom = 1.0
	win_modal.offset_left = -248
	win_modal.offset_right = 248
	win_modal.offset_top = -270
	win_modal.offset_bottom = -72
	win_modal.add_theme_stylebox_override("panel", _make_stylebox(Color(1.0, 0.99, 0.96, 0.98), 22, Color(0.90, 0.76, 0.42), 2))
	gameplay_hud.add_child(win_modal)

	var w_vbox := VBoxContainer.new()
	w_vbox.add_theme_constant_override("separation", 10)
	win_modal.add_child(w_vbox)

	lbl_win_keepsake = Label.new()
	lbl_win_keepsake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_win_keepsake.add_theme_font_size_override("font_size", 18)
	lbl_win_keepsake.add_theme_color_override("font_color", Color(0.62, 0.40, 0.08))
	w_vbox.add_child(lbl_win_keepsake)

	lbl_win_breakdown = Label.new()
	lbl_win_breakdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_win_breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_win_breakdown.add_theme_font_size_override("font_size", 13)
	lbl_win_breakdown.add_theme_color_override("font_color", Color(0.36, 0.32, 0.28))
	w_vbox.add_child(lbl_win_breakdown)

	var w_btns := HBoxContainer.new()
	w_btns.add_theme_constant_override("separation", 10)
	w_vbox.add_child(w_btns)

	var btn_view_cloche := Button.new()
	btn_view_cloche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_view_cloche.custom_minimum_size = Vector2(0, 44)
	btn_view_cloche.text = "收入玻璃罩展柜鉴赏"
	_style_btn(btn_view_cloche, Color(0.93, 0.90, 0.84), Color(0.34, 0.28, 0.20), 14, 14)
	btn_view_cloche.pressed.connect(func():
		audio.play_ui_click()
		_open_diorama_shelf(int(stage.current_level_data.get("keepsake_idx", 0)))
	)
	w_btns.add_child(btn_view_cloche)

	var btn_next := Button.new()
	btn_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_next.custom_minimum_size = Vector2(0, 44)
	btn_next.text = "挑战下一座盲盒 ▶"
	_style_btn(btn_next, Color(0.36, 0.64, 0.54), Color.WHITE, 14, 15)
	btn_next.pressed.connect(func():
		audio.play_ui_confirm()
		_start_level(current_level + 1)
	)
	w_btns.add_child(btn_next)

	# HIGH-IMPULSE PINCH GATE BOOSTER & RESCUE MODAL!
	rescue_modal = PanelContainer.new()
	rescue_modal.visible = false
	rescue_modal.z_index = 30
	rescue_modal.anchor_left = 0.5
	rescue_modal.anchor_right = 0.5
	rescue_modal.anchor_top = 0.5
	rescue_modal.anchor_bottom = 0.5
	rescue_modal.offset_left = -246
	rescue_modal.offset_right = 246
	rescue_modal.offset_top = -172
	rescue_modal.offset_bottom = 172
	rescue_modal.add_theme_stylebox_override("panel", _make_stylebox(Color(0.99, 0.98, 0.95, 0.98), 22, Color(0.88, 0.36, 0.26), 2))
	gameplay_hud.add_child(rescue_modal)

	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 8)
	rescue_modal.add_child(r_vbox)

	var r_title := Label.new()
	r_title.text = "★ 5 个槽位已被跨层大炮锁死！"
	r_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_title.add_theme_font_size_override("font_size", 18)
	r_title.add_theme_color_override("font_color", Color(0.78, 0.22, 0.16))
	r_vbox.add_child(r_title)

	lbl_rescue_status = Label.new()
	lbl_rescue_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_rescue_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_rescue_status.add_theme_font_size_override("font_size", 12)
	lbl_rescue_status.add_theme_color_override("font_color", Color(0.36, 0.32, 0.28))
	r_vbox.add_child(lbl_rescue_status)

	btn_rescue_hammer = Button.new()
	btn_rescue_hammer.custom_minimum_size = Vector2(0, 42)
	btn_rescue_hammer.text = "▣ 强推：破城重锤强拆木柱 · 引爆百格大坍塌 (120 币)"
	_style_btn(btn_rescue_hammer, Color(0.88, 0.38, 0.20), Color.WHITE, 12, 13)
	btn_rescue_hammer.pressed.connect(func():
		if coins >= 120:
			coins -= 120
			rescue_modal.visible = false
			stage.use_booster_hammer()
			_update_coins_ui()
			_save_progress()
	)
	r_vbox.add_child(btn_rescue_hammer)

	btn_rescue_magnet = Button.new()
	btn_rescue_magnet.custom_minimum_size = Vector2(0, 40)
	btn_rescue_magnet.text = "◎ 强力磁吸 · 无视遮挡抽空第1卡槽同色块 (140 币)"
	_style_btn(btn_rescue_magnet, Color(0.26, 0.60, 0.78), Color.WHITE, 12, 13)
	btn_rescue_magnet.pressed.connect(func():
		if coins >= 140:
			coins -= 140
			rescue_modal.visible = false
			stage.use_booster_magnet()
			_update_coins_ui()
			_save_progress()
	)
	r_vbox.add_child(btn_rescue_magnet)

	btn_coin_rescue = Button.new()
	btn_coin_rescue.custom_minimum_size = Vector2(0, 40)
	btn_coin_rescue.text = "★ 终极救场：永久开启第6超载槽 + 双槽清空 (260 币)"
	_style_btn(btn_coin_rescue, Color(0.92, 0.68, 0.22), Color(0.24, 0.14, 0.02), 12, 13)
	btn_coin_rescue.pressed.connect(func():
		if coins >= FAIR_RESCUE_COST:
			coins -= FAIR_RESCUE_COST
			rescue_modal.visible = false
			stage.execute_fair_rescue()
			_update_coins_ui()
			_save_progress()
	)
	r_vbox.add_child(btn_coin_rescue)

	btn_sim_iap = Button.new()
	btn_sim_iap.custom_minimum_size = Vector2(0, 38)
	btn_sim_iap.text = "★ 模拟内购补给包：立得 +500 金币 ($0.99 变现测试)"
	_style_btn(btn_sim_iap, Color(0.24, 0.56, 0.42), Color.WHITE, 12, 13)
	btn_sim_iap.pressed.connect(func():
		coins += 500
		audio.play_overdrive_ready()
		_update_coins_ui()
		_refresh_rescue_modal_buttons()
		_save_progress()
	)
	r_vbox.add_child(btn_sim_iap)

	var btn_restart_lv := Button.new()
	btn_restart_lv.custom_minimum_size = Vector2(0, 34)
	btn_restart_lv.text = "放弃当前进度 · 重新挑战本关"
	_style_btn(btn_restart_lv, Color(0.90, 0.88, 0.84), Color(0.42, 0.36, 0.32), 11, 12)
	btn_restart_lv.pressed.connect(func():
		audio.play_ui_click()
		rescue_modal.visible = false
		_start_level(current_level)
	)
	r_vbox.add_child(btn_restart_lv)


func _build_shelf_hud() -> void:
	shelf_hud = Control.new()
	shelf_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	shelf_hud.visible = false
	shelf_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(shelf_hud)

	for i in range(6):
		var hb := Button.new()
		hb.flat = true
		hb.focus_mode = Control.FOCUS_NONE
		hb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx_cap: int = i
		hb.pressed.connect(func():
			audio.play_ui_click()
			shelf.refresh_collection(unlocked_keepsakes, idx_cap)
			_update_shelf_card()
		)
		shelf_hud.add_child(hb)
		shelf_bay_buttons.append(hb)

	var top_bar := CenterContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_top = 14
	top_bar.offset_bottom = 74
	shelf_hud.add_child(top_bar)

	var header_p := PanelContainer.new()
	header_p.custom_minimum_size = Vector2(500, 52)
	header_p.add_theme_stylebox_override("panel", _make_stylebox(Color(0.99, 0.98, 0.95, 0.95), 16, Color(0.84, 0.78, 0.68), 1))
	top_bar.add_child(header_p)

	var h_row := HBoxContainer.new()
	header_p.add_child(h_row)

	var st := Label.new()
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.text = "微缩玻璃罩展柜 · Diorama Shelf"
	st.add_theme_font_size_override("font_size", 17)
	st.add_theme_color_override("font_color", Color(0.24, 0.20, 0.16))
	h_row.add_child(st)

	var btn_back := Button.new()
	btn_back.text = "◀ 返回工坊拆解"
	_style_btn(btn_back, Color(0.38, 0.66, 0.56), Color.WHITE, 12, 14)
	btn_back.pressed.connect(func():
		audio.play_ui_click()
		_close_diorama_shelf()
	)
	h_row.add_child(btn_back)

	var bot_info := CenterContainer.new()
	bot_info.anchor_left = 0.0
	bot_info.anchor_right = 1.0
	bot_info.anchor_top = 1.0
	bot_info.anchor_bottom = 1.0
	bot_info.offset_top = -126
	bot_info.offset_bottom = -18
	shelf_hud.add_child(bot_info)

	var info_card := PanelContainer.new()
	info_card.custom_minimum_size = Vector2(500, 96)
	info_card.add_theme_stylebox_override("panel", _make_stylebox(Color(0.99, 0.98, 0.95, 0.96), 18, Color(0.86, 0.78, 0.66), 1))
	bot_info.add_child(info_card)

	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	info_card.add_child(iv)

	lbl_shelf_selected_title = Label.new()
	lbl_shelf_selected_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_shelf_selected_title.add_theme_font_size_override("font_size", 17)
	lbl_shelf_selected_title.add_theme_color_override("font_color", Color(0.56, 0.38, 0.10))
	iv.add_child(lbl_shelf_selected_title)

	lbl_shelf_selected_desc = Label.new()
	lbl_shelf_selected_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_shelf_selected_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_shelf_selected_desc.add_theme_font_size_override("font_size", 13)
	lbl_shelf_selected_desc.add_theme_color_override("font_color", Color(0.40, 0.36, 0.30))
	iv.add_child(lbl_shelf_selected_desc)


func _connect_stage_signals() -> void:
	stage.stats_changed.connect(_on_stats_changed)
	stage.callout_triggered.connect(_on_callout)
	stage.coins_earned.connect(_on_coins_earned)
	stage.level_completed.connect(_on_level_completed)
	stage.slots_jammed.connect(_on_slots_jammed)
	stage.state_updated.connect(_refresh_dynamic_badges_content)


func _start_level(lv: int) -> void:
	current_level = maxi(1, lv)
	highest_level = maxi(highest_level, current_level)
	armed_booster = ""
	win_modal.visible = false
	rescue_modal.visible = false
	level_picker_modal.visible = false
	_close_diorama_shelf()

	stage.load_level(current_level)
	lbl_chapter.text = String(stage.current_level_data["chapter"])
	lbl_title.text = "《%s》" % String(stage.current_level_data["title"])
	lbl_tip.text = "◆ " + String(stage.current_level_data["tip"])
	btn_pinch_shortcut.visible = (current_level != 2)
	_update_coins_ui()
	_refresh_booster_buttons()
	_refresh_dynamic_badges_content()
	_save_progress()


func _process(delta: float) -> void:
	if armed_booster != "":
		armed_timer -= delta
		if armed_timer <= 0.0:
			armed_booster = ""
			_refresh_booster_buttons()

	if shelf.is_open:
		_update_shelf_hitboxes()
	else:
		_update_projected_stage_badges()


func _update_projected_stage_badges() -> void:
	for i in range(VoxelStage.TOTAL_SLOTS):
		var sl = stage.slots[i]
		if sl == null:
			slot_badges[i].visible = false
		else:
			slot_badges[i].visible = true
			var sp: Vector2 = stage.get_slot_screen_pos(i)
			slot_badges[i].position = sp - slot_badges[i].size * 0.5 + Vector2(0, -18)

	var sp6: Vector2 = stage.get_slot_screen_pos(5)
	lbl_overdrive_tag.position = sp6 + Vector2(-42, 22)
	lbl_overdrive_tag.size = Vector2(84, 20)

	for c in range(VoxelStage.NUM_COLS):
		var col_arr: Array = stage.columns[c]
		var top_sp: Vector2 = stage.get_column_row_screen_pos(c, 0)
		var bot_sp: Vector2 = stage.get_column_row_screen_pos(c, 2)

		var btn: Button = col_hit_buttons[c]
		btn.visible = (not col_arr.is_empty()) and (not stage.celebrating_win)
		btn.position = Vector2(top_sp.x - 36, top_sp.y - 32)
		btn.size = Vector2(72, maxf(88.0, bot_sp.y - top_sp.y + 64.0))

		for r in range(VoxelStage.VISIBLE_ROWS):
			var p: PanelContainer = col_row_badges[c][r]
			if r < col_arr.size() and not stage.celebrating_win:
				p.visible = true
				var rsp: Vector2 = stage.get_column_row_screen_pos(c, r)
				p.position = rsp - p.size * 0.5 + Vector2(0, -12 if r == 0 else -8)
			else:
				p.visible = false

		var ex_lbl: Label = col_extra_labels[c]
		if col_arr.size() > VoxelStage.VISIBLE_ROWS and not stage.celebrating_win:
			ex_lbl.visible = true
			ex_lbl.text = "深 %d" % (col_arr.size() - VoxelStage.VISIBLE_ROWS)
			ex_lbl.position = bot_sp + Vector2(-30, 24)
			ex_lbl.size = Vector2(60, 18)
		else:
			ex_lbl.visible = false


func _refresh_dynamic_badges_content() -> void:
	for i in range(VoxelStage.TOTAL_SLOTS):
		var sl = stage.slots[i]
		if sl != null:
			var ch: int = int(sl["ch"])
			var info: Dictionary = SculptureCatalog.CHANNELS[ch]
			var prefix: String = (String(info["symbol"]) + " ") if symbol_mode else ""
			slot_labels[i].text = "%s%d" % [prefix, int(sl["ammo"])]
			slot_badges[i].add_theme_stylebox_override("panel", _make_stylebox(info["ui_color"], 9, Color(1,1,1,0.75), 1))

	for c in range(VoxelStage.NUM_COLS):
		var col_arr: Array = stage.columns[c]
		for r in range(mini(col_arr.size(), VoxelStage.VISIBLE_ROWS)):
			var item: Dictionary = col_arr[r]
			var rl := col_row_labels[c][r] as Label
			var rp := col_row_badges[c][r] as PanelContainer
			if r == 2:
				# Deep mystery blind-box row!
				rl.text = "?"
				rp.add_theme_stylebox_override("panel", _make_stylebox(Color(0.28, 0.27, 0.30, 0.90), 8, Color(0.7, 0.7, 0.75, 0.4), 1))
			else:
				var ch: int = int(item["ch"])
				var info: Dictionary = SculptureCatalog.CHANNELS[ch]
				var col_bg: Color = info["ui_color"] if r == 0 else (info["ui_color"] as Color).darkened(0.14)
				if r > 0:
					col_bg.a = 0.88
				var prefix: String = (String(info["symbol"]) + " ") if symbol_mode else ""
				rl.text = "%s%d" % [prefix, int(item["ammo"])]
				rp.add_theme_stylebox_override("panel", _make_stylebox(col_bg, 10 if r == 0 else 8, Color(1, 1, 1, 0.85 if r == 0 else 0.35), 2 if r == 0 else 1))


func _on_orbit_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		stage.apply_orbit_drag((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenDrag:
		stage.apply_orbit_drag((event as InputEventScreenDrag).relative)
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		stage.end_orbit_drag()
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		stage.end_orbit_drag()


func _on_column_pressed(col_idx: int) -> void:
	if armed_booster != "":
		armed_booster = ""
		_refresh_booster_buttons()
	stage.try_pick_column(col_idx)


func _on_booster_clicked(booster_id: String) -> void:
	var cost: int = int(BOOSTER_COSTS[booster_id])
	if coins < cost:
		audio.play_ui_click()
		_on_slots_jammed() # Open booster/IAP shop when out of coins!
		return

	if armed_booster != booster_id:
		armed_booster = booster_id
		armed_timer = 2.8
		audio.play_ui_click()
		_refresh_booster_buttons()
		return

	armed_booster = ""
	var ok: bool = false
	match booster_id:
		"magnet":
			ok = stage.use_booster_magnet()
		"hammer":
			ok = stage.use_booster_hammer()
		"shuffle":
			ok = stage.use_booster_shuffle()

	if ok:
		coins -= cost
		audio.play_ui_confirm()
		_update_coins_ui()
		_save_progress()
	_refresh_booster_buttons()


func _refresh_booster_buttons() -> void:
	var titles: Dictionary = {
		"hammer": "▣ 破城重锤 120",
		"magnet": "◎ 强力磁吸 140",
		"shuffle": "◆ 透视洗牌 90",
	}
	for bid: String in booster_buttons.keys():
		var b: Button = booster_buttons[bid]
		if armed_booster == bid:
			b.text = "✓ 再点确认(%d)" % int(BOOSTER_COSTS[bid])
			_style_btn(b, Color(0.92, 0.42, 0.18), Color.WHITE, 11, 12)
		else:
			b.text = String(titles[bid])
			_style_btn(b, Color(0.94, 0.92, 0.88), Color(0.28, 0.24, 0.20), 11, 12)


func _on_stats_changed(rem: int, total: int, combo: int, od_ratio: float, od_unlocked: bool) -> void:
	var cleared: int = maxi(0, total - rem)
	progress_bar.max_value = maxi(1, total)
	progress_bar.value = cleared
	lbl_progress.text = "已剥 %d / %d" % [cleared, total]
	lbl_combo.text = ("COMBO ×%d" % combo) if combo >= 2 else ""

	if od_unlocked:
		lbl_overdrive_tag.text = "★ 超载已开"
		lbl_overdrive_tag.add_theme_color_override("font_color", Color(0.68, 0.42, 0.04))
	else:
		lbl_overdrive_tag.text = "超载 %d%%" % int(round(od_ratio * 100.0))
		lbl_overdrive_tag.add_theme_color_override("font_color", Color(0.36, 0.31, 0.26))


func _on_callout(text: String, accent: Color, _world_pos: Vector3) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if text.contains("折射") and now_ms - _last_minor_callout_ms < 750:
		return
	if text.contains("折射"):
		_last_minor_callout_ms = now_ms

	var stack_idx: int = mini(callout_container.get_child_count(), 2)
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _make_stylebox(Color(0.15, 0.13, 0.11, 0.92), 14, accent, 2))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", accent.lightened(0.34))
	p.add_child(l)
	callout_container.add_child(p)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var start_y: float = 142.0 + float(stack_idx) * 34.0
	p.position = Vector2(vp.x * 0.5 - 145.0, start_y)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.10)
	tw.parallel().tween_property(p, "position:y", start_y - 8.0, 0.90).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)


func _on_coins_earned(amount: int, _reason: String) -> void:
	coins += amount
	_update_coins_ui()


func _on_level_completed(summary: Dictionary) -> void:
	var keep_info: Dictionary = summary["keepsake"]
	var keep_id: String = String(keep_info["id"])
	var is_new: bool = not unlocked_keepsakes.has(keep_id)
	unlocked_keepsakes[keep_id] = true

	coins += int(summary["base_coins"]) + int(summary["combo_coins"])
	highest_level = maxi(highest_level, current_level + 1)
	_save_progress()
	_update_coins_ui()
	_refresh_header_toggles()

	var badge_new: String = "【新入柜藏品！】" if is_new else "【藏品复刻鉴赏】"
	lbl_win_keepsake.text = "★ %s %s ★" % [badge_new, String(keep_info["title"])]
	lbl_win_breakdown.text = (
		"通关奖励 +%d 币  ·  坍塌雪崩 +%d 币  ·  连击奖励 +%d 币\n"
		+ "本局共触发重力坍塌消除 %d 格  |  最高连击 ×%d"
	) % [
		int(summary["base_coins"]),
		int(summary["collapse_coins"]),
		int(summary["combo_coins"]),
		int(summary["collapsed_blocks"]),
		int(summary["max_combo"]),
	]
	win_modal.visible = true


func _on_slots_jammed() -> void:
	if stage.celebrating_win:
		return
	var cleared: int = stage.total_voxel_count - stage.voxels.size()
	var pct: int = int(round(float(cleared) * 100.0 / float(maxi(1, stage.total_voxel_count))))
	lbl_rescue_status.text = (
		"已成功剥离 %d%%（剩余 %d 格，核心藏品就在内层！）\n"
		+ "当前金币：%d 币 —— 选择一项强力道具瞬间破开深层死局："
	) % [pct, stage.voxels.size(), coins]
	_refresh_rescue_modal_buttons()
	rescue_modal.visible = true


func _refresh_rescue_modal_buttons() -> void:
	var cleared: int = stage.total_voxel_count - stage.voxels.size()
	var pct: int = int(round(float(cleared) * 100.0 / float(maxi(1, stage.total_voxel_count))))
	lbl_rescue_status.text = (
		"已剥离 %d%%（剩余 %d 格，核心金藏品近在咫尺！）  |  当前金币：%d 币"
	) % [pct, stage.voxels.size(), coins]
	btn_rescue_hammer.disabled = (coins < 120)
	btn_rescue_magnet.disabled = (coins < 140)
	btn_coin_rescue.disabled = (coins < FAIR_RESCUE_COST)


func _open_diorama_shelf(focus_idx: int = -1) -> void:
	stage.stage_active = false
	gameplay_hud.visible = false
	shelf.is_open = true
	shelf_hud.visible = true
	shelf.refresh_collection(unlocked_keepsakes, focus_idx if focus_idx >= 0 else shelf.selected_idx)
	_update_shelf_card()


func _close_diorama_shelf() -> void:
	shelf.is_open = false
	shelf_hud.visible = false
	gameplay_hud.visible = true
	stage.stage_active = true


func _update_shelf_card() -> void:
	var idx: int = clampi(shelf.selected_idx, 0, SculptureCatalog.KEEPSAKES.size() - 1)
	var info: Dictionary = SculptureCatalog.KEEPSAKES[idx]
	var unlocked: bool = unlocked_keepsakes.has(String(info["id"]))
	if unlocked:
		lbl_shelf_selected_title.text = "★ %s（已典藏入柜）" % String(info["title"])
		lbl_shelf_selected_desc.text = "%s — %s  |  已永久陈列于微缩玻璃罩展柜（%d / 6）" % [
			String(info["chapter"]),
			String(info["subtitle"]),
			unlocked_keepsakes.size(),
		]
	else:
		lbl_shelf_selected_title.text = "◆ 待解锁微缩藏品 · ???"
		lbl_shelf_selected_desc.text = "通关第 %d 关（%s）剥开体素核心后自动飞入玻璃罩点亮！" % [
			int(info["unlock_level"]),
			String(info["chapter"]),
		]


func _update_shelf_hitboxes() -> void:
	for i in range(6):
		var sp: Vector2 = shelf.get_bay_screen_pos(i)
		shelf_bay_buttons[i].position = sp - Vector2(54, 64)
		shelf_bay_buttons[i].size = Vector2(108, 128)


func _toggle_symbol_mode() -> void:
	symbol_mode = not symbol_mode
	audio.play_ui_click()
	stage.set_symbol_mode(symbol_mode)
	_refresh_header_toggles()
	_refresh_dynamic_badges_content()
	_save_progress()


func _toggle_sound() -> void:
	audio.sound_enabled = not audio.sound_enabled
	if audio.sound_enabled:
		audio.play_ui_click()
	_refresh_header_toggles()


func _refresh_header_toggles() -> void:
	btn_shelf.text = "展柜 %d/6" % unlocked_keepsakes.size()
	btn_symbols.text = "符号:开" if symbol_mode else "符号:关"
	btn_sound.text = "音:开" if (audio == null or audio.sound_enabled) else "音:关"


func _update_coins_ui() -> void:
	lbl_coins.text = " %d 币 " % coins
	if btn_shelf != null:
		btn_shelf.text = "展柜 %d/6" % unlocked_keepsakes.size()


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "coins", coins)
	cfg.set_value("player", "current_level", current_level)
	cfg.set_value("player", "highest_level", highest_level)
	cfg.set_value("player", "symbol_mode", symbol_mode)
	cfg.set_value("player", "keepsakes", unlocked_keepsakes.keys())
	cfg.save(SAVE_PATH)


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = int(cfg.get_value("player", "coins", 280))
	current_level = int(cfg.get_value("player", "current_level", 1))
	highest_level = int(cfg.get_value("player", "highest_level", 1))
	symbol_mode = bool(cfg.get_value("player", "symbol_mode", false))
	var k_list: Array = cfg.get_value("player", "keepsakes", [])
	for k in k_list:
		unlocked_keepsakes[String(k)] = true
