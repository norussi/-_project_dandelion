extends Node3D
## 완강기 하강을 건물 밖에서 3인칭으로 보여 주는 연출.
## main.gd의 _start_descent()가 플레이어(보이지 않는 1인칭 몸)를 트윈으로 움직이는 동안,
## 여기서 사람 모형과 로프를 그리고 바깥 카메라가 따라간다.
##   창가로 걸어옴 → 창틀에 걸터앉음 → 벽 쪽으로 돌아 매달림 → 두 발로 벽을 디디며 하강 → 착지
##
## 사람 모형은 외부 에셋 없이 만든다. 팔다리는 관절(구)과 끝이 가늘어지는 원통으로 잇고,
## 손발 위치를 먼저 정한 뒤 무릎·팔꿈치를 계산해서(2관절 IK) 발이 벽에 붙어 있게 한다.
## 모든 좌표는 이 노드 기준이다: 원점 = 창문 아래 실내 바닥, +Z = 건물 밖, +Y = 위.

## main.gd의 트윈과 맞추는 시간 (초)
const APPROACH_TIME := 1.2     # 창가로 걸어오는 시간
const EXIT_TIME := 3.2         # 창틀에 올라앉아 밖으로 나가 매달리기까지

const SKIN := Color(0.93, 0.76, 0.63)
const SHIRT := Color(0.93, 0.94, 0.96)
const PANTS := Color(0.13, 0.16, 0.29)
const HAIR := Color(0.07, 0.06, 0.06)
const SHOE := Color(0.1, 0.1, 0.11)
const BELT := Color(0.82, 0.12, 0.08)
const ROPE := Color(0.95, 0.45, 0.08)    # 창밖에 내려 둔 로프(parts/descender.gd)와 같은 색
const METAL := Color(0.72, 0.74, 0.78)

const SILL_Y := 1.01           # 창틀 윗면 높이
const THIGH := 0.42
const SHIN := 0.40
const ANKLE := 0.075           # 발바닥에서 발목까지
const UPPER_ARM := 0.27
const FOREARM := 0.25
const STAND_Y := 0.90          # 서 있을 때 골반 높이
const HANG_Y := 0.10           # 매달리기 시작할 때 골반 높이 (창틀 바로 아래)
const HANG_D := 0.42           # 내려가는 동안 골반과 벽 사이 거리
const FOOT_DROP := 0.45        # 벽을 디딘 발이 골반보다 낮은 정도
const FOOT_OFFSET := [0.11, -0.11]   # 두 발이 벽을 번갈아 디디도록 엇갈린 높이

var player: Node3D
var wall_out := 0.2            # 바깥 벽면의 Z
var ground_y := -12.65         # 지면의 Y

var t := 0.0
var landed := false
var land_t := 0.0
var exit_start := Vector3(0, STAND_Y, -0.35)
var yaw_start := PI
var walk_phase := 0.0
var last_xz := Vector2.ZERO
var hanging_started := false
var plant_y := [0.0, 0.0]      # 벽을 디딘 발의 높이
var swing := [-1.0, -1.0]      # 발을 옮기는 중이면 0~1, 디디고 있으면 -1
var swing_from := [0.0, 0.0]
var swing_to := [0.0, 0.0]
var push := 0.0                # 발로 벽을 밀 때 몸이 살짝 뒤로 밀리는 정도
var last_pel_y := 0.0

# 자세 (매 프레임 계산)
var pel := Vector3.ZERO        # 골반 위치
var yaw := PI                  # 0 = 벽을 봄, PI = 창밖을 봄
var lean := 0.0                # 몸통을 뒤로 젖힌 각도
var roll := 0.0
var head_pitch := 0.0          # +면 아래를 봄
var foot_pos := [Vector3.ZERO, Vector3.ZERO]      # 발바닥이 닿는 곳
var foot_nrm := [Vector3.UP, Vector3.UP]          # 발바닥이 닿는 면의 방향
var foot_toe := [Vector3.FORWARD, Vector3.FORWARD]
var hand_pos := [Vector3.ZERO, Vector3.ZERO]

