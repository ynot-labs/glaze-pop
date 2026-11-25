class_name LevelArchitect
extends RefCounted

## Handcrafted High-Recognition 3D Voxel Sculptures for《合炮大爆破 Fuse Smash!》
## 6 Iconic Toy Sculptures (12x12x12 to 16x16x16), clean vibrant color-blocking,
## embedded Golden Pulse Cores, Spinner Layers, Magnetic Snap bands, and Chain Locks!

const LEVEL_COUNT: int = 6

static func build_level(level_num: int) -> Dictionary:
	var idx: int = (maxi(1, level_num) - 1) % LEVEL_COUNT
	match idx:
		0:
			return _build_lv1_robot(level_num)
		1:
			return _build_lv2_rocket(level_num)
		2:
			return _build_lv3_console(level_num)
		3:
			return _build_lv4_duck(level_num)
		4:
			return _build_lv5_racer(level_num)
		_:
			return _build_lv6_castle(level_num)


static func _hollow_interior(raw: Dictionary, max_depth: int = 2) -> Dictionary:
	# Keep a clean thick shell (2 layers deep) so the sculpture feels solid and pops fast at 60fps!
	const DIRS: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]
	var depth: Dictionary = {}
	var q: Array[Vector3i] = []
	for p: Vector3i in raw.keys():
		var exposed: bool = false
		for d in DIRS:
			if not raw.has(p + d):
				exposed = true
				break
		if exposed:
			depth[p] = 0
			q.append(p)
	var head: int = 0
	while head < q.size():
		var cur: Vector3i = q[head]
		head += 1
		var cd: int = int(depth[cur])
		if cd >= max_depth:
			continue
		for d in DIRS:
			var nb: Vector3i = cur + d
			if raw.has(nb) and not depth.has(nb):
				depth[nb] = cd + 1
				q.append(nb)

	var out: Dictionary = {}
	for p: Vector3i in raw.keys():
		if depth.has(p) and int(depth[p]) < max_depth:
			out[p] = raw[p]
	return out


static func _put(grid: Dictionary, p: Vector3i, ch: int, locked: bool = false) -> void:
	grid[p] = {"ch": ch, "locked": locked, "core": false}


# ==============================================================================
# LV.1 — 积木小机器人 (Arcade Robot): Teaches 同色合炮 (Fuse Cannon) + Chest Core!
# ==============================================================================
static func _build_lv1_robot(level_num: int) -> Dictionary:
	var raw: Dictionary = {}

	# Boots & Legs (Emerald Green=3, Orange accents=2)
	for side in [-2, 2]:
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for y in range(0, 3):
					var c: int = 2 if y == 0 else 3
					_put(raw, Vector3i(side + dx, y, dz), c)

	# Torso (Cobalt Blue=0, Yellow chest frame=4, Red core hatch=1)
	for x in range(-3, 4):
		for y in range(3, 8):
			for z in range(-2, 3):
				var ch: int = 0
				if z == 2 and abs(x) <= 1 and y >= 4 and y <= 6:
					ch = 4 # Sun yellow chest ring
				elif y == 3:
					ch = 2 # Orange waist belt
				_put(raw, Vector3i(x, y, z), ch)

	# Arms (Emerald Green=3 + Coral Red=1 fists)
	for side in [-5, 5]:
		var sgn: int = 1 if side > 0 else -1
		for y in range(4, 8):
			for z in range(-1, 2):
				_put(raw, Vector3i(side - sgn, y, z), 3 if y >= 5 else 1)
				if y >= 5:
					_put(raw, Vector3i(side, y, z), 3)

	# Head (Coral Red=1 helmet + Yellow visor=4 + Blue antenna=0)
	for x in range(-2, 3):
		for y in range(8, 12):
			for z in range(-2, 3):
				var ch: int = 1
				if z == 2 and y == 10 and abs(x) <= 1:
					ch = 4 # Bright visor
				elif y == 8:
					ch = 0 # Neck ring
				_put(raw, Vector3i(x, y, z), ch)
	# Antenna on top
	_put(raw, Vector3i(0, 12, 0), 4)
	_put(raw, Vector3i(0, 13, 0), 1)

	var voxels: Dictionary = _hollow_interior(raw, 2)
	# Clear a tiny glowing chamber for the Chest Pulse Core & place it right behind the yellow window!
	var core_pos := Vector3i(0, 5, 1)
	voxels[core_pos] = {"ch": 4, "locked": false, "core": true}
	voxels.erase(Vector3i(0, 5, 2)) # Slight window cutout so golden pulse core peeks out!

	return {
		"level": level_num,
		"title": "积木小机器人",
		"subtitle": "教学：相邻同色自动合炮！",
		"gimmick_tag": "⚡ 同色合炮",
		"voxels": voxels,
		"voxel_step": 0.42,
		"tilt_deg": Vector3(8.0, -24.0, -6.0),
		"spinner_y_min": -99,
		"spinner_y_max": -99,
		"has_magnetic_snap": false,
		"has_dual_cannons": false,
		"fuse_bias": 0.92,
	}


