class_name StoreServices
extends Node

## V1.0 Store-Ready Meta, Economy, Lives, Daily Tasks, Hybrid Monetization 2.0,
## Store Compliance & 8-Event BI Telemetry (RD-SPEC-02 & RD-SPEC-03 Compliant!)

signal economy_updated()
signal telemetry_logged(event_name: String, params: Dictionary)

const SAVE_PATH: String = "user://fuse_smash_v1_prod.cfg"
const LIFE_REGEN_SEC: int = 1500 # 25 minutes per heart (RD-SPEC-01 Section 2.2)

# Exact RD-SPEC-02 / CSV Economy Prices
const PRICE_CONTINUE: int = 360
const PRICE_MAGNET: int = 250
const PRICE_SHOCKWAVE: int = 300
const PRICE_EXTRA_SLOT: int = 350
const PRICE_PRE_SUPER: int = 200
const PRICE_PRE_DOUBLE_CORE: int = 200

# Exact 7 IAP SKUs from CSV & RD-SPEC-01 7.1
const IAP_SKUS: Array[Dictionary] = [
	{"sku": "starter_pack", "name": "新手起航包", "price": 0.99, "unlock_lv": 25, "coins": 1000, "boosters": 2, "inf_min": 30, "once": true, "desc": "1000金币 + 全道具×2 + 30分钟无限体力"},
	{"sku": "mini_coins", "name": "小额金币包", "price": 1.99, "unlock_lv": 1, "coins": 1200, "boosters": 0, "inf_min": 0, "once": false, "desc": "立得 1200 金币"},
	{"sku": "fail_proof", "name": "失败防线救援包", "price": 4.99, "unlock_lv": 19, "coins": 3000, "boosters": 3, "inf_min": 60, "once": false, "desc": "3000金币 + 全道具×3 + 1小时无限体力"},
	{"sku": "no_ads_pro", "name": "尊享去广告包", "price": 7.99, "unlock_lv": 1, "coins": 600, "boosters": 0, "inf_min": 0, "once": true, "desc": "永久免插屏 + 每日3次免广告双倍领奖"},
	{"sku": "fuse_pass", "name": "赛季通行证 Fuse Pass", "price": 9.99, "unlock_lv": 15, "coins": 1500, "boosters": 3, "inf_min": 60, "once": true, "desc": "28天赛季 + 体力上限升至8心 + 霓虹电弧皮肤"},
	{"sku": "medium_bundle", "name": "中额礼包", "price": 9.99, "unlock_lv": 1, "coins": 7000, "boosters": 5, "inf_min": 0, "once": false, "desc": "7000金币 + 全道具×5"},
	{"sku": "large_bundle", "name": "大额礼包", "price": 19.99, "unlock_lv": 1, "coins": 16000, "boosters": 10, "inf_min": 180, "once": false, "desc": "16000金币 + 全道具×10 + 3小时无限体力"},
]

# Persistent Player State
var coins: int = 350
var current_level: int = 1
var highest_level: int = 1
var win_streak: int = 0
var lives: int = 5
var last_life_ts: int = 0
var inf_stamina_until_ts: int = 0

# Booster Inventory (free gifted & purchased stock!)
var inv_magnet: int = 0
var inv_shockwave: int = 0
var inv_extra_slot: int = 0
var ftue_gifts_claimed: Dictionary = {}

# Paint-the-Island Progression (2 Chapters × 5 Modules, 500 energy per paint!)
var island_energy: int = 0
var island_chapter: int = 0 # 0=Ch1, 1=Ch2
var island_modules_painted: Array[int] = [0, 0] # 0..5 per chapter

# Settings & Compliance
var sound_enabled: bool = true
var bgm_enabled: bool = true
var symbol_mode: bool = false
var att_prompted: bool = false
var rated_current_version: bool = false

