class_name FuseStage
extends Node3D

## Core 3D Arcade Voxel Engine for《合炮大爆破 Fuse Smash!》
## Strictly adheres to GDD 5.2 60fps performance redline:
##  - 1 Draw Call MultiMeshInstance3D for ALL sculpture cubes (standard 44-tri beveled cube)
##  - Pre-allocated 40-cube Debris Object Pool (zero GC stutter!)
##  - Merge-to-Fire (同色合炮), Pulse Core 3x3x3 Shockwave + 0.15s Slow-Mo,
##    Spinner Layer 90° auto-rotation, Magnetic Snap, Chain Locks, Dual-Color Cannons,
##    and 360° Auto-Scan Anti-Stuck!

signal stats_changed(cleared: int, total: int, combo: int)
signal state_updated()
signal fuse_triggered(left_slot: int, right_slot: int, ch: int, new_ammo: int)
signal shot_fired(slot_idx: int, target_screen_pos: Vector2, ch: int, is_super: bool)
signal voxel_cleared_fx(screen_pos: Vector2, ch: int, is_core: bool)
signal pulse_core_detonated(screen_pos: Vector2, cleared_count: int, bonus_coins: int)
signal callout_banner(text: String, accent: Color)
signal level_completed(summary: Dictionary)
signal slots_jammed()

const BASE_SLOTS: int = 5
const MAX_SLOTS: int = 6
const NUM_COLS: int = 5
const DEBRIS_POOL_SIZE: int = 40 # GDD 5.2 strict 40-object pool!
const DIRS6: Array[Vector3i] = [
	Vector3i(1,0,0), Vector3i(-1,0,0),
	Vector3i(0,1,0), Vector3i(0,-1,0),
	Vector3i(0,0,1), Vector3i(0,0,-1),
]

var camera: Camera3D
var audio: ArcadeAudio

var model_tilt_root: Node3D
var orbit_pivot: Node3D
var main_multimesh: MultiMeshInstance3D
var core_multimesh: MultiMeshInstance3D
var fx_root: Node3D

var plastic_mat: ShaderMaterial
var core_mat: ShaderMaterial
var cube_mesh: ArrayMesh
var core_mesh: SphereMesh

var level_data: Dictionary = {}
var voxels: Dictionary = {} # Vector3i -> {ch, locked, core, hit_t, ao}
var exposed_set: Dictionary = {}
var reserved_targets: Dictionary = {}
var total_voxels: int = 0
var voxel_step: float = 0.36
var center_offset := Vector3.ZERO
var bound_radius: float = 2.8
var spinner_y_min: int = -99
var spinner_y_max: int = -99
var has_magnetic_snap: bool = false

var slots: Array = [] # size 6, entries null or {ch, ammo, ch2, ammo2, is_super, cooldown}
var extra_slot_unlocked: bool = false
var columns: Array = [[], [], [], [], []]

var debris_pool: Array[Dictionary] = []
var debris_cursor: int = 0
var shock_rings: Array[Dictionary] = []
var pending_hits: Array[Dictionary] = []

var yaw: float = 0.0
var pitch: float = 0.0
var yaw_vel: float = 0.0
var pitch_vel: float = 0.0
var zoom_offset: float = 0.0
var is_dragging: bool = false
var auto_scanning: bool = false
var auto_scan_accum: float = 0.0

var combo_count: int = 0
var combo_timer: float = 0.0
var max_combo: int = 0
var slot_clear_streak: int = 0
var pulse_cores_blasted: int = 0
var core_bonus_coins: int = 0
var fuse_count_this_level: int = 0

var hit_shake: float = 0.0
var slowmo_real_remaining: float = 0.0
var snap_bounce_t: float = 0.0
var spinner_anim_angle: float = 0.0
var multimesh_dirty: bool = false
var celebrating_win: bool = false
var stage_active: bool = true
var show_symbols: bool = false
var jam_grace_timer: float = 0.0
var verified_paths_count: int = 0


func setup(p_camera: Camera3D, p_audio: ArcadeAudio) -> void:
	camera = p_camera
	audio = p_audio

	cube_mesh = BeveledCubeBuilder.create_beveled_cube(0.485, 0.095)
	core_mesh = BeveledCubeBuilder.create_core_sphere(0.56)

	plastic_mat = ShaderMaterial.new()
	plastic_mat.shader = preload("res://shaders/arcade_plastic.gdshader")

	core_mat = ShaderMaterial.new()
	core_mat.shader = preload("res://shaders/pulse_core.gdshader")

	model_tilt_root = Node3D.new()
	model_tilt_root.name = "ModelTiltRoot"
	model_tilt_root.position = Vector3(0.0, 1.35, 0.0)
	add_child(model_tilt_root)

	orbit_pivot = Node3D.new()
	orbit_pivot.name = "OrbitPivot"
	model_tilt_root.add_child(orbit_pivot)

	# SINGLE DRAW CALL MultiMeshInstance3D for ALL static sculpture cubes!
	main_multimesh = MultiMeshInstance3D.new()
	main_multimesh.name = "SculptureMultiMesh"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = cube_mesh
	main_multimesh.multimesh = mm
	main_multimesh.material_override = plastic_mat
	main_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	orbit_pivot.add_child(main_multimesh)

	# Lightweight MultiMesh for embedded Golden Pulse Energy Cores
	core_multimesh = MultiMeshInstance3D.new()
	core_multimesh.name = "PulseCoreMultiMesh"
	var cmm := MultiMesh.new()
	cmm.transform_format = MultiMesh.TRANSFORM_3D
	cmm.mesh = core_mesh
	core_multimesh.multimesh = cmm
	core_multimesh.material_override = core_mat
	core_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orbit_pivot.add_child(core_multimesh)

	fx_root = Node3D.new()
	fx_root.name = "FXRoot"
	add_child(fx_root)

	# Pre-allocate 40 flying debris cubes (GDD 5.2 strict object pool!)
	for i in range(DEBRIS_POOL_SIZE):
		var mi := MeshInstance3D.new()
		mi.mesh = cube_mesh
		mi.visible = false
		var dm := StandardMaterial3D.new()
		dm.roughness = 0.22
		dm.metallic_specular = 0.65
		mi.material_override = dm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mi)
		debris_pool.append({
			"node": mi,
			"mat": dm,
			"vel": Vector3.ZERO,
			"rot_vel": Vector3.ZERO,
			"life": 0.0,
			"max_life": 0.75,
			"base_scale": 0.36,
			"active": false,
		})

	slots.resize(MAX_SLOTS)
	for i in range(MAX_SLOTS):
		slots[i] = null


