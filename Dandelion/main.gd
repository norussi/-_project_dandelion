extends Node3D

# Dandelion — Godot 4.3+, no external assets.
# 모드 1: 시각장애인 보행 체험
#
# 감각 규칙(실제에 가깝게 축소)
#  - 지팡이(긴 지팡이, 1.2m)는 몸 중앙에서 잡고, 어깨보다 조금 넓게 좌우로 호를 그린다.
#  - 지팡이 끝은 발 앞 약 1m 지점을 걸음마다 한 번씩 좌우 번갈아 두드린다 (이점 촉타법, in-step).
#  - 알 수 있는 것: 지팡이 끝이 닿은 곳(반경 수십 cm)과, 두드리는 소리가 넓은 벽/가림막에
#    반사되어 오는 희미한 울림(약 1.5~3m). 작은 물체나 허리 위 높이의 물체는 알 수 없다.

const SPEED := 1.15             # 지팡이 보행 평균 속도 (m/s)
const SPRINT_MULT := 1.35
const STEP_LENGTH := 0.62       # 한 걸음 (m)
const SENSITIVITY := 0.0022
const DEST := Vector3(0, 0, -57)

const CANE_LENGTH := 1.20
const HAND_LOCAL := Vector3(0.0, 0.95, -0.30)   # 배꼽 높이, 몸 중앙
const SWEEP_ANGLE := 0.47       # 좌우 호 반각 (rad). 끝이 좌우 약 ±0.33m → 어깨보다 조금 넓게
const TIP_LIFT := 0.035         # 호를 그릴 때 지팡이 끝이 뜨는 높이

const TOUCH_RADIUS := 0.38      # 걸으며 두드린 지점에서 느껴지는 범위
const ECHO_WALK := 1.6          # 걸으며 가볍게 두드린 소리의 반향 거리
const ECHO_HARD := 2.8          # 멈춰서 세게 두드린 소리의 반향 거리
const OBSTACLE_TOUCH := 0.65    # 지팡이에 걸린 물체를 더듬어 아는 범위
const HEAD_TOUCH := 0.75
const PULSES := 6

const NOISE_POS := Vector3(6.4, 0.5, -29.5)

var player: CharacterBody3D
var camera: Camera3D
var edge_material: ShaderMaterial
var black_material: StandardMaterial3D
var pulse_index := 0
var clock := 0.0
var hard_cooldown := 0.0
var elapsed := 0.0
var beacon_clock := 0.0
var playing := false
var finished := false
var paused := false
var story_page := 0
var checkpoint := 0
var pitch := -0.62
var message_ttl := 0.0
var status: Label
var message: Label
var panel: PanelContainer
var title: Label
var body: Label
var action: Button
var hud: Control
var flash: ColorRect
var sweep_view: Control
var sound_tap: AudioStreamWAV
var sound_step: AudioStreamWAV
var sound_beacon: AudioStreamWAV
var sound_knock: AudioStreamWAV
var sound_thud: AudioStreamWAV
var sound_paving: AudioStreamWAV
var sound_noise: AudioStreamWAV
var noise_player: AudioStreamPlayer3D
var line_vertices := PackedVector3Array()
var line_colors := PackedColorArray()

# 지팡이 상태
var cane: MeshInstance3D
var step_phase := 0.0
var sweep := 1.0                 # -1 = 왼쪽 끝, +1 = 오른쪽 끝
var tip_world := Vector3.ZERO
var tip_on_ground := true
var contact := false
var contact_label := ""
var contact_refresh := 0.0
var last_label_time := {}
var touch_marks: Array[MeshInstance3D] = []
var touch_mark_age: Array[float] = []
var mark_index := 0

# 불편함 요소 상태
var paving_rects: Array[Rect2] = []      # 선형 점자블록 (x, z)
var warning_rects: Array[Rect2] = []     # 점형 점자블록
var on_paving_msg := false
var paving_lost_msg := false
var was_on_paving := false
var off_paving_taps := 0
var tip_over_paving := false
var head_cooldown := 0.0
var stun := 0.0
var shake := 0.0
var echo_gain := 1.0
var noise_msg := false
var gps_error := Vector2.ZERO
var gps_clock := 0.0
var gps_cooldown := 0.0
var count_contacts := 0
var count_head := 0
var tts_voice := ""

func _ready() -> void:
	_setup_inputs()
	_setup_materials()
	_build_world()
	_build_player()
	_build_ui()
	sound_tap = _make_sound(1300.0, 0.20, 0)
	sound_step = _make_sound(150.0, 0.10, 1)
	sound_beacon = _make_sound(680.0, 0.55, 2)
	sound_paving = _make_sound(900.0, 0.22, 3)
	sound_knock = _make_sound(420.0, 0.18, 4)
	sound_thud = _make_sound(90.0, 0.35, 5)
	sound_noise = _make_sound(60.0, 1.0, 6)
	_start_noise()
	_reroll_gps()
	_find_tts_voice()
	_show_intro()

func _setup_inputs() -> void:
	var mappings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "tap": KEY_SPACE, "sprint": KEY_SHIFT, "phone": KEY_Q, "pause_game": KEY_ESCAPE, "restart_game": KEY_R}
	for name in mappings:
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		var event := InputEventKey.new()
		event.physical_keycode = mappings[name]
		InputMap.action_add_event(name, event)

