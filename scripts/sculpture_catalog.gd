class_name SculptureCatalog
extends RefCounted

## Defines the 6 Triple-Encoded Color-Material Channels, 6 Miniature Keepsakes,
## and architectural multi-material 3D voxel sculptures for Glaze Pop!

enum MatType {
	CERAMIC = 0, # 磨砂青釉陶瓷 — Clean tactile peel
	JELLY = 1,   # 半透果冻硅胶 — Elastic ripple unlocks adjacent Brass Locks!
	CRYSTAL = 2, # 晶透棱面冰晶 — 1-tile refractive pierce inward!
	WOOD = 3,    # 温润原木骨架 — Structural load-bearing Timber Collapse!
}

## Triple-encoded channels: Unique Hue + Material Physics + Geometric Symbol
const CHANNELS: Array[Dictionary] = [
	{
		"id": 0,
		"name": "青釉瓷",
		"mat": MatType.CERAMIC,
		"color": Color(0.44, 0.69, 0.61),
		"ui_color": Color(0.36, 0.62, 0.54),
		"symbol": "◎",
		"sym_idx": 0,
	},
	{
		"id": 1,
		"name": "蜜桃冻",
		"mat": MatType.JELLY,
		"color": Color(0.96, 0.50, 0.37),
		"ui_color": Color(0.91, 0.43, 0.30),
		"symbol": "≈",
		"sym_idx": 1,
	},
	{
		"id": 2,
		"name": "晴空晶",
		"mat": MatType.CRYSTAL,
		"color": Color(0.35, 0.73, 0.94),
		"ui_color": Color(0.24, 0.62, 0.86),
		"symbol": "◆",
		"sym_idx": 2,
	},
	{
		"id": 3,
		"name": "胡桃木",
		"mat": MatType.WOOD,
		"color": Color(0.73, 0.49, 0.29),
		"ui_color": Color(0.64, 0.41, 0.22),
		"symbol": "▣",
		"sym_idx": 3,
	},
	{
		"id": 4,
		"name": "莓果冻",
		"mat": MatType.JELLY,
		"color": Color(0.90, 0.38, 0.55),
		"ui_color": Color(0.82, 0.30, 0.47),
		"symbol": "▲",
		"sym_idx": 4,
	},
	{
		"id": 5,
		"name": "琥珀釉",
		"mat": MatType.CERAMIC,
		"color": Color(0.90, 0.68, 0.26),
		"ui_color": Color(0.80, 0.56, 0.16),
		"symbol": "★",
		"sym_idx": 5,
	},
]

const KEEPSAKES: Array[Dictionary] = [
	{
		"id": "lucky_cat",
		"title": "鎏金招财猫",
		"chapter": "京都陶艺坊",
		"subtitle": "千本鸟居茶室秘藏",
		"scene_path": "res://assets/models/keepsake_lucky_cat.glb",
		"unlock_level": 1,
	},
	{
		"id": "croissant",
		"title": "鎏金起酥可颂",
		"chapter": "巴黎甜品街",
		"subtitle": "蒙马特晨光烘焙屋",
		"scene_path": "res://assets/models/keepsake_croissant.glb",
		"unlock_level": 2,
	},
	{
		"id": "camera",
		"title": "薄荷旁轴胶片机",
		"chapter": "北欧木作室",
		"subtitle": "银盐时光暗房典藏",
		"scene_path": "res://assets/models/keepsake_camera.glb",
		"unlock_level": 3,
	},
	{
		"id": "koi",
		"title": "琉璃戏莲锦鲤",
		"chapter": "京都陶艺坊",
		"subtitle": "岚山庭院水亭清影",
		"scene_path": "res://assets/models/keepsake_koi.glb",
		"unlock_level": 4,
	},
	{
		"id": "teapot",
		"title": "宇治抹茶急须组",
		"chapter": "东京深夜食堂",
		"subtitle": "百年茶寮手捻青瓷",
		"scene_path": "res://assets/models/keepsake_teapot.glb",
		"unlock_level": 5,
	},
	{
		"id": "crown",
		"title": "皇室花丝鎏金冠",
		"chapter": "巴黎甜品街",
		"subtitle": "鎏金钟楼穹顶圣物",
		"scene_path": "res://assets/models/keepsake_crown.glb",
		"unlock_level": 6,
	},
]


