class_name VoxelStage
extends Node3D

## High-Density .vox MultiMesh Stage (Up to 900+ Cubes @ 60fps Mobile/WebGL2)
## Features CC0 Porcelain/Jelly/Crystal MatCaps + Poly Haven Walnut PBR + Screen Refraction,
## 5 Columns × Deep Mystery Queue, Heavy Cannon Slot-Occupation Pinch, and 150+ Cube Timber Collapse!

signal stats_changed(remaining_voxels: int, total_voxels: int, combo: int, overdrive_ratio: float, overdrive_unlocked: bool)
signal callout_triggered(text: String, accent_color: Color, world_pos: Vector3)
signal coins_earned(amount: int, reason: String)
signal level_completed(summary: Dictionary)
signal slots_jammed()
signal state_updated()

const MAX_MAIN_SLOTS: int = 5
const TOTAL_SLOTS: int = 6
const NUM_COLS: int = 5
const VISIBLE_ROWS: int = 3
const SHARD_POOL_SIZE: int = 120
const FALLING_POOL_SIZE: int = 180

const SLOT_LOCAL_X: Array[float] = [-2.55, -1.53, -0.51, 0.51, 1.53, 2.55]
const COL_LOCAL_X: Array[float] = [-2.16, -1.08, 0.0, 1.08, 2.16]

var voxel_step: float = 0.34
var audio: AsmrAudio
var camera: Camera3D

var turntable_pivot: Node3D
var voxel_root: Node3D
var keepsake_holder: Node3D
var keepsake_light: OmniLight3D
var fx_root: Node3D
var arena_tray: Node3D

var mat_shaders: Array[ShaderMaterial] = []
var mat_brass_lock: StandardMaterial3D
var mat_overdrive_gold: StandardMaterial3D
var mat_cream_cup: StandardMaterial3D

var multi_meshes: Array[MultiMeshInstance3D] = []
var lock_multimesh: MultiMeshInstance3D
var voxel_meshes: Array[Mesh] = []
var lock_mesh: Mesh

var scn_turntable: PackedScene
var scn_blaster: PackedScene
var scn_slot_cup: PackedScene

var current_level_data: Dictionary = {}
var voxels: Dictionary = {}
var exposed_cache: Dictionary = {}
var reserved_targets: Dictionary = {}
var total_voxel_count: int = 0
var collapse_bonus_coins: int = 0
var total_collapsed_blocks: int = 0
var max_combo_reached: int = 0

var combo_count: int = 0
var combo_timer: float = 0.0
var slot_clear_streak: int = 0
var overdrive_charge: float = 0.0
var overdrive_unlocked: bool = false
var show_symbols: bool = false

var yaw: float = 0.62
var yaw_vel: float = 0.0
var pitch_offset: float = 0.0
var is_dragging_orbit: bool = false
var auto_scan_idle_timer: float = 0.0
var hit_shake: float = 0.0
var hitstop_timer: float = 0.0
var celebrating_win: bool = false
var stage_active: bool = true

var slot_cups: Array[Node3D] = []
var slots: Array = []
var columns: Array = [[], [], [], [], []]
var col_visual_nodes: Array = [[], [], [], [], []]

var projectiles: Array[Dictionary] = []
var falling_blocks: Array[Dictionary] = []
var falling_pool: Array[MeshInstance3D] = []
var falling_cursor: int = 0
var shard_pool: Array[Dictionary] = []
var shard_cursor: int = 0
var active_rings: Array[Dictionary] = []
var active_beams: Array[Dictionary] = []
var jam_check_delay: float = 0.0
var multimesh_dirty: bool = false


func setup(p_camera: Camera3D, p_audio: AsmrAudio) -> void:
	camera = p_camera
	audio = p_audio
	_init_materials_and_meshes()
	_build_stage_hierarchy()
	_init_pools()


func _init_materials_and_meshes() -> void:
	var tex_env: Texture2D = load("res://assets/textures/studio_hdri_pano.jpg")
	var tex_mc_porcelain: Texture2D = load("res://assets/textures/matcap_porcelain.png")
	var tex_mc_jelly: Texture2D = load("res://assets/textures/matcap_jelly.png")
	var tex_mc_crystal: Texture2D = load("res://assets/textures/matcap_crystal.png")
	var tex_w_alb: Texture2D = load("res://assets/textures/walnut_albedo.jpg")
	var tex_w_nrm: Texture2D = load("res://assets/textures/walnut_normal.jpg")
	var tex_w_rgh: Texture2D = load("res://assets/textures/walnut_rough.jpg")

	var sm_ceramic := ShaderMaterial.new()
	sm_ceramic.shader = preload("res://shaders/ceramic_glaze.gdshader")
	sm_ceramic.set_shader_parameter("u_matcap_porcelain", tex_mc_porcelain)
	sm_ceramic.set_shader_parameter("u_studio_env", tex_env)

	var sm_jelly := ShaderMaterial.new()
	sm_jelly.shader = preload("res://shaders/soft_jelly.gdshader")
	sm_jelly.set_shader_parameter("u_matcap_jelly", tex_mc_jelly)
	sm_jelly.set_shader_parameter("u_studio_env", tex_env)

	var sm_crystal := ShaderMaterial.new()
	sm_crystal.shader = preload("res://shaders/faceted_crystal.gdshader")
	sm_crystal.set_shader_parameter("u_matcap_crystal", tex_mc_crystal)
	sm_crystal.set_shader_parameter("u_studio_env", tex_env)

	var sm_wood := ShaderMaterial.new()
	sm_wood.shader = preload("res://shaders/warm_wood.gdshader")
	sm_wood.set_shader_parameter("u_wood_albedo", tex_w_alb)
	sm_wood.set_shader_parameter("u_wood_normal", tex_w_nrm)
	sm_wood.set_shader_parameter("u_wood_rough", tex_w_rgh)
	sm_wood.set_shader_parameter("u_studio_env", tex_env)

	mat_shaders = [sm_ceramic, sm_jelly, sm_crystal, sm_wood]

	mat_brass_lock = StandardMaterial3D.new()
	mat_brass_lock.albedo_color = Color(0.92, 0.73, 0.28)
	mat_brass_lock.metallic = 0.90
	mat_brass_lock.roughness = 0.20

	mat_overdrive_gold = StandardMaterial3D.new()
	mat_overdrive_gold.albedo_color = Color(0.98, 0.80, 0.32)
	mat_overdrive_gold.metallic = 0.85
	mat_overdrive_gold.roughness = 0.18
	mat_overdrive_gold.emission_enabled = true
	mat_overdrive_gold.emission = Color(0.95, 0.68, 0.18)
	mat_overdrive_gold.emission_energy_multiplier = 0.25

	mat_cream_cup = StandardMaterial3D.new()
	mat_cream_cup.albedo_color = Color(0.86, 0.82, 0.75)
	mat_cream_cup.roughness = 0.34

	var glb_paths: Array[String] = [
		"res://assets/models/voxel_ceramic.glb",
		"res://assets/models/voxel_jelly.glb",
		"res://assets/models/voxel_crystal.glb",
		"res://assets/models/voxel_wood.glb",
	]
	for path in glb_paths:
		var ps: PackedScene = load(path)
		voxel_meshes.append(_extract_first_mesh(ps))
	lock_mesh = _extract_first_mesh(load("res://assets/models/voxel_lock_cage.glb"))
	scn_turntable = load("res://assets/models/studio_turntable.glb")
	scn_blaster = load("res://assets/models/blaster_pawn.glb")
	scn_slot_cup = load("res://assets/models/slot_cup.glb")