var cam: Camera3D
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var mats := {}
var n := {}                    # 이름 → MeshInstance3D


## 하강을 시작한다. p = 1인칭 플레이어, win = 창문 노드 (Descender, 바깥이 -Z)
func begin(p: Node3D, win: Node3D) -> void:
	player = p
	var out := -win.global_basis.z
	out.y = 0.0
	out = out.normalized()
	global_transform = Transform3D(Basis(Vector3.UP.cross(out), Vector3.UP, out), win.global_position)
	_measure()
	_build()
	var pl := to_local(player.global_position)
	last_xz = Vector2(pl.x, pl.z)
	var f := global_basis.inverse() * (-player.global_basis.z)
	yaw_start = atan2(-f.x, -f.z)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	cam.far = 150.0
	add_child(cam)
	_pose(0.0)
	_apply()
	cam_pos = _cam_goal()
	cam_look = _look_goal()
	cam.look_at_from_position(to_global(cam_pos), to_global(cam_look), Vector3.UP)
	cam.current = true


## 땅에 닿았을 때: 무릎으로 충격을 받고 일어서서 가슴 벨트를 푼다
func land() -> void:
	landed = true
	land_t = 0.0


func _process(delta: float) -> void:
	if player == null:
		return
	t += delta
	if landed:
		land_t += delta
	_pose(delta)
	_apply()
	cam_pos = cam_pos.lerp(_cam_goal(), 1.0 - exp(-delta * 2.0))
	cam_look = cam_look.lerp(_look_goal(), 1.0 - exp(-delta * 4.0))
	cam.look_at_from_position(to_global(cam_pos), to_global(cam_look), Vector3.UP)


# 바깥 벽면과 지면의 위치를 실제 맵에서 잰다 (못 재면 기본값)
func _measure() -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(to_global(Vector3(0.6, 0.5, 4.0)), to_global(Vector3(0.6, 0.5, -1.0)))
	var r := space.intersect_ray(q)
	if not r.is_empty():
		wall_out = to_local(r["position"]).z
	q = PhysicsRayQueryParameters3D.create(to_global(Vector3(0, 0.5, wall_out + 0.6)), to_global(Vector3(0, -40.0, wall_out + 0.6)))
	r = space.intersect_ray(q)
	if not r.is_empty():
		ground_y = to_local(r["position"]).y


# ================================================================ 자세 계산

func _pose(delta: float) -> void:
	var pl := to_local(player.global_position)
	if t < APPROACH_TIME:
		_pose_approach(pl, delta)
	elif t < APPROACH_TIME + EXIT_TIME:
		_pose_exit((t - APPROACH_TIME) / EXIT_TIME)
	else:
		_pose_hang(pl, delta)


# 창가로 걸어온다 (창틀 아래는 벽에 가려 상체만 보인다)
func _pose_approach(pl: Vector3, delta: float) -> void:
	var k := smoothstep(0.0, APPROACH_TIME, t)
	pel = Vector3(pl.x, STAND_Y, minf(pl.z, -0.3))
	exit_start = pel
	yaw = lerp_angle(yaw_start, PI, k)
	lean = 0.0
	roll = 0.0
	head_pitch = 0.05
	var xz := Vector2(pl.x, pl.z)
	var moved := xz.distance_to(last_xz)
	last_xz = xz
	walk_phase += moved / 0.32 * PI
	var moving := clampf(moved / maxf(delta, 0.001) / 0.6, 0.0, 1.0)
	pel.y += absf(sin(walk_phase)) * 0.025 * moving
	var b := Basis(Vector3.UP, yaw)
	for i in 2:
		var sgn := -1.0 if i == 0 else 1.0
		var ph := walk_phase + PI * i
		var step := sin(ph) * 0.16 * moving
		var lift := maxf(cos(ph), 0.0) * 0.07 * moving
		foot_pos[i] = pel + b * Vector3(sgn * 0.09, 0, -step)
		foot_pos[i].y = lift
		foot_nrm[i] = Vector3.UP
		foot_toe[i] = b * Vector3.FORWARD
		var sh := _shoulder(i)
		hand_pos[i] = sh + b * Vector3(sgn * 0.06, -0.48, -0.04 + sin(ph) * 0.1 * moving)


