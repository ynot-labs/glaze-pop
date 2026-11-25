class_name LevelRepository
extends RefCounted

## V1.0 60-Level On-Demand JSON Loader & Post-Lv.60 Daily Master Pool (RD-SPEC-02 Section 2.2)
## Uses pure JSON manifest (res://data/levels_manifest.json) instead of .csv so Godot's
## CSV-to-Translation importer NEVER strips the level manifest on WebGL2 / iOS / Android exports!

const MANIFEST_PATH: String = "res://data/levels_manifest.json"
const LEVELS_DIR: String = "res://data/levels/"

var manifest: Array[Dictionary] = [] # 60 entries indexed 0..59


func load_manifest() -> void:
	manifest.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Missing 60-level JSON manifest: " + MANIFEST_PATH)
		return
	var txt: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid manifest JSON array: " + MANIFEST_PATH)
		return
	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY:
			manifest.append(item)


func get_total_handcrafted_levels() -> int:
	return manifest.size()


func get_manifest_row(level_id: int) -> Dictionary:
	if manifest.is_empty():
		load_manifest()
	if manifest.is_empty():
		return {}
	var resolved_id: int = _resolve_level_id(level_id)
	return manifest[clampi(resolved_id - 1, 0, manifest.size() - 1)]


func load_level_json(level_id: int) -> Dictionary:
	if manifest.is_empty():
		load_manifest()
	if manifest.is_empty():
		return {}
	var is_endless: bool = level_id > manifest.size()
	var resolved_id: int = _resolve_level_id(level_id)
	var row: Dictionary = manifest[clampi(resolved_id - 1, 0, manifest.size() - 1)]
	var model_id: String = String(row["model_id"])
	var json_path: String = LEVELS_DIR + model_id + ".json"

	if not FileAccess.file_exists(json_path):
		push_error("Missing level JSON: " + json_path)
		return {}

	var txt: String = FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in " + json_path)
		return {}

	var data: Dictionary = parsed
	data["display_level_id"] = level_id
	data["is_endless_master"] = is_endless
	return data


func _resolve_level_id(level_id: int) -> int:
	var n: int = manifest.size()
	if level_id <= n:
		return maxi(1, level_id)
	# RD-SPEC-02 2.2 Redline #5: Post-Lv.60 Daily Master Pool (20 shuffled levels from Lv.11..60!)
	var day_seed: int = int(Time.get_unix_time_from_system() / 86400.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 918273 + day_seed * 7919
	var pool: Array[int] = []
	for lv in range(11, n + 1):
		pool.append(lv)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var endless_idx: int = (level_id - n - 1) % 20
	return pool[endless_idx]
