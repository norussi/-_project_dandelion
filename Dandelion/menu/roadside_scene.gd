extends Control
## 메인 메뉴 배경: 해 질 녘 길가, 보도블록 틈에 홀로 핀 민들레.
## 외부 이미지 없이 매 프레임 직접 그린다.
## 움직이는 것: 흔들리는 꽃대와 잎, 날아가는 씨앗, 지나가는 자동차, 구름, 깜빡이는 창문과 가로등.

const SKY_TOP := Color("1d2546")
const SKY_MID := Color("5a4f86")
const SKY_LOW := Color("e9926a")
const SKY_HORIZON := Color("f8d49a")
const CITY_FAR := Color("4a3a5c")
const CITY_NEAR := Color("2c2238")
const ROAD := Color("3a3741")
const CURB_TOP := Color("c9bfb2")
const CURB_FACE := Color("8f877d")
const WALK := Color("c8b9a6")
const WALK_DARK := Color("ad9d89")
const TACTILE := Color("e2b33a")
const LEAF := Color("4e7a39")
const LEAF_LIGHT := Color("82aa58")
const STEM := Color("6e9a45")
const PETAL_OUT := Color("f2b01e")
const PETAL_MID := Color("ffcf3a")
const PETAL_IN := Color("ffe27a")

var t := 0.0
var wind := 0.0                 # 자동차가 지나갈 때 생기는 바람 (0~1)
var seeds: Array[Dictionary] = []
var cars: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var bokeh: Array[Dictionary] = []
var buildings_far: Array[Rect2] = []
var buildings_near: Array[Rect2] = []
var windows: Array[Dictionary] = []
var puff_gone: Dictionary = {}  # 솜털 머리에서 떨어져 나간 씨앗 번호 -> 다시 자랄 때까지 남은 시간
var rng := RandomNumberGenerator.new()
var seed_timer := 0.0
var ambient_timer := 0.0
var car_timer := 2.5

const PUFF_SEEDS := 54


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rng.seed = 20261103
	_make_city()
	for i in 4:
		clouds.append({"x": rng.randf(), "y": rng.randf_range(0.08, 0.3), "s": rng.randf_range(0.7, 1.4), "v": rng.randf_range(0.004, 0.009)})
	for i in 9:
		bokeh.append({"x": rng.randf(), "y": rng.randf_range(0.15, 0.95), "r": rng.randf_range(0.02, 0.06), "p": rng.randf() * TAU})
	for i in 10:
		_spawn_ambient_seed(true)


func _process(delta: float) -> void:
	t += delta
	wind = maxf(wind - delta * 0.35, 0.0)
	# 솜털 머리에서 씨앗이 떠나고, 시간이 지나면 다시 채워진다
	seed_timer -= delta
	if seed_timer <= 0.0:
		seed_timer = rng.randf_range(0.9, 2.2) - wind
		_release_seed()
	ambient_timer -= delta
	if ambient_timer <= 0.0:
		ambient_timer = rng.randf_range(1.6, 3.2)
		_spawn_ambient_seed(false)
	for k in puff_gone.keys():
		puff_gone[k] -= delta
		if puff_gone[k] <= 0.0:
			puff_gone.erase(k)
	_update_seeds(delta)
	_update_cars(delta)
	for c in clouds:
		c["x"] = fmod(c["x"] + c["v"] * delta, 1.35)
	queue_redraw()


# ---------------------------------------------------------------- 장면 구성 값

func _horizon() -> float:
	return size.y * 0.53

func _curb_y() -> float:
	return size.y * 0.685

func _flower_base() -> Vector2:
	return Vector2(size.x * 0.215, size.y * 0.715)

func _gust() -> float:
	# 평소의 산들바람 + 자동차가 지나간 뒤의 바람
	return sin(t * 0.85) * 0.045 + sin(t * 2.1 + 1.3) * 0.015 + wind * (0.10 + 0.04 * sin(t * 7.0))


