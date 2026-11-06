@tool
class_name SmokeZone
extends Node3D
## 연기 농도 구역. 플레이어가 이 상자 안에 있으면 그 농도로 시야가 가려지고 호흡이 줄어든다.
## 여러 구역이 겹치면 더 작은(구체적인) 구역이 우선한다.
## 에디터에서는 반투명 상자로 보이고, 게임 중에는 보이지 않는다.

## 상자 크기 (m)
@export var size := Vector3(10, 3, 10):
	set(v):
		size = v
		_rebuild()
## 연기 농도 (0 = 맑음, 0.4 = 짙음, 0.7 = 매우 짙음)
@export_range(0.0, 1.5, 0.01) var density := 0.4:
	set(v):
		density = v
		_rebuild()
## 연기 색 (불 근처는 주황빛)
@export var smoke_color := Color(0.13, 0.12, 0.11)


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("smoke_zones")


func contains(p: Vector3) -> bool:
	var local := global_transform.affine_inverse() * p
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5 and absf(local.z) <= size.z * 0.5


func volume() -> float:
	return size.x * size.y * size.z


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	if not Engine.is_editor_hint():
		return
	# 에디터 표시용 반투명 상자
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.3, 0.3, 0.3, clampf(density * 0.25, 0.03, 0.3))
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.mesh.material = m
	mi.set_meta("_gen", true)
	add_child(mi)