# 창틀에 걸터앉고 → 벽 쪽으로 돌아 → 로프에 몸을 싣고 매달린다
func _pose_exit(u: float) -> void:
	var a := smoothstep(0.0, 0.32, u)      # 창틀에 올라앉기
	var bt := smoothstep(0.30, 0.62, u)    # 벽 쪽으로 돌기
	var c := smoothstep(0.60, 1.0, u)      # 매달리며 내려앉기
	var k1 := Vector3(0, SILL_Y + 0.10, 0.10)
	var k2 := Vector3(0, SILL_Y + 0.02, wall_out + 0.30)
	var k3 := Vector3(0, HANG_Y, wall_out + HANG_D)
	pel = exit_start.lerp(k1, a)
	pel.y += sin(a * PI) * 0.12
	pel = pel.lerp(k2, bt).lerp(k3, c)
	yaw = lerpf(PI, 0.0, bt)
	lean = lerpf(lerpf(0.0, -0.12, sin(a * PI)), 0.18, c)
	roll = 0.0
	head_pitch = lerpf(0.1, 0.4, c) + sin(bt * PI) * 0.15
	var b := Basis(Vector3.UP, yaw)
	var b_out := Basis(Vector3.UP, PI)
	var wall_w := smoothstep(0.74, 0.96, u)
	for i in 2:
		var sgn := -1.0 if i == 0 else 1.0
		# 서 있던 자리 → 창틀을 넘어 → 창밖으로 늘어뜨린 발
		var stand: Vector3 = exit_start + b_out * Vector3(sgn * 0.09, 0, 0)
		stand.y = 0.0
		var dangle: Vector3 = k1 + b_out * Vector3(sgn * 0.10, -0.46, -0.40)
		var over := Vector3(stand.x, SILL_Y + 0.32, 0.0)
		var ai := smoothstep(0.02 + 0.10 * i, 0.20 + 0.10 * i, u)
		var fp := stand.lerp(over, ai).lerp(over.lerp(dangle, ai), ai)
		# 돌면서 다리를 아래로 늘어뜨린다
		var hang_local: Vector3 = pel + b * Vector3(sgn * 0.09, -0.80, -0.10)
		fp = fp.lerp(hang_local, bt)
		# 벽을 디딘다
		var wall_p := Vector3(sgn * 0.11, pel.y - FOOT_DROP + FOOT_OFFSET[i], wall_out)
		foot_pos[i] = fp.lerp(wall_p, wall_w)
		foot_nrm[i] = Vector3.UP.lerp(Vector3.BACK, wall_w).normalized()
		foot_toe[i] = (b * Vector3.FORWARD).lerp(Vector3.UP, wall_w).normalized()
		# 손: 옆구리 → 창틀을 짚음 → 벽을 짚음
		var sh := _shoulder(i)
		var rest: Vector3 = sh + b * Vector3(sgn * 0.06, -0.48, -0.04)
		var sill := Vector3(clampf(sh.x * 1.35, -0.34, 0.34), SILL_Y + 0.02, lerpf(0.03, wall_out - 0.04, bt))
		var hp := rest.lerp(sill, smoothstep(0.0, 0.10, u))
		hand_pos[i] = hp.lerp(_wall_hand(sh, i), smoothstep(0.80, 0.97, u))


