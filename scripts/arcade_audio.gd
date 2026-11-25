class_name ArcadeAudio
extends Node

## 100% Procedural Arcade SFX Synthesizer (GDD 5.3 — Zero External WAV Bloat!)
## Crisp Lego-brick click + bubble "pop" with +0.04 semitone combo climb (up to +12 steps),
## Electric Fuse "滋—叮!", Pulse Core bass "咚—哗啦!", Magnetic Snap "啪!", and Island Spray!

const SAMPLE_RATE: int = 22050

var sound_enabled: bool = true
var players: Array[AudioStreamPlayer] = []
var player_idx: int = 0

var wav_brick_pop: AudioStreamWAV
var wav_shoot: AudioStreamWAV
var wav_fuse_arc: AudioStreamWAV
var wav_pulse_boom: AudioStreamWAV
var wav_mag_snap: AudioStreamWAV
var wav_slot_in: AudioStreamWAV
var wav_slot_clear: AudioStreamWAV
var wav_ui_click: AudioStreamWAV
var wav_paint_pop: AudioStreamWAV
var wav_victory: AudioStreamWAV


func _ready() -> void:
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		players.append(p)

	wav_brick_pop = _synth_brick_pop()
	wav_shoot = _synth_shoot()
	wav_fuse_arc = _synth_fuse_arc()
	wav_pulse_boom = _synth_pulse_boom()
	wav_mag_snap = _synth_mag_snap()
	wav_slot_in = _synth_slot_in()
	wav_slot_clear = _synth_slot_clear()
	wav_ui_click = _synth_ui_click()
	wav_paint_pop = _synth_paint_pop()
	wav_victory = _synth_victory()


func _play(stream: AudioStreamWAV, pitch: float = 1.0, vol_db: float = -4.0) -> void:
	if not sound_enabled or stream == null or players.is_empty():
		return
	var p: AudioStreamPlayer = players[player_idx]
	player_idx = (player_idx + 1) % players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.5, 2.5)
	p.volume_db = vol_db
	p.play()


func play_brick_pop(combo_step: int = 0) -> void:
	# GDD 5.3: Escalating pitch per combo step up to +12 steps (euphoric crisp Lego + bubble pop!)
	var steps: int = clampi(combo_step, 0, 12)
	var pitch: float = pow(2.0, float(steps) * 0.45 / 12.0) * randf_range(0.985, 1.015)
	_play(wav_brick_pop, pitch, -4.5)


func play_shoot(is_super: bool = false) -> void:
	_play(wav_shoot, (1.22 if is_super else 1.0) * randf_range(0.95, 1.06), -11.0 if is_super else -13.0)


func play_fuse_arc() -> void:
	_play(wav_fuse_arc, 1.0, -1.5)


func play_pulse_boom() -> void:
	_play(wav_pulse_boom, 1.0, -0.5)


func play_mag_snap() -> void:
	_play(wav_mag_snap, 1.0, -2.0)


func play_slot_in() -> void:
	_play(wav_slot_in, randf_range(0.96, 1.04), -5.0)


func play_slot_clear(streak: int = 0) -> void:
	_play(wav_slot_clear, 1.0 + minf(float(streak) * 0.06, 0.42), -3.5)


func play_ui_click() -> void:
	_play(wav_ui_click, 1.0, -7.0)


func play_paint_pop(step: int = 0) -> void:
	_play(wav_paint_pop, 0.92 + float(step % 8) * 0.08, -4.0)


func play_victory() -> void:
	_play(wav_victory, 1.0, -2.0)


# --- PCM 16-bit Procedural Synthesizers ---

func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var pcm := PackedByteArray()
	pcm.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
		pcm[i * 2] = v & 0xFF
		pcm[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = pcm
	return wav


func _synth_brick_pop() -> AudioStreamWAV:
	# Crisp Lego ABS click + rising bubble "pop!"
	var n: int = int(SAMPLE_RATE * 0.085)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var env_pop: float = exp(-t * 36.0)
		var freq: float = lerpf(420.0, 960.0, clampf(t / 0.045, 0.0, 1.0))
		ph += TAU * freq / float(SAMPLE_RATE)
		var bubble: float = sin(ph) * env_pop * 0.65
		var click: float = sin(TAU * 2400.0 * t) * exp(-t * 180.0) * 0.45
		buf[i] = clampf(bubble + click, -0.95, 0.95)
	return _make_wav(buf)


func _synth_shoot() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.055)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var freq: float = lerpf(1180.0, 480.0, t / 0.055)
		ph += TAU * freq / float(SAMPLE_RATE)
		buf[i] = sin(ph) * exp(-t * 58.0) * 0.42
	return _make_wav(buf)