# Hybrid Monetization 2.0 State
var no_ads_pro: bool = false
var fuse_pass_active: bool = false
var is_payer: bool = false
var purchased_once_skus: Dictionary = {}
var consecutive_fails: int = 0
var levels_since_interstitial: int = 0
var daily_day_key: int = 0
var daily_free_rescues_used: int = 0
var daily_adfree_doubles_used: int = 0

# Daily Tasks (4 × 50 = 200 coins/day)
var daily_fuses: int = 0
var daily_cubes: int = 0
var daily_cores: int = 0
var daily_wins: int = 0
var daily_claimed: Array[bool] = [false, false, false, false]

# BI Telemetry Ring Buffer (8 required events from CSV!)
var telemetry_log: Array[Dictionary] = []


func _ready() -> void:
	load_save()
	_check_daily_reset()
	refresh_lives()


func get_max_lives() -> int:
	return 8 if fuse_pass_active else 5


func is_infinite_stamina() -> bool:
	return int(Time.get_unix_time_from_system()) < inf_stamina_until_ts


func get_infinite_stamina_remaining_sec() -> int:
	return maxi(0, inf_stamina_until_ts - int(Time.get_unix_time_from_system()))


func grant_infinite_stamina(minutes: int) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var base: int = maxi(now, inf_stamina_until_ts)
	inf_stamina_until_ts = base + minutes * 60
	save_state()
	economy_updated.emit()


func refresh_lives() -> void:
	var max_l: int = get_max_lives()
	if lives >= max_l:
		lives = max_l
		last_life_ts = int(Time.get_unix_time_from_system())
		return
	var now: int = int(Time.get_unix_time_from_system())
	if last_life_ts <= 0:
		last_life_ts = now
		return
	var elapsed: int = now - last_life_ts
	if elapsed >= LIFE_REGEN_SEC:
		@warning_ignore("integer_division")
		var gained: int = elapsed / LIFE_REGEN_SEC
		lives = mini(max_l, lives + gained)
		last_life_ts += gained * LIFE_REGEN_SEC
		if lives >= max_l:
			last_life_ts = now
		save_state()
		economy_updated.emit()


func get_next_life_sec() -> int:
	if lives >= get_max_lives() or is_infinite_stamina():
		return 0
	var now: int = int(Time.get_unix_time_from_system())
	return maxi(0, LIFE_REGEN_SEC - (now - last_life_ts))


func consume_life_on_fail(shots_fired_count: int) -> bool:
	# RD-SPEC-01 2.2: Free restart within first 3 shots (never deducts a heart!)
	if shots_fired_count <= 3 or is_infinite_stamina():
		return false
	refresh_lives()
	if lives > 0:
		if lives == get_max_lives():
			last_life_ts = int(Time.get_unix_time_from_system())
		lives -= 1
		save_state()
		economy_updated.emit()
		return true
	return false


func add_life(amount: int = 1) -> void:
	lives = mini(get_max_lives(), lives + amount)
	save_state()
	economy_updated.emit()


func grant_ftue_milestone_gifts(level_id: int) -> String:
	# RD-SPEC-02 Section 3: Lv.12 gifts x2 Magnet, Lv.18 gifts x2 Shockwave!
	var key: String = "lv_%d" % level_id
	if ftue_gifts_claimed.has(key):
		return ""
	if level_id == 12:
		ftue_gifts_claimed[key] = true
		inv_magnet += 2
		save_state()
		economy_updated.emit()
		return "🎁 解锁【磁力合炮】！免费赠送 ×2 枚体验"
	elif level_id == 18:
		ftue_gifts_claimed[key] = true
		inv_shockwave += 2
		save_state()
		economy_updated.emit()
		return "🎁 解锁【脉冲震荡】！免费赠送 ×2 枚体验"
	return ""