func _setup_materials() -> void:
	black_material = StandardMaterial3D.new()
	black_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black_material.albedo_color = Color.BLACK
	edge_material = ShaderMaterial.new()
	edge_material.shader = load("res://echo.gdshader")
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.environment = environment
	add_child(env)

# ---------------------------------------------------------------- world

func _build_world() -> void:
	_box(Vector3(0,-0.25,-27), Vector3(20,0.5,70), "", 0.0, false)
	# 건물 벽: 넓고 단단한 면 → 가까이(약 1.5~3m) 가면 반향으로 희미하게 느껴진다.
	_box(Vector3(-8,2.5,-27), Vector3(1,5,68), "wall", 1.0)
	_box(Vector3(8,2.5,-27), Vector3(1,5,68), "wall", 1.0)
	_box(Vector3(0,2.5,7), Vector3(17,5,1), "wall", 1.0)
	_box(Vector3(0,2.5,-61), Vector3(17,5,1), "wall", 1.0)
	# 공사 가림막: 오른쪽, 왼쪽, 오른쪽에 빈틈.
	_box(Vector3(-2.0,1.1,-12), Vector3(11,2.2,1.0), "barrier", 1.0)
	_box(Vector3(2.0,1.1,-25), Vector3(11,2.2,1.0), "barrier", 1.0)
	_box(Vector3(-2.0,1.1,-38), Vector3(11,2.2,1.0), "barrier", 1.0)
	# 거리 소품: 작아서 반향으로는 거의 알 수 없다. 지팡이에 닿아야 안다.
	for z in [0.0,-7.0,-18.0,-32.0,-46.0,-54.0]:
		_box(Vector3(-6.7,0.65,z), Vector3(1.1,1.3,1.8), "box", 0.4)
		_box(Vector3(6.9,1.6,z-2), Vector3(0.18,3.2,0.18), "pole", 0.0)
		_box(Vector3(6.5,3.15,z-2), Vector3(0.9,0.18,0.4), "", 0.0)
	for z in [-4.0,-20.0,-43.0]:
		_box(Vector3(5.9,0.32,z), Vector3(1.8,0.64,0.6), "bench", 0.3)
		_box(Vector3(6.4,0.95,z), Vector3(0.18,0.65,0.6), "bench", 0.0)
	# 병원 현관 프레임
	_box(Vector3(-2.0,1.8,-58.5), Vector3(0.25,3.6,0.3), "door", 0.2)
	_box(Vector3(2.0,1.8,-58.5), Vector3(0.25,3.6,0.3), "door", 0.2)
	_box(Vector3(0,3.55,-58.5), Vector3(4.25,0.25,0.3), "door", 0.2)
	_box(Vector3(0,4.4,-59), Vector3(0.3,1.4,0.2), "", 0.0, true, false)
	_box(Vector3(0,4.4,-59), Vector3(1.3,0.3,0.2), "", 0.0, true, false)

	# 불편함 1 — 머리 높이 돌출물: 지팡이는 허리 아래만 탐색하므로 닿지 않는다.
	_box(Vector3(-5.85,1.68,-22.0), Vector3(3.3,0.45,0.08), "overhang_sign", 0.0, true, true, true)
	_box(Vector3(5.7,1.56,-41.0), Vector3(3.6,0.10,0.10), "overhang_pipe", 0.0, true, true, true)
	_box(Vector3(5.7,1.56,-41.35), Vector3(3.6,0.10,0.10), "overhang_pipe", 0.0, true, true, true)

	# 불편함 2 — 점자블록: 따라가면 길을 알 수 있지만, 막히고 끊겨 있다.
	var path: Array[Vector2] = [Vector2(0,4.5), Vector2(0,-7), Vector2(4.6,-7), Vector2(4.6,-18.5), Vector2(-5.2,-18.5), Vector2(-5.2,-31.5), Vector2(4.6,-31.5), Vector2(4.6,-44.5), Vector2(0,-44.5), Vector2(0,-56.4)]
	for i in range(path.size() - 1):
		_paving_segment(path[i], path[i+1], i)
	_warning_block(Rect2(-0.6, -57.0, 1.2, 0.6))    # 현관 앞 점형블록
	# 점자블록 위에 세워둔 전동 킥보드
	_box(Vector3(4.6,0.09,-10.5), Vector3(1.1,0.18,0.22), "scooter", 0.0)
	_box(Vector3(4.1,0.65,-10.5), Vector3(0.05,1.0,0.05), "scooter", 0.0)
	_box(Vector3(4.1,1.13,-10.5), Vector3(0.05,0.04,0.5), "scooter", 0.0)

	# 불편함 3 — 공사 발전기 소음: 청각 단서(반향, 안내음)를 덮는다.
	_box(NOISE_POS, Vector3(1.2,1.0,0.8), "generator", 0.5)

	# 바닥 보도블록 줄눈 (50cm). 촉각 전용 — 반향 없음.
	var x := -7.5
	while x <= 7.51:
		_segment(Vector3(x,0.012,5), Vector3(x,0.012,-60))
		x += 0.5
	var z := 5.0
	while z >= -60.01:
		_segment(Vector3(-7.5,0.012,z), Vector3(7.5,0.012,z))
		z -= 0.5

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, edge_material)
	for i in range(line_vertices.size()):
		mesh.surface_set_color(line_colors[i])
		mesh.surface_add_vertex(line_vertices[i])
	mesh.surface_end()
	var outlines := MeshInstance3D.new()
	outlines.mesh = mesh
	outlines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outlines)

	# 지팡이 끝이 닿은 자리 표시 (좌우 번갈아 찍히는 두 점)
	for i in range(8):
		var mark := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.03
		ring.outer_radius = 0.045
		ring.rings = 20
		ring.ring_segments = 6
		mark.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1,1,1,0)
		mark.material_override = mat
		mark.visible = false
		add_child(mark)
		touch_marks.append(mark)
		touch_mark_age.append(99.0)

