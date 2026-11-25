class_name AsmrAudio
extends Node

## Multi-voice polyphonic ASMR sound engine for Glaze Pop!
## Maps the 4 physical materials (Ceramic, Jelly, Crystal, Wood) to studio-synthesized
## acoustic samples with Major Pentatonic combo pitch escalation.

const PENTATONIC_RATIOS: Array[float] = [
	1.000, 1.122, 1.260, 1.498, 1.682, 2.000, 2.245, 2.520
]

const POOL_SIZE: int = 20

var sound_enabled: bool = true
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _last_shoot_ms: int = 0
var _last_pop_ms: int = 0

var _streams: Dictionary = {}


func _ready() -> void:
	_preload_all()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)


func _preload_all() -> void:
	_streams["ceramic"] = [
		load("res://assets/audio/ceramic_1.wav"),
		load("res://assets/audio/ceramic_2.wav"),
		load("res://assets/audio/ceramic_3.wav"),
	]
	_streams["jelly"] = [
		load("res://assets/audio/jelly_1.wav"),
		load("res://assets/audio/jelly_2.wav"),
		load("res://assets/audio/jelly_3.wav"),
	]
	_streams["crystal"] = [
		load("res://assets/audio/crystal_1.wav"),
		load("res://assets/audio/crystal_2.wav"),
		load("res://assets/audio/crystal_3.wav"),
	]
	_streams["wood"] = [
		load("res://assets/audio/wood_1.wav"),
		load("res://assets/audio/wood_2.wav"),
		load("res://assets/audio/wood_3.wav"),
	]
	_streams["shoot"] = load("res://assets/audio/blaster_shoot.wav")
	_streams["slot"] = load("res://assets/audio/slot_place.wav")
	_streams["clear"] = load("res://assets/audio/launcher_clear.wav")
	_streams["unlock"] = load("res://assets/audio/jelly_unlock.wav")
	_streams["refract"] = load("res://assets/audio/crystal_refract.wav")
	_streams["collapse"] = load("res://assets/audio/timber_collapse.wav")
	_streams["overdrive"] = load("res://assets/audio/overdrive_ready.wav")
	_streams["reveal"] = load("res://assets/audio/treasure_reveal.wav")
	_streams["click"] = load("res://assets/audio/ui_click.wav")
	_streams["confirm"] = load("res://assets/audio/ui_confirm.wav")


func _play(stream: AudioStream, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sound_enabled or stream == null or _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	p.stream = stream
	p.volume_db = vol_db
	p.pitch_scale = clampf(pitch, 0.5, 2.8)
	p.play()


func play_voxel_pop(mat_type: int, combo_idx: int = 0) -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_pop_ms < 22:
		return
	_last_pop_ms = now_ms

	var key: String = "ceramic"
	var base_db: float = -2.5
	match mat_type:
		0:
			key = "ceramic"
			base_db = -2.5
		1:
			key = "jelly"
			base_db = -1.5
		2:
			key = "crystal"
			base_db = -3.5
		3:
			key = "wood"
			base_db = -1.0

	var arr: Array = _streams[key]
	var variant: AudioStream = arr[combo_idx % arr.size()]
	var scale_step: int = clampi(combo_idx, 0, PENTATONIC_RATIOS.size() - 1)
	var pitch: float = PENTATONIC_RATIOS[scale_step] * randf_range(0.985, 1.015)
	if mat_type == 3:
		# Keep wood grounded and rich even at high combos
		pitch = lerpf(1.0, pitch, 0.55)
	_play(variant, base_db, pitch)


func play_shoot() -> void:
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_shoot_ms < 42:
		return
	_last_shoot_ms = now_ms
	_play(_streams["shoot"], -8.5, randf_range(0.95, 1.08))


func play_slot_place() -> void:
	_play(_streams["slot"], -2.0, randf_range(0.97, 1.04))


func play_launcher_clear(chain_step: int = 0) -> void:
	var p: float = 1.0 + float(mini(chain_step, 5)) * 0.08
	_play(_streams["clear"], -1.5, p)


func play_jelly_unlock() -> void:
	_play(_streams["unlock"], -1.0, randf_range(0.98, 1.05))


func play_crystal_refract() -> void:
	_play(_streams["refract"], -2.5, randf_range(0.96, 1.06))


func play_timber_collapse() -> void:
	_play(_streams["collapse"], 0.5, randf_range(0.97, 1.03))


func play_overdrive_ready() -> void:
	_play(_streams["overdrive"], -0.5, 1.0)


func play_treasure_reveal() -> void:
	_play(_streams["reveal"], 0.5, 1.0)


func play_ui_click() -> void:
	_play(_streams["click"], -5.0, randf_range(0.98, 1.03))


func play_ui_confirm() -> void:
	_play(_streams["confirm"], -2.5, 1.0)