static func build_level(level_num: int) -> Dictionary:
	var idx: int = (level_num - 1) % 6
	var cycle: int = (level_num - 1) / 6
	var voxels: Dictionary = {} # Vector3i -> {"ch": int, "locked": bool}
	var title: String = ""
	var chapter: String = ""
	var tip: String = ""
	var keepsake_idx: int = idx

	match idx:
		0:
			title = "京都茶室" if cycle == 0 else "京都茶室 · 极"
			chapter = "第一章 · 京都陶艺坊"
			tip = "左右滑动旋转模型 → 优先击碎四角【胡桃木柱】触发整座屋顶轰然坍塌！"
			_build_kyoto_teahouse(voxels, cycle)
		1:
			title = "法式可颂烘焙屋" if cycle == 0 else "法式烘焙屋 · 极"
			chapter = "第二章 · 巴黎甜品街"
			tip = "瞄准底层【原木承重柱】抽空支撑 → 悬空果冻雨棚与阁楼将整片免费消除！"
			_build_paris_bakery(voxels, cycle)
		2:
			title = "银盐复古暗房" if cycle == 0 else "银盐暗房 · 极"
			chapter = "第三章 · 北欧木作室"
			tip = "黄铜锁块无法直接击碎 → 引爆旁边的【Q弹果冻块】用弹性波纹自动震开卡扣！"
			_build_retro_camera_house(voxels, cycle)
		3:
			title = "岚山琉璃水亭" if cycle == 0 else "琉璃水亭 · 极"
			chapter = "第四章 · 水庭秘境"
			tip = "击碎【晴空冰晶】会向内层发射一次免费折射穿透，提前破开盲区！"
			_build_crystal_pavilion(voxels, cycle)
		4:
			title = "宇治百年茶窑" if cycle == 0 else "宇治茶窑 · 极"
			chapter = "第五章 · 东京深夜食堂"
			tip = "先用【果冻共振】震开窑门铜锁，再抽断双侧木拱触发连环坍塌！"
			_build_uji_kiln(voxels, cycle)
		5:
			title = "皇家鎏金钟楼" if cycle == 0 else "鎏金钟楼 · 极"
			chapter = "第六章 · 藏品庆典关"
			tip = "大师庆典关：结合果冻破锁、冰晶折射与高层塔楼定向爆破，揭晓皇室王冠！"
			_build_royal_clocktower(voxels, cycle)

	# Hollow out central 3x3x2 core vault at (0, 1..2, 0) for the 3D miniature keepsake!
	_carve_keepsake_vault(voxels)
	# Ensure every block at level start is structurally connected to y == 0
	_prune_initially_floating(voxels)

	return {
		"level": level_num,
		"title": title,
		"chapter": chapter,
		"tip": tip,
		"keepsake": KEEPSAKES[keepsake_idx],
		"keepsake_idx": keepsake_idx,
		"voxels": voxels,
	}


static func _set_v(voxels: Dictionary, x: int, y: int, z: int, ch: int, locked: bool = false) -> void:
	voxels[Vector3i(x, y, z)] = {"ch": ch, "locked": locked}


static func _carve_keepsake_vault(voxels: Dictionary) -> void:
	for x in range(-1, 2):
		for y in range(0, 3):
			for z in range(-1, 2):
				# Keep y=0 center empty so keepsake sits directly on turntable at (0,0,0)!
				voxels.erase(Vector3i(x, y, z))


static func _prune_initially_floating(voxels: Dictionary) -> void:
	var visited: Dictionary = {}
	var queue: Array[Vector3i] = []
	for pos: Vector3i in voxels.keys():
		if pos.y == 0:
			visited[pos] = true
			queue.append(pos)
	var head: int = 0
	const DIRS: Array[Vector3i] = [
		Vector3i(1,0,0), Vector3i(-1,0,0),
		Vector3i(0,1,0), Vector3i(0,-1,0),
		Vector3i(0,0,1), Vector3i(0,0,-1),
	]
	while head < queue.size():
		var cur: Vector3i = queue[head]
		head += 1
		for d in DIRS:
			var nb: Vector3i = cur + d
			if voxels.has(nb) and not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	for pos: Vector3i in voxels.keys():
		if not visited.has(pos):
			voxels.erase(pos)


