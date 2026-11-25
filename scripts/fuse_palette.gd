class_name FusePalette
extends RefCounted

## Strict Version B 6-Color Safety Palette (RD-SPEC-03 Section 1.2)
## 1-based Color IDs matching levels_v1_60_config.csv & level_XXX.json!
##  1: Cobalt Blue #1D63ED (Solid Circle)
##  2: Coral Red #FF4D4F (Equilateral Triangle)
##  3: Vibrant Orange #FF8A1F (Diamond)
##  4: Emerald Green #14B866 (Square)
##  5: Sun Yellow #FFD014 (5-Point Star)
##  6: Electric Purple #8B5CF6 (Cross Star, unlocked Lv.43)

const COLORS: Dictionary = {
	1: {
		"name": "钴蓝",
		"hex": "#1D63ED",
		"color": Color(0.114, 0.388, 0.929),
		"dark": Color(0.065, 0.235, 0.650),
		"light": Color(0.360, 0.590, 1.000),
		"symbol": "●",
	},
	2: {
		"name": "珊瑚红",
		"hex": "#FF4D4F",
		"color": Color(1.000, 0.302, 0.310),
		"dark": Color(0.760, 0.145, 0.165),
		"light": Color(1.000, 0.540, 0.545),
		"symbol": "▲",
	},
	3: {
		"name": "活力橘",
		"hex": "#FF8A1F",
		"color": Color(1.000, 0.541, 0.122),
		"dark": Color(0.760, 0.340, 0.040),
		"light": Color(1.000, 0.720, 0.380),
		"symbol": "◆",
	},
	4: {
		"name": "翡翠绿",
		"hex": "#14B866",
		"color": Color(0.078, 0.722, 0.400),
		"dark": Color(0.035, 0.480, 0.250),
		"light": Color(0.320, 0.870, 0.590),
		"symbol": "■",
	},
	5: {
		"name": "阳光黄",
		"hex": "#FFD014",
		"color": Color(1.000, 0.816, 0.078),
		"dark": Color(0.780, 0.550, 0.015),
		"light": Color(1.000, 0.910, 0.420),
		"symbol": "★",
	},
	6: {
		"name": "电光紫",
		"hex": "#8B5CF6",
		"color": Color(0.545, 0.361, 0.965),
		"dark": Color(0.350, 0.180, 0.720),
		"light": Color(0.720, 0.580, 1.000),
		"symbol": "✦",
	},
}

## V1.0 2 Chapters × 5 Paintable 3D Island Modules (RD-SPEC-02 Section 4.1)
const ISLAND_CHAPTERS: Array[Dictionary] = [
	{
		"id": 0,
		"chapter_key": "Ch1_积木启航岛",
		"name": "积木启航岛",
		"subtitle": "Ch.1 · Lv.1–30",
		"glb_path": "res://assets/fuse/models/island_ch1_sail.glb",
		"modules": ["火箭发射台", "机器人雕像", "海角灯塔", "信号雷达站", "空间站核心"],
		"completion_coins": 300,
		"completion_stamina_min": 30,
	},
	{
		"id": 1,
		"chapter_key": "Ch2_街头甜品坊",
		"name": "街头甜品坊",
		"subtitle": "Ch.2 · Lv.31–60",
		"glb_path": "res://assets/fuse/models/island_ch2_dessert.glb",
		"modules": ["甜甜圈拱门", "珍珠奶茶屋", "冰激凌餐车", "马卡龙高塔", "梦幻甜品城堡"],
		"completion_coins": 300,
		"completion_stamina_min": 30,
	},
]


static func get_color(cid: int) -> Color:
	return COLORS[clampi(cid, 1, 6)]["color"]


static func get_dark(cid: int) -> Color:
	return COLORS[clampi(cid, 1, 6)]["dark"]


static func get_light(cid: int) -> Color:
	return COLORS[clampi(cid, 1, 6)]["light"]


static func get_symbol(cid: int) -> String:
	return String(COLORS[clampi(cid, 1, 6)]["symbol"])