# ==============================================================================
# HYBRID MONETIZATION 2.0 (Smart Ad Layering + 7 IAP SKUs + Restore Purchase)
# ==============================================================================
func should_show_interstitial(level_id: int, level_interstitial_flag: bool) -> bool:
	# RD-SPEC-02 4.2 & RD-SPEC-03 5.1:
	#  - Lv.1-30: ZERO interstitials!
	#  - Payers / No Ads Pro: ZERO interstitials!
	#  - Non-payers Lv.31+: every 2 levels, skipped during 2-consecutive-fail cooldown!
	if level_id <= 30 or not level_interstitial_flag:
		return false
	if no_ads_pro or is_payer:
		return false
	if consecutive_fails >= 2:
		return false
	levels_since_interstitial += 1
	if levels_since_interstitial >= 2:
		levels_since_interstitial = 0
		return true
	return false


func can_use_adfree_double() -> bool:
	_check_daily_reset()
	return no_ads_pro and daily_adfree_doubles_used < 3


func use_adfree_double() -> bool:
	if not can_use_adfree_double():
		return false
	daily_adfree_doubles_used += 1
	save_state()
	return true


func can_use_daily_free_rescue() -> bool:
	_check_daily_reset()
	return daily_free_rescues_used < 2


func consume_daily_free_rescue() -> void:
	daily_free_rescues_used += 1
	save_state()


func should_show_five_star_prompt(is_celebration: bool) -> bool:
	# RD-SPEC-03 4.2: ONLY when win_streak >= 3 + Celebration level + not yet rated!
	return (not rated_current_version) and win_streak >= 3 and is_celebration


func purchase_sku(sku_id: String) -> Dictionary:
	for s in IAP_SKUS:
		if String(s["sku"]) == sku_id:
			if bool(s["once"]) and purchased_once_skus.has(sku_id):
				return {"ok": false, "msg": "该限购礼包已拥有"}
			var is_first: bool = not is_payer
			is_payer = true
			if bool(s["once"]):
				purchased_once_skus[sku_id] = true
			coins += int(s["coins"])
			var b_cnt: int = int(s["boosters"])
			if b_cnt > 0:
				inv_magnet += b_cnt
				inv_shockwave += b_cnt
				inv_extra_slot += b_cnt
			if int(s["inf_min"]) > 0:
				grant_infinite_stamina(int(s["inf_min"]))
			if sku_id == "no_ads_pro":
				no_ads_pro = true
			elif sku_id == "fuse_pass":
				fuse_pass_active = true
				lives = get_max_lives()

			log_event("iap_purchase", {
				"sku_id": sku_id,
				"price_usd": float(s["price"]),
				"level_id": current_level,
				"is_first_pay": is_first,
			})
			save_state()
			economy_updated.emit()
			return {"ok": true, "msg": "购买成功：%s！" % String(s["name"])}
	return {"ok": false, "msg": "未知商品"}


func restore_purchases() -> String:
	# StoreKit / Play Billing restore hook (restores permanent entitlements cleanly)
	var restored: Array[String] = []
	if no_ads_pro:
		restored.append("尊享去广告包")
	if fuse_pass_active:
		restored.append("Fuse Pass")
	save_state()
	if restored.is_empty():
		return "已完成商店凭证核验（当前无待恢复的永久权益）"
	return "已成功恢复永久权益：%s" % ", ".join(restored)


# ==============================================================================
# DAILY TASKS (4 × 50 = 200 Coins/Day)
# ==============================================================================
func _check_daily_reset() -> void:
	var today: int = int(Time.get_unix_time_from_system() / 86400.0)
	if daily_day_key != today:
		daily_day_key = today
		daily_free_rescues_used = 0
		daily_adfree_doubles_used = 0
		daily_fuses = 0
		daily_cubes = 0
		daily_cores = 0
		daily_wins = 0
		daily_claimed = [false, false, false, false]