func set_symbol_mode(enabled: bool) -> void:
	show_symbols = enabled
	if plastic_mat:
		plastic_mat.set_shader_parameter("u_show_symbols", 1.0 if enabled else 0.0)


func load_level(level_num: int, win_streak: int = 0) -> void:
	_reset_transient()
	level_data = LevelArchitect.build_level(level_num)
	voxel_step = float(level_data.get("voxel_step", 0.36))
	spinner_y_min = int(level_data.get("spinner_y_min", -99))
	spinner_y_max = int(level_data.get("spinner_y_max", -99))
	has_magnetic_snap = bool(level_data.get("has_magnetic_snap", false))

	var tilt_deg: Vector3 = level_data.get("tilt_deg", Vector3(10.0, -22.0, -10.0))
	model_tilt_root.rotation_degrees = Vector3(tilt_deg.x, 0.0, tilt_deg.z)
	yaw = deg_to_rad(tilt_deg.y)
	pitch = 0.0
	yaw_vel = 0.0
	pitch_vel = 0.0
	zoom_offset = 0.0

	var src_voxels: Dictionary = level_data["voxels"]
	var min_v := Vector3(999, 999, 999)
	var max_v := Vector3(-999, -999, -999)
	for p: Vector3i in src_voxels.keys():
		var d: Dictionary = src_voxels[p]
		voxels[p] = {
			"ch": int(d["ch"]),
			"locked": bool(d.get("locked", false)),
			"core": bool(d.get("core", false)),
			"hit_t": -10.0,
			"ao": 1.0,
		}
		min_v.x = minf(min_v.x, float(p.x))
		min_v.y = minf(min_v.y, float(p.y))
		min_v.z = minf(min_v.z, float(p.z))
		max_v.x = maxf(max_v.x, float(p.x))
		max_v.y = maxf(max_v.y, float(p.y))
		max_v.z = maxf(max_v.z, float(p.z))

	center_offset = (min_v + max_v) * 0.5
	var max_r: float = 1.8
	for p: Vector3i in voxels.keys():
		var local_p: Vector3 = (Vector3(p) - center_offset) * voxel_step
		max_r = maxf(max_r, local_p.length() + voxel_step * 0.65)
	bound_radius = max_r
	total_voxels = voxels.size()

	# Generate Auto-Solver Verified 5-Column Queues!
	var gen: Dictionary = FuseSolver.generate_verified_columns(level_data)
	columns = gen["columns"]
	verified_paths_count = int(gen["verified_paths"])

	# Win Streak Reward (GDD 4): 3+ streak starts with 1 pre-charged Super Cannon in Column 2 Row 0!
	if win_streak >= 3 and not columns[2].is_empty():
		columns[2][0]["is_super"] = true
		columns[2][0]["ammo"] = int(ceil(float(columns[2][0]["ammo"]) * 1.25))

	_recompute_exposed_and_ao()
	_rebuild_multimeshes()
	stats_changed.emit(0, total_voxels, 0)
	state_updated.emit()


func _reset_transient() -> void:
	Engine.time_scale = 1.0
	slowmo_real_remaining = 0.0
	voxels.clear()
	exposed_set.clear()
	reserved_targets.clear()
	pending_hits.clear()
	for i in range(MAX_SLOTS):
		slots[i] = null
	extra_slot_unlocked = false
	celebrating_win = false
	auto_scanning = false
	auto_scan_accum = 0.0
	jam_grace_timer = 0.0
	combo_count = 0
	combo_timer = 0.0
	max_combo = 0
	slot_clear_streak = 0
	pulse_cores_blasted = 0
	core_bonus_coins = 0
	fuse_count_this_level = 0
	hit_shake = 0.0
	snap_bounce_t = 0.0
	spinner_anim_angle = 0.0

	for db in debris_pool:
		db["active"] = false
		(db["node"] as MeshInstance3D).visible = false
	for r in shock_rings:
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
	shock_rings.clear()


func get_active_slot_limit() -> int:
	return MAX_SLOTS if extra_slot_unlocked else BASE_SLOTS


func apply_orbit_drag(rel: Vector2) -> void:
	is_dragging = true
	auto_scanning = false
	yaw += rel.x * 0.0115
	pitch = clampf(pitch + rel.y * 0.007, -0.58, 0.58)
	yaw_vel = clampf(rel.x * 0.45, -7.5, 7.5)
	pitch_vel = clampf(rel.y * 0.25, -4.0, 4.0)


func end_orbit_drag() -> void:
	is_dragging = false


func apply_zoom_delta(delta_z: float) -> void:
	zoom_offset = clampf(zoom_offset + delta_z, -2.6, 2.2)


