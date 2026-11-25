class_name IslandPaintView
extends Control

## Light-Weight Dynamic Meta Loop: Paint-the-Island (能量喷涂浮空岛, GDD Section 4)
## Hold the glossy Spray button for 2 seconds to blast vibrant paint streams onto the grayscale
## floating toy island landmarks, popping them alive with bouncy scale animations + Chest reward!

signal closed(proceed_next_level: bool)
signal island_reward_claimed(coins_reward: int, island_idx: int)

var audio: ArcadeAudio
var island_index: int = 0
var painted_steps: int = 0 # 0..5 landmarks painted on current island
var available_charges: int = 0 # Paint charges earned from beating levels

var is_spraying: bool = false
var spray_hold_progress: float = 0.0 # 0..1 over ~1.8s
var anim_clock: float = 0.0
var landmark_pops: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var paint_drops: Array[Dictionary] = []
var chest_unlocked: bool = false

var lbl_title: Label
var lbl_sub: Label
var btn_spray: Button
var btn_close: Button
var btn_next: Button
var chest_banner: PanelContainer
var lbl_chest: Label
var canvas_view: Control


func setup(p_audio: ArcadeAudio, p_font: Font) -> void:
	audio = p_audio
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 40

	# Clean bright studio modal backdrop
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.922, 0.945, 0.973, 0.98)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 26
	vbox.offset_bottom = -26
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Header Row
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)

	lbl_title = Label.new()
	lbl_title.add_theme_font_size_override("font_size", 24)
	lbl_title.add_theme_color_override("font_color", Color(0.11, 0.16, 0.28))
	if p_font:
		lbl_title.add_theme_font_override("font", p_font)
	title_col.add_child(lbl_title)

	lbl_sub = Label.new()
	lbl_sub.add_theme_font_size_override("font_size", 13)
	lbl_sub.add_theme_color_override("font_color", Color(0.38, 0.45, 0.56))
	if p_font:
		lbl_sub.add_theme_font_override("font", p_font)
	title_col.add_child(lbl_sub)

	btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(44, 44)
	_style_pill_btn(btn_close, Color.WHITE, Color(0.18, 0.24, 0.36), 14, 18)
	btn_close.pressed.connect(func():
		if audio:
			audio.play_ui_click()
		visible = false
		closed.emit(false)
	)
	header.add_child(btn_close)

	# Custom 2.5D Floating Island Canvas
	canvas_view = Control.new()
	canvas_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_view.draw.connect(_draw_island_canvas)
	vbox.add_child(canvas_view)

	# Chest Reward Banner
	chest_banner = PanelContainer.new()
	chest_banner.visible = false
	var cb_sb := StyleBoxFlat.new()
	cb_sb.bg_color = Color(1.0, 0.96, 0.82)
	cb_sb.border_color = Color(1.0, 0.78, 0.14)
	cb_sb.set_border_width_all(2)
	cb_sb.set_corner_radius_all(18)
	cb_sb.set_content_margin_all(12)
	chest_banner.add_theme_stylebox_override("panel", cb_sb)
	vbox.add_child(chest_banner)

	lbl_chest = Label.new()
	lbl_chest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_chest.add_theme_font_size_override("font_size", 15)
	lbl_chest.add_theme_color_override("font_color", Color(0.55, 0.32, 0.04))
	if p_font:
		lbl_chest.add_theme_font_override("font", p_font)
	chest_banner.add_child(lbl_chest)

	# Action Buttons (Hold 2s Spray OR Continue)
	btn_spray = Button.new()
	btn_spray.custom_minimum_size = Vector2(0, 62)
	btn_spray.text = "🎨 按住 2 秒 · 能量喷涂点亮小岛！"
	_style_pill_btn(btn_spray, Color(0.114, 0.388, 0.929), Color.WHITE, 20, 18)
	if p_font:
		btn_spray.add_theme_font_override("font", p_font)
	btn_spray.button_down.connect(_on_spray_down)
	btn_spray.button_up.connect(_on_spray_up)
	vbox.add_child(btn_spray)

	btn_next = Button.new()
	btn_next.custom_minimum_size = Vector2(0, 56)
	btn_next.text = "继续挑战下一关 ▶"
	_style_pill_btn(btn_next, Color(0.078, 0.722, 0.400), Color.WHITE, 18, 17)
	if p_font:
		btn_next.add_theme_font_override("font", p_font)
	btn_next.pressed.connect(func():
		if audio:
			audio.play_ui_click()
		visible = false
		closed.emit(true)
	)
	vbox.add_child(btn_next)