func _segment(a: Vector3, b: Vector3, reflect: float = 0.0) -> void:
	var c := Color(reflect, 0, 0, 1)
	line_vertices.append(a)
	line_vertices.append(b)
	line_colors.append(c)
	line_colors.append(c)

func _box(center: Vector3, size: Vector3, label: String = "", reflect: float = 0.0, outline: bool = true, collision: bool = true, overhang: bool = false) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = black_material
	visual.position = center
	add_child(visual)
	if collision:
		var solid := StaticBody3D.new()
		solid.position = center
		solid.set_meta("label", label)
		solid.set_meta("overhang", overhang)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		solid.add_child(shape_node)
		add_child(solid)
	if outline:
		var half := size * 0.5 + Vector3.ONE * 0.012
		var corners: Array[Vector3] = []
		for i in range(8):
			corners.append(center + Vector3(half.x if i & 1 else -half.x, half.y if i & 2 else -half.y, half.z if i & 4 else -half.z))
		for i in range(8):
			for bit in [1,2,4]:
				if (i & bit) == 0:
					_segment(corners[i], corners[i | bit], reflect)
		# 넓은 면에는 세로 줄을 그어, 반향이 닿은 '면'의 범위가 드러나게 한다.
		if reflect >= 0.9:
			var lo := center - half
			var hi := center + half
			if size.x >= size.z:
				var px := lo.x + 0.5
				while px < hi.x:
					_segment(Vector3(px, lo.y, lo.z), Vector3(px, hi.y, lo.z), reflect)
					_segment(Vector3(px, lo.y, hi.z), Vector3(px, hi.y, hi.z), reflect)
					px += 0.5
			else:
				var pz := lo.z + 0.5
				while pz < hi.z:
					_segment(Vector3(lo.x, lo.y, pz), Vector3(lo.x, hi.y, pz), reflect)
					_segment(Vector3(hi.x, lo.y, pz), Vector3(hi.x, hi.y, pz), reflect)
					pz += 0.5

func _paving_segment(a: Vector2, b: Vector2, index: int) -> void:
	var w := 0.15
	var rect: Rect2
	if is_equal_approx(a.x, b.x):
		rect = Rect2(a.x - w, minf(a.y, b.y), w * 2, absf(a.y - b.y))
	else:
		rect = Rect2(minf(a.x, b.x), a.y - w, absf(a.x - b.x), w * 2)
	# 공사로 뜯겨 나간 구간: 이 구간의 점자블록은 중간에서 끊긴다.
	if index == 4:
		var cut_from := -27.0
		var cut_to := -30.5
		var first := Rect2(rect.position.x, cut_from, rect.size.x, rect.end.y - cut_from)
		var second := Rect2(rect.position.x, rect.position.y, rect.size.x, cut_to - rect.position.y)
		_paving_rect(first, true)
		_paving_rect(second, true)
	else:
		_paving_rect(rect, is_equal_approx(a.x, b.x))
	if index > 0:
		_warning_block(Rect2(a.x - w, a.y - w, w * 2, w * 2))

func _paving_rect(rect: Rect2, along_z: bool) -> void:
	paving_rects.append(rect)
	var y := 0.022
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	_segment(Vector3(x0,y,z0), Vector3(x1,y,z0))
	_segment(Vector3(x0,y,z1), Vector3(x1,y,z1))
	_segment(Vector3(x0,y,z0), Vector3(x0,y,z1))
	_segment(Vector3(x1,y,z0), Vector3(x1,y,z1))
	# 진행 방향으로 솟은 4줄의 돌기 (선형블록)
	for k in range(4):
		var f := (k + 0.5) / 4.0
		if along_z:
			var bx := lerpf(x0, x1, f)
			_segment(Vector3(bx,y+0.01,z0), Vector3(bx,y+0.01,z1))
		else:
			var bz := lerpf(z0, z1, f)
			_segment(Vector3(x0,y+0.01,bz), Vector3(x1,y+0.01,bz))

func _warning_block(rect: Rect2) -> void:
	warning_rects.append(rect)
	var y := 0.03
	var n := int(rect.size.x / 0.075)
	var m := int(rect.size.y / 0.075)
	for i in range(n):
		for j in range(m):
			var cx := rect.position.x + (i + 0.5) * rect.size.x / n
			var cz := rect.position.y + (j + 0.5) * rect.size.y / m
			_segment(Vector3(cx-0.018,y,cz), Vector3(cx+0.018,y,cz))
			_segment(Vector3(cx,y,cz-0.018), Vector3(cx,y,cz+0.018))

