@tool
class_name FireSource
extends Node3D
## 불. 일렁이는 불꽃 + 연기 속에 번지는 주황빛 + 깜빡이는 조명 + 타는 소리.
## 기준점 = 불의 바닥 가운데. 가까이 가면 열기로 호흡이 빠르게 줄어든다.

## 불 크기 (1 = 약 1.5m 높이)
@export_range(0.3, 3.0, 0.05) var fire_size := 1.0:
	set(v):
		fire_size = v
		_rebuild()
## 이 거리 안에 들어가면 뜨거워서 피해를 입음 (m)
@export_range(0.5, 10.0, 0.1) var heat_radius := 3.5

const GLOW_SHADER := preload("res://shaders/glow_sprite.gdshader")

var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		add_to_group("fires")
		var sfx := get_node_or_null("/root/Sfx")
		if sfx == null:
			return
		var snd := AudioStreamPlayer3D.new()
		snd.stream = sfx.get_stream("crackle")
		snd.unit_size = 4.0 * fire_size
		snd.volume_db = -2.0
		snd.autoplay = true
		add_child(snd)


func _process(delta: float) -> void:
	if _light == null:
		return
	_t += delta
	var n := 0.7 + 0.2 * sin(_t * 11.0) + 0.15 * sin(_t * 23.7 + 1.3) + 0.1 * sin(_t * 5.3)
	_light.light_energy = 3.0 * fire_size * n


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("_gen"):
			remove_child(c)
			c.free()
	var s := fire_size
	# 불꽃 파티클
	var flames := CPUParticles3D.new()
	flames.amount = 70
	flames.lifetime = 0.85
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 0.55 * s
	flames.direction = Vector3.UP
	flames.spread = 18.0
	flames.initial_velocity_min = 0.8 * s
	flames.initial_velocity_max = 1.8 * s
	flames.gravity = Vector3(0, 1.4 * s, 0)
	flames.scale_amount_min = 0.7 * s
	flames.scale_amount_max = 1.2 * s
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.2))
	flames.scale_amount_curve = sc
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.65, 1.0))
	g.set_color(1, Color(0.3, 0.05, 0.0, 0.0))
	g.add_point(0.35, Color(1.0, 0.55, 0.12, 0.9))
	g.add_point(0.7, Color(0.85, 0.18, 0.03, 0.5))
	flames.color_ramp = g
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var fm := ShaderMaterial.new()
	fm.shader = GLOW_SHADER
	fm.set_shader_parameter("glow_color", Color.WHITE)
	fm.set_shader_parameter("intensity", 1.8)
	fm.set_shader_parameter("see_falloff", 0.055)
	fm.set_shader_parameter("softness", 2.2)
	fm.set_shader_parameter("use_vertex_color", true)
	qm.material = fm
	flames.mesh = qm
	flames.position.y = 0.3 * s
	_add(flames)
	# 연기 속에 번지는 큰 주황빛
	var haze := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(7, 7) * s
	haze.mesh = hq
	var hm := ShaderMaterial.new()
	hm.shader = GLOW_SHADER
	hm.set_shader_parameter("glow_color", Color(1.0, 0.42, 0.1))
	hm.set_shader_parameter("intensity", 0.45)
	hm.set_shader_parameter("see_falloff", 0.045)
	hm.set_shader_parameter("softness", 2.5)
	haze.material_override = hm
	haze.position.y = 1.2 * s
	haze.extra_cull_margin = 8.0
	_add(haze)
	# 검은 연기 기둥
	var smoke := CPUParticles3D.new()
	smoke.amount = 24
	smoke.lifetime = 4.0
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.5 * s
	smoke.direction = Vector3.UP
	smoke.spread = 25.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.1
	smoke.gravity = Vector3(0, 0.2, 0)
	smoke.scale_amount_min = 1.5 * s
	smoke.scale_amount_max = 2.8 * s
	var sg := Gradient.new()
	sg.set_color(0, Color(0.06, 0.05, 0.05, 0.0))
	sg.set_color(1, Color(0.08, 0.08, 0.08, 0.0))
	sg.add_point(0.2, Color(0.06, 0.05, 0.05, 0.6))
	smoke.color_ramp = sg
	smoke.mesh = _puff_mesh()
	smoke.position.y = 1.4 * s
	_add(smoke)
	# 깜빡이는 불빛
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.18)
	_light.light_energy = 3.0 * s
	_light.omni_range = 10.0 * s
	_light.position.y = 1.0 * s
	_add(_light)


static func _puff_mesh() -> QuadMesh:
	var qm := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gg := Gradient.new()
	gg.set_color(0, Color(1, 1, 1, 1))
	gg.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = gg
	m.albedo_texture = gt
	qm.material = m
	return qm


func _add(n: Node) -> void:
	n.set_meta("_gen", true)
	add_child(n)
