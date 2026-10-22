
extends Node
# Fully procedural audio: sound effects and an Iraqi-maqam-flavoured music loop (Hijaz scale,
# oud-like plucks and a darbuka "maqsum" rhythm). No audio files are needed.

const RATE := 16000
const HIJAZ := [293.66, 311.13, 369.99, 392.0, 440.0, 466.16, 523.25, 587.33]

var sounds := {}
var players: Array = []
var music: AudioStreamPlayer
var tracks := {}
var current := ""
var _buf := PackedFloat32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -9.0
	add_child(music)
	_build_sfx()
	tracks["menu"] = _build_music(92.0,
		[0, -1, 2, 3, 4, -1, 3, 2, 1, -1, 2, 1, 0, -1, -1, -1, 0, 2, 3, 4, 5, 4, 3, 2, 3, 2, 1, 2, 0, -1, 0, -1])
	tracks["game"] = _build_music(138.0,
		[4, -1, 4, 5, 4, 3, 2, -1, 3, 3, 2, 1, 2, -1, 0, -1, 4, 4, 5, 6, 7, 6, 5, 4, 3, 2, 3, 4, 3, 2, 1, 0])

func _wav(data: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = data.size() / 2
	return w

# segs: [[f0, f1, dur, "s"|"n"], ...]
func _synth(segs: Array, vol: float) -> AudioStreamWAV:
	var total := 0
	for s in segs:
		total += int(float(s[2]) * RATE)
	var data := PackedByteArray()
	data.resize(total * 2)
	var pos := 0
	var phase := 0.0
	for s in segs:
		var n := int(float(s[2]) * RATE)
		for i in n:
			var t := float(i) / float(n)
			phase += TAU * lerpf(float(s[0]), float(s[1]), t) / RATE
			var v := 0.0
			if s[3] == "n":
				v = (randf() * 2.0 - 1.0) * sin(PI * t)
			else:
				v = sin(phase) + 0.3 * sin(phase * 2.0)
			v *= vol * (1.0 - t) * minf(1.0, float(i) / 60.0)
			data.encode_s16((pos + i) * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
		pos += n
	return _wav(data, false)

func _build_sfx() -> void:
	sounds["coin"] = _synth([[1320, 1320, 0.05, "s"], [1760, 1760, 0.12, "s"]], 0.45)
	sounds["jump"] = _synth([[300, 700, 0.18, "s"]], 0.45)
	sounds["roll"] = _synth([[0, 0, 0.3, "n"]], 0.35)
	sounds["swipe"] = _synth([[0, 0, 0.1, "n"]], 0.22)
	sounds["land"] = _synth([[110, 70, 0.1, "s"]], 0.5)
	sounds["crash"] = _synth([[0, 0, 0.35, "n"], [120, 40, 0.45, "s"]], 0.9)
	sounds["bump"] = _synth([[160, 80, 0.18, "s"], [0, 0, 0.1, "n"]], 0.7)
	sounds["power"] = _synth([[523, 523, 0.07, "s"], [659, 659, 0.07, "s"], [784, 784, 0.07, "s"], [1047, 1047, 0.18, "s"]], 0.5)
	sounds["shield_break"] = _synth([[900, 200, 0.3, "s"], [0, 0, 0.2, "n"]], 0.6)
	sounds["click"] = _synth([[700, 700, 0.04, "s"], [900, 900, 0.06, "s"]], 0.4)
	sounds["buy"] = _synth([[784, 784, 0.07, "s"], [988, 988, 0.07, "s"], [1319, 1319, 0.2, "s"]], 0.5)
	sounds["deny"] = _synth([[220, 180, 0.2, "s"]], 0.5)
	sounds["horn"] = _synth([[196, 196, 0.5, "s"], [246, 246, 0.3, "s"]], 0.35)
	sounds["city"] = _synth([[392, 392, 0.12, "s"], [494, 494, 0.12, "s"], [587, 587, 0.12, "s"], [784, 784, 0.35, "s"]], 0.45)

func _pluck(start: int, freq: float, dur: float, vol: float) -> void:
	var n := int(dur * RATE)
	var w := TAU * freq / RATE
	var size := _buf.size()
	for i in n:
		var idx := (start + i) % size
		var t := float(i) / float(n)
		var env := exp(-4.2 * t) * minf(1.0, float(i) / 40.0)
		var ph := w * i
		_buf[idx] += vol * env * (sin(ph) + 0.45 * sin(2.0 * ph) + 0.18 * sin(3.0 * ph))

func _dum(start: int, vol: float) -> void:
	var n := int(0.22 * RATE)
	var size := _buf.size()
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		phase += TAU * lerpf(130.0, 55.0, t) / RATE
		_buf[(start + i) % size] += vol * sin(phase) * exp(-6.0 * t)

func _tek(start: int, vol: float) -> void:
	var n := int(0.07 * RATE)
	var size := _buf.size()
	var prev := 0.0
	for i in n:
		var t := float(i) / float(n)
		var r := randf() * 2.0 - 1.0
		var hp := r - prev
		prev = r
		_buf[(start + i) % size] += vol * hp * 0.6 * exp(-7.0 * t)

func _build_music(bpm: float, melody: Array) -> AudioStreamWAV:
	var step := 60.0 / bpm / 2.0
	var step_n := int(step * RATE)
	var steps := melody.size()
	_buf = PackedFloat32Array()
	_buf.resize(step_n * steps)
	var bass := [73.42, 73.42, 98.0, 73.42]
	var maqsum := ["D", "T", "-", "T", "D", "-", "T", "-"]
	for s in steps:
		var start := s * step_n
		var m: int = melody[s]
		if m >= 0:
			_pluck(start, HIJAZ[m], step * 2.4, 0.22)
		if s % 2 == 0:
			_pluck(start, float(bass[(s / 8) % 4]), step * 3.0, 0.2)
		var r: String = maqsum[s % 8]
		if r == "D":
			_dum(start, 0.55)
		elif r == "T":
			_tek(start, 0.4)
	var data := PackedByteArray()
	data.resize(_buf.size() * 2)
	for i in _buf.size():
		data.encode_s16(i * 2, int(clampf(_buf[i], -1.0, 1.0) * 26000.0))
	_buf = PackedFloat32Array()
	return _wav(data, true)

func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not Save.d["sfx"] or not sounds.has(name):
		return
	for p in players:
		if not p.playing:
			p.stream = sounds[name]
			p.pitch_scale = pitch
			p.volume_db = vol_db
			p.play()
			return

func play_music(name: String) -> void:
	if current == name and music.playing:
		return
	current = name
	music.stream = tracks[name]
	if Save.d["music"]:
		music.play()

func set_music(on: bool) -> void:
	Save.d["music"] = on
	if on:
		if current != "":
			music.stream = tracks[current]
			music.play()
	else:
		music.stop()
	Save.save()

func set_sfx(on: bool) -> void:
	Save.d["sfx"] = on
	Save.save()
