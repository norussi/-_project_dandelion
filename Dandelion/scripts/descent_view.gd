extends Node3D
## 완강기 하강을 건물 밖에서 3인칭으로 보여 주는 연출.
## main.gd의 _start_descent()가 플레이어(보이지 않는 1인칭 몸)를 트윈으로 움직이면,
## 여기서 그 위치에 사람 모형을 두고 로프와 함께 그리며, 바깥 카메라가 따라간다.
##   창틀로 다가가 몸을 내밂 → 벽을 바라보고 몸을 뒤로 기댄 채 발로 벽을 밀며 하강 → 착지
## 사람 모형은 외부 에셋 없이 기본 도형으로 만든다 (교복 + 완강기 가슴 벨트).

const SKIN := Color(0.93, 0.76, 0.62)
const SHIRT := Color(0.92, 0.93, 0.95)
const PANTS := Color(0.12, 0.15, 0.28)
const HAIR := Color(0.06, 0.05, 0.05)
const SHOE := Color(0.08, 0.08, 0.09)
const BELT := Color(0.85, 0.12, 0.08)
const ROPE := Color(0.82, 0.74, 0.55)

## 바깥 카메라 위치 (창문 기준). 창문 오른쪽 앞, 나무 위에서 비스듬히 본다.
const CAM_OFFSET := Vector3(5.0, 1.2, 8.5)

var player: Node3D
var window_pos := Vector3.ZERO   # 창문 안쪽 벽면, 바닥 높이
var anchor := Vector3.ZERO       # 로프가 창틀 위로 넘어가는 곳
var avatar: Node3D
var hips := []                   # [왼쪽, 오른쪽] 엉덩이 관절
var knees := []
var shoulders := []
var rope: MeshInstance3D
var cam: Camera3D
var t := 0.0
var landed := false
var _yaw := 0.0
var _lean := 0.0


## 하강을 시작한다. p = 1인칭 플레이어, win = 창문 노드
func begin(p: Node3D, win: Node3D) -> void:
	player = p
	window_pos = win.global_position
	anchor = window_pos + Vector3(0, 1.0, 0.45)
	_build_avatar()
	_build_rope()
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.05
	cam.far = 120.0
	add_child(cam)
	_yaw = player.rotation.y
	_update_avatar(0.0)
	cam.global_position = _cam_target()
	cam.look_at(_chest())
	cam.current = true


## 땅에 닿았을 때: 똑바로 서서 벨트를 푸는 자세
func land() -> void:
	landed = true


func _process(delta: float) -> void:
	if player == null:
		return
	t += delta
	_update_avatar(delta)
	_update_rope()
	cam.global_position = cam.global_position.lerp(_cam_target(), clampf(delta * 2.5, 0.0, 1.0))
	cam.look_at(_chest())


func _update_avatar(delta: float) -> void:
	avatar.global_position = player.global_position
	# 창밖으로 몸이 나가 내려가기 시작하면 벽(건물 쪽, -Z)을 바라본다
	var hanging := not landed and player.global_position.z > window_pos.z + 0.5
	var want_yaw: float = 0.0 if (hanging or landed) else player.rotation.y
	var k := clampf(delta * 3.0, 0.0, 1.0) if delta > 0.0 else 1.0
	_yaw = lerp_angle(_yaw, want_yaw, k)
	_lean = lerpf(_lean, 0.32 if hanging else 0.0, k)   # 로프에 몸을 맡기고 뒤로 기댄다
	avatar.rotation = Vector3(_lean, _yaw, 0.0)
	var walk := t * 3.2
	for i in 2:
		var ph := walk + PI * i   # 두 다리가 번갈아 벽을 민다
		if hanging:
			hips[i].rotation.x = 0.95 + sin(ph) * 0.3
			knees[i].rotation.x = -0.75 + sin(ph + 1.2) * 0.3
			shoulders[i].rotation.x = 0.9 + sin(ph * 0.5) * 0.08   # 손은 로프 대신 벽 쪽으로
			shoulders[i].rotation.z = (0.25 if i == 0 else -0.25)
		elif landed:
			hips[i].rotation.x = lerpf(hips[i].rotation.x, 0.0, k)
			knees[i].rotation.x = lerpf(knees[i].rotation.x, 0.0, k)
			shoulders[i].rotation.x = lerpf(shoulders[i].rotation.x, 0.5, k)   # 가슴 벨트를 푼다
			shoulders[i].rotation.z = lerpf(shoulders[i].rotation.z, 0.5 if i == 0 else -0.5, k)
		else:
			# 창틀에 걸터앉아 몸을 내미는 동안
			hips[i].rotation.x = lerpf(hips[i].rotation.x, 1.3, k)
			knees[i].rotation.x = lerpf(knees[i].rotation.x, -1.3, k)
			shoulders[i].rotation.x = lerpf(shoulders[i].rotation.x, 0.4, k)


