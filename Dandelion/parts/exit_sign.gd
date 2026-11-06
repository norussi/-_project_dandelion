@tool
class_name ExitSign
extends Node3D
## 유도등. 연기 속에서도 초록 빛이 번져 보인다.
##  - 피난구 유도등: 초록 바탕 + 흰 사람 + 문. 비상구(계단) 문 위에 단다.
##  - 통로 유도등: 흰 바탕 + 초록 화살표. 복도 벽 아래쪽(바닥에서 1m 이하)에 단다.
## 기준점 = 표시면 가운데. 표시면은 +Z 쪽을 향한다 (벽에 붙일 때 +Z가 복도 쪽).

enum Kind { EXIT_DOOR, CORRIDOR }
enum Arrow { NONE, LEFT, RIGHT, BOTH }

@export var kind: Kind = Kind.CORRIDOR:
	set(v):
		kind = v
		_rebuild()
## 보는 사람 기준 화살표 방향 (통로 유도등)
@export var arrow: Arrow = Arrow.LEFT:
	set(v):
		arrow = v
		_rebuild()
## 주변을 비추는 초록 불빛 세기
@export_range(0.0, 2.0, 0.05) var light_energy := 0.35:
	set(v):
		light_energy = v
		_rebuild()

const FACE_SHADER := preload("res://shaders/sign_face.gdshader")
const GLOW_SHADER := preload("res://shaders/glow_sprite.gdshader")
const GREEN := Color(0.05, 0.62, 0.32)
const WHITE := Color(0.97, 0.98, 0.95)

static var _tex_cache := {}


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	var size := Vector2(0.62, 0.31) if kind == Kind.EXIT_DOOR else Vector2(0.5, 0.17)
	# 본체 상자
	var housing := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(size.x + 0.04, size.y + 0.04, 0.07)
	housing.mesh = hb
	housing.material_override = preload("res://materials/metal.tres")
	housing.position.z = -0.04
	_add(housing)
	# 표시면
	var face := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	face.mesh = qm
	var fm := ShaderMaterial.new()
	fm.shader = FACE_SHADER
	fm.set_shader_parameter("sign_texture", _texture(kind, arrow))
	face.material_override = fm
	face.position.z = 0.001
	_add(face)
	# 연기 속 후광
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	var hs := 1.7 if kind == Kind.EXIT_DOOR else 1.1
	hq.size = Vector2(hs, hs)
	halo.mesh = hq
	var gm := ShaderMaterial.new()
	gm.shader = GLOW_SHADER
	gm.set_shader_parameter("glow_color", Color(0.25, 1.0, 0.45) if kind == Kind.EXIT_DOOR else Color(0.55, 1.0, 0.65))
	gm.set_shader_parameter("intensity", 0.9 if kind == Kind.EXIT_DOOR else 0.55)
	gm.set_shader_parameter("see_falloff", 0.085)
	gm.set_shader_parameter("softness", 3.5)
	halo.material_override = gm
	halo.position.z = 0.08
	halo.extra_cull_margin = 2.0
	_add(halo)
	# 주변 벽·바닥을 비추는 빛
	if light_energy > 0.0:
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 1.0, 0.5)
		l.light_energy = light_energy
		l.omni_range = 2.6
		l.position.z = 0.3
		_add(l)


func _add(n: Node) -> void:
	n.set_meta("_gen", true)
	add_child(n)