# 벽을 디디며 일정한 속도로 내려와 착지한다
func _pose_hang(pl: Vector3, delta: float) -> void:
	var prog := clampf(inverse_lerp(0.0, ground_y + 0.05, pl.y), 0.0, 1.0)
	var stand := ground_y + STAND_Y
	var y := lerpf(HANG_Y, stand, prog)
	if not hanging_started:
		hanging_started = true
		last_pel_y = y
		for i in 2:
			plant_y[i] = y - FOOT_DROP + FOOT_OFFSET[i]
	var speed := (last_pel_y - y) / maxf(delta, 0.0001) if delta > 0.0 else 0.0
	last_pel_y = y
	# 땅이 가까워지면 벽에서 발을 떼고 아래로 뻗는다
	var gw := smoothstep(1.9, 1.15, y - ground_y)
	var dip := 0.0
	if landed:
		dip = sin(clampf(land_t / 0.6, 0.0, 1.0) * PI) * 0.16      # 무릎으로 충격을 받는다
	push = maxf(push - delta * 0.12, 0.0)
	pel = Vector3(sin(t * 1.3) * 0.02 * (1.0 - gw), y - dip, wall_out + lerpf(HANG_D, 0.40, gw) + push * (1.0 - gw))
	yaw = sin(t * 0.9) * 0.04 * (1.0 - gw)
	lean = lerpf(0.18, 0.0, gw) + dip * 0.6
	roll = sin(t * 1.7) * 0.025 * (1.0 - gw)
	head_pitch = lerpf(0.4, 0.15, gw)
	if landed:
		head_pitch = lerpf(0.15, -0.3, smoothstep(0.8, 1.5, land_t))     # 내려온 건물을 올려다본다
	var b := Basis(Vector3.UP, yaw)
	var ideal := y - FOOT_DROP
	for i in 2:
		var sgn := -1.0 if i == 0 else 1.0
		var o := 1 - i
		var off := 0.0      # 발을 옮길 때 벽에서 떨어지는 정도
		if gw < 0.5:
			if swing[i] < 0.0 and swing[o] < 0.0 and plant_y[i] - ideal > 0.20:
				swing[i] = 0.0
				swing_from[i] = plant_y[i]
				swing_to[i] = ideal - 0.22 - speed * 0.26
			if swing[i] >= 0.0:
				swing[i] += delta / 0.26
				var s := smoothstep(0.0, 1.0, minf(swing[i], 1.0))
				plant_y[i] = lerpf(swing_from[i], swing_to[i], s)
				off = sin(minf(swing[i], 1.0) * PI) * 0.11
				if swing[i] >= 1.0:
					swing[i] = -1.0
					push = 0.03       # 디디면서 벽을 민다
		var wall_p := Vector3(sgn * 0.11, plant_y[i], wall_out + off)
		var ground_p := Vector3(sgn * 0.10, ground_y, wall_out + 0.36)
		foot_pos[i] = wall_p.lerp(ground_p, gw)
		foot_nrm[i] = Vector3.BACK.lerp(Vector3.UP, gw).normalized()
		foot_toe[i] = Vector3.UP.lerp(Vector3.FORWARD, gw).normalized()
		var sh := _shoulder(i)
		var rest: Vector3 = sh + b * Vector3(sgn * 0.07, -0.47, -0.05)
		hand_pos[i] = _wall_hand(sh, i).lerp(rest, gw)
		if landed:
			# 가슴 벨트의 조임쇠를 푼다
			var buckle: Vector3 = _ring() + b * Vector3(sgn * 0.06, -0.03, 0.0)
			hand_pos[i] = hand_pos[i].lerp(buckle, smoothstep(0.5, 1.0, land_t))


func _torso() -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean) * Basis(Vector3.BACK, roll)


func _shoulder(i: int) -> Vector3:
	return pel + _torso() * Vector3(-0.168 if i == 0 else 0.168, 0.425, 0)


# 가슴 벨트 앞의 고리 (로프가 걸리는 곳)
func _ring() -> Vector3:
	return pel + _torso() * Vector3(0, 0.35, -0.15)


# 벽을 짚는 손: 어깨보다 조금 바깥, 내려가며 번갈아 살짝 짚는다
func _wall_hand(sh: Vector3, i: int) -> Vector3:
	var side := -1.0 if i == 0 else 1.0
	return Vector3(sh.x + side * 0.09, sh.y - 0.03 + sin(t * 2.4 + PI * i) * 0.035, wall_out + 0.02)


func _cam_goal() -> Vector3:
	if landed:
		return Vector3(3.3, ground_y + 1.4, 5.8)
	if t < APPROACH_TIME + EXIT_TIME:
		return Vector3(2.8, 1.75, 5.3)
	return Vector3(3.7, maxf(pel.y + 1.2, ground_y + 1.4), 6.6)