# ---------------------------------------------------------------- player

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0,0.05,3)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.7
	collider.shape = capsule
	collider.position.y = 0.85
	player.add_child(collider)
	add_child(player)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = 78
	camera.near = 0.05
	camera.rotation.x = pitch
	player.add_child(camera)
	camera.current = true
	# 흰 지팡이: 손(몸 중앙)에서 지팡이 끝까지 매 프레임 배치한다.
	cane = MeshInstance3D.new()
	var cane_mesh := CylinderMesh.new()
	cane_mesh.top_radius = 0.011
	cane_mesh.bottom_radius = 0.009
	cane_mesh.height = 1.0
	cane_mesh.radial_segments = 8
	cane_mesh.rings = 1
	cane.mesh = cane_mesh
	var cane_material := StandardMaterial3D.new()
	cane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cane_material.albedo_color = Color(0.62,0.62,0.62)
	cane.material_override = cane_material
	cane.visible = false
	add_child(cane)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR"])
	theme.default_font = font
	theme.default_font_size = 19
	hud.theme = theme
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1,1,1,0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	status = Label.new()
	status.position = Vector2(28,22)
	status.add_theme_color_override("font_color", Color(0.45,0.45,0.45))
	status.add_theme_font_size_override("font_size", 16)
	hud.add_child(status)
	sweep_view = Control.new()
	sweep_view.position = Vector2(28, 56)
	sweep_view.size = Vector2(90, 56)
	sweep_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep_view.draw.connect(_draw_sweep)
	sweep_view.visible = false
	hud.add_child(sweep_view)
	message = Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	message.offset_top = -118
	message.offset_bottom = -24
	message.offset_left = 30
	message.offset_right = -30
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(message)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -300
	panel.offset_bottom = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.018,0.018,0.98)
	style.border_color = Color(0.3,0.3,0.3)
	style.set_border_width_all(1)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 17)
	column.add_child(body)
	action = Button.new()
	action.custom_minimum_size.y = 48
	action.pressed.connect(_on_action)
	column.add_child(action)

# 화면 아래의 작은 도식: 지팡이 호와 지팡이 끝 위치, 지금 내딛는 발
func _draw_sweep() -> void:
	var c := Vector2(45, 34)
	var r := 28.0
	var dim := Color(0.35,0.35,0.35)
	sweep_view.draw_arc(c, r, -PI/2 - SWEEP_ANGLE, -PI/2 + SWEEP_ANGLE, 24, dim, 1.5)
	var a := -PI/2 + sweep * SWEEP_ANGLE
	var tip := c + Vector2(cos(a), sin(a)) * r
	sweep_view.draw_line(c + Vector2(0, 4), tip, dim, 1.0)
	var col := Color(1,1,1) if tip_on_ground else Color(0.55,0.55,0.55)
	if contact:
		col = Color(1.0,0.75,0.4)
	sweep_view.draw_circle(tip, 4.0 if tip_on_ground or contact else 2.5, col)
	# 이점 촉타법: 지팡이 끝과 반대쪽 발이 함께 나간다
	var left_foot := sweep > 0.0
	sweep_view.draw_rect(Rect2(c + Vector2(-12, 6), Vector2(6, 10)), Color(0.8,0.8,0.8) if left_foot else dim, left_foot)
	sweep_view.draw_rect(Rect2(c + Vector2(6, 6), Vector2(6, 10)), Color(0.8,0.8,0.8) if not left_foot else dim, not left_foot)

func _show_intro() -> void:
	title.text = "민들레  /  DANDELION"
	body.text = "밤 11시 47분, 병원에서 전화가 왔다.\n“아버님이 깨어나셨어요. 계속 찾고 계십니다.”\n\n익숙했던 골목은 공사로 길이 바뀌었다.\n흰 지팡이 하나로 병원 현관까지 가야 한다.\n\n· 걸으면 지팡이가 걸음에 맞춰 좌우로 호를 그리며 발 앞 약 1m를 두드립니다.\n· 알 수 있는 것은 지팡이 끝이 닿은 곳과, 가까운 벽에서 돌아오는 희미한 울림뿐입니다.\n· 허리 위 높이의 물체는 지팡이로 알 수 없습니다.\n\nW/S 걷기 · A/D 옆걸음 · 마우스 몸 돌리기 · Shift 서두르기\nSpace 멈춰서 세게 두드리기 · Q 휴대폰 음성 안내 · Esc 일시정지\n\n헤드폰 권장. 실제 감각의 재현이 아닌 허구적 시각화입니다."
	action.text = "전화기를 넣고, 출발한다"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_action() -> void:
	if finished:
		story_page += 1
		if story_page >= 3:
			get_tree().reload_current_scene()
		else:
			_show_ending_page()
		return
	playing = true
	paused = false
	panel.hide()
	cane.visible = true
	sweep_view.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_notify("병원은 골목 끝에 있다. 발밑의 점자블록을 지팡이로 찾아 따라가 보자.", 7)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_game") and (paused or finished):
		get_tree().reload_current_scene()
		return
	if event.is_action_pressed("pause_game") and playing and not finished:
		paused = not paused
		panel.visible = paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
		if paused:
			title.text = "잠시, 숨을 고른다"
			body.text = "W/S 걷기 · A/D 옆걸음 · 마우스 몸 돌리기 · Shift 서두르기\nSpace: 멈춰서 세게 두드리기 (울림이 조금 더 멀리 간다)\nQ: 휴대폰 음성 안내 (골목에서는 GPS 오차가 크다)\n\n· 지팡이 끝은 걸음과 반대쪽을 두드린다. 왼발이 나갈 때 오른쪽.\n· 점자블록의 줄무늬를 따라가면 길이 이어진다. 끊기거나 막힌 곳도 있다.\n· 가림막에 지팡이가 걸리면 가림막을 따라 옆으로 움직이며 빈틈을 찾자.\n· 벽 가까이에서는 울림이 달라진다. 소음 속에서는 그마저 들리지 않는다.\n· 허리 위 돌출물은 지팡이에 닿지 않는다.\n\nEsc: 계속하기 · R: 처음부터 다시 시작"
			action.text = "다시 걷는다"
		return
	if not playing or paused or finished:
		return
	if event is InputEventMouseMotion:
		player.rotation.y -= event.relative.x * SENSITIVITY
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, -1.05, -0.25)
		camera.rotation.x = pitch
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hard_tap()
	if event.is_action_pressed("tap"):
		_hard_tap()
	if event.is_action_pressed("phone"):
		_phone_guide()