# ==============================================================================
# LV.2 — 太空火箭 (Space Rocket — Page 2 Hero Benchmark!)
# Tilted iconic rocket with Cobalt body, Coral/Orange nose & fins, Yellow/Green
# porthole framing a blazing Golden Pulse Core + Spinner Layer!
# ==============================================================================
static func _build_lv2_rocket(level_num: int) -> Dictionary:
	var raw: Dictionary = {}

	# Exhaust Flame (Yellow=4 core, Orange=2 mid, Green=3 rim) y = 0..2
	for y in range(0, 3):
		var rad: float = 1.6 if y == 2 else (1.2 if y == 1 else 0.8)
		for x in range(-2, 3):
			for z in range(-2, 3):
				if Vector2(x, z).length() <= rad:
					var c: int = 4 if y == 0 else (2 if y == 1 else 3)
					_put(raw, Vector3i(x, y, z), c)

	# Main Cylindrical Hull (Cobalt Blue=0, Emerald Green=3 accent ring) y = 3..11
	for y in range(3, 12):
		var r: float = 3.25 if (y >= 4 and y <= 10) else 2.65
		for x in range(-4, 5):
			for z in range(-4, 5):
				var dist: float = Vector2(x, z).length()
				if dist <= r:
					var ch: int = 0 # Cobalt Blue fuselage
					if y == 5:
						ch = 3 # Emerald green spinner band!
					_put(raw, Vector3i(x, y, z), ch)

	# Nosecone (Coral Red=1 base -> Vibrant Orange=2 tip) y = 12..15
	for y in range(12, 16):
		var r: float = 2.4 - float(y - 12) * 0.65
		for x in range(-3, 4):
			for z in range(-3, 4):
				if Vector2(x, z).length() <= maxf(0.6, r):
					_put(raw, Vector3i(x, y, z), 2 if y >= 14 else 1)

	# 4 Swept Rocket Fins (Coral Red=1 + Orange=2 leading edge)
	for dy in range(0, 6):
		var reach: int = 5 - (dy / 2)
		for f in range(3, reach + 1):
			var c: int = 2 if dy >= 4 else 1
			_put(raw, Vector3i(f, 2 + dy, 0), c)
			_put(raw, Vector3i(-f, 2 + dy, 0), c)
			_put(raw, Vector3i(0, 2 + dy, f), 2 if f >= 4 else 1)
			_put(raw, Vector3i(0, 2 + dy, -f), c)
			if dy <= 3:
				_put(raw, Vector3i(f, 2 + dy, 1), c)
				_put(raw, Vector3i(-f, 2 + dy, 1), c)

	# Iconic Page 2 Porthole Ring on Front (+Z face, centered at x=0, y=9)
	for x in range(-2, 3):
		for y in range(7, 12):
			var d: float = Vector2(x, y - 9).length()
			if d <= 2.3 and d >= 1.15:
				_put(raw, Vector3i(x, y, 3), 4) # Sun Yellow porthole rim
			elif d <= 2.9 and d > 2.3:
				_put(raw, Vector3i(x, y, 3), 3) # Emerald Green outer porthole collar

	var voxels: Dictionary = _hollow_interior(raw, 2)

	# Carve front porthole glass opening so the blazing Golden Pulse Core shines right out (just like Page 2!)
	for x in range(-1, 2):
		for y in range(8, 11):
			if abs(x) + abs(y - 9) <= 1:
				voxels.erase(Vector3i(x, y, 3))
	voxels[Vector3i(0, 9, 2)] = {"ch": 4, "locked": false, "core": true}
	# Second deep Pulse Core on opposite side for huge chain-blast!
	voxels[Vector3i(0, 8, -2)] = {"ch": 4, "locked": false, "core": true}

	return {
		"level": level_num,
		"title": "太空火箭",
		"subtitle": "打爆舷窗金色脉冲核 + 分段自转层！",
		"gimmick_tag": "☀ 脉冲核 × 自转层",
		"voxels": voxels,
		"voxel_step": 0.35,
		"tilt_deg": Vector3(10.0, -18.0, -24.0), # Iconic Page 2 heroic tilted rocket angle!
		"spinner_y_min": 5,
		"spinner_y_max": 5,
		"has_magnetic_snap": false,
		"has_dual_cannons": false,
		"fuse_bias": 0.85,
	}