# ==============================================================================
# PLAYER INPUT: Pick Column Top Cannon -> Active Slot -> Check Instant Merge-to-Fire!
# ==============================================================================
func try_pick_column(col_idx: int) -> bool:
	if celebrating_win or col_idx < 0 or col_idx >= NUM_COLS:
		return false
	if columns[col_idx].is_empty():
		return false

	var limit: int = get_active_slot_limit()
	var free_idx: int = -1
	for i in range(limit):
		if slots[i] == null:
			free_idx = i
			break

	if free_idx == -1:
		hit_shake = 0.10
		callout_banner.emit("槽位已满！试试同色合炮或道具破局", Color(1.0, 0.30, 0.31))
		return false

	var item: Dictionary = columns[col_idx].pop_front()
	slots[free_idx] = {
		"ch": int(item["ch"]),
		"ammo": int(item["ammo"]),
		"ch2": int(item.get("ch2", -1)),
		"ammo2": int(item.get("ammo2", 0)),
		"is_super": bool(item.get("is_super", false)),
		"cooldown": 0.05,
	}
	audio.play_slot_in()
	auto_scanning = false
	jam_grace_timer = 0.0

	# CORE SIGNATURE MECHANIC: Check adjacent Same-Color Fuse Cannon!
	_check_and_trigger_adjacent_fuse(free_idx)
	_retire_exhausted_channels()
	state_updated.emit()
	return true


func _check_and_trigger_adjacent_fuse(focus_idx: int = -1) -> bool:
	var limit: int = get_active_slot_limit()
	var merged_any: bool = false
	var keep_checking: bool = true

	while keep_checking:
		keep_checking = false
		var pairs_to_check: Array[Vector2i] = []
		if focus_idx >= 0:
			if focus_idx > 0:
				pairs_to_check.append(Vector2i(focus_idx - 1, focus_idx))
			if focus_idx + 1 < limit:
				pairs_to_check.append(Vector2i(focus_idx, focus_idx + 1))
		for i in range(limit - 1):
			var pr := Vector2i(i, i + 1)
			if not pairs_to_check.has(pr):
				pairs_to_check.append(pr)

		for pr in pairs_to_check:
			var a_i: int = pr.x
			var b_i: int = pr.y
			if slots[a_i] != null and slots[b_i] != null:
				if int(slots[a_i]["ch"]) == int(slots[b_i]["ch"]):
					var ch: int = int(slots[a_i]["ch"])
					var sum_ammo: int = int(slots[a_i]["ammo"]) + int(slots[b_i]["ammo"])
					var bonus_ammo: int = maxi(2, int(ceil(float(sum_ammo) * 0.20)))
					var total_ammo: int = sum_ammo + bonus_ammo

					# Preserve secondary color if either was a Dual-Color cannon
					var keep_ch2: int = int(slots[a_i]["ch2"])
					var keep_ammo2: int = int(slots[a_i]["ammo2"])
					if keep_ch2 == -1 and int(slots[b_i]["ch2"]) != -1:
						keep_ch2 = int(slots[b_i]["ch2"])
						keep_ammo2 = int(slots[b_i]["ammo2"])

					slots[a_i] = {
						"ch": ch,
						"ammo": total_ammo,
						"ch2": keep_ch2,
						"ammo2": keep_ammo2,
						"is_super": true,
						"cooldown": 0.04,
					}
					slots[b_i] = null
					fuse_count_this_level += 1
					audio.play_fuse_arc()
					hit_shake = maxf(hit_shake, 0.14)
					fuse_triggered.emit(a_i, b_i, ch, total_ammo)
					callout_banner.emit("⚡ 同色合炮！弹药 +%d · 1.8×射速 · 双层穿透！" % bonus_ammo, Color(0.11, 0.65, 1.0))

					# Compact slots left gently? No — leaving the newly freed slot right there matches Page 2 & allows strategic positioning!
					merged_any = true
					keep_checking = true
					focus_idx = a_i
					break

	return merged_any


