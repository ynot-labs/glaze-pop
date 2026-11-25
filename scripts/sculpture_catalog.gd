class_name SculptureCatalog
extends RefCounted

## High-density .vox open-source model catalog + Pinch-Gate Difficulty Tiers for Glaze Pop!

enum MatType {
	CERAMIC = 0, # 磨砂青釉/骨瓷 — CC0 Porcelain MatCap + Studio Softbox Clearcoat
	JELLY = 1,   # 半透磨砂果冻 — Blurred Screen Transmission + Elastic Lock-Breaker Ripple!
	CRYSTAL = 2, # 棱面色散冰晶 — Chromatic Dispersion Refraction + 1-Tile Inner Pierce!
	WOOD = 3,    # 扫描北美胡桃木 — Poly Haven CC0 Walnut PBR + Real Gravity Timber Collapse!
}

enum DiffMode {
	FLOW = 0,      # 爽感热身（可解 + 大坍塌）
	TACTICAL = 1,  # 烧脑走钢丝（乱点必爆槽，精确转面数块可零氪极限通关）
	PINCH_GATE = 2 # 商业逼氪绝境卡点关（800+ Cubes + 大弹匣跨层锁槽，必买道具暴力破局！）
}

const CHANNELS: Array[Dictionary] = [
	{
		"id": 0,
		"name": "青釉瓷",
		"mat": MatType.CERAMIC,
		"color": Color(0.42, 0.72, 0.63),
		"ui_color": Color(0.30, 0.58, 0.50),
		"symbol": "◎",
		"sym_idx": 0,
	},
	{
		"id": 1,
		"name": "蜜桃冻",
		"mat": MatType.JELLY,
		"color": Color(0.98, 0.46, 0.34),
		"ui_color": Color(0.88, 0.38, 0.26),
		"symbol": "≈",
		"sym_idx": 1,
	},
	{
		"id": 2,
		"name": "晴空晶",
		"mat": MatType.CRYSTAL,
		"color": Color(0.32, 0.74, 0.96),
		"ui_color": Color(0.20, 0.58, 0.84),
		"symbol": "◆",
		"sym_idx": 2,
	},
	{
		"id": 3,
		"name": "胡桃木",
		"mat": MatType.WOOD,
		"color": Color(0.76, 0.50, 0.28),
		"ui_color": Color(0.58, 0.37, 0.19),
		"symbol": "▣",
		"sym_idx": 3,
	},
	{
		"id": 4,
		"name": "莓果冻",
		"mat": MatType.JELLY,
		"color": Color(0.94, 0.34, 0.56),
		"ui_color": Color(0.80, 0.25, 0.45),
		"symbol": "▲",
		"sym_idx": 4,
	},
	{
		"id": 5,
		"name": "琥珀釉",
		"mat": MatType.CERAMIC,
		"color": Color(0.95, 0.72, 0.25),
		"ui_color": Color(0.78, 0.55, 0.14),
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
		"id": "crown",
		"title": "皇室花丝鎏金冠",
		"chapter": "绝境卡点·天守阁",
		"subtitle": "八百格浮世天守镇阁圣物",
		"scene_path": "res://assets/models/keepsake_crown.glb",
		"unlock_level": 2,
	},
	{
		"id": "croissant",
		"title": "鎏金起酥可颂",
		"chapter": "纪念碑古堡",
		"subtitle": "云端圣殿晨光秘宝",
		"scene_path": "res://assets/models/keepsake_croissant.glb",
		"unlock_level": 3,
	},
	{
		"id": "teapot",
		"title": "宇治抹茶急须组",
		"chapter": "巨型茶寮工坊",
		"subtitle": "百年名器釉下典藏",
		"scene_path": "res://assets/models/keepsake_teapot.glb",
		"unlock_level": 4,
	},
	{
		"id": "camera",
		"title": "薄荷旁轴胶片机",
		"chapter": "高塔迷城",
		"subtitle": "银盐时光暗房典藏",
		"scene_path": "res://assets/models/keepsake_camera.glb",
		"unlock_level": 5,
	},
	{
		"id": "koi",
		"title": "琉璃戏莲锦鲤",
		"chapter": "水庭双生殿",
		"subtitle": "岚山庭院水亭清影",
		"scene_path": "res://assets/models/keepsake_koi.glb",
		"unlock_level": 6,
	},
]