func _extract_first_mesh(ps: PackedScene) -> Mesh:
	var inst: Node = ps.instantiate()
	var found: Mesh = _find_mesh_recursive(inst)
	inst.free()
	return found


func _find_mesh_recursive(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		return (n as MeshInstance3D).mesh
	for c in n.get_children():
		var m: Mesh = _find_mesh_recursive(c)
		if m != null:
			return m
	return null


func _build_stage_hierarchy() -> void:
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.85, 0.825, 0.79)
	bg_mat.roughness = 0.95

	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	backdrop.mesh = plane
	backdrop.position = Vector3(0.0, -4.2, -2.0)
	backdrop.material_override = bg_mat
	add_child(backdrop)

	var rear_wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(90.0, 48.0, 0.5)
	rear_wall.mesh = wall_mesh
	rear_wall.position = Vector3(0.0, 12.0, -14.0)
	rear_wall.material_override = bg_mat
	add_child(rear_wall)

	turntable_pivot = Node3D.new()
	turntable_pivot.name = "TurntablePivot"
	turntable_pivot.position = Vector3(0.0, 1.36, -0.35)
	add_child(turntable_pivot)

	var shadow_disc := MeshInstance3D.new()
	var s_cyl := CylinderMesh.new()
	s_cyl.top_radius = 3.35
	s_cyl.bottom_radius = 3.35
	s_cyl.height = 0.04
	shadow_disc.mesh = s_cyl
	shadow_disc.position = Vector3(0.0, 0.62, -0.35)
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.66, 0.62, 0.56)
	s_mat.roughness = 0.95
	shadow_disc.material_override = s_mat
	add_child(shadow_disc)

	var tt_inst: Node3D = scn_turntable.instantiate()
	tt_inst.scale = Vector3(0.56, 0.56, 0.56)
	var tt_ceramic := StandardMaterial3D.new()
	tt_ceramic.albedo_color = Color(0.86, 0.83, 0.78)
	tt_ceramic.roughness = 0.32
	_override_turntable_top(tt_inst, tt_ceramic)
	turntable_pivot.add_child(tt_inst)

	voxel_root = Node3D.new()
	voxel_root.name = "VoxelRoot"
	turntable_pivot.add_child(voxel_root)

	for m_idx in range(4):
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MultiMesh_Mat_%d" % m_idx
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = voxel_meshes[m_idx]
		mmi.multimesh = mm
		mmi.material_override = mat_shaders[m_idx]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		voxel_root.add_child(mmi)
		multi_meshes.append(mmi)

	lock_multimesh = MultiMeshInstance3D.new()
	var lmm := MultiMesh.new()
	lmm.transform_format = MultiMesh.TRANSFORM_3D
	lmm.mesh = lock_mesh
	lock_multimesh.multimesh = lmm
	lock_multimesh.material_override = mat_brass_lock
	voxel_root.add_child(lock_multimesh)

	keepsake_holder = Node3D.new()
	keepsake_holder.position = Vector3(0.0, 0.02, 0.0)
	turntable_pivot.add_child(keepsake_holder)

	keepsake_light = OmniLight3D.new()
	keepsake_light.position = Vector3(0.0, 0.85, 0.0)
	keepsake_light.light_color = Color(1.0, 0.86, 0.52)
	keepsake_light.light_energy = 1.25
	keepsake_light.omni_range = 3.2
	turntable_pivot.add_child(keepsake_light)

	fx_root = Node3D.new()
	fx_root.name = "FXRoot"
	add_child(fx_root)

	# 5+1 Slot Tray + 5 Launcher Columns
	arena_tray = Node3D.new()
	arena_tray.name = "ArenaTray"
	arena_tray.position = Vector3(0.0, -1.72, 2.05)
	arena_tray.rotation_degrees = Vector3(24.0, 0.0, 0.0)
	add_child(arena_tray)

	var tray_bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.55, 0.24, 1.28)
	tray_bar.mesh = box
	tray_bar.position = Vector3(0.0, 0.58, -0.78)
	var oak_tray_mat := StandardMaterial3D.new()
	oak_tray_mat.albedo_texture = load("res://assets/textures/walnut_albedo.jpg")
	oak_tray_mat.albedo_color = Color(0.88, 0.74, 0.58)
	oak_tray_mat.roughness = 0.44
	tray_bar.material_override = oak_tray_mat
	arena_tray.add_child(tray_bar)

	var well_mat := StandardMaterial3D.new()
	well_mat.albedo_color = Color(0.28, 0.23, 0.19)
	well_mat.roughness = 0.85

	slots.resize(TOTAL_SLOTS)
	for i in range(TOTAL_SLOTS):
		slots[i] = null
		var cup: Node3D = scn_slot_cup.instantiate()
		cup.position = Vector3(SLOT_LOCAL_X[i], 0.70, -0.78)
		cup.scale = Vector3(0.80, 0.85, 0.80)
		if i == 5:
			_override_mesh_materials(cup, mat_overdrive_gold)
		else:
			_override_mesh_materials(cup, mat_cream_cup)
		arena_tray.add_child(cup)
		slot_cups.append(cup)

		var well := MeshInstance3D.new()
		var wc := CylinderMesh.new()
		wc.top_radius = 0.32
		wc.bottom_radius = 0.30
		wc.height = 0.05
		well.mesh = wc
		well.position = Vector3(SLOT_LOCAL_X[i], 0.94, -0.78)
		well.material_override = well_mat
		arena_tray.add_child(well)


func _init_pools() -> void:
	var shard_box := BoxMesh.new()
	shard_box.size = Vector3(0.18, 0.14, 0.18)
	for i in range(SHARD_POOL_SIZE):
		var mi := MeshInstance3D.new()
		mi.mesh = shard_box
		mi.visible = false
		var sm := StandardMaterial3D.new()
		sm.roughness = 0.22
		mi.material_override = sm
		fx_root.add_child(mi)
		shard_pool.append({
			"node": mi,
			"mat": sm,
			"vel": Vector3.ZERO,
			"rot_vel": Vector3.ZERO,
			"life": 0.0,
			"active": false,
		})

	for i in range(FALLING_POOL_SIZE):
		var fmi := MeshInstance3D.new()
		fmi.visible = false
		var fsm := StandardMaterial3D.new()
		fsm.roughness = 0.28
		fmi.material_override = fsm
		fx_root.add_child(fmi)
		falling_pool.append(fmi)


func set_symbol_mode(enabled: bool) -> void:
	show_symbols = enabled
	var val: float = 1.0 if enabled else 0.0
	for sm in mat_shaders:
		sm.set_shader_parameter("u_show_symbols", val)


func load_level(level_num: int) -> void:
	_clear_transient_state()
	current_level_data = SculptureCatalog.build_level(level_num)
	voxel_step = float(current_level_data.get("voxel_step", 0.34))
	celebrating_win = false
	yaw = 0.62
	yaw_vel = 0.0
	pitch_offset = 0.0
	combo_count = 0
	combo_timer = 0.0
	slot_clear_streak = 0
	overdrive_charge = 0.0
	overdrive_unlocked = false
	collapse_bonus_coins = 0
	total_collapsed_blocks = 0
	max_combo_reached = 0
	jam_check_delay = 0.0

	_update_overdrive_cup_visual()

	var src_voxels: Dictionary = current_level_data["voxels"]
	for pos: Vector3i in src_voxels.keys():
		var d: Dictionary = src_voxels[pos]
		voxels[pos] = {
			"ch": int(d["ch"]),
			"locked": bool(d["locked"]),
			"hit_t": -10.0,
			"ao": 1.0,
		}
	total_voxel_count = voxels.size()

	for c in keepsake_holder.get_children():
		c.queue_free()
	var keep_info: Dictionary = current_level_data["keepsake"]
	var keep_scn: PackedScene = load(String(keep_info["scene_path"]))
	if keep_scn:
		var k_inst: Node3D = keep_scn.instantiate()
		k_inst.scale = Vector3(0.75, 0.75, 0.75)
		keepsake_holder.add_child(k_inst)

	var diff_m: int = int(current_level_data.get("diff_mode", SculptureCatalog.DiffMode.TACTICAL))
	columns = VoxelSolver.generate_verified_columns(src_voxels, level_num, diff_m)
	_rebuild_column_visuals()
	_recompute_exposure_and_ao()
	_rebuild_multimeshes()
	_emit_stats()
	state_updated.emit()