func open_view(p_island_idx: int, p_painted_steps: int, p_charges: int) -> void:
	island_index = p_island_idx % FusePalette.ISLAND_THEMES.size()
	painted_steps = clampi(p_painted_steps, 0, 5)
	available_charges = maxi(0, p_charges)
	is_spraying = false
	spray_hold_progress = 0.0
	chest_unlocked = false
	chest_banner.visible = false
	paint_drops.clear()
	for i in range(5):
		landmark_pops[i] = 1.0 if i < painted_steps else 0.0
	_refresh_labels()
	visible = true


func _refresh_labels() -> void:
	var theme_d: Dictionary = FusePalette.ISLAND_THEMES[island_index]
	lbl_title.text = "🏝 %s (%d/5)" % [String(theme_d["name"]), painted_steps]
	if available_charges > 0:
		lbl_sub.text = "已收集能量燃料 ×%d · 长按下方按钮 2 秒一键炫彩喷涂！" % available_charges
		btn_spray.visible = true
		btn_spray.disabled = false
		btn_spray.text = "🎨 按住 2 秒 · 喷涂点亮下一座地标！(余 %d)" % available_charges
	else:
		lbl_sub.text = "过关收集彩色方块能量即可回来喷涂点亮浮空地标！"
		btn_spray.visible = false


func _on_spray_down() -> void:
	if available_charges <= 0:
		return
	is_spraying = true
	if audio:
		audio.play_paint_pop(painted_steps)


func _on_spray_up() -> void:
	is_spraying = false


func _process(delta: float) -> void:
	if not visible:
		return
	anim_clock += delta

	if is_spraying and available_charges > 0:
		spray_hold_progress += delta / 1.55
		# Spawn rapid colorful paint droplets shooting from bottom cannon to target landmark!
		if randf() < 0.72:
			var theme_d: Dictionary = FusePalette.ISLAND_THEMES[island_index]
			var accents: Array = theme_d["accent_colors"]
			var c: Color = accents[randi() % accents.size()]
			var target_slot: int = mini(painted_steps, 4)
			var sz: Vector2 = canvas_view.size
			var start_p := Vector2(sz.x * 0.5, sz.y - 36.0)
			var end_p: Vector2 = _get_landmark_pos(target_slot, sz)
			paint_drops.append({
				"start": start_p,
				"end": end_p + Vector2(randf_range(-26, 26), randf_range(-24, 18)),
				"t": 0.0,
				"dur": randf_range(0.22, 0.36),
				"color": c,
				"radius": randf_range(6.0, 12.0),
			})
		if int(spray_hold_progress * 8.0) > int((spray_hold_progress - delta / 1.55) * 8.0):
			if audio:
				audio.play_paint_pop(int(spray_hold_progress * 8.0))

		btn_spray.text = "🎨 喷涂充能中 %d%%..." % mini(100, int(spray_hold_progress * 100.0))

		if spray_hold_progress >= 1.0:
			spray_hold_progress = 0.0
			is_spraying = false
			available_charges = maxi(0, available_charges - 1)
			painted_steps = mini(5, painted_steps + 1)
			if painted_steps - 1 >= 0 and painted_steps - 1 < 5:
				landmark_pops[painted_steps - 1] = 0.01
			if audio:
				audio.play_victory()

			if painted_steps >= 5:
				chest_unlocked = true
				chest_banner.visible = true
				lbl_chest.text = "🎁 小岛全部点亮！开启宝箱：+150 金币 + 15 分钟 ∞ 无限体力！"
				island_reward_claimed.emit(150, island_index)
				# Prepare next island after showing celebration
				island_index = (island_index + 1) % FusePalette.ISLAND_THEMES.size()
				painted_steps = 0
			else:
				chest_banner.visible = true
				lbl_chest.text = "✨ 地标已点亮！获得喷涂奖励 +35 金币"
				island_reward_claimed.emit(35, island_index)
			_refresh_labels()
	elif spray_hold_progress > 0.0:
		spray_hold_progress = maxf(0.0, spray_hold_progress - delta * 1.4)

	# Animate landmark bounce pops
	for i in range(5):
		if landmark_pops[i] > 0.0 and landmark_pops[i] < 1.0:
			landmark_pops[i] = minf(1.0, landmark_pops[i] + delta * 3.4)

	# Update paint droplets
	for i in range(paint_drops.size() - 1, -1, -1):
		var d: Dictionary = paint_drops[i]
		d["t"] = float(d["t"]) + delta
		if float(d["t"]) >= float(d["dur"]):
			paint_drops.remove_at(i)

	canvas_view.queue_redraw()


func _get_landmark_pos(idx: int, sz: Vector2) -> Vector2:
	var cx: float = sz.x * 0.5
	var cy: float = sz.y * 0.48 + sin(anim_clock * 2.1) * 8.0
	var offsets: Array[Vector2] = [
		Vector2(-120, -28),
		Vector2(-58, -62),
		Vector2(0, -78),
		Vector2(64, -56),
		Vector2(118, -22),
	]
	return Vector2(cx, cy) + offsets[idx]