func _synth_fuse_arc() -> AudioStreamWAV:
	# Crackling cyan electric arc "滋—" followed by bright super-chime "叮!"
	var n: int = int(SAMPLE_RATE * 0.42)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ph_z: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var s: float = 0.0
		if t < 0.16:
			var z_env: float = sin((t / 0.16) * PI)
			var f: float = lerpf(320.0, 1450.0, t / 0.16)
			ph_z += TAU * f / float(SAMPLE_RATE)
			var buzz: float = (sin(ph_z) + 0.4 * sin(ph_z * 2.5)) * 0.45
			var spark: float = rng.randf_range(-1.0, 1.0) * 0.35
			s += (buzz + spark) * z_env * 0.72
		if t >= 0.11:
			var dt: float = t - 0.11
			var bell: float = (
				sin(TAU * 880.0 * dt) * 0.45
				+ sin(TAU * 1318.5 * dt) * 0.35
				+ sin(TAU * 1760.0 * dt) * 0.25
			) * exp(-dt * 9.5)
			s += bell
		buf[i] = clampf(s, -0.95, 0.95)
	return _make_wav(buf)


func _synth_pulse_boom() -> AudioStreamWAV:
	# Punchy sub-bass "咚—" + bright sparkling brick cascade "哗啦!"
	var n: int = int(SAMPLE_RATE * 0.58)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 108
	var ph: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sub_f: float = lerpf(150.0, 44.0, clampf(t / 0.26, 0.0, 1.0))
		ph += TAU * sub_f / float(SAMPLE_RATE)
		var boom: float = sin(ph) * exp(-t * 6.8) * 0.82
		var crack: float = rng.randf_range(-1.0, 1.0) * exp(-t * 14.0) * 0.34
		var shimmer: float = sin(TAU * (620.0 + sin(t * 48.0) * 180.0) * t) * exp(-maxf(0.0, t - 0.06) * 8.0) * 0.22
		buf[i] = clampf(boom + crack + shimmer, -0.95, 0.95)
	return _make_wav(buf)


func _synth_mag_snap() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.24)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var clack: float = (sin(TAU * 360.0 * t) * 0.6 + sin(TAU * 1140.0 * t) * 0.4) * exp(-t * 24.0)
		var ring: float = sin(TAU * 720.0 * t) * exp(-t * 12.0) * 0.3
		buf[i] = clampf(clack + ring, -0.95, 0.95)
	return _make_wav(buf)


func _synth_slot_in() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.09)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		ph += TAU * lerpf(280.0, 620.0, t / 0.09) / float(SAMPLE_RATE)
		buf[i] = sin(ph) * exp(-t * 32.0) * 0.55
	return _make_wav(buf)


func _synth_slot_clear() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.18)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var f: float = 660.0 if t < 0.06 else 990.0
		buf[i] = (sin(TAU * f * t) * 0.55 + sin(TAU * f * 1.5 * t) * 0.22) * exp(-t * 16.0)
	return _make_wav(buf)


func _synth_ui_click() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.04)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		buf[i] = sin(TAU * 980.0 * t) * exp(-t * 90.0) * 0.42
	return _make_wav(buf)


func _synth_paint_pop() -> AudioStreamWAV:
	var n: int = int(SAMPLE_RATE * 0.11)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		ph += TAU * lerpf(340.0, 1120.0, t / 0.11) / float(SAMPLE_RATE)
		buf[i] = sin(ph) * exp(-t * 24.0) * 0.55
	return _make_wav(buf)


func _synth_victory() -> AudioStreamWAV:
	# Bright C-major arcade arpeggio fanfare (C5 -> E5 -> G5 -> C6)
	var n: int = int(SAMPLE_RATE * 0.72)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for i in range(n):
		var t: float = float(i) / float(SAMPLE_RATE)
		var s: float = 0.0
		for k in range(notes.size()):
			var start_t: float = float(k) * 0.095
			if t >= start_t:
				var dt: float = t - start_t
				var f: float = notes[k]
				s += (sin(TAU * f * dt) * 0.34 + sin(TAU * f * 2.0 * dt) * 0.12) * exp(-dt * 5.2)
		buf[i] = clampf(s, -0.95, 0.95)
	return _make_wav(buf)