func _look_goal() -> Vector3:
	if t < APPROACH_TIME + EXIT_TIME * 0.6:
		return Vector3(0, 1.2, 0.25)
	return Vector3(0, pel.y + 0.3, wall_out + 0.25)


# ================================================================ 모형에 자세 입히기

func _apply() -> void:
	var b := Basis(Vector3.UP, yaw)
	var tb := _torso()
	var hb := tb * Basis(Vector3.RIGHT, -head_pitch)
	n["pelvis"].transform = Transform3D(b * Basis.from_scale(Vector3(1.15, 0.75, 0.9)), pel)
	n["torso"].transform = Transform3D(tb * Basis.from_scale(Vector3(1.2, 1.0, 0.85)), pel + tb * Vector3(0, 0.27, 0))
	n["belt"].transform = Transform3D(tb * Basis.from_scale(Vector3(1.2, 1.0, 0.86)), pel + tb * Vector3(0, 0.35, 0))
	var neck := pel + tb * Vector3(0, 0.50, 0)
	var head := neck + hb * Vector3(0, 0.17, -0.01)
	_seg(n["neck"], neck, neck + hb * Vector3(0, 0.09, 0))
	n["head"].transform = Transform3D(hb * Basis.from_scale(Vector3(1.0, 1.08, 1.0)), head)
	n["hair"].transform = Transform3D(hb, head + hb * Vector3(0, 0.022, 0.024))
	for i in 2:
		n["eye%d" % i].position = head + hb * Vector3(-0.042 if i == 0 else 0.042, 0.0, -0.112)
	# 로프 고리
	var ring := _ring()
	n["ring"].transform = Transform3D(tb * Basis(Vector3.RIGHT, PI * 0.5), ring)
	for i in 2:
		var sgn := -1.0 if i == 0 else 1.0
		var side := b * Vector3(sgn, 0, 0)
		# 다리
		var hip := pel + b * Vector3(sgn * 0.085, -0.02, 0)
		var ankle: Vector3 = foot_pos[i] + foot_nrm[i] * ANKLE
		var leg := _ik(hip, ankle, THIGH, SHIN, b * Vector3(0, 1.0, -0.5) + side * 0.15)
		_seg(n["thigh%d" % i], hip, leg[0])
		_seg(n["shin%d" % i], leg[0], leg[1])
		n["hipj%d" % i].position = hip
		n["knee%d" % i].position = leg[0]
		# 발: 발목이 닿지 못하면(허공) 실제 발목 위치를 따른다
		var sole: Vector3 = leg[1] - foot_nrm[i] * ANKLE
		var toe: Vector3 = foot_toe[i]
		var up_f: Vector3 = foot_nrm[i]
		var right_f := toe.cross(up_f).normalized()
		toe = up_f.cross(right_f).normalized()
		n["shoe%d" % i].transform = Transform3D(Basis(right_f * 0.95, toe, up_f * 0.72), sole + up_f * 0.04 + toe * 0.055)
		# 팔
		var sh := _shoulder(i)
		var arm := _ik(sh, hand_pos[i], UPPER_ARM, FOREARM, Vector3(0, -1.0, 0) + side * 0.7 + b * Vector3(0, 0, 0.35))
		_seg(n["upper%d" % i], sh, arm[0])
		_seg(n["fore%d" % i], arm[0], arm[1])
		n["shj%d" % i].position = sh
		n["elbow%d" % i].position = arm[0]
		var fdir: Vector3 = (arm[1] - arm[0]).normalized()
		n["hand%d" % i].position = arm[1] + fdir * 0.03
	# 로프: 창틀 위를 지나 가슴 고리까지
	var sill_a := Vector3(0, SILL_Y + 0.015, -0.02)
	var sill_b := Vector3(0, SILL_Y + 0.015, wall_out + 0.02)
	_seg(n["rope_sill"], sill_a, sill_b)
	_seg(n["rope"], Vector3(0, SILL_Y + 0.015, clampf(ring.z, sill_a.z, sill_b.z)), ring)
	n["fill"].position = pel + Vector3(1.6, 1.0, 2.2)


