class_name FuseStage
extends Node3D

## V1.0 Store-Ready 3D Arcade Voxel Engine (RD-SPEC-02 & RD-SPEC-03 Compliant)
##  - Strict 7-State Finite State Machine:
##      INIT_LOAD, PLAYING_IDLE, DOCK_INSERT_AND_FUSE, FIRING_LOOP,
##      AUTO_SCAN_FAILSAFE, RESCUE_PROMPT, VICTORY_SETTLE
##  - 1 Draw Call MultiMeshInstance3D using beveled_cube.glb (exact 92 tris, 2-seg bevel!)
##  - Real 3D pulse_core.glb & chain_lock_cage.glb MultiMeshes
##  - Strict 40-cube Debris Object Pool (0.75s flight -> scale 0 recycle, zero GC!)
##  - 1-Tier Super Cannon (1.2x ammo, 1.8x rate, 2-layer pierce) + 2-Tier Mega Cannon (2.2x rate, 3-layer pierce)
##  - 360° Auto-Scan Failsafe (1.2s smooth spin, 15° sampling) + 5 Mechanics + 3 In-Game & 2 Pre-Level Boosters!

enum StageState {
	INIT_LOAD,
	PLAYING_IDLE,
	DOCK_INSERT_AND_FUSE,
	FIRING_LOOP,
	AUTO_SCAN_FAILSAFE,
	RESCUE_PROMPT,
	VICTORY_SETTLE,
}

signal state_changed(new_state: int)
signal stats_changed(cleared: int, total: int, combo: int)
signal dock_updated()
signal cannon_inserted_fx(col_idx: int, slot_idx: int, color_id: int, ammo: int)
signal fuse_triggered(left_slot: int, right_slot: int, color_id: int, new_ammo: int, tier: int)
signal shot_fired(slot_idx: int, target_screen_pos: Vector2, color_id: int, tier: int)
signal voxel_cleared_fx(screen_pos: Vector2, color_id: int, is_core: bool)
signal pulse_core_detonated(screen_pos: Vector2, blasted_count: int, bonus_coins: int)
signal callout_banner(text: String, accent: Color)
signal level_completed(summary: Dictionary)
signal slots_jammed(remaining_cubes: int, dock_snapshot: Array)
signal first_rotate_detected()

const BASE_SLOTS: int = 5
const MAX_SLOTS: int = 6
const DEBRIS_POOL_SIZE: int = 40
const BASE_FIRE_RATE: float = 6.0 # RD-SPEC-02 1.2: 6 shots/sec -> Super 10.8/s -> Mega 13.2/s!
const DIRS6: Array[Vector3i] = [
	Vector3i(1,0,0), Vector3i(-1,0,0),
	Vector3i(0,1,0), Vector3i(0,-1,0),
	Vector3i(0,0,1), Vector3i(0,0,-1),
]

var stage_state: int = StageState.INIT_LOAD
var camera: Camera3D
var audio: ArcadeAudio

var model_tilt_root: Node3D
var orbit_pivot: Node3D
var main_multimesh: MultiMeshInstance3D
var core_multimesh: MultiMeshInstance3D
var chain_multimesh: MultiMeshInstance3D
var spinner_ring_root: Node3D
var fx_root: Node3D

var plastic_mat: ShaderMaterial
var core_mat: ShaderMaterial
var chain_mat: StandardMaterial3D
var cube_mesh: Mesh
var core_mesh: Mesh
var chain_mesh: Mesh

var level_json: Dictionary = {}
var voxels: Dictionary = {} # Vector3i -> {cid, locked, core, hit_t, ao}
var exposed_set: Dictionary = {}
var reserved_targets: Dictionary = {}
var total_voxels: int = 0
var voxel_step: float = 0.36
var center_offset := Vector3.ZERO
var bound_radius: float = 2.6

var spinner_layers: Array[int] = []
var has_magnetic_snap: bool = false
var hidden_queue_pct: float = 0.0
var num_cols: int = 5

# Dock slots: null or {cid, ammo, tier(0=basic,1=super,2=mega), cooldown, locked_for_fuse}
var slots: Array = []
var extra_slot_unlocked: bool = false
var columns: Array = [] # Array of Array[Dictionary {color_id, ammo, hidden}]
var forced_first_tap_col: int = -1

var debris_pool: Array[Dictionary] = []
var debris_cursor: int = 0
var shock_rings: Array[Dictionary] = []
var pending_hits: Array[Dictionary] = []

# Camera / Orbit / Interaction (RD-SPEC-02 1.1 exact constraints)
var yaw: float = -0.38
var pitch: float = 0.0
var yaw_vel: float = 0.0
var pitch_vel: float = 0.0
var zoom_scale: float = 1.0 # Clamped 0.85x - 1.25x
var is_dragging: bool = false
var total_user_rot_rad: float = 0.0
var reported_first_rotate: bool = false

# Timers & Telemetry Stats
var insert_fuse_timer: float = 0.0
var auto_scan_idle_t: float = 0.0
var auto_scan_elapsed: float = 0.0
var auto_scan_start_yaw: float = 0.0
var auto_scan_last_sector: int = -1
var slowmo_real_rem: float = 0.0
var hit_shake: float = 0.0
var snap_bounce_t: float = 0.0
var spinner_visual_rot_rem: float = 0.0

var level_start_ms: int = 0
var shots_fired_total: int = 0
var combo_count: int = 0
var combo_timer: float = 0.0
var max_combo: int = 0
var fuse_count: int = 0
var cores_popped: int = 0
var core_bonus_coins: int = 0
var max_single_core_blast: int = 0
var boosters_used_count: int = 0
var warned_4_slots: bool = false

var multimesh_dirty: bool = false
var stage_active: bool = true
var show_symbols: bool = false


func setup(p_camera: Camera3D, p_audio: ArcadeAudio) -> void:
	camera = p_camera
	audio = p_audio

	# Load Store-Ready Blender/glTF 2.0 Production Meshes (RD-SPEC-03 2.1!)
	cube_mesh = _extract_glb_mesh("res://assets/fuse/models/beveled_cube.glb")
	if cube_mesh == null:
		cube_mesh = BeveledCubeBuilder.create_beveled_cube(0.488, 0.12)
	core_mesh = _extract_glb_mesh("res://assets/fuse/models/pulse_core.glb")
	if core_mesh == null:
		core_mesh = BeveledCubeBuilder.create_core_sphere(0.56)
	chain_mesh = _extract_glb_mesh("res://assets/fuse/models/chain_lock_cage.glb")

	plastic_mat = ShaderMaterial.new()
	plastic_mat.shader = preload("res://shaders/arcade_plastic.gdshader")
	core_mat = ShaderMaterial.new()
	core_mat.shader = preload("res://shaders/pulse_core.gdshader")

	chain_mat = StandardMaterial3D.new()
	chain_mat.albedo_color = Color(0.20, 0.25, 0.34)
	chain_mat.metallic = 0.85
	chain_mat.roughness = 0.28

	model_tilt_root = Node3D.new()
	model_tilt_root.name = "ModelTiltRoot"
	model_tilt_root.position = Vector3(0.0, 1.55, 0.0)
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

	core_multimesh = MultiMeshInstance3D.new()
	core_multimesh.name = "PulseCoreMultiMesh"
	var cmm := MultiMesh.new()
	cmm.transform_format = MultiMesh.TRANSFORM_3D
	cmm.mesh = core_mesh
	core_multimesh.multimesh = cmm
	core_multimesh.material_override = core_mat
	core_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orbit_pivot.add_child(core_multimesh)

	chain_multimesh = MultiMeshInstance3D.new()
	chain_multimesh.name = "ChainLockMultiMesh"
	var chmm := MultiMesh.new()
	chmm.transform_format = MultiMesh.TRANSFORM_3D
	if chain_mesh != null:
		chmm.mesh = chain_mesh
	chain_multimesh.multimesh = chmm
	chain_multimesh.material_override = chain_mat
	chain_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orbit_pivot.add_child(chain_multimesh)

	spinner_ring_root = Node3D.new()
	spinner_ring_root.name = "SpinnerRings"
	orbit_pivot.add_child(spinner_ring_root)

	fx_root = Node3D.new()
	fx_root.name = "FXRoot"
	add_child(fx_root)

	# Pre-allocate strict 40-cube Debris Object Pool (RD-SPEC-03 2.2!)
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


