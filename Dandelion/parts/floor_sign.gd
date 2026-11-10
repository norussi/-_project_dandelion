@tool
class_name FloorSign
extends Node3D
## 계단실 층수 표지. 층계참 벽에 붙여 지금 몇 층인지 알려 준다.
## 실제 계단실처럼 큰 숫자(3F)와 작은 글씨(3층)를 쓰고, 정전된 연기 속에서도
## 읽을 수 있도록 축광 표지처럼 은은하게 빛난다.
## 기준점 = 표지판 가운데. 표지면은 +Z 쪽을 향한다 (벽에 붙일 때 +Z가 계단 쪽).

@export_range(1, 20) var floor_number := 1:
	set(v):
		floor_number = v
		_rebuild()

const PLATE := Vector3(0.62, 0.46, 0.02)
const TEXT_COLOR := Color(0.06, 0.32, 0.18)
const FONT_NAMES := ["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"]

static var _plate_mat: StandardMaterial3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	if _plate_mat == null:
		_plate_mat = StandardMaterial3D.new()
		_plate_mat.albedo_color = Color(0.93, 0.95, 0.88)
		_plate_mat.emission_enabled = true
		_plate_mat.emission = Color(0.55, 0.7, 0.5)   # 축광 표지의 연한 연두빛
		_plate_mat.emission_energy_multiplier = 0.35
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = PLATE
	plate.mesh = bm
	plate.material_override = _plate_mat
	plate.position = Vector3(0, 0, PLATE.z * 0.5)
	_add(plate)
	_label("%dF" % floor_number, Vector3(0, 0.05, PLATE.z + 0.002), 120)
	_label("%d층" % floor_number, Vector3(0, -0.16, PLATE.z + 0.002), 36)


func _label(text: String, pos: Vector3, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	font.font_weight = 800
	l.font = font
	l.font_size = size
	l.pixel_size = 0.0025
	l.modulate = TEXT_COLOR
	l.outline_size = 0
	l.shaded = false   # 어두운 계단실에서도 글자가 묻히지 않게
	l.position = pos
	_add(l)


func _add(n: Node) -> void:
	n.set_meta("_gen", true)
	add_child(n)