# ==============================================================================
# LV.3 — 复古游戏机 (Retro Handheld Console): Teaches Magnetic Snap (磁吸合拢)!
# ==============================================================================
static func _build_lv3_console(level_num: int) -> Dictionary:
	var raw: Dictionary = {}

	# Main Handheld Body: x=-4..4, y=0..13, z=-2..2
	for x in range(-4, 5):
		for y in range(0, 14):
			for z in range(-2, 3):
				# Rounded outer corners
				if abs(x) == 4 and (y == 0 or y == 13):
					continue
				var ch: int = 0 # Cobalt Blue shell top/bottom
				if y >= 6 and y <= 7:
					# Middle Magnetic Snap Belt (Vibrant Orange=2 — hollowing this snaps top & bottom together!)
					ch = 2
				elif y >= 8 and y <= 12 and abs(x) <= 3 and z == 2:
					ch = 3 # Emerald Green retro screen bezel
				elif y >= 9 and y <= 11 and abs(x) <= 2 and z >= 1:
					ch = 4 # Sun Yellow glowing screen pixels
				elif y >= 2 and y <= 4 and x <= -1 and z == 2:
					ch = 1 # Coral Red D-Pad zone
				elif y >= 2 and y <= 4 and x >= 1 and z == 2:
					ch = 4 # Yellow AB buttons
				elif y <= 5:
					ch = 3 if (x + y) % 3 == 0 else 0
				_put(raw, Vector3i(x, y, z), ch)

	# Protruding AB Buttons & D-Pad on front (+Z = 3)
	_put(raw, Vector3i(-2, 3, 3), 1)
	_put(raw, Vector3i(-3, 3, 3), 1)
	_put(raw, Vector3i(-1, 3, 3), 1)
	_put(raw, Vector3i(-2, 4, 3), 1)
	_put(raw, Vector3i(-2, 2, 3), 1)
	_put(raw, Vector3i(2, 3, 3), 1)
	_put(raw, Vector3i(3, 4, 3), 4)

	var voxels: Dictionary = _hollow_interior(raw, 2)
	# Two Pulse Cores tucked behind screen & lower core!
	voxels[Vector3i(0, 10, 1)] = {"ch": 4, "locked": false, "core": true}
	voxels[Vector3i(0, 3, 1)] = {"ch": 4, "locked": false, "core": true}

	return {
		"level": level_num,
		"title": "复古游戏机",
		"subtitle": "掏空橙色中腰触发【磁吸合拢】！",
		"gimmick_tag": "🧲 磁吸合拢",
		"voxels": voxels,
		"voxel_step": 0.37,
		"tilt_deg": Vector3(8.0, -22.0, -8.0),
		"spinner_y_min": -99,
		"spinner_y_max": -99,
		"has_magnetic_snap": true,
		"has_dual_cannons": false,
		"fuse_bias": 0.85,
	}


