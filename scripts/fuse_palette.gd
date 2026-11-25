class_name FusePalette
extends RefCounted

## Exact High-Contrast 6-Color Arcade Safety Palette (GDD Section 2.2)
## Zero ambiguous near-colors! Crisp white text outline + optional micro-symbols.

const COLORS: Array[Dictionary] = [
	{
		"id": 0,
		"name": "钴蓝",
		"hex": "#1D63ED",
		"color": Color(0.114, 0.388, 0.929),
		"dark": Color(0.065, 0.235, 0.650),
		"light": Color(0.360, 0.590, 1.000),
		"symbol": "○",
	},
	{
		"id": 1,
		"name": "珊瑚红",
		"hex": "#FF4D4F",
		"color": Color(1.000, 0.302, 0.310),
		"dark": Color(0.760, 0.145, 0.165),
		"light": Color(1.000, 0.540, 0.545),
		"symbol": "◆",
	},
	{
		"id": 2,
		"name": "活力橘",
		"hex": "#FF8A1F",
		"color": Color(1.000, 0.541, 0.122),
		"dark": Color(0.760, 0.340, 0.040),
		"light": Color(1.000, 0.720, 0.380),
		"symbol": "▲",
	},
	{
		"id": 3,
		"name": "翡翠绿",
		"hex": "#14B866",
		"color": Color(0.078, 0.722, 0.400),
		"dark": Color(0.035, 0.480, 0.250),
		"light": Color(0.320, 0.870, 0.590),
		"symbol": "＋",
	},
	{
		"id": 4,
		"name": "阳光黄",
		"hex": "#FFD014",
		"color": Color(1.000, 0.816, 0.078),
		"dark": Color(0.780, 0.550, 0.015),
		"light": Color(1.000, 0.910, 0.420),
		"symbol": "★",
	},
	{
		"id": 5,
		"name": "电光紫",
		"hex": "#8B5CF6",
		"color": Color(0.545, 0.361, 0.965),
		"dark": Color(0.350, 0.180, 0.720),
		"light": Color(0.720, 0.580, 1.000),
		"symbol": "□",
	},
]

const ISLAND_THEMES: Array[Dictionary] = [
	{
		"id": 0,
		"name": "云端游乐园",
		"subtitle": "Cloud Toy Park",
		"landmarks": ["摩天轮", "彩虹拱门", "扭蛋屋", "旋转木马", "星星灯塔"],
		"base_color": Color(0.24, 0.78, 0.48),
		"accent_colors": [Color(1.0, 0.30, 0.31), Color(0.11, 0.39, 0.93), Color(1.0, 0.82, 0.08), Color(1.0, 0.54, 0.12), Color(0.55, 0.36, 0.96)],
	},
	{
		"id": 1,
		"name": "霓虹街机城",
		"subtitle": "Neon Arcade City",
		"landmarks": ["像素门楼", "街机巨塔", "全息广告", "电玩广场", "超频信号站"],
		"base_color": Color(0.24, 0.30, 0.52),
		"accent_colors": [Color(0.11, 0.68, 1.0), Color(1.0, 0.30, 0.54), Color(0.55, 0.36, 0.96), Color(1.0, 0.82, 0.08), Color(0.08, 0.82, 0.52)],
	},
	{
		"id": 2,
		"name": "积木水上乐园",
		"subtitle": "Block Splash Park",
		"landmarks": ["冲浪滑梯", "珊瑚灯塔", "帆船码头", "海星舞台", "喷泉中心"],
		"base_color": Color(0.18, 0.74, 0.88),
		"accent_colors": [Color(1.0, 0.54, 0.12), Color(1.0, 0.82, 0.08), Color(0.08, 0.72, 0.40), Color(1.0, 0.30, 0.31), Color(0.11, 0.39, 0.93)],
	},
	{
		"id": 3,
		"name": "糖果太空站",
		"subtitle": "Candy Space Station",
		"landmarks": ["火箭发射坪", "行星圆顶", "能量反应堆", "星环轨道", "银河灯塔"],
		"base_color": Color(0.42, 0.34, 0.74),
		"accent_colors": [Color(1.0, 0.82, 0.08), Color(1.0, 0.30, 0.31), Color(0.11, 0.62, 1.0), Color(1.0, 0.54, 0.12), Color(0.08, 0.82, 0.52)],
	},
]

static func get_color(ch: int) -> Color:
	return COLORS[clampi(ch, 0, COLORS.size() - 1)]["color"]

static func get_dark(ch: int) -> Color:
	return COLORS[clampi(ch, 0, COLORS.size() - 1)]["dark"]

static func get_light(ch: int) -> Color:
	return COLORS[clampi(ch, 0, COLORS.size() - 1)]["light"]

static func get_symbol(ch: int) -> String:
	return String(COLORS[clampi(ch, 0, COLORS.size() - 1)]["symbol"])
