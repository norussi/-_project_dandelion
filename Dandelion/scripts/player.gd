extends CharacterBody3D
## 1인칭 플레이어: 걷기 / 자세 낮추기 / 코와 입 막기 / 바라보는 물체와 상호작용

const STAND_H := 1.6
const CROUCH_H := 0.85
const SEAT_H := 1.15

@export var walk_speed := 2.2
@export var crouch_speed := 1.1
@export var mouse_sensitivity := 0.0025

var controls_enabled := false
var frozen := false
var seated := true            ## 처음엔 책상에 엎드려 있다가 일어남
var crouching := false
var covering := false         ## 소매로 코와 입을 막는 중
var is_moving := false
var camera: Camera3D
var head_height := SEAT_H

var _shake := 0.0
var _step_accum := 0.0
var _lamp: OmniLight3D


func _ready() -> void:
	_setup_input()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.2
	cs.shape = cap
	cs.position.y = 0.6
	add_child(cs)

	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 80.0
	camera.position.y = SEAT_H
	add_child(camera)
	camera.current = true

	# 연기 속에서 가까운 곳만 희미하게 보이게 해주는 은은한 빛
	_lamp = OmniLight3D.new()
	_lamp.light_color = Color(1.0, 0.88, 0.75)
	_lamp.light_energy = 0.55
	_lamp.omni_range = 4.5
	_lamp.position = Vector3(0, 0.2, 0)
	camera.add_child(_lamp)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed and controls_enabled:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if not controls_enabled:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	elif event.is_action_pressed("crouch_toggle"):
		crouching = not crouching
		seated = false


func _physics_process(delta: float) -> void:
	if frozen:   # 완강기 하강 연출 중에는 스크립트가 직접 위치를 움직인다
		return
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	var input := Vector2.ZERO
	covering = false
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		covering = Input.is_action_pressed("cover")
		var turn := Input.get_axis("turn_right", "turn_left")
		rotate_y(turn * 2.0 * delta)
		if input != Vector2.ZERO:
			seated = false
	var hold := controls_enabled and Input.is_action_pressed("crouch_hold")
	var crouched := crouching or hold or seated
	var speed := crouch_speed if crouched else walk_speed
	if covering:
		speed *= 0.85
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	is_moving = dir != Vector3.ZERO

	var before := global_position
	move_and_slide()

	# 머리 높이 (앉음 / 섬 / 낮춤)
	var target_h := SEAT_H if seated else (CROUCH_H if (crouching or hold) else STAND_H)
	head_height = move_toward(head_height, target_h, delta * 2.2)
	var bob := 0.0
	if is_moving and is_on_floor():
		_step_accum += Vector2(global_position.x - before.x, global_position.z - before.z).length()
		bob = sin(_step_accum * 6.0) * (0.02 if crouched else 0.035)
		if _step_accum >= (0.55 if crouched else 0.75):
			_step_accum = 0.0
			Sfx.play("step", -14.0 if crouched else -9.0, randf_range(0.85, 1.1))
	camera.position.y = head_height + bob

	# 기침할 때 화면 흔들림
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.05
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.05
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## 바라보고 있는 상호작용 물체 (문, 발신기 등). 없으면 null
func looked_object() -> Object:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * 2.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c: Object = hit.collider
	if c and c.has_method("interact"):
		return c
	return null


func _setup_input() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A])
	_add_keys("move_right", [KEY_D])
	_add_keys("turn_left", [KEY_LEFT])
	_add_keys("turn_right", [KEY_RIGHT])
	_add_keys("crouch_toggle", [KEY_C])
	_add_keys("crouch_hold", [KEY_CTRL])
	_add_keys("cover", [KEY_F], MOUSE_BUTTON_RIGHT)
	_add_keys("interact", [KEY_E], MOUSE_BUTTON_LEFT)


func _add_keys(action: String, keys: Array, mouse_button := MOUSE_BUTTON_NONE) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	if mouse_button != MOUSE_BUTTON_NONE:
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse_button
		InputMap.action_add_event(action, mb)