# ==============================================================================
# LV.4 — 皇冠小鸭 (Crown Duck): Spinner Layer + Pulse Core + High Contrast!
# ==============================================================================
static func _build_lv4_duck(level_num: int) -> Dictionary:
	var raw: Dictionary = {}

	# Plump Yellow Duck Body (x=-4..4, y=0..6, z=-4..4)
	for x in range(-4, 5):
		for y in range(0, 7):
			for z in range(-4, 5):
				var rx: float = float(x) / 4.2
				var ry: float = float(y - 3) / 3.4
				var rz: float = float(z) / 4.5
				if rx * rx + ry * ry + rz * rz <= 1.0:
					var ch: int = 4 # Sun Yellow body
					if y == 4:
						ch = 0 # Cobalt Blue Spinner Collar!
					elif abs(x) >= 3 and y >= 2 and y <= 4:
						ch = 2 # Vibrant Orange wings
					elif z <= -3 and y >= 3:
						ch = 1 # Coral Red tail feathers
					_put(raw, Vector3i(x, y, z), ch)

	# Duck Head (y=6..11, centered at z=+1)
	for x in range(-3, 4):
		for y in range(6, 12):
			for z in range(-2, 4):
				var rx: float = float(x) / 3.1
				var ry: float = float(y - 8.5) / 2.9
				var rz: float = float(z - 1.0) / 2.9
				if rx * rx + ry * ry + rz * rz <= 1.0:
					var ch: int = 4
					if y == 9 and abs(x) == 2 and z >= 2:
						ch = 0 # Cute cobalt eyes
					_put(raw, Vector3i(x, y, z), ch)

	# Orange Beak (+Z = 4..5)
	for x in range(-1, 2):
		for z in range(4, 6):
			_put(raw, Vector3i(x, 8, z), 2)
			if z == 4:
				_put(raw, Vector3i(x, 7, z), 2)

	# Emerald & Coral Crown on top (y=11..13)
	for x in range(-2, 3):
		for z in range(-1, 3):
			if abs(x) == 2 or z == -1 or z == 2:
				_put(raw, Vector3i(x, 12, z), 3)
				if (abs(x) + abs(z)) % 2 == 0:
					_put(raw, Vector3i(x, 13, z), 1)

	var voxels: Dictionary = _hollow_interior(raw, 2)
	voxels[Vector3i(0, 3, 2)] = {"ch": 4, "locked": false, "core": true}
	voxels[Vector3i(0, 8, 1)] = {"ch": 4, "locked": false, "core": true}

	return {
		"level": level_num,
		"title": "皇冠小鸭",
		"subtitle": "旋转蓝领层 + 双脉冲能量核！",
		"gimmick_tag": "↻ 自转层 × 双核",
		"voxels": voxels,
		"voxel_step": 0.37,
		"tilt_deg": Vector3(10.0, -32.0, -5.0),
		"spinner_y_min": 4,
		"spinner_y_max": 4,
		"has_magnetic_snap": false,
		"has_dual_cannons": false,
		"fuse_bias": 0.80,
	}


# ==============================================================================
# LV.5 — 像素超跑 (Turbo Racer): Unlocks Electric Purple + Chain Locks + Dual Cannons!
# ==============================================================================
static func _build_lv5_racer(level_num: int) -> Dictionary:
	var raw: Dictionary = {}

	# Lower Chassis (Coral Red=1 + Electric Purple=5 racing stripes!)
	for x in range(-6, 7):
		for y in range(1, 5):
			for z in range(-4, 5):
				if abs(x) == 6 and y >= 3:
					continue
				var ch: int = 1
				if abs(z) <= 1:
					ch = 5 # Electric Purple center stripe!
				elif x >= 5 and abs(z) >= 2 and y == 2:
					ch = 4 # Yellow headlights
				elif x <= -5 and y == 2:
					ch = 2 # Orange turbo exhausts
				_put(raw, Vector3i(x, y, z), ch)

	# 4 Wheels (Emerald Green rims=3 + Cobalt tires=0)
	for wx in [-4, 4]:
		for wz in [-4, 4]:
			for dx in range(-1, 2):
				for dy in range(0, 3):
					var is_hub: bool = (dx == 0 and dy == 1)
					_put(raw, Vector3i(wx + dx, dy, wz), 3 if is_hub else 0)

	# Cockpit Canopy (Cobalt Blue=0 glass + Purple roof=5)
	for x in range(-3, 4):
		for y in range(5, 8):
			for z in range(-3, 4):
				if abs(x) == 3 and y == 7:
					continue
				_put(raw, Vector3i(x, y, z), 5 if y == 7 else 0)

	# Rear Spoiler Wing (Vibrant Orange=2 + Emerald=3)
	for z in range(-4, 5):
		_put(raw, Vector3i(-6, 6, z), 2)
		_put(raw, Vector3i(-5, 6, z), 3)
	_put(raw, Vector3i(-5, 5, -3), 0)
	_put(raw, Vector3i(-5, 5, 3), 0)

	var voxels: Dictionary = _hollow_interior(raw, 2)

	# Add a handful of Chain-Locked bumper cubes (unlock when any adjacent cube is cleared!)
	var lock_count: int = 0
	for p: Vector3i in voxels.keys():
		if p.y == 2 and abs(p.z) == 4 and abs(p.x) <= 2 and lock_count < 10:
			voxels[p]["locked"] = true
			lock_count += 1

	voxels[Vector3i(0, 4, 0)] = {"ch": 4, "locked": false, "core": true}
	voxels[Vector3i(3, 3, 0)] = {"ch": 4, "locked": false, "core": true}

	return {
		"level": level_num,
		"title": "像素超跑",
		"subtitle": "解锁电光紫 · 铁链锁 + 双色交替炮！",
		"gimmick_tag": "⛓ 铁链锁 × 双色炮",
		"voxels": voxels,
		"voxel_step": 0.36,
		"tilt_deg": Vector3(14.0, -34.0, -6.0),
		"spinner_y_min": -99,
		"spinner_y_max": -99,
		"has_magnetic_snap": false,
		"has_dual_cannons": true,
		"fuse_bias": 0.80,
	}