func _extract_glb_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path)
	if ps == null:
		return null
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


func _set_state(new_st: int) -> void:
	if stage_state == new_st:
		return
	stage_state = new_st
	state_changed.emit(new_st)


func set_symbol_mode(enabled: bool) -> void:
	show_symbols = enabled
	if plastic_mat:
		plastic_mat.set_shader_parameter("u_show_symbols", 1.0 if enabled else 0.0)


# ==============================================================================
# INIT_LOAD: Parse V1.0 JSON Blueprint + Apply Pre-Level Boosters & FTUE!
# ==============================================================================
func load_level_from_json(data: Dictionary, pre_super: bool = false, pre_double_core: bool = false) -> void:
	_set_state(StageState.INIT_LOAD)
	_reset_transient()
	level_json = data

	var mech: Dictionary = data.get("mechanics", {})
	spinner_layers.clear()
	for sy in mech.get("spinner_layers", []):
		spinner_layers.append(int(sy))
	has_magnetic_snap = bool(mech.get("magnetic_snap_enabled", false))
	hidden_queue_pct = float(data.get("hidden_queue_pct", 0.0))

	var raw_voxels: Array = data.get("voxels", [])
	var min_v := Vector3(999, 999, 999)
	var max_v := Vector3(-999, -999, -999)
	for entry in raw_voxels:
		var p := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
		var cid: int = clampi(int(entry[3]), 1, 6)
		var flg: int = int(entry[4]) if entry.size() > 4 else 0
		voxels[p] = {
			"cid": cid,
			"locked": (flg == 3),
			"core": (flg == 1),
			"hit_t": -10.0,
			"ao": 1.0,
		}
		min_v.x = minf(min_v.x, float(p.x))
		min_v.y = minf(min_v.y, float(p.y))
		min_v.z = minf(min_v.z, float(p.z))
		max_v.x = maxf(max_v.x, float(p.x))
		max_v.y = maxf(max_v.y, float(p.y))
		max_v.z = maxf(max_v.z, float(p.z))

	# Pre-Level Booster: Double Pulse Core (injects 1 extra glowing golden core inside sculpture!)
	if pre_double_core and voxels.size() > 12:
		var best_p := Vector3i.ZERO
		var best_dist: float = 9999.0
		var mid_v: Vector3 = (min_v + max_v) * 0.5
		for p: Vector3i in voxels.keys():
			if not bool(voxels[p]["core"]):
				var d: float = (Vector3(p) - mid_v).length()
				if d < best_dist:
					best_dist = d
					best_p = p
		voxels[best_p]["core"] = true
		voxels[best_p]["locked"] = false

	center_offset = (min_v + max_v) * 0.5
	var span_max: float = maxf(max_v.x - min_v.x + 1.0, maxf(max_v.y - min_v.y + 1.0, max_v.z - min_v.z + 1.0))
	voxel_step = clampf(4.2 / maxf(span_max, 5.0), 0.28, 0.56)

	var max_r: float = 1.6
	for p: Vector3i in voxels.keys():
		var lp: Vector3 = (Vector3(p) - center_offset) * voxel_step
		max_r = maxf(max_r, lp.length() + voxel_step * 0.65)
	bound_radius = max_r
	total_voxels = voxels.size()

	# Heroic 3/4 tilt angle (RD-SPEC-03 1.1: 28° 3/4 isometric appeal!)
	var model_id: String = String(data.get("model_id", ""))
	if model_id.contains("rocket") or model_id.contains("shuttle"):
		model_tilt_root.rotation_degrees = Vector3(10.0, 0.0, -22.0)
	else:
		model_tilt_root.rotation_degrees = Vector3(8.0, 0.0, -5.0)
	yaw = deg_to_rad(-24.0)
	pitch = 0.0
	yaw_vel = 0.0
	pitch_vel = 0.0
	zoom_scale = 1.0

	# Load shooter queues from JSON + apply hidden_queue_pct fog on deep rows!
	var src_queues: Array = data.get("shooter_queues", [])
	num_cols = clampi(src_queues.size(), 3, 5)
	columns.clear()
	var total_q_items: int = 0
	for c_arr in src_queues:
		var col_list: Array = []
		for it in c_arr:
			col_list.append({
				"color_id": clampi(int(it["color_id"]), 1, 6),
				"ammo": int(it["ammo"]),
				"hidden": false,
			})
			total_q_items += 1
		columns.append(col_list)

	# Mark deepest hidden_queue_pct cannons as '?' mystery fog (revealed as they move up to Row 0/1!)
	if hidden_queue_pct > 0.01:
		var target_hidden: int = int(round(float(total_q_items) * hidden_queue_pct))
		var hid_cnt: int = 0
		for depth_row in range(8, 1, -1):
			for c_i in range(columns.size()):
				if hid_cnt >= target_hidden:
					break
				if depth_row < columns[c_i].size():
					columns[c_i][depth_row]["hidden"] = true
					hid_cnt += 1

	# FTUE Preloaded Dock (e.g. Lv.1 Cobalt Blue 14 in Slot 0 + forced_first_tap_column = 0!)
	var ftue: Dictionary = data.get("ftue_script", {})
	forced_first_tap_col = int(ftue.get("forced_first_tap_column", -1)) if bool(ftue.get("enabled", false)) else -1
	for pre in ftue.get("preloaded_dock", []):
		var s_i: int = clampi(int(pre["slot_index"]), 0, BASE_SLOTS - 1)
		slots[s_i] = {
			"cid": clampi(int(pre["color_id"]), 1, 6),
			"ammo": int(pre["ammo"]),
			"tier": 0,
			"cooldown": 999.0 if forced_first_tap_col >= 0 else 0.15, # Wait for Lv.1 first fuse tap!
			"locked_for_fuse": false,
		}

	# Pre-Level Booster: Charged Super Cannon in Slot 0 (or next empty slot if FTUE preloaded!)
	if pre_super:
		var target_s: int = 0 if slots[0] == null else 1
		var top_cid: int = int(columns[0][0]["color_id"]) if not columns[0].is_empty() else 1
		slots[target_s] = {
			"cid": top_cid,
			"ammo": 22,
			"tier": 1,
			"cooldown": 0.15,
			"locked_for_fuse": false,
		}

	_build_spinner_ring_visuals()
	_recompute_exposed_and_ao()
	_rebuild_multimeshes()
	level_start_ms = Time.get_ticks_msec()
	_set_state(StageState.PLAYING_IDLE)
	stats_changed.emit(0, total_voxels, 0)
	dock_updated.emit()