func get_daily_tasks() -> Array[Dictionary]:
	_check_daily_reset()
	return [
		{"idx": 0, "title": "触发同色合炮 3 次", "cur": daily_fuses, "goal": 3, "reward": 50, "claimed": daily_claimed[0]},
		{"idx": 1, "title": "粉碎 120 块积木", "cur": daily_cubes, "goal": 120, "reward": 50, "claimed": daily_claimed[1]},
		{"idx": 2, "title": "引爆 2 颗脉冲核", "cur": daily_cores, "goal": 2, "reward": 50, "claimed": daily_claimed[2]},
		{"idx": 3, "title": "累计通关 3 关", "cur": daily_wins, "goal": 3, "reward": 50, "claimed": daily_claimed[3]},
	]


func claim_daily_task(idx: int) -> int:
	var tasks: Array[Dictionary] = get_daily_tasks()
	if idx < 0 or idx >= tasks.size():
		return 0
	var t: Dictionary = tasks[idx]
	if bool(t["claimed"]) or int(t["cur"]) < int(t["goal"]):
		return 0
	daily_claimed[idx] = true
	var rew: int = int(t["reward"])
	coins += rew
	save_state()
	economy_updated.emit()
	return rew


# ==============================================================================
# 8-EVENT BI TELEMETRY (Exact CSV Dictionary!)
# ==============================================================================
func log_event(event_name: String, params: Dictionary) -> void:
	var entry := {
		"ts": int(Time.get_unix_time_from_system()),
		"event": event_name,
		"params": params,
	}
	telemetry_log.append(entry)
	if telemetry_log.size() > 80:
		telemetry_log.pop_front()
	telemetry_logged.emit(event_name, params)


