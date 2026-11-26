@tool
class_name SchoolDoor
extends StaticBody3D
## 문. 종류에 따라 E 키를 눌렀을 때 반응이 다르다.
##  - EXIT     : 비상구(계단) 문. 처음 E로 손잡이가 뜨거운지 확인하고, 다시 E로 연다.
##  - HOT      : 너머에 불이 난 문. 손잡이가 뜨겁다 → 열지 말아야 함.
##               확인한 뒤에도 다시 E로 억지로 열 수는 있지만, 열면 백드래프트로 불길이 덮친다.
##  - LOCKED   : 잠긴 문 (교실, 교무실 등)
##  - ELEVATOR : 엘리베이터. 화재 때는 타면 안 된다.
## 기준점 = 문 아래 가운데 (벽면 위). 문 앞면은 +Z 쪽을 향한다.

enum Kind { EXIT, HOT, LOCKED, ELEVATOR }

@export var kind: Kind = Kind.LOCKED:
	set(v):
		kind = v
		_rebuild()
@export_range(0.7, 2.5, 0.05) var width := 1.0:
	set(v):
		width = v
		_rebuild()
## 문 위 팻말 (비워두면 없음)
@export var plate_text := "":
	set(v):
		plate_text = v
		_rebuild()

var is_open := false
## 손등으로 손잡이를 확인했는지 (EXIT 문은 확인한 뒤에야 열 수 있다)
var is_checked := false
var _hinge: Node3D
var _shape: CollisionShape3D


func _ready() -> void:
	_rebuild()


func get_prompt() -> String:
	match kind:
		Kind.EXIT:
			if is_open:
				return ""
			return "E  문 열기" if is_checked else "E  손등으로 손잡이 만져보기"
		Kind.HOT:
			if is_open:
				return ""
			return "E  그래도 문 열기 (위험!)" if is_checked else "E  손등으로 손잡이 만져보기"
		Kind.ELEVATOR:
			return "E  엘리베이터 호출 버튼 누르기"
		_:
			return "E  문 열기"


## 결과: {"msg": 화면 안내, "event": 기록용 이름}
func interact() -> Dictionary:
	match kind:
		Kind.EXIT:
			if is_open:
				return {}
			if not is_checked:
				is_checked = true
				return {"msg": "손등으로 손잡이를 만져봤다. 뜨겁지 않다.\n문 너머에 불은 없는 것 같다. 이제 문을 열자.", "event": "exit_checked"}
			open()
			return {"msg": "문을 천천히 연다!", "event": "exit_opened"}
		Kind.HOT:
			if is_open:
				return {}
			if not is_checked:
				is_checked = true
				return {"msg": "앗, 뜨겁다! 문 너머에 불이 있다.\n이 문은 열지 말고 다른 길로 가자.", "event": "hot_checked"}
			# 경고를 무시하고 연다 → 백드래프트 (main.gd가 연출을 맡는다)
			open(0.25)
			return {"event": "backdraft", "door": self}
		Kind.ELEVATOR:
			return {"msg": "엘리베이터 버튼을 눌렀다…\n하지만 화재 때는 정전이나 연기로 갇힐 수 있다. 계단으로 가자!", "event": "elevator"}
		_:
			return {"msg": "잠겨 있다.", "event": ""}


## duration = 문이 다 열리기까지 걸리는 시간 (백드래프트 때는 불길에 밀려 확 열린다)
func open(duration := 0.9) -> void:
	if is_open:
		return
	is_open = true
	_shape.disabled = true
	if _hinge:
		var tw := create_tween()
		tw.tween_property(_hinge, "rotation:y", deg_to_rad(-100.0), duration).set_trans(Tween.TRANS_SINE)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	var door_mat := preload("res://materials/door.tres")
	var metal := preload("res://materials/metal.tres")
	var h := 2.1
	# 문틀
	_box(Vector3(-width * 0.5 - 0.04, h * 0.5, 0.02), Vector3(0.08, h, 0.06), metal, self)
	_box(Vector3(width * 0.5 + 0.04, h * 0.5, 0.02), Vector3(0.08, h, 0.06), metal, self)
	_box(Vector3(0, h + 0.04, 0.02), Vector3(width + 0.16, 0.08, 0.06), metal, self)
	if kind == Kind.ELEVATOR:
		for sx in [-1, 1]:
			_box(Vector3(sx * width * 0.25, h * 0.5, 0.0), Vector3(width * 0.5 - 0.01, h, 0.04), metal, self)
		_box(Vector3(width * 0.5 + 0.35, 1.15, 0.02), Vector3(0.14, 0.3, 0.04), metal, self)   # 버튼판
		_box(Vector3(width * 0.5 + 0.35, 1.15, 0.045), Vector3(0.05, 0.05, 0.02), preload("res://materials/red.tres"), self)
		_label("화재 시 사용 금지", Vector3(0, 1.55, 0.03), 26, Color(0.85, 0.1, 0.05))
		_hinge = null
	else:
		_hinge = Node3D.new()
		_hinge.position = Vector3(-width * 0.5, 0, 0)
		_add(_hinge, self)
		# 교실 문(팻말이 있는 잠긴 문·뜨거운 문)은 나무 문에 유리창, 계단 문은 철문
		var classroom := kind == Kind.LOCKED or (kind == Kind.HOT and plate_text != "")
		var mat := door_mat if classroom else metal
		_box(Vector3(width * 0.5, h * 0.5, 0.0), Vector3(width - 0.02, h - 0.02, 0.05), mat, _hinge)
		_box(Vector3(width - 0.12, 1.0, 0.05), Vector3(0.12, 0.03, 0.05), preload("res://materials/dark.tres"), _hinge)   # 손잡이
		if classroom:   # 교실 문 유리창 (안에 불이 난 교실은 유리창이 검붉게 일렁인다)
			_box(Vector3(width * 0.5, 1.5, 0.026), Vector3(width * 0.5, 0.5, 0.01), _ember_glass() if kind == Kind.HOT else preload("res://materials/glass.tres"), _hinge)
		if is_open:
			_hinge.rotation.y = deg_to_rad(-100.0)
	if plate_text != "":
		_box(Vector3(0, h + 0.35, 0.02), Vector3(0.6, 0.2, 0.03), preload("res://materials/wall.tres"), self)
		_label(plate_text, Vector3(0, h + 0.35, 0.04), 24, Color(0.1, 0.1, 0.1))
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, h, 0.12)
	_shape.shape = bs
	_shape.position = Vector3(0, h * 0.5, 0)
	_shape.disabled = is_open
	_add(_shape, self)


## 불씨가 남은 방을 비추는 유리: 연기에 그을려 어둡고, 안쪽 불빛이 검붉게 비친다
static func _ember_glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.06, 0.03)
	m.emission_enabled = true
	m.emission = Color(0.85, 0.26, 0.05)
	m.emission_energy_multiplier = 0.45
	return m


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_add(mi, parent)


func _label(text: String, pos: Vector3, size: int, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"])
	l.font = font
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.position = pos
	_add(l, self)


func _add(n: Node, parent: Node) -> void:
	n.set_meta("_gen", true)
	parent.add_child(n)