# ------------------------------------------------------------ 표시면 그림 생성
static func _texture(k: int, a: int) -> Texture2D:
	var key := "%d_%d" % [k, a]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var w := 192
	var h := 96 if k == Kind.EXIT_DOOR else 64
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var bg := GREEN if k == Kind.EXIT_DOOR else WHITE
	var fg := WHITE if k == Kind.EXIT_DOOR else GREEN
	var segs := []    # [Vector2 a, Vector2 b, 두께]
	var circles := [] # [Vector2 c, 반지름]
	var tris := []    # [Vector2, Vector2, Vector2]
	var flip := a == Arrow.LEFT
	if k == Kind.EXIT_DOOR:
		_runner(segs, circles, Rect2(8, 6, 96, 84), false)
		# 문 (흰 테두리)
		var d := Rect2(120, 10, 56, 78)
		var t := 7.0
		segs.append([d.position, Vector2(d.end.x, d.position.y), t])
		segs.append([Vector2(d.end.x, d.position.y), d.end, t])
		segs.append([Vector2(d.position.x, d.end.y), d.end, t])
		segs.append([d.position, Vector2(d.position.x, d.end.y), t])
	else:
		# 작은 사람 + 화살표
		var rx := 118.0 if flip else 8.0
		_runner(segs, circles, Rect2(rx, 6, 64, 54), flip)
		var ax0 := 18.0 if flip else 84.0
		var ax1 := 108.0 if flip else 180.0
		if a != Arrow.NONE:
			var y := 32.0
			segs.append([Vector2(ax0 + (22 if flip else 0), y), Vector2(ax1 - (0 if flip else 22), y), 12.0])
			if flip or a == Arrow.BOTH:
				tris.append([Vector2(ax0, y), Vector2(ax0 + 30, y - 22), Vector2(ax0 + 30, y + 22)])
			if not flip or a == Arrow.BOTH:
				tris.append([Vector2(ax1, y), Vector2(ax1 - 30, y - 22), Vector2(ax1 - 30, y + 22)])
	for py in h:
		for px in w:
			var p := Vector2(px + 0.5, py + 0.5)
			var cover := 0.0
			for s in segs:
				var dist: float = _seg_dist(p, s[0], s[1]) - float(s[2]) * 0.5
				cover = maxf(cover, clampf(0.5 - dist, 0.0, 1.0))
			for c in circles:
				cover = maxf(cover, clampf(0.5 - (p.distance_to(c[0]) - c[1]), 0.0, 1.0))
			for t in tris:
				if Geometry2D.point_is_inside_triangle(p, t[0], t[1], t[2]):
					cover = 1.0
			img.set_pixel(px, py, bg.lerp(fg, cover))
	# 테두리
	for px in w:
		for b in 2:
			img.set_pixel(px, b, bg.darkened(0.3))
			img.set_pixel(px, h - 1 - b, bg.darkened(0.3))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex_cache[key] = tex
	return tex


## 달리는 사람 그림 (r 영역 안, flip 이면 왼쪽으로 달림)
static func _runner(segs: Array, circles: Array, r: Rect2, flip: bool) -> void:
	var f := func(x: float, y: float) -> Vector2:
		var xx := (1.0 - x) if flip else x
		return r.position + Vector2(xx * r.size.x, y * r.size.y)
	var t := r.size.y * 0.1
	circles.append([f.call(0.62, 0.13), r.size.y * 0.1])
	segs.append([f.call(0.58, 0.28), f.call(0.45, 0.56), t * 1.3])          # 몸통
	segs.append([f.call(0.56, 0.33), f.call(0.72, 0.43), t])                # 앞팔
	segs.append([f.call(0.72, 0.43), f.call(0.84, 0.33), t])
	segs.append([f.call(0.54, 0.33), f.call(0.38, 0.40), t])                # 뒷팔
	segs.append([f.call(0.38, 0.40), f.call(0.28, 0.31), t])
	segs.append([f.call(0.45, 0.56), f.call(0.62, 0.72), t * 1.1])          # 앞다리
	segs.append([f.call(0.62, 0.72), f.call(0.60, 0.94), t * 1.1])
	segs.append([f.call(0.45, 0.56), f.call(0.31, 0.73), t * 1.1])          # 뒷다리
	segs.append([f.call(0.31, 0.73), f.call(0.14, 0.76), t * 1.1])


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * tt)