# ---------------------------------------------------------------- 그리기

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 10 or h < 10:
		return
	_draw_sky(w, h)
	_draw_clouds(w, h)
	_draw_sun(w, h)
	_draw_city(w, h)
	_draw_lamp(w, h)
	_draw_road(w, h)
	_draw_cars(w, h, 0)
	_draw_cars(w, h, 1)
	_draw_sidewalk(w, h)
	_draw_dandelion(w, h)
	_draw_seeds()
	_draw_bokeh(w, h)
	_draw_vignette(w, h)
	# 가운데 제목과 버튼 뒤를 살짝 어둡게 해서 글자가 잘 읽히게
	for k in 4:
		_draw_ellipse(Vector2(w * 0.5, h * 0.4), w * (0.2 + k * 0.03), h * (0.13 + k * 0.02), Color(0.08, 0.05, 0.08, 0.07), 0.0, 40)


func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_sky(w: float, h: float) -> void:
	var hz := _horizon()
	_vgrad(Rect2(0, 0, w, hz * 0.45), SKY_TOP, SKY_MID)
	_vgrad(Rect2(0, hz * 0.45, w, hz * 0.35), SKY_MID, SKY_LOW)
	_vgrad(Rect2(0, hz * 0.8, w, hz * 0.2 + 1), SKY_LOW, SKY_HORIZON)
	# 이른 별 몇 개
	for i in 14:
		var sx := fmod(i * 0.6180339 * w * 1.7, w)
		var sy := fmod(i * 37.0, hz * 0.32) + 6
		var a := 0.25 + 0.25 * sin(t * 1.3 + i * 2.1)
		draw_circle(Vector2(sx, sy), 1.1, Color(1, 0.96, 0.85, a))


func _draw_clouds(w: float, h: float) -> void:
	for c in clouds:
		var cx: float = (c["x"] - 0.2) * w
		var cy: float = c["y"] * _horizon()
		var s: float = c["s"] * h * 0.05
		var col := Color(1.0, 0.78, 0.72, 0.16)
		for k in 5:
			draw_circle(Vector2(cx + (k - 2) * s * 0.9, cy + sin(k * 1.7) * s * 0.25), s * (1.0 - abs(k - 2) * 0.18), col)


func _draw_sun(w: float, h: float) -> void:
	var c := Vector2(w * 0.74, _horizon() - h * 0.035)
	var pulse := 1.0 + 0.02 * sin(t * 0.7)
	for k in 7:
		var r := h * (0.34 - k * 0.045) * pulse
		draw_circle(c, r, Color(1.0, 0.82, 0.55, 0.045 + k * 0.012))
	draw_circle(c, h * 0.052, Color("fff0c8"))


func _make_city() -> void:
	var x := -0.02
	while x < 1.02:
		var bw := rng.randf_range(0.035, 0.08)
		buildings_far.append(Rect2(x, 0, bw, rng.randf_range(0.06, 0.16)))
		x += bw + rng.randf_range(0.0, 0.01)
	x = 0.36
	while x < 1.02:
		var bw := rng.randf_range(0.05, 0.1)
		var bh := rng.randf_range(0.1, 0.24)
		buildings_near.append(Rect2(x, 0, bw, bh))
		var wx := x + 0.008
		while wx < x + bw - 0.012:
			var wy := 0.02
			while wy < bh - 0.02:
				if rng.randf() < 0.35:
					windows.append({"x": wx, "y": wy, "on": rng.randf() < 0.55, "p": rng.randf() * 30.0})
				wy += 0.028
			wx += 0.014
		x += bw + rng.randf_range(0.005, 0.03)


func _draw_city(w: float, h: float) -> void:
	var hz := _horizon()
	for b in buildings_far:
		draw_rect(Rect2(b.position.x * w, hz - b.size.y * h, b.size.x * w + 1, b.size.y * h), Color(CITY_FAR, 0.75))
	for b in buildings_near:
		draw_rect(Rect2(b.position.x * w, hz - b.size.y * h, b.size.x * w + 1, b.size.y * h), CITY_NEAR)
	for win in windows:
		# 창문은 아주 천천히 켜졌다 꺼진다
		var on: bool = win["on"]
		if fmod(t + win["p"], 30.0) < 1.2:
			on = not on
		if on:
			var wx: float = win["x"] * w
			var wy: float = hz - win["y"] * h
			draw_rect(Rect2(wx, wy - h * 0.012, w * 0.006, h * 0.012), Color(1.0, 0.82, 0.48, 0.85))