# ==============================================================================
# FRAME UPDATE: Orbit, Active Cannon Auto-Fire, 360° Auto-Scan, Debris Pool, Slow-Mo
# ==============================================================================
func _process(delta: float) -> void:
	if not stage_active:
		return

	# Handle real-time slow-mo timer (unscaled by Engine.time_scale!)
	if slowmo_real_remaining > 0.0:
		var real_dt: float = delta / maxf(Engine.time_scale, 0.05)
		slowmo_real_remaining -= real_dt
		if slowmo_real_remaining <= 0.0:
			Engine.time_scale = 1.0

	var now_sec: float = Time.get_ticks_msec() * 0.001
	plastic_mat.set_shader_parameter("u_clock", now_sec)
	core_mat.set_shader_parameter("u_clock", now_sec)

	# Smooth orbit damping & elastic zoom snap-back
	if celebrating_win:
		yaw += delta * 1.45
		pitch = lerpf(pitch, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	elif auto_scanning:
		var scan_step: float = delta * 2.85
		yaw += scan_step
		auto_scan_accum += scan_step
		pitch = lerpf(pitch, 0.0, clampf(delta * 3.5, 0.0, 1.0))
	elif not is_dragging:
		yaw += yaw_vel * delta
		pitch = clampf(pitch + pitch_vel * delta, -0.58, 0.58)
		yaw_vel = lerpf(yaw_vel, 0.0, clampf(delta * 6.5, 0.0, 1.0))
		pitch_vel = lerpf(pitch_vel, 0.0, clampf(delta * 6.5, 0.0, 1.0))
		zoom_offset = lerpf(zoom_offset, 0.0, clampf(delta * 5.0, 0.0, 1.0))

	# Gentle floating hover + Magnetic Snap elastic bounce
	var hover_y: float = sin(now_sec * 1.9) * 0.11
	var squash := Vector3.ONE
	if snap_bounce_t > 0.0:
		snap_bounce_t = maxf(0.0, snap_bounce_t - delta * 3.8)
		var b: float = sin(snap_bounce_t * PI * 2.0) * snap_bounce_t * 0.16
		squash = Vector3(1.0 + b, 1.0 - b * 1.25, 1.0 + b)

	model_tilt_root.position.y = 1.55 + hover_y
	orbit_pivot.rotation = Vector3(pitch, yaw, 0.0)
	orbit_pivot.scale = squash

	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			_emit_stats()

	_update_camera(delta)
	_process_active_slots(delta)
	_process_pending_hits(delta)
	_process_debris_and_rings(delta)

	if multimesh_dirty:
		multimesh_dirty = false
		_rebuild_multimeshes()

	# Auto-Scan Anti-Stuck (GDD 2.1 #5): When all slots full & idle, spin 360° before ever declaring jam!
	if not celebrating_win and pending_hits.is_empty():
		if _are_all_slots_filled_and_idle():
			if not auto_scanning:
				jam_grace_timer += delta
				if jam_grace_timer > 0.35:
					auto_scanning = true
					auto_scan_accum = 0.0
					callout_banner.emit("↻ 自动 360° 扫描背面同色块...", Color(0.11, 0.39, 0.93))
			elif auto_scan_accum >= TAU * 1.08:
				auto_scanning = false
				auto_scan_accum = 0.0
				jam_grace_timer = -999.0
				slots_jammed.emit()
		else:
			jam_grace_timer = 0.0


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = vp.x / maxf(vp.y, 1.0)
	camera.fov = 34.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

	# Dynamically frame EVERY sculpture cleanly inside the upper-center 50% stage (zero HUD/slot overlap!)
	var half_tan_y: float = tan(deg_to_rad(17.0))
	var half_tan_x: float = half_tan_y * aspect
	var dist_for_w: float = (bound_radius * 1.24) / maxf(half_tan_x, 0.14)
	var dist_for_h: float = (bound_radius * 2.38) / half_tan_y
	var dist: float = maxf(18.5, maxf(dist_for_w, dist_for_h)) + zoom_offset
	var look_at_pt := Vector3(0.0, -0.30, 0.0) # Places sculpture dead-center in upper-center 50% zone!
	var desired := look_at_pt + Vector3(0.0, 0.24, 1.0).normalized() * dist

	if hit_shake > 0.001:
		hit_shake = maxf(0.0, hit_shake - delta * 2.8)
		desired += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * hit_shake

	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 10.0, 0.0, 1.0))
	camera.look_at(look_at_pt, Vector3.UP)


func _process_active_slots(delta: float) -> void:
	if celebrating_win or voxels.is_empty():
		return

	var limit: int = get_active_slot_limit()
	for s_idx in range(limit):
		var sl = slots[s_idx]
		if sl == null:
			continue

		var ch: int = int(sl["ch"])
		if _count_remaining_for_color(ch) == 0 and not _has_pending_for_color(ch):
			_advance_or_retire_slot(s_idx)
			continue

		sl["cooldown"] = float(sl["cooldown"]) - delta
		if float(sl["cooldown"]) > 0.0 or int(sl["ammo"]) <= 0:
			continue

		var is_super: bool = bool(sl["is_super"])
		# Require front/side visibility during normal play; allow any exposed angle during 360° auto-scan!
		var min_facing: float = -0.35 if auto_scanning else -0.15
		var target_pos: Vector3i = _pick_best_target(ch, min_facing)
		if target_pos == Vector3i(999, 999, 999):
			continue

		# Found a live target! Cancel auto-scan immediately & open fire!
		auto_scanning = false
		auto_scan_accum = 0.0
		jam_grace_timer = 0.0

		reserved_targets[target_pos] = true
		sl["ammo"] = int(sl["ammo"]) - 1
		# Super Cannon fires 1.8x faster (GDD 2.1 #4)!
		sl["cooldown"] = 0.052 if is_super else 0.094

		# Trigger instant Hit-Flash white + pop expansion (0.06s before shatter!)
		if voxels.has(target_pos):
			voxels[target_pos]["hit_t"] = Time.get_ticks_msec() * 0.001
			multimesh_dirty = true

		var world_p: Vector3 = _grid_to_world(target_pos)
		var screen_p: Vector2 = camera.unproject_position(world_p) if camera else Vector2(270, 320)
		shot_fired.emit(s_idx, screen_p, ch, is_super)
		audio.play_shoot(is_super)

		pending_hits.append({
			"pos": target_pos,
			"ch": ch,
			"is_super": is_super,
			"t": 0.062, # Exact 0.06s Hit-Flash duration before shatter pop!
		})

		if int(sl["ammo"]) <= 0:
			_advance_or_retire_slot(s_idx)
		state_updated.emit()


func _process_pending_hits(delta: float) -> void:
	for i in range(pending_hits.size() - 1, -1, -1):
		var h: Dictionary = pending_hits[i]
		h["t"] = float(h["t"]) - delta
		if float(h["t"]) <= 0.0:
			pending_hits.remove_at(i)
			var pos: Vector3i = h["pos"]
			var is_super: bool = bool(h["is_super"])
			reserved_targets.erase(pos)
			_destroy_voxel(pos, is_super, false)


func _pick_best_target(ch: int, min_facing: float) -> Vector3i:
	var best_pos := Vector3i(999, 999, 999)
	var best_score: float = -1e9
	var cam_pos: Vector3 = camera.global_position if camera else Vector3(0, 5, 16)
	var center_w: Vector3 = model_tilt_root.global_position

	for p: Vector3i in exposed_set.keys():
		if reserved_targets.has(p) or not voxels.has(p):
			continue
		var d: Dictionary = voxels[p]
		if bool(d["locked"]):
			continue
		var is_core: bool = bool(d["core"])
		if not is_core and int(d["ch"]) != ch:
			continue

		var wp: Vector3 = _grid_to_world(p)
		var radial: Vector3 = (wp - center_w).normalized()
		var to_cam: Vector3 = (cam_pos - center_w).normalized()
		var facing: float = radial.dot(to_cam)
		if facing < min_facing:
			continue

		# Strongly prioritize exposed Golden Pulse Cores and camera-facing front blocks!
		var score: float = facing * 4.0 + (6.0 if is_core else 0.0) + float(p.y) * 0.06
		if score > best_score:
			best_score = score
			best_pos = p

	return best_pos


