extends Node3D
## 연기 속 탈출 — 화재 대피 체험
## 교실에서 잠깐 잠들었다 깨어나 보니 연기가 가득하다. 앞이 잘 보이지 않는다.
## 자세를 낮추고, 코와 입을 막고, 초록색 유도등을 따라 계단으로 대피해야 한다.

const DEFAULT_DENSITY := 0.5

var player: CharacterBody3D
var env: Environment

var breath := 100.0           # 호흡 (0 이 되면 의식을 잃음)
var _state := "intro"         # intro → play → escaped / fainted
var _density := DEFAULT_DENSITY
var _smoke_color := Color(0.13, 0.12, 0.11)
var _heat := 0.0
var _cough_timer := 3.0
var _blur_pulse := 0.0
var _alarm_on := false

# 기록 (엔딩 평가용)
var _t_play := 0.0
var _t_moving := 0.0
var _t_moving_low := 0.0
var _t_smoke := 0.0
var _t_smoke_cover := 0.0
var _elevator_tried := false
var _hot_checked := false
var _hints := {}
var _stand_smoke_time := 0.0
var _f1_reached := false      # 1층까지 내려가 출구가 막힌 것을 확인함
var _desc_log := {}           # 완강기 사용 단계 기록
var _outside := false
var _descent_t := 0.0
var _descent_view: Node3D      # 완강기 하강 3인칭 연출 (scripts/descent_view.gd)
var _objective: Label

# HUD
var _fx: ShaderMaterial
var _msg_box: PanelContainer
var _msg: Label
var _msg_tween: Tween
var _prompt: Label
var _breath_bar: ProgressBar
var _breath_fill: StyleBoxFlat
var _posture: Label
var _sleeve: Panel
var _end_panel: PanelContainer
var _end_title: Label
var _end_body: RichTextLabel


func _ready() -> void:
	randomize()
	Descender.reset()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _smoke_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.45)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = _smoke_color
	env.fog_density = DEFAULT_DENSITY
	env.fog_sky_affect = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var map := get_node("Map")
	var start: Node3D = map.get_node("Markers/PlayerStart")
	var escape: Area3D = map.get_node("EscapeZone")
	escape.body_entered.connect(_on_escape_entered)

	player = preload("res://scripts/player.gd").new()
	add_child(player)
	player.global_position = start.global_position + Vector3(0, 0.05, 0)
	player.rotation.y = start.global_rotation.y

	_build_hud()
	_intro()


# ================================================================== 진행
func _process(delta: float) -> void:
	_update_smoke(delta)
	if _state == "play":
		_update_breath(delta)
		_update_prompt()
		_update_hints(delta)
		_update_mission()
	elif _state == "descending":
		_descent_t += delta
		player.camera.rotation.z = sin(_descent_t * 1.6) * 0.035   # 로프에 매달려 살짝 흔들림
	_update_fx(delta)


func _update_smoke(delta: float) -> void:
	# 지금 서 있는 연기 구역 찾기 (겹치면 작은 구역 우선)
	var head: Vector3 = player.camera.global_position
	var best: Node = null
	for z in get_tree().get_nodes_in_group("smoke_zones"):
		if z.contains(head) and (best == null or z.volume() < best.volume()):
			best = z
	var target_density: float = best.density if best else DEFAULT_DENSITY
	var target_color: Color = best.smoke_color if best else Color(0.13, 0.12, 0.11)
	# 건물 밖(창밖)은 맑은 밤공기. 완강기 하강 중에는 바깥 카메라로 보므로 처음부터 바깥 공기로 본다.
	_outside = (player.global_position.z > 11.4 and player.global_position.x > -13.9) or _state == "descending"
	if _outside:
		target_density = 0.02
		target_color = Color(0.1, 0.12, 0.17)
	# 불의 열기
	_heat = 0.0
	for f in get_tree().get_nodes_in_group("fires"):
		var d: float = player.global_position.distance_to(f.global_position)
		if d < f.heat_radius:
			_heat = maxf(_heat, 1.0 - d / f.heat_radius)
	target_color = target_color.lerp(Color(0.4, 0.17, 0.06), _heat * 0.7)
	_density = lerpf(_density, target_density, clampf(delta * 1.5, 0.0, 1.0))
	_smoke_color = _smoke_color.lerp(target_color, clampf(delta * 1.5, 0.0, 1.0))
	# 연기는 위로 모인다: 자세를 낮추면 덜 가려짐
	var low_t := clampf((player.head_height - 0.85) / (1.6 - 0.85), 0.0, 1.0)   # 0 = 낮춤, 1 = 섬
	env.fog_density = _density * lerpf(0.5, 1.0, low_t)
	env.fog_light_color = _smoke_color
	env.background_color = _smoke_color