func _clear_transient_state() -> void:
	voxels.clear()
	exposed_cache.clear()
	reserved_targets.clear()
	for i in range(TOTAL_SLOTS):
		if slots[i] != null and is_instance_valid(slots[i]["node"]):
			slots[i]["node"].queue_free()
		slots[i] = null
	for c in range(NUM_COLS):
		for n in col_visual_nodes[c]:
			if is_instance_valid(n):
				n.queue_free()
		col_visual_nodes[c].clear()
	for p in projectiles:
		if is_instance_valid(p["node"]):
			p["node"].queue_free()
	projectiles.clear()
	for fb in falling_blocks:
		fb["node"].visible = false
	falling_blocks.clear()
	for sh in shard_pool:
		sh["active"] = false
		sh["node"].visible = false
	for r in active_rings:
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
	active_rings.clear()
	for b in active_beams:
		if is_instance_valid(b["node"]):
			b["node"].queue_free()
	active_beams.clear()


func _process(delta: float) -> void:
	if not stage_active:
		return

	var now_sec: float = Time.get_ticks_msec() * 0.001
	for sm in mat_shaders:
		sm.set_shader_parameter("u_clock", now_sec)

	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		delta *= 0.22

	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			_emit_stats()

	if celebrating_win:
		yaw += delta * 1.45
		if keepsake_holder.get_child_count() > 0:
			keepsake_holder.position.y = lerpf(keepsake_holder.position.y, 0.35, delta * 4.0)
			keepsake_holder.scale = keepsake_holder.scale.lerp(Vector3(1.55, 1.55, 1.55), delta * 4.0)
			keepsake_light.light_energy = lerpf(keepsake_light.light_energy, 3.0, delta * 4.0)
	else:
		keepsake_holder.position.y = 0.02 + sin(now_sec * 2.4) * 0.03
		keepsake_holder.scale = Vector3.ONE
		keepsake_holder.rotation.y = -yaw * 0.35 + sin(now_sec * 1.5) * 0.25
		keepsake_light.light_energy = 1.25
		if not is_dragging_orbit:
			yaw += yaw_vel * delta
			yaw_vel = lerpf(yaw_vel, 0.0, clampf(delta * 6.5, 0.0, 1.0))
			pitch_offset = lerpf(pitch_offset, 0.0, clampf(delta * 4.5, 0.0, 1.0))
			auto_scan_idle_timer += delta
		else:
			auto_scan_idle_timer = 0.0

	turntable_pivot.rotation = Vector3(pitch_offset, yaw, 0.0)

	_update_camera_framing(delta)
	_process_active_slots(delta)
	_process_projectiles(delta)
	_process_falling_blocks(delta)
	_process_shards_and_fx(delta)

	if multimesh_dirty:
		multimesh_dirty = false
		_rebuild_multimeshes()

	if not celebrating_win and projectiles.is_empty() and falling_blocks.is_empty():
		if _are_all_available_slots_jammed():
			jam_check_delay += delta
			if jam_check_delay > 0.45:
				jam_check_delay = -999.0
				slots_jammed.emit()
		else:
			jam_check_delay = 0.0


func _update_camera_framing(delta: float) -> void:
	if camera == null:
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = vp_size.x / maxf(vp_size.y, 1.0)
	var fov_deg: float = 34.0
	camera.fov = fov_deg
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

	var half_tan_y: float = tan(deg_to_rad(fov_deg * 0.5))
	var half_tan_x: float = half_tan_y * aspect
	var needed_dist_for_width: float = 3.75 / maxf(half_tan_x, 0.11)
	var base_dist: float = maxf(24.2, needed_dist_for_width + 2.5)
	if celebrating_win:
		base_dist *= 0.62

	var target_look := Vector3(0.0, 1.85 if celebrating_win else 0.72, 0.25)
	var cam_dir := Vector3(0.0, 0.39 if not celebrating_win else 0.28, 1.0).normalized()
	var desired_pos: Vector3 = target_look + cam_dir * base_dist

	if hit_shake > 0.001:
		hit_shake = maxf(0.0, hit_shake - delta * 3.0)
		desired_pos += Vector3(
			randf_range(-1.0, 1.0) * hit_shake,
			randf_range(-1.0, 1.0) * hit_shake,
			0.0
		)

	camera.global_position = camera.global_position.lerp(desired_pos, clampf(delta * 9.0, 0.0, 1.0))
	camera.look_at(target_look, Vector3.UP)


func apply_orbit_drag(relative: Vector2) -> void:
	is_dragging_orbit = true
	yaw += relative.x * 0.011
	yaw_vel = clampf(relative.x * 0.42, -7.5, 7.5)
	pitch_offset = clampf(pitch_offset + relative.y * 0.0035, -0.14, 0.22)


func end_orbit_drag() -> void:
	is_dragging_orbit = false


func try_pick_column(col_idx: int) -> bool:
	if celebrating_win or col_idx < 0 or col_idx >= NUM_COLS:
		return false
	if columns[col_idx].is_empty():
		return false

	var free_slot: int = _find_free_slot()
	if free_slot == -1:
		hit_shake = 0.11
		callout_triggered.emit("★ 5槽已满！快用底部【碎柱重锤】或【磁吸清槽】破局！", Color(0.95, 0.36, 0.28), arena_tray.global_position)
		slots_jammed.emit()
		return false

	var item: Dictionary = columns[col_idx].pop_front()
	var ch: int = int(item["ch"])
	var ammo: int = int(item["ammo"])

	var pawn_node: Node3D
	if not col_visual_nodes[col_idx].is_empty():
		pawn_node = col_visual_nodes[col_idx].pop_front()
	else:
		pawn_node = _create_blaster_pawn(ch, false)
		arena_tray.add_child(pawn_node)

	var target_local := Vector3(SLOT_LOCAL_X[free_slot], 0.86, -0.78)
	var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(pawn_node, "position", target_local, 0.16)
	pawn_node.scale = Vector3(1.08, 0.80, 1.08)
	var tw_s := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw_s.tween_property(pawn_node, "scale", Vector3(0.90, 0.90, 0.90), 0.26)

	slots[free_slot] = {
		"ch": ch,
		"ammo": ammo,
		"node": pawn_node,
		"cooldown": 0.04,
		"recoil": 0.0,
	}
	audio.play_slot_place()
	_rebuild_column_visuals(true)
	jam_check_delay = 0.0

	_retire_surplus_launchers_for_channel(ch)
	state_updated.emit()
	return true


func _find_free_slot() -> int:
	var limit: int = TOTAL_SLOTS if overdrive_unlocked else MAX_MAIN_SLOTS
	for i in range(limit):
		if slots[i] == null:
			return i
	return -1


func get_occupied_jammed_count() -> int:
	var limit: int = TOTAL_SLOTS if overdrive_unlocked else MAX_MAIN_SLOTS
	var cnt: int = 0
	for i in range(limit):
		if slots[i] != null and _pick_best_exposed_target(int(slots[i]["ch"])).is_empty():
			cnt += 1
	return cnt


