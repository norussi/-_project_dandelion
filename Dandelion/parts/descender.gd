@tool
class_name Descender
extends StaticBody3D
## 완강기 세트. 실제 사용 순서대로 E 키로 진행하고, 단계마다 짧은 동작(애니메이션)이 나온다.
##  1) 완강기함 열기 → 2) 완강기 꺼내기 → (창문 열기) → 3) 지지대를 세워 창밖으로 펼치기
##  4) 지지대 끝 고리에 완강기를 걸고 잠그기 → 5) 아래를 확인하고 로프 던지기
##  6) 벨트를 가슴 위로 입고 조이기 → 7) 창틀에서 내려가기
## 같은 스크립트를 세 군데에 쓴다 (part): 완강기함(CASE) / 지지대(ANCHOR) / 창문(WINDOW).
## 지지대와 창문은 같은 자리(창문 가운데 아래 벽면)에 둔다. 지지대·로프 위치를 서로 맞춰 쓰기 때문이다.
## 기준점 = 벽면 위 바닥. 앞면(+Z)이 복도 쪽, 창밖은 -Z 쪽이다. (북쪽 벽에 붙일 때 Y축으로 180° 돌린다)
##
## interact()는 동작이 있는 단계에서 {"anim": 걸리는 시간, "look": 바라볼 곳(전역 좌표)}을 함께 돌려준다.
## main.gd는 그동안 조작을 막고 시선을 그쪽으로 돌리며, 호흡이 줄어들지 않게 한다.

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

## 0 함 닫힘 → 1 함 열림 → 2 꺼냄 → 3 지지대 펼침 → 4 고리 걸어 고정 → 5 로프 내림 → 6 벨트 착용
static var stage := 0
static var window_open := false

## 지지대: 창문 아래 벽에 접혀(팔이 아래로 늘어져) 있다가, 방 쪽으로 들어 올려 창밖으로 60° 기울여 펼친다.
## 열린 창문 유리(양옆 경첩에서 복도 쪽으로 열림)와 창틀에 닿지 않는 위치·각도다.
const HINGE := Vector3(0.45, 1.0, 0.2)       # 지지대 팔의 회전축 (창틀 윗면 바로 아래, 복도 쪽)
const ARM_LEN := 1.0
const ARM_OPEN := -240.0                      # 펼쳤을 때 팔 각도 (X축, 도). 0 = 아래로 접힘
const TIP := Vector3(0.45, 1.5, -0.666)       # 펼친 팔 끝 고리 = HINGE + (0, cos60°, -sin60°) × ARM_LEN
const REEL_POS := Vector3(0.45, 1.3, -0.666)  # 고리에 매단 완강기(릴) 가운데
const ROPE_TOP := Vector3(0.45, 1.18, -0.666) # 릴 아래로 로프가 나오는 곳

const ORANGE := Color(0.95, 0.45, 0.08)
const BELT := Color(0.82, 0.12, 0.08)

var _door: Node3D
var _reel: Node3D
var _hinge_l: Node3D
var _hinge_r: Node3D
var _arm: Node3D
var _hooked_reel: Node3D
var _lock: Node3D
var _rope_out: Node3D
var _arm_shape: CollisionShape3D
var _shown_stage := 0
var _shown_window := false


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
				return "E  완강기 지지대"
			if stage == 2:
				return "E  지지대를 세워 창밖으로 펼치기"
			if stage == 3:
				return "E  지지대 고리에 완강기 걸고 잠그기"
		Part.WINDOW:
			if not window_open:
				return "E  창문 열기"
			match stage:
				4:
					return "E  아래를 확인하고 로프 던지기"
				5:
					return "E  벨트를 가슴 위로 입고 조이기"
				6:
					return "E  창틀에 걸터앉아 내려가기"
	return ""