# ---------------------------------------------------------------- frame

func _physics_process(delta: float) -> void:
	if not playing or paused or finished:
		return
	clock += delta
	elapsed += delta
	hard_cooldown = maxf(hard_cooldown - delta, 0)
	head_cooldown = maxf(head_cooldown - delta, 0)
	gps_cooldown = maxf(gps_cooldown - delta, 0)
	stun = maxf(stun - delta, 0)
	edge_material.set_shader_parameter("clock", clock)
	message_ttl -= delta
	if message_ttl <= 0:
		message.text = ""

	# 이동: 지팡이 사용자의 평균 보행 속도. 부딪힌 직후에는 잠시 멈춘다.
	var input := Input.get_vector("left", "right", "forward", "back")
	if stun > 0:
		input = Vector2.ZERO
	var direction := player.transform.basis * Vector3(input.x, 0, input.y)
	var speed := SPEED * (SPRINT_MULT if Input.is_action_pressed("sprint") else 1.0)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 20 * delta
	else:
		player.velocity.y = 0
	var before := player.global_position
	player.move_and_slide()
	_check_head_bump()
	var moved := Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length()

	# 걸음 위상: 실제로 이동한 거리만큼 진행한다. 한 걸음 = 지팡이 호 한 번.
	var old_phase := step_phase
	if moved > 0.0005:
		step_phase += moved / STEP_LENGTH
	elif step_phase - floorf(step_phase) > 0.001:
		# 멈추면 지팡이 끝을 다음 쪽 끝까지 마저 내려놓는다.
		step_phase = minf(step_phase + delta * 1.4, ceilf(step_phase))
	var touchdown := floorf(step_phase) > floorf(old_phase)
	_update_cane(touchdown, moved > 0.0005, delta)

	camera.position.y = 1.6 - absf(sin(step_phase * PI)) * 0.018
	if shake > 0:
		shake = maxf(shake - delta, 0)
		camera.position.x = randf_range(-1, 1) * shake * 0.06
		camera.rotation.z = randf_range(-1, 1) * shake * 0.05
	else:
		camera.position.x = 0
		camera.rotation.z = 0
	flash.color.a = maxf(flash.color.a - delta * 1.8, 0)
	_update_marks(delta)
	sweep_view.queue_redraw()

	# 불편함 3: 소음이 반향과 안내음을 덮는다.
	var noise_distance := Vector2(player.global_position.x - NOISE_POS.x, player.global_position.z - NOISE_POS.z).length()
	echo_gain = clampf((noise_distance - 3.0) / 6.5, 0.0, 1.0)
	edge_material.set_shader_parameter("echo_gain", echo_gain)
	if not noise_msg and noise_distance < 7.0:
		noise_msg = true
		_notify("발전기 소리가 골목을 가득 채운다.\n지팡이 소리의 울림도, 병원 안내음도 들리지 않는다. 지팡이 끝의 감각만 남았다.", 8)

	var distance := Vector2(player.position.x - DEST.x, player.position.z - DEST.z).length()
	status.text = "Space 세게 두드리기 · Q 휴대폰 안내 · Esc 도움말"
	beacon_clock += delta
	if beacon_clock > 4.5:
		beacon_clock = 0
		# 소음 근처에서는 안내음이 묻힌다.
		_play_sound(sound_beacon, DEST + Vector3(0,1.5,0), lerpf(-40.0, -8.0, echo_gain), 85)
	gps_clock += delta
	if gps_clock > 15.0:
		_reroll_gps()

	if checkpoint == 0 and player.position.z < -13:
		checkpoint = 1
		_notify("첫 가림막을 지났다. 점자블록이 다시 이어지는지 지팡이로 찾아보자.", 6)
	elif checkpoint == 1 and player.position.z < -26:
		checkpoint = 2
		_notify("전화 속 목소리가 떠오른다. “천천히, 조심해서 오세요.”", 6)
	elif checkpoint == 2 and player.position.z < -39:
		checkpoint = 3
		_notify("멀리 현관 안내음이 들린다. 소리 나는 쪽으로.", 6)
	if distance < 2.1 and player.position.z < -55:
		_finish()