func _process_active_slots(delta: float) -> void:
	if celebrating_win or voxels.is_empty():
		return

	var limit: int = TOTAL_SLOTS if overdrive_unlocked else MAX_MAIN_SLOTS
	var any_backside_target_yaw: float = INF
	var fire_interval: float = 0.055 if total_voxel_count > 300 else 0.085

	for s_idx in range(limit):
		var sl = slots[s_idx]
		if sl == null:
			continue
		var pawn: Node3D = sl["node"]
		if is_instance_valid(pawn):
			sl["recoil"] = lerpf(float(sl["recoil"]), 0.0, clampf(delta * 18.0, 0.0, 1.0))
			pawn.position.y = 0.86 - float(sl["recoil"])

		var s_ch: int = int(sl["ch"])
		if _count_remaining_channel(s_ch, false) == 0 and not _has_inflight_for_channel(s_ch):
			_retire_slot(s_idx, true)
			continue

		sl["cooldown"] = float(sl["cooldown"]) - delta
		if float(sl["cooldown"]) > 0.0 or int(sl["ammo"]) <= 0:
			continue

		var target_info: Dictionary = _pick_best_exposed_target(s_ch)
		if target_info.is_empty():
			continue

		var t_pos: Vector3i = target_info["pos"]
		if float(target_info["facing"]) < -0.15:
			any_backside_target_yaw = float(target_info["ideal_yaw"])

		reserved_targets[t_pos] = true
		sl["ammo"] = int(sl["ammo"]) - 1
		sl["cooldown"] = fire_interval
		sl["recoil"] = 0.13

		if is_instance_valid(pawn):
			var w_target: Vector3 = _grid_to_world(t_pos)
			var dir_flat: Vector3 = w_target - pawn.global_position
			pawn.rotation.y = clampf(atan2(-dir_flat.x, -dir_flat.z), -0.65, 0.65)

		_spawn_projectile(pawn.global_position + Vector3(0, 0.50, 0), t_pos, s_ch)
		audio.play_shoot()
		state_updated.emit()

		if int(sl["ammo"]) <= 0:
			_retire_slot(s_idx, true)

	if not is_dragging_orbit and auto_scan_idle_timer > 0.45 and any_backside_target_yaw != INF:
		var diff: float = wrapf(any_backside_target_yaw - yaw, -PI, PI)
		yaw += clampf(diff * 2.8, -2.6, 2.6) * delta


func _pick_best_exposed_target(ch: int) -> Dictionary:
	var best_pos := Vector3i.ZERO
	var best_score: float = -1e9
	var best_facing: float = 0.0
	var best_ideal_yaw: float = 0.0
	var found: bool = false

	var cam_fwd_xz := Vector2(0.0, 1.0)
	for pos: Vector3i in exposed_cache.keys():
		if reserved_targets.has(pos) or not voxels.has(pos):
			continue
		var d: Dictionary = voxels[pos]
		if int(d["ch"]) != ch or bool(d["locked"]):
			continue

		var local_xz := Vector2(float(pos.x), float(pos.z))
		var rot_x: float = local_xz.x * cos(yaw) + local_xz.y * sin(yaw)
		var rot_z: float = -local_xz.x * sin(yaw) + local_xz.y * cos(yaw)
		var norm_xz: Vector2 = Vector2(rot_x, rot_z).normalized() if local_xz.length_squared() > 0.01 else Vector2(0, 1)
		var facing: float = norm_xz.dot(cam_fwd_xz)

		var pillar_bonus: float = (5.0 - float(pos.y)) * 0.25 if ch == 3 else float(pos.y) * 0.04
		var score: float = facing * 3.5 + pillar_bonus
		if score > best_score:
			best_score = score
			best_pos = pos
			best_facing = facing
			best_ideal_yaw = atan2(local_xz.x, local_xz.y)
			found = true

	if not found:
		return {}
	return {"pos": best_pos, "facing": best_facing, "ideal_yaw": best_ideal_yaw}


func _spawn_projectile(start_world: Vector3, target_grid: Vector3i, ch: int) -> void:
	var bead := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.13
	sph.height = 0.26
	sph.radial_segments = 10
	sph.rings = 5
	bead.mesh = sph
	var sm := StandardMaterial3D.new()
	var col: Color = SculptureCatalog.CHANNELS[ch]["color"]
	sm.albedo_color = col.lightened(0.20)
	sm.emission_enabled = true
	sm.emission = col
	sm.emission_energy_multiplier = 0.55
	sm.roughness = 0.15
	bead.material_override = sm
	fx_root.add_child(bead)
	bead.global_position = start_world

	projectiles.append({
		"node": bead,
		"start": start_world,
		"target_grid": target_grid,
		"ch": ch,
		"t": 0.0,
		"dur": 0.125,
	})


func _process_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["t"] = float(p["t"]) + delta
		var u: float = clampf(float(p["t"]) / float(p["dur"]), 0.0, 1.0)
		var target_w: Vector3 = _grid_to_world(p["target_grid"])
		var mid: Vector3 = (Vector3(p["start"]) + target_w) * 0.5 + Vector3(0.0, 1.2, 0.7)
		var pos_now: Vector3 = Vector3(p["start"]).lerp(mid, u).lerp(mid.lerp(target_w, u), u)
		if is_instance_valid(p["node"]):
			p["node"].global_position = pos_now
		if u >= 1.0:
			if is_instance_valid(p["node"]):
				p["node"].queue_free()
			var tg: Vector3i = p["target_grid"]
			var ch: int = int(p["ch"])
			projectiles.remove_at(i)
			reserved_targets.erase(tg)
			_destroy_voxel(tg, true)
			_retire_surplus_launchers_for_channel(ch)


func _destroy_voxel(pos: Vector3i, allow_material_chain: bool, defer_rebuild: bool = false) -> void:
	if not voxels.has(pos):
		return
	var data: Dictionary = voxels[pos]
	var ch: int = int(data["ch"])
	var ch_info: Dictionary = SculptureCatalog.CHANNELS[ch]
	var mat_type: int = int(ch_info["mat"])
	var col: Color = ch_info["color"]
	var world_pos: Vector3 = _grid_to_world(pos)

	voxels.erase(pos)
	reserved_targets.erase(pos)

	combo_count += 1
	max_combo_reached = maxi(max_combo_reached, combo_count)
	combo_timer = 1.6
	audio.play_voxel_pop(mat_type, combo_count - 1)
	_spawn_shatter_shards(world_pos, col, 3 if defer_rebuild else 4)
	if not defer_rebuild:
		_jostle_neighbors(pos, 1)

	if allow_material_chain and mat_type == SculptureCatalog.MatType.JELLY:
		_spawn_shockwave_ring(world_pos, col, 1.6)
		_jostle_neighbors(pos, 2)
		var unlocked_any: int = 0
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					var nb := pos + Vector3i(dx, dy, dz)
					if voxels.has(nb) and bool(voxels[nb]["locked"]):
						voxels[nb]["locked"] = false
						unlocked_any += 1
						_spawn_shatter_shards(_grid_to_world(nb), Color(0.95, 0.78, 0.30), 3)
		if unlocked_any > 0:
			audio.play_jelly_unlock()
			_add_overdrive_charge(0.14 * float(unlocked_any))
			callout_triggered.emit("果冻弹性共振 · 震开 %d 枚黄铜锁！" % unlocked_any, Color(0.96, 0.48, 0.36), world_pos)

	if allow_material_chain and mat_type == SculptureCatalog.MatType.CRYSTAL:
		var refract_target: Vector3i = _find_crystal_refract_target(pos)
		if refract_target != Vector3i(999, 999, 999):
			var target_w: Vector3 = _grid_to_world(refract_target)
			_spawn_prism_beam(world_pos, target_w)
			audio.play_crystal_refract()
			var inner_ch: int = int(voxels[refract_target]["ch"])
			voxels[refract_target]["locked"] = false
			_destroy_voxel(refract_target, false, true)
			_retire_surplus_launchers_for_channel(inner_ch)
			callout_triggered.emit("◆ 冰晶折射穿透 +1", Color(0.32, 0.76, 0.98), target_w)

	if not defer_rebuild:
		_auto_slip_isolated_locks()
		if allow_material_chain:
			_check_and_trigger_timber_collapse()
		_recompute_exposure_and_ao()
		multimesh_dirty = true
		_emit_stats()
		if voxels.is_empty() and not celebrating_win:
			_trigger_level_victory()


