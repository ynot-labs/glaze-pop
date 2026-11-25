class_name ArcadeAudio
extends Node

## V1.0 Production Audio Manager (RD-SPEC-03 Section 3.2)
## Loads 14 Crisp SFX WAVs + 2 Seamless Looping Chapter BGMs (-14 dB default):
##   - Ch.1: 108 BPM Electronic Marimba
##   - Ch.2: 102 BPM Warm Sweet Jazzy Lo-fi
##   - Combo pitch climb: +0.04 semitones per step up to +12 steps!

const AUDIO_ROOT: String = "res://assets/fuse/audio/"

var sound_enabled: bool = true
var bgm_enabled: bool = true

var sfx_players: Array[AudioStreamPlayer] = []
var sfx_cursor: int = 0
var bgm_player: AudioStreamPlayer
var current_bgm_chapter: int = -1

var streams: Dictionary = {}
var bgm_ch1: AudioStream
var bgm_ch2: AudioStream


func _ready() -> void:
	for i in range(14):
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		sfx_players.append(p)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.volume_db = -14.0 # RD-SPEC-03 3.2: default -14 dB so SFX pops cleanly!
	add_child(bgm_player)

	var sfx_names: Array[String] = [
		"sfx_brick_pop", "sfx_super_pierce", "sfx_chain_break",
		"sfx_fuse_arc", "sfx_mega_fuse", "sfx_pulse_boom",
		"sfx_spinner_click", "sfx_mag_snap", "sfx_slot_in",
		"sfx_slot_warn", "sfx_confirm_btn", "sfx_victory",
		"sfx_island_spray", "sfx_coin_clink",
	]
	for n in sfx_names:
		var path: String = AUDIO_ROOT + n + ".wav"
		if ResourceLoader.exists(path):
			streams[n] = load(path)

	if ResourceLoader.exists(AUDIO_ROOT + "bgm_ch1_marimba.mp3"):
		bgm_ch1 = load(AUDIO_ROOT + "bgm_ch1_marimba.mp3")
		if bgm_ch1 is AudioStreamMP3:
			(bgm_ch1 as AudioStreamMP3).loop = true
	if ResourceLoader.exists(AUDIO_ROOT + "bgm_ch2_lofi.mp3"):
		bgm_ch2 = load(AUDIO_ROOT + "bgm_ch2_lofi.mp3")
		if bgm_ch2 is AudioStreamMP3:
			(bgm_ch2 as AudioStreamMP3).loop = true


func play_chapter_bgm(chapter_idx: int) -> void:
	if not bgm_enabled:
		if bgm_player.playing:
			bgm_player.stop()
		return
	var target_ch: int = 0 if chapter_idx == 0 else 1
	if current_bgm_chapter == target_ch and bgm_player.playing:
		return
	current_bgm_chapter = target_ch
	var st: AudioStream = bgm_ch1 if target_ch == 0 else bgm_ch2
	if st != null:
		bgm_player.stream = st
		bgm_player.volume_db = -14.0
		bgm_player.play()


func set_bgm_enabled(enabled: bool) -> void:
	bgm_enabled = enabled
	if not enabled:
		bgm_player.stop()
	else:
		var ch: int = maxi(0, current_bgm_chapter)
		current_bgm_chapter = -1
		play_chapter_bgm(ch)


func _play(key: String, pitch: float = 1.0, vol_db: float = -4.0) -> void:
	if not sound_enabled or not streams.has(key) or sfx_players.is_empty():
		return
	var p: AudioStreamPlayer = sfx_players[sfx_cursor]
	sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
	p.stream = streams[key]
	p.pitch_scale = clampf(pitch, 0.5, 2.4)
	p.volume_db = vol_db
	p.play()


func play_brick_pop(combo_step: int = 0) -> void:
	# RD-SPEC-03 3.2: Programmatic pitch +0.04 semitones per step up to +12 loop!
	var step: int = combo_step % 13
	var pitch: float = pow(2.0, float(step) * 0.40 / 12.0) * randf_range(0.99, 1.01)
	_play("sfx_brick_pop", pitch, -4.5)


func play_super_pierce() -> void:
	_play("sfx_super_pierce", randf_range(0.96, 1.06), -6.0)


func play_chain_break() -> void:
	_play("sfx_chain_break", randf_range(0.95, 1.08), -3.5)


func play_fuse_arc(tier: int = 1) -> void:
	if tier >= 2:
		_play("sfx_mega_fuse", 1.0, -1.0)
	else:
		_play("sfx_fuse_arc", 1.0, -2.0)


func play_pulse_boom() -> void:
	_play("sfx_pulse_boom", 1.0, -0.5)


func play_spinner_click() -> void:
	_play("sfx_spinner_click", 1.0, -4.0)


func play_mag_snap() -> void:
	_play("sfx_mag_snap", 1.0, -2.0)


func play_slot_in() -> void:
	_play("sfx_slot_in", randf_range(0.96, 1.04), -5.0)


func play_slot_warn() -> void:
	_play("sfx_slot_warn", 1.0, -5.0)


func play_ui_click() -> void:
	_play("sfx_confirm_btn", 1.0, -7.0)


func play_victory() -> void:
	_play("sfx_victory", 1.0, -2.0)


func play_island_spray(step: int = 0) -> void:
	_play("sfx_island_spray", 0.92 + float(step % 8) * 0.07, -4.0)


func play_coin_clink() -> void:
	_play("sfx_coin_clink", 1.0, -4.0)