## Lv.1: Kyoto Tea House (matches Fig. 1!)
## 4 Warm Wood corner pillars carry a rich Celadon Ceramic pitched roof, Peach Jelly lanterns & Crystal windows!
static func _build_kyoto_teahouse(v: Dictionary, cycle: int) -> void:
	# 4 sturdy Wood corner columns (x in {-2,2}, z in {-2,2}, y = 0..3) -> TIMBER COLLAPSE trigger!
	for x in [-2, 2]:
		for z in [-2, 2]:
			for y in range(0, 4):
				_set_v(v, x, y, z, 3)
	# Wall panels between pillars (y = 0..2), leaving small peek gaps & crystal shoji windows
	for y in range(0, 3):
		for i in range(-1, 2):
			var wall_ch: int = 0 if y != 1 else 2 # Celadon base/lintel, Crystal shoji middle
			_set_v(v, i, y, -2, wall_ch)
			_set_v(v, i, y, 2, wall_ch)
			_set_v(v, -2, y, i, 1 if (y == 1 and i == 0) else 0)
			_set_v(v, 2, y, i, 1 if (y == 1 and i == 0) else 0)
	# Hanging Peach Jelly corner lanterns at y = 3 overhangs
	for x in [-3, 3]:
		for z in [-2, 2]:
			_set_v(v, x, 3, z, 1)
	# Wood roof ring beam at y = 3
	for i in range(-2, 3):
		_set_v(v, i, 3, -2, 3)
		_set_v(v, i, 3, 2, 3)
		_set_v(v, -2, 3, i, 3)
		_set_v(v, 2, 3, i, 3)
	# Sweeping Celadon Ceramic gabled pagoda roof at y = 4, 5, 6 (45+ blocks supported by the pillars!)
	for x in range(-3, 4):
		for z in range(-3, 4):
			if abs(x) == 3 and abs(z) == 3:
				continue
			_set_v(v, x, 4, z, 0 if (abs(x) < 3 and abs(z) < 3) else 2)
	for x in range(-2, 3):
		for z in range(-2, 3):
			_set_v(v, x, 5, z, 0)
	for z in range(-2, 3):
		_set_v(v, 0, 6, z, 3 if abs(z) == 2 else 0)
	if cycle > 0:
		_set_v(v, 0, 2, -2, 0, true)
		_set_v(v, 0, 1, -2, 1)


## Lv.2: Parisian Croissant Bakery (exact tribute to Fig. 2 & Page 8!)
## Front & side Wood pillars hold up a striped Peach/Berry Jelly awning + Mansard Ceramic/Crystal roof!
static func _build_paris_bakery(v: Dictionary, cycle: int) -> void:
	# Wood pillars at y = 0..3
	for pos2 in [Vector2i(-2,-2), Vector2i(2,-2), Vector2i(-2,2), Vector2i(2,2), Vector2i(0,2)]:
		for y in range(0, 4):
			_set_v(v, pos2.x, y, pos2.y, 3)
	# Bakery display windows (Crystal) & Amber pastry walls on y = 0..2
	for i in range(-1, 2):
		_set_v(v, i, 0, -2, 5)
		_set_v(v, i, 1, -2, 2)
		_set_v(v, i, 2, -2, 3)
		_set_v(v, -2, 0, i, 5)
		_set_v(v, -2, 1, i, 2)
		_set_v(v, 2, 0, i, 5)
		_set_v(v, 2, 1, i, 2)
		_set_v(v, i, 1, 2, 0)
	# Iconic French Striped Jelly Awning jutting out in front (z = -3, y = 2..3)
	for x in range(-2, 3):
		var stripe: int = 1 if ((x + 4) % 2 == 0) else 4
		_set_v(v, x, 3, -2, stripe)
		_set_v(v, x, 2, -3, stripe)
	# Upper Mansard Patisserie Roof (y = 3..6) — HUGE Timber Collapse payoff!
	for x in range(-2, 3):
		for z in range(-2, 3):
			if abs(x) <= 1 and abs(z) <= 1:
				_set_v(v, x, 3, z, 5)
	for x in range(-3, 4):
		for z in range(-2, 3):
			if abs(x) == 3 and abs(z) == 2:
				continue
			_set_v(v, x, 4, z, 0 if (x + z) % 2 == 0 else 5)
	for x in range(-2, 3):
		for z in range(-1, 2):
			_set_v(v, x, 5, z, 4 if abs(x) == 2 else 0)
	for x in range(-1, 2):
		_set_v(v, x, 6, 0, 5)
	if cycle > 0:
		_set_v(v, -1, 2, -2, 5, true)
		_set_v(v, 1, 2, -2, 5, true)