# 지팡이: 몸 중앙의 손에서 좌우로 호를 그리며 발 앞 약 1m를 두드린다.
func _update_cane(touchdown: bool, walking: bool, delta: float) -> void:
	sweep = cos(step_phase * PI)                  # 정수 위상에서 좌/우 끝
	var lift := TIP_LIFT * absf(sin(step_phase * PI))
	var body_basis := player.global_transform.basis
	var hand := player.global_transform * HAND_LOCAL
	var drop := HAND_LOCAL.y - lift
	var reach := sqrt(maxf(CANE_LENGTH * CANE_LENGTH - drop * drop, 0.01))
	var yaw := sweep * SWEEP_ANGLE
	var tip_local := Vector3(HAND_LOCAL.x + sin(yaw) * reach, lift, HAND_LOCAL.z - cos(yaw) * reach)
	var target := player.global_transform * tip_local
	target.y = player.global_position.y + lift
	var dir := (target - hand).normalized()
	var query := PhysicsRayQueryParameters3D.create(hand, target + dir * 0.05, 1, [player.get_rid()])
	query.hit_from_inside = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	var was_contact := contact
	var hit_label := ""
	contact = false
	tip_world = target
	tip_on_ground = lift < 0.004
	if not result.is_empty():
		var point: Vector3 = result["position"]
		var normal: Vector3 = result["normal"]
		var collider: Object = result["collider"]
		if normal.y > 0.7 and point.y < 0.06:
			tip_world = point
			tip_on_ground = true
		else:
			tip_world = point
			contact = true
			tip_on_ground = false
			if collider and collider.has_meta("label"):
				hit_label = str(collider.get_meta("label"))
	_place_cane(hand, tip_world)

	# 장애물에 지팡이가 걸림
	contact_refresh = maxf(contact_refresh - delta, 0)
	if contact and (not was_contact or hit_label != contact_label):
		count_contacts += 1
		contact_label = hit_label
		contact_refresh = 0.45
		_pulse(tip_world, OBSTACLE_TOUCH, ECHO_WALK * 0.6)
		_mark(tip_world)
		_play_sound(sound_knock, tip_world, -9)
		shake = maxf(shake, 0.12)
		_describe_contact(hit_label)
	elif contact and contact_refresh <= 0:
		# 걸린 채로 더듬으면 그 물체의 모양이 조금씩 드러난다.
		contact_refresh = 0.45
		_pulse(tip_world, OBSTACLE_TOUCH, 0.0)
	if not contact:
		contact_label = ""

	# 호를 그리며 지나가는 지팡이 끝이 점자블록 돌기를 스친다.
	var over := ""
	if not contact:
		over = _surface_at(tip_world)
	if over != "" and not tip_over_paving:
		_pulse(tip_world, TOUCH_RADIUS, 0.0)
		_play_sound(sound_paving, tip_world, -12)
		_paving_feedback(over)
	tip_over_paving = over != ""

	# 바닥을 두드림 (한 걸음마다 한 번, 좌우 번갈아)
	if touchdown and not contact:
		_pulse(tip_world, TOUCH_RADIUS, ECHO_WALK)
		_mark(tip_world)
		_play_sound(sound_tap, tip_world, -16)
		if over == "":
			_paving_feedback("")
	if touchdown and walking:
		# in-step: 지팡이 끝 반대쪽 발이 디딘다.
		var side := -1.0 if sweep > 0.0 else 1.0
		_play_sound(sound_step, player.global_position + body_basis.x * side * 0.12, -22)

func _place_cane(hand: Vector3, tip: Vector3) -> void:
	var axis := tip - hand
	var length := axis.length()
	if length < 0.01:
		return
	var y := axis / length
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	cane.global_transform = Transform3D(Basis(x, y * length, z), (hand + tip) * 0.5)

func _check_head_bump() -> void:
	for i in range(player.get_slide_collision_count()):
		var c := player.get_slide_collision(i)
		var collider := c.get_collider()
		if collider and collider.has_meta("overhang") and collider.get_meta("overhang"):
			if head_cooldown > 0:
				return
			head_cooldown = 1.6
			stun = 0.9
			shake = 0.45
			flash.color = Color(1,1,1,0.55)
			count_head += 1
			var p := c.get_position()
			print_verbose("head bump at ", p)
			_pulse(p, HEAD_TOUCH, 0.0)
			_play_sound(sound_thud, p, -2)
			var back := -player.global_transform.basis.z
			player.global_position -= Vector3(back.x, 0, back.z) * 0.12
			var text := "쿵— 이마를 무언가에 부딪혔다. 지팡이에는 아무것도 걸리지 않았는데.\n"
			if str(collider.get_meta("label")) == "overhang_sign":
				text += "벽에서 튀어나온 간판이다. 머리 높이의 돌출물은 지팡이로 알 수 없다."
			else:
				text += "공사용 파이프가 머리 높이로 튀어나와 있다. 몸을 낮추거나 돌아가야 한다."
			_notify(text, 6)
			return