func _find_crystal_refract_target(from_pos: Vector3i) -> Vector3i:
	const DIRS6: Array[Vector3i] = [
		Vector3i(-1,0,0), Vector3i(1,0,0),
		Vector3i(0,0,-1), Vector3i(0,0,1),
		Vector3i(0,-1,0), Vector3i(0,1,0),
	]
	var best := Vector3i(999, 999, 999)
	var best_dist_center: float = 9999.0
	for d in DIRS6:
		var nb: Vector3i = from_pos + d
		if voxels.has(nb) and not reserved_targets.has(nb):
			var dist_c: float = Vector2(float(nb.x), float(nb.z)).length()
			if dist_c < best_dist_center:
				best_dist_center = dist_c
				best = nb
	return best


func _auto_slip_isolated_locks() -> void:
	const DIRS6: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]
	for p: Vector3i in voxels.keys():
		if bool(voxels[p]["locked"]):
			var empty_sides: int = 0
			for d in DIRS6:
				if not voxels.has(p + d) and (p + d).y >= 0:
					empty_sides += 1
			if empty_sides >= 5:
				voxels[p]["locked"] = false


func _check_and_trigger_timber_collapse() -> int:
	if voxels.is_empty():
		return 0
	var grounded: Dictionary = {}
	var queue: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if p.y == 0:
			grounded[p] = true
			queue.append(p)

	const DIRS6: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]
	var head: int = 0
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		for d in DIRS6:
			var nb: Vector3i = cur + d
			if voxels.has(nb) and not grounded.has(nb):
				grounded[nb] = true
				queue.append(nb)

	var unsupported: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if not grounded.has(p):
			unsupported.append(p)

	if unsupported.is_empty():
		return 0

	var affected_channels: Dictionary = {}
	var center_accum := Vector3.ZERO
	var visual_cap: int = 0
	for p in unsupported:
		var d: Dictionary = voxels[p]
		var ch: int = int(d["ch"])
		affected_channels[ch] = true
		var w_pos: Vector3 = _grid_to_world(p)
		center_accum += w_pos
		if visual_cap < FALLING_POOL_SIZE:
			_spawn_falling_collapse_block(w_pos, ch)
			visual_cap += 1
		voxels.erase(p)
		reserved_targets.erase(p)

	var count: int = unsupported.size()
	total_collapsed_blocks += count
	var bonus_coins: int = maxi(5, int(ceil(float(count) * 0.55)))
	collapse_bonus_coins += bonus_coins
	combo_count += count
	max_combo_reached = maxi(max_combo_reached, combo_count)
	combo_timer = 2.0

	hitstop_timer = 0.075 if count >= 20 else 0.03
	hit_shake = clampf(0.10 + float(count) * 0.004, 0.10, 0.34)
	audio.play_timber_collapse()
	var is_pinch: bool = int(current_level_data.get("diff_mode", 0)) == SculptureCatalog.DiffMode.PINCH_GATE
	_add_overdrive_charge((0.18 if is_pinch else 0.32) + float(count) * 0.005)

	var avg_pos: Vector3 = center_accum / float(count)
	_spawn_shockwave_ring(Vector3(0.0, turntable_pivot.global_position.y + 0.05, 0.0), Color(0.96, 0.76, 0.32), 3.8)
	callout_triggered.emit("★ TIMBER COLLAPSE! 轰然雪崩 ×%d (+%d币)" % [count, bonus_coins], Color(0.98, 0.70, 0.20), avg_pos)
	coins_earned.emit(bonus_coins, "坍塌奖励")

	for ch_key: int in affected_channels.keys():
		_retire_surplus_launchers_for_channel(ch_key)
	return count


func _spawn_falling_collapse_block(world_pos: Vector3, ch: int) -> void:
	var fmi: MeshInstance3D = falling_pool[falling_cursor]
	falling_cursor = (falling_cursor + 1) % FALLING_POOL_SIZE
	var ch_info: Dictionary = SculptureCatalog.CHANNELS[ch]
	var mat_idx: int = int(ch_info["mat"])
	fmi.mesh = voxel_meshes[mat_idx]
	(fmi.material_override as StandardMaterial3D).albedo_color = ch_info["color"]
	fmi.global_position = world_pos
	fmi.rotation = turntable_pivot.rotation
	fmi.scale = Vector3.ONE * voxel_step
	fmi.visible = true

	var out_dir: Vector3 = (world_pos - turntable_pivot.global_position)
	out_dir.y = 0.0
	if out_dir.length_squared() < 0.01:
		out_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	out_dir = out_dir.normalized()

	falling_blocks.append({
		"node": fmi,
		"color": ch_info["color"],
		"vel": out_dir * randf_range(1.8, 4.4) + Vector3(0.0, randf_range(0.6, 2.8), 0.0),
		"rot_vel": Vector3(randf_range(-10, 10), randf_range(-8, 8), randf_range(-10, 10)),
		"bounced": false,
		"life": 1.05,
	})


func _process_falling_blocks(delta: float) -> void:
	var floor_y: float = turntable_pivot.global_position.y + 0.18
	for i in range(falling_blocks.size() - 1, -1, -1):
		var fb: Dictionary = falling_blocks[i]
		var n: MeshInstance3D = fb["node"]
		fb["vel"] = Vector3(fb["vel"]) + Vector3(0.0, -28.0 * delta, 0.0)
		n.global_position += Vector3(fb["vel"]) * delta
		n.rotation += Vector3(fb["rot_vel"]) * delta
		fb["life"] = float(fb["life"]) - delta

		if n.global_position.y <= floor_y and not bool(fb["bounced"]):
			fb["bounced"] = true
			n.global_position.y = floor_y
			var v := Vector3(fb["vel"])
			v.y = absf(v.y) * 0.36
			v.x *= 1.18
			v.z *= 1.18
			fb["vel"] = v
			fb["life"] = minf(float(fb["life"]), 0.24)
			_spawn_shatter_shards(n.global_position, fb["color"], 1)

		if float(fb["life"]) <= 0.0:
			n.visible = false
			falling_blocks.remove_at(i)


func _retire_surplus_launchers_for_channel(ch: int) -> void:
	if _count_remaining_channel(ch, false) > 0 or _has_inflight_for_channel(ch):
		return

	var chain_idx: int = 0
	for s_idx in range(TOTAL_SLOTS):
		if slots[s_idx] != null and int(slots[s_idx]["ch"]) == ch:
			_retire_slot(s_idx, true, chain_idx)
			chain_idx += 1

	var col_popped: bool = false
	for c in range(NUM_COLS):
		for r in range(columns[c].size() - 1, -1, -1):
			if int(columns[c][r]["ch"]) == ch:
				columns[c].remove_at(r)
				col_popped = true
				chain_idx += 1
	if col_popped:
		audio.play_launcher_clear(chain_idx)
		_rebuild_column_visuals(true)
		state_updated.emit()


