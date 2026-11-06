@tool
class_name Descender
extends StaticBody3D
## 완강기 세트. 실제 사용 순서대로 E 키로 진행한다.
##  1) 완강기함 열기 → 2) 완강기 꺼내기 → 3) 창문 열기 → 4) 지지대에 고리 걸기(고정)
##  5) 아래를 확인하고 로프 던지기 → 6) 벨트를 가슴 위로 입고 조이기 → 7) 창틀에서 내려가기
## 같은 스크립트를 세 군데에 쓴다 (part): 완강기함(CASE) / 고정 지지대(ANCHOR) / 창문(WINDOW).
## 기준점 = 벽면 위 바닥. 앞면(+Z)이 복도 쪽, 창밖은 -Z 쪽이다. (북쪽 벽에 붙일 때 Y축으로 180° 돌린다)

enum Part { CASE, ANCHOR, WINDOW }

@export var part: Part = Part.CASE:
	set(v):
		part = v
		_rebuild()
## 창문 아래 지면까지 로프 길이 (m)
@export var drop_height := 12.6:
	set(v):
		drop_height = v
		_rebuild()

## 0 함 닫힘 → 1 함 열림 → 2 꺼냄 → 3 고정함 → 4 로프 내림 → 5 벨트 착용
static var stage := 0
static var window_open := false

var _door: Node3D
var _reel: Node3D
var _hinge_l: Node3D
var _hinge_r: Node3D
var _rope_in: Node3D
var _rope_out: Node3D
var _hooked_reel: Node3D


static func reset() -> void:
	stage = 0
	window_open = false


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("descender_parts")


# ------------------------------------------------------------------ 상호작용
func get_prompt() -> String:
	match part:
		Part.CASE:
			if stage == 0:
				return "E  완강기함 열기"
			if stage == 1:
				return "E  완강기 꺼내기"
		Part.ANCHOR:
			if stage < 2:
				return "E  완강기 고정 지지대"
			if stage == 2:
				return "E  지지대에 완강기 고리 걸기"
		Part.WINDOW:
			if not window_open:
				return "E  창문 열기"
			match stage:
				3:
					return "E  아래를 확인하고 로프 던지기"
				4:
					return "E  벨트를 가슴 위로 입고 조이기"
				5:
					return "E  창틀에 걸터앉아 내려가기"
	return ""


func interact() -> Dictionary:
	var res := {}
	match part:
		Part.CASE:
			if stage == 0:
				stage = 1
				res = {"msg": "완강기함을 열었다.\n안에 완강기(릴)와 로프, 벨트, 고리가 들어 있다.", "event": "desc_case"}
			elif stage == 1:
				stage = 2
				res = {"msg": "완강기를 꺼냈다.\n먼저 창문 아래 벽의 고정 지지대에 고리를 걸어야 한다.", "event": "desc_take"}
		Part.ANCHOR:
			if stage < 2:
				res = {"msg": "벽에 튼튼한 고리가 박혀 있다. 완강기를 고정하는 지지대다.\n먼저 완강기함에서 완강기를 꺼내자.", "event": ""}
			elif stage == 2:
				stage = 3
				res = {"msg": "고리를 지지대에 걸고 잠금장치를 돌렸다.\n힘껏 당겨 봐도 빠지지 않는다. 고정 완료!", "event": "desc_hook"}
		Part.WINDOW:
			if not window_open:
				window_open = true
				res = {"msg": "창문을 활짝 열었다.\n연기가 빠져나가고 찬 공기가 들어온다.", "event": "desc_window"}
			else:
				match stage:
					0, 1, 2:
						res = {"msg": "완강기가 필요하다. 완강기함은 복도 쪽 벽에 있다.", "event": ""}
					3:
						stage = 4
						res = {"msg": "아래에 사람이나 장애물이 없는지 확인했다.\n로프 릴을 창밖으로 던지자 로프가 지면까지 풀려 내려갔다.", "event": "desc_rope"}
					4:
						stage = 5
						res = {"msg": "벨트를 머리부터 넣어 겨드랑이 밑, 가슴 위에 걸고\n조임쇠를 당겨 몸에 단단히 조였다.", "event": "desc_belt"}
					5:
						res = {"event": "descend", "window": self}
	if not res.is_empty():
		get_tree().call_group("descender_parts", "_refresh")
	return res


