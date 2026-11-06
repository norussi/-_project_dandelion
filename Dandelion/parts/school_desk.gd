@tool
class_name SchoolDesk
extends StaticBody3D
## 학생 책상 + 의자. 기준점 = 책상 바닥 가운데.
## 학생은 +X 쪽 의자에 앉아 -X 쪽(칠판)을 본다. Y 회전으로 방향을 바꿀 수 있다.

@export var with_chair := true:
	set(v):
		with_chair = v
		_rebuild()
## 의자가 넘어져 있음
@export var chair_fallen := false:
	set(v):
		chair_fallen = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	var wood := preload("res://materials/wood.tres")
	var metal := preload("res://materials/metal.tres")
	# 책상: 상판 + 다리 4개 + 서랍칸
	_box(Vector3(0, 0.72, 0), Vector3(0.5, 0.04, 0.65), wood, self)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(Vector3(sx * 0.21, 0.35, sz * 0.29), Vector3(0.035, 0.7, 0.035), metal, self)
	_box(Vector3(-0.05, 0.6, 0), Vector3(0.35, 0.02, 0.6), metal, self)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.5, 0.75, 0.65)
	cs.shape = bs
	cs.position.y = 0.375
	_add(cs, self)
	# 의자 (충돌 없음 — 지나다닐 수 있게)
	if with_chair:
		var chair := Node3D.new()
		chair.position = Vector3(0.48, 0, 0)
		if chair_fallen:
			chair.position = Vector3(0.75, 0.2, 0.1)
			chair.rotation = Vector3(0, 0.4, deg_to_rad(-80))
		_add(chair, self)
		_box(Vector3(0, 0.44, 0), Vector3(0.38, 0.03, 0.38), wood, chair)
		_box(Vector3(0.18, 0.7, 0), Vector3(0.03, 0.3, 0.36), wood, chair)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				_box(Vector3(sx * 0.16, 0.22, sz * 0.16), Vector3(0.03, 0.44, 0.03), metal, chair)
		_box(Vector3(0.17, 0.6, 0), Vector3(0.03, 0.3, 0.03), metal, chair)


func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	_add(mi, parent)


func _add(n: Node, parent: Node) -> void:
	n.set_meta("_gen", true)
	parent.add_child(n)
