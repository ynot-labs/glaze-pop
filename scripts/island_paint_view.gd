class_name IslandPaintView
extends Control

## V1.0 Store-Ready 3D Paint-the-Island Studio (RD-SPEC-02 Section 4.1)
## Loads real 3D GLB islands (island_ch1_sail.glb & island_ch2_dessert.glb), each with 5
## independently paintable 3D landmark modules! Hold 2 seconds to blast rainbow paint onto
## grayscale modules -> pops into glossy color with 3D bounce + 300 Coins & 30min ∞ Stamina!

signal closed(proceed_next_level: bool)
signal module_painted(chapter_idx: int, module_idx: int, reward_coins: int, completed_island: bool)

const ENERGY_PER_PAINT: int = 500

var audio: ArcadeAudio
var services: StoreServices

var chapter_idx: int = 0
var painted_count: int = 0
var available_energy: int = 0
var free_ftue_paint: bool = false

var is_spraying: bool = false
var spray_progress: float = 0.0
var anim_clock: float = 0.0
var paint_drops: Array[Dictionary] = []

var vp_container: SubViewportContainer
var sub_vp: SubViewport
var island_pivot: Node3D
var module_nodes: Array[Node3D] = []
var module_orig_mats: Array[Material] = []
var module_pop_t: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var gray_mat: StandardMaterial3D
var spray_overlay: Control

var lbl_title: Label
var lbl_sub: Label
var energy_bar: ProgressBar
var btn_spray: Button
var btn_ch_switch: Button
var chest_panel: PanelContainer
var lbl_chest: Label


func setup(p_audio: ArcadeAudio, p_services: StoreServices, p_font: Font) -> void:
	audio = p_audio
	services = p_services
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 45

	gray_mat = StandardMaterial3D.new()
	gray_mat.albedo_color = Color(0.76, 0.80, 0.86)
	gray_mat.roughness = 0.65

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.918, 0.941, 0.972, 0.99)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 18
	vbox.offset_right = -18
	vbox.offset_top = 24
	vbox.offset_bottom = -24
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var tcol := VBoxContainer.new()
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(tcol)

	lbl_title = Label.new()
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color(0.118, 0.161, 0.231))
	if p_font:
		lbl_title.add_theme_font_override("font", p_font)
	tcol.add_child(lbl_title)

	lbl_sub = Label.new()
	lbl_sub.add_theme_font_size_override("font_size", 13)
	lbl_sub.add_theme_color_override("font_color", Color(0.36, 0.43, 0.54))
	if p_font:
		lbl_sub.add_theme_font_override("font", p_font)
	tcol.add_child(lbl_sub)

	btn_ch_switch = Button.new()
	btn_ch_switch.custom_minimum_size = Vector2(96, 40)
	btn_ch_switch.text = "切换章节"
	_style_btn(btn_ch_switch, Color.WHITE, Color(0.114, 0.388, 0.929), 13, 13)
	btn_ch_switch.pressed.connect(func():
		if audio:
			audio.play_ui_click()
		chapter_idx = (chapter_idx + 1) % FusePalette.ISLAND_CHAPTERS.size()
		painted_count = services.island_modules_painted[chapter_idx]
		_load_3d_island_scene()
		_refresh_ui()
	)
	header.add_child(btn_ch_switch)

	var btn_x := Button.new()
	btn_x.text = "✕"
	btn_x.custom_minimum_size = Vector2(44, 40)
	_style_btn(btn_x, Color.WHITE, Color(0.18, 0.24, 0.36), 13, 18)
	btn_x.pressed.connect(func():
		if audio:
			audio.play_ui_click()
		visible = false
		closed.emit(false)
	)
	header.add_child(btn_x)

	# Paint Energy Progress Bar
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(0, 14)
	energy_bar.max_value = ENERGY_PER_PAINT
	energy_bar.show_percentage = false
	var eb_bg := StyleBoxFlat.new()
	eb_bg.bg_color = Color(0.82, 0.86, 0.92)
	eb_bg.set_corner_radius_all(7)
	var eb_fill := StyleBoxFlat.new()
	eb_fill.bg_color = Color(0.114, 0.388, 0.929)
	eb_fill.set_corner_radius_all(7)
	energy_bar.add_theme_stylebox_override("background", eb_bg)
	energy_bar.add_theme_stylebox_override("fill", eb_fill)
	vbox.add_child(energy_bar)

	# 3D SubViewport Rendering the Real GLB Floating Island!
	var stage_holder := Control.new()
	stage_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(stage_holder)

	vp_container = SubViewportContainer.new()
	vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	stage_holder.add_child(vp_container)

	sub_vp = SubViewport.new()
	sub_vp.own_world_3d = true
	sub_vp.transparent_bg = true
	sub_vp.msaa_3d = Viewport.MSAA_2X
	sub_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vp_container.add_child(sub_vp)

	var cam := Camera3D.new()
	cam.fov = 34.0
	sub_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 4.3, 8.8), Vector3(0.0, 0.95, 0.0), Vector3.UP)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.92, 0.945, 0.975, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.90, 0.94, 1.0)
	env.ambient_light_energy = 0.72
	var we := WorldEnvironment.new()
	we.environment = env
	sub_vp.add_child(we)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	light.light_energy = 1.35
	sub_vp.add_child(light)

	island_pivot = Node3D.new()
	sub_vp.add_child(island_pivot)

	spray_overlay = Control.new()
	spray_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	spray_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spray_overlay.draw.connect(_draw_spray_overlay)
	stage_holder.add_child(spray_overlay)

	# Chest Reward Banner
	chest_panel = PanelContainer.new()
	chest_panel.visible = false
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(1.0, 0.965, 0.84)
	csb.border_color = Color(1.0, 0.78, 0.14)
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(16)
	csb.set_content_margin_all(12)
	chest_panel.add_theme_stylebox_override("panel", csb)
	vbox.add_child(chest_panel)

	lbl_chest = Label.new()
	lbl_chest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_chest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_chest.add_theme_font_size_override("font_size", 14)
	lbl_chest.add_theme_color_override("font_color", Color(0.56, 0.30, 0.02))
	if p_font:
		lbl_chest.add_theme_font_override("font", p_font)
	chest_panel.add_child(lbl_chest)

	# Hold-to-Spray 2s Primary CTA
	btn_spray = Button.new()
	btn_spray.custom_minimum_size = Vector2(0, 58)
	_style_btn(btn_spray, Color(0.114, 0.388, 0.929), Color.WHITE, 18, 17)
	if p_font:
		btn_spray.add_theme_font_override("font", p_font)
	btn_spray.button_down.connect(_on_spray_down)
	btn_spray.button_up.connect(func(): is_spraying = false)
	vbox.add_child(btn_spray)

	var btn_next := Button.new()
	btn_next.custom_minimum_size = Vector2(0, 52)
	btn_next.text = "返回继续闯关 ▶"
	_style_btn(btn_next, Color(0.078, 0.722, 0.400), Color.WHITE, 16, 16)
	if p_font:
		btn_next.add_theme_font_override("font", p_font)
	btn_next.pressed.connect(func():
		if audio:
			audio.play_ui_click()
		visible = false
		closed.emit(true)
	)
	vbox.add_child(btn_next)


