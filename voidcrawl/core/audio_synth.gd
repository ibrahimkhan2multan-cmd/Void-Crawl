class_name VCAudioSynth
extends RefCounted
## Procedural sound effects and music loops. Everything is synthesised from
## oscillators and noise at runtime, so VOIDCRAWL ships no third-party audio.

const SFX_RATE := 22050
const MUSIC_RATE := 11025

static func _wav(samples: PackedFloat32Array, rate: int, loop: bool = false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	var b := PackedByteArray()
	b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	s.data = b
	# Music is NOT given an engine loop: the loop wrap-around of AudioStreamWAV happens exactly
	# N seconds after playback starts, which lined up with the field crashes. game.gd restarts
	# the player from its `finished` signal instead (see _on_music_finished).
	return s

static func _buf(seconds: float, rate: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(maxi(1, int(seconds * float(rate))))
	return a

## Frequency sweep with exponential decay. f0->f1 over the clip.
static func _sweep(sec: float, f0: float, f1: float, decay: float, noise: float = 0.0, wave: int = 0, seed_: int = 1) -> PackedFloat32Array:
	var rate := SFX_RATE
	var a := _buf(sec, rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var ph := 0.0
	var n := a.size()
	var lp := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f := f0 * pow(f1 / f0, t) if f0 > 0.0 and f1 > 0.0 else f0
		ph += TAU * f / float(rate)
		var env := exp(-decay * t) * minf(1.0, float(i) / 60.0)
		var v := 0.0
		match wave:
			0: v = sin(ph)
			1: v = fposmod(ph / TAU, 1.0) * 2.0 - 1.0          # saw
			2: v = 1.0 if sin(ph) > 0.0 else -1.0               # square
			_: v = sin(ph) + 0.5 * sin(ph * 2.0)
		if noise > 0.0:
			lp = lp * 0.6 + (rng.randf() * 2.0 - 1.0) * 0.4
			v = v * (1.0 - noise) + lp * noise * 2.0
		a[i] = v * env * 0.6
	return a

static func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: int = 0, gain: float = 1.0) -> PackedFloat32Array:
	var out := a.duplicate()
	if offset + b.size() > out.size():
		out.resize(offset + b.size())
	for i in b.size():
		out[offset + i] += b[i] * gain
	return out

static func make_sfx(name: String) -> AudioStreamWAV:
	var s: PackedFloat32Array
	match name:
		"swing":
			s = _sweep(0.16, 900.0, 300.0, 5.0, 0.9, 0, 3)
		"hit":
			s = _mix(_sweep(0.14, 170.0, 55.0, 6.0, 0.15, 0, 5), _sweep(0.05, 1500.0, 700.0, 8.0, 0.8, 0, 6), 0, 0.5)
		"crit":
			s = _mix(_sweep(0.2, 200.0, 60.0, 5.0, 0.2, 3, 7), _sweep(0.25, 1800.0, 2600.0, 6.0, 0.0, 0, 8), 0, 0.5)
		"hurt":
			s = _sweep(0.24, 260.0, 90.0, 4.5, 0.25, 1, 9)
		"dodge":
			s = _sweep(0.22, 300.0, 1400.0, 3.0, 0.95, 0, 10)
		"coin":
			s = _mix(_sweep(0.10, 988.0, 988.0, 3.0, 0.0, 0, 11), _sweep(0.2, 1318.0, 1318.0, 4.5, 0.0, 0, 12), 1200, 1.0)
		"pickup":
			s = _mix(_sweep(0.12, 520.0, 780.0, 3.5), _sweep(0.2, 780.0, 1170.0, 4.0), 900)
		"chest":
			s = _sweep(0.12, 330.0, 330.0, 3.0)
			s = _mix(s, _sweep(0.12, 415.0, 415.0, 3.0), 2200)
			s = _mix(s, _sweep(0.12, 494.0, 494.0, 3.0), 4400)
			s = _mix(s, _sweep(0.35, 659.0, 659.0, 3.5), 6600)
		"levelup":
			s = _sweep(0.15, 392.0, 392.0, 3.0)
			s = _mix(s, _sweep(0.15, 494.0, 494.0, 3.0), 3000)
			s = _mix(s, _sweep(0.15, 587.0, 587.0, 3.0), 6000)
			s = _mix(s, _sweep(0.5, 784.0, 784.0, 3.0, 0.0, 3), 9000)
		"enemy_die":
			s = _mix(_sweep(0.4, 320.0, 40.0, 5.0, 0.3, 1, 13), _sweep(0.25, 1200.0, 200.0, 7.0, 0.9, 0, 14), 0, 0.5)
		"ability":
			s = _mix(_sweep(0.55, 90.0, 700.0, 2.5, 0.2, 3, 15), _sweep(0.5, 1400.0, 300.0, 3.0, 0.7, 0, 16), 0, 0.5)
		"shoot":
			s = _sweep(0.14, 700.0, 220.0, 5.0, 0.2, 2, 17)
		"enemy_shoot":
			s = _sweep(0.16, 420.0, 160.0, 5.0, 0.3, 1, 18)
		"click":
			s = _sweep(0.06, 760.0, 600.0, 6.0)
		"back":
			s = _sweep(0.07, 520.0, 380.0, 6.0)
		"boss_roar":
			s = _mix(_sweep(1.1, 62.0, 40.0, 1.6, 0.3, 1, 19), _sweep(1.0, 120.0, 70.0, 2.0, 0.5, 1, 20), 0, 0.6)
		"heal":
			s = _mix(_sweep(0.3, 440.0, 880.0, 2.5), _sweep(0.35, 660.0, 1320.0, 3.0), 1500)
		"door":
			s = _sweep(0.6, 70.0, 45.0, 2.0, 0.7, 1, 21)
		"telegraph":
			s = _sweep(0.25, 200.0, 420.0, 2.5, 0.1, 2, 22)
		"checkpoint":
			s = _sweep(0.3, 523.0, 1046.0, 2.5, 0.0, 3)
			s = _mix(s, _sweep(0.5, 784.0, 1568.0, 2.8, 0.0, 3), 2500)
		"victory":
			s = _sweep(0.2, 523.0, 523.0, 2.5, 0.0, 3)
			s = _mix(s, _sweep(0.2, 659.0, 659.0, 2.5, 0.0, 3), 4000)
			s = _mix(s, _sweep(0.2, 784.0, 784.0, 2.5, 0.0, 3), 8000)
			s = _mix(s, _sweep(0.8, 1046.0, 1046.0, 2.2, 0.0, 3), 12000)
		"defeat":
			s = _mix(_sweep(0.9, 220.0, 55.0, 2.5, 0.2, 1, 23), _sweep(0.9, 165.0, 40.0, 2.5, 0.2, 1, 24), 0, 0.6)
		_:
			s = _sweep(0.1, 600.0, 600.0, 4.0)
	return _wav(s, SFX_RATE)

## Slow dark-ambient loop: detuned drone plus sparse bell tones. kind: dungeon / menu / boss
static func make_music(kind: String) -> AudioStreamWAV:
	var rate := MUSIC_RATE
	var sec := 16.0
	var a := _buf(sec, rate)
	var n := a.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777 if kind == "dungeon" else (555 if kind == "menu" else 999)
	var root := 55.0 if kind != "boss" else 49.0
	var fifth := root * 1.5
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	var lfo_rate := 0.11 if kind != "boss" else 0.2
	for i in n:
		var t := float(i) / float(rate)
		var lfo := 0.5 + 0.5 * sin(TAU * lfo_rate * t)
		p1 += TAU * root / float(rate)
		p2 += TAU * (root * 1.005) / float(rate)
		p3 += TAU * fifth / float(rate)
		var v := 0.22 * sin(p1) + 0.18 * sin(p2) + 0.08 * lfo * sin(p3)
		v += 0.05 * sin(p1 * 2.0) * (1.0 - lfo)
		a[i] = v
	# bell tones from A minor pentatonic
	var scale := [1.0, 1.2, 1.333, 1.5, 1.8, 2.0]
	var notes := 7 if kind == "menu" else (9 if kind == "boss" else 5)
	for k in notes:
		var start := int(rng.randf() * float(n) * 0.8)
		var f: float = root * 4.0 * float(scale[rng.randi_range(0, scale.size() - 1)])
		var len_ := int(rate * 3.0)
		for j in len_:
			var idx := start + j
			if idx >= n:
				idx -= n
			var tt := float(j) / float(rate)
			var env := exp(-1.7 * tt) * minf(1.0, tt * 40.0)
			a[idx] += (sin(TAU * f * tt) + 0.3 * sin(TAU * f * 2.01 * tt)) * env * 0.07
	if kind == "boss":
		# slow pulse like a distant war drum
		var beat := int(rate * 0.8)
		var pos := 0
		while pos < n:
			for j in int(rate * 0.25):
				var idx := pos + j
				if idx >= n:
					break
				var tt := float(j) / float(rate)
				a[idx] += sin(TAU * (70.0 - 120.0 * tt) * tt) * exp(-12.0 * tt) * 0.3
			pos += beat
	# fade ends so the loop seam is inaudible
	var fade := int(rate * 0.25)
	for i in fade:
		var g := float(i) / float(fade)
		a[i] *= g
		a[n - 1 - i] *= g
	return _wav(a, rate, true)