func _retire_slot(s_idx: int, completed_cleanly: bool, chain_step: int = 0) -> void:
	var sl = slots[s_idx]
	if sl == null:
		return
	var pawn: Node3D = sl["node"]
	var ch: int = int(sl["ch"])
	slots[s_idx] = null

	if completed_cleanly:
		slot_clear_streak += 1
		audio.play_launcher_clear(chain_step)
		var is_pinch: bool = int(current_level_data.get("diff_mode", 0)) == SculptureCatalog.DiffMode.PINCH_GATE
		# On Pinch Gate, Overdrive charges slowly (0.12) so 5-slot jam happens before free 6th slot!
		_add_overdrive_charge(0.11 if is_pinch else (0.24 if slot_clear_streak < 3 else 0.42))

	if is_instance_valid(pawn):
		_spawn_shatter_shards(pawn.global_position + Vector3(0, 0.4, 0), SculptureCatalog.CHANNELS[ch]["color"], 4)
		var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tw.tween_property(pawn, "scale", Vector3.ZERO, 0.16)
		tw.tween_callback(pawn.queue_free)
	state_updated.emit()


func _add_overdrive_charge(amount: float) -> void:
	if overdrive_unlocked:
		return
	var is_pinch: bool = int(current_level_data.get("diff_mode", 0)) == SculptureCatalog.DiffMode.PINCH_GATE
	if is_pinch:
		# On Pinch Gate levels, cap free charge at 85% so 6th Overdrive Slot requires Booster/Rescue!
		overdrive_charge = clampf(overdrive_charge + amount * 0.35, 0.0, 0.85)
		_emit_stats()
		return
	overdrive_charge = clampf(overdrive_charge + amount, 0.0, 1.0)
	if overdrive_charge >= 1.0:
		overdrive_unlocked = true
		audio.play_overdrive_ready()
		_update_overdrive_cup_visual()
		callout_triggered.emit("★ 第 6 共振超载槽已激活！", Color(0.98, 0.78, 0.22), slot_cups[5].global_position)
	_emit_stats()


func _update_overdrive_cup_visual() -> void:
	if slot_cups.size() < 6:
		return
	var cup6: Node3D = slot_cups[5]
	if overdrive_unlocked:
		cup6.scale = Vector3(0.88, 0.90, 0.88)
		mat_overdrive_gold.albedo_color = Color(1.0, 0.84, 0.34)
		mat_overdrive_gold.emission_energy_multiplier = 0.65
	else:
		cup6.scale = Vector3(0.74, 0.76, 0.74)
		mat_overdrive_gold.albedo_color = Color(0.74, 0.70, 0.64)
		mat_overdrive_gold.emission_energy_multiplier = 0.06


## COMMERCIAL HIGH-CATHARSIS BOOSTERS!
## 1. Deep Magnet: Rips ALL needed ammo for the most jammed occupied slot straight out of deep layers,
##    immediately emptying that jammed slot AND exposing deep inner colors!
func use_booster_magnet() -> bool:
	if voxels.is_empty():
		return false
	var best_slot: int = -1
	var target_ch: int = -1
	var needed_ammo: int = 36
	for s_idx in range(TOTAL_SLOTS):
		if slots[s_idx] != null:
			best_slot = s_idx
			target_ch = int(slots[s_idx]["ch"])
			needed_ammo = maxi(28, int(slots[s_idx]["ammo"]))
			break
	if target_ch == -1:
		for p: Vector3i in voxels.keys():
			target_ch = int(voxels[p]["ch"])
			break
	if target_ch == -1:
		return false

	var to_pop: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if int(voxels[p]["ch"]) == target_ch:
			to_pop.append(p)
			if to_pop.size() >= needed_ammo:
				break
	for p in to_pop:
		voxels[p]["locked"] = false
		_destroy_voxel(p, false, true)

	if best_slot >= 0 and slots[best_slot] != null:
		_retire_slot(best_slot, true, 1)
	_retire_surplus_launchers_for_channel(target_ch)
	_check_and_trigger_timber_collapse()
	_recompute_exposure_and_ao()
	multimesh_dirty = true
	jam_check_delay = 0.0
	_emit_stats()
	audio.play_overdrive_ready()
	callout_triggered.emit("◎ 强力深层磁吸 · 瞬拔 %d 格清空卡槽！" % to_pop.size(), SculptureCatalog.CHANNELS[target_ch]["color"], turntable_pivot.global_position)
	if voxels.is_empty() and not celebrating_win:
		_trigger_level_victory()
	return true


## 2. Siege Breaker Hammer: Demolishes structural Wood Support Columns (both mid-level neck & base piers!),
##    guaranteed to trigger a massive 120–240+ cube Timber Collapse avalanche on architectural castles!
func use_booster_hammer() -> bool:
	if voxels.is_empty():
		return false

	var targets: Array[Vector3i] = []
	# Prioritize high overhang-supporting Wood columns (p.y >= 4) FIRST so Siege Hammer triggers 150-260+ cube roof collapse!
	var wood_high: Array[Vector3i] = []
	var wood_low: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if int(voxels[p]["ch"]) == 3:
			if p.y >= 4:
				wood_high.append(p)
			else:
				wood_low.append(p)
	targets.append_array(wood_high)
	for wl in wood_low:
		if targets.size() >= 72:
			break
		targets.append(wl)
	# Also clear nearby locked blocks if Wood count was small
	if targets.size() < 24:
		for p: Vector3i in voxels.keys():
			if bool(voxels[p]["locked"]) or p.y <= 3:
				targets.append(p)
				if targets.size() >= 48:
					break
	if targets.is_empty():
		for p: Vector3i in voxels.keys():
			targets.append(p)
			if targets.size() >= 40:
				break

	var touched_chs: Dictionary = {}
	for p in targets:
		if voxels.has(p):
			touched_chs[int(voxels[p]["ch"])] = true
			voxels[p]["locked"] = false
			_destroy_voxel(p, false, true)

	var collapsed_n: int = _check_and_trigger_timber_collapse()

	# Also crack open 1 jammed slot's buried inner vein (up to 32 cubes) so jammed cannons immediately roar back to life!
	for s_idx in range(TOTAL_SLOTS):
		if slots[s_idx] != null:
			var j_ch: int = int(slots[s_idx]["ch"])
			var j_need: int = int(slots[s_idx]["ammo"])
			for p: Vector3i in voxels.keys():
				if j_need <= 0:
					break
				if int(voxels[p]["ch"]) == j_ch:
					voxels[p]["locked"] = false
					_destroy_voxel(p, false, true)
					j_need -= 1
			_retire_slot(s_idx, true, 1)
			touched_chs[j_ch] = true
			break

	for ch_k: int in touched_chs.keys():
		_retire_surplus_launchers_for_channel(ch_k)

	_recompute_exposure_and_ao()
	multimesh_dirty = true
	jam_check_delay = 0.0
	hit_shake = 0.28
	audio.play_timber_collapse()
	_emit_stats()
	if collapsed_n == 0:
		callout_triggered.emit("▣ 破城重锤强拆 ×%d 格护甲！" % targets.size(), Color(0.95, 0.56, 0.24), turntable_pivot.global_position)
	if voxels.is_empty() and not celebrating_win:
		_trigger_level_victory()
	return true