## Lv.3: Retro Photo Studio — Showcases Soft Jelly Elastic Ripple unlocking Brass Clasps!
static func _build_retro_camera_house(v: Dictionary, _cycle: int) -> void:
	for x in range(-3, 4):
		for z in range(-2, 3):
			for y in range(0, 4):
				if abs(x) <= 1 and abs(z) <= 1 and y <= 2:
					continue
				if abs(x) == 3 and abs(z) == 2 and y == 3:
					continue
				# Wood base tripod legs on corners, Celadon body, Silver/Crystal top plate
				var ch: int = 0
				var locked: bool = false
				if y == 0 and (abs(x) >= 2 and abs(z) == 2):
					ch = 3
				elif y == 3:
					ch = 2 if abs(x) <= 1 else 5
				elif z == -2 and abs(x) <= 1 and y in [1, 2]:
					# Camera lens barrel with Brass-Locked shutter ring + Jelly center/sides!
					if x == 0 and y == 1:
						ch = 1 # Peach Jelly detonator right inside the lens!
					else:
						ch = 2
						locked = true
				elif abs(x) == 3 and y in [1, 2]:
					ch = 4 # Berry Jelly side grips!
				elif z == 2 and x == 0 and y in [1, 2]:
					ch = 1
				_set_v(v, x, y, z, ch, locked)
	# Protruding Crystal & Jelly lens ring at z = -3
	for x in range(-1, 2):
		for y in range(1, 3):
			var is_center: bool = (x == 0 and y == 2)
			_set_v(v, x, y, -3, 1 if is_center else 2)
	# Top flash prism & shutter button
	for x in range(-1, 2):
		_set_v(v, x, 4, 0, 2)
	_set_v(v, 2, 4, 0, 1)


## Lv.4: Crystal Water Pavilion — Heavy Crystal Refraction + Stilted Wood Bridge Collapse!
static func _build_crystal_pavilion(v: Dictionary, _cycle: int) -> void:
	# 6 Stilted Warm Wood pier columns in water (y = 0..2)
	for x in [-3, 0, 3]:
		for z in [-2, 2]:
			for y in range(0, 3):
				_set_v(v, x, y, z, 3)
	# Inner Crystal lotus sanctuary walls (y = 0..3)
	for ang_p in [Vector2i(-2,0), Vector2i(2,0), Vector2i(0,-2), Vector2i(0,2), Vector2i(-2,-1), Vector2i(2,-1), Vector2i(-2,1), Vector2i(2,1)]:
		for y in range(0, 3):
			_set_v(v, ang_p.x, y, ang_p.y, 2 if y > 0 else 0)
	# Bridge deck at y = 3 spanning -3..3
	for x in range(-3, 4):
		for z in range(-2, 3):
			if abs(x) <= 1 and abs(z) <= 1:
				_set_v(v, x, 3, z, 2)
			else:
				_set_v(v, x, 3, z, 3 if (abs(x) == 3 or abs(z) == 2) else 0)
	# Floating Lotus Jelly & Crystal Pagoda Canopy (y = 4..6)
	for x in range(-3, 4):
		for z in range(-2, 3):
			if abs(x) + abs(z) <= 4:
				var ch_r: int = 2 if (abs(x) + abs(z)) % 2 == 0 else 4
				var lck: bool = (abs(x) == 1 and z == 0)
				_set_v(v, x, 4, z, ch_r, lck)
	for x in range(-2, 3):
		for z in range(-1, 2):
			_set_v(v, x, 5, z, 1 if abs(x) == 2 else 0)
	_set_v(v, 0, 6, 0, 2)
	_set_v(v, -1, 6, 0, 5)
	_set_v(v, 1, 6, 0, 5)