func _destroy_voxel(pos: Vector3i, can_pierce: bool, from_shockwave: bool) -> void:
	if not voxels.has(pos):
		return
	var d: Dictionary = voxels[pos]
	var ch: int = int(d["ch"])
	var is_core: bool = bool(d["core"])
	var wp: Vector3 = _grid_to_world(pos)
	var sp: Vector2 = camera.unproject_position(wp) if camera else Vector2(270, 320)

	voxels.erase(pos)
	reserved_targets.erase(pos)

	combo_count += 1
	max_combo = maxi(max_combo, combo_count)
	combo_timer = 1.65

	if not from_shockwave:
		audio.play_brick_pop(combo_count - 1)
	_spawn_debris(wp, FusePalette.get_color(ch), 1.0 if from_shockwave else 0.85)
	voxel_cleared_fx.emit(sp, ch, is_core)

	# Unlock adjacent Chain-Locked blocks (GDD 3.1: 铁链锁)!
	for dir in DIRS6:
		var nb: Vector3i = pos + dir
		if voxels.has(nb) and bool(voxels[nb]["locked"]):
			voxels[nb]["locked"] = false

	# If this block WAS a Pulse Core -> DETONATE 3x3x3 RADIAL SHOCKWAVE!
	if is_core:
		_detonate_pulse_core(pos, wp)

	# Super Cannon 2-Layer Piercing (GDD 2.1 #4): Pierce straight into 1 deeper inner same-color block OR inner Pulse Core!
	if can_pierce and not is_core:
		var inner: Vector3i = _find_pierce_neighbor(pos, ch)
		if inner != Vector3i(999, 999, 999):
			voxels[inner]["locked"] = false
			_destroy_voxel(inner, false, false)

	if not from_shockwave:
		if has_magnetic_snap:
			_check_magnetic_snap()
		_recompute_exposed_and_ao()
		multimesh_dirty = true
		_retire_exhausted_channels()
		_emit_stats()
		if voxels.is_empty() and not celebrating_win:
			_trigger_final_smash_victory()


func _find_pierce_neighbor(from_pos: Vector3i, ch: int) -> Vector3i:
	# Priority 1: Adjacent inner Golden Pulse Core!
	for dir in DIRS6:
		var nb: Vector3i = from_pos + dir
		if voxels.has(nb) and not reserved_targets.has(nb) and bool(voxels[nb]["core"]):
			return nb
	# Priority 2: Deeper adjacent same-color cube closer to sculpture center!
	var best := Vector3i(999, 999, 999)
	var best_d: float = 9999.0
	for dir in DIRS6:
		var nb: Vector3i = from_pos + dir
		if voxels.has(nb) and not reserved_targets.has(nb) and int(voxels[nb]["ch"]) == ch:
			var dist_c: float = (Vector3(nb) - center_offset).length()
			if dist_c < best_d:
				best_d = dist_c
				best = nb
	return best


# ==============================================================================
# PULSE CORE 3x3x3 RADIAL SHOCKWAVE + 0.15s SLOW-MO (GDD 1.1 & 5.3)
# ==============================================================================
func _detonate_pulse_core(core_grid: Vector3i, core_world: Vector3) -> void:
	pulse_cores_blasted += 1
	var bonus: int = 15
	core_bonus_coins += bonus

	audio.play_pulse_boom()
	_trigger_slowmo(0.15, 0.35)
	hit_shake = maxf(hit_shake, 0.32)
	_spawn_shockwave_ring(core_world, Color(1.0, 0.80, 0.16), 4.2)

	var blast_list: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		var diff: Vector3i = p - core_grid
		if abs(diff.x) <= 2 and abs(diff.y) <= 2 and abs(diff.z) <= 2:
			if Vector3(diff).length() <= 2.35:
				blast_list.append(p)

	var chained_cores: Array[Vector3i] = []
	for p in blast_list:
		if not voxels.has(p):
			continue
		var d: Dictionary = voxels[p]
		var wp: Vector3 = _grid_to_world(p)
		var c: Color = FusePalette.get_color(int(d["ch"]))
		var was_core: bool = bool(d["core"])
		voxels.erase(p)
		reserved_targets.erase(p)
		combo_count += 1
		max_combo = maxi(max_combo, combo_count)
		_spawn_debris(wp, c, 1.45, (wp - core_world).normalized())
		if was_core:
			chained_cores.append(p)

	var sp: Vector2 = camera.unproject_position(core_world) if camera else Vector2(270, 320)
	pulse_core_detonated.emit(sp, blast_list.size(), bonus)
	callout_banner.emit("☀ 脉冲核爆破！震飞 ×%d 块 (+%d 币)" % [blast_list.size(), bonus], Color(1.0, 0.62, 0.08))

	for cc in chained_cores:
		_detonate_pulse_core(cc, _grid_to_world(cc))

	if has_magnetic_snap:
		_check_magnetic_snap()
	_recompute_exposed_and_ao()
	multimesh_dirty = true