func _surface_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for r in warning_rects:
		if r.grow(0.03).has_point(q):
			return "warning"
	for r in paving_rects:
		if r.grow(0.03).has_point(q):
			return "linear"
	return ""

func _paving_feedback(surface: String) -> void:
	if surface != "":
		off_paving_taps = 0
		if not on_paving_msg:
			on_paving_msg = true
			_notify("지팡이 끝에 길게 솟은 줄무늬가 느껴진다. 점자블록이다. 이 줄을 따라가면 된다.", 6)
		elif surface == "warning" and not was_on_paving:
			_notify("오돌토돌한 점형블록 — 방향이 바뀌거나 무언가 앞에 있다는 표시다.", 4)
		was_on_paving = true
		return
	if was_on_paving:
		off_paving_taps += 1
		if off_paving_taps >= 3:
			was_on_paving = false
			if player.global_position.z < -26.5 and player.global_position.z > -31.5 and not paving_lost_msg:
				paving_lost_msg = true
				_notify("점자블록이 갑자기 끊겼다. 공사하면서 뜯어낸 것 같다.\n여기서부터는 어디로 가야 하지?", 7)
			else:
				_notify("점자블록을 놓쳤다. 좌우로 두드리며 다시 찾아보자.", 3.5)

func _describe_contact(label: String) -> void:
	var now := clock
	var last: float = last_label_time.get(label, -100.0)
	if now - last < 6.0:
		return
	last_label_time[label] = now
	var texts := {
		"barrier": "탁— 넓고 단단한 면이 앞을 막는다. 공사 가림막이다.\n가림막을 따라 옆으로 움직이며 빈틈을 찾자.",
		"wall": "건물 벽이다. 벽을 따라가면 방향을 잃지 않는다.",
		"box": "허리 높이의 묵직한 상자에 걸렸다.",
		"pole": "가느다란 기둥. 조금만 옆이었으면 그냥 지나쳤을 것이다.",
		"bench": "낮고 긴 물체 — 벤치인 것 같다.",
		"scooter": "점자블록 위에 무언가 서 있다… 전동 킥보드다.\n누군가 점자블록 한가운데에 세워 두고 갔다. 돌아가야 한다.",
		"generator": "덜덜 떨리는 쇳덩이. 소리의 정체, 발전기다.",
		"door": "매끈한 기둥. 출입문 틀이다.",
	}
	if texts.has(label):
		_notify(texts[label], 4.5)

# ---------------------------------------------------------------- feedback helpers

func _pulse(pos: Vector3, touch_r: float, echo_r: float) -> void:
	edge_material.set_shader_parameter("pulse%d" % pulse_index, Vector4(pos.x, pos.y, pos.z, clock))
	edge_material.set_shader_parameter("shape%d" % pulse_index, Vector2(touch_r, echo_r))
	pulse_index = (pulse_index + 1) % PULSES

func _mark(pos: Vector3) -> void:
	var m := touch_marks[mark_index]
	m.position = Vector3(pos.x, maxf(pos.y, 0.0) + 0.02, pos.z)
	m.visible = true
	touch_mark_age[mark_index] = 0.0
	mark_index = (mark_index + 1) % touch_marks.size()

func _update_marks(delta: float) -> void:
	for i in range(touch_marks.size()):
		touch_mark_age[i] += delta
		var a := clampf(1.0 - touch_mark_age[i] / 1.2, 0.0, 1.0)
		var mat := touch_marks[i].material_override as StandardMaterial3D
		mat.albedo_color.a = a * 0.8
		touch_marks[i].visible = a > 0.0

# 멈춰서 세게 두드리기: 소리가 커서 반향이 조금 더 멀리 (그래도 약 3m)
func _hard_tap() -> void:
	if hard_cooldown > 0:
		return
	hard_cooldown = 0.6
	var p := tip_world
	_pulse(p, TOUCH_RADIUS, ECHO_HARD)
	_mark(p)
	_play_sound(sound_tap, p + Vector3(0,0.1,0), -5)
	_paving_feedback(_surface_at(p))
	if echo_gain < 0.25:
		_notify("세게 두드려도 소음에 묻혀 울림이 들리지 않는다.", 2.5)

func _reroll_gps() -> void:
	gps_clock = 0.0
	var angle := randf() * TAU
	gps_error = Vector2(cos(angle), sin(angle)) * randf_range(3.0, 9.0)

# 휴대폰 보행 안내: 대략적인 거리와 시계 방향만, 그것도 오차가 있다.
func _phone_guide() -> void:
	if gps_cooldown > 0:
		return
	gps_cooldown = 3.0
	var guess := DEST + Vector3(gps_error.x, 0, gps_error.y)
	var to_goal := guess - player.global_position
	var local_goal := player.global_transform.basis.inverse() * to_goal
	var bearing := rad_to_deg(atan2(local_goal.x, -local_goal.z))
	var hour := int(round(bearing / 30.0))
	if hour <= 0:
		hour += 12
	var meters := int(round(Vector2(to_goal.x, to_goal.z).length() / 5.0) * 5)
	var line := "목적지까지 약 %d미터, %d시 방향입니다." % [maxi(meters, 5), hour]
	_notify("휴대폰 음성 안내: “%s”\n(건물 사이 골목에서는 위치 오차가 수 미터에 이른다)" % line, 5)
	if tts_voice != "":
		DisplayServer.tts_stop()
		DisplayServer.tts_speak(line, tts_voice)