# 2관절 IK: 뿌리 a에서 목표 c까지, 길이 l1·l2인 두 마디의 가운데 관절 위치를 구한다.
# pole = 관절이 꺾이는 쪽. 닿지 못하면 목표 쪽으로 쭉 편다. [관절, 끝] 을 돌려준다.
func _ik(a: Vector3, c: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var d := c - a
	var dist := clampf(d.length(), 0.02, l1 + l2 - 0.002)
	var dir := d.normalized() if d.length() > 0.0001 else Vector3.DOWN
	var end := a + dir * dist
	var along := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - along * along, 0.0))
	var p := pole - dir * pole.dot(dir)
	p = p.normalized() if p.length() > 0.0001 else Vector3.UP
	return [a + dir * along + p * h, end]


# 원통 마디를 a에서 b까지 놓는다 (메시 높이 1, -Y 끝이 a)
func _seg(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var y := b - a
	var length := y.length()
	if length < 0.001:
		mi.visible = false
		return
	mi.visible = true
	var yn := y / length
	var x := yn.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = yn.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(yn).normalized()
	mi.transform = Transform3D(Basis(x, yn * length, z), (a + b) * 0.5)


# ================================================================ 모형 만들기

func _build() -> void:
	# 몸통: 교복 셔츠, 골반: 바지
	_add("torso", _capsule(0.15, 0.56), SHIRT)
	_add("pelvis", _sphere(0.15), PANTS)
	_add("neck", _taper(0.047, 0.045), SKIN)
	_add("head", _sphere(0.12), SKIN)
	_add("hair", _sphere(0.128), HAIR)
	for i in 2:
		_add("eye%d" % i, _sphere(0.013), HAIR)
	# 완강기 가슴 벨트 (겨드랑이 밑 가슴 위를 한 바퀴)와 앞쪽 고리
	var belt := TorusMesh.new()
	belt.inner_radius = 0.128
	belt.outer_radius = 0.172
	belt.rings = 32
	belt.ring_segments = 12
	_add("belt", belt, BELT)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.018
	ring.outer_radius = 0.034
	ring.rings = 16
	ring.ring_segments = 8
	_add("ring", ring, METAL)
	for i in 2:
		# 다리
		_add("hipj%d" % i, _sphere(0.08), PANTS)
		_add("thigh%d" % i, _taper(0.078, 0.062), PANTS)
		_add("knee%d" % i, _sphere(0.062), PANTS)
		_add("shin%d" % i, _taper(0.06, 0.046), PANTS)
		_add("shoe%d" % i, _capsule(0.055, 0.25), SHOE)
		# 팔: 반소매 셔츠 + 맨팔
		_add("shj%d" % i, _sphere(0.058), SHIRT)
		_add("upper%d" % i, _taper(0.054, 0.044), SHIRT)
		_add("elbow%d" % i, _sphere(0.043), SKIN)
		_add("fore%d" % i, _taper(0.042, 0.033), SKIN)
		_add("hand%d" % i, _sphere(0.042), SKIN)
	_add("rope", _taper(0.014, 0.014), ROPE)
	_add("rope_sill", _taper(0.014, 0.014), ROPE)
	# 밤이라 어두우므로 사람이 묻히지 않게 은은한 보조 조명을 함께 움직인다
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.9, 0.78)
	fill.light_energy = 0.55
	fill.omni_range = 5.0
	fill.shadow_enabled = false
	add_child(fill)
	n["fill"] = fill


func _add(key: String, mesh: Mesh, color: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	add_child(mi)
	n[key] = mi


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 24
	m.rings = 8
	return m


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 24
	m.rings = 12
	return m


# 끝이 가늘어지는 원통 (높이 1 — _seg()가 길이에 맞춰 늘린다). r_a = 시작 쪽 반지름
func _taper(r_a: float, r_b: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = r_a
	m.top_radius = r_b
	m.height = 1.0
	m.radial_segments = 16
	m.rings = 1
	return m


func _mat(color: Color) -> StandardMaterial3D:
	if not mats.has(color):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		m.metallic_specular = 0.25
		if color == METAL:
			m.metallic = 0.6
			m.roughness = 0.4
		mats[color] = m
	return mats[color]