func _update_rope() -> void:
	var a := anchor
	var b := _chest() + avatar.global_basis.z * -0.12   # 가슴 벨트 앞쪽 고리
	var d := b - a
	var len := d.length()
	if len < 0.01:
		rope.visible = false
		return
	rope.visible = true
	var y := d / len
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	rope.global_transform = Transform3D(Basis(x, y * len, z), (a + b) * 0.5)


func _chest() -> Vector3:
	return avatar.to_global(Vector3(0, 1.3, 0))


func _cam_target() -> Vector3:
	var c := _chest()
	return Vector3(window_pos.x + CAM_OFFSET.x, maxf(c.y + CAM_OFFSET.y, -0.3), window_pos.z + CAM_OFFSET.z)


# ---------------------------------------------------------------- 모형 만들기

func _build_avatar() -> void:
	avatar = Node3D.new()
	add_child(avatar)
	# 몸통과 골반
	_capsule(avatar, Vector3(0, 1.22, 0), 0.17, 0.62, SHIRT)
	_box(avatar, Vector3(0, 0.93, 0), Vector3(0.32, 0.18, 0.2), PANTS)
	# 완강기 가슴 벨트와 어깨끈
	_box(avatar, Vector3(0, 1.3, 0), Vector3(0.38, 0.07, 0.27), BELT)
	for sx in [-1, 1]:
		_box(avatar, Vector3(sx * 0.1, 1.42, 0), Vector3(0.05, 0.22, 0.25), BELT)
	# 머리
	_sphere(avatar, Vector3(0, 1.58, 0), 0.11, SKIN)
	_sphere(avatar, Vector3(0, 1.62, 0.025), 0.115, HAIR)   # 뒤통수와 정수리를 덮는 머리카락
	_box(avatar, Vector3(0, 1.58, -0.105), Vector3(0.12, 0.08, 0.02), SKIN)   # 얼굴 앞면
	# 팔
	for sx in [-1, 1]:
		var sh := _pivot(avatar, Vector3(sx * 0.22, 1.45, 0))
		_capsule(sh, Vector3(0, -0.16, 0), 0.05, 0.34, SHIRT)
		_capsule(sh, Vector3(0, -0.44, 0), 0.042, 0.3, SKIN)
		shoulders.append(sh)
	# 다리
	for sx in [-1, 1]:
		var hip := _pivot(avatar, Vector3(sx * 0.09, 0.88, 0))
		_capsule(hip, Vector3(0, -0.22, 0), 0.07, 0.46, PANTS)
		var knee := _pivot(hip, Vector3(0, -0.44, 0))
		_capsule(knee, Vector3(0, -0.21, 0), 0.06, 0.44, PANTS)
		_box(knee, Vector3(0, -0.44, -0.04), Vector3(0.1, 0.07, 0.24), SHOE)
		hips.append(hip)
		knees.append(knee)


func _build_rope() -> void:
	rope = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 1.0
	cm.radial_segments = 6
	rope.mesh = cm
	rope.material_override = _mat(ROPE)
	add_child(rope)


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _capsule(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	_mesh(parent, cm, pos, color)


func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	_mesh(parent, sm, pos, color)


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_mesh(parent, bm, pos, color)


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m