func open_view(p_chapter: int, p_free_ftue: bool = false) -> void:
	chapter_idx = clampi(p_chapter, 0, FusePalette.ISLAND_CHAPTERS.size() - 1)
	painted_count = services.island_modules_painted[chapter_idx]
	available_energy = services.island_energy
	free_ftue_paint = p_free_ftue
	is_spraying = false
	spray_progress = 0.0
	chest_panel.visible = false
	paint_drops.clear()
	_load_3d_island_scene()
	_refresh_ui()
	visible = true


func _load_3d_island_scene() -> void:
	for c in island_pivot.get_children():
		c.queue_free()
	module_nodes.clear()
	module_orig_mats.clear()

	var ch_info: Dictionary = FusePalette.ISLAND_CHAPTERS[chapter_idx]
	var glb_path: String = String(ch_info["glb_path"])
	if not ResourceLoader.exists(glb_path):
		return
	var ps: PackedScene = load(glb_path)
	if ps == null:
		return
	var inst: Node3D = ps.instantiate()
	island_pivot.add_child(inst)

	# Enable vertex colors cleanly on all painted GLB materials + cache Module_0..Module_4!
	var found_mods: Dictionary = {}
	_collect_island_meshes(inst, found_mods)
	for i in range(5):
		var key: String = "Module_%d" % i
		if found_mods.has(key):
			var mi: MeshInstance3D = found_mods[key]
			var painted_mat := StandardMaterial3D.new()
			painted_mat.vertex_color_use_as_albedo = true
			painted_mat.roughness = 0.24
			painted_mat.metallic_specular = 0.65
			module_nodes.append(mi)
			module_orig_mats.append(painted_mat)
			mi.material_override = painted_mat if i < painted_count else gray_mat
			module_pop_t[i] = 1.0 if i < painted_count else 0.0
	if found_mods.has("IslandBase"):
		var bmi: MeshInstance3D = found_mods["IslandBase"]
		var base_m := StandardMaterial3D.new()
		base_m.vertex_color_use_as_albedo = true
		base_m.roughness = 0.38
		bmi.material_override = base_m if painted_count > 0 else gray_mat


func _collect_island_meshes(n: Node, out: Dictionary) -> void:
	if n is MeshInstance3D:
		out[n.name] = n
	for c in n.get_children():
		_collect_island_meshes(c, out)


func _can_paint_now() -> bool:
	return painted_count < 5 and (free_ftue_paint or available_energy >= ENERGY_PER_PAINT)