func _find_tts_voice() -> void:
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var voices := DisplayServer.tts_get_voices_for_language("ko")
	if voices.size() > 0:
		tts_voice = voices[0]

func _notify(text: String, duration: float) -> void:
	message.text = text
	message_ttl = duration

func _finish() -> void:
	finished = true
	cane.hide()
	sweep_view.hide()
	status.hide()
	message.hide()
	panel.show()
	if noise_player:
		noise_player.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	story_page = 0
	_show_ending_page()

func _show_ending_page() -> void:
	var titles := ["01  /  도착", "02  /  목소리", "03  /  잔향"]
	var pages := ["현관의 자동문이 열린다.\n\n차가운 밤공기 대신 익숙한 소독약 냄새가 난다.\n걸음을 멈추자, 누군가 다가와 내 이름을 부른다.\n\n“오셨군요. 아버님이 기다리고 계세요.”", "손을 뻗자, 거칠고 따뜻한 손이 잡힌다.\n\n“왔니?”\n“응. 나 왔어.”\n\n오는 길에 하고 싶던 말은 많았는데,\n그 짧은 대답이면 충분했다.", "보이지 않는 길에도, 돌아갈 곳은 있었다.\n\nDANDELION — 끝\n\n걸린 시간  %d분 %02d초\n지팡이에 걸린 장애물  %d번 · 머리를 부딪힌 횟수  %d번\n\n점자블록 위의 킥보드, 머리 높이의 간판, 뜯겨 나간 점자블록,\n안내음을 덮는 소음 — 모두 누군가에게는 매일의 길입니다.\n\n이 작품의 윤곽선은 허구적 시각화입니다." % [int(elapsed)/60, int(elapsed)%60, count_contacts, count_head]]
	title.text = titles[story_page]
	body.text = pages[story_page]
	action.text = "처음부터 다시 걷기" if story_page == 2 else "계속"

# ---------------------------------------------------------------- audio

func _start_noise() -> void:
	noise_player = AudioStreamPlayer3D.new()
	noise_player.stream = sound_noise
	noise_player.position = NOISE_POS + Vector3(0, 0.5, 0)
	noise_player.volume_db = 2.0
	noise_player.unit_size = 3.0
	noise_player.max_distance = 26.0
	add_child(noise_player)
	noise_player.play()

func _play_sound(stream: AudioStreamWAV, point: Vector3, volume: float, max_range: float = 25.0) -> void:
	var speaker := AudioStreamPlayer3D.new()
	speaker.stream = stream
	speaker.position = point
	speaker.volume_db = volume
	speaker.max_distance = max_range
	speaker.unit_size = 6
	add_child(speaker)
	speaker.finished.connect(speaker.queue_free)
	speaker.play()

# kind: 0 지팡이 두드림 · 1 발걸음 · 2 음향신호기 · 3 점자블록 긁힘 · 4 물체에 걸림 · 5 머리 부딪힘 · 6 발전기(반복)
func _make_sound(frequency: float, duration: float, kind: int) -> AudioStreamWAV:
	var rate := 22050
	var count := int(duration * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71 + kind
	var low := 0.0
	for i in range(count):
		var t := float(i) / rate
		var envelope := exp(-t * 30.0)
		var wave := sin(TAU * frequency * t)
		if kind == 0:
			wave = wave * 0.5 + sin(TAU * frequency * 2.7 * t) * 0.2 + rng.randf_range(-1,1) * 0.3
		elif kind == 1:
			wave = rng.randf_range(-1,1) * 0.7 + wave * 0.3
		elif kind == 2:
			# 띵-동 두 음
			var f := frequency if t < 0.25 else frequency * 0.8
			var lt := t if t < 0.25 else t - 0.25
			wave = sin(TAU * f * lt)
			envelope = exp(-lt * 8.0) * minf(lt * 90, 1)
		elif kind == 3:
			# 돌기를 긁는 드르륵
			var click := fmod(t, 0.028) < 0.006
			wave = rng.randf_range(-1,1) * (0.9 if click else 0.15) + sin(TAU * frequency * t) * 0.2
			envelope = exp(-t * 9.0)
		elif kind == 4:
			wave = sin(TAU * frequency * t) * 0.6 + sin(TAU * frequency * 1.6 * t) * 0.3 + rng.randf_range(-1,1) * 0.25
			envelope = exp(-t * 22.0)
		elif kind == 5:
			low = low * 0.9 + rng.randf_range(-1,1) * 0.1
			wave = sin(TAU * frequency * t * (1.0 - t)) * 0.8 + low * 3.0
			envelope = exp(-t * 9.0)
		elif kind == 6:
			low = low * 0.97 + rng.randf_range(-1,1) * 0.03
			wave = sin(TAU * frequency * t) * 0.35 + sin(TAU * frequency * 2.0 * t) * 0.25 + sin(TAU * frequency * 3.0 * t) * 0.12 + low * 4.0 + rng.randf_range(-1,1) * 0.12
			envelope = 1.0
		var sample := int(clampf(wave * envelope * 0.65,-1,1) * 32767)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if kind == 6:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream
