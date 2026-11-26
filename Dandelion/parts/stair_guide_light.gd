@tool
class_name StairGuideLight
extends Node3D
## 계단통로유도등 (신형, 층수 표시). 계단 중간의 층계참(반층) 벽 아래쪽에 단다.
## 이 층계참에서 올라가면 몇 층, 내려가면 몇 층인지 화살표와 함께 보여 주고,
## 아래로 비추는 빛으로 층계참 바닥과 계단 디딤면을 밝힌다.
## 연기 속에서도 보이도록 표시면에서 은은한 흰빛·초록빛이 번진다.
## 기준점 = 표시면 가운데. 표시면은 +Z 쪽을 향한다 (벽에 붙일 때 +Z가 계단 쪽).

## 위로 올라가면 나오는 층
@export_range(1, 20) var upper_floor := 2:
	set(v):
		upper_floor = v
		_rebuild()
## 아래로 내려가면 나오는 층 (0 = 이 층계참이 건물 밖으로 나가는 층: 표시면 왼쪽의 출구 문을 가리킨다)
@export_range(0, 20) var lower_floor := 1:
	set(v):
		lower_floor = v
		_rebuild()

const PLATE := Vector2(0.42, 0.3)
const GREEN := Color(0.03, 0.5, 0.25)
const FONT_NAMES := ["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"]
const GLOW_SHADER := preload("res://shaders/glow_sprite.gdshader")

static var _face_mat: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	# 본체 상자
	var housing := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(PLATE.x + 0.04, PLATE.y + 0.04, 0.06)
	housing.mesh = hb
	housing.material_override = preload("res://materials/metal.tres")
	housing.position.z = -0.03
	_add(housing)
	# 표시면 (안에서 불이 켜진 흰 면)
	if _face_mat == null:
		_face_mat = StandardMaterial3D.new()
		_face_mat.albedo_color = Color(0.97, 0.98, 0.95)
		_face_mat.emission_enabled = true
		_face_mat.emission = Color(0.95, 1.0, 0.95)
		_face_mat.emission_energy_multiplier = 0.9
	var face := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = PLATE
	face.mesh = qm
	face.material_override = _face_mat
	face.position.z = 0.001
	_add(face)
	# 가운데 가로줄로 위층 / 아래층을 나눈다
	var line := MeshInstance3D.new()
	var lm := QuadMesh.new()
	lm.size = Vector2(PLATE.x - 0.04, 0.008)
	line.mesh = lm
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = GREEN
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = line_mat
	line.position.z = 0.002
	_add(line)
	_label("▲  %dF" % upper_floor, Vector3(0, 0.072, 0.003), 64)
	# 가장 아래 층계참은 건물 밖으로 나가는 층(피난층)이라, 옆의 출구 문을 가리킨다
	_label("◀  출구" if lower_floor <= 0 else "▼  %dF" % lower_floor, Vector3(0, -0.072, 0.003), 64)
	# 연기 속 후광
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(1.0, 1.0)
	halo.mesh = hq
	var gm := ShaderMaterial.new()
	gm.shader = GLOW_SHADER
	gm.set_shader_parameter("glow_color", Color(0.7, 1.0, 0.78))
	gm.set_shader_parameter("intensity", 0.5)
	gm.set_shader_parameter("see_falloff", 0.1)
	gm.set_shader_parameter("softness", 3.5)
	halo.material_override = gm
	halo.position.z = 0.08
	halo.extra_cull_margin = 2.0
	_add(halo)
	# 층계참 바닥과 계단을 비추는 빛 (계단통로유도등은 바닥면과 디딤면을 비춘다)
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 1.0, 0.88)
	l.light_energy = 0.7
	l.omni_range = 3.2
	l.position = Vector3(0, -0.25, 0.45)
	_add(l)


func _label(text: String, pos: Vector3, size: int) -> void:
	var lb := Label3D.new()
	lb.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.font_weight = 800
	lb.font = font
	lb.font_size = size
	lb.pixel_size = 0.0018
	lb.modulate = GREEN
	lb.outline_size = 0
	lb.shaded = false
	lb.position = pos
	_add(lb)


func _add(n: Node) -> void:
	n.set_meta("_gen", true)
	add_child(n)