## 3. Tactical X-Ray Shuffle: Pulls Wood pillar-snipers, Jelly lock-breakers & small-ammo openers to Row 0!
func use_booster_shuffle() -> bool:
	var flat: Array[Dictionary] = []
	for c in range(NUM_COLS):
		for item in columns[c]:
			flat.append(item)
	if flat.size() <= 1:
		return false

	var exp_counts: Dictionary = {}
	for p: Vector3i in exposed_cache.keys():
		if voxels.has(p) and not bool(voxels[p]["locked"]):
			var ch: int = int(voxels[p]["ch"])
			exp_counts[ch] = int(exp_counts.get(ch, 0)) + 1

	flat.sort_custom(func(a, b):
		var ca: int = int(a["ch"])
		var cb: int = int(b["ch"])
		var hit_a: int = int(exp_counts.get(ca, 0))
		var hit_b: int = int(exp_counts.get(cb, 0))
		var clear_a: int = 1 if (hit_a >= int(a["ammo"]) and hit_a > 0) else 0
		var clear_b: int = 1 if (hit_b >= int(b["ammo"]) and hit_b > 0) else 0
		if clear_a != clear_b:
			return clear_a > clear_b
		return hit_a - int(a["ammo"]) > hit_b - int(b["ammo"])
	)
	for c in range(NUM_COLS):
		columns[c].clear()
	for i in range(flat.size()):
		columns[i % NUM_COLS].append(flat[i])

	_rebuild_column_visuals(true)
	audio.play_overdrive_ready()
	callout_triggered.emit("◆ 透视洗牌 · 破局小口径发射器已提至前排！", Color(0.38, 0.74, 0.94), arena_tray.global_position)
	state_updated.emit()
	return true


func execute_fair_rescue() -> void:
	overdrive_unlocked = true
	overdrive_charge = 1.0
	_update_overdrive_cup_visual()
	var cleared_slots: int = 0
	for s_idx in range(TOTAL_SLOTS):
		if slots[s_idx] != null and cleared_slots < 2:
			var ch: int = int(slots[s_idx]["ch"])
			var need: int = int(slots[s_idx]["ammo"])
			for p: Vector3i in voxels.keys():
				if need <= 0:
					break
				if int(voxels[p]["ch"]) == ch:
					voxels[p]["locked"] = false
					_destroy_voxel(p, false, true)
					need -= 1
			_retire_slot(s_idx, true, cleared_slots)
			_retire_surplus_launchers_for_channel(ch)
			cleared_slots += 1
	_check_and_trigger_timber_collapse()
	_recompute_exposure_and_ao()
	multimesh_dirty = true
	jam_check_delay = 0.0
	audio.play_overdrive_ready()
	_emit_stats()
	state_updated.emit()
	if voxels.is_empty() and not celebrating_win:
		_trigger_level_victory()


func _are_all_available_slots_jammed() -> bool:
	var limit: int = TOTAL_SLOTS if overdrive_unlocked else MAX_MAIN_SLOTS
	for i in range(limit):
		if slots[i] == null:
			return false
		var s_ch: int = int(slots[i]["ch"])
		if not _pick_best_exposed_target(s_ch).is_empty():
			return false
	return true


func _trigger_level_victory() -> void:
	celebrating_win = true
	for i in range(TOTAL_SLOTS):
		if slots[i] != null:
			_retire_slot(i, true, i)
	for c in range(NUM_COLS):
		columns[c].clear()
	_rebuild_column_visuals()

	audio.play_treasure_reveal()
	_spawn_shockwave_ring(turntable_pivot.global_position + Vector3(0, 0.5, 0), Color(1.0, 0.84, 0.32), 4.2)

	var base_coins: int = 60
	var combo_coins: int = mini(40, int(max_combo_reached / 8))
	var summary := {
		"level": int(current_level_data["level"]),
		"title": String(current_level_data["title"]),
		"keepsake": current_level_data["keepsake"],
		"keepsake_idx": int(current_level_data["keepsake_idx"]),
		"base_coins": base_coins,
		"collapse_coins": collapse_bonus_coins,
		"combo_coins": combo_coins,
		"total_coins": base_coins + collapse_bonus_coins + combo_coins,
		"collapsed_blocks": total_collapsed_blocks,
		"max_combo": max_combo_reached,
	}
	state_updated.emit()
	level_completed.emit(summary)


func _recompute_exposure_and_ao() -> void:
	exposed_cache.clear()
	var exp_list: Array[Vector3i] = VoxelSolver.compute_exposed_positions(voxels)
	for p in exp_list:
		exposed_cache[p] = true

	const NEIGHBORS_AO: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1),
		Vector3i(1,1,0), Vector3i(-1,1,0), Vector3i(0,1,1), Vector3i(0,1,-1),
		Vector3i(1,0,1), Vector3i(-1,0,1), Vector3i(1,0,-1), Vector3i(-1,0,-1),
	]
	for p: Vector3i in voxels.keys():
		var occ: float = 0.0
		for d in NEIGHBORS_AO:
			var nb: Vector3i = p + d
			if nb.y < 0 or voxels.has(nb):
				occ += 1.0 if (abs(d.x) + abs(d.y) + abs(d.z) == 1) else 0.55
		voxels[p]["ao"] = clampf(1.0 - occ * 0.072, 0.26, 1.0)


func _rebuild_multimeshes() -> void:
	var buckets: Array = [[], [], [], []]
	var locks: Array[Vector3i] = []

	for p: Vector3i in voxels.keys():
		var d: Dictionary = voxels[p]
		var ch: int = int(d["ch"])
		var m_idx: int = int(SculptureCatalog.CHANNELS[ch]["mat"])
		buckets[m_idx].append(p)
		if bool(d["locked"]):
			locks.append(p)

	var v_scale := Basis.from_scale(Vector3.ONE * voxel_step)
	for m_idx in range(4):
		var list: Array = buckets[m_idx]
		var mm: MultiMesh = multi_meshes[m_idx].multimesh
		mm.instance_count = list.size()
		for i in range(list.size()):
			var p: Vector3i = list[i]
			var d: Dictionary = voxels[p]
			var ch: int = int(d["ch"])
			var ch_info: Dictionary = SculptureCatalog.CHANNELS[ch]
			var origin := Vector3(float(p.x) * voxel_step, (float(p.y) + 0.5) * voxel_step, float(p.z) * voxel_step)
			mm.set_instance_transform(i, Transform3D(v_scale, origin))
			mm.set_instance_color(i, ch_info["color"])
			mm.set_instance_custom_data(i, Color(
				float(ch_info["sym_idx"]),
				float(d["hit_t"]),
				1.0 if bool(d["locked"]) else 0.0,
				float(d["ao"])
			))

	var lmm: MultiMesh = lock_multimesh.multimesh
	lmm.instance_count = locks.size()
	var l_scale := Basis.from_scale(Vector3.ONE * (voxel_step * 1.04))
	for i in range(locks.size()):
		var p: Vector3i = locks[i]
		var origin := Vector3(float(p.x) * voxel_step, (float(p.y) + 0.5) * voxel_step, float(p.z) * voxel_step)
		lmm.set_instance_transform(i, Transform3D(l_scale, origin))


func _jostle_neighbors(center: Vector3i, radius: int) -> void:
	var now_sec: float = Time.get_ticks_msec() * 0.001
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			for dz in range(-radius, radius + 1):
				var nb := center + Vector3i(dx, dy, dz)
				if voxels.has(nb):
					voxels[nb]["hit_t"] = now_sec
	multimesh_dirty = true