func _draw_lamp(w: float, h: float) -> void:
	var base := Vector2(w * 0.9, _curb_y() + h * 0.012)
	var top := Vector2(w * 0.9, h * 0.2)
	var flicker := 0.92 + 0.08 * sin(t * 13.0) * sin(t * 3.1)
	draw_line(base, top, Color("2a2430"), maxf(3.0, w * 0.004))
	draw_line(top, top + Vector2(-w * 0.045, -h * 0.015), Color("2a2430"), maxf(3.0, w * 0.0035))
	var bulb := top + Vector2(-w * 0.047, -h * 0.005)
	for k in 6:
		draw_circle(bulb, h * (0.16 - k * 0.025), Color(1.0, 0.86, 0.55, (0.035 + k * 0.012) * flicker))
	draw_circle(bulb, h * 0.012, Color(1.0, 0.95, 0.8, flicker))


func _draw_road(w: float, h: float) -> void:
	var hz := _horizon()
	var cy := _curb_y()
	_vgrad(Rect2(0, hz, w, cy - hz), Color("4a4650"), ROAD)
	# 차선: 가운데 점선
	var lane_y := hz + (cy - hz) * 0.42
	var dash := w * 0.06
	var x := -dash * 0.5
	while x < w:
		draw_rect(Rect2(x, lane_y, dash, maxf(2.0, h * 0.004)), Color(0.95, 0.9, 0.75, 0.55))
		x += dash * 2.0
	# 노을빛 반사
	_vgrad(Rect2(w * 0.55, hz, w * 0.4, (cy - hz) * 0.6), Color(1.0, 0.75, 0.5, 0.12), Color(1.0, 0.75, 0.5, 0.0))


func _update_cars(delta: float) -> void:
	car_timer -= delta
	if car_timer <= 0.0:
		car_timer = rng.randf_range(4.5, 9.0)
		var lane := rng.randi() % 2
		var dir := 1.0 if lane == 1 else -1.0
		cars.append({"lane": lane, "x": -0.35 if dir > 0 else 1.35, "dir": dir, "v": rng.randf_range(0.16, 0.24), "col": [Color("2b2a35"), Color("5b2f2f"), Color("2f4357"), Color("cfc8bd")][rng.randi() % 4], "passed": false})
	for c in cars:
		c["x"] += c["dir"] * c["v"] * delta
		# 가까운 차선의 차가 민들레 앞을 지나가면 바람이 인다
		if c["lane"] == 1 and not c["passed"] and abs(c["x"] - 0.215) < 0.05:
			c["passed"] = true
			wind = 1.0
			for i in 3:
				_release_seed()
	cars.assign(cars.filter(func(c): return c["x"] > -0.5 and c["x"] < 1.5))


func _draw_cars(w: float, h: float, lane: int) -> void:
	var hz := _horizon()
	var cy := _curb_y()
	for c in cars:
		if c["lane"] != lane:
			continue
		var s := 0.75 if lane == 0 else 1.0
		var base_y := hz + (cy - hz) * (0.36 if lane == 0 else 0.86)
		var cw := w * 0.16 * s
		var ch := h * 0.045 * s
		var x: float = c["x"] * w
		var front := 1.0 if c["dir"] > 0 else -1.0
		var body := Rect2(x - cw / 2, base_y - ch, cw, ch)
		var col: Color = c["col"]
		draw_rect(body, col)
		# 지붕
		var roof := PackedVector2Array([
			Vector2(x - cw * 0.28, base_y - ch), Vector2(x - cw * 0.18, base_y - ch * 1.75),
			Vector2(x + cw * 0.2, base_y - ch * 1.75), Vector2(x + cw * 0.32, base_y - ch)])
		draw_colored_polygon(roof, col.darkened(0.15))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - cw * 0.22, base_y - ch * 1.05), Vector2(x - cw * 0.15, base_y - ch * 1.62),
			Vector2(x + cw * 0.17, base_y - ch * 1.62), Vector2(x + cw * 0.26, base_y - ch * 1.05)]), Color(1.0, 0.85, 0.65, 0.35))
		# 바퀴
		for wx in [-0.3, 0.3]:
			draw_circle(Vector2(x + cw * wx, base_y), ch * 0.38, Color("141218"))
		# 전조등과 후미등
		var head := Vector2(x + front * cw * 0.5, base_y - ch * 0.55)
		var tail := Vector2(x - front * cw * 0.5, base_y - ch * 0.55)
		for k in 4:
			draw_circle(head + Vector2(front * ch * (0.4 + k * 0.5), 0), ch * (1.1 - k * 0.22), Color(1.0, 0.95, 0.75, 0.07 + k * 0.03))
		draw_circle(head, ch * 0.16, Color(1.0, 0.97, 0.85))
		draw_circle(tail, ch * 0.14, Color(1.0, 0.25, 0.2, 0.95))
		draw_circle(tail, ch * 0.5, Color(1.0, 0.2, 0.15, 0.12))


