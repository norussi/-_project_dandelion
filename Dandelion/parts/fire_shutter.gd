@tool
class_name FireShutter
extends StaticBody3D
## 방화셔터 (화재 차단벽). 화재 때 천장에서 내려와 복도를 막아 불길과 연기가 번지는 것을 막는다.
## 천장 아래 셔터 박스, 양옆 가이드 레일, 가로 철판(슬랫)을 이어 붙인 셔터 막,
## 바닥의 노란·검은 빗금(셔터가 내려오는 자리, 물건을 두면 안 됨)으로 이루어진다.
## 기준점 = 바닥 가운데. 셔터 막은 X축 방향으로 펼쳐지고 앞뒤(±Z) 양쪽에서 보인다.

## 막는 통로의 폭 (m)
@export_range(1.0, 6.0, 0.05) var width := 2.8:
	set(v):
		width = v
		_rebuild()
## 바닥에서 천장까지 높이 (m)
@export_range(2.0, 4.0, 0.05) var height := 3.0:
	set(v):
		height = v
		_rebuild()
## 내려온 정도 (0 = 천장 속에 감김, 1 = 바닥까지 닫힘)
@export_range(0.0, 1.0, 0.01) var closed := 1.0:
	set(v):
		closed = v
		_update_curtain()

const BOX_H := 0.32        # 셔터 박스 높이
const SLAT_H := 0.1        # 철판 한 장 높이

static var _stripe_tex: ImageTexture

var _curtain: Node3D
var _shape: CollisionShape3D


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("fire_shutters")


func get_prompt() -> String:
	return "E  방화셔터 살펴보기"


func interact() -> Dictionary:
	return {"msg": "방화셔터가 내려와 복도를 막고 있다.\n불길과 연기가 번지지 않도록 막는 화재 차단벽이다. 이쪽으로는 갈 수 없다.", "event": "shutter"}


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	var metal := preload("res://materials/metal.tres")
	var dark := preload("res://materials/dark.tres")
	var rail_top := height - BOX_H
	# 셔터 박스 (천장 아래)
	_box(Vector3(0, height - BOX_H * 0.5, 0), Vector3(width + 0.2, BOX_H, 0.42), metal, self)
	_box(Vector3(0, height - BOX_H, 0), Vector3(width, 0.02, 0.1), dark, self)    # 셔터가 나오는 틈
	# 가이드 레일 (양옆 벽에 붙은 홈)
	for sx in [-1, 1]:
		_box(Vector3(sx * (width * 0.5 - 0.03), rail_top * 0.5, 0), Vector3(0.08, rail_top, 0.16), metal, self)
	# 셔터 막: 가로 철판을 이어 붙인다. 위쪽 끝을 기준으로 내려오므로 _curtain 원점은 박스 아래에 둔다.
	_curtain = Node3D.new()
	_curtain.position = Vector3(0, rail_top, 0)
	_add(_curtain, self)
	var slat_a := StandardMaterial3D.new()
	slat_a.albedo_color = Color(0.56, 0.57, 0.58)
	slat_a.metallic = 0.4
	slat_a.roughness = 0.55
	var slat_b := StandardMaterial3D.new()
	slat_b.albedo_color = Color(0.47, 0.48, 0.49)
	slat_b.metallic = 0.4
	slat_b.roughness = 0.6
	var n := int(ceil(rail_top / SLAT_H))
	for i in n:
		var y := -(i + 0.5) * SLAT_H
		_box(Vector3(0, y, 0), Vector3(width - 0.1, SLAT_H - 0.006, 0.045), slat_a if i % 2 == 0 else slat_b, _curtain)
		_box(Vector3(0, y - SLAT_H * 0.5 + 0.003, 0), Vector3(width - 0.1, 0.012, 0.06), slat_b, _curtain)   # 이음매
	_box(Vector3(0, -rail_top + 0.03, 0), Vector3(width - 0.08, 0.06, 0.08), dark, _curtain)   # 맨 아래 하단바
	# 앞뒤 표지
	for side in [1.0, -1.0]:
		var basis := Basis.IDENTITY if side > 0 else Basis(Vector3.UP, PI)
		_label("방화셔터", basis, Vector3(0, -0.85, 0.035 * side), 64, Color(0.82, 0.08, 0.05))
		_label("화재 시 자동으로 내려와 불길과 연기를 막습니다", basis, Vector3(0, -1.1, 0.035 * side), 22, Color(0.12, 0.12, 0.12))
	# 바닥 빗금: 셔터가 내려오는 자리 (물건을 두면 안 되는 곳)
	var stripe := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, 0.5)
	stripe.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = _stripes()
	sm.uv1_scale = Vector3(width / 0.5, 1, 1)
	sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stripe.material_override = sm
	stripe.position.y = 0.004
	_add(stripe, self)
	# 닫혔을 때 지나갈 수 없게 막는 충돌
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 0.2)
	_shape.shape = bs
	_shape.position.y = height * 0.5
	_add(_shape, self)
	_update_curtain()


func _update_curtain() -> void:
	if _curtain == null:
		return
	# 감긴 부분은 셔터 박스 속으로 들어간 것처럼 박스 위로 올려 숨긴다
	var rail_top := height - BOX_H
	_curtain.position.y = rail_top + rail_top * (1.0 - closed)
	for c in _curtain.get_children():
		if c is Node3D:
			c.visible = _curtain.position.y + c.position.y < rail_top + 0.02
	if _shape:
		_shape.disabled = closed < 0.98


static func _stripes() -> ImageTexture:
	if _stripe_tex:
		return _stripe_tex
	var s := 64
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var yellow := int(floor((x + y) / 16.0)) % 2 == 0
			img.set_pixel(x, y, Color(0.95, 0.75, 0.08) if yellow else Color(0.08, 0.08, 0.08))
	img.generate_mipmaps()
	_stripe_tex = ImageTexture.create_from_image(img)
	return _stripe_tex


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_add(mi, parent)


func _label(text: String, basis: Basis, pos: Vector3, size: int, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"])
	font.font_weight = 700
	l.font = font
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.transform = Transform3D(basis, pos)
	_add(l, _curtain)


func _add(n: Node, parent: Node) -> void:
	n.set_meta("_gen", true)
	parent.add_child(n)