# ------------------------------------------------------------------ 겉모습
func _refresh() -> void:
	match part:
		Part.CASE:
			if _door:
				var tw := create_tween()
				tw.tween_property(_door, "rotation:y", deg_to_rad(-105.0) if stage >= 1 else 0.0, 0.5).set_trans(Tween.TRANS_SINE)
			if _reel:
				_reel.visible = stage < 2
		Part.ANCHOR:
			if _rope_in:
				_rope_in.visible = stage >= 3
			if _hooked_reel:
				_hooked_reel.visible = stage >= 3
		Part.WINDOW:
			if _hinge_l:
				var tw := create_tween()
				tw.set_parallel(true)
				tw.tween_property(_hinge_l, "rotation:y", deg_to_rad(-95.0) if window_open else 0.0, 0.7).set_trans(Tween.TRANS_SINE)
				tw.tween_property(_hinge_r, "rotation:y", deg_to_rad(95.0) if window_open else 0.0, 0.7).set_trans(Tween.TRANS_SINE)
			if _rope_out:
				_rope_out.visible = stage >= 4


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	_door = null
	_reel = null
	_hinge_l = null
	_hinge_r = null
	_rope_in = null
	_rope_out = null
	_hooked_reel = null
	var metal := preload("res://materials/metal.tres")
	var red := preload("res://materials/red.tres")
	var glass := preload("res://materials/glass.tres")
	var dark := preload("res://materials/dark.tres")
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.95, 0.45, 0.08)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	match part:
		Part.CASE:
			_box(Vector3(0, 0.55, 0.08), Vector3(0.5, 0.7, 0.16), red, self)
			_box(Vector3(0, 0.55, 0.165), Vector3(0.42, 0.62, 0.01), dark, self)   # 함 안쪽
			_reel = _cyl(Vector3(0, 0.5, 0.1), 0.12, 0.2, orange, self, true)
			_box(Vector3(0, 0.5, 0.1), Vector3(0.3, 0.05, 0.04), dark, self)
			_door = Node3D.new()
			_door.position = Vector3(-0.25, 0.55, 0.17)
			_add(_door, self)
			_box(Vector3(0.25, 0, 0.01), Vector3(0.5, 0.7, 0.02), red, _door)
			_box(Vector3(0.25, 0.1, 0.022), Vector3(0.34, 0.3, 0.01), glass, _door)
			_label("완강기", Vector3(0.25, -0.2, 0.025), 34, Color.WHITE, _door)
			_label("완강기", Vector3(0, 1.05, 0.02), 40, Color(0.9, 0.1, 0.05), self)
			bs.size = Vector3(0.5, 0.7, 0.2)
			cs.position = Vector3(0, 0.55, 0.1)
		Part.ANCHOR:
			_box(Vector3(0, 0.45, 0.02), Vector3(0.24, 0.24, 0.04), metal, self)
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.035
			tm.outer_radius = 0.065
			ring.mesh = tm
			ring.material_override = metal
			ring.rotation.x = deg_to_rad(90.0)
			ring.position = Vector3(0, 0.45, 0.06)
			_add(ring, self)
			_hooked_reel = _cyl(Vector3(0, 0.33, 0.12), 0.1, 0.16, orange, self, true)
			_rope_in = _cyl(Vector3(0, 0.72, 0.07), 0.012, 0.5, orange, self, false)
			bs.size = Vector3(0.3, 0.3, 0.1)
			cs.position = Vector3(0, 0.45, 0.05)
		Part.WINDOW:
			# 개구부: 폭 2.0, 높이 0.95 ~ 2.5 (map.tscn 의 북쪽 벽 창문과 같은 크기)
			var frame := preload("res://materials/frame_green.tres")
			var pane := preload("res://materials/window_glass.tres")
			_box(Vector3(0, 0.98, 0.05), Vector3(2.0, 0.06, 0.1), frame, self)
			_box(Vector3(0, 2.47, 0.04), Vector3(2.0, 0.06, 0.08), frame, self)
			for sx in [-1, 1]:
				_box(Vector3(sx * 0.97, 1.725, 0.04), Vector3(0.06, 1.55, 0.08), frame, self)
			_hinge_l = Node3D.new()
			_hinge_l.position = Vector3(-0.94, 1.725, 0.03)
			_add(_hinge_l, self)
			_box(Vector3(0.465, 0, 0), Vector3(0.93, 1.44, 0.02), pane, _hinge_l)
			_box(Vector3(0.465, 0, 0.011), Vector3(0.93, 0.04, 0.02), frame, _hinge_l)
			_hinge_r = Node3D.new()
			_hinge_r.position = Vector3(0.94, 1.725, 0.03)
			_add(_hinge_r, self)
			_box(Vector3(-0.465, 0, 0), Vector3(0.93, 1.44, 0.02), pane, _hinge_r)
			_box(Vector3(-0.465, 0, 0.011), Vector3(0.93, 0.04, 0.02), frame, _hinge_r)
			_rope_out = _cyl(Vector3(0, 1.0 - drop_height * 0.5, -0.32), 0.02, drop_height, orange, self, false)
			bs.size = Vector3(2.0, 1.55, 0.1)
			cs.position = Vector3(0, 1.725, 0.05)
	cs.shape = bs
	_add(cs, self)
	if not Engine.is_editor_hint():
		_refresh_instant()


func _refresh_instant() -> void:
	if _door:
		_door.rotation.y = deg_to_rad(-105.0) if stage >= 1 else 0.0
	if _reel:
		_reel.visible = stage < 2
	if _rope_in:
		_rope_in.visible = stage >= 3
	if _hooked_reel:
		_hooked_reel.visible = stage >= 3
	if _hinge_l:
		_hinge_l.rotation.y = deg_to_rad(-95.0) if window_open else 0.0
		_hinge_r.rotation.y = deg_to_rad(95.0) if window_open else 0.0
	if _rope_out:
		_rope_out.visible = stage >= 4


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_add(mi, parent)


## 원기둥. along_z 가 true 면 축을 Z 방향으로 눕힌다 (릴).
func _cyl(pos: Vector3, radius: float, height: float, mat: Material, parent: Node, along_z: bool) -> Node3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	if along_z:
		mi.rotation.x = deg_to_rad(90.0)
	_add(mi, parent)
	return mi


func _label(text: String, pos: Vector3, size: int, color: Color, parent: Node) -> void:
	var l := Label3D.new()
	l.text = text
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"])
	l.font = font
	l.font_size = size
	l.pixel_size = 0.003
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.position = pos
	_add(l, parent)


func _add(n: Node, parent: Node) -> void:
	n.set_meta("_gen", true)
	parent.add_child(n)