# ==============================================================================
# LV.6 — 霓虹扭蛋城堡 (Mega Toy Castle): Joy Boss Level with ALL Gimmicks!
# ==============================================================================
static func _build_lv6_castle(level_num: int) -> Dictionary:
	var raw: Dictionary = {}

	# Base Keep (x=-5..5, y=0..6, z=-5..5)
	for x in range(-5, 6):
		for y in range(0, 7):
			for z in range(-5, 6):
				if abs(x) <= 1 and y <= 3 and z >= 4:
					continue # Arched front castle gate!
				var ch: int = 0 if (y <= 2) else (3 if y <= 4 else 5)
				if y == 5:
					ch = 2 # Vibrant Orange Magnetic Snap + Spinner Waist!
				_put(raw, Vector3i(x, y, z), ch)

	# 4 Corner Turrets (y=0..11) with Coral Red & Sun Yellow spires
	for cx in [-4, 4]:
		for cz in [-4, 4]:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					for y in range(7, 11):
						_put(raw, Vector3i(cx + dx, y, cz + dz), 1 if y >= 9 else 0)
			_put(raw, Vector3i(cx, 11, cz), 4)
			_put(raw, Vector3i(cx, 12, cz), 4)

	# Central Grand Spire (y=7..14)
	for x in range(-2, 3):
		for z in range(-2, 3):
			for y in range(7, 12):
				_put(raw, Vector3i(x, y, z), 5 if y <= 9 else 1)
	for x in range(-1, 2):
		for z in range(-1, 2):
			_put(raw, Vector3i(x, 12, z), 4)
	_put(raw, Vector3i(0, 13, 0), 2)
	_put(raw, Vector3i(0, 14, 0), 4)

	var voxels: Dictionary = _hollow_interior(raw, 2)

	# Strategic Chain Locks on gate pillars
	for p: Vector3i in voxels.keys():
		if p.y == 2 and p.z == 5 and abs(p.x) == 2:
			voxels[p]["locked"] = true

	# 3 Blazing Pulse Cores for massive Boss Joy fireworks!
	voxels[Vector3i(0, 3, 2)] = {"ch": 4, "locked": false, "core": true}
	voxels[Vector3i(0, 8, 2)] = {"ch": 4, "locked": false, "core": true}
	voxels[Vector3i(0, 8, -2)] = {"ch": 4, "locked": false, "core": true}

	return {
		"level": level_num,
		"title": "霓虹扭蛋城堡",
		"subtitle": "终极爽关：脉冲核翻倍 + 全机关满屏炸裂！",
		"gimmick_tag": "👑 终极爽关 · 三核",
		"voxels": voxels,
		"voxel_step": 0.34,
		"tilt_deg": Vector3(12.0, -28.0, -4.0),
		"spinner_y_min": 5,
		"spinner_y_max": 5,
		"has_magnetic_snap": true,
		"has_dual_cannons": true,
		"fuse_bias": 0.88,
	}
