@tool
class_name SmokeLayer
extends Node3D
## 천장 아래에 천천히 떠다니는 연기 덩어리 (움직임을 주는 장식).
## 기준점 = 상자 가운데. size 상자 안에서 연기가 생겨난다.

@export var size := Vector3(9, 1.2, 8):
	set(v):
		size = v
		_rebuild()
@export_range(4, 120, 1) var amount := 30:
	set(v):
		amount = v
		_rebuild()
@export var color := Color(0.16, 0.15, 0.14, 0.45):
	set(v):
		color = v
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
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = size * 0.5
	p.direction = Vector3(1, 0, 0.3)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.gravity = Vector3.ZERO
	p.angular_velocity_min = -8.0
	p.angular_velocity_max = 8.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color(color, 0.0))
	g.set_color(1, Color(color, 0.0))
	g.add_point(0.25, color)
	g.add_point(0.75, color)
	p.color_ramp = g
	p.mesh = FireSource._puff_mesh()
	p.set_meta("_gen", true)
	add_child(p)