## Lv.5: Uji Matcha Kiln — Twin Timber Arches + Brass-Locked Kiln Doors + Jelly Steam Vents!
static func _build_uji_kiln(v: Dictionary, _cycle: int) -> void:
	# Left & Right Wood Arch Supports (x = -3 and x = 3, y = 0..3)
	for x in [-3, -2, 2, 3]:
		for z in [-2, 2]:
			for y in range(0, 4):
				if abs(x) == 3 and y > 2:
					continue
				_set_v(v, x, y, z, 3)
	# Front & Back Kiln Chambers with Brass Locks flanked by Peach/Berry Jelly
	for z in [-2, 2]:
		for x in range(-1, 2):
			for y in range(0, 3):
				if x == 0 and y == 1:
					_set_v(v, x, y, z, 1) # Jelly core breaker!
				else:
					_set_v(v, x, y, z, 0 if y == 0 else 5, y >= 1)
	for z in range(-1, 2):
		for y in range(0, 3):
			_set_v(v, -2, y, z, 0)
			_set_v(v, 2, y, z, 0)
			_set_v(v, -3, min(y, 1), z, 4)
			_set_v(v, 3, min(y, 1), z, 4)
	# Upper Stepped Kiln Chimney & Matcha Glaze Dome (y = 3..6)
	for x in range(-2, 3):
		for z in range(-2, 3):
			_set_v(v, x, 3, z, 3 if abs(x) == 2 else 0)
			_set_v(v, x, 4, z, 0 if (x + z) % 2 == 0 else 2)
	for x in range(-1, 2):
		for z in range(-1, 2):
			_set_v(v, x, 5, z, 5 if (x == 0 and z == 0) else 0)
	_set_v(v, 0, 6, 0, 1)
	_set_v(v, 0, 7, 0, 2)


## Lv.6: Grand Royal Clocktower — Multi-Stage Masterpiece!
static func _build_royal_clocktower(v: Dictionary, _cycle: int) -> void:
	# Lower Citadel Base (y = 0..2) with 4 corner Wood Buttresses + Crystal Rose Windows + Locked Gold Gates
	for x in [-2, 2]:
		for z in [-2, 2]:
			for y in range(0, 6):
				_set_v(v, x, y, z, 3) # Tall 6-high Wood structural columns!
	for side in range(-1, 2):
		for y in range(0, 3):
			var is_mid: bool = (side == 0 and y == 1)
			_set_v(v, side, y, -2, 4 if is_mid else 5, (not is_mid and y == 1))
			_set_v(v, side, y, 2, 4 if is_mid else 5, (not is_mid and y == 1))
			_set_v(v, -2, y, side, 1 if is_mid else 2, (not is_mid and y == 1))
			_set_v(v, 2, y, side, 1 if is_mid else 2, (not is_mid and y == 1))
	# Mid-level Balcony Ring (y = 3)
	for x in range(-3, 4):
		for z in range(-3, 4):
			if abs(x) == 3 and abs(z) == 3:
				continue
			if abs(x) <= 1 and abs(z) <= 1:
				_set_v(v, x, 3, z, 0)
			elif abs(x) == 3 or abs(z) == 3:
				_set_v(v, x, 3, z, 5)
	# Open Belfry Arches at y = 4..5 ( ONLY the 4 Wood corner columns at (±2, y, ±2) hold up the Spire!! )
	# Clock faces floating on y = 5 attached to the y = 6 Spire deck!
	for x in range(-2, 3):
		for z in range(-2, 3):
			_set_v(v, x, 6, z, 0 if (abs(x) + abs(z)) % 2 == 0 else 5)
	for dir2 in [Vector2i(0,-2), Vector2i(0,2), Vector2i(-2,0), Vector2i(2,0)]:
		_set_v(v, dir2.x, 5, dir2.y, 2) # Hanging Crystal Clock Dials!
	# Royal Golden & Crystal Spire (y = 7..8)
	for x in range(-1, 2):
		for z in range(-1, 2):
			_set_v(v, x, 7, z, 2 if (x == 0 or z == 0) else 4)
	_set_v(v, 0, 8, 0, 5)
	_set_v(v, 0, 9, 0, 2)