func _draw_island_canvas() -> void:
	var sz: Vector2 = canvas_view.size
	var cx: float = sz.x * 0.5
	var bob: float = sin(anim_clock * 2.1) * 8.0
	var cy: float = sz.y * 0.50 + bob

	var theme_d: Dictionary = FusePalette.ISLAND_THEMES[island_index]
	var base_c: Color = theme_d["base_color"]
	var accents: Array = theme_d["accent_colors"]
	var painted_ratio: float = float(painted_steps) / 5.0
	var deck_color: Color = Color(0.82, 0.85, 0.90).lerp(base_c, clampf(painted_ratio + spray_hold_progress * 0.25, 0.0, 1.0))

	# Soft floating shadow below island
	canvas_view.draw_set_transform(Vector2(cx, sz.y * 0.67), 0.0, Vector2(1.0, 0.28))
	canvas_view.draw_circle(Vector2.ZERO, 150.0, Color(0.74, 0.80, 0.88, 0.35))
	canvas_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Floating Island Rock Underbelly (Faceted Toy Poly)
	var rock_pts := PackedVector2Array([
		Vector2(cx - 178, cy + 10),
		Vector2(cx + 178, cy + 10),
		Vector2(cx + 112, cy + 88),
		Vector2(cx, cy + 118),
		Vector2(cx - 116, cy + 86),
	])
	canvas_view.draw_colored_polygon(rock_pts, Color(0.78, 0.82, 0.88).lerp(Color(0.86, 0.68, 0.52), painted_ratio))

	# Top Island Platform Oval
	canvas_view.draw_set_transform(Vector2(cx, cy + 8.0), 0.0, Vector2(1.0, 0.34))
	canvas_view.draw_circle(Vector2.ZERO, 184.0, deck_color.darkened(0.18))
	canvas_view.draw_circle(Vector2(0, -14), 178.0, deck_color)
	canvas_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5 Miniature Toy Landmarks (Grayscale -> Bouncy Glossy Vibrant Color!)
	for i in range(5):
		var pos: Vector2 = _get_landmark_pos(i, sz)
		var is_lit: bool = (i < painted_steps) or chest_unlocked
		var pop: float = landmark_pops[i]
		var bounce_s: float = 1.0
		if is_lit and pop < 1.0:
			bounce_s = 1.0 + sin(pop * PI) * 0.34
		var c: Color = (accents[i] as Color) if is_lit else Color(0.80, 0.84, 0.90)
		var w: float = (44.0 if i == 2 else 36.0) * bounce_s
		var h: float = (84.0 if i == 2 else (62.0 if i in [1, 3] else 48.0)) * bounce_s
		var rect := Rect2(pos.x - w * 0.5, pos.y - h + 38.0, w, h)
		canvas_view.draw_rect(rect, c, true)
		# Glossy top bevel highlight
		canvas_view.draw_rect(Rect2(rect.position.x + 4, rect.position.y + 4, rect.size.x - 8, 10), c.lightened(0.32), true)
		# Cute roof / beacon cap
		canvas_view.draw_circle(Vector2(pos.x, rect.position.y), w * 0.42, c.lightened(0.15) if is_lit else Color(0.74, 0.78, 0.85))

	# Mini Paint Cannon at Bottom Center
	var cannon_pos := Vector2(cx, sz.y - 28.0)
	var recoil: float = sin(anim_clock * 32.0) * 4.0 if is_spraying else 0.0
	canvas_view.draw_circle(cannon_pos + Vector2(0, recoil), 26.0, Color(0.114, 0.388, 0.929))
	canvas_view.draw_circle(cannon_pos + Vector2(0, recoil - 4.0), 16.0, Color(0.45, 0.76, 1.0))

	# Flying Paint Droplets
	for d in paint_drops:
		var u: float = clampf(float(d["t"]) / float(d["dur"]), 0.0, 1.0)
		var p: Vector2 = (d["start"] as Vector2).lerp(d["end"] as Vector2, u)
		p.y -= sin(u * PI) * 42.0
		canvas_view.draw_circle(p, float(d["radius"]) * (1.0 - u * 0.35), d["color"])


func _style_pill_btn(btn: Button, bg: Color, fg: Color, radius: int, fsz: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.12, 0.20, 0.34, 0.14)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.06)
	btn.add_theme_stylebox_override("hover", hover)
	var press := sb.duplicate() as StyleBoxFlat
	press.bg_color = bg.darkened(0.08)
	btn.add_theme_stylebox_override("pressed", press)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_font_size_override("font_size", fsz)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