func _reset_transient() -> void:
	Engine.time_scale = 1.0
	slowmo_real_rem = 0.0
	voxels.clear()
	exposed_set.clear()
	reserved_targets.clear()
	pending_hits.clear()
	for i in range(MAX_SLOTS):
		slots[i] = null
	extra_slot_unlocked = false
	forced_first_tap_col = -1
	insert_fuse_timer = 0.0
	auto_scan_idle_t = 0.0
	auto_scan_elapsed = 0.0
	auto_scan_last_sector = -1
	total_user_rot_rad = 0.0
	reported_first_rotate = false
	shots_fired_total = 0
	combo_count = 0
	combo_timer = 0.0
	max_combo = 0
	fuse_count = 0
	cores_popped = 0
	core_bonus_coins = 0
	max_single_core_blast = 0
	boosters_used_count = 0
	warned_4_slots = false
	hit_shake = 0.0
	snap_bounce_t = 0.0
	spinner_visual_rot_rem = 0.0

	for db in debris_pool:
		db["active"] = false
		(db["node"] as MeshInstance3D).visible = false
	for r in shock_rings:
		if is_instance_valid(r["node"]):
			r["node"].queue_free()
	shock_rings.clear()
	for c in spinner_ring_root.get_children():
		c.queue_free()


func _build_spinner_ring_visuals() -> void:
	for sy in spinner_layers:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var rad: float = bound_radius * 0.92
		torus.inner_radius = maxf(0.8, rad - 0.035)
		torus.outer_radius = rad + 0.035
		torus.rings = 36
		torus.ring_segments = 8
		ring.mesh = torus
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color = Color(1.0, 1.0, 1.0, 0.78)
		ring.material_override = sm
		ring.position = Vector3(0.0, (float(sy) - center_offset.y) * voxel_step, 0.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spinner_ring_root.add_child(ring)


func get_active_slot_limit() -> int:
	return MAX_SLOTS if extra_slot_unlocked else BASE_SLOTS


func get_occupied_slot_count() -> int:
	var n: int = 0
	for i in range(get_active_slot_limit()):
		if slots[i] != null:
			n += 1
	return n


# ==============================================================================
# INTERACTION: Exact 210° Full-Width Swipe, 0.88/frame Decay, 0.85x-1.25x Zoom!
# ==============================================================================
func apply_orbit_drag(rel: Vector2) -> void:
	if stage_state in [StageState.AUTO_SCAN_FAILSAFE, StageState.RESCUE_PROMPT, StageState.VICTORY_SETTLE]:
		return
	is_dragging = true
	var vp_w: float = maxf(320.0, get_viewport().get_visible_rect().size.x)
	# RD-SPEC-02 1.1: Full screen width drag = 210 degrees!
	var d_yaw: float = (rel.x / vp_w) * deg_to_rad(210.0)
	var d_pitch: float = (rel.y / vp_w) * deg_to_rad(130.0)
	yaw += d_yaw
	pitch = clampf(pitch + d_pitch, -0.56, 0.56)
	yaw_vel = clampf(d_yaw, -0.22, 0.22)
	pitch_vel = clampf(d_pitch, -0.14, 0.14)
	total_user_rot_rad += absf(d_yaw)
	if not reported_first_rotate and total_user_rot_rad > 0.65:
		reported_first_rotate = true
		first_rotate_detected.emit()


func end_orbit_drag() -> void:
	is_dragging = false


func apply_zoom_factor(mult: float) -> void:
	zoom_scale = clampf(zoom_scale * mult, 0.85, 1.25)


# ==============================================================================
# DOCK_INSERT_AND_FUSE: 0.18s Bezier Fly-In + 1-Tier Super & 2-Tier Mega Fuse!
# ==============================================================================
func try_pick_column(col_idx: int) -> bool:
	if stage_state in [StageState.INIT_LOAD, StageState.AUTO_SCAN_FAILSAFE, StageState.RESCUE_PROMPT, StageState.VICTORY_SETTLE]:
		return false
	if col_idx < 0 or col_idx >= columns.size() or columns[col_idx].is_empty():
		return false
	# Lv.1 FTUE forced first tap constraint!
	if forced_first_tap_col >= 0 and col_idx != forced_first_tap_col:
		return false

	var limit: int = get_active_slot_limit()
	var free_idx: int = -1
	for i in range(limit):
		if slots[i] == null:
			free_idx = i
			break
	if free_idx == -1:
		hit_shake = 0.10
		audio.play_slot_warn()
		return false

	var item: Dictionary = columns[col_idx].pop_front()
	# Reveal next visible rows in that column
	for r in range(mini(2, columns[col_idx].size())):
		columns[col_idx][r]["hidden"] = false

	# Release Lv.1 FTUE hold after first tap!
	var was_ftue_fuse: bool = (forced_first_tap_col >= 0)
	if was_ftue_fuse:
		forced_first_tap_col = -1
		if slots[0] != null:
			slots[0]["cooldown"] = 0.05

	var cid: int = int(item["color_id"])
	var ammo: int = int(item["ammo"])
	slots[free_idx] = {
		"cid": cid,
		"ammo": ammo,
		"tier": 0,
		"cooldown": 0.18, # Match 0.18s Bezier fly-in before firing!
		"locked_for_fuse": false,
	}
	audio.play_slot_in()
	auto_scan_idle_t = 0.0
	cannon_inserted_fx.emit(col_idx, free_idx, cid, ammo)
	_set_state(StageState.DOCK_INSERT_AND_FUSE)
	insert_fuse_timer = 0.18

	# Check immediate Merge-to-Fire (Slot i-1 priority, then Slot i+1!) + 2-Tier Mega Chain!
	var merged: bool = _resolve_adjacent_fuses(free_idx)
	if merged:
		insert_fuse_timer = 0.28 # 0.28s electric arc merge lock!

	# 4/5 Slot warning sound (RD-SPEC-03 3.2!)
	if get_occupied_slot_count() == limit - 1 and not warned_4_slots:
		warned_4_slots = true
		audio.play_slot_warn()
	elif get_occupied_slot_count() < limit - 1:
		warned_4_slots = false

	_retire_exhausted_channels()
	dock_updated.emit()
	return true


func _resolve_adjacent_fuses(focus_idx: int) -> bool:
	var limit: int = get_active_slot_limit()
	var any_merged: bool = false
	var keep_checking: bool = true

	while keep_checking:
		keep_checking = false
		var check_pairs: Array[Vector2i] = []
		# RD-SPEC-02 1.2: Priority slot[i-1], secondary slot[i+1]!
		if focus_idx > 0 and focus_idx < limit:
			check_pairs.append(Vector2i(focus_idx - 1, focus_idx))
		if focus_idx >= 0 and focus_idx + 1 < limit:
			check_pairs.append(Vector2i(focus_idx, focus_idx + 1))
		for i in range(limit - 1):
			var pr := Vector2i(i, i + 1)
			if not check_pairs.has(pr):
				check_pairs.append(pr)

		for pr in check_pairs:
			var a: int = pr.x
			var b: int = pr.y
			if slots[a] != null and slots[b] != null:
				if int(slots[a]["cid"]) == int(slots[b]["cid"]):
					var cur_tier_max: int = maxi(int(slots[a]["tier"]), int(slots[b]["tier"]))
					if cur_tier_max >= 2:
						continue # RD-SPEC-02 1.2: Cap at Tier 2 Mega Cannon!
					var new_tier: int = mini(2, cur_tier_max + 1)
					var cid: int = int(slots[a]["cid"])
					var sum_a: int = int(slots[a]["ammo"]) + int(slots[b]["ammo"])
					var new_ammo: int = int(ceil(float(sum_a) * 1.2))
					var bonus_a: int = new_ammo - sum_a

					slots[a] = {
						"cid": cid,
						"ammo": new_ammo,
						"tier": new_tier,
						"cooldown": 0.28,
						"locked_for_fuse": true,
					}
					slots[b] = null
					_compact_slots_left()

					fuse_count += 1
					audio.play_fuse_arc(new_tier)
					hit_shake = maxf(hit_shake, 0.22 if new_tier >= 2 else 0.14)
					if new_tier >= 2:
						Input.vibrate_handheld(45)
						callout_banner.emit("⚡⚡ 终极 MEGA 合炮！弹药 +%d · 3层穿透！" % bonus_a, Color(0.55, 0.36, 0.96))
					else:
						callout_banner.emit("⚡ 同色合炮！弹药 +%d · 1.8×射速 · 双层穿透！" % bonus_a, Color(0.11, 0.65, 1.0))

					fuse_triggered.emit(a, b, cid, new_ammo, new_tier)
					any_merged = true
					keep_checking = true
					focus_idx = a
					break

	return any_merged


func _compact_slots_left() -> void:
	# RD-SPEC-02 1.2: Compact active dock slots smoothly to the left after merge!
	var limit: int = get_active_slot_limit()
	var compact: Array = []
	for i in range(limit):
		if slots[i] != null:
			compact.append(slots[i])
	for i in range(limit):
		slots[i] = compact[i] if i < compact.size() else null


# ==============================================================================
# FRAME LOOP: FSM Transitions, Orbit Damping (0.88/frame), Firing & AutoScan!
# ==============================================================================
func _process(delta: float) -> void:
	if not stage_active:
		return

	# Real-time Slow-Mo timer (0.15s @ Engine.time_scale = 0.35)
	if slowmo_real_rem > 0.0:
		var real_dt: float = delta / maxf(Engine.time_scale, 0.05)
		slowmo_real_rem -= real_dt
		if slowmo_real_rem <= 0.0:
			Engine.time_scale = 1.0

	var now_sec: float = Time.get_ticks_msec() * 0.001
	plastic_mat.set_shader_parameter("u_clock", now_sec)
	core_mat.set_shader_parameter("u_clock", now_sec)

	# State-driven rotation & animation
	if stage_state == StageState.VICTORY_SETTLE:
		yaw += delta * 1.45
		pitch = lerpf(pitch, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	elif stage_state == StageState.AUTO_SCAN_FAILSAFE:
		# RD-SPEC-02 1.1: Smooth 360° scan over 1.2s sampling every 15°!
		auto_scan_elapsed += delta
		var frac: float = clampf(auto_scan_elapsed / 1.2, 0.0, 1.0)
		yaw = auto_scan_start_yaw + frac * TAU
		pitch = lerpf(pitch, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		var sector: int = int(floor(frac * 24.0)) # 24 sectors = 15° steps!
		if sector != auto_scan_last_sector:
			auto_scan_last_sector = sector
			if _any_slot_has_visible_target(-0.20):
				_set_state(StageState.FIRING_LOOP)
				auto_scan_idle_t = 0.0
		if frac >= 1.0 and stage_state == StageState.AUTO_SCAN_FAILSAFE:
			_set_state(StageState.RESCUE_PROMPT)
			slots_jammed.emit(voxels.size(), _snapshot_dock())
	elif not is_dragging:
		# Exact 0.88/frame angular velocity damping (normalized to 60fps!)
		var decay: float = pow(0.88, delta * 60.0)
		yaw += yaw_vel * (delta * 60.0)
		pitch = clampf(pitch + pitch_vel * (delta * 60.0), -0.56, 0.56)
		yaw_vel *= decay
		pitch_vel *= decay
		if absf(yaw_vel) < 0.0005:
			yaw_vel = 0.0
		if absf(pitch_vel) < 0.0005:
			pitch_vel = 0.0
		zoom_scale = lerpf(zoom_scale, 1.0, clampf(delta * 4.5, 0.0, 1.0))

	# Smooth 0.35s visual spin kick for Spinner Layer ring
	if spinner_visual_rot_rem > 0.0:
		var step_r: float = minf(spinner_visual_rot_rem, delta * (PI * 0.5 / 0.35))
		spinner_visual_rot_rem -= step_r
		spinner_ring_root.rotation.y += step_r

	# Gentle float + 0.22s Magnetic Snap squash bounce
	var hover_y: float = sin(now_sec * 1.9) * 0.09
	var squash := Vector3.ONE
	if snap_bounce_t > 0.0:
		snap_bounce_t = maxf(0.0, snap_bounce_t - delta / 0.22)
		var b: float = sin(snap_bounce_t * PI * 2.0) * snap_bounce_t * 0.16
		squash = Vector3(1.0 + b, 1.0 - b * 1.22, 1.0 + b)

	model_tilt_root.position.y = 1.55 + hover_y
	orbit_pivot.rotation = Vector3(pitch, yaw, 0.0)
	orbit_pivot.scale = squash

	if combo_count > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_count = 0
			_emit_stats()

	# DOCK_INSERT_AND_FUSE transition timer
	if stage_state == StageState.DOCK_INSERT_AND_FUSE:
		insert_fuse_timer -= delta
		if insert_fuse_timer <= 0.0:
			for i in range(MAX_SLOTS):
				if slots[i] != null:
					slots[i]["locked_for_fuse"] = false
			_set_state(StageState.FIRING_LOOP)

	_update_camera(delta)
	if stage_state in [StageState.PLAYING_IDLE, StageState.FIRING_LOOP, StageState.DOCK_INSERT_AND_FUSE]:
		_process_active_slots(delta)
	_process_pending_hits(delta)
	_process_debris_and_rings(delta)

	if multimesh_dirty:
		multimesh_dirty = false
		_rebuild_multimeshes()

	# Trigger AUTO_SCAN_FAILSAFE if all slots full & 0.4s idle (RD-SPEC-02 1.1!)
	if stage_state in [StageState.PLAYING_IDLE, StageState.FIRING_LOOP] and pending_hits.is_empty():
		if _are_all_slots_filled_and_idle():
			auto_scan_idle_t += delta
			if auto_scan_idle_t >= 0.40:
				auto_scan_idle_t = 0.0
				auto_scan_elapsed = 0.0
				auto_scan_start_yaw = yaw
				auto_scan_last_sector = -1
				_set_state(StageState.AUTO_SCAN_FAILSAFE)
				callout_banner.emit("↻ 自动 360° 扫描背面同色块...", Color(0.11, 0.39, 0.93))
		else:
			auto_scan_idle_t = 0.0


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = vp.x / maxf(vp.y, 1.0)
	camera.fov = 34.0 # RD-SPEC-03 1.1 exact FOV = 34°!
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

	# Heroic Cube-Smash Framing: Sculpture fills ~78% of stage width (BIG, BOLD, CHUNKY!)
	var half_tan_y: float = tan(deg_to_rad(17.0))
	var half_tan_x: float = half_tan_y * aspect
	var dist_for_w: float = (bound_radius / 0.42) / maxf(half_tan_x, 0.14)
	var dist_for_h: float = (bound_radius * 2.05) / half_tan_y
	var dist: float = maxf(13.8, maxf(dist_for_w, dist_for_h)) / zoom_scale
	var look_at_pt := Vector3(0.0, -0.22, 0.0)
	var elev_rad: float = deg_to_rad(24.0)
	var desired := look_at_pt + Vector3(0.0, sin(elev_rad), cos(elev_rad)) * dist

	if hit_shake > 0.001:
		hit_shake = maxf(0.0, hit_shake - delta * 2.8)
		desired += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * hit_shake

	camera.global_position = camera.global_position.lerp(desired, clampf(delta * 10.0, 0.0, 1.0))
	camera.look_at(look_at_pt, Vector3.UP)


func _process_active_slots(delta: float) -> void:
	if voxels.is_empty():
		return
	var limit: int = get_active_slot_limit()
	var any_fired: bool = false

	for s_idx in range(limit):
		var sl = slots[s_idx]
		if sl == null or bool(sl.get("locked_for_fuse", false)):
			continue
		var cid: int = int(sl["cid"])
		if _count_remaining_for_color(cid) == 0 and not _has_pending_for_color(cid):
			_retire_slot(s_idx)
			continue

		sl["cooldown"] = float(sl["cooldown"]) - delta
		if float(sl["cooldown"]) > 0.0 or int(sl["ammo"]) <= 0:
			continue

		var target_pos: Vector3i = _pick_best_target(cid, -0.15)
		if target_pos == Vector3i(999, 999, 999):
			continue

		any_fired = true
		auto_scan_idle_t = 0.0
		reserved_targets[target_pos] = true
		sl["ammo"] = int(sl["ammo"]) - 1
		shots_fired_total += 1

		var tier: int = int(sl["tier"])
		var rate: float = BASE_FIRE_RATE * (2.2 if tier >= 2 else (1.8 if tier == 1 else 1.0))
		sl["cooldown"] = 1.0 / rate

		# Hit-Flash 0.06s + pop scale 1.0 -> 1.15 before pop!
		if voxels.has(target_pos):
			voxels[target_pos]["hit_t"] = Time.get_ticks_msec() * 0.001
			multimesh_dirty = true

		var wp: Vector3 = _grid_to_world(target_pos)
		var sp: Vector2 = camera.unproject_position(wp) if camera else Vector2(270, 320)
		shot_fired.emit(s_idx, sp, cid, tier)
		if tier >= 1:
			audio.play_super_pierce()

		pending_hits.append({
			"pos": target_pos,
			"cid": cid,
			"tier": tier,
			"t": 0.06, # Exact 0.06s Hit-Flash!
		})

		if int(sl["ammo"]) <= 0:
			_retire_slot(s_idx)
		dock_updated.emit()

	if any_fired and stage_state == StageState.PLAYING_IDLE:
		_set_state(StageState.FIRING_LOOP)
	elif not any_fired and stage_state == StageState.FIRING_LOOP and pending_hits.is_empty():
		_set_state(StageState.PLAYING_IDLE)


func _process_pending_hits(delta: float) -> void:
	for i in range(pending_hits.size() - 1, -1, -1):
		var h: Dictionary = pending_hits[i]
		h["t"] = float(h["t"]) - delta
		if float(h["t"]) <= 0.0:
			pending_hits.remove_at(i)
			var pos: Vector3i = h["pos"]
			var tier: int = int(h["tier"])
			reserved_targets.erase(pos)
			# Pierce depth: 0 -> 1 block, Tier 1 Super -> 2 layers, Tier 2 Mega -> 3 layers!
			_destroy_voxel(pos, tier, false)


func _pick_best_target(cid: int, min_facing: float) -> Vector3i:
	var best_pos := Vector3i(999, 999, 999)
	var best_score: float = -1e9
	var fallback_pos := Vector3i(999, 999, 999)
	var fallback_score: float = -1e9
	var cam_pos: Vector3 = camera.global_position if camera else Vector3(0, 5, 16)
	var pivot_basis: Basis = orbit_pivot.global_transform.basis.orthonormalized()

	for p: Vector3i in exposed_set.keys():
		if reserved_targets.has(p) or not voxels.has(p):
			continue
		var d: Dictionary = voxels[p]
		if bool(d["locked"]):
			continue
		var is_core: bool = bool(d["core"])
		if not is_core and int(d["cid"]) != cid:
			continue

		var wp: Vector3 = _grid_to_world(p)
		var to_cam: Vector3 = (cam_pos - wp).normalized()

		# Compute BEST exposed outward face normal dot product toward camera!
		# Fixes the "last/bottom-center block unshootable at any yaw" bug 100%:
		# An exposed standalone/bottom/center block has +Y/+Z/+X exposed faces -> best_face_dot >= +0.4!
		var best_face_dot: float = -1.0
		for dir in DIRS6:
			if not voxels.has(p + dir):
				var world_n: Vector3 = (pivot_basis * Vector3(dir)).normalized()
				best_face_dot = maxf(best_face_dot, world_n.dot(to_cam))

		var score: float = best_face_dot * 5.0 + (6.5 if is_core else 0.0) + float(p.y) * 0.04
		if score > fallback_score:
			fallback_score = score
			fallback_pos = p

		if best_face_dot >= min_facing:
			if score > best_score:
				best_score = score
				best_pos = p

	if best_pos != Vector3i(999, 999, 999):
		return best_pos
	# Final safety net: when <= 10 voxels remain on the whole sculpture, NEVER strand the last block!
	if voxels.size() <= 10 and fallback_pos != Vector3i(999, 999, 999):
		return fallback_pos
	return best_pos


func _destroy_voxel(pos: Vector3i, pierce_depth: int, from_shockwave: bool) -> void:
	if not voxels.has(pos):
		return
	var d: Dictionary = voxels[pos]
	var cid: int = int(d["cid"])
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
	_spawn_debris(wp, FusePalette.get_color(cid), 1.0 if from_shockwave else 0.85)
	voxel_cleared_fx.emit(sp, cid, is_core)

	# Unlock adjacent Chain-Locked voxels (RD-SPEC-02 1.3: any 6-neighbor unlocks immediately!)
	var broke_chain: bool = false
	for dir in DIRS6:
		var nb: Vector3i = pos + dir
		if voxels.has(nb) and bool(voxels[nb]["locked"]):
			voxels[nb]["locked"] = false
			broke_chain = true
	if broke_chain:
		audio.play_chain_break()

	if is_core:
		_detonate_pulse_core(pos, wp)

	# Pierce inward for Super (tier 1 -> 1 extra layer) / Mega (tier 2 -> 2 extra layers)!
	if pierce_depth > 0 and not is_core:
		var inner: Vector3i = _find_pierce_neighbor(pos, cid)
		if inner != Vector3i(999, 999, 999):
			voxels[inner]["locked"] = false
			_destroy_voxel(inner, pierce_depth - 1, false)

	if not from_shockwave:
		if has_magnetic_snap:
			_check_magnetic_snap()
		_recompute_exposed_and_ao()
		multimesh_dirty = true
		_retire_exhausted_channels()
		_emit_stats()
		if voxels.is_empty() and stage_state != StageState.VICTORY_SETTLE:
			_trigger_victory()


func _find_pierce_neighbor(from_pos: Vector3i, cid: int) -> Vector3i:
	for dir in DIRS6:
		var nb: Vector3i = from_pos + dir
		if voxels.has(nb) and not reserved_targets.has(nb) and bool(voxels[nb]["core"]):
			return nb
	var best := Vector3i(999, 999, 999)
	var best_d: float = 9999.0
	for dir in DIRS6:
		var nb: Vector3i = from_pos + dir
		if voxels.has(nb) and not reserved_targets.has(nb) and int(voxels[nb]["cid"]) == cid:
			var dist_c: float = (Vector3(nb) - center_offset).length()
			if dist_c < best_d:
				best_d = dist_c
				best = nb
	return best


# ==============================================================================
# PULSE CORE 3×3×3 MANHATTAN <= 2 BLAST + 0.15s SLOW-MO + HAPTICS (RD-SPEC-02 1.3)
# ==============================================================================
func _detonate_pulse_core(core_grid: Vector3i, core_world: Vector3) -> void:
	cores_popped += 1
	var bonus: int = 15
	core_bonus_coins = mini(30, core_bonus_coins + bonus)

	audio.play_pulse_boom()
	Input.vibrate_handheld(55)
	_trigger_slowmo(0.15, 0.35)
	hit_shake = maxf(hit_shake, 0.28)
	_spawn_shockwave_ring(core_world, Color(1.0, 0.816, 0.078), 4.0)

	# RD-SPEC-02 1.3: 3x3x3 Manhattan distance <= 2 around core!
	var blast_list: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		var diff: Vector3i = p - core_grid
		if abs(diff.x) <= 1 and abs(diff.y) <= 1 and abs(diff.z) <= 1:
			if abs(diff.x) + abs(diff.y) + abs(diff.z) <= 2:
				blast_list.append(p)

	max_single_core_blast = maxi(max_single_core_blast, blast_list.size())
	var chained_cores: Array[Vector3i] = []
	for p in blast_list:
		if not voxels.has(p):
			continue
		var d: Dictionary = voxels[p]
		var wp: Vector3 = _grid_to_world(p)
		var was_core: bool = bool(d["core"])
		var cid: int = int(d["cid"])
		voxels.erase(p)
		reserved_targets.erase(p)
		combo_count += 1
		max_combo = maxi(max_combo, combo_count)
		_spawn_debris(wp, FusePalette.get_color(cid), 1.45, (wp - core_world).normalized())
		if was_core:
			chained_cores.append(p)

	var sp: Vector2 = camera.unproject_position(core_world) if camera else Vector2(270, 320)
	pulse_core_detonated.emit(sp, blast_list.size(), bonus)
	callout_banner.emit("☀ 脉冲核引爆！震飞 ×%d 块 (+%d 币)" % [blast_list.size(), bonus], Color(1.0, 0.58, 0.08))

	for cc in chained_cores:
		_detonate_pulse_core(cc, _grid_to_world(cc))

	if has_magnetic_snap:
		_check_magnetic_snap()
	_recompute_exposed_and_ao()
	multimesh_dirty = true


# ==============================================================================
# SPINNER LAYER 90° CLOCKWISE & MAGNETIC SNAP (RD-SPEC-02 1.3)
# ==============================================================================
func _rotate_spinner_layers_90() -> void:
	if spinner_layers.is_empty() or voxels.is_empty():
		return
	var cx: int = int(round(center_offset.x))
	var cz: int = int(round(center_offset.z))
	var moved: Dictionary = {}
	var to_erase: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if spinner_layers.has(p.y):
			to_erase.append(p)
			var rx: int = p.x - cx
			var rz: int = p.z - cz
			var np := Vector3i(cx - rz, p.y, cz + rx)
			moved[np] = voxels[p]
	if to_erase.is_empty():
		return
	for p in to_erase:
		voxels.erase(p)
		reserved_targets.erase(p)
	for np: Vector3i in moved.keys():
		moved[np]["hit_t"] = Time.get_ticks_msec() * 0.001
		voxels[np] = moved[np]
	spinner_visual_rot_rem += PI * 0.5
	audio.play_spinner_click()
	_recompute_exposed_and_ao()
	multimesh_dirty = true
	callout_banner.emit("↻ 分段自转层顺时针旋转 90°！", Color(0.11, 0.39, 0.93))


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
	var gap_y: int = -999
	for y in range(min_y + 1, max_y):
		if not ys.has(y):
			gap_y = y
			break
	if gap_y == -999:
		return
	var drop_by: int = 0
	var cy: int = gap_y
	while cy <= max_y and not ys.has(cy):
		drop_by += 1
		cy += 1
	if drop_by <= 0:
		return

	var shifted: Dictionary = {}
	for p: Vector3i in voxels.keys():
		var d: Dictionary = voxels[p]
		if p.y > gap_y:
			d["hit_t"] = Time.get_ticks_msec() * 0.001
			shifted[Vector3i(p.x, p.y - drop_by, p.z)] = d
		else:
			shifted[p] = d
	voxels = shifted
	reserved_targets.clear()
	snap_bounce_t = 1.0
	audio.play_mag_snap()
	hit_shake = maxf(hit_shake, 0.20)
	_spawn_shockwave_ring(model_tilt_root.global_position, Color(1.0, 0.54, 0.12), 3.4)
	callout_banner.emit("🧲 啪嗒！磁吸合拢！", Color(1.0, 0.54, 0.12))


func _retire_slot(s_idx: int) -> void:
	if slots[s_idx] == null:
		return
	slots[s_idx] = null
	_compact_slots_left()
	if not spinner_layers.is_empty() and stage_state != StageState.VICTORY_SETTLE:
		_rotate_spinner_layers_90()
	dock_updated.emit()


func _retire_exhausted_channels() -> void:
	var limit: int = get_active_slot_limit()
	for i in range(limit - 1, -1, -1):
		if slots[i] != null:
			var cid: int = int(slots[i]["cid"])
			if _count_remaining_for_color(cid) == 0 and not _has_pending_for_color(cid):
				_retire_slot(i)
	var swept: bool = false
	for c in range(columns.size()):
		for r in range(columns[c].size() - 1, -1, -1):
			var cid: int = int(columns[c][r]["color_id"])
			if _count_remaining_for_color(cid) == 0 and not _has_pending_for_color(cid):
				columns[c].remove_at(r)
				swept = true
	if swept:
		dock_updated.emit()


# ==============================================================================
# 3 IN-GAME BOOSTERS & FAIR 360-COIN RESCUE (RD-SPEC-01 Section 5 & RD-SPEC-02!)
# ==============================================================================
func use_booster_magnet() -> bool:
	# RD-SPEC-01 Section 5: Auto-pulls a matching-color cannon from ANY queue row straight into
	# the dock next to an occupied slot to force an immediate Super Fuse!
	if voxels.is_empty():
		return false
	var limit: int = get_active_slot_limit()
	var pulled: bool = false

	for s_i in range(limit):
		if slots[s_i] == null or int(slots[s_i]["tier"]) >= 2:
			continue
		var want_cid: int = int(slots[s_i]["cid"])
		# Search all columns & depths for a matching cannon!
		for c in range(columns.size()):
			for r in range(columns[c].size()):
				if int(columns[c][r]["color_id"]) == want_cid:
					var pulled_it: Dictionary = columns[c][r]
					columns[c].remove_at(r)
					# Reveal next rows
					for k in range(mini(2, columns[c].size())):
						columns[c][k]["hidden"] = false
					# Directly fuse into slots[s_i]!
					var sum_a: int = int(slots[s_i]["ammo"]) + int(pulled_it["ammo"])
					var new_ammo: int = int(ceil(float(sum_a) * 1.2))
					var new_tier: int = mini(2, int(slots[s_i]["tier"]) + 1)
					slots[s_i]["ammo"] = new_ammo
					slots[s_i]["tier"] = new_tier
					slots[s_i]["cooldown"] = 0.08
					fuse_count += 1
					boosters_used_count += 1
					audio.play_fuse_arc(new_tier)
					fuse_triggered.emit(s_i, mini(limit - 1, s_i + 1), want_cid, new_ammo, new_tier)
					callout_banner.emit("🧲 磁力合炮！强拉同色炮瞬间超级合体！", FusePalette.get_color(want_cid))
					pulled = true
					break
			if pulled:
				break
		if pulled:
			break

	# Fallback if no matching cannon in queue: clear up to 16 matching voxels for Slot 0!
	if not pulled:
		var target_cid: int = int(slots[0]["cid"]) if slots[0] != null else -1
		if target_cid == -1:
			for p: Vector3i in voxels.keys():
				if not bool(voxels[p]["core"]):
					target_cid = int(voxels[p]["cid"])
					break
		if target_cid == -1:
			return false
		var to_pop: Array[Vector3i] = []
		for p: Vector3i in voxels.keys():
			if int(voxels[p]["cid"]) == target_cid:
				to_pop.append(p)
				if to_pop.size() >= 16:
					break
		for p in to_pop:
			voxels[p]["locked"] = false
			_destroy_voxel(p, 0, true)
		boosters_used_count += 1
		audio.play_mag_snap()
		callout_banner.emit("🧲 磁力吸清 ×%d 块同色积木！" % to_pop.size(), FusePalette.get_color(target_cid))
		_recompute_exposed_and_ao()
		multimesh_dirty = true

	_retire_exhausted_channels()
	_emit_stats()
	if stage_state == StageState.RESCUE_PROMPT:
		_set_state(StageState.FIRING_LOOP)
	if voxels.is_empty() and stage_state != StageState.VICTORY_SETTLE:
		_trigger_victory()
	dock_updated.emit()
	return true


func use_booster_shockwave() -> bool:
	# RD-SPEC-01 Section 5: Immediately detonates ALL Pulse Cores on board; if none, blasts 15 outermost cubes!
	if voxels.is_empty():
		return false
	boosters_used_count += 1
	var cores: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if bool(voxels[p]["core"]):
			cores.append(p)

	if not cores.is_empty():
		for cp in cores:
			if voxels.has(cp):
				voxels.erase(cp)
				_detonate_pulse_core(cp, _grid_to_world(cp))
	else:
		# Blast 15 outermost exposed voxels radially!
		audio.play_pulse_boom()
		_trigger_slowmo(0.15, 0.35)
		hit_shake = maxf(hit_shake, 0.28)
		_spawn_shockwave_ring(model_tilt_root.global_position, Color(0.11, 0.65, 1.0), 4.2)
		var exp_arr: Array[Vector3i] = []
		for p: Vector3i in exposed_set.keys():
			exp_arr.append(p)
		exp_arr.shuffle()
		var cnt: int = mini(15, exp_arr.size())
		for i in range(cnt):
			var p: Vector3i = exp_arr[i]
			if voxels.has(p):
				var wp: Vector3 = _grid_to_world(p)
				var cid: int = int(voxels[p]["cid"])
				voxels.erase(p)
				_spawn_debris(wp, FusePalette.get_color(cid), 1.35)
		callout_banner.emit("⚡ 脉冲震荡！震飞外层 ×%d 块积木！" % cnt, Color(0.11, 0.65, 1.0))

	if has_magnetic_snap:
		_check_magnetic_snap()
	_recompute_exposed_and_ao()
	multimesh_dirty = true
	_retire_exhausted_channels()
	_emit_stats()
	if stage_state == StageState.RESCUE_PROMPT:
		_set_state(StageState.FIRING_LOOP)
	if voxels.is_empty() and stage_state != StageState.VICTORY_SETTLE:
		_trigger_victory()
	dock_updated.emit()
	return true


func unlock_extra_slot() -> bool:
	if extra_slot_unlocked:
		return false
	extra_slot_unlocked = true
	boosters_used_count += 1
	audio.play_fuse_arc(1)
	if stage_state == StageState.RESCUE_PROMPT:
		_set_state(StageState.PLAYING_IDLE)
	callout_banner.emit("➕ 临时第 6 安全扩容槽已开启！", Color(0.08, 0.72, 0.40))
	dock_updated.emit()
	return true


func execute_fair_rescue() -> void:
	# RD-SPEC-02 1.1: Clear 2 jammed dock slots back to the top of the queues + resume play!
	var returned: int = 0
	var limit: int = get_active_slot_limit()
	for i in range(limit - 1, -1, -1):
		if slots[i] != null and returned < 2:
			var sl: Dictionary = slots[i]
			var target_col: int = returned % columns.size()
			columns[target_col].push_front({
				"color_id": int(sl["cid"]),
				"ammo": int(sl["ammo"]),
				"hidden": false,
			})
			slots[i] = null
			returned += 1
	_compact_slots_left()
	auto_scan_idle_t = 0.0
	_set_state(StageState.PLAYING_IDLE)
	audio.play_fuse_arc(1)
	callout_banner.emit("⚡ 救场成功！2 座炮台已安全退回队列", Color(0.11, 0.39, 0.93))
	dock_updated.emit()


func _trigger_victory() -> void:
	_set_state(StageState.VICTORY_SETTLE)
	_trigger_slowmo(0.15, 0.35)
	hit_shake = 0.24
	Input.vibrate_handheld(50)
	_spawn_shockwave_ring(model_tilt_root.global_position, Color(0.11, 0.65, 1.0), 4.8)
	audio.play_victory()

	for i in range(MAX_SLOTS):
		slots[i] = null
	for c in range(columns.size()):
		columns[c].clear()
	dock_updated.emit()

	var base_coins: int = int(level_json.get("coin_reward", 50))
	var tier_str: String = String(level_json.get("difficulty_tier", "Normal"))
	var dur_sec: float = float(Time.get_ticks_msec() - level_start_ms) * 0.001
	level_completed.emit({
		"level_id": int(level_json.get("display_level_id", 1)),
		"title": String(level_json.get("model_name_zh", "")),
		"difficulty_tier": tier_str,
		"is_celebration": (tier_str == "Celebration"),
		"base_coins": base_coins,
		"core_bonus": core_bonus_coins,
		"total_coins": base_coins + core_bonus_coins,
		"paint_energy": 150 if tier_str == "Celebration" else 100,
		"duration_sec": snappedf(dur_sec, 0.1),
		"fuse_count": fuse_count,
		"cores_popped": cores_popped,
		"max_core_blast": max_single_core_blast,
		"boosters_used": boosters_used_count,
		"total_cubes": total_voxels,
		"max_combo": max_combo,
	})


func _trigger_slowmo(real_dur: float, scale_val: float) -> void:
	Engine.time_scale = scale_val
	slowmo_real_rem = maxf(slowmo_real_rem, real_dur)


# ==============================================================================
# DEBRIS OBJECT POOL (Strict 40 Nodes Max, 0.75s Flight -> Scale 0 Recycle!)
# ==============================================================================
func _spawn_debris(world_pos: Vector3, col: Color, speed_mult: float = 1.0, dir_hint: Vector3 = Vector3.ZERO) -> void:
	var db: Dictionary = debris_pool[debris_cursor]
	debris_cursor = (debris_cursor + 1) % DEBRIS_POOL_SIZE
	var mi: MeshInstance3D = db["node"]
	(db["mat"] as StandardMaterial3D).albedo_color = col
	mi.global_position = world_pos
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	var bs: float = voxel_step * randf_range(0.84, 1.04)
	mi.scale = Vector3.ONE * bs
	mi.visible = true

	var out_dir: Vector3 = dir_hint
	if out_dir.length_squared() < 0.05:
		out_dir = (world_pos - model_tilt_root.global_position).normalized()
	if out_dir.length_squared() < 0.05:
		out_dir = Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized()
	var spread := Vector3(randf_range(-0.55, 0.55), randf_range(0.1, 0.85), randf_range(-0.55, 0.55))
	db["vel"] = (out_dir + spread).normalized() * randf_range(3.8, 6.6) * speed_mult
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
		mi.scale = Vector3.ONE * maxf(0.001, float(db["base_scale"]) * smoothstep(0.0, 0.38, u))

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
# MULTIMESH REBUILD (1 Draw Call Sculpture + Optional Cores & 3D Chain Cages)
# ==============================================================================
func _recompute_exposed_and_ao() -> void:
	exposed_set.clear()
	for p: Vector3i in voxels.keys():
		for d in DIRS6:
			if not voxels.has(p + d):
				exposed_set[p] = true
				break

	const AO_OFFS: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1),
		Vector3i(1,1,0), Vector3i(-1,1,0), Vector3i(0,1,1), Vector3i(0,1,-1),
	]
	for p: Vector3i in voxels.keys():
		var occ: float = 0.0
		for d in AO_OFFS:
			if voxels.has(p + d):
				occ += 1.0 if (abs(d.x) + abs(d.y) + abs(d.z) == 1) else 0.52
		voxels[p]["ao"] = clampf(1.0 - occ * 0.052, 0.52, 1.0)


func _rebuild_multimeshes() -> void:
	var normal_list: Array[Vector3i] = []
	var core_list: Array[Vector3i] = []
	var lock_list: Array[Vector3i] = []

	for p: Vector3i in voxels.keys():
		var d: Dictionary = voxels[p]
		if bool(d["core"]):
			core_list.append(p)
		else:
			normal_list.append(p)
			if bool(d["locked"]):
				lock_list.append(p)

	var mm: MultiMesh = main_multimesh.multimesh
	mm.instance_count = normal_list.size()
	var sc := Basis.from_scale(Vector3.ONE * voxel_step)
	for i in range(normal_list.size()):
		var p: Vector3i = normal_list[i]
		var d: Dictionary = voxels[p]
		var cid: int = int(d["cid"])
		var lp: Vector3 = (Vector3(p) - center_offset) * voxel_step
		mm.set_instance_transform(i, Transform3D(sc, lp))
		mm.set_instance_color(i, FusePalette.get_color(cid))
		var flag: float = 2.0 if spinner_layers.has(p.y) else 0.0
		mm.set_instance_custom_data(i, Color(float(cid), float(d["hit_t"]), flag, float(d["ao"])))

	var cmm: MultiMesh = core_multimesh.multimesh
	cmm.instance_count = core_list.size()
	var csc := Basis.from_scale(Vector3.ONE * (voxel_step * 1.15))
	for i in range(core_list.size()):
		var p: Vector3i = core_list[i]
		cmm.set_instance_transform(i, Transform3D(csc, (Vector3(p) - center_offset) * voxel_step))

	var chmm: MultiMesh = chain_multimesh.multimesh
	chmm.instance_count = lock_list.size()
	var lsc := Basis.from_scale(Vector3.ONE * voxel_step)
	for i in range(lock_list.size()):
		var p: Vector3i = lock_list[i]
		chmm.set_instance_transform(i, Transform3D(lsc, (Vector3(p) - center_offset) * voxel_step))


func _grid_to_world(p: Vector3i) -> Vector3:
	return orbit_pivot.to_global((Vector3(p) - center_offset) * voxel_step)


func _count_remaining_for_color(cid: int) -> int:
	var n: int = 0
	for p: Vector3i in voxels.keys():
		if bool(voxels[p]["core"]) or int(voxels[p]["cid"]) == cid:
			n += 1
	return n


func _has_pending_for_color(cid: int) -> bool:
	for h in pending_hits:
		if int(h["cid"]) == cid:
			return true
	return false


func _any_slot_has_visible_target(min_facing: float) -> bool:
	var limit: int = get_active_slot_limit()
	for i in range(limit):
		if slots[i] != null:
			if _pick_best_target(int(slots[i]["cid"]), min_facing) != Vector3i(999, 999, 999):
				return true
	return false


func _are_all_slots_filled_and_idle() -> bool:
	var limit: int = get_active_slot_limit()
	for i in range(limit):
		if slots[i] == null:
			return false
		if _pick_best_target(int(slots[i]["cid"]), -0.15) != Vector3i(999, 999, 999):
			return false
	return true


func _snapshot_dock() -> Array:
	var snap: Array = []
	for i in range(get_active_slot_limit()):
		if slots[i] != null:
			snap.append({"cid": int(slots[i]["cid"]), "ammo": int(slots[i]["ammo"]), "tier": int(slots[i]["tier"])})
	return snap


func _emit_stats() -> void:
	stats_changed.emit(maxi(0, total_voxels - voxels.size()), total_voxels, combo_count)