# ==============================================================================
# SPINNER LAYER 90° AUTO-ROTATION (GDD 3.1: 分段自转层)
# ==============================================================================
func _rotate_spinner_layer_90() -> void:
	if spinner_y_min < -50 or voxels.is_empty():
		return
	var moved: Dictionary = {}
	var to_erase: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if p.y >= spinner_y_min and p.y <= spinner_y_max:
			to_erase.append(p)
			var new_p := Vector3i(-p.z, p.y, p.x)
			moved[new_p] = voxels[p]
	if to_erase.is_empty():
		return
	for p in to_erase:
		voxels.erase(p)
		reserved_targets.erase(p)
	for np: Vector3i in moved.keys():
		moved[np]["hit_t"] = Time.get_ticks_msec() * 0.001
		voxels[np] = moved[np]
	_recompute_exposed_and_ao()
	multimesh_dirty = true
	callout_banner.emit("↻ 自转层旋转 90°！暴露新色面", Color(0.11, 0.39, 0.93))


# ==============================================================================
# MAGNETIC SNAP (GDD 3.1: 磁吸合拢 — Hollowed middle layer snaps upper half down!)
# ==============================================================================
func _check_magnetic_snap() -> void:
	if voxels.is_empty():
		return
	var ys: Dictionary = {}
	var min_y: int = 999
	var max_y: int = -999
	for p: Vector3i in voxels.keys():
		ys[p.y] = true
		min_y = mini(min_y, p.y)
		max_y = maxi(max_y, p.y)

	var empty_gap_y: int = -999
	for y in range(min_y + 1, max_y):
		if not ys.has(y):
			empty_gap_y = y
			break
	if empty_gap_y == -999:
		return

	# Find highest occupied row below gap and lowest occupied row above gap
	var drop_by: int = 0
	var check_y: int = empty_gap_y
	while check_y <= max_y and not ys.has(check_y):
		drop_by += 1
		check_y += 1
	if drop_by <= 0:
		return

	var shifted: Dictionary = {}
	for p: Vector3i in voxels.keys():
		var d: Dictionary = voxels[p]
		if p.y > empty_gap_y:
			var np := Vector3i(p.x, p.y - drop_by, p.z)
			d["hit_t"] = Time.get_ticks_msec() * 0.001
			shifted[np] = d
		else:
			shifted[p] = d

	voxels = shifted
	reserved_targets.clear()
	snap_bounce_t = 1.0
	audio.play_mag_snap()
	hit_shake = maxf(hit_shake, 0.22)
	_spawn_shockwave_ring(model_tilt_root.global_position, Color(1.0, 0.54, 0.12), 3.6)
	callout_banner.emit("🧲 啪！磁吸合拢！拼出大片连色区", Color(1.0, 0.54, 0.12))


func _advance_or_retire_slot(s_idx: int) -> void:
	var sl = slots[s_idx]
	if sl == null:
		return
	# Dual-Color Cannon switches seamlessly to second color (GDD 3.1)!
	if int(sl.get("ch2", -1)) != -1 and int(sl.get("ammo2", 0)) > 0:
		sl["ch"] = int(sl["ch2"])
		sl["ammo"] = int(sl["ammo2"])
		sl["ch2"] = -1
		sl["ammo2"] = 0
		sl["cooldown"] = 0.08
		audio.play_slot_in()
		callout_banner.emit("⇄ 双色炮切换第二色！", FusePalette.get_color(int(sl["ch"])))
		_check_and_trigger_adjacent_fuse(s_idx)
		state_updated.emit()
		return

	slots[s_idx] = null
	slot_clear_streak += 1
	audio.play_slot_clear(slot_clear_streak)
	# Spinner Layer triggers 90° turn whenever a cannon finishes!
	if spinner_y_min >= -50 and not celebrating_win:
		_rotate_spinner_layer_90()
	state_updated.emit()


func _retire_exhausted_channels() -> void:
	var limit: int = get_active_slot_limit()
	for s_idx in range(limit):
		if slots[s_idx] != null:
			var ch: int = int(slots[s_idx]["ch"])
			if _count_remaining_for_color(ch) == 0 and not _has_pending_for_color(ch):
				_advance_or_retire_slot(s_idx)

	# Also sweep queue cannons whose primary color no longer exists (and have no live ch2)
	var swept: bool = false
	for c in range(NUM_COLS):
		for r in range(columns[c].size() - 1, -1, -1):
			var it: Dictionary = columns[c][r]
			var ch1: int = int(it["ch"])
			var ch2: int = int(it.get("ch2", -1))
			if _count_remaining_for_color(ch1) == 0 and not _has_pending_for_color(ch1):
				if ch2 != -1 and _count_remaining_for_color(ch2) > 0:
					it["ch"] = ch2
					it["ammo"] = int(it["ammo2"])
					it["ch2"] = -1
					it["ammo2"] = 0
				else:
					columns[c].remove_at(r)
				swept = true
	if swept:
		state_updated.emit()


# ==============================================================================
# SAFE CENTERED BOOSTERS (Magnet / Shockwave / Confirmed Extra Slot / Continue)
# ==============================================================================
func use_booster_magnet() -> bool:
	if voxels.is_empty():
		return false
	var target_slot: int = -1
	var target_ch: int = -1
	var limit: int = get_active_slot_limit()
	for i in range(limit):
		if slots[i] != null:
			target_slot = i
			target_ch = int(slots[i]["ch"])
			break
	if target_ch == -1:
		for p: Vector3i in voxels.keys():
			if not bool(voxels[p]["core"]):
				target_ch = int(voxels[p]["ch"])
				break
	if target_ch == -1:
		return false

	var need: int = int(slots[target_slot]["ammo"]) if target_slot >= 0 else 18
	var popped: int = 0
	var list: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if int(voxels[p]["ch"]) == target_ch:
			list.append(p)
			if list.size() >= need:
				break

	for p in list:
		if voxels.has(p):
			voxels[p]["locked"] = false
			_destroy_voxel(p, false, true)
			popped += 1

	if target_slot >= 0 and slots[target_slot] != null:
		_advance_or_retire_slot(target_slot)

	if has_magnetic_snap:
		_check_magnetic_snap()
	_recompute_exposed_and_ao()
	multimesh_dirty = true
	_retire_exhausted_channels()
	_emit_stats()
	audio.play_mag_snap()
	callout_banner.emit("🧲 磁铁强吸！瞬清 ×%d 块腾出活槽" % popped, FusePalette.get_color(target_ch))
	if voxels.is_empty() and not celebrating_win:
		_trigger_final_smash_victory()
	state_updated.emit()
	return true