func _draw_sidewalk(w: float, h: float) -> void:
	var cy := _curb_y()
	var top_h := h * 0.014
	var face_h := h * 0.018
	draw_rect(Rect2(0, cy - face_h, w, face_h), CURB_FACE)
	draw_rect(Rect2(0, cy - face_h - top_h, w, top_h), CURB_TOP)
	var walk_top := cy
	_vgrad(Rect2(0, walk_top, w, h - walk_top), WALK_DARK, WALK)
	# 원근이 들어간 보도블록 줄눈
	var vp := Vector2(w * 0.62, _horizon() - h * 0.05)
	var rows := 7
	for i in range(1, rows + 1):
		var f := pow(float(i) / rows, 1.7)
		var y := walk_top + (h - walk_top) * f
		draw_line(Vector2(0, y), Vector2(w, y), Color(0.42, 0.36, 0.3, 0.35), 1.2)
	for i in range(-14, 26):
		var bx := w * 0.62 + i * w * 0.11
		var p_bottom := Vector2(bx, h)
		var dir := (vp - p_bottom).normalized()
		var tt := (walk_top - h) / dir.y
		draw_line(p_bottom, p_bottom + dir * tt, Color(0.42, 0.36, 0.3, 0.28), 1.0)
	# 노란 선형 점자블록 띠
	var ty0 := walk_top + (h - walk_top) * 0.36
	var ty1 := walk_top + (h - walk_top) * 0.62
	draw_rect(Rect2(0, ty0, w, ty1 - ty0), TACTILE)
	for k in 4:
		var yy := ty0 + (ty1 - ty0) * (k + 0.5) / 4.0
		draw_line(Vector2(0, yy), Vector2(w, yy), Color("f4cf62"), maxf(2.0, (ty1 - ty0) * 0.09))
		draw_line(Vector2(0, yy + (ty1 - ty0) * 0.06), Vector2(w, yy + (ty1 - ty0) * 0.06), Color("b8892a"), 1.0)
	for i in range(0, 40):
		var x := i * w * 0.09
		draw_line(Vector2(x, ty0), Vector2(x, ty1), Color(0.6, 0.45, 0.15, 0.45), 1.0)
	# 가로등 불빛이 바닥에 닿은 자리
	var glow := Vector2(w * 0.86, walk_top + (h - walk_top) * 0.4)
	for k in 5:
		_draw_ellipse(glow, w * (0.2 - k * 0.03), h * (0.07 - k * 0.011), Color(1.0, 0.85, 0.5, 0.05))
	# 민들레가 자란 틈
	var b := _flower_base()
	var crack := PackedVector2Array([b + Vector2(-w * 0.07, h * 0.006), b + Vector2(-w * 0.04, -h * 0.002),
		b + Vector2(-w * 0.015, h * 0.008), b + Vector2(w * 0.01, -h * 0.004), b + Vector2(w * 0.035, h * 0.01),
		b + Vector2(w * 0.06, h * 0.03), b + Vector2(w * 0.075, h * 0.07)])
	draw_polyline(crack, Color(0.25, 0.2, 0.16, 0.8), 2.0, true)
	draw_polyline(crack, Color(0.95, 0.9, 0.8, 0.25), 1.0, true)
	# 틈 사이 풀
	for i in 9:
		var gx := b.x + (i - 4) * w * 0.012 + sin(i * 3.1) * w * 0.004
		var gh := h * (0.025 + 0.02 * absf(sin(i * 1.7)))
		var bend := _gust() * 1.4 + sin(t * 1.6 + i) * 0.04
		draw_line(Vector2(gx, b.y), Vector2(gx + gh * bend * 3.0 + sin(i) * gh * 0.3, b.y - gh), Color("5f8a3e") if i % 2 else Color("7aa04d"), 2.0, true)