static func build_level(level_num: int) -> Dictionary:
	var idx: int = (level_num - 1) % 6
	var voxels: Dictionary = {}
	var title: String = ""
	var chapter: String = ""
	var tip: String = ""
	var diff_mode: int = DiffMode.TACTICAL
	var voxel_step: float = 0.42

	match idx:
		0:
			# Lv.1: ~490 Cubes (chr_cat.vox @ native 1:1!) — Tactical Warmup!
			title = "招财灵猫雕像"
			chapter = "Lv.1 · 进阶热身（约490格）"
			tip = "注意看发射器数字！外层色块不够喂饱大炮时会滞留占槽；可点上方红钮【直达850+格绝境关】直接体验必买道具卡点！"
			diff_mode = DiffMode.TACTICAL
			voxel_step = 0.27
			voxels = VoxLoader.load_vox_sculpture("res://assets/vox/chr_cat.vox", 22, 4, false, false)
		1:
			# Lv.2: THE SIGNATURE 850+ CUBE MUST-BUY-BOOSTER PINCH GATE! (monu9.vox Pagoda Keep)
			title = "浮世千本天守阁"
			chapter = "Lv.2 · 【超难卡点关 · 850+格】"
			tip = "【必买道具卡点关】前排全是大弹匣跨层炮，中层承重胡桃木柱撑起整座百格天守楼阁！5槽锁死时用【破城重锤】引爆百格雪崩破局！"
			diff_mode = DiffMode.PINCH_GATE
			voxel_step = 0.24
			voxels = VoxLoader.load_vox_sculpture("res://assets/vox/monu9.vox", 26, 3, true, true)
		2:
			# Lv.3: ~740 Cubes Monument Valley Citadel (monu1.vox) — Pure Skill Solvable Master!
			title = "云端纪念碑圣殿"
			chapter = "Lv.3 · 硬核技术关（740+格）"
			tip = "纯技术零氪极限关：旋转观察暴露最多的色面优先下炮，留足缓冲槽剥开果冻破锁！"
			diff_mode = DiffMode.TACTICAL
			voxel_step = 0.25
			voxels = VoxLoader.load_vox_sculpture("res://assets/vox/monu1.vox", 22, 2, false, true)
		3:
			# Lv.4: ~820 Cubes Giant Utah Teapot Sculpt (teapot.vox) — Pinch Gate II!
			title = "宗师青瓷巨壶"
			chapter = "Lv.4 · 【超难卡点关 · 820+格】"
			tip = "壶腹内藏大量异色夹心层！当 5 槽被半残大炮填满时，用【强力磁吸】抽干深层色块瞬间连环解套！"
			diff_mode = DiffMode.PINCH_GATE
			voxel_step = 0.24
			voxels = VoxLoader.load_vox_sculpture("res://assets/vox/teapot.vox", 26, 3, true, false)
		4:
			# Lv.5: ~880 Cubes Sky Obelisk Tower (monu10.vox) — Towering Timber Collapse!
			title = "苍穹螺旋高塔"
			chapter = "Lv.5 · 高塔爆破关（880+格）"
			tip = "摩天巨塔卡点关！用【破城重锤】砸断中腰四根胡桃木承重柱，整座上半塔将一次雪崩消除 200+ 格！"
			diff_mode = DiffMode.PINCH_GATE
			voxel_step = 0.22
			voxels = VoxLoader.load_vox_sculpture("res://assets/vox/monu10.vox", 25, 3, true, true)
		5:
			# Lv.6: ~920 Cubes Grand Twin Palace (monu2.vox)
			title = "双生琉璃王城"
			chapter = "Lv.6 · 终极藏品庆典（900+格）"
			tip = "终极九百格王城：结合果冻破锁、冰晶色散穿透与重锤坍塌，夺取最终微缩圣物！"
			diff_mode = DiffMode.PINCH_GATE
			voxel_step = 0.23
			voxels = VoxLoader.load_vox_sculpture("res://assets/vox/monu2.vox", 22, 2, true, true)

	return {
		"level": level_num,
		"title": title,
		"chapter": chapter,
		"tip": tip,
		"diff_mode": diff_mode,
		"voxel_step": voxel_step,
		"keepsake": KEEPSAKES[idx],
		"keepsake_idx": idx,
		"voxels": voxels,
	}