func _update_breath(delta: float) -> void:
	var low: bool = player.head_height < 1.2
	var in_smoke := _density > 0.12
	var drain := 0.0
	if in_smoke:
		drain = (_density / 0.6) * (1.0 if low else 3.0) * (0.45 if player.covering else 1.0)
		_t_smoke += delta
		if player.covering:
			_t_smoke_cover += delta
	else:
		drain = -5.0   # 맑은 공기에서는 회복
	drain += _heat * 28.0
	breath = clampf(breath - drain * delta, 0.0, 100.0)
	_t_play += delta
	if player.is_moving:
		_t_moving += delta
		if low:
			_t_moving_low += delta

	# 기침
	_cough_timer -= delta
	if in_smoke and not player.covering and _cough_timer <= 0.0:
		Sfx.play("cough", -4.0, randf_range(0.9, 1.1))
		player.shake(0.5)
		_blur_pulse = 0.6
		breath = maxf(0.0, breath - 1.5)
		_cough_timer = randf_range(6.0, 10.0) if low else randf_range(2.5, 5.0)
	elif player.covering:
		_cough_timer = maxf(_cough_timer, 1.5)

	_breath_bar.value = breath
	_breath_fill.bg_color = Color(0.85, 0.2, 0.15).lerp(Color(0.3, 0.75, 0.4), breath / 100.0)
	_posture.text = ("자세: 낮춤" if low else "자세: 서 있음") + ("   ·   코와 입을 막는 중" if player.covering else "")

	if breath <= 0.0:
		_faint()


func _update_prompt() -> void:
	var obj: Object = player.looked_object()
	_prompt.text = obj.get_prompt() if obj else ""


func _update_hints(delta: float) -> void:
	var low: bool = player.head_height < 1.2
	if not low and _density > 0.2:
		_stand_smoke_time += delta
		if _stand_smoke_time > 3.0:
			_hint("crouch", "연기는 위로 올라간다. 자세를 낮추자!  (C)", 4.0)
	if _stand_smoke_time > 9.0:
		_hint("cover", "숨쉬기가 힘들다… 소매로 코와 입을 막자!  (F 누르고 있기)", 4.0)
	if player.global_position.z > 8.3:
		_hint("corridor", "복도도 연기로 가득하다.\n초록색 유도등을 따라가자.", 4.0)
	if player.global_position.x < -15.0:
		_hint("stairs", "비상계단이다. 1층 출구까지 내려가자!", 3.5)
	if _heat > 0.05:
		_hint("fire", "불이다! 너무 뜨겁다. 이쪽으로는 갈 수 없다.", 3.5)
	if breath < 35.0:
		_hint("low", "숨이 막힌다… 서둘러야 해!", 3.0)


const _STEPS := [
	"4층 복도 창가에서 완강기함을 찾는다",
	"완강기를 꺼낸다",
	"창문을 열고, 지지대에 완강기 고리를 건다",
	"아래를 확인하고 로프를 창밖으로 던진다",
	"벨트를 입고 가슴 위로 조인다",
	"창틀에 걸터앉아 내려간다",
]