func _draw_ellipse(c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, n := 24) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, col)


# ---------------------------------------------------------------- 민들레

func _stem_points(base: Vector2, height: float, lean: float, sway: float, n := 18) -> PackedVector2Array:
	var a := lean + sway
	var tip := base + Vector2(sin(a) * height, -cos(a) * height)
	var ctrl := base + Vector2(sin(lean * 0.4 + sway * 0.25) * height * 0.5, -height * 0.55)
	var pts := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		pts.append(base.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u))
	return pts


func _draw_dandelion(w: float, h: float) -> void:
	var base := _flower_base()
	var g := _gust()
	# 잎: 사자 이빨처럼 뒤로 젖혀진 톱니가 있는 로제트
	# [각도, 길이, 폭] 뒤쪽 잎을 먼저 그리고 앞쪽 잎을 나중에 그린다
	var leaves := [[-1.95, 0.12, 0.8], [-1.3, 0.13, 0.85], [-2.55, 0.2, 1.0], [-0.6, 0.2, 1.0], [-2.95, 0.24, 1.1], [-0.18, 0.23, 1.1], [3.0, 0.15, 0.9], [0.12, 0.14, 0.85]]
	for lf in leaves:
		var ang: float = lf[0] + g * 0.25 + sin(t * 1.1 + lf[0]) * 0.025
		_draw_leaf(base, ang, h * lf[1] * 1.25, h * 0.03 * lf[2])
	# 꽃대 1: 노란 꽃
	var s1 := _stem_points(base + Vector2(-w * 0.004, 0), h * 0.4, -0.06, g)
	draw_polyline(s1, STEM.darkened(0.25), 6.0, true)
	draw_polyline(s1, STEM, 4.0, true)
	draw_polyline(s1, STEM.lightened(0.25), 1.2, true)
	_draw_flower(s1[s1.size() - 1], h * 0.058, g)
	# 꽃대 2: 솜털 씨앗 머리
	var s2 := _stem_points(base + Vector2(w * 0.006, 0), h * 0.47, 0.13, g * 1.25)
	draw_polyline(s2, STEM.darkened(0.3), 5.0, true)
	draw_polyline(s2, Color("7c9c52"), 3.2, true)
	_draw_puff(s2[s2.size() - 1], h * 0.07, g)
	# 꽃대 3: 아직 피지 않은 봉오리
	var s3 := _stem_points(base + Vector2(w * 0.002, 0), h * 0.2, 0.32, g * 0.8)
	draw_polyline(s3, STEM.darkened(0.2), 3.5, true)
	var bud := s3[s3.size() - 1]
	_draw_ellipse(bud, h * 0.011, h * 0.022, Color("5e8a3a"), 0.32 + g)
	_draw_ellipse(bud + Vector2(0, -h * 0.014).rotated(0.32 + g), h * 0.006, h * 0.008, Color(PETAL_OUT, 0.9), 0.32 + g)