func _refresh_ui() -> void:
	var ch_info: Dictionary = FusePalette.ISLAND_CHAPTERS[chapter_idx]
	var mods: Array = ch_info["modules"]
	lbl_title.text = "%s · %s (%d/5)" % [String(ch_info["subtitle"]), String(ch_info["name"]), painted_count]
	energy_bar.value = ENERGY_PER_PAINT if free_ftue_paint else mini(ENERGY_PER_PAINT, available_energy)

	if painted_count >= 5:
		lbl_sub.text = "本章节全部 5 座 3D 地标已点亮！可切换至下一章继续建造"
		btn_spray.visible = false
	elif _can_paint_now():
		var next_name: String = String(mods[painted_count])
		lbl_sub.text = "能量已满！长按 2 秒用彩漆炮点亮【%s】" % next_name
		btn_spray.visible = true
		btn_spray.disabled = false
		btn_spray.text = "🎨 按住 2 秒 · 喷涂点亮【%s】" % next_name
	else:
		lbl_sub.text = "当前涂装能量 %d / %d（每通关 +100，庆典关 +150）" % [available_energy, ENERGY_PER_PAINT]
		btn_spray.visible = false


func _on_spray_down() -> void:
	if not _can_paint_now():
		return
	is_spraying = true
	if audio:
		audio.play_island_spray(painted_count)


func _process(delta: float) -> void:
	if not visible:
		return
	anim_clock += delta
	island_pivot.rotation.y += delta * (0.95 if is_spraying else 0.36)
	island_pivot.position.y = sin(anim_clock * 2.0) * 0.14

	# Animate 3D module pop bounce
	for i in range(mini(5, module_nodes.size())):
		if module_pop_t[i] > 0.0 and module_pop_t[i] < 1.0:
			module_pop_t[i] = minf(1.0, module_pop_t[i] + delta * 3.0)
			var b: float = 1.0 + sin(module_pop_t[i] * PI) * 0.32
			module_nodes[i].scale = Vector3(b, b, b)
		elif module_pop_t[i] >= 1.0:
			module_nodes[i].scale = Vector3.ONE

	if is_spraying and _can_paint_now():
		spray_progress += delta / 1.75
		if randf() < 0.78:
			var sz: Vector2 = spray_overlay.size
			paint_drops.append({
				"start": Vector2(sz.x * 0.5, sz.y - 18.0),
				"end": Vector2(sz.x * 0.5 + randf_range(-110, 110), sz.y * 0.45 + randf_range(-70, 50)),
				"t": 0.0,
				"dur": randf_range(0.20, 0.34),
				"col": FusePalette.get_color(randi_range(1, 6)),
				"rad": randf_range(6.0, 11.0),
			})
		if int(spray_progress * 9.0) > int((spray_progress - delta / 1.75) * 9.0):
			if audio:
				audio.play_island_spray(int(spray_progress * 9.0))
		btn_spray.text = "🎨 能量喷涂中 %d%%..." % mini(100, int(spray_progress * 100.0))

		if spray_progress >= 1.0:
			spray_progress = 0.0
			is_spraying = false
			if free_ftue_paint:
				free_ftue_paint = false
			else:
				available_energy = maxi(0, available_energy - ENERGY_PER_PAINT)
				services.island_energy = available_energy

			var newly_painted: int = painted_count
			painted_count = mini(5, painted_count + 1)
			services.island_modules_painted[chapter_idx] = painted_count

			if newly_painted < module_nodes.size():
				(module_nodes[newly_painted] as MeshInstance3D).material_override = module_orig_mats[newly_painted]
				module_pop_t[newly_painted] = 0.01

			var completed_island: bool = (painted_count >= 5)
			var rew: int = 300 if completed_island else 150
			services.coins += rew
			if completed_island:
				services.grant_infinite_stamina(30)
				lbl_chest.text = "🎁 整座浮空岛点亮完成！宝箱奖励：+300 金币 + 30 分钟 ∞ 无限体力！"
			else:
				lbl_chest.text = "✨ 地标点亮成功！开启节点宝箱：+150 金币！"
			chest_panel.visible = true
			if audio:
				audio.play_victory()
				audio.play_coin_clink()

			services.log_event("island_paint_complete", {
				"chapter_id": chapter_idx + 1,
				"node_index": newly_painted,
				"total_coins_rewarded": rew,
			})
			services.save_state()
			module_painted.emit(chapter_idx, newly_painted, rew, completed_island)
			_refresh_ui()
	elif spray_progress > 0.0:
		spray_progress = maxf(0.0, spray_progress - delta * 1.5)

	for i in range(paint_drops.size() - 1, -1, -1):
		paint_drops[i]["t"] = float(paint_drops[i]["t"]) + delta
		if float(paint_drops[i]["t"]) >= float(paint_drops[i]["dur"]):
			paint_drops.remove_at(i)
	spray_overlay.queue_redraw()


func _draw_spray_overlay() -> void:
	for d in paint_drops:
		var u: float = clampf(float(d["t"]) / float(d["dur"]), 0.0, 1.0)
		var p: Vector2 = (d["start"] as Vector2).lerp(d["end"] as Vector2, u)
		p.y -= sin(u * PI) * 44.0
		spray_overlay.draw_circle(p, float(d["rad"]) * (1.0 - u * 0.35), d["col"])


func _style_btn(btn: Button, bg: Color, fg: Color, radius: int, fsz: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.06, 0.09, 0.16, 0.10)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.set_content_margin_all(10)
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