func interact() -> Dictionary:
	var res := {}
	match part:
		Part.CASE:
			if stage == 0:
				stage = 1
				res = {"msg": "완강기함을 열었다.\n안에 완강기(릴)와 로프, 벨트가 들어 있다.", "event": "desc_case",
					"anim": 0.8, "look": to_global(Vector3(0, 0.55, 0.1))}
			elif stage == 1:
				stage = 2
				res = {"msg": "완강기를 꺼냈다.\n창문을 열고, 창문 아래 벽의 지지대를 펼쳐 완강기를 걸어야 한다.", "event": "desc_take",
					"anim": 1.0, "look": to_global(Vector3(0, 0.5, 0.1))}
		Part.ANCHOR:
			if stage < 2:
				res = {"msg": "창문 아래 벽에 접이식 완강기 지지대가 있다.\n먼저 완강기함에서 완강기를 꺼내자.", "event": ""}
			elif stage == 2:
				if not window_open:
					res = {"msg": "지지대를 창밖으로 펼치려면 먼저 창문을 열어야 한다.", "event": ""}
				else:
					stage = 3
					res = {"msg": "접혀 있던 지지대를 들어 올려 창밖으로 펼쳤다.\n팔 끝의 고리가 건물 벽에서 떨어져 창밖에 나와 있다.", "event": "desc_arm",
						"anim": 1.9, "look": to_global(Vector3(HINGE.x, 1.2, 0.0)), "stand": to_global(Vector3(0.1, 0, 0.8))}
			elif stage == 3:
				stage = 4
				res = {"msg": "완강기 고리를 지지대 끝 고리에 걸고 잠금 나사를 돌려 조였다.\n힘껏 당겨 봐도 빠지지 않는다. 고정 완료!", "event": "desc_hook",
					"anim": 1.8, "look": to_global(REEL_POS), "stand": to_global(Vector3(0.2, 0, 0.65))}
		Part.WINDOW:
			if not window_open:
				window_open = true
				res = {"msg": "창문을 활짝 열었다.\n연기가 빠져나가고 찬 공기가 들어온다.", "event": "desc_window",
					"anim": 0.8, "look": to_global(Vector3(0, 1.6, 0)), "stand": to_global(Vector3(0, 0, 1.15))}
			else:
				match stage:
					0, 1:
						res = {"msg": "완강기가 필요하다. 완강기함은 복도 쪽 벽에 있다.", "event": ""}
					2:
						res = {"msg": "창문 아래 벽의 지지대를 창밖으로 펼쳐 완강기를 걸자.", "event": ""}
					3:
						res = {"msg": "펼친 지지대 끝 고리에 완강기를 걸자.", "event": ""}
					4:
						stage = 5
						res = {"msg": "아래에 사람이나 장애물이 없는지 확인했다.\n로프 릴을 창밖으로 던지자 로프가 지면까지 풀려 내려갔다.", "event": "desc_rope",
							"anim": 1.8, "look": to_global(Vector3(TIP.x, 0.9, -1.6)), "stand": to_global(Vector3(0.15, 0, 0.55))}
					5:
						stage = 6
						res = {"msg": "벨트를 머리부터 넣어 겨드랑이 밑, 가슴 위에 걸고\n조임쇠를 당겨 몸에 단단히 조였다.", "event": "desc_belt",
							"anim": 1.7, "look": to_global(Vector3(0, 0.2, -0.3)), "stand": to_global(Vector3(0, 0, 0.75))}
					6:
						res = {"event": "descend", "window": self}
	if not res.is_empty():
		get_tree().call_group("descender_parts", "_refresh")
	return res