func use_booster_shockwave() -> bool:
	if voxels.is_empty():
		return false
	# Pick a Pulse Core if present, otherwise the cube closest to sculpture center!
	var epic: Vector3i = Vector3i.ZERO
	var found_core: bool = false
	for p: Vector3i in voxels.keys():
		if bool(voxels[p]["core"]):
			epic = p
			found_core = true
			break
	if not found_core:
		var best_d: float = 9999.0
		for p: Vector3i in voxels.keys():
			var dist: float = (Vector3(p) - center_offset).length()
			if dist < best_d:
				best_d = dist
				epic = p

	_detonate_pulse_core(epic, _grid_to_world(epic))
	_retire_exhausted_channels()
	_emit_stats()
	if voxels.is_empty() and not celebrating_win:
		_trigger_final_smash_victory()
	state_updated.emit()
	return true


func unlock_extra_slot() -> bool:
	if extra_slot_unlocked:
		return false
	extra_slot_unlocked = true
	auto_scanning = false
	jam_grace_timer = 0.0
	audio.play_fuse_arc()
	callout_banner.emit("➕ 临时第 6 槽位已开启！", Color(0.08, 0.72, 0.40))
	state_updated.emit()
	return true


func execute_fair_continue() -> void:
	# Fair Continue (360 coins): Unlocks 6th slot AND clears 2 jammed slots' matching blocks!
	extra_slot_unlocked = true
	var cleared_slots: int = 0
	for i in range(MAX_SLOTS):
		if slots[i] != null and cleared_slots < 2:
			var ch: int = int(slots[i]["ch"])
			var need: int = int(slots[i]["ammo"])
			var to_pop: Array[Vector3i] = []
			for p: Vector3i in voxels.keys():
				if int(voxels[p]["ch"]) == ch:
					to_pop.append(p)
					if to_pop.size() >= need:
						break
			for p in to_pop:
				if voxels.has(p):
					_destroy_voxel(p, false, true)
			_advance_or_retire_slot(i)
			cleared_slots += 1
	_recompute_exposed_and_ao()
	multimesh_dirty = true
	_retire_exhausted_channels()
	_emit_stats()
	audio.play_pulse_boom()
	auto_scanning = false
	jam_grace_timer = 0.0
	if voxels.is_empty() and not celebrating_win:
		_trigger_final_smash_victory()
	state_updated.emit()


# ==============================================================================
# FINAL SMASH SLOW-MO & VICTORY (GDD 5.3)
# ==============================================================================
func _trigger_final_smash_victory() -> void:
	celebrating_win = true
	_trigger_slowmo(0.15, 0.35)
	hit_shake = 0.28
	_spawn_shockwave_ring(model_tilt_root.global_position, Color(0.11, 0.65, 1.0), 5.0)
	audio.play_victory()

	for i in range(MAX_SLOTS):
		slots[i] = null
	for c in range(NUM_COLS):
		columns[c].clear()
	state_updated.emit()

	# Healthy 6:1 Economy (GDD 6): Base 50 coins + 10-30 Pulse Core bonus!
	var base_coins: int = 50
	var clamped_core_bonus: int = clampi(core_bonus_coins, 0, 30)
	level_completed.emit({
		"level": int(level_data["level"]),
		"title": String(level_data["title"]),
		"base_coins": base_coins,
		"core_bonus": clamped_core_bonus,
		"total_coins": base_coins + clamped_core_bonus,
		"fuses": fuse_count_this_level,
		"cores": pulse_cores_blasted,
		"max_combo": max_combo,
	})


func _trigger_slowmo(real_dur: float, scale_val: float) -> void:
	Engine.time_scale = scale_val
	slowmo_real_remaining = maxf(slowmo_real_remaining, real_dur)


# ==============================================================================
# DEBRIS OBJECT POOL (40 cubes max, 0.75s flight -> scale 0 recycle, GDD 5.2!)
# ==============================================================================
func _spawn_debris(world_pos: Vector3, col: Color, speed_mult: float = 1.0, dir_hint: Vector3 = Vector3.ZERO) -> void:
	var db: Dictionary = debris_pool[debris_cursor]
	debris_cursor = (debris_cursor + 1) % DEBRIS_POOL_SIZE
	var mi: MeshInstance3D = db["node"]
	(db["mat"] as StandardMaterial3D).albedo_color = col
	mi.global_position = world_pos
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	var bs: float = voxel_step * randf_range(0.82, 1.05)
	mi.scale = Vector3.ONE * bs
	mi.visible = true

	var out_dir: Vector3 = dir_hint
	if out_dir.length_squared() < 0.05:
		out_dir = (world_pos - model_tilt_root.global_position).normalized()
	if out_dir.length_squared() < 0.05:
		out_dir = Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized()

	var rand_spread := Vector3(randf_range(-0.6, 0.6), randf_range(0.1, 0.85), randf_range(-0.6, 0.6))
	db["vel"] = (out_dir + rand_spread).normalized() * randf_range(3.8, 6.8) * speed_mult
	db["rot_vel"] = Vector3(randf_range(-11, 11), randf_range(-11, 11), randf_range(-11, 11))
	db["life"] = 0.75
	db["max_life"] = 0.75
	db["base_scale"] = bs
	db["active"] = true


