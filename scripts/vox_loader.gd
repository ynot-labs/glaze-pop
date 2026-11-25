class_name VoxLoader
extends RefCounted

## Native MagicaVoxel (.vox) binary parser & multi-layer architectural sculptor.
## Reads open-source CC0/MIT .vox files directly into 400–900+ cube 3D levels
## with hollow treasure vaults, load-bearing wood piers, brass lock belts, and onion-layer colors!

const DIRS6: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


static func load_vox_sculpture(
	vox_path: String,
	target_span: int = 16,
	shell_layers: int = 3,
	pinch_mode: bool = false,
	carve_overhang_pillars: bool = true
) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(vox_path)
	if bytes.size() < 20 or bytes.slice(0, 4).get_string_from_ascii() != "VOX ":
		push_error("Invalid .vox file: " + vox_path)
		return {}

	var size_x: int = 20
	var size_y: int = 20
	var size_z: int = 20
	var raw_pts: Array[Vector3i] = []
	var raw_cidx: PackedByteArray = PackedByteArray()

	var offset: int = 8
	var total_len: int = bytes.size()
	while offset + 12 <= total_len:
		var cid: String = bytes.slice(offset, offset + 4).get_string_from_ascii()
		var content_sz: int = bytes.decode_u32(offset + 4)
		var children_sz: int = bytes.decode_u32(offset + 8)
		var data_start: int = offset + 12

		if cid == "SIZE" and content_sz >= 12:
			size_x = bytes.decode_u32(data_start)
			size_y = bytes.decode_u32(data_start + 4)
			size_z = bytes.decode_u32(data_start + 8)
		elif cid == "XYZI" and content_sz >= 4:
			var num_v: int = bytes.decode_u32(data_start)
			var p_off: int = data_start + 4
			for i in range(num_v):
				if p_off + 4 > total_len:
					break
				var vx: int = bytes[p_off]
				var vy: int = bytes[p_off + 1]
				var vz: int = bytes[p_off + 2] # MagicaVoxel +Z is UP!
				var col_i: int = bytes[p_off + 3]
				raw_pts.append(Vector3i(vx, vz, vy))
				raw_cidx.append(col_i)
				p_off += 4
			break

		if cid == "MAIN":
			offset += 12
		else:
			offset += 12 + content_sz + children_sz

	if raw_pts.is_empty():
		return {}

	# Compute integer downsample stride so huge 126^3 .vox castles scale cleanly to target_span!
	var max_dim: int = maxi(size_x, maxi(size_y, size_z))
	var stride: int = maxi(1, int(ceil(float(max_dim) / float(target_span))))

	var grid_raw: Dictionary = {} # Vector3i -> int color_bucket
	var min_g := Vector3i(9999, 9999, 9999)
	var max_g := Vector3i(-9999, -9999, -9999)

	for idx in range(raw_pts.size()):
		var rp: Vector3i = raw_pts[idx]
		var gp := Vector3i(rp.x / stride, rp.y / stride, rp.z / stride)
		if not grid_raw.has(gp):
			grid_raw[gp] = int(raw_cidx[idx])
			min_g.x = mini(min_g.x, gp.x)
			min_g.y = mini(min_g.y, gp.y)
			min_g.z = mini(min_g.z, gp.z)
			max_g.x = maxi(max_g.x, gp.x)
			max_g.y = maxi(max_g.y, gp.y)
			max_g.z = maxi(max_g.z, gp.z)

	# Recenter X/Z around 0 and place bottom flush at Y = 0
	var cx: int = (min_g.x + max_g.x) / 2
	var cz: int = (min_g.z + max_g.z) / 2
	var centered: Dictionary = {}
	var top_y: int = 0
	for gp: Vector3i in grid_raw.keys():
		var np := Vector3i(gp.x - cx, gp.y - min_g.y, gp.z - cz)
		centered[np] = int(grid_raw[gp])
		top_y = maxi(top_y, np.y)

	# Geometry-aware Wood Pillar Neck: thins a 2-high horizontal neck band (split_y-2 .. split_y-1)
	# down to <= 12 vertical columns where upper & lower structure actually meet, turning all of them
	# into Warm Walnut Wood (ch=3) so Siege Hammer / Wood snipers trigger a 150-350+ cube roof collapse!
	var forced_wood: Dictionary = {}
	if carve_overhang_pillars and top_y >= 8:
		var split_y: int = clampi(int(round(float(top_y) * 0.58)), 5, top_y - 3)
		var valid_xz: Array[Vector2i] = []
		for p: Vector3i in centered.keys():
			if p.y == split_y:
				var col_xz := Vector2i(p.x, p.z)
				if not valid_xz.has(col_xz) \
					and centered.has(Vector3i(p.x, split_y - 1, p.z)) \
					and centered.has(Vector3i(p.x, split_y - 2, p.z)) \
					and centered.has(Vector3i(p.x, split_y - 3, p.z)):
					valid_xz.append(col_xz)
		var kept_xz: Dictionary = {}
		var step_pick: int = maxi(1, valid_xz.size() / 8)
		for idx_k in range(0, valid_xz.size(), step_pick):
			if kept_xz.size() >= 10:
				break
			kept_xz[valid_xz[idx_k]] = true
		if not kept_xz.is_empty():
			for p: Vector3i in centered.keys():
				if p.y == split_y - 1 or p.y == split_y - 2:
					var k2 := Vector2i(p.x, p.z)
					if kept_xz.has(k2):
						forced_wood[p] = true
					else:
						centered.erase(p)

	# Carve central 3x3x3 hollow treasure vault at (0, 0..2, 0) for the 3D miniature keepsake!
	for vx in range(-1, 2):
		for vy in range(0, 3):
			for vz in range(-1, 2):
				centered.erase(Vector3i(vx, vy, vz))

	# Compute onion-shell depth from exterior air & trim ultra-deep solid core (> shell_layers)
	var depth_map: Dictionary = _compute_shell_depths(centered)
	var voxels: Dictionary = {}

	for p: Vector3i in centered.keys():
		var d: int = int(depth_map.get(p, 0))
		if d >= shell_layers and not forced_wood.has(p):
			continue
		var vox_c: int = int(centered[p])
		var ch: int = 3 if forced_wood.has(p) else _assign_material_channel(p, d, vox_c, top_y, pinch_mode)
		var locked: bool = false
		if pinch_mode:
			# Brass-lock ALL load-bearing Wood neck columns AND any exposed inner-vault colors (1, 4, 5)
			# so ~350 inner-vault cubes stay sealed behind Brass Locks & outer Celadon/Crystal armor!
			if forced_wood.has(p):
				locked = true
			elif ch in [1, 4, 5] and d == 0 and not (p.y == 2 and p.x == 0):
				locked = true
		elif top_y >= 9 and p.y == 2 and d == 0 and ch == 3 and (abs(p.x) == abs(p.z)):
			locked = true

		voxels[p] = {"ch": ch, "locked": locked}

	# Guarantee all initial blocks are structurally connected to y == 0
	_prune_floating(voxels)
	return voxels