# ------------------------------------------------------------------ 동작
## 단계가 바뀌면 각 부분이 자기 몫의 동작을 보여 준다 (모든 부분에 call_group으로 불린다)
func _refresh() -> void:
	var from := _shown_stage
	var win_was := _shown_window
	_shown_stage = stage
	_shown_window = window_open
	match part:
		Part.CASE:
			if from < 1 and stage >= 1 and _door:
				_tween().tween_property(_door, "rotation:y", deg_to_rad(-105.0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if from < 2 and stage >= 2 and _reel:
				_carry_reel_out()
		Part.ANCHOR:
			if from < 3 and stage >= 3 and _arm:
				_unfold_arm()
			if from < 4 and stage >= 4:
				_hook_reel()
		Part.WINDOW:
			if not win_was and window_open and _hinge_l:
				var tw := _tween()
				tw.set_parallel(true)
				tw.tween_property(_hinge_l, "rotation:y", deg_to_rad(-95.0), 0.7).set_trans(Tween.TRANS_SINE)
				tw.tween_property(_hinge_r, "rotation:y", deg_to_rad(95.0), 0.7).set_trans(Tween.TRANS_SINE)
			if from < 5 and stage >= 5 and _rope_out:
				_throw_rope()
			if from < 6 and stage >= 6:
				_put_on_belt()


func _tween() -> Tween:
	return create_tween()


func _camera() -> Camera3D:
	return get_viewport().get_camera_3d()


## 함 속의 릴을 들어 올려 손(화면 아래쪽)으로 가져온다
func _carry_reel_out() -> void:
	var cam := _camera()
	var held := _reel_mesh(0.12, 0.2)
	add_child(held)
	held.global_transform = _reel.global_transform
	_reel.visible = false
	var tw := _tween()
	tw.tween_property(held, "global_position", _reel.global_position + global_basis.z * 0.35 + Vector3.UP * 0.1, 0.35).set_trans(Tween.TRANS_SINE)
	if cam:
		tw.tween_property(held, "global_position", cam.to_global(Vector3(0.18, -0.32, -0.5)), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(held.queue_free)


## 접혀 있던 팔을 방 쪽으로 들어 올렸다가 창밖으로 기울여 펼친다
func _unfold_arm() -> void:
	var tw := _tween()
	tw.tween_property(_arm, "rotation:x", deg_to_rad(-180.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_arm, "rotation:x", deg_to_rad(ARM_OPEN), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): if _arm_shape: _arm_shape.disabled = false)


## 손에 든 완강기를 팔 끝 고리에 걸고, 잠금 나사를 돌려 조인다
func _hook_reel() -> void:
	var cam := _camera()
	if _hooked_reel == null:
		return
	var tw := _tween()
	if cam:
		var held := _reel_mesh(0.1, 0.16)
		add_child(held)
		held.global_position = cam.to_global(Vector3(0.15, -0.3, -0.45))
		held.global_basis = _hooked_reel.global_basis
		tw.tween_property(held, "global_position", to_global(REEL_POS) + Vector3.UP * 0.12, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(held, "global_position", to_global(REEL_POS), 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(held.queue_free)
	tw.tween_callback(func(): _hooked_reel.visible = true)
	# 잠금 나사를 두 바퀴 돌린다
	if _lock:
		tw.tween_property(_lock, "rotation:y", TAU * 2.0, 0.7).set_trans(Tween.TRANS_SINE)


## 손에 든 로프 뭉치를 창밖으로 던지면, 뭉치가 떨어지며 릴에서 로프가 아래로 빠르게 풀려 내려간다
func _throw_rope() -> void:
	var cam := _camera()
	var bundle := _reel_mesh(0.09, 0.14)
	add_child(bundle)
	bundle.global_position = cam.to_global(Vector3(0.12, -0.28, -0.4)) if cam else to_global(Vector3(TIP.x, 1.3, 0.5))
	_rope_out.visible = true
	_rope_out.scale = Vector3(1, 0.01, 1)
	var rope_len := ROPE_TOP.y - (1.0 - drop_height)
	var tw := _tween()
	tw.tween_interval(0.35)   # 시선이 창밖을 향하는 동안
	# 창밖으로 던진다 (살짝 위로 포물선)
	tw.tween_property(bundle, "global_position", to_global(Vector3(TIP.x, 1.55, -1.1)), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(bundle, "global_position", to_global(Vector3(TIP.x, ROPE_TOP.y - rope_len + 0.08, -0.666)), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_rope_out, "scale:y", 1.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(bundle.queue_free)


## 벨트 고리를 들어 올려 가슴 높이에 걸고, 조임쇠를 당겨 조인다 (1인칭: 화면 아래에서 올라온다)
func _put_on_belt() -> void:
	var cam := _camera()
	if cam == null:
		return
	var belt := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.11
	tm.outer_radius = 0.14
	belt.mesh = tm
	belt.material_override = _color_mat(BELT)
	var buckle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.03, 0.05)
	buckle.mesh = bm
	buckle.material_override = preload("res://materials/metal.tres")
	buckle.position = Vector3(0, 0, 0.13)
	belt.add_child(buckle)
	cam.add_child(belt)
	# 화면 아래에서 고리를 들어 올려 가슴 앞에 두르고, 조임쇠를 당겨 조인다
	belt.position = Vector3(0, -0.75, -0.6)
	belt.rotation.x = deg_to_rad(25.0)
	var tw := _tween()
	tw.tween_interval(0.25)
	tw.tween_property(belt, "position", Vector3(0, -0.17, -0.6), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(belt, "position", Vector3(0, -0.24, -0.5), 0.3).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(belt, "scale", Vector3(0.8, 1, 0.8), 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.25)
	tw.tween_property(belt, "position:y", -0.85, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(belt.queue_free)


# ------------------------------------------------------------------ 겉모습
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
	_arm = null
	_hooked_reel = null
	_lock = null
	_rope_out = null
	_arm_shape = null
	var metal := preload("res://materials/metal.tres")
	var red := preload("res://materials/red.tres")
	var glass := preload("res://materials/glass.tres")
	var dark := preload("res://materials/dark.tres")
	var orange := _color_mat(ORANGE)
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
			# 벽에 박힌 받침판과 경첩
			_box(Vector3(HINGE.x, HINGE.y - 0.08, 0.02), Vector3(0.22, 0.26, 0.04), metal, self)
			_box(Vector3(HINGE.x, HINGE.y, HINGE.z * 0.5 + 0.02), Vector3(0.12, 0.08, HINGE.z), metal, self)
			_cyl(HINGE, 0.03, 0.14, dark, self, false).rotation.z = deg_to_rad(90.0)
			_label("완강기 지지대", Vector3(HINGE.x, HINGE.y - 0.3, 0.045), 22, Color(0.85, 0.1, 0.05), self)
			# 팔: 경첩에서 아래로 늘어진 모양으로 만들고, 펼칠 때 X축으로 돌린다
			_arm = Node3D.new()
			_arm.position = HINGE
			_add(_arm, self)
			_box(Vector3(0, -ARM_LEN * 0.5, 0), Vector3(0.05, ARM_LEN, 0.05), metal, _arm)
			_box(Vector3(0, -ARM_LEN * 0.25, 0), Vector3(0.03, ARM_LEN * 0.45, 0.075), metal, _arm)   # 보강대
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.03
			tm.outer_radius = 0.05
			ring.mesh = tm
			ring.material_override = metal
			ring.rotation.z = deg_to_rad(90.0)
			ring.position = Vector3(0, -ARM_LEN - 0.03, 0)
			_add(ring, _arm)
			# 고리에 매단 완강기 (고리를 걸면 보인다): 팔과 상관없이 늘 아래로 매달린다
			_hooked_reel = Node3D.new()
			_hooked_reel.position = REEL_POS
			_add(_hooked_reel, self)
			_box(Vector3(0, 0.1, 0), Vector3(0.025, 0.12, 0.025), metal, _hooked_reel)                  # 걸이
			_cyl(Vector3.ZERO, 0.1, 0.16, orange, _hooked_reel, true)
			_lock = Node3D.new()
			_lock.position = Vector3(0, 0.16, 0)
			_add(_lock, _hooked_reel)
			_box(Vector3.ZERO, Vector3(0.07, 0.025, 0.025), dark, _lock)                                # 잠금 나사
			bs.size = Vector3(0.3, 1.1, 0.16)
			cs.position = Vector3(HINGE.x, 0.5, HINGE.z * 0.5 + 0.04)
			# 펼친 팔을 바라봐도 고리를 걸 수 있도록, 펼치면 켜지는 충돌
			_arm_shape = CollisionShape3D.new()
			var arm_box := BoxShape3D.new()
			arm_box.size = Vector3(0.25, 0.6, 0.45)
			_arm_shape.shape = arm_box
			_arm_shape.position = Vector3(HINGE.x, 1.3, -0.05)
			_add(_arm_shape, self)
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
			# 창밖 로프: 지지대에 매단 릴 아래에서 지면 근처까지. 위쪽 끝을 기준으로 늘어나며 풀린다.
			_rope_out = Node3D.new()
			_rope_out.position = ROPE_TOP
			_add(_rope_out, self)
			var rope_len := ROPE_TOP.y - (1.0 - drop_height)
			_cyl(Vector3(0, -rope_len * 0.5, 0), 0.02, rope_len, orange, _rope_out, false)
			_cyl(Vector3(0, -rope_len + 0.08, 0), 0.09, 0.14, orange, _rope_out, true)             # 끝의 벨트 뭉치
			bs.size = Vector3(2.0, 1.55, 0.1)
			cs.position = Vector3(0, 1.725, 0.05)
	cs.shape = bs
	_add(cs, self)
	if not Engine.is_editor_hint():
		_refresh_instant()


## 지금 단계 그대로 (동작 없이) 보여 준다
func _refresh_instant() -> void:
	_shown_stage = stage
	_shown_window = window_open
	if _door:
		_door.rotation.y = deg_to_rad(-105.0) if stage >= 1 else 0.0
	if _reel:
		_reel.visible = stage < 2
	if _arm:
		_arm.rotation.x = deg_to_rad(ARM_OPEN) if stage >= 3 else 0.0
	if _arm_shape:
		_arm_shape.disabled = stage < 3
	if _hooked_reel:
		_hooked_reel.visible = stage >= 4
	if _hinge_l:
		_hinge_l.rotation.y = deg_to_rad(-95.0) if window_open else 0.0
		_hinge_r.rotation.y = deg_to_rad(95.0) if window_open else 0.0
	if _rope_out:
		_rope_out.visible = stage >= 5
		_rope_out.scale = Vector3.ONE


func _reel_mesh(radius: float, height: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = _color_mat(ORANGE)
	mi.rotation.x = deg_to_rad(90.0)
	return mi


static func _color_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


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