func _spawn_shockwave_ring(world_pos: Vector3, col: Color, max_s: float) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.44
	torus.outer_radius = 0.56
	torus.rings = 28
	torus.ring_segments = 8
	ring.mesh = torus
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(col.r, col.g, col.b, 0.92)
	ring.material_override = sm
	fx_root.add_child(ring)
	ring.global_position = world_pos
	ring.scale = Vector3.ONE * 0.25
	shock_rings.append({"node": ring, "mat": sm, "t": 0.0, "dur": 0.36, "max_s": max_s})


func _process_debris_and_rings(delta: float) -> void:
	for db in debris_pool:
		if not bool(db["active"]):
			continue
		db["life"] = float(db["life"]) - delta
		var mi: MeshInstance3D = db["node"]
		if float(db["life"]) <= 0.0:
			db["active"] = false
			mi.visible = false
			continue
		db["vel"] = Vector3(db["vel"]) + Vector3(0.0, -14.5 * delta, 0.0)
		mi.global_position += Vector3(db["vel"]) * delta
		mi.rotation += Vector3(db["rot_vel"]) * delta
		var u: float = clampf(float(db["life"]) / float(db["max_life"]), 0.0, 1.0)
		var sc: float = float(db["base_scale"]) * smoothstep(0.0, 0.38, u)
		mi.scale = Vector3.ONE * maxf(0.001, sc)

	for i in range(shock_rings.size() - 1, -1, -1):
		var r: Dictionary = shock_rings[i]
		r["t"] = float(r["t"]) + delta
		var u: float = clampf(float(r["t"]) / float(r["dur"]), 0.0, 1.0)
		if is_instance_valid(r["node"]):
			r["node"].scale = Vector3.ONE * lerpf(0.25, float(r["max_s"]), 1.0 - pow(1.0 - u, 3.0))
			if camera:
				r["node"].look_at(camera.global_position, Vector3.UP)
				r["node"].rotate_object_local(Vector3.RIGHT, PI * 0.5)
			var c: Color = (r["mat"] as StandardMaterial3D).albedo_color
			c.a = (1.0 - u) * 0.90
			(r["mat"] as StandardMaterial3D).albedo_color = c
		if u >= 1.0:
			if is_instance_valid(r["node"]):
				r["node"].queue_free()
			shock_rings.remove_at(i)


# ==============================================================================
# MULTIMESH REBUILD (Constant 1 Draw Call for Entire Sculpture!)
# ==============================================================================
func _recompute_exposed_and_ao() -> void:
	exposed_set.clear()
	for ep in FuseSolver.compute_exposed_positions(voxels):
		exposed_set[ep] = true

	const AO_OFFSETS: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1),
		Vector3i(1,1,0), Vector3i(-1,1,0), Vector3i(0,1,1), Vector3i(0,1,-1),
	]
	for p: Vector3i in voxels.keys():
		var occ: float = 0.0
		for d in AO_OFFSETS:
			if voxels.has(p + d):
				occ += 1.0 if (abs(d.x) + abs(d.y) + abs(d.z) == 1) else 0.55
		voxels[p]["ao"] = clampf(1.0 - occ * 0.055, 0.54, 1.0)


func _rebuild_multimeshes() -> void:
	var normal_list: Array[Vector3i] = []
	var core_list: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if bool(voxels[p]["core"]):
			core_list.append(p)
		else:
			normal_list.append(p)

	var mm: MultiMesh = main_multimesh.multimesh
	mm.instance_count = normal_list.size()
	var sc := Basis.from_scale(Vector3.ONE * voxel_step)

	for i in range(normal_list.size()):
		var p: Vector3i = normal_list[i]
		var d: Dictionary = voxels[p]
		var ch: int = int(d["ch"])
		var local_pos: Vector3 = (Vector3(p) - center_offset) * voxel_step
		mm.set_instance_transform(i, Transform3D(sc, local_pos))
		mm.set_instance_color(i, FusePalette.get_color(ch))
		var flag: float = 0.0
		if bool(d["locked"]):
			flag = 3.0
		elif p.y >= spinner_y_min and p.y <= spinner_y_max:
			flag = 2.0
		mm.set_instance_custom_data(i, Color(
			float(ch),
			float(d["hit_t"]),
			flag,
			float(d["ao"])
		))

	var cmm: MultiMesh = core_multimesh.multimesh
	cmm.instance_count = core_list.size()
	var csc := Basis.from_scale(Vector3.ONE * (voxel_step * 1.48))
	for i in range(core_list.size()):
		var p: Vector3i = core_list[i]
		var local_pos: Vector3 = (Vector3(p) - center_offset) * voxel_step
		cmm.set_instance_transform(i, Transform3D(csc, local_pos))


func _grid_to_world(p: Vector3i) -> Vector3:
	return orbit_pivot.to_global((Vector3(p) - center_offset) * voxel_step)


func _count_remaining_for_color(ch: int) -> int:
	var n: int = 0
	for p: Vector3i in voxels.keys():
		if bool(voxels[p]["core"]) or int(voxels[p]["ch"]) == ch:
			n += 1
	return n


func _has_pending_for_color(ch: int) -> bool:
	for h in pending_hits:
		if int(h["ch"]) == ch:
			return true
	return false


func _are_all_slots_filled_and_idle() -> bool:
	var limit: int = get_active_slot_limit()
	for i in range(limit):
		if slots[i] == null:
			return false
		var ch: int = int(slots[i]["ch"])
		if _pick_best_target(ch, -0.15) != Vector3i(999, 999, 999):
			return false
	return true


func _emit_stats() -> void:
	var cleared: int = maxi(0, total_voxels - voxels.size())
	stats_changed.emit(cleared, total_voxels, combo_count)