func _update_mission() -> void:
	if not _f1_reached and player.global_position.y < 0.6 and player.global_position.x < -14.2:
		_f1_reached = true
		_show_message("1층이다! 그런데 출구로 내려가는 계단에 불길이 번졌다.\n더는 내려갈 수 없다… 다른 길을 찾아야 한다!", 5.0)
	if not _f1_reached:
		_objective.text = "목표: 1층 출구로 대피한다"
		return
	var step: String = _STEPS[Descender.stage]
	if Descender.stage == 3 and not Descender.window_open:
		step = "창문을 열고, 아래를 확인하며 로프를 던진다"
	elif Descender.stage == 2 and not Descender.window_open:
		step = "창문을 열고, 지지대에 완강기 고리를 건다"
	_objective.text = "목표: 1층 출구가 불길로 막혔다 → 4층 완강기로 탈출\n  · " + step


func _hint(id: String, text: String, dur: float) -> void:
	if _hints.has(id):
		return
	_hints[id] = true
	_show_message(text, dur)


func _update_fx(delta: float) -> void:
	_blur_pulse = maxf(0.0, _blur_pulse - delta * 0.8)
	var choke := 1.0 - breath / 100.0
	_fx.set_shader_parameter("blur", clampf(_density * 0.25 + choke * 0.6 + _blur_pulse, 0.0, 1.0))
	_fx.set_shader_parameter("vignette", clampf(0.2 + choke * 0.8, 0.0, 1.0))
	_fx.set_shader_parameter("tint", Color(1.0, 0.35, 0.05, _heat * 0.6))
	# 소매 (코와 입 막기)
	var target := -150.0 if player.covering else 40.0
	_sleeve.offset_top = lerpf(_sleeve.offset_top, target, clampf(delta * 10.0, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if _state == "play" and event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var obj: Object = player.looked_object()
		if obj:
			_handle_result(obj.interact())
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		if _state in ["escaped", "fainted"]:
			Sfx.stop_all_loops()
			get_tree().reload_current_scene()


func _handle_result(res: Dictionary) -> void:
	if res.is_empty():
		return
	var ev: String = res.get("event", "")
	if ev.begins_with("desc_"):
		_desc_log[ev] = true
		Sfx.play("door" if ev == "desc_window" else "beep", -8.0)
	match ev:
		"descend":
			_start_descent(res.get("window"))
			return
		"alarm":
			_ring_alarm()
			return
		"exit_opened":
			Sfx.play("door", -4.0)
		"hot_checked":
			_hot_checked = true
			player.shake(0.3)
			_blur_pulse = 0.4
		"elevator":
			_elevator_tried = true
			Sfx.play("beep", -6.0)
	if res.get("msg", "") != "":
		_show_message(res.msg, 4.0)


func _ring_alarm() -> void:
	if _alarm_on:
		_show_message("이미 비상벨이 울리고 있다.", 2.0)
		return
	_alarm_on = true
	Sfx.start_loop("alarm", -12.0)
	for a in get_tree().get_nodes_in_group("alarm_buttons"):
		a.set_lamp(true)
	_show_message("\"불이야!\" 비상벨을 눌러 건물 전체에 화재를 알렸다.", 3.5)


# ================================================================== 연출
func _intro() -> void:
	_state = "intro"
	player.controls_enabled = false
	player.camera.rotation.x = -1.0     # 책상에 엎드린 자세
	_fx.set_shader_parameter("fade", 1.0)
	_fx.set_shader_parameter("lid", 1.0)
	for a in get_tree().get_nodes_in_group("alarm_buttons"):
		a.set_lamp(false)
	await get_tree().create_timer(1.0).timeout
	_show_message("……", 1.5)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _fx.set_shader_parameter("fade", v), 1.0, 0.0, 1.2)
	tw.tween_method(_set_lid, 1.0, 0.55, 0.6)
	tw.tween_method(_set_lid, 0.55, 1.0, 0.3)
	tw.tween_method(_set_lid, 1.0, 0.35, 0.7)
	tw.tween_method(_set_lid, 0.35, 0.8, 0.3)
	tw.tween_method(_set_lid, 0.8, 0.0, 0.9)
	var tw2 := create_tween()
	tw2.tween_interval(1.5)
	tw2.tween_property(player.camera, "rotation:x", -0.12, 2.8).set_trans(Tween.TRANS_SINE)
	await tw.finished
	Sfx.play("cough", -3.0)
	player.shake(0.5)
	_show_message("콜록콜록… 이게 무슨 냄새지?\n연기…! 불이 났다!", 3.5)
	await get_tree().create_timer(3.5).timeout
	_state = "play"
	player.controls_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_message("여기는 3층 교실이다.\n교실을 빠져나가 1층 출구로 대피해야 한다!", 3.5)


func _set_lid(v: float) -> void:
	_fx.set_shader_parameter("lid", v)


## 완강기로 창밖으로 내려가는 연출: 창틀로 → 몸을 내밂 → 일정한 속도로 하강 → 착지
func _start_descent(win: Node3D) -> void:
	_state = "descending"
	_descent_t = 0.0
	player.controls_enabled = false
	player.frozen = true
	# 내려가는 동안에는 두 손이 로프와 벽을 짚어야 하므로 코와 입을 막던 손을 뗀다.
	# (frozen이면 플레이어가 covering을 다시 계산하지 않아 막은 상태가 그대로 남았다)
	player.covering = false
	_prompt.text = ""
	_objective.text = ""
	var wp: Vector3 = win.global_position   # 창문 안쪽 벽면, 바닥 높이
	var ground_y := -1.85
	_show_message("창틀에 걸터앉아 몸을 밖으로 내민다…\n두 손으로 로프를 잡지 말고, 벽을 발로 밀며 내려가자.", 4.5)
	# 건물 밖 3인칭 카메라로 바꿔, 아래의 트윈으로 움직이는 플레이어 위치에 사람 모형을 보여 준다
	_descent_view = preload("res://scripts/descent_view.gd").new()
	add_child(_descent_view)
	_descent_view.begin(player, win)
	var tw := create_tween()
	tw.tween_property(player, "global_position", Vector3(wp.x, wp.y, wp.z - 0.35), 1.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(player, "rotation:y", player.rotation.y + angle_difference(player.rotation.y, PI), 1.2)
	tw.parallel().tween_property(player.camera, "rotation:x", -0.3, 1.2)
	tw.tween_property(player, "global_position", Vector3(wp.x, wp.y, wp.z + 0.9), 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _show_message("로프가 풀리며 천천히 내려간다.\n속도는 일정하다. 침착하게…", 4.0))
	tw.tween_property(player, "global_position:y", ground_y + 0.05, 12.0)
	tw.parallel().tween_property(player, "global_position:z", wp.z + 1.4, 12.0)
	tw.parallel().tween_property(player.camera, "rotation:x", -0.55, 6.0)
	tw.tween_callback(_finish_descent)


func _finish_descent() -> void:
	player.camera.rotation.z = 0.0
	player.camera.rotation.x = -0.1
	if _descent_view:
		_descent_view.land()
	_show_message("무사히 지상에 도착했다! 벨트를 풀고 건물에서 멀리 떨어지자.", 3.0)
	await get_tree().create_timer(1.5).timeout
	_state = "play"
	_on_escape_entered(player)


func _on_escape_entered(body: Node) -> void:
	if body != player or _state != "play":
		return
	_state = "escaped"
	player.controls_enabled = false
	_show_message("", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _fx.set_shader_parameter("fade", v), 0.0, 0.85, 1.5)
	await tw.finished
	_show_end(true)


func _faint() -> void:
	if _state != "play":
		return
	_state = "fainted"
	player.controls_enabled = false
	_show_message("", 0.0)
	var tw := create_tween()
	tw.tween_method(_set_lid, 0.0, 1.0, 2.5)
	tw.parallel().tween_property(player.camera, "rotation:z", 0.5, 2.5)
	await tw.finished
	_show_end(false)


func _show_end(success: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_prompt.text = ""
	var low_pct := int(100.0 * _t_moving_low / maxf(_t_moving, 0.01))
	var cover_pct := int(100.0 * _t_smoke_cover / maxf(_t_smoke, 0.01))
	var ok := "[color=#3a9a5b]✔[/color]"
	var no := "[color=#c0392b]✘[/color]"
	var t := ""
	if success:
		_end_title.text = "대피 성공!"
		t += "4층 완강기를 타고 창문을 통해 건물 밖으로 대피했습니다.\n"
		t += "걸린 시간 %d초   ·   남은 호흡 %d%%\n\n" % [int(_t_play), int(breath)]
	else:
		_end_title.text = "의식을 잃었습니다"
		t += "연기를 너무 많이 마셨습니다.\n"
		t += "화재 사망자의 상당수는 불길이 아니라 연기 때문에 목숨을 잃습니다.\n\n"
	t += "[b]이번 대피 돌아보기[/b]\n"
	t += "%s 비상벨을 눌러 화재를 알렸다\n" % (ok if _alarm_on else no)
	t += "%s 자세를 낮춰 이동했다 (%d%%)\n" % [ok if low_pct >= 60 else no, low_pct]
	t += "%s 코와 입을 막았다 (%d%%)\n" % [ok if cover_pct >= 50 else no, cover_pct]
	t += "%s 엘리베이터를 타려 하지 않았다\n" % (no if _elevator_tried else ok)
	if _hot_checked:
		t += "%s 뜨거운 문을 열지 않고 다른 길을 찾았다\n" % ok
	t += "%s 1층까지 내려가 출구 상황을 확인했다\n" % (ok if _f1_reached else no)
	t += "%s 완강기를 지지대에 고정하고 로프를 내린 뒤 벨트를 입고 내려왔다\n" % (ok if (_desc_log.has("desc_hook") and _desc_log.has("desc_rope") and _desc_log.has("desc_belt") and success) else no)
	t += "\n[b]실제 화재가 났을 때[/b]\n"
	t += "1. \"불이야!\" 크게 외치고 비상벨(발신기)을 누릅니다.\n"
	t += "2. 젖은 수건이나 옷소매로 코와 입을 막고, 자세를 낮춰 이동합니다.\n"
	t += "3. 초록색 유도등을 따라 계단으로 대피합니다. 엘리베이터는 타지 않습니다.\n"
	t += "4. 문을 열기 전 손등으로 손잡이를 만져 보고, 뜨거우면 열지 않습니다.\n"
	t += "5. 계단이 불길이나 연기로 막혔다면 창가의 완강기(피난사다리)를 씁니다.\n    ①지지대에 고리를 걸어 고정 ②아래를 확인하고 로프를 창밖으로 내림\n    ③벨트를 겨드랑이 밑 가슴 위에 걸고 조임 ④창밖으로 나가 벽을 밀며 내려감\n"
	t += "6. 밖으로 대피한 뒤 119에 신고합니다.\n\n"
	t += "[color=#777777][R] 다시 하기[/color]"
	_end_body.text = t
	_end_panel.visible = true


# ================================================================== HUD
func _korean_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "맑은 고딕", "Noto Sans CJK KR", "Noto Sans KR", "NanumGothic", "sans-serif"])
	return font


func _build_hud() -> void:
	var font := _korean_font()
	var theme := Theme.new()
	theme.default_font = font

	# 화면 효과 (흐림 / 비네트 / 열기 / 눈꺼풀)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 0
	add_child(fx_layer)
	var fx_rect := ColorRect.new()
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx = ShaderMaterial.new()
	_fx.shader = preload("res://shaders/screen_fx.gdshader")
	fx_rect.material = _fx
	fx_layer.add_child(fx_rect)
	fx_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 소매 (코와 입 막기) — 화면 아래에서 올라옴
	_sleeve = Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.16, 0.17, 0.22)
	ss.set_corner_radius_all(160)
	_sleeve.add_theme_stylebox_override("panel", ss)
	_sleeve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sleeve)
	_sleeve.anchor_left = 0.18
	_sleeve.anchor_right = 0.82
	_sleeve.anchor_top = 1.0
	_sleeve.anchor_bottom = 1.0
	_sleeve.offset_top = 40.0
	_sleeve.offset_bottom = 260.0

	# 점 조준선
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.35)
	dot.size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dot)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)

	# 호흡 게이지
	var bl := _label(root, 16, Color(1, 1, 1, 0.85))
	bl.text = "호흡"
	bl.position = Vector2(24, 18)
	_breath_bar = ProgressBar.new()
	_breath_bar.show_percentage = false
	_breath_bar.max_value = 100.0
	_breath_bar.value = 100.0
	_breath_bar.position = Vector2(70, 22)
	_breath_bar.size = Vector2(240, 16)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(4)
	_breath_fill = StyleBoxFlat.new()
	_breath_fill.bg_color = Color(0.3, 0.75, 0.4)
	_breath_fill.set_corner_radius_all(4)
	_breath_bar.add_theme_stylebox_override("background", bg)
	_breath_bar.add_theme_stylebox_override("fill", _breath_fill)
	_breath_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_breath_bar)
	_posture = _label(root, 14, Color(1, 1, 1, 0.65))
	_posture.position = Vector2(24, 46)
	_objective = _label(root, 16, Color(1, 0.95, 0.6, 0.95))
	_objective.position = Vector2(24, 72)
	_objective.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective.add_theme_constant_override("outline_size", 4)
	_objective.text = "목표: 1층 출구로 대피한다"

	# 상호작용 안내
	_prompt = _label(root, 20, Color(1, 1, 1, 0.95))
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_top = -120
	_prompt.offset_bottom = -90
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)

	var help := _label(root, 13, Color(1, 1, 1, 0.5))
	help.text = "W A S D 이동  ·  마우스 시선  ·  C 자세 낮추기  ·  F / 우클릭(누르고 있기) 코와 입 막기  ·  E / 좌클릭 상호작용  ·  Esc 마우스 해제"
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.offset_top = -32
	help.offset_bottom = -10

	# 안내 문구 (위쪽 가운데)
	var top := CenterContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 70
	top.offset_bottom = 200
	_msg_box = PanelContainer.new()
	var mb := StyleBoxFlat.new()
	mb.bg_color = Color(0, 0, 0, 0.55)
	mb.set_corner_radius_all(6)
	mb.content_margin_left = 26
	mb.content_margin_right = 26
	mb.content_margin_top = 14
	mb.content_margin_bottom = 14
	_msg_box.add_theme_stylebox_override("panel", mb)
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_msg_box)
	_msg = _label(_msg_box, 22, Color.WHITE)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_box.visible = false

	# 엔딩
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cc)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_panel = PanelContainer.new()
	var eb := StyleBoxFlat.new()
	eb.bg_color = Color(0.97, 0.96, 0.93, 0.97)
	eb.set_corner_radius_all(8)
	eb.set_content_margin_all(32)
	_end_panel.add_theme_stylebox_override("panel", eb)
	cc.add_child(_end_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_end_panel.add_child(vb)
	_end_title = _label(vb, 32, Color(0.12, 0.12, 0.12))
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body = RichTextLabel.new()
	_end_body.bbcode_enabled = true
	_end_body.fit_content = true
	_end_body.custom_minimum_size = Vector2(640, 0)
	_end_body.add_theme_font_size_override("normal_font_size", 17)
	_end_body.add_theme_font_size_override("bold_font_size", 18)
	_end_body.add_theme_color_override("default_color", Color(0.15, 0.15, 0.15))
	_end_body.add_theme_font_override("normal_font", font)
	var bold := SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	_end_body.add_theme_font_override("bold_font", bold)
	vb.add_child(_end_body)
	_end_panel.visible = false


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## duration 초 뒤 사라짐 (0 이면 즉시 숨김)
func _show_message(text: String, duration: float) -> void:
	if _msg_tween:
		_msg_tween.kill()
	_msg.text = text
	_msg_box.visible = text != ""
	_msg_box.modulate.a = 1.0
	if duration > 0.0 and text != "":
		_msg_tween = create_tween()
		_msg_tween.tween_interval(duration)
		_msg_tween.tween_property(_msg_box, "modulate:a", 0.0, 0.6)
		_msg_tween.tween_callback(func() -> void: _msg_box.visible = false)
