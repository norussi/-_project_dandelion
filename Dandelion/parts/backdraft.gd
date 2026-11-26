extends Node3D
## 백드래프트 연출: 산소가 모자라 불씨만 남아 있던 닫힌 방의 문을 열면, 들어간 공기와 만나
## 불길이 폭발하듯 문밖으로 쏟아져 나와 천장을 타고 복도로 번진다.
## 문 노드와 같은 위치·방향에 두고 쓴다 (+Z = 문밖 복도 쪽). 몇 초 뒤 스스로 사라진다.

const GLOW_SHADER := preload("res://shaders/glow_sprite.gdshader")
const LIFE := 4.0

var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	# 1) 문틈에서 쏟아져 나오는 불덩이
	var burst := _flames(260, 1.0, Vector3(0.45, 1.0, 0.1), 5.0, 9.0, 30.0)
	burst.position = Vector3(0, 1.1, 0.15)
	add_child(burst)
	# 2) 천장을 타고 복도로 굴러가는 불길
	var roll := _flames(160, 1.5, Vector3(0.5, 0.2, 0.1), 3.0, 6.0, 20.0)
	roll.direction = Vector3(0, 0.45, 1)
	roll.position = Vector3(0, 2.1, 0.2)
	roll.gravity = Vector3(0, 2.5, 0)
	add_child(roll)
	# 3) 뒤따르는 검은 연기
	var smoke := CPUParticles3D.new()
	smoke.one_shot = true
	smoke.explosiveness = 0.5
	smoke.amount = 60
	smoke.lifetime = 3.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(0.5, 1.0, 0.2)
	smoke.direction = Vector3(0, 0.3, 1)
	smoke.spread = 35.0
	smoke.initial_velocity_min = 1.5
	smoke.initial_velocity_max = 3.5
	smoke.damping_min = 1.0
	smoke.damping_max = 2.0
	smoke.gravity = Vector3(0, 0.8, 0)
	smoke.scale_amount_min = 1.5
	smoke.scale_amount_max = 3.0
	var sg := Gradient.new()
	sg.set_color(0, Color(0.05, 0.04, 0.04, 0.0))
	sg.set_color(1, Color(0.07, 0.07, 0.07, 0.0))
	sg.add_point(0.25, Color(0.05, 0.04, 0.04, 0.75))
	smoke.color_ramp = sg
	smoke.mesh = FireSource._puff_mesh()
	smoke.position = Vector3(0, 1.2, 0.3)
	add_child(smoke)
	for p in [burst, roll, smoke]:
		p.emitting = true
	# 4) 번쩍이는 불빛
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.2)
	_light.light_energy = 16.0
	_light.omni_range = 11.0
	_light.position = Vector3(0, 1.5, 1.2)
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	_light.light_energy = 16.0 * exp(-_t * 1.6) * (0.85 + 0.15 * sin(_t * 37.0))
	if _t > LIFE:
		queue_free()


func _flames(amount: int, life: float, box: Vector3, v_min: float, v_max: float, spread: float) -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.one_shot = true
	f.explosiveness = 0.75
	f.amount = amount
	f.lifetime = life
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = box
	f.direction = Vector3(0, 0.15, 1)
	f.spread = spread
	f.initial_velocity_min = v_min
	f.initial_velocity_max = v_max
	f.damping_min = 3.0
	f.damping_max = 5.0
	f.gravity = Vector3(0, 3.0, 0)
	f.scale_amount_min = 1.0
	f.scale_amount_max = 2.2
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.5))
	sc.add_point(Vector2(0.35, 1.0))
	sc.add_point(Vector2(1, 0.3))
	f.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.97, 0.75, 1.0))
	g.set_color(1, Color(0.25, 0.04, 0.0, 0.0))
	g.add_point(0.3, Color(1.0, 0.6, 0.15, 0.95))
	g.add_point(0.65, Color(0.9, 0.22, 0.04, 0.6))
	f.color_ramp = g
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = GLOW_SHADER
	m.set_shader_parameter("glow_color", Color.WHITE)
	m.set_shader_parameter("intensity", 2.0)
	m.set_shader_parameter("see_falloff", 0.04)
	m.set_shader_parameter("softness", 2.0)
	m.set_shader_parameter("use_vertex_color", true)
	qm.material = m
	f.mesh = qm
	return f