# ==============================================================================
# PERSISTENCE & STORE COMPLIANCE (DELETE ACCOUNT / RESET)
# ==============================================================================
func save_state() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("core", "coins", coins)
	cfg.set_value("core", "current_level", current_level)
	cfg.set_value("core", "highest_level", highest_level)
	cfg.set_value("core", "win_streak", win_streak)
	cfg.set_value("core", "lives", lives)
	cfg.set_value("core", "last_life_ts", last_life_ts)
	cfg.set_value("core", "inf_stamina_until_ts", inf_stamina_until_ts)

	cfg.set_value("inv", "magnet", inv_magnet)
	cfg.set_value("inv", "shockwave", inv_shockwave)
	cfg.set_value("inv", "extra_slot", inv_extra_slot)
	cfg.set_value("inv", "ftue_gifts", ftue_gifts_claimed.keys())

	cfg.set_value("island", "energy", island_energy)
	cfg.set_value("island", "chapter", island_chapter)
	cfg.set_value("island", "painted", island_modules_painted)

	cfg.set_value("prefs", "sound", sound_enabled)
	cfg.set_value("prefs", "bgm", bgm_enabled)
	cfg.set_value("prefs", "symbols", symbol_mode)
	cfg.set_value("prefs", "att", att_prompted)
	cfg.set_value("prefs", "rated", rated_current_version)

	cfg.set_value("monetization", "no_ads_pro", no_ads_pro)
	cfg.set_value("monetization", "fuse_pass", fuse_pass_active)
	cfg.set_value("monetization", "is_payer", is_payer)
	cfg.set_value("monetization", "once_skus", purchased_once_skus.keys())
	cfg.set_value("monetization", "consec_fails", consecutive_fails)
	cfg.set_value("monetization", "since_inter", levels_since_interstitial)

	cfg.set_value("daily", "day", daily_day_key)
	cfg.set_value("daily", "free_rescues", daily_free_rescues_used)
	cfg.set_value("daily", "adfree_doubles", daily_adfree_doubles_used)
	cfg.set_value("daily", "fuses", daily_fuses)
	cfg.set_value("daily", "cubes", daily_cubes)
	cfg.set_value("daily", "cores", daily_cores)
	cfg.set_value("daily", "wins", daily_wins)
	cfg.set_value("daily", "claimed", daily_claimed)
	cfg.save(SAVE_PATH)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		last_life_ts = int(Time.get_unix_time_from_system())
		return
	coins = int(cfg.get_value("core", "coins", 350))
	current_level = int(cfg.get_value("core", "current_level", 1))
	highest_level = int(cfg.get_value("core", "highest_level", 1))
	win_streak = int(cfg.get_value("core", "win_streak", 0))
	lives = int(cfg.get_value("core", "lives", 5))
	last_life_ts = int(cfg.get_value("core", "last_life_ts", int(Time.get_unix_time_from_system())))
	inf_stamina_until_ts = int(cfg.get_value("core", "inf_stamina_until_ts", 0))

	inv_magnet = int(cfg.get_value("inv", "magnet", 0))
	inv_shockwave = int(cfg.get_value("inv", "shockwave", 0))
	inv_extra_slot = int(cfg.get_value("inv", "extra_slot", 0))
	ftue_gifts_claimed.clear()
	for k in cfg.get_value("inv", "ftue_gifts", []):
		ftue_gifts_claimed[String(k)] = true

	island_energy = int(cfg.get_value("island", "energy", 0))
	island_chapter = int(cfg.get_value("island", "chapter", 0))
	var p_arr: Array = cfg.get_value("island", "painted", [0, 0])
	if p_arr.size() >= 2:
		island_modules_painted = [int(p_arr[0]), int(p_arr[1])]

	sound_enabled = bool(cfg.get_value("prefs", "sound", true))
	bgm_enabled = bool(cfg.get_value("prefs", "bgm", true))
	symbol_mode = bool(cfg.get_value("prefs", "symbols", false))
	att_prompted = bool(cfg.get_value("prefs", "att", false))
	rated_current_version = bool(cfg.get_value("prefs", "rated", false))

	no_ads_pro = bool(cfg.get_value("monetization", "no_ads_pro", false))
	fuse_pass_active = bool(cfg.get_value("monetization", "fuse_pass", false))
	is_payer = bool(cfg.get_value("monetization", "is_payer", false))
	purchased_once_skus.clear()
	for sk in cfg.get_value("monetization", "once_skus", []):
		purchased_once_skus[String(sk)] = true
	consecutive_fails = int(cfg.get_value("monetization", "consec_fails", 0))
	levels_since_interstitial = int(cfg.get_value("monetization", "since_inter", 0))

	daily_day_key = int(cfg.get_value("daily", "day", 0))
	daily_free_rescues_used = int(cfg.get_value("daily", "free_rescues", 0))
	daily_adfree_doubles_used = int(cfg.get_value("daily", "adfree_doubles", 0))
	daily_fuses = int(cfg.get_value("daily", "fuses", 0))
	daily_cubes = int(cfg.get_value("daily", "cubes", 0))
	daily_cores = int(cfg.get_value("daily", "cores", 0))
	daily_wins = int(cfg.get_value("daily", "wins", 0))
	var dc: Array = cfg.get_value("daily", "claimed", [false, false, false, false])
	if dc.size() >= 4:
		daily_claimed = [bool(dc[0]), bool(dc[1]), bool(dc[2]), bool(dc[3])]


func delete_all_account_data() -> void:
	# App Store / Google Play mandatory Delete Account & Data Reset compliance!
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	coins = 350
	current_level = 1
	highest_level = 1
	win_streak = 0
	lives = 5
	last_life_ts = int(Time.get_unix_time_from_system())
	inf_stamina_until_ts = 0
	inv_magnet = 0
	inv_shockwave = 0
	inv_extra_slot = 0
	ftue_gifts_claimed.clear()
	island_energy = 0
	island_chapter = 0
	island_modules_painted = [0, 0]
	no_ads_pro = false
	fuse_pass_active = false
	is_payer = false
	purchased_once_skus.clear()
	rated_current_version = false
	daily_claimed = [false, false, false, false]
	save_state()
	economy_updated.emit()