func _draw_leaf(base: Vector2, angle: float, length: float, width: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var nrm := Vector2(-dir.y, dir.x)
	var n := 26
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	var spine := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var droop := u * u * length * 0.1
		var p := base + dir * length * u + Vector2(0, droop)
		# 잎 가장자리의 뒤로 젖혀진 톱니 (민들레 = 사자 이빨)
		var tooth := pow(1.0 - fmod(u * 4.0 + 0.3, 1.0), 2.0)
		var hw := width * pow(sin(PI * pow(u, 0.7)), 0.7) * (0.62 + 0.38 * tooth)
		up.append(p + nrm * hw)
		lo.append(p - nrm * hw * 0.85)
		spine.append(p)
	for i in n:
		var q := PackedVector2Array([up[i], up[i + 1], lo[i + 1], lo[i]])
		var shade := LEAF.lerp(LEAF_LIGHT, 0.15 + 0.25 * float(i) / n)
		draw_colored_polygon(q, shade)
	draw_polyline(spine, Color(LEAF_LIGHT, 0.8), 1.4, true)


func _draw_flower(c: Vector2, r: float, g: float) -> void:
	var breathe := 1.0 + 0.02 * sin(t * 1.4)
	var tilt := g * 0.6
	# 꽃받침
	for i in 9:
		var a := PI * 0.5 + (i - 4) * 0.28 + tilt
		var tip := c + Vector2(cos(a), sin(a)) * r * 0.75
		draw_line(c + Vector2(0, r * 0.15), tip, Color("4f7a35"), 2.0, true)
	# 꽃잎 세 겹
	var rings := [[30, 1.0, PETAL_OUT], [24, 0.78, PETAL_MID], [16, 0.52, PETAL_IN]]
	for ring in rings:
		var count: int = ring[0]
		var rr: float = ring[1] * r * breathe
		var col: Color = ring[2]
		for i in count:
			var a: float = TAU * i / count + float(ring[1]) * 0.7 + tilt
			var jitter := 0.9 + 0.1 * sin(i * 7.3 + ring[1] * 11.0)
			var plen := rr * jitter
			var pc := c + Vector2(cos(a), sin(a) * 0.86) * plen * 0.55
			_draw_ellipse(pc, plen * 0.5, maxf(1.6, r * 0.07), col, atan2(sin(a) * 0.86, cos(a)), 10)
	draw_circle(c, r * 0.2, Color("e9a514"))
	for i in 10:
		var a := TAU * i / 10.0 + t * 0.1
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.12, r * 0.035, Color("d18a0c"))


func _puff_dir(i: int) -> Vector2:
	var a := i * 2.39996323  # 황금각
	return Vector2(cos(a), sin(a)) * (0.72 + 0.28 * sqrt(float(i + 1) / PUFF_SEEDS))


func _draw_puff(c: Vector2, r: float, g: float) -> void:
	draw_circle(c, r * 1.12, Color(1, 0.98, 0.93, 0.08))
	draw_circle(c, r * 0.9, Color(1, 0.98, 0.93, 0.07))
	for i in PUFF_SEEDS:
		# puff_gone 값 = 다시 자랄 때까지 남은 시간. 마지막 2초 동안 서서히 다시 나타난다
		var back: float = puff_gone.get(i, 0.0)
		var alpha := 1.0 if back <= 0.0 else clampf(1.0 - back / 2.0, 0.0, 1.0)
		if alpha <= 0.01:
			continue
		var d := _puff_dir(i).rotated(g * 0.4)
		var tip := c + d * r
		draw_line(c, tip, Color(1, 1, 1, 0.38 * alpha), 1.0, true)
		var ang := d.angle()
		for k in 5:
			var fa := ang + (k - 2) * 0.32
			draw_line(tip, tip + Vector2(cos(fa), sin(fa)) * r * 0.2, Color(1, 0.99, 0.95, 0.55 * alpha), 1.0, true)
	draw_circle(c, r * 0.11, Color("8b7a5a"))


# ---------------------------------------------------------------- 날아가는 씨앗

func _release_seed() -> void:
	var free_ids := []
	for i in PUFF_SEEDS:
		if not puff_gone.has(i):
			free_ids.append(i)
	if free_ids.size() < 12:
		return
	var id: int = free_ids[rng.randi() % free_ids.size()]
	puff_gone[id] = rng.randf_range(14.0, 24.0)
	var base := _flower_base()
	var s2_tip := _stem_points(base + Vector2(size.x * 0.006, 0), size.y * 0.47, 0.13, _gust() * 1.25)
	var c := s2_tip[s2_tip.size() - 1]
	var p := c + _puff_dir(id) * size.y * 0.07
	seeds.append({"p": p, "v": Vector2(rng.randf_range(14, 30), rng.randf_range(-16, -4)), "rot": _puff_dir(id).angle() + PI * 0.5, "life": 0.0, "max": rng.randf_range(9.0, 16.0), "ph": rng.randf() * TAU, "s": rng.randf_range(0.85, 1.15)})