func _rebuild_column_visuals(animate_slide: bool = false) -> void:
	for c in range(NUM_COLS):
		for n in col_visual_nodes[c]:
			if is_instance_valid(n):
				n.queue_free()
		col_visual_nodes[c].clear()

		var rows_to_show: int = mini(columns[c].size(), VISIBLE_ROWS)
		for r in range(rows_to_show):
			var item: Dictionary = columns[c][r]
			var is_mystery: bool = (r == 2) # 3rd row in deep fog blind-box disguise!
			var pawn: Node3D = _create_blaster_pawn(int(item["ch"]), is_mystery)
			var target_pos := _column_local_pos(c, r)
			arena_tray.add_child(pawn)
			var s_factor: float = 0.88 if r == 0 else (0.78 if r == 1 else 0.68)
			pawn.scale = Vector3.ONE * s_factor
			if animate_slide:
				pawn.position = _column_local_pos(c, r + 1)
				var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
				tw.tween_property(pawn, "position", target_pos, 0.14)
			else:
				pawn.position = target_pos
			col_visual_nodes[c].append(pawn)


func _column_local_pos(col: int, row: int) -> Vector3:
	return Vector3(COL_LOCAL_X[col], -0.08 - float(row) * 0.70, 0.28 + float(row) * 0.50)


func _override_turntable_top(n: Node, ceramic_mat: Material) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			mi.set_surface_override_material(0, ceramic_mat)
	for c in n.get_children():
		_override_turntable_top(c, ceramic_mat)


func _create_blaster_pawn(ch: int, mystery_fog: bool) -> Node3D:
	var inst: Node3D = scn_blaster.instantiate()
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.55, 0.53, 0.50) if mystery_fog else Color(0.90, 0.86, 0.80)
	body_mat.roughness = 0.36
	var cap_mat := StandardMaterial3D.new()
	if mystery_fog:
		cap_mat.albedo_color = Color(0.36, 0.35, 0.38)
		cap_mat.roughness = 0.45
	else:
		var ch_info: Dictionary = SculptureCatalog.CHANNELS[ch]
		cap_mat.albedo_color = ch_info["color"]
		cap_mat.roughness = 0.16
	_tint_blaster_parts(inst, cap_mat, body_mat)
	return inst


func _tint_blaster_parts(n: Node, cap_mat: Material, body_mat: Material) -> void:
	if n is MeshInstance3D:
		if n.name.contains("Cap"):
			(n as MeshInstance3D).material_override = cap_mat
		elif n.name.contains("Body"):
			(n as MeshInstance3D).material_override = body_mat
	for c in n.get_children():
		_tint_blaster_parts(c, cap_mat, body_mat)


func _override_mesh_materials(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_override_mesh_materials(c, mat)


func _spawn_shatter_shards(world_pos: Vector3, col: Color, count: int) -> void:
	for _i in range(count):
		var sh: Dictionary = shard_pool[shard_cursor]
		shard_cursor = (shard_cursor + 1) % SHARD_POOL_SIZE
		var mi: MeshInstance3D = sh["node"]
		(sh["mat"] as StandardMaterial3D).albedo_color = col
		mi.global_position = world_pos + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
		mi.scale = Vector3.ONE * randf_range(0.55, 1.0)
		mi.visible = true
		sh["vel"] = Vector3(randf_range(-3.0, 3.0), randf_range(2.0, 5.0), randf_range(-3.0, 3.0))
		sh["rot_vel"] = Vector3(randf_range(-14, 14), randf_range(-14, 14), randf_range(-14, 14))
		sh["life"] = randf_range(0.28, 0.46)
		sh["active"] = true


func _spawn_shockwave_ring(world_pos: Vector3, col: Color, max_scale: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.40
	torus.outer_radius = 0.50
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(col.r, col.g, col.b, 0.85)
	ring.material_override = sm
	fx_root.add_child(ring)
	ring.global_position = world_pos
	ring.scale = Vector3.ONE * 0.25
	active_rings.append({"node": ring, "mat": sm, "t": 0.0, "dur": 0.34, "max_s": max_scale})


func _spawn_prism_beam(from_w: Vector3, to_w: Vector3) -> void:
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var dist: float = maxf(0.1, from_w.distance_to(to_w))
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.05
	cyl.height = dist
	beam.mesh = cyl
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.55, 0.94, 1.0, 0.95)
	beam.material_override = sm
	fx_root.add_child(beam)
	beam.global_position = (from_w + to_w) * 0.5
	var dir: Vector3 = (to_w - from_w).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.99:
		beam.look_at(to_w, Vector3.UP)
		beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	active_beams.append({"node": beam, "mat": sm, "t": 0.0, "dur": 0.22})


func _process_shards_and_fx(delta: float) -> void:
	for sh in shard_pool:
		if not bool(sh["active"]):
			continue
		sh["life"] = float(sh["life"]) - delta
		var mi: MeshInstance3D = sh["node"]
		if float(sh["life"]) <= 0.0:
			sh["active"] = false
			mi.visible = false
			continue
		sh["vel"] = Vector3(sh["vel"]) + Vector3(0.0, -22.0 * delta, 0.0)
		mi.global_position += Vector3(sh["vel"]) * delta
		mi.rotation += Vector3(sh["rot_vel"]) * delta
		mi.scale = mi.scale.lerp(Vector3.ZERO, clampf(delta * 4.8, 0.0, 1.0))

	for i in range(active_rings.size() - 1, -1, -1):
		var r: Dictionary = active_rings[i]
		r["t"] = float(r["t"]) + delta
		var u: float = clampf(float(r["t"]) / float(r["dur"]), 0.0, 1.0)
		if is_instance_valid(r["node"]):
			r["node"].scale = Vector3.ONE * lerpf(0.25, float(r["max_s"]), 1.0 - pow(1.0 - u, 3.0))
			var c: Color = (r["mat"] as StandardMaterial3D).albedo_color
			c.a = (1.0 - u) * 0.85
			(r["mat"] as StandardMaterial3D).albedo_color = c
		if u >= 1.0:
			if is_instance_valid(r["node"]):
				r["node"].queue_free()
			active_rings.remove_at(i)

	for i in range(active_beams.size() - 1, -1, -1):
		var b: Dictionary = active_beams[i]
		b["t"] = float(b["t"]) + delta
		var u: float = clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)
		if is_instance_valid(b["node"]):
			var c: Color = (b["mat"] as StandardMaterial3D).albedo_color
			c.a = 1.0 - u
			(b["mat"] as StandardMaterial3D).albedo_color = c
		if u >= 1.0:
			if is_instance_valid(b["node"]):
				b["node"].queue_free()
			active_beams.remove_at(i)


func _grid_to_world(p: Vector3i) -> Vector3:
	var local := Vector3(float(p.x) * voxel_step, (float(p.y) + 0.5) * voxel_step, float(p.z) * voxel_step)
	return turntable_pivot.to_global(local)


func _count_remaining_channel(ch: int, unlocked_only: bool) -> int:
	var n: int = 0
	for p: Vector3i in voxels.keys():
		if int(voxels[p]["ch"]) == ch and (not unlocked_only or not bool(voxels[p]["locked"])):
			n += 1
	return n


func _has_inflight_for_channel(ch: int) -> bool:
	for p in projectiles:
		if int(p["ch"]) == ch:
			return true
	return false


func _emit_stats() -> void:
	stats_changed.emit(voxels.size(), total_voxel_count, combo_count, overdrive_charge, overdrive_unlocked)


func get_slot_screen_pos(slot_idx: int) -> Vector2:
	if camera == null or slot_idx < 0 or slot_idx >= slot_cups.size():
		return Vector2(-999, -999)
	return camera.unproject_position(slot_cups[slot_idx].global_position + Vector3(0.0, 0.52, 0.0))


func get_column_row_screen_pos(col_idx: int, row_idx: int) -> Vector2:
	if camera == null:
		return Vector2(-999, -999)
	var w: Vector3 = arena_tray.to_global(_column_local_pos(col_idx, row_idx) + Vector3(0.0, 0.42, 0.0))
	return camera.unproject_position(w)
