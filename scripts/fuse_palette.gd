class_name FusePalette
extends RefCounted

## High-Saturation Jewel 6-Color Arcade Palette (Tuned for Maximum Pop on Royal-Blue Stage!)
## 1-based Color IDs matching levels_manifest.json & level_XXX.json:
##  1: Sky-Electric Blue #1EA7FF (pops brilliantly against deep royal-blue stage!)
##  2: Vivid Coral Red   #FF334B
##  3: Juicy Orange      #FF8800
##  4: Neon Emerald      #00D166
##  5: Bright Sun Gold   #FFD600
##  6: Vivid Purple      #A855F7 (Lv.43+)

const COLORS: Dictionary = {
	1: {
		"name": "天际蓝",
		"hex": "#1EA7FF",
		"color": Color(0.118, 0.655, 1.000),
		"dark": Color(0.045, 0.380, 0.740),
		"light": Color(0.450, 0.820, 1.000),
		"symbol": "●",
	},
	2: {
		"name": "珊瑚红",
		"hex": "#FF334B",
		"color": Color(1.000, 0.200, 0.294),
		"dark": Color(0.740, 0.080, 0.150),
		"light": Color(1.000, 0.480, 0.540),
		"symbol": "▲",
	},
	3: {
		"name": "活力橘",
		"hex": "#FF8800",
		"color": Color(1.000, 0.533, 0.000),
		"dark": Color(0.760, 0.320, 0.000),
		"light": Color(1.000, 0.720, 0.300),
		"symbol": "◆",
	},
	4: {
		"name": "翡翠绿",
		"hex": "#00D166",
		"color": Color(0.000, 0.820, 0.400),
		"dark": Color(0.000, 0.520, 0.220),
		"light": Color(0.320, 0.960, 0.620),
		"symbol": "■",
	},
	5: {
		"name": "阳光黄",
		"hex": "#FFD600",
		"color": Color(1.000, 0.839, 0.000),
		"dark": Color(0.780, 0.560, 0.000),
		"light": Color(1.000, 0.930, 0.400),
		"symbol": "★",
	},
	6: {
		"name": "电光紫",
		"hex": "#A855F7",
		"color": Color(0.659, 0.333, 0.969),
		"dark": Color(0.420, 0.150, 0.720),
		"light": Color(0.800, 0.580, 1.000),
		"symbol": "✦",
	},
}

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