func _spawn_ambient_seed(anywhere: bool) -> void:
	var p := Vector2(-20, rng.randf_range(0.15, 0.85) * maxf(size.y, 720.0))
	if anywhere:
		p = Vector2(rng.randf() * maxf(size.x, 1280.0), rng.randf_range(0.1, 0.9) * maxf(size.y, 720.0))
	seeds.append({"p": p, "v": Vector2(rng.randf_range(16, 34), rng.randf_range(-8, 4)), "rot": 0.0, "life": rng.randf() * 3.0 if anywhere else 0.0, "max": rng.randf_range(14.0, 24.0), "ph": rng.randf() * TAU, "s": rng.randf_range(0.6, 1.0)})


func _update_seeds(delta: float) -> void:
	for s in seeds:
		s["life"] += delta
		var push := Vector2(18.0 + wind * 60.0, -6.0 - wind * 14.0)
		s["v"] = s["v"].lerp(push, delta * 0.4)
		var wob := Vector2(sin(t * 1.3 + s["ph"]) * 8.0, cos(t * 0.9 + s["ph"]) * 6.0)
		s["p"] += (s["v"] + wob) * delta
		s["rot"] = lerp_angle(s["rot"], sin(t * 0.8 + s["ph"]) * 0.35, delta * 0.8)
	seeds.assign(seeds.filter(func(s): return s["life"] < s["max"] and s["p"].x < size.x + 60 and s["p"].y > -60))


func _draw_seeds() -> void:
	for s in seeds:
		var life: float = s["life"]
		var a := clampf(life / 0.8, 0.0, 1.0) * clampf((s["max"] - life) / 2.0, 0.0, 1.0)
		var p: Vector2 = s["p"]
		var sc: float = s["s"] * size.y / 720.0
		var up := Vector2(0, -1).rotated(s["rot"])
		var achene := p - up * 11.0 * sc
		draw_line(p, achene, Color(1, 1, 1, 0.55 * a), 1.0, true)
		_draw_ellipse(achene, 1.4 * sc, 3.0 * sc, Color(0.55, 0.45, 0.32, 0.8 * a), up.angle() + PI * 0.5, 8)
		for k in 7:
			var fa := up.angle() + (k - 3) * 0.36
			draw_line(p, p + Vector2(cos(fa), sin(fa)) * 7.5 * sc, Color(1, 0.99, 0.95, 0.75 * a), 1.0, true)
		draw_circle(p, 5.0 * sc, Color(1, 1, 1, 0.06 * a))


func _draw_bokeh(w: float, h: float) -> void:
	for b in bokeh:
		var x: float = fmod(b["x"] * w + t * 6.0, w + 80) - 40
		var y: float = b["y"] * h + sin(t * 0.4 + b["p"]) * 10.0
		var a := 0.05 + 0.03 * sin(t * 0.7 + b["p"])
		draw_circle(Vector2(x, y), b["r"] * h, Color(1.0, 0.86, 0.55, a))


func _draw_vignette(w: float, h: float) -> void:
	var dark := Color(0.05, 0.03, 0.06, 0.55)
	var clear := Color(0.05, 0.03, 0.06, 0.0)
	_vgrad(Rect2(0, 0, w, h * 0.18), Color(0.05, 0.03, 0.06, 0.35), clear)
	_vgrad(Rect2(0, h * 0.82, w, h * 0.18), clear, dark)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.12, 0), Vector2(w * 0.12, h), Vector2(0, h)]),
		PackedColorArray([Color(0.05, 0.03, 0.06, 0.4), clear, clear, Color(0.05, 0.03, 0.06, 0.4)]))
	draw_polygon(PackedVector2Array([Vector2(w * 0.88, 0), Vector2(w, 0), Vector2(w, h), Vector2(w * 0.88, h)]),
		PackedColorArray([clear, Color(0.05, 0.03, 0.06, 0.4), Color(0.05, 0.03, 0.06, 0.4), clear]))