static func _assign_material_channel(p: Vector3i, shell_depth: int, vox_col: int, top_y: int, pinch_mode: bool) -> int:
	# 1. Load-bearing mid-neck & base structural columns -> Warm Walnut Wood (ch = 3)!
	var split_y: int = clampi(int(round(float(top_y) * 0.56)), 6, maxi(6, top_y - 4))
	if top_y >= 10 and p.y >= split_y - 3 and p.y < split_y and abs(p.x) >= 2 and abs(p.x) <= 3 and abs(p.z) >= 2 and abs(p.z) <= 3:
		return 3
	if p.y <= 3 and abs(p.x) >= 3 and abs(p.z) >= 3:
		return 3

	if pinch_mode:
		# Architectural Pinch Zoning: Inner citadel core (|x|<=4, |z|<=4, y<=6) holds ~380 cubes of
		# Berry Jelly (4), Amber Porcelain (5) & Peach Jelly (1), while outer towers & upper roof
		# (~850 cubes!) are clad in Celadon Ceramic (0) & Glacial Crystal (2)!
		if abs(p.x) <= 4 and abs(p.z) <= 4 and p.y <= 6:
			return [4, 5, 1][(abs(p.x) + p.y + abs(p.z)) % 3]
		return 0 if ((abs(p.x) + p.y + abs(p.z)) % 2 == 0) else 2

	# Rich artistic zoning for normal & tactical levels
	if shell_depth >= 1:
		return [1, 2, 4, 5][(abs(p.x) + p.y + abs(p.z)) % 4]
	var hash_zone: int = (vox_col + p.y / 2 + (1 if p.x > 0 else 0)) % 6
	return hash_zone


static func _compute_shell_depths(grid: Dictionary) -> Dictionary:
	var depths: Dictionary = {}
	var queue: Array[Vector3i] = []
	for p: Vector3i in grid.keys():
		var on_surface: bool = false
		for d in DIRS6:
			var nb: Vector3i = p + d
			if nb.y >= 0 and not grid.has(nb):
				on_surface = true
				break
		if on_surface:
			depths[p] = 0
			queue.append(p)

	var head: int = 0
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		var cd: int = int(depths[cur])
		for d in DIRS6:
			var nb: Vector3i = cur + d
			if grid.has(nb) and not depths.has(nb):
				depths[nb] = cd + 1
				queue.append(nb)
	return depths


static func _prune_floating(voxels: Dictionary) -> void:
	var grounded: Dictionary = {}
	var q: Array[Vector3i] = []
	for p: Vector3i in voxels.keys():
		if p.y == 0:
			grounded[p] = true
			q.append(p)
	var head: int = 0
	while head < q.size():
		var cur: Vector3i = q[head]
		head += 1
		for d in DIRS6:
			var nb: Vector3i = cur + d
			if voxels.has(nb) and not grounded.has(nb):
				grounded[nb] = true
				q.append(nb)
	for p: Vector3i in voxels.keys():
		if not grounded.has(p):
			voxels.erase(p)
