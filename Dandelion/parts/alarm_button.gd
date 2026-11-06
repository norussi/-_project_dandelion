@tool
class_name AlarmButton
extends StaticBody3D
## 화재 발신기 (비상벨 누름 버튼). 빨간 상자. E 키로 누르면 건물 전체에 비상벨이 울린다.
## 기준점 = 상자 가운데. 앞면은 +Z 쪽을 향한다.

var _lamp: MeshInstance3D


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("alarm_buttons")


func get_prompt() -> String:
	return "E  비상벨(발신기) 누르기"


func interact() -> Dictionary:
	return {"msg": "", "event": "alarm"}


func set_lamp(on: bool) -> void:
	if _lamp:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1, 0.2, 0.1)
		m.emission_enabled = on
		m.emission = Color(1, 0.15, 0.05)
		m.emission_energy_multiplier = 3.0
		_lamp.material_override = m


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	var red := preload("res://materials/red.tres")
	_box(Vector3.ZERO, Vector3(0.32, 0.42, 0.08), red)
	_box(Vector3(0, -0.04, 0.045), Vector3(0.12, 0.12, 0.02), preload("res://materials/metal.tres"))   # 누름 버튼
	_lamp = _box(Vector3(0, 0.3, 0.02), Vector3(0.14, 0.1, 0.1), red)                             # 표시등
	var l := Label3D.new()
	l.text = "발신기\n누르세요"
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"])
	l.font = font
	l.font_size = 20
	l.pixel_size = 0.0035
	l.modulate = Color.WHITE
	l.outline_size = 0
	l.shaded = true
	l.position = Vector3(0, 0.12, 0.045)
	l.set_meta("_gen", true)
	add_child(l)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.32, 0.42, 0.1)
	cs.shape = bs
	cs.set_meta("_gen", true)
	add_child(cs)


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.set_meta("_gen", true)
	add_child(mi)
	return mi
