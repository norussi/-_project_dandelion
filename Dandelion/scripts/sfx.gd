extends Node
## 효과음을 코드로 만들어 재생 (autoload: Sfx). 외부 음원 파일 없이 동작한다.

const RATE := 22050

var _streams := {}
var _loops := {}


func _ready() -> void:
	_streams["alarm"] = _make_bell()
	_streams["crackle"] = _make_crackle()
	_streams["cough"] = _make_cough()
	_streams["step"] = _make_step()
	_streams["door"] = _make_door()
	_streams["beep"] = _make_beep()


func get_stream(n: String) -> AudioStream:
	return _streams[n]


func play(n: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[n]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_at(n: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[n]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = 4.0
	add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func start_loop(n: String, volume_db := 0.0) -> void:
	if _loops.has(n):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[n]
	p.volume_db = volume_db
	add_child(p)
	p.play()
	_loops[n] = p


func stop_all_loops() -> void:
	for p in _loops.values():
		p.queue_free()
	_loops.clear()


# ------------------------------------------------------------ 생성기
## 비상벨: 망치가 종을 빠르게 두드리는 "따르르르릉" 소리 (반복 재생)
func _make_bell() -> AudioStreamWAV:
	var n := RATE   # 1초 반복
	var s := PackedFloat32Array()
	s.resize(n)
	var strikes := 20
	var partials := [[1180.0, 1.0], [2950.0, 0.55], [4700.0, 0.3], [6300.0, 0.15]]
	for i in n:
		var t := float(i) / RATE
		var since := fmod(t, 1.0 / strikes)
		var v := 0.0
		for pp in partials:
			v += sin(TAU * pp[0] * t) * pp[1] * exp(-since * 55.0)
		v += sin(TAU * 1180.0 * t) * 0.25   # 계속 울리는 잔향
		s[i] = v * 0.45
	return _to_wav(s, true)


## 불 타는 소리: 낮은 웅웅거림 + 타닥타닥 튀는 소리 (반복 재생)
func _make_crackle() -> AudioStreamWAV:
	var n := RATE * 3
	var s := PackedFloat32Array()
	s.resize(n)
	var brown := 0.0
	var pop := 0.0
	for i in n:
		brown = clampf(brown + randf_range(-1.0, 1.0) * 0.06, -1.0, 1.0) * 0.995
		if randf() < 0.0009:
			pop = randf_range(0.5, 1.0)
		pop *= 0.985
		s[i] = brown * 0.6 + randf_range(-1.0, 1.0) * pop * 0.8
	# 이음매 부드럽게
	for i in 400:
		var k := float(i) / 400.0
		s[i] *= k
		s[n - 1 - i] *= k
	return _to_wav(s, true)


## 기침: 거친 바람소리 두 번
func _make_cough() -> AudioStreamWAV:
	var n := int(0.65 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		for start in [0.0, 0.3]:
			var d: float = t - start
			if d >= 0.0:
				env += minf(1.0, d / 0.012) * exp(-d * 14.0)
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)
		s[i] = (lp * 0.9 + sin(TAU * 180.0 * t) * 0.15) * env
	return _to_wav(s, false)


func _make_step() -> AudioStreamWAV:
	var n := int(0.12 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = (sin(TAU * 100.0 * t) * 0.4 + randf_range(-1.0, 1.0) * 0.5) * exp(-t * 32.0)
	return _to_wav(s, false)


func _make_door() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var creak := sin(TAU * (300.0 + 80.0 * sin(t * 30.0)) * t) * 0.3 * exp(-t * 4.0)
		var thump := (sin(TAU * 70.0 * t) + randf_range(-0.5, 0.5)) * exp(-t * 20.0) * 0.6
		s[i] = creak + thump
	return _to_wav(s, false)


func _make_beep() -> AudioStreamWAV:
	var n := int(0.15 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 880.0 * t) * minf(1.0, (n - i) / 300.0) * 0.5
	return _to_wav(s, false)


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
