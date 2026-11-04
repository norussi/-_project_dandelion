extends Node3D

# 민들레(Dandelion) — 모드 1: 시각장애인 보행 체험. Godot 4.3+, no external assets.
# 민들레 프로젝트 · 모드 1: 시각장애인 보행 체험
#
# 감각 규칙
#  - 지팡이(긴 지팡이, 1.2m)는 몸 중앙 배꼽 높이에서 잡는다. 마우스 왼쪽 클릭으로 바라보는 곳을 짚는다.
#  - 지팡이 끝이 닿을 수 있는 곳만 짚을 수 있다: 손에서 1.2m 이내, 몸 앞쪽.
#    더 먼 곳을 겨누면 같은 방향의 가장 먼 바닥(발 앞 약 1m)을 짚는다.
#  - 알 수 있는 것: 지팡이 끝이 닿은 곳(반경 수십 cm)과, 두드린 소리가 넓은 면에 반사되는 희미한 울림(약 2m).

const SPEED := 1.15
const SPRINT_MULT := 1.35
const STEP_LENGTH := 0.62
const SENSITIVITY := 0.0022
const DOOR_POS := Vector3(0, 0, -62)         # 병원 현관 (음향 유도기, GPS 목적지)

const CANE_LENGTH := 1.20
const HAND_LOCAL := Vector3(0.10, 0.95, -0.28)   # 배꼽 높이, 몸 중앙에서 약간 오른쪽
const TAP_MIN := 0.40           # 몸에서 지팡이 끝까지 최소 수평거리 (너무 가까우면 짚을 수 없음)
const TAP_MAX_HEIGHT := 1.30    # 지팡이 끝이 닿는 최대 높이
const TAP_COOLDOWN := 0.42

const TOUCH_RADIUS := 0.38
const ECHO_TAP := 2.0
const OBSTACLE_TOUCH := 0.65
const HEAD_TOUCH := 0.75
const PULSES := 6

# v0.3.0: 걸음에 맞춘 자동 좌우 짚기 (v0.1.0의 이점 촉타법)
const SWEEP_ANGLE := 0.47       # 좌우 호 반각 (rad). 끝이 좌우 약 ±0.33m
const TIP_LIFT := 0.035         # 호 가운데에서 지팡이 끝이 뜨는 높이
const ECHO_WALK := 1.6          # 걸으며 가볍게 짚은 소리의 반향 거리
# 웅크리기
const STAND_HEIGHT := 1.7
const CROUCH_HEIGHT := 1.15
const STAND_EYE := 1.6
const CROUCH_EYE := 1.0
const CROUCH_SPEED := 0.55
# 연습(튜토리얼) 구간: 아파트 1층 복도 (x = -60에 따로 있음)
const TUT_X := -60.0
const TUT_BEAM_Z := -9.5
const MAIN_START := Vector3(0, 0.05, 3)
# 도와주는 사람: 병원 밖에서 이 시간 동안 점자블록을 못 찾으면 다가온다
const HELP_DELAY := 60.0

const NOISE_POS := Vector3(6.4, 0.5, -29.5)
const UP_X := 60.0              # 2~5층 공용 공간이 놓인 x 오프셋 (엘리베이터로 순간 이동)
const ROAD_Z0 := -47.0
const ROAD_Z1 := -55.0
const LANES := [-49.0, -53.0]   # 0차로: +x 방향, 1차로: -x 방향
const CAR_SPEED := 9.0
const CAR_HALF := 2.1
const SIGNAL_POLE := Vector3(1.6, 0, -46.6)
const SIGNAL_FAR := Vector3(-1.6, 0, -55.4)
const PED_GREEN := 15.0
const PED_RED := 18.0
const TARGET_FLOOR := 5
const TARGET_ROOM := 3

const BRAILLE_DIGITS := ["⠚", "⠁", "⠃", "⠉", "⠙", "⠑", "⠋", "⠛", "⠓", "⠊"]
const BRAILLE_NUM := "⠼"
const BR_ELEVATOR := "⠝⠂⠐⠕⠘⠝⠕⠓⠎"   # 엘리베이터
const BR_FLOOR := "⠰⠪⠶"               # 층
const BR_OPEN := "⠳⠐⠕⠢"               # 열림
const BR_CLOSE := "⠊⠔⠚⠕⠢"             # 닫힘
const BR_ALARM := "⠘⠕⠇⠶"              # 비상
const BR_UP := "⠍⠗"                   # 위
const BR_DOWN := "⠣⠐⠗"                # 아래
const BR_HO := "⠚⠥"                   # 호

var player: CharacterBody3D
var camera: Camera3D
var edge_material: ShaderMaterial
var black_material: StandardMaterial3D
var pulse_index := 0
var clock := 0.0
var elapsed := 0.0
var beacon_clock := 0.0
var playing := false
var finished := false
var paused := false
var story_page := 0
var flags := {}
var pitch := -0.55
var message_ttl := 0.0
var status: Label
var message: Label
var aim: Label
var panel: PanelContainer
var title: Label
var body: Label
var action: Button
var hud: Control
var flash: ColorRect
var ui_font: Font
var line_vertices := PackedVector3Array()
var line_colors := PackedColorArray()

var sound_tap: AudioStreamWAV
var sound_step: AudioStreamWAV
var sound_beacon: AudioStreamWAV
var sound_knock: AudioStreamWAV
var sound_thud: AudioStreamWAV
var sound_paving: AudioStreamWAV
var sound_noise: AudioStreamWAV
var sound_locator: AudioStreamWAV
var sound_guide: AudioStreamWAV
var sound_engine: AudioStreamWAV
var sound_horn: AudioStreamWAV
var sound_ding: AudioStreamWAV
var sound_click: AudioStreamWAV
var noise_player: AudioStreamPlayer3D

# 지팡이
var cane: MeshInstance3D
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var tap_t := -1.0
var tap_info := {}
var tap_impacted := false
var tap_cooldown := 0.0
var aim_info := {}
var clamp_msg := false
var step_dist := 0.0
var step_left := true
var last_label_time := {}
var touch_marks: Array[MeshInstance3D] = []
var touch_mark_age: Array[float] = []
var mark_index := 0

# 불편함 요소
var paving_rects: Array[Rect2] = []
var warning_rects: Array[Rect2] = []
var on_paving_msg := false
var paving_lost_msg := false
var was_on_paving := false
var off_paving_taps := 0
var head_cooldown := 0.0
var bump_cooldown := 0.0
var stun := 0.0
var shake := 0.0
var echo_gain := 1.0
var gps_error := Vector2.ZERO
var gps_clock := 0.0
var gps_cooldown := 0.0
var count_contacts := 0
var count_head := 0
var count_honk := 0
var tts_voice := ""
var settings_button: Button
var menu_button: Button
var settings_open := false
var skip_button: Button
var fade: ColorRect

# 자동 좌우 짚기
var step_phase := 0.0
var sweep := 1.0
var sweep_over_paving := false
var sweep_contact := false
var sweep_contact_label := ""
var sweep_refresh := 0.0
# 웅크리기
var crouching := false
var crouch_t := 0.0
var player_shape: CapsuleShape3D
var player_collider: CollisionShape3D
# 연습 구간
var tutorial_active := false
var tut_step := 0
var tut_walked := 0.0
var tut_touched_paving := false
var tut_ducked := false
var tut_door_nodes: Array[Node] = []
var tut_exit_open := false
# 도와주는 사람
var no_paving_time := 0.0
var last_paving_pos := Vector3(0, 0.05, 3.2)
var helping := false
var count_help := 0

# 신호등과 차량
var ped_green := false
var sig_clock := 7.0
var sig_requested := false
var sig_warned := false
var locator_clock := 0.0
var guide_clock := 0.0
var cars: Array[Dictionary] = []
var lane_timer: Array[float] = [1.0, 2.5]

# 엘리베이터
var player_floor := 1
var car_floor := 4
var car_queue: Array[int] = []
var car_state := "idle"          # idle, opening, open, closing, moving
var car_timer := 0.0
var car_dir := 0
var door_t := 0.0
var riding := false
var lobby_doors: Array[AnimatableBody3D] = []
var upper_doors: Array[AnimatableBody3D] = []

# 손으로 더듬기 (버튼, 명패)
var interactables: Array[Dictionary] = []
var near_item := {}
var touch_view: Control
var touch_open := false
var touch_kind := ""
var touch_items: Array[Dictionary] = []
var touch_hover := -1
var touch_dwell := 0.0
var touch_title := ""

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
	sound_locator = _make_sound(1900.0, 0.06, 7)
	sound_guide = _make_sound(1050.0, 0.36, 8)
	sound_engine = _make_sound(42.0, 1.0, 9)
	sound_horn = _make_sound(420.0, 0.6, 10)
	sound_ding = _make_sound(1320.0, 1.2, 11)
	sound_click = _make_sound(2400.0, 0.04, 12)
	_start_noise()
	_reroll_gps()
	_find_tts_voice()
	_show_intro()

func _setup_inputs() -> void:
	# 키 설정은 Settings(자동 로드)가 InputMap에 등록한다. 설정 화면에서 바꾸면 바로 반영된다.
	Settings.changed.connect(_apply_settings)


# 키 이름 (설정에서 바꾼 키가 안내 문구에도 나오도록)
func _k(action: String) -> String:
	return Settings.key(action)


func _apply_settings() -> void:
	if camera:
		camera.fov = Settings.fov
	if hud and hud.theme:
		hud.theme.default_font_size = Settings.font_size(19)
		status.add_theme_font_size_override("font_size", Settings.font_size(16))
		title.add_theme_font_size_override("font_size", Settings.font_size(34))
		body.add_theme_font_size_override("font_size", Settings.font_size(17))
	if paused and not finished:
		_show_pause_text()

func _setup_materials() -> void:
	black_material = StandardMaterial3D.new()
	black_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black_material.albedo_color = Color.BLACK
	edge_material = ShaderMaterial.new()
	edge_material.shader = load("res://stages/visual_walk/echo.gdshader")
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.environment = environment
	add_child(env)

# ================================================================ world

func _build_world() -> void:
	_box(Vector3(20,-0.25,-30), Vector3(140,0.5,100), "", 0.0, false)

	# --- 골목 (z 7 ~ -47)
	_box(Vector3(-8,2.5,-20), Vector3(1,5,54), "wall", 1.0)
	_box(Vector3(8,2.5,-20), Vector3(1,5,54), "wall", 1.0)
	_box(Vector3(0,2.5,7), Vector3(17,5,1), "wall", 1.0)
	_box(Vector3(-2.0,1.1,-12), Vector3(11,2.2,1.0), "barrier", 1.0)
	_box(Vector3(2.0,1.1,-25), Vector3(11,2.2,1.0), "barrier", 1.0)
	_box(Vector3(-2.0,1.1,-38), Vector3(11,2.2,1.0), "barrier", 1.0)
	for z in [0.0,-7.0,-18.0,-32.0,-44.0]:
		_box(Vector3(-6.7,0.65,z), Vector3(1.1,1.3,1.8), "box", 0.4)
		_box(Vector3(6.9,1.6,z-2), Vector3(0.18,3.2,0.18), "pole", 0.0)
		_box(Vector3(6.5,3.15,z-2), Vector3(0.9,0.18,0.4), "", 0.0)
	for z in [-4.0,-20.0,-43.0]:
		_box(Vector3(5.9,0.32,z), Vector3(1.8,0.64,0.6), "bench", 0.3)
		_box(Vector3(6.4,0.95,z), Vector3(0.18,0.65,0.6), "bench", 0.0)
	# 머리 높이 돌출물
	_box(Vector3(-5.85,1.68,-22.0), Vector3(3.3,0.45,0.08), "overhang_sign", 0.0, true, true, true)
	_box(Vector3(5.7,1.56,-41.0), Vector3(3.6,0.10,0.10), "overhang_pipe", 0.0, true, true, true)
	_box(Vector3(5.7,1.56,-41.35), Vector3(3.6,0.10,0.10), "overhang_pipe", 0.0, true, true, true)
	# 점자블록 위 킥보드, 발전기
	_box(Vector3(4.6,0.09,-10.5), Vector3(1.1,0.18,0.22), "scooter", 0.0)
	_box(Vector3(4.1,0.65,-10.5), Vector3(0.05,1.0,0.05), "scooter", 0.0)
	_box(Vector3(4.1,1.13,-10.5), Vector3(0.05,0.04,0.5), "scooter", 0.0)
	_box(NOISE_POS, Vector3(1.2,1.0,0.8), "generator", 0.5)

	# --- 차도와 횡단보도 (z -47 ~ -55, x -30 ~ 30)
	for sx in [-1.0, 1.0]:
		_box(Vector3(19.25*sx,2.5,-46.5), Vector3(21.5,5,1), "wall", 1.0)
		_box(Vector3(19.25*sx,2.5,-55.5), Vector3(21.5,5,1), "wall", 1.0)
		_box(Vector3(30.5*sx,2.5,-51), Vector3(1,5,10), "wall", 1.0)
	# 연석 (손끝으로 느껴지는 턱). 횡단보도의 흰 칠은 지팡이로 알 수 없으므로 그리지 않는다.
	for cz in [ROAD_Z0, ROAD_Z1]:
		var inner: float = cz + (0.15 if cz == ROAD_Z0 else -0.15)
		_segment(Vector3(-30,0.03,cz), Vector3(30,0.03,cz))
		_segment(Vector3(-30,0.03,inner), Vector3(30,0.03,inner))
	# 음향신호기 기둥 (이쪽 / 건너편)
	for p in [SIGNAL_POLE, SIGNAL_FAR]:
		_box(p + Vector3(0,1.6,0), Vector3(0.12,3.2,0.12), "signal_pole", 0.0)
		_box(p + Vector3(0,3.1,0), Vector3(0.3,0.6,0.25), "", 0.0, true, false)
	_box(SIGNAL_POLE + Vector3(0,1.1,0.12), Vector3(0.18,0.26,0.12), "", 0.0, true, false)
	_box(SIGNAL_FAR + Vector3(0,1.1,-0.12), Vector3(0.18,0.26,0.12), "", 0.0, true, false)
	interactables.append({"pos": SIGNAL_POLE + Vector3(0,0,0.15), "r": 1.3, "kind": "signal", "hint": "음향신호기 버튼 누르기"})

	# --- 병원 앞 보도 (z -55 ~ -62)와 로비 (z -63 ~ -75)
	_box(Vector3(-8,2.5,-65.5), Vector3(1,5,21), "wall", 1.0)
	_box(Vector3(8,2.5,-65.5), Vector3(1,5,21), "wall", 1.0)
	_box(Vector3(-4.5,2.5,-62.5), Vector3(6,5,1), "facade", 1.0)
	_box(Vector3(4.5,2.5,-62.5), Vector3(6,5,1), "facade", 1.0)
	_box(Vector3(0,3.75,-62.5), Vector3(3,2.5,1), "facade", 1.0)
	_box(Vector3(-1.45,1.25,-62.0), Vector3(0.12,2.5,0.12), "door", 0.2)
	_box(Vector3(1.45,1.25,-62.0), Vector3(0.12,2.5,0.12), "door", 0.2)
	_box(Vector3(0,4.4,-61.9), Vector3(0.3,1.4,0.2), "", 0.0, true, false)
	_box(Vector3(0,4.4,-61.9), Vector3(1.3,0.3,0.2), "", 0.0, true, false)
	_box(Vector3(-4.5,0.55,-68.0), Vector3(2.4,1.1,0.8), "desk", 0.5)
	_box(Vector3(5.5,0.23,-66.0), Vector3(2.0,0.46,0.6), "bench", 0.3)
	_build_elevator_hall(0.0, true)

	# --- 2~5층 복도 (모든 위층이 같은 구조, x = UP_X)
	_box(Vector3(UP_X-2.5,2.5,-67), Vector3(1,5,17), "wall", 1.0)
	_box(Vector3(UP_X+2.5,2.5,-67), Vector3(1,5,17), "wall", 1.0)
	_box(Vector3(UP_X,2.5,-58.5), Vector3(6,5,1), "wall", 1.0)
	_box(Vector3(UP_X-1.95,0.9,-67.5), Vector3(0.06,0.06,13.0), "rail", 0.0)
	_build_elevator_hall(UP_X, false)
	_room_door(Vector3(UP_X-1.97,1.05,-70.0), true, 1, Vector3(UP_X-1.95,1.45,-69.2))
	_room_door(Vector3(UP_X+1.97,1.05,-66.0), true, 2, Vector3(UP_X+1.95,1.45,-65.2))
	_room_door(Vector3(UP_X,1.05,-59.03), false, 3, Vector3(UP_X+0.85,1.45,-59.05))

	_build_tutorial()

	# --- 점자블록
	var path: Array[Vector2] = [Vector2(0,4.5), Vector2(0,-7), Vector2(4.6,-7), Vector2(4.6,-18.5), Vector2(-5.2,-18.5), Vector2(-5.2,-31.5), Vector2(4.6,-31.5), Vector2(4.6,-44.5), Vector2(0,-44.5), Vector2(0,-46.35)]
	for i in range(path.size() - 1):
		_paving_segment(path[i], path[i+1], i)
	_warning_block(Rect2(-0.6, -46.95, 1.2, 0.6))     # 횡단보도 앞 (이쪽)
	_warning_block(Rect2(-0.6, -55.65, 1.2, 0.6))     # 횡단보도 앞 (건너편)
	_paving_rect(Rect2(-0.15, -61.3, 0.3, 5.65), true)
	_warning_block(Rect2(-0.6, -61.9, 1.2, 0.6))      # 현관 앞
	_paving_rect(Rect2(-0.15, -74.25, 0.3, 11.1), true)
	_warning_block(Rect2(-0.6, -74.85, 1.2, 0.6))     # 엘리베이터 앞

	# --- 바닥 줄눈 (촉각 전용). 차도 아스팔트에는 줄눈이 없다.
	_grid(-7.5, 7.5, 6.5, -47.0, 0.5)
	_grid(-7.5, 7.5, -55.0, -62.0, 0.5)
	_grid(-7.5, 7.5, -63.0, -75.0, 0.6)
	_grid(UP_X-2.0, UP_X+2.0, -59.0, -75.0, 0.6)

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

	# 조준 표시: 지팡이 끝이 실제로 닿을 자리
	marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.06
	ring.outer_radius = 0.08
	ring.rings = 24
	ring.ring_segments = 6
	marker.mesh = ring
	marker_material = StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(0.55,0.55,0.55)
	marker.material_override = marker_material
	marker.visible = false
	add_child(marker)

	for i in range(8):
		var mark := MeshInstance3D.new()
		var r := TorusMesh.new()
		r.inner_radius = 0.03
		r.outer_radius = 0.045
		r.rings = 20
		r.ring_segments = 6
		mark.mesh = r
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1,1,1,0)
		mark.material_override = mat
		mark.visible = false
		add_child(mark)
		touch_marks.append(mark)
		touch_mark_age.append(99.0)

# 엘리베이터 홀: 뒷벽(문 개구부), 엘리베이터 칸, 미닫이 문 2짝, 호출 버튼, 칸 안 버튼판
func _build_elevator_hall(ox: float, lobby: bool) -> void:
	var half := 8.0 if lobby else 3.0
	var piece := half - 1.1
	_box(Vector3(ox - 1.1 - piece * 0.5,2.5,-75.5), Vector3(piece,5,1), "wall", 1.0)
	_box(Vector3(ox + 1.1 + piece * 0.5,2.5,-75.5), Vector3(piece,5,1), "wall", 1.0)
	_box(Vector3(ox,3.7,-75.5), Vector3(2.2,2.6,1), "wall", 1.0)
	# 칸 내부
	_box(Vector3(ox-1.2,1.2,-76.65), Vector3(0.1,2.4,3.3), "elev_wall", 0.8)
	_box(Vector3(ox+1.2,1.2,-76.65), Vector3(0.1,2.4,3.3), "elev_wall", 0.8)
	_box(Vector3(ox,1.2,-78.35), Vector3(2.5,2.4,0.1), "elev_wall", 0.8)
	_box(Vector3(ox,0.9,-78.27), Vector3(1.8,0.05,0.05), "", 0.0, true, false)     # 손잡이
	_box(Vector3(ox+1.13,1.1,-75.7), Vector3(0.04,0.55,0.28), "", 0.0, true, false) # 칸 안 버튼판
	_box(Vector3(ox+1.6,1.1,-74.98), Vector3(0.22,0.34,0.04), "", 0.0, true, false) # 호출 버튼
	_grid(ox-1.1, ox+1.1, -75.0, -78.3, 0.3)
	for side in [-1.0, 1.0]:
		var door := AnimatableBody3D.new()
		door.sync_to_physics = false
		door.set_meta("label", "elev_door")
		door.set_meta("overhang", false)
		door.set_meta("side", side)
		door.set_meta("ox", ox)
		door.position = Vector3(ox + side * 0.55, 1.1, -75.03)
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.1, 2.2, 0.06)
		shape_node.shape = shape
		door.add_child(shape_node)
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.1, 2.2, 0.06)
		vis.mesh = bm
		vis.material_override = black_material
		door.add_child(vis)
		door.add_child(_outline_mesh([[Vector3.ZERO, Vector3(1.1,2.2,0.06)]], 0.8))
		add_child(door)
		if lobby:
			lobby_doors.append(door)
		else:
			upper_doors.append(door)
	var tag := "lobby" if lobby else "upper"
	interactables.append({"pos": Vector3(ox+1.6,0,-74.8), "r": 1.35, "kind": "call_" + tag, "hint": "엘리베이터 호출 버튼 더듬기"})
	interactables.append({"pos": Vector3(ox+0.9,0,-75.8), "r": 0.95, "kind": "car_" + tag, "hint": "엘리베이터 버튼판 더듬기", "inside": ox})

func _room_door(center: Vector3, on_side_wall: bool, room: int, plate: Vector3) -> void:
	var size := Vector3(0.06, 2.1, 1.0) if on_side_wall else Vector3(1.0, 2.1, 0.06)
	_box(center, size, "room_door", 0.3)
	_box(plate, Vector3(0.03,0.12,0.22) if on_side_wall else Vector3(0.22,0.12,0.03), "", 0.0, true, false)
	interactables.append({"pos": Vector3(plate.x, 0, plate.z), "r": 1.35, "kind": "plate", "room": room, "hint": "문 옆 명패 더듬기"})

func _grid(x0: float, x1: float, z0: float, z1: float, step: float) -> void:
	var x := x0
	while x <= x1 + 0.001:
		_segment(Vector3(x,0.012,z0), Vector3(x,0.012,z1))
		x += step
	var z := z0
	while z >= z1 - 0.001:
		_segment(Vector3(x0,0.012,z), Vector3(x1,0.012,z))
		z -= step

func _segment(a: Vector3, b: Vector3, reflect: float = 0.0) -> void:
	var c := Color(reflect, 0, 0, 1)
	line_vertices.append(a)
	line_vertices.append(b)
	line_colors.append(c)
	line_colors.append(c)

func _box_edges(center: Vector3, size: Vector3, reflect: float, verts: PackedVector3Array, colors: PackedColorArray, hatch: bool) -> void:
	var c := Color(reflect, 0, 0, 1)
	var half := size * 0.5 + Vector3.ONE * 0.012
	var corners: Array[Vector3] = []
	for i in range(8):
		corners.append(center + Vector3(half.x if i & 1 else -half.x, half.y if i & 2 else -half.y, half.z if i & 4 else -half.z))
	for i in range(8):
		for bit in [1,2,4]:
			if (i & bit) == 0:
				verts.append(corners[i])
				verts.append(corners[i | bit])
				colors.append(c)
				colors.append(c)
	# 넓은 면에는 세로 줄 — 반향이 닿은 '면'의 범위가 드러나게 한다.
	if hatch:
		var lo := center - half
		var hi := center + half
		if size.x >= size.z:
			var px := lo.x + 0.5
			while px < hi.x:
				for zz in [lo.z, hi.z]:
					verts.append(Vector3(px, lo.y, zz))
					verts.append(Vector3(px, hi.y, zz))
					colors.append(c)
					colors.append(c)
				px += 0.5
		else:
			var pz := lo.z + 0.5
			while pz < hi.z:
				for xx in [lo.x, hi.x]:
					verts.append(Vector3(xx, lo.y, pz))
					verts.append(Vector3(xx, hi.y, pz))
					colors.append(c)
					colors.append(c)
				pz += 0.5

func _outline_mesh(boxes: Array, reflect: float) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for b in boxes:
		_box_edges(b[0], b[1], reflect, verts, colors, false)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, edge_material)
	for i in range(verts.size()):
		mesh.surface_set_color(colors[i])
		mesh.surface_add_vertex(verts[i])
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

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
		_box_edges(center, size, reflect, line_vertices, line_colors, reflect >= 0.9)

func _paving_segment(a: Vector2, b: Vector2, index: int) -> void:
	var w := 0.15
	var rect: Rect2
	if is_equal_approx(a.x, b.x):
		rect = Rect2(a.x - w, minf(a.y, b.y), w * 2, absf(a.y - b.y))
	else:
		rect = Rect2(minf(a.x, b.x), a.y - w, absf(a.x - b.x), w * 2)
	if index == 4:
		# 공사로 뜯겨 나간 구간
		var cut_from := -27.0
		var cut_to := -30.5
		_paving_rect(Rect2(rect.position.x, cut_from, rect.size.x, rect.end.y - cut_from), true)
		_paving_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, cut_to - rect.position.y), true)
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

# ================================================================ player & UI

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0,0.05,3)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = STAND_HEIGHT
	collider.shape = capsule
	collider.position.y = STAND_HEIGHT * 0.5
	player.add_child(collider)
	player_shape = capsule
	player_collider = collider
	add_child(player)
	camera = Camera3D.new()
	camera.position.y = 1.6
	camera.fov = Settings.fov
	camera.near = 0.05
	camera.rotation.x = pitch
	player.add_child(camera)
	camera.current = true
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
	theme.default_font_size = Settings.font_size(19)
	hud.theme = theme
	ui_font = font
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1,1,1,0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)
	status = Label.new()
	status.position = Vector2(28,22)
	status.add_theme_color_override("font_color", Color(0.45,0.45,0.45))
	status.add_theme_font_size_override("font_size", Settings.font_size(16))
	hud.add_child(status)
	aim = Label.new()
	aim.text = "+"
	aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aim.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim.position -= Vector2(10,15)
	aim.size = Vector2(20,30)
	aim.visible = false
	hud.add_child(aim)
	message = Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	message.offset_top = -130
	message.offset_bottom = -24
	message.offset_left = 30
	message.offset_right = -30
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(message)
	touch_view = Control.new()
	touch_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_view.mouse_filter = Control.MOUSE_FILTER_STOP
	touch_view.draw.connect(_draw_touch)
	touch_view.gui_input.connect(_on_touch_input)
	touch_view.visible = false
	hud.add_child(touch_view)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -410
	panel.offset_right = 410
	panel.offset_top = -315
	panel.offset_bottom = 315
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018,0.018,0.018,0.98)
	style.border_color = Color(0.3,0.3,0.3)
	style.set_border_width_all(1)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	title = Label.new()
	title.add_theme_font_size_override("font_size", Settings.font_size(34))
	column.add_child(title)
	var body_scroll := ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(body_scroll)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", Settings.font_size(17))
	body_scroll.add_child(body)
	# 아래 버튼 줄: [주 행동] [설정] [메인 메뉴]
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	action = Button.new()
	action.custom_minimum_size.y = 48
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.pressed.connect(_on_action)
	buttons.add_child(action)
	skip_button = Button.new()
	skip_button.text = "연습 건너뛰기"
	skip_button.custom_minimum_size = Vector2(140, 48)
	skip_button.pressed.connect(_on_skip)
	buttons.add_child(skip_button)
	settings_button = Button.new()
	settings_button.text = "설정"
	settings_button.custom_minimum_size = Vector2(110, 48)
	settings_button.pressed.connect(_open_settings)
	buttons.add_child(settings_button)
	menu_button = Button.new()
	menu_button.text = "메인 메뉴"
	menu_button.custom_minimum_size = Vector2(130, 48)
	menu_button.pressed.connect(func(): Game.goto_main_menu())
	buttons.add_child(menu_button)

func _show_intro() -> void:
	title.text = "민들레  /  DANDELION"
	body.text = ("밤 11시 47분, 병원에서 전화가 왔다.\n“아버님이 깨어나셨어요. 5층 503호에서 계속 찾고 계십니다.”\n\n"
		+ "익숙했던 골목은 공사로 길이 바뀌었다. 큰길의 횡단보도도 건너야 한다.\n흰 지팡이 하나로 병원 503호까지 가야 한다.\n\n"
		+ "· 걸으면 지팡이가 걸음에 맞춰 좌우를 번갈아 짚는다. %s로 바라보는 곳을 직접 짚어 확인할 수도 있다.\n" % _k("cane_tap")
		+ "· 알 수 있는 것은 지팡이 끝이 닿은 곳과, 가까운 벽에서 돌아오는 희미한 울림뿐.\n"
		+ "· 허리 위 물체는 지팡이로 알 수 없다. 머리 높이에 무언가 있으면 %s를 누른 채 몸을 낮추자.\n\n" % _k("crouch")
		+ _controls_line() + "\n\n"
		+ "처음이라면 집 앞 복도에서 짧은 연습부터 시작하자. (약 2분)\n"
		+ "헤드폰 권장. 실제 감각의 재현이 아닌 허구적 시각화입니다.")
	action.text = "연습부터 시작하기"
	skip_button.text = "바로 출발"
	skip_button.visible = true
	settings_button.visible = true
	menu_button.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _controls_line() -> String:
	return ("%s/%s 걷기 · %s/%s 옆걸음 · 마우스 몸 돌리기/숙이기 · %s 서두르기 · %s 웅크리기\n" % [_k("forward"), _k("back"), _k("left"), _k("right"), _k("sprint"), _k("crouch")]
		+ "%s 짚기 · %s 발 앞 짚기 · %s 손으로 더듬기 · %s 휴대폰 안내 · %s 일시정지" % [_k("cane_tap"), _k("tap"), _k("interact"), _k("phone"), _k("pause_game")])


func _show_pause_text() -> void:
	title.text = "잠시, 숨을 고른다"
	body.text = (_controls_line() + "\n"
		+ "%s: 바라보는 곳 짚기 (손에서 1.2m 이내) · %s: 발 앞 짚기\n" % [_k("cane_tap"), _k("tap")]
		+ "%s: 누르고 있는 동안 몸을 낮춘다 (머리 높이 돌출물 피하기)\n" % _k("crouch")
		+ "%s: 손으로 더듬기 (신호기 버튼, 엘리베이터 버튼, 문 옆 명패)\n" % _k("interact")
		+ "%s: 휴대폰 음성 안내 (골목에서는 오차가 크다)\n\n" % _k("phone")
		+ "· 걸으면 지팡이가 걸음에 맞춰 좌우를 번갈아 짚는다. (설정에서 끌 수 있다)\n"
		+ "· 점자블록의 줄무늬를 따라가면 길이 이어진다. 끊기거나 막힌 곳도 있다.\n"
		+ "· 점자블록을 오래 찾지 못하면 지나가던 사람이 도움을 청해 온다.\n"
		+ "· 큰길: 기둥의 ‘딱, 딱’ 위치 알림음을 찾아 버튼을 누르고, 녹색 신호 안내를 기다리자.\n"
		+ "  녹색 신호 동안 건너편 기둥에서 유도음이 난다.\n"
		+ "· 엘리베이터 버튼 위에는 점자가 있다. 버튼 위를 천천히 훑으면 읽을 수 있다.\n\n"
		+ "%s: 계속하기 · %s: 처음부터 다시 시작" % [_k("pause_game"), _k("restart_game")])
	action.text = "다시 걷는다"
	skip_button.text = "연습 건너뛰기"
	skip_button.visible = tutorial_active
	settings_button.visible = true
	menu_button.visible = true


func _open_settings() -> void:
	if settings_open:
		return
	settings_open = true
	panel.hide()
	var menu: Control = preload("res://menu/settings_menu.gd").new()
	menu.closed.connect(func():
		settings_open = false
		panel.show()
		if paused and not finished:
			_show_pause_text()
		elif not playing:
			_show_intro())
	hud.add_child(menu)


func _on_action() -> void:
	if finished:
		story_page += 1
		if story_page >= 4:
			get_tree().reload_current_scene()
		else:
			_show_ending_page()
		return
	if playing:
		_resume()
		return
	_begin(true)


func _resume() -> void:
	paused = false
	panel.hide()
	message.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _begin(with_tutorial: bool) -> void:
	playing = true
	paused = false
	panel.hide()
	message.visible = true
	cane.visible = true
	aim.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if with_tutorial:
		_start_tutorial()
	else:
		_start_main(false)


func _on_skip() -> void:
	if not playing:
		_begin(false)
	elif tutorial_active:
		_resume()
		_start_main(false)

func _unhandled_input(event: InputEvent) -> void:
	if settings_open:
		return
	if event.is_action_pressed("restart_game") and (paused or finished):
		get_tree().reload_current_scene()
		return
	if touch_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("pause_game"):
			_close_touch()
		return
	if event.is_action_pressed("pause_game") and playing and not finished:
		paused = not paused
		panel.visible = paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
		# 일시정지 중에는 하단 안내 문구를 숨겨 패널 뒤로 겹치지 않게 한다
		message.visible = not paused
		if paused:
			_show_pause_text()
		return
	if not playing or paused or finished:
		return
	if event is InputEventMouseMotion:
		var sens := Settings.mouse_sensitivity
		var dy: float = -event.relative.y if Settings.invert_y else event.relative.y
		player.rotation.y -= event.relative.x * sens
		pitch = clampf(pitch - dy * sens, -1.35, 0.35)
		camera.rotation.x = pitch
	if helping:
		return
	if event.is_action_pressed("cane_tap"):
		_start_tap(aim_info)
	if event.is_action_pressed("tap"):
		_start_tap(_cane_target(true))
	if event.is_action_pressed("phone"):
		_phone_guide()
	if event.is_action_pressed("interact"):
		_interact()

# ================================================================ frame

func _physics_process(delta: float) -> void:
	if not playing or paused or finished:
		return
	clock += delta
	elapsed += delta
	tap_cooldown = maxf(tap_cooldown - delta, 0)
	head_cooldown = maxf(head_cooldown - delta, 0)
	bump_cooldown = maxf(bump_cooldown - delta, 0)
	gps_cooldown = maxf(gps_cooldown - delta, 0)
	stun = maxf(stun - delta, 0)
	edge_material.set_shader_parameter("clock", clock)
	message_ttl -= delta
	if message_ttl <= 0:
		message.text = ""

	_update_crouch(delta)
	var input := Input.get_vector("left", "right", "forward", "back")
	if stun > 0 or touch_open or helping:
		input = Vector2.ZERO
	var direction := player.transform.basis * Vector3(input.x, 0, input.y)
	var speed := SPEED * (SPRINT_MULT if Input.is_action_pressed("sprint") and crouch_t < 0.5 else 1.0)
	speed *= lerpf(1.0, CROUCH_SPEED, crouch_t)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor():
		player.velocity.y -= 20 * delta
	else:
		player.velocity.y = 0
	var before := player.global_position
	player.move_and_slide()
	_check_collisions()
	var moved := Vector2(player.global_position.x - before.x, player.global_position.z - before.z).length()
	# 걸음 위상: 실제로 이동한 거리만큼 진행한다. 한 걸음 = 지팡이 짚기 한 번 (이점 촉타법)
	var old_phase := step_phase
	if moved > 0.0005:
		step_phase += moved / STEP_LENGTH
	elif step_phase - floorf(step_phase) > 0.001:
		step_phase = minf(step_phase + delta * 1.4, ceilf(step_phase))  # 멈추면 끝까지 마저 내려놓는다
	var touchdown := floorf(step_phase) > floorf(old_phase)
	if touchdown and moved > 0.0005:
		# in-step: 지팡이 끝 반대쪽 발이 디딘다
		var cane_right := cos(floorf(step_phase) * PI) > 0.0
		_play_sound(sound_step, player.global_position + player.global_transform.basis.x * (-0.12 if cane_right else 0.12), -22)
	if tutorial_active:
		tut_walked += moved
	var eye := lerpf(STAND_EYE, CROUCH_EYE, crouch_t)
	camera.position.y = eye - absf(sin(step_phase * PI)) * 0.016 * minf(moved * 60.0, 1.0)

	_update_cane(delta, touchdown)
	if shake > 0:
		shake = maxf(shake - delta, 0)
		var fx := 1.0 if Settings.screen_effects else 0.0
		camera.position.x = randf_range(-1, 1) * shake * 0.06 * fx
		camera.rotation.z = randf_range(-1, 1) * shake * 0.05 * fx
	else:
		camera.position.x = 0
		camera.rotation.z = 0
	flash.color.a = maxf(flash.color.a - delta * 1.8, 0)
	if not Settings.screen_effects:
		flash.color.a = 0.0
	aim.modulate.a = 1.0 if Settings.show_aim else 0.0
	_update_marks(delta)

	_signal_process(delta)
	_cars_process(delta)
	_elevator_process(delta)
	_update_near_item()

	# 소음(발전기, 지나가는 차)이 반향을 덮는다.
	var noise_distance := Vector2(player.global_position.x - NOISE_POS.x, player.global_position.z - NOISE_POS.z).length()
	echo_gain = clampf((noise_distance - 3.0) / 6.5, 0.0, 1.0)
	for car in cars:
		var cb: AnimatableBody3D = car["body"]
		var cd := Vector2(player.global_position.x - cb.position.x, player.global_position.z - cb.position.z).length()
		echo_gain = minf(echo_gain, clampf((cd - 2.5) / 6.0, 0.0, 1.0))
	edge_material.set_shader_parameter("echo_gain", echo_gain)

	var hint := ""
	if not near_item.is_empty():
		hint = _k("interact") + "  " + str(near_item["hint"]) + "   ·   "
	if tutorial_active:
		hint = "연습 %d/5   ·   " % mini(tut_step + 1, 5) + hint
	status.text = hint + "%s 짚기 · %s 웅크리기 · %s 휴대폰 · %s 도움말" % [_k("cane_tap"), _k("crouch"), _k("phone"), _k("pause_game")]

	var outside := player.global_position.z > -62.5 and player.global_position.x < 40.0 and not tutorial_active
	beacon_clock += delta
	if beacon_clock > 4.5 and outside:
		beacon_clock = 0
		_play_sound(sound_beacon, DOOR_POS + Vector3(0,2.4,0), lerpf(-40.0, -8.0, echo_gain), 85)
	gps_clock += delta
	if gps_clock > 15.0:
		_reroll_gps()
	_story_checkpoints(noise_distance)
	if tutorial_active:
		_tutorial_process()
	else:
		_help_process(delta)

func _story_checkpoints(noise_distance: float) -> void:
	var p := player.global_position
	if p.x > 40.0 or tutorial_active:
		return
	if _once("gate1", p.z < -13):
		_notify("첫 가림막을 지났다. 점자블록이 다시 이어지는지 지팡이로 찾아보자.", 6)
	elif _once("gate2", p.z < -26):
		_notify("전화 속 목소리가 떠오른다. “천천히, 조심해서 오세요.”", 6)
	elif _once("noise", noise_distance < 7.0):
		_notify("발전기 소리가 골목을 가득 채운다.\n지팡이 소리의 울림도, 병원 안내음도 들리지 않는다. 지팡이 끝의 감각만 남았다.", 8)
	elif _once("road", p.z < -43.0):
		_notify("차 소리가 왼쪽과 오른쪽에서 지나간다. 큰길이다.\n‘딱, 딱’ — 신호기 기둥의 위치 알림음을 찾아가 버튼을 누르자 (%s)." % _k("interact"), 8)
	elif _once("crossed", p.z < -55.6):
		_notify("건넜다. 병원 현관의 안내음이 바로 앞에서 들린다.", 5)
	elif _once("lobby", p.z < -63.2):
		_notify("자동문이 열린다. 병원 로비. 밤이라 안내 데스크는 비어 있다.\n바닥의 점자블록이 안쪽으로 이어진다. 엘리베이터를 찾아 5층으로.", 8)

func _once(key: String, condition: bool) -> bool:
	if condition and not flags.has(key):
		flags[key] = true
		return true
	return false

# ================================================================ cane

func _hand() -> Vector3:
	# 웅크리면 손(배꼽) 높이도 내려간다
	return player.global_transform * Vector3(HAND_LOCAL.x, lerpf(HAND_LOCAL.y, 0.62, crouch_t), HAND_LOCAL.z)

# 지팡이 끝이 닿을 곳: 조준점이 지팡이 길이 안이면 그곳, 아니면 같은 방향의 가장 먼 바닥.
func _cane_target(straight_ahead: bool) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var hand := _hand()
	var floor_y := player.global_position.y
	var forward := -player.global_transform.basis.z
	var flat := Vector3(forward.x, 0, forward.z).normalized()
	var reach_h := sqrt(maxf(CANE_LENGTH * CANE_LENGTH - (hand.y - floor_y) * (hand.y - floor_y), 0.01))
	var point := Vector3.ZERO
	var exact := false
	if not straight_ahead:
		var from := camera.global_position
		var fwd := -camera.global_transform.basis.z
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * 4.0, 1, [player.get_rid()])
		var r := space.intersect_ray(q)
		var want_h := reach_h
		if not r.is_empty():
			var hit: Vector3 = r["position"]
			var local := player.global_transform.affine_inverse() * hit
			if hit.distance_to(hand) <= CANE_LENGTH and -local.z >= TAP_MIN and hit.y <= TAP_MAX_HEIGHT:
				point = hit
				exact = true
			else:
				want_h = Vector2(hit.x - hand.x, hit.z - hand.z).length()
		if not exact:
			var h := clampf(want_h, TAP_MIN - absf(HAND_LOCAL.z), reach_h)
			point = Vector3(hand.x, floor_y, hand.z) + flat * h
	else:
		point = Vector3(hand.x, floor_y, hand.z) + flat * reach_h * 0.92
		exact = true
	# 손에서 지팡이 끝까지 사이에 무언가 있으면 거기에 걸린다.
	var dir := (point - hand).normalized()
	var q2 := PhysicsRayQueryParameters3D.create(hand, point + dir * 0.05, 1, [player.get_rid()])
	q2.hit_from_inside = true
	var r2 := space.intersect_ray(q2)
	var collider: Object = null
	var normal := Vector3.UP
	if not r2.is_empty():
		point = r2["position"]
		normal = r2["normal"]
		collider = r2["collider"]
	return {"point": point, "exact": exact, "collider": collider, "normal": normal}

func _start_tap(info: Dictionary) -> void:
	if info.is_empty() or tap_cooldown > 0 or touch_open:
		return
	tap_cooldown = TAP_COOLDOWN
	tap_info = info
	tap_t = 0.0
	tap_impacted = false
	if not info["exact"] and not clamp_msg:
		clamp_msg = true
		_notify("지팡이(1.2m)가 닿지 않는 곳이다. 지팡이 끝은 발 앞 약 1m까지만 닿는다.", 4)

func _rest_tip(hand: Vector3) -> Vector3:
	var target := player.global_transform * Vector3(HAND_LOCAL.x + 0.08, 0.05, HAND_LOCAL.z - 0.66)
	target.y = player.global_position.y + 0.05
	var dir := (target - hand).normalized()
	var q := PhysicsRayQueryParameters3D.create(hand, target + dir * 0.03, 1, [player.get_rid()])
	q.hit_from_inside = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		return r["position"]
	return target

func _update_cane(delta: float, touchdown: bool) -> void:
	var hand := _hand()
	# 걸을 때는 걸음에 맞춰 좌우를 짚고(자동), 클릭하면 그 동작 위에 직접 짚기가 끼어든다.
	var rest := _sweep_tip(hand, touchdown, delta) if Settings.auto_sweep else _rest_tip(hand)
	aim_info = {} if (touch_open or helping) else _cane_target(false)
	marker.visible = not aim_info.is_empty() and tap_t < 0
	if marker.visible:
		var mp: Vector3 = aim_info["point"]
		var n: Vector3 = aim_info["normal"]
		marker.position = mp + n * 0.02
		if absf(n.y) > 0.7 or n.length_squared() < 0.25:
			marker.rotation = Vector3.ZERO
		else:
			marker.look_at(mp + n * 2.0, Vector3.UP)
			marker.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		marker_material.albedo_color = Color(0.75,0.75,0.75) if aim_info["exact"] else Color(0.35,0.35,0.35)
		aim.modulate = Color.WHITE if aim_info["exact"] else Color(0.4,0.4,0.4)
	var tip := rest
	if tap_t >= 0.0:
		tap_t += delta
		var out_t := 0.11
		var hold_t := 0.08
		var back_t := 0.24
		var target: Vector3 = tap_info["point"]
		if tap_t < out_t:
			tip = rest.lerp(target, smoothstep(0.0, 1.0, tap_t / out_t))
		elif tap_t < out_t + hold_t:
			tip = target
		elif tap_t < out_t + hold_t + back_t:
			tip = target.lerp(rest, smoothstep(0.0, 1.0, (tap_t - out_t - hold_t) / back_t))
		else:
			tap_t = -1.0
		if not tap_impacted and tap_t >= out_t:
			tap_impacted = true
			_cane_impact(tap_info)
	_place_cane(hand, tip)

func _cane_impact(info: Dictionary) -> void:
	var p: Vector3 = info["point"]
	var n: Vector3 = info["normal"]
	var collider: Object = info["collider"]
	var label := ""
	if collider and collider.has_meta("label"):
		label = str(collider.get_meta("label"))
	_mark(p)
	if n.y > 0.7 and p.y < 0.06:
		_pulse(p, TOUCH_RADIUS, ECHO_TAP)
		var surface := _surface_at(p)
		if surface != "":
			_play_sound(sound_paving, p, -10)
			_touched_paving(p)
		else:
			_play_sound(sound_tap, p + Vector3(0,0.05,0), -9)
		_paving_feedback(surface)
		if surface == "" and p.z < ROAD_Z0 + 0.05 and p.z > ROAD_Z1 - 0.05 and absf(p.x) < 30.0:
			_once_notify("asphalt", "매끈한 아스팔트. 횡단보도의 흰 칠은 지팡이로 느낄 수 없다.\n방향은 신호기 소리로 잡아야 한다.", 5)
	else:
		count_contacts += 1
		_pulse(p, OBSTACLE_TOUCH, ECHO_TAP * 0.7)
		_play_sound(sound_knock, p, -8)
		shake = maxf(shake, 0.08)
		_describe_contact(label, "")

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

# 몸으로 부딪힘: 머리 높이 돌출물, 또는 짚지 않고 걸어서 몸에 닿은 물체
func _check_collisions() -> void:
	for i in range(player.get_slide_collision_count()):
		var c := player.get_slide_collision(i)
		var collider := c.get_collider()
		if collider == null or not collider.has_meta("label"):
			continue
		var label := str(collider.get_meta("label"))
		var p := c.get_position()
		if collider.get_meta("overhang"):
			if head_cooldown > 0:
				return
			head_cooldown = 1.6
			stun = 0.9
			shake = 0.45
			flash.color = Color(1,1,1,0.55)
			count_head += 1
			_pulse(p, HEAD_TOUCH, 0.0)
			_play_sound(sound_thud, p, -2)
			var back := -player.global_transform.basis.z
			player.global_position -= Vector3(back.x, 0, back.z) * 0.12
			var text := "쿵— 이마를 무언가에 부딪혔다.\n"
			if label == "overhang_sign":
				text += "벽에서 튀어나온 간판이다. 머리 높이의 돌출물은 지팡이로 알 수 없다.\n%s를 누른 채 몸을 낮추면 아래로 지나갈 수 있다." % _k("crouch")
			elif label == "tut_beam":
				text += "복도 천장에서 내려온 배관이다. %s를 누른 채 몸을 낮춰 지나가 보자." % _k("crouch")
			else:
				text += "공사용 파이프가 머리 높이로 튀어나와 있다. %s를 누른 채 몸을 낮추거나 돌아가야 한다." % _k("crouch")
			_notify(text, 6)
			return
		if label != "" and absf(c.get_normal().y) < 0.5 and bump_cooldown <= 0:
			bump_cooldown = 1.4
			shake = maxf(shake, 0.2)
			_pulse(p, OBSTACLE_TOUCH, 0.0)
			_play_sound(sound_thud, p, -14)
			_describe_contact(label, "몸에 부딪혔다 — ")
			return

func _surface_at(p: Vector3) -> String:
	var q := Vector2(p.x, p.z)
	for r in warning_rects:
		if r.grow(0.04).has_point(q):
			return "warning"
	for r in paving_rects:
		if r.grow(0.04).has_point(q):
			return "linear"
	return ""

func _paving_feedback(surface: String) -> void:
	var p := player.global_position
	if surface != "":
		off_paving_taps = 0
		if not on_paving_msg:
			on_paving_msg = true
			_notify("지팡이 끝에 길게 솟은 줄무늬가 느껴진다. 점자블록이다. 이 줄을 따라가면 된다.", 6)
		elif surface == "warning":
			if p.z < -45.5 and p.z > -47.5:
				_notify("오돌토돌한 점형블록 — 여기서 길이 끝난다. 앞은 차도다.", 4)
			elif p.z < -73.0:
				_notify("점형블록 — 엘리베이터 앞이다. 문 오른쪽 벽에 호출 버튼이 있다.", 4)
			else:
				_notify("오돌토돌한 점형블록 — 방향이 바뀌거나 무언가 앞에 있다는 표시다.", 4)
		was_on_paving = true
		return
	if was_on_paving:
		off_paving_taps += 1
		if off_paving_taps >= 3:
			was_on_paving = false
			if p.z < -26.5 and p.z > -31.5 and not paving_lost_msg:
				paving_lost_msg = true
				_notify("점자블록이 갑자기 끊겼다. 공사하면서 뜯어낸 것 같다.\n여기서부터는 어디로 가야 하지?", 7)
			elif p.z > -46.0:
				_notify("점자블록을 놓쳤다. 좌우를 짚으며 다시 찾아보자.", 3.5)

func _describe_contact(label: String, prefix: String) -> void:
	var last: float = last_label_time.get(label, -100.0)
	if clock - last < 6.0:
		return
	last_label_time[label] = clock
	var texts := {
		"barrier": "탁— 넓고 단단한 면이 앞을 막는다. 공사 가림막이다.\n가림막을 따라 옆으로 짚어 가며 빈틈을 찾자.",
		"wall": "건물 벽이다. 벽을 따라가면 방향을 잃지 않는다.",
		"box": "허리 높이의 묵직한 상자다.",
		"pole": "가느다란 기둥. 조금만 옆이었으면 그냥 지나쳤을 것이다.",
		"bench": "낮고 긴 물체 — 벤치인 것 같다.",
		"scooter": "점자블록 위에 무언가 서 있다… 전동 킥보드다.\n누군가 점자블록 한가운데에 세워 두고 갔다. 돌아가야 한다.",
		"generator": "덜덜 떨리는 쇳덩이. 소리의 정체, 발전기다.",
		"door": "매끈한 기둥. 출입문 틀이다.",
		"facade": "병원 건물 외벽이다. 입구는 가운데에 있다.",
		"car": "매끈하고 차가운 철판 — 자동차다! 지금 차도 위에 서 있다.",
		"signal_pole": "가느다란 금속 기둥, 허리 높이에 상자가 달려 있다. 음향신호기다. (%s: 버튼 누르기)" % _k("interact"),
		"desk": "높은 탁자 — 안내 데스크. 밤이라 아무도 없다.",
		"elev_wall": "매끈한 금속 벽. 엘리베이터 안이다. 문 쪽 오른쪽 벽에 버튼판이 있다.",
		"elev_door": "가운데가 갈라진 금속 문 — 엘리베이터 문이다. 문 오른쪽 벽에 호출 버튼이 있다.",
		"room_door": "문이다. 문 옆 명패에 점자가 있을지도 모른다. (%s)" % _k("interact"),
		"rail": "벽을 따라 이어진 손잡이. 따라가면 복도 끝까지 갈 수 있다.",
		"home_door": "우리 집 현관문이다. 이제 출발이다.",
		"tut_door": "유리문 — 공동현관이다. 오른쪽 벽에 열림 버튼이 있다. (%s)" % _k("interact"),
	}
	if texts.has(label):
		_notify(prefix + str(texts[label]), 4.5)
	elif prefix != "":
		_notify(prefix + "무언가 단단한 것.", 2.5)

func _once_notify(key: String, text: String, duration: float) -> void:
	if not flags.has(key):
		flags[key] = true
		_notify(text, duration)

# ================================================================ traffic signal & cars

func _signal_process(delta: float) -> void:
	var p := player.global_position
	var near_road := p.x < 40.0 and p.z < -38.0 and p.z > -62.0
	sig_clock -= delta
	if sig_clock <= 0.0:
		ped_green = not ped_green
		sig_clock = PED_GREEN if ped_green else PED_RED
		sig_warned = false
		if ped_green and near_road:
			if sig_requested or p.distance_to(SIGNAL_POLE) < 6.0:
				_say("녹색 신호입니다. 건너가십시오.", 5)
			sig_requested = false
		elif not ped_green and near_road and p.z < ROAD_Z0 and p.z > ROAD_Z1:
			_notify("신호가 바뀌었다! 차들이 출발한다.", 4)
	if ped_green and not sig_warned and sig_clock < 5.0 and near_road:
		sig_warned = true
		if p.distance_to(SIGNAL_POLE) < 6.0 or (p.z < ROAD_Z0 and p.z > ROAD_Z1):
			_say("신호가 곧 바뀝니다.", 3)
	# 위치 알림음: 기둥을 찾을 수 있도록 일정하게 '딱, 딱'
	locator_clock += delta
	if locator_clock > 1.3 and near_road and p.z > -47.5:
		locator_clock = 0.0
		_play_sound(sound_locator, SIGNAL_POLE + Vector3(0,1.2,0), -10, 20)
	# 녹색 동안 건너편 기둥에서 유도음
	guide_clock += delta
	if ped_green and near_road and guide_clock > 0.75:
		guide_clock = 0.0
		_play_sound(sound_guide, SIGNAL_FAR + Vector3(0,1.4,0), -6, 30)

func _press_signal() -> void:
	_play_sound(sound_click, SIGNAL_POLE + Vector3(0,1.1,0), -6)
	if ped_green:
		_say("녹색 신호입니다. 남은 시간 %d초. 건너가십시오." % int(sig_clock), 5)
	else:
		sig_requested = true
		_say("빨간 신호입니다. 잠시 기다려 주십시오. 신호가 바뀌면 안내해 드리겠습니다.", 6)
	_once_notify("arrow", "버튼 상자 윗면의 튀어나온 화살표가 건너는 방향(앞)을 가리킨다.", 4)

func _cars_process(delta: float) -> void:
	# 차량 신호(= 보행자 빨간불)일 때 양쪽 차로에서 차가 온다.
	for lane in range(2):
		lane_timer[lane] -= delta
		if lane_timer[lane] <= 0.0:
			lane_timer[lane] = randf_range(2.6, 5.5)
			if not ped_green and sig_clock > 4.0 and cars.size() < 8:
				_spawn_car(lane)
	var p := player.global_position
	for car in cars.duplicate():
		var b: AnimatableBody3D = car["body"]
		var dir: float = car["dir"]
		var lane_z: float = car["lane"]
		var front_s := b.position.x * dir + CAR_HALF
		var limit_s := 1000.0
		var stop_s := -3.0      # 횡단보도(x -2~2) 앞 정지선
		# 보행 녹색 3초 전부터(황색) 정지선 앞의 차는 멈춘다 — 녹색이 되면 교차로가 비어 있도록.
		var must_stop := ped_green or sig_clock < 3.0
		if must_stop and front_s <= stop_s + 0.05:
			limit_s = minf(limit_s, stop_s)
		# 앞차와 간격
		for other in cars:
			if other == car or float(other["lane"]) != lane_z:
				continue
			var ob: AnimatableBody3D = other["body"]
			var other_rear: float = ob.position.x * dir - CAR_HALF
			if other_rear > front_s - 0.1:
				limit_s = minf(limit_s, other_rear - 1.5)
		# 차로 위의 사람: 달리던 차가 사람 때문에 급히 멈출 때만 경적을 울린다.
		var in_lane := absf(p.z - lane_z) < 1.4 and p.x < 40.0
		var player_s := p.x * dir
		var honk_now := false
		if in_lane and player_s - front_s > -1.0 and player_s - front_s < 7.0:
			if limit_s > front_s + 0.3:
				honk_now = true
			limit_s = minf(limit_s, player_s - 1.8)
		var new_front := minf(front_s + CAR_SPEED * delta, maxf(limit_s, front_s))
		b.position.x = (new_front - CAR_HALF) * dir
		var engine: AudioStreamPlayer3D = car["engine"]
		var was_moving: bool = car.get("moving", true)
		car["moving"] = new_front - front_s > 0.001
		engine.volume_db = -4.0 if car["moving"] else -14.0
		if honk_now and not car["honked"] and was_moving:
			car["honked"] = true
			count_honk += 1
			_play_sound(sound_horn, b.position + Vector3(0,1,0), 2)
			shake = maxf(shake, 0.3)
			_notify("빠앙—! 바로 옆에서 차가 급히 멈췄다.\n" + ("신호를 기다리지 않고 건넜다." if not ped_green else "차가 정지선을 넘어 들어와 있었다."), 5)
		elif not honk_now:
			car["honked"] = false
		if b.position.x * dir > 34.0:
			b.queue_free()
			cars.erase(car)

func _spawn_car(lane: int) -> void:
	var dir := 1.0 if lane == 0 else -1.0
	var lane_z: float = LANES[lane]
	var b := AnimatableBody3D.new()
	b.sync_to_physics = false
	b.set_meta("label", "car")
	b.set_meta("overhang", false)
	b.position = Vector3(-34.0 * dir, 0, lane_z)
	var parts := [[Vector3(0,0.55,0), Vector3(4.2,0.8,1.8)], [Vector3(-0.3*dir,1.25,0), Vector3(2.2,0.6,1.6)]]
	for part in parts:
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		vis.mesh = bm
		vis.position = part[0]
		vis.material_override = black_material
		b.add_child(vis)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.2, 1.5, 1.8)
	shape_node.shape = shape
	shape_node.position.y = 0.75
	b.add_child(shape_node)
	b.add_child(_outline_mesh(parts, 0.8))
	var engine := AudioStreamPlayer3D.new()
	engine.stream = sound_engine
	engine.volume_db = -4.0
	engine.unit_size = 4.0
	engine.max_distance = 40.0
	engine.position.y = 0.6
	b.add_child(engine)
	add_child(b)
	engine.play()
	cars.append({"body": b, "dir": dir, "lane": lane_z, "honked": false, "engine": engine})

# ================================================================ elevator

func _car_location_x(floor_no: int) -> float:
	return 0.0 if floor_no == 1 else UP_X

func _player_in_car() -> bool:
	var ox := _car_location_x(player_floor)
	var p := player.global_position
	return absf(p.x - ox) < 1.15 and p.z < -75.25 and p.z > -78.3

func _in_doorway() -> bool:
	if car_floor != player_floor:
		return false
	var ox := _car_location_x(player_floor)
	var p := player.global_position
	return absf(p.x - ox) < 0.85 and p.z < -74.4 and p.z > -75.7

func _elevator_process(delta: float) -> void:
	match car_state:
		"idle":
			if car_queue.size() > 0:
				if car_queue[0] == car_floor:
					car_queue.pop_front()
					_open_doors(false)
				else:
					_depart()
		"opening":
			door_t = minf(door_t + delta / 0.9, 1.0)
			if door_t >= 1.0:
				car_state = "open"
				car_timer = 5.0
		"open":
			car_timer -= delta
			if _in_doorway():
				car_timer = maxf(car_timer, 2.0)
			if car_timer <= 0.0:
				car_state = "closing"
				if _player_in_car():
					_say("문이 닫힙니다.", 2)
		"closing":
			if _in_doorway():
				car_state = "opening"
			else:
				door_t = maxf(door_t - delta / 0.9, 0.0)
				if door_t <= 0.0:
					car_state = "idle"
		"moving":
			car_timer -= delta
			if car_timer <= 0.0:
				car_floor += car_dir
				if car_queue.size() > 0 and car_floor == car_queue[0]:
					_arrive()
				else:
					car_timer = 2.0
	_update_doors()

func _depart() -> void:
	var target := car_queue[0]
	car_dir = 1 if target > car_floor else -1
	riding = _player_in_car() and car_floor == player_floor
	car_state = "moving"
	car_timer = 2.0
	if riding:
		_say("올라갑니다." if car_dir > 0 else "내려갑니다.", 2.5)

func _arrive() -> void:
	car_queue.pop_front()
	var announce := riding
	if riding:
		var from_x := _car_location_x(player_floor)
		player_floor = car_floor
		var to_x := _car_location_x(player_floor)
		player.global_position.x += to_x - from_x
		riding = false
	_open_doors(announce)

func _open_doors(announce: bool) -> void:
	car_state = "opening"
	if car_floor != player_floor:
		return
	var at := Vector3(_car_location_x(car_floor), 2.2, -75.2)
	# 올라가는 칸은 한 번, 내려가는 칸은 두 번 울린다.
	_play_sound(sound_ding, at, -6)
	if car_dir < 0:
		get_tree().create_timer(0.4).timeout.connect(func(): _play_sound(sound_ding, at, -6))
	if announce or _player_in_car():
		_say("%d층입니다. 문이 열립니다." % car_floor, 3.5)
	else:
		_notify("띵— 엘리베이터 문이 열리는 소리.", 3)

func _update_doors() -> void:
	var open_lobby := door_t if car_floor == 1 and car_state != "moving" else 0.0
	var open_upper := door_t if car_floor == player_floor and player_floor > 1 and car_state != "moving" else 0.0
	for d in lobby_doors:
		_set_door(d, open_lobby)
	for d in upper_doors:
		_set_door(d, open_upper)

func _set_door(d: AnimatableBody3D, amount: float) -> void:
	var side: float = d.get_meta("side")
	var ox: float = d.get_meta("ox")
	d.position.x = ox + side * (0.55 + 1.05 * amount)

func _call_elevator(going_up: bool) -> void:
	_play_sound(sound_click, Vector3(_car_location_x(player_floor) + 1.6, 1.1, -75.0), -6)
	if car_floor == player_floor and car_state != "moving":
		if car_state == "idle" or car_state == "closing":
			car_dir = 1 if going_up else -1
			_open_doors(false)
		else:
			car_timer = maxf(car_timer, 4.0)
		return
	if not car_queue.has(player_floor):
		car_queue.append(player_floor)
	_notify("버튼을 눌렀다. 엘리베이터가 오는 소리를 기다린다…", 3)

func _car_button(id: String) -> void:
	_play_sound(sound_click, player.global_position + Vector3(0.5, 1.1, 0), -8)
	if id.begins_with("floor"):
		var n := int(id.substr(5))
		if n == car_floor and car_state != "moving":
			if car_state == "closing" or car_state == "idle":
				_open_doors(false)
		elif not car_queue.has(n):
			car_queue.append(n)
	elif id == "open":
		if car_state == "closing" or (car_state == "idle" and car_floor == player_floor):
			car_state = "opening"
		elif car_state == "open":
			car_timer = maxf(car_timer, 5.0)
	elif id == "close":
		if car_state == "open":
			car_timer = 0.0
	elif id == "alarm":
		_say("관리실입니다. 무슨 일이신가요? …괜찮으시면 원하는 층 버튼을 눌러 주세요.", 5)

# ================================================================ hands: buttons & plates

func _update_near_item() -> void:
	near_item = {}
	var p := player.global_position
	var best := 99.0
	for item in interactables:
		var ip: Vector3 = item["pos"]
		var d := Vector2(p.x - ip.x, p.z - ip.z).length()
		if d > float(item["r"]) or d > best:
			continue
		if item.has("inside"):
			if not _player_in_car() or absf(_car_location_x(player_floor) - float(item["inside"])) > 1.0:
				continue
		elif str(item["kind"]).begins_with("call") and _player_in_car():
			continue
		best = d
		near_item = item

func _interact() -> void:
	if near_item.is_empty():
		_notify("손을 뻗어 보지만 아무것도 닿지 않는다.", 2)
		return
	var kind := str(near_item["kind"])
	if kind == "tut_door":
		_tut_press_door()
	elif kind == "signal":
		_press_signal()
	elif kind.begins_with("call"):
		_open_touch("call", near_item)
	elif kind.begins_with("car"):
		_open_touch("car", near_item)
	elif kind == "plate":
		_open_touch("plate", near_item)

func _num_braille(n: int) -> String:
	var s := BRAILLE_NUM
	for ch in str(n):
		s += BRAILLE_DIGITS[int(ch)]
	return s

func _open_touch(kind: String, item: Dictionary) -> void:
	touch_open = true
	touch_kind = kind
	touch_items.clear()
	touch_hover = -1
	touch_dwell = 0.0
	var c := Vector2(640, 350)
	if kind == "call":
		touch_title = "엘리베이터 호출 버튼"
		touch_items.append({"pos": c + Vector2(-90, -150), "braille": BR_ELEVATOR, "text": "엘리베이터", "id": ""})
		touch_items.append({"pos": c + Vector2(-40, -105), "braille": _num_braille(player_floor) + BR_FLOOR, "text": "%d층" % player_floor, "id": ""})
		if player_floor < 5:
			touch_items.append({"pos": c + Vector2(0, -10), "braille": BR_UP, "text": "위 (올라가기) ▲", "id": "up", "button": true})
		if player_floor > 1:
			touch_items.append({"pos": c + Vector2(0, 110), "braille": BR_DOWN, "text": "아래 (내려가기) ▼", "id": "down", "button": true})
	elif kind == "car":
		touch_title = "엘리베이터 안 버튼판"
		var floors := [[5, Vector2(-55, -160)], [3, Vector2(-55, -78)], [4, Vector2(55, -78)], [1, Vector2(-55, 4)], [2, Vector2(55, 4)]]
		for f in floors:
			touch_items.append({"pos": c + f[1], "braille": _num_braille(f[0]), "text": "%d층" % f[0], "id": "floor%d" % f[0], "button": true})
		touch_items.append({"pos": c + Vector2(-55, 86), "braille": BR_OPEN, "text": "열림 ◀▶", "id": "open", "button": true})
		touch_items.append({"pos": c + Vector2(55, 86), "braille": BR_CLOSE, "text": "닫힘 ▶◀", "id": "close", "button": true})
		touch_items.append({"pos": c + Vector2(0, 166), "braille": BR_ALARM, "text": "비상 호출 (관리실 연결)", "id": "alarm", "button": true})
	elif kind == "plate":
		var room: int = item["room"]
		var number := player_floor * 100 + room
		touch_title = "문 옆 명패"
		# 숫자 뒤에 ‘ㅎ’으로 시작하는 글자가 오면 숫자 0(⠚)과 헷갈리지 않도록 띄어 쓴다.
		touch_items.append({"pos": c + Vector2(0, -60), "braille": _num_braille(number) + "⠀" + BR_HO, "text": "%d호" % number, "id": "plate", "room": room})
		touch_items.append({"pos": c + Vector2(0, 90), "braille": "", "text": "문 두드리기", "id": "knock", "button": true, "room": room})
	touch_view.visible = true
	message.text = ""
	aim.visible = false
	marker.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch_view.queue_redraw()

func _close_touch() -> void:
	touch_open = false
	touch_view.visible = false
	aim.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _item_rect(item: Dictionary) -> Rect2:
	var pos: Vector2 = item["pos"]
	var w := maxf(str(item["braille"]).length() * 22.0, 60.0)
	if item.get("button", false):
		var bw := maxf(w, 80.0)
		return Rect2(pos - Vector2(bw * 0.5, 66), Vector2(bw, 96))
	return Rect2(pos - Vector2(w * 0.5, 22), Vector2(w, 44))

func _hover_at(pos: Vector2) -> void:
	var hover := -1
	for i in range(touch_items.size()):
		if _item_rect(touch_items[i]).has_point(pos):
			hover = i
	if hover != touch_hover:
		touch_hover = hover
		touch_dwell = 0.0
		if hover >= 0:
			_play_sound(sound_click, player.global_position + Vector3(0, 1.1, -0.4), -30)

func _press_touch() -> void:
	if touch_hover < 0:
		return
	var item: Dictionary = touch_items[touch_hover]
	if not item.get("button", false):
		return
	var id := str(item["id"])
	if touch_kind == "call":
		_call_elevator(id == "up")
		_close_touch()
	elif touch_kind == "car":
		_car_button(id)
	elif touch_kind == "plate":
		_knock(int(item["room"]))

func _on_touch_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hover_at(event.position)
		_press_touch()

func _process(delta: float) -> void:
	if touch_open:
		touch_dwell += delta
		touch_view.queue_redraw()

func _draw_braille(origin: Vector2, text: String, alpha: float) -> void:
	var x := origin.x
	for i in range(text.length()):
		var code := text.unicode_at(i) - 0x2800
		for dot in range(6):
			var col := 0 if dot < 3 else 1
			var row := dot % 3
			var pos := Vector2(x + col * 8.0, origin.y + row * 8.0)
			if code >= 0 and code < 256 and (code >> dot) & 1:
				touch_view.draw_circle(pos, 2.9, Color(1, 1, 1, alpha))
			else:
				touch_view.draw_circle(pos, 1.2, Color(1, 1, 1, alpha * 0.18))
		x += 22.0

func _draw_touch() -> void:
	var c := Vector2(640, 350)
	touch_view.draw_rect(Rect2(c - Vector2(230, 270), Vector2(460, 520)), Color(0.02, 0.02, 0.02, 0.93))
	touch_view.draw_rect(Rect2(c - Vector2(230, 270), Vector2(460, 520)), Color(0.25, 0.25, 0.25), false, 1.0)
	touch_view.draw_string(ui_font, c + Vector2(-210, -244), "손끝으로 더듬기 — " + touch_title, HORIZONTAL_ALIGNMENT_LEFT, 420, 18, Color(0.6, 0.6, 0.6))
	for i in range(touch_items.size()):
		var item: Dictionary = touch_items[i]
		var pos: Vector2 = item["pos"]
		var hovered := i == touch_hover
		var br := str(item["braille"])
		var bw := br.length() * 22.0 - 14.0
		var is_button: bool = item.get("button", false)
		var braille_y := pos.y - 56.0 if is_button else pos.y - 8.0
		if br != "":
			_draw_braille(Vector2(pos.x - bw * 0.5, braille_y), br, 1.0 if hovered else 0.10)
		if is_button:
			touch_view.draw_circle(pos, 26.0, Color(0.12, 0.12, 0.12) if hovered else Color(0.06, 0.06, 0.06))
			touch_view.draw_arc(pos, 26.0, 0, TAU, 32, Color(0.8, 0.8, 0.8) if hovered else Color(0.22, 0.22, 0.22), 1.5)
	if touch_hover >= 0:
		var item: Dictionary = touch_items[touch_hover]
		var reading := "손끝이 점자를 읽는 중…"
		if touch_dwell > 0.45 or str(item["braille"]) == "":
			if str(item["braille"]) != "":
				reading = "점자 " + str(item["braille"]) + "   →   " + str(item["text"])
			else:
				reading = str(item["text"])
		touch_view.draw_string(ui_font, c + Vector2(-210, 226), reading, HORIZONTAL_ALIGNMENT_CENTER, 420, 20, Color(1, 1, 1))
	touch_view.draw_string(ui_font, c + Vector2(-210, -224), "마우스로 천천히 훑어 점자 읽기 · 클릭: 누르기 · %s / %s: 손 떼기" % [_k("interact"), _k("pause_game")], HORIZONTAL_ALIGNMENT_LEFT, 420, 13, Color(0.42, 0.42, 0.42))

func _knock(room: int) -> void:
	_play_sound(sound_knock, player.global_position + Vector3(0, 1.3, -0.6), -2)
	if player_floor == TARGET_FLOOR and room == TARGET_ROOM:
		_close_touch()
		_notify("똑, 똑.\n“들어오세요.”", 3)
		get_tree().create_timer(2.2).timeout.connect(_finish)
	else:
		_notify("똑, 똑… 대답이 없다. %d호. 여기가 아니다." % (player_floor * 100 + room), 3.5)

# ================================================================ feedback helpers

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

func _reroll_gps() -> void:
	gps_clock = 0.0
	var angle := randf() * TAU
	gps_error = Vector2(cos(angle), sin(angle)) * randf_range(3.0, 9.0)

func _phone_guide() -> void:
	if gps_cooldown > 0:
		return
	gps_cooldown = 3.0
	if tutorial_active:
		var tline := "현재 위치는 집 앞입니다. 목적지까지 약 70미터, 12시 방향입니다."
		_notify("휴대폰 음성 안내: “%s”\n(실제 휴대폰 보행 안내처럼 대략적인 거리와 시계 방향으로만 알려 준다)" % tline, 6)
		_speak(tline)
		if tut_step == 3:
			get_tree().create_timer(2.5).timeout.connect(func(): _tut_advance(4))
		return
	if player.global_position.z < -62.5 or player.global_position.x > 40.0:
		_say("실내에서는 위치 안내를 할 수 없습니다.", 3)
		return
	var guess := DOOR_POS + Vector3(gps_error.x, 0, gps_error.y)
	var to_goal := guess - player.global_position
	var local_goal := player.global_transform.basis.inverse() * to_goal
	var bearing := rad_to_deg(atan2(local_goal.x, -local_goal.z))
	var hour := int(round(bearing / 30.0))
	if hour <= 0:
		hour += 12
	var meters := int(round(Vector2(to_goal.x, to_goal.z).length() / 5.0) * 5)
	var line := "목적지까지 약 %d미터, %d시 방향입니다." % [maxi(meters, 5), hour]
	_notify("휴대폰 음성 안내: “%s”\n(건물 사이 골목에서는 위치 오차가 수 미터에 이른다)" % line, 5)
	_speak(line)

func _say(line: String, duration: float) -> void:
	_notify("(음성 안내) “%s”" % line, duration)
	_speak(line)

func _speak(line: String) -> void:
	Settings.speak(line)

func _find_tts_voice() -> void:
	tts_voice = Settings.tts_voice

func _notify(text: String, duration: float) -> void:
	message.text = text
	message_ttl = duration

func _finish() -> void:
	if finished:
		return
	finished = true
	cane.hide()
	aim.hide()
	marker.hide()
	status.hide()
	message.hide()
	touch_view.hide()
	touch_open = false
	panel.show()
	if noise_player:
		noise_player.stop()
	for car in cars:
		var e: AudioStreamPlayer3D = car["engine"]
		e.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	story_page = 0
	_show_ending_page()

func _show_ending_page() -> void:
	var titles := ["01  /  503호", "02  /  목소리", "03  /  잔향", "04  /  함께 걷는 법"]
	var record := "걸린 시간  %d분 %02d초\n지팡이에 걸린 장애물  %d번 · 머리를 부딪힌 횟수  %d번 · 경적  %d번 · 도움을 받은 횟수  %d번" % [int(elapsed)/60, int(elapsed)%60, count_contacts, count_head, count_honk, count_help]
	var pages := [
		"문 옆 명패의 점자를 손끝으로 한 번 더 확인하고, 문을 두드렸다.\n\n“들어오세요.”\n\n소독약 냄새 사이로, 익숙한 목소리가 들린다.",
		"손을 뻗자, 거칠고 따뜻한 손이 잡힌다.\n\n“왔니?”\n“응. 나 왔어.”\n\n오는 길에 하고 싶던 말은 많았는데,\n그 짧은 대답이면 충분했다.",
		("보이지 않는 길에도, 돌아갈 곳은 있었다.\n\nDANDELION — 끝\n\n" + record + "\n\n"
			+ "점자블록 위의 킥보드, 머리 높이의 간판, 뜯겨 나간 점자블록,\n안내음을 덮는 소음, 손끝으로 느낄 수 없는 횡단보도의 흰 칠,\n"
			+ "버튼 위 손톱만 한 점자 — 모두 누군가에게는 매일의 길입니다.\n\n오늘 길에서 겪은 불편은 눈이 아니라 길이 만든 것이었습니다."),
		("이 길을 매일 걷는 이웃과 함께하는 방법\n\n"
			+ "길에서\n"
			+ "· 점자블록 위에는 킥보드, 자전거, 짐을 세워 두지 마세요. 점자블록은 누군가의 길입니다.\n"
			+ "· 공사를 할 때는 점자블록이 끊기지 않게 하고, 돌아가는 길을 안내해 주세요.\n"
			+ "· 머리 높이의 간판이나 나뭇가지처럼 튀어나온 것은 지팡이로 알 수 없습니다.\n"
			+ "· 횡단보도 음향신호기와 점자 버튼이 고장 나 있으면 관리 기관에 알려 주세요.\n\n"
			+ "도움을 드릴 때\n"
			+ "· 먼저 “도와드릴까요?” 하고 물어보고, 원할 때만 도와주세요.\n"
			+ "· 갑자기 팔이나 지팡이를 잡아끌지 마세요. 내 팔꿈치를 잡게 하고 반 걸음 앞에서 걸어 주세요.\n"
			+ "· 길은 “저기”보다 “오른쪽으로 다섯 걸음”처럼 구체적으로 알려 주세요.\n"
			+ "· 안내견은 일하는 중입니다. 만지거나 부르거나 먹을 것을 주지 마세요.\n"
			+ "· 자리를 떠날 때는 말로 알려 주세요.\n\n"
			+ "작은 배려가 끊긴 길을 다시 잇습니다.\n\n"
			+ "이 작품의 윤곽선은 허구적 시각화이며, 실제 경험은 사람마다 다릅니다."),
	]
	title.text = titles[story_page]
	body.text = pages[story_page]
	action.text = "처음부터 다시 걷기" if story_page == 3 else "계속"
	skip_button.visible = false
	settings_button.visible = false
	menu_button.visible = story_page == 3

# ================================================================ audio

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

# kind: 0 지팡이 · 1 발걸음 · 2 현관 유도음 · 3 점자블록 · 4 물체 · 5 부딪힘 · 6 발전기(반복)
#       7 신호기 위치 알림음 · 8 횡단 유도음 · 9 엔진(반복) · 10 경적 · 11 엘리베이터 차임 · 12 버튼
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
		match kind:
			0:
				wave = wave * 0.5 + sin(TAU * frequency * 2.7 * t) * 0.2 + rng.randf_range(-1,1) * 0.3
			1:
				wave = rng.randf_range(-1,1) * 0.7 + wave * 0.3
			2:
				var f := frequency if t < 0.25 else frequency * 0.8
				var lt := t if t < 0.25 else t - 0.25
				wave = sin(TAU * f * lt)
				envelope = exp(-lt * 8.0) * minf(lt * 90, 1)
			3:
				var click := fmod(t, 0.028) < 0.006
				wave = rng.randf_range(-1,1) * (0.9 if click else 0.15) + sin(TAU * frequency * t) * 0.2
				envelope = exp(-t * 9.0)
			4:
				wave = sin(TAU * frequency * t) * 0.6 + sin(TAU * frequency * 1.6 * t) * 0.3 + rng.randf_range(-1,1) * 0.25
				envelope = exp(-t * 22.0)
			5:
				low = low * 0.9 + rng.randf_range(-1,1) * 0.1
				wave = sin(TAU * frequency * t * (1.0 - t)) * 0.8 + low * 3.0
				envelope = exp(-t * 9.0)
			6:
				low = low * 0.97 + rng.randf_range(-1,1) * 0.03
				wave = sin(TAU * frequency * t) * 0.35 + sin(TAU * frequency * 2.0 * t) * 0.25 + sin(TAU * frequency * 3.0 * t) * 0.12 + low * 4.0 + rng.randf_range(-1,1) * 0.12
				envelope = 1.0
			7:
				wave = signf(sin(TAU * frequency * t)) * 0.6 + rng.randf_range(-1,1) * 0.2
				envelope = exp(-t * 70.0)
			8:
				# 뚜르르 — 빠르게 떨리는 유도음
				wave = sin(TAU * frequency * t) * (0.55 + 0.45 * signf(sin(TAU * 22.0 * t)))
				envelope = minf(t * 60.0, 1.0) * exp(-t * 3.0)
			9:
				low = low * 0.985 + rng.randf_range(-1,1) * 0.015
				wave = sin(TAU * frequency * t) * 0.3 + sin(TAU * frequency * 2.0 * t) * 0.2 + low * 6.0 + rng.randf_range(-1,1) * 0.05
				envelope = 1.0
			10:
				wave = signf(sin(TAU * frequency * t)) * 0.35 + signf(sin(TAU * frequency * 1.26 * t)) * 0.35
				envelope = minf(t * 40.0, 1.0) * minf((duration - t) * 20.0, 1.0)
			11:
				wave = sin(TAU * frequency * t) * 0.6 + sin(TAU * frequency * 2.0 * t) * 0.2 + sin(TAU * frequency * 3.01 * t) * 0.1
				envelope = minf(t * 200.0, 1.0) * exp(-t * 3.5)
			12:
				wave = rng.randf_range(-1,1) * 0.5 + sin(TAU * frequency * t) * 0.5
				envelope = exp(-t * 120.0)
		var sample := int(clampf(wave * envelope * 0.65,-1,1) * 32767)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	if kind == 6 or kind == 9:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = count
	return stream


# ================================================================ v0.3.0: 자동 좌우 짚기

# 걸음 위상에 맞춰 지팡이 끝이 좌우 호를 그린다. 정수 위상에서 좌/우 끝을 짚고, 가운데에서는 살짝 뜬다.
func _sweep_tip(hand: Vector3, touchdown: bool, delta: float) -> Vector3:
	sweep = cos(step_phase * PI)
	var lift := TIP_LIFT * absf(sin(step_phase * PI))
	var floor_y := player.global_position.y
	var drop := (hand.y - floor_y) - lift
	var reach := sqrt(maxf(CANE_LENGTH * CANE_LENGTH - drop * drop, 0.01))
	var yaw := sweep * SWEEP_ANGLE
	var target := player.global_transform * Vector3(sin(yaw) * reach, 0.0, HAND_LOCAL.z - cos(yaw) * reach)
	target.y = floor_y + lift
	var dir := (target - hand).normalized()
	var q := PhysicsRayQueryParameters3D.create(hand, target + dir * 0.05, 1, [player.get_rid()])
	q.hit_from_inside = true
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var tip := target
	var contact := false
	var label := ""
	if not r.is_empty():
		var point: Vector3 = r["position"]
		var normal: Vector3 = r["normal"]
		tip = point
		if not (normal.y > 0.7 and point.y < 0.06):
			contact = true
			var col: Object = r["collider"]
			if col and col.has_meta("label"):
				label = str(col.get_meta("label"))
	sweep_refresh = maxf(sweep_refresh - delta, 0.0)
	if tap_t < 0.0 and not helping:
		if contact and (not sweep_contact or label != sweep_contact_label):
			# 지팡이가 물체에 걸림
			count_contacts += 1
			sweep_refresh = 0.45
			_pulse(tip, OBSTACLE_TOUCH, ECHO_WALK * 0.6)
			_mark(tip)
			_play_sound(sound_knock, tip, -9)
			shake = maxf(shake, 0.08)
			_describe_contact(label, "")
		elif contact and sweep_refresh <= 0.0:
			# 걸린 채 더듬으면 모양이 조금씩 드러난다
			sweep_refresh = 0.45
			_pulse(tip, OBSTACLE_TOUCH, 0.0)
		var over := ""
		if not contact and tip.y < floor_y + 0.06:
			over = _surface_at(tip)
		if over != "":
			_touched_paving(tip)
			if not sweep_over_paving:
				# 호를 그리는 지팡이 끝이 점자블록 돌기를 스친다 (드르륵)
				_pulse(tip, TOUCH_RADIUS, 0.0)
				_play_sound(sound_paving, tip, -12)
				_paving_feedback(over)
		sweep_over_paving = over != ""
		if touchdown and not contact:
			_pulse(tip, TOUCH_RADIUS, ECHO_WALK)
			_mark(tip)
			_play_sound(sound_tap, tip, -16)
			if over == "":
				_paving_feedback("")
				if tip.z < ROAD_Z0 + 0.05 and tip.z > ROAD_Z1 - 0.05 and absf(tip.x) < 30.0:
					_once_notify("asphalt", "매끈한 아스팔트. 횡단보도의 흰 칠은 지팡이로 느낄 수 없다.\n방향은 신호기 소리로 잡아야 한다.", 5)
	sweep_contact = contact
	sweep_contact_label = label if contact else ""
	return tip


# ================================================================ v0.3.0: 웅크리기

func _update_crouch(delta: float) -> void:
	var want := Input.is_action_pressed("crouch") and not touch_open and not helping
	if want:
		crouching = true
	elif crouching:
		if _can_stand():
			crouching = false
		else:
			_once_notify("cant_stand", "머리 위에 무언가 있어 일어설 수 없다. 몸을 낮춘 채 조금 더 지나가자.", 3.5)
	crouch_t = move_toward(crouch_t, 1.0 if crouching else 0.0, delta * 5.0)
	var h := lerpf(STAND_HEIGHT, CROUCH_HEIGHT, crouch_t)
	player_shape.height = h
	player_collider.position.y = h * 0.5
	# 몸을 낮춘 채 돌출물 아래를 지나가는 중
	if crouch_t > 0.9 and not _can_stand():
		if tutorial_active:
			tut_ducked = true
		var key := "duck_%d" % int(round(player.global_position.z))
		if not flags.has("duck_any") or (not flags.has(key) and player.global_position.z < -15.0):
			flags["duck_any"] = true
			flags[key] = true
			_notify("몸을 낮춘 채 머리 위 돌출물 아래를 지나간다.", 3)


# 서 있는 높이의 캡슐을 놓아 보고, 머리 위에 막힌 것이 없으면 일어설 수 있다.
func _can_stand() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = STAND_HEIGHT - 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), player.global_position + Vector3(0, STAND_HEIGHT * 0.5 + 0.06, 0))
	q.exclude = [player.get_rid()]
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


# ================================================================ v0.3.0: 연습 구간 (아파트 1층 복도 → 공동현관)

func _build_tutorial() -> void:
	var x := TUT_X
	_box(Vector3(x, -0.25, -6), Vector3(10, 0.5, 26), "", 0.0, false)          # 바닥
	_box(Vector3(x - 2.5, 2.5, -6), Vector3(1, 5, 22), "wall", 1.0)
	_box(Vector3(x + 2.5, 2.5, -6), Vector3(1, 5, 22), "wall", 1.0)
	_box(Vector3(x, 2.5, 5), Vector3(6, 5, 1), "home_door", 1.0)              # 우리 집 현관 쪽 벽
	# 공동현관: 가운데 1.6m 출입구, 유리문
	_box(Vector3(x - 1.65, 2.5, -16.5), Vector3(1.7, 5, 1), "wall", 1.0)
	_box(Vector3(x + 1.65, 2.5, -16.5), Vector3(1.7, 5, 1), "wall", 1.0)
	_box(Vector3(x, 3.75, -16.5), Vector3(1.6, 2.5, 1), "wall", 1.0)
	var door := StaticBody3D.new()
	door.position = Vector3(x, 1.25, -16.3)
	door.set_meta("label", "tut_door")
	door.set_meta("overhang", false)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 2.5, 0.08)
	shape_node.shape = shape
	door.add_child(shape_node)
	var vis := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 2.5, 0.08)
	vis.mesh = bm
	vis.material_override = black_material
	door.add_child(vis)
	door.add_child(_outline_mesh([[Vector3.ZERO, Vector3(1.6, 2.5, 0.08)]], 0.6))
	add_child(door)
	tut_door_nodes.append(door)
	# 열림 버튼 (문 오른쪽 벽)
	_box(Vector3(x + 1.97, 1.1, -15.6), Vector3(0.04, 0.22, 0.16), "", 0.0, true, false)
	interactables.append({"pos": Vector3(x + 1.3, 0, -15.3), "r": 1.5, "kind": "tut_door", "hint": "공동현관 열림 버튼 누르기"})
	# 머리 높이 배관 (웅크리기 연습)
	_box(Vector3(x, 1.55, TUT_BEAM_Z), Vector3(4.0, 0.14, 0.14), "tut_beam", 0.0, true, true, true)
	# 점자블록: 집 앞 → 꺾임 → 복도 → 공동현관 앞 점형블록
	_paving_path([Vector2(x - 1, 4.2), Vector2(x - 1, -2.5), Vector2(x + 1, -2.5), Vector2(x + 1, -14.0), Vector2(x, -14.0), Vector2(x, -15.35)])
	_warning_block(Rect2(x - 0.6, -15.95, 1.2, 0.6))
	_grid(x - 2.0, x + 2.0, 4.5, -16.0, 0.5)


# 끊김 없는 점자블록 경로 (꺾이는 곳마다 점형블록)
func _paving_path(path: Array[Vector2]) -> void:
	var w := 0.15
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var along_z := is_equal_approx(a.x, b.x)
		var rect := Rect2(a.x - w, minf(a.y, b.y), w * 2, absf(a.y - b.y)) if along_z else Rect2(minf(a.x, b.x), a.y - w, absf(a.x - b.x), w * 2)
		_paving_rect(rect, along_z)
		if i > 0:
			_warning_block(Rect2(a.x - w, a.y - w, w * 2, w * 2))


func _start_tutorial() -> void:
	tutorial_active = true
	tut_step = 0
	tut_walked = 0.0
	player.global_position = Vector3(TUT_X - 1.0, 0.05, 3.4)
	player.rotation.y = 0.0
	step_phase = 0.0
	_tut_prompt()


const TUT_PROMPTS := [
	"[연습 1/5] 아파트 1층 복도. 현관을 나서기 전에 지팡이 감각을 익히자.\n%s로 걸어 보자. 걸으면 지팡이가 걸음에 맞춰 좌우를 번갈아 짚는다.",
	"[연습 2/5] 발밑의 노란 점자블록을 따라가자. 지팡이 끝이 줄무늬를 스치면 ‘드르륵’ 소리가 난다.\n꺾이는 곳의 오돌토돌한 점형블록에서 방향을 바꾸자.",
	"[연습 3/5] 경비 아저씨가 “복도 중간에 배관이 낮게 내려와 있어요, 머리 조심하세요” 하셨다.\n머리 높이는 지팡이로 알 수 없다. %s를 누른 채 몸을 낮춰 지나가자.",
	"[연습 4/5] 휴대폰 보행 안내를 들어 보자. %s를 누르면 목적지까지의 거리와 방향을 알려 준다.",
	"[연습 5/5] 공동현관이다. 문 오른쪽 벽의 열림 버튼을 손으로 더듬어 누르자. (%s)",
]


func _tut_prompt() -> void:
	var t: String = TUT_PROMPTS[tut_step]
	match tut_step:
		0: t = t % _k("forward")
		2: t = t % _k("crouch")
		3: t = t % _k("phone")
		4: t = t % _k("interact")
	_notify(t, 9999.0)


func _tut_advance(to_step: int) -> void:
	if not tutorial_active or tut_step >= to_step:
		return
	tut_step = to_step
	_play_sound(sound_ding, player.global_position + Vector3(0, 1.6, -0.5), -16)
	_tut_prompt()


func _tutorial_process() -> void:
	var p := player.global_position
	match tut_step:
		0:
			if tut_walked > 2.0:
				_tut_advance(1)
		1:
			if tut_touched_paving and p.z < -6.0:
				_tut_advance(2)
		2:
			if tut_ducked and p.z < TUT_BEAM_Z - 0.6:
				_tut_advance(3)
		4:
			if tut_exit_open and p.z < -16.9:
				_start_main(true)


func _tut_press_door() -> void:
	if tut_exit_open:
		return
	if tut_step < 4:
		_notify("열림 버튼이다. 먼저 앞의 연습을 마쳐 보자. (일시정지 화면에서 ‘연습 건너뛰기’도 할 수 있다)", 4)
		return
	tut_exit_open = true
	_play_sound(sound_click, Vector3(TUT_X + 1.97, 1.1, -15.6), -6)
	for n in tut_door_nodes:
		n.queue_free()
	tut_door_nodes.clear()
	_say("문이 열립니다.", 2.5)
	get_tree().create_timer(2.6).timeout.connect(func():
		if tutorial_active:
			_notify("연습 끝! 열린 문으로 걸어 나가면 골목이다.\n이제부터는 안내가 없다. 지금까지 익힌 감각으로 병원 503호까지 가자.", 9999.0))


# 본 게임 시작: 골목 입구로 나간다. 연습에서의 기록은 지운다.
func _start_main(from_tutorial: bool) -> void:
	tutorial_active = false
	if from_tutorial:
		fade.color.a = 1.0
		create_tween().tween_property(fade, "color:a", 0.0, 1.2)
	player.global_position = MAIN_START
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	pitch = -0.55
	camera.rotation.x = pitch
	step_phase = 0.0
	elapsed = 0.0
	count_contacts = 0
	count_head = 0
	count_honk = 0
	count_help = 0
	no_paving_time = 0.0
	last_paving_pos = Vector3(0, 0.05, 3.2)
	on_paving_msg = true if from_tutorial else on_paving_msg
	_notify("공동현관을 나섰다. 병원은 골목 끝, 큰길 건너편에 있다.\n발밑의 점자블록을 찾아 따라가 보자.", 7)


# ================================================================ v0.3.0: 도와주는 사람

func _touched_paving(p: Vector3) -> void:
	no_paving_time = 0.0
	if tutorial_active:
		tut_touched_paving = true
		return
	if p.z > -62.5 and p.x < 40.0:
		last_paving_pos = Vector3(p.x, 0.05, p.z)


func _help_process(delta: float) -> void:
	if helping or touch_open or finished:
		return
	var p := player.global_position
	if p.z < -62.5 or p.x > 40.0:
		no_paving_time = 0.0     # 병원 안에서는 도움 기능을 쓰지 않는다
		return
	if _surface_at(p) != "":
		no_paving_time = 0.0
		last_paving_pos = Vector3(p.x, 0.05, p.z)
		return
	if p.distance_to(SIGNAL_POLE) < 2.5 or p.distance_to(SIGNAL_FAR) < 2.5:
		return                   # 신호기 앞에서 신호를 기다리는 중
	no_paving_time += delta
	if no_paving_time >= HELP_DELAY:
		_start_help()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _helper_say(line: String, duration: float) -> void:
	_notify("지나가던 사람: “%s”" % line, duration)
	_speak(line)
	await _wait(duration)


func _start_help() -> void:
	helping = true
	no_paving_time = 0.0
	count_help += 1
	var p := player.global_position
	var fwd := -player.global_transform.basis.z
	for i in 3:
		_play_sound(sound_step, p + fwd * (3.0 - i * 0.8) + player.global_transform.basis.x * 0.8, -16)
		await _wait(0.35)
	await _helper_say("저기요, 혹시 길을 찾고 계세요? 도와드릴까요?", 4.0)
	_notify("나: “네… 점자블록을 놓친 것 같아요.”", 2.5)
	await _wait(2.5)
	await _helper_say("도와드릴게요. 제가 팔을 살짝 터치해도 될까요?", 4.0)
	_notify("나: “네, 괜찮아요.”", 2.0)
	await _wait(2.0)
	await _helper_say("제 팔꿈치를 잡으세요. 제가 반 걸음 앞에서 천천히 걸을게요. 마지막으로 점자블록이 있던 곳까지 같이 가요.", 5.5)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.85, 0.8)
	await tw.finished
	for i in 6:
		_play_sound(sound_step, player.global_position + player.global_transform.basis.x * (-0.12 if i % 2 == 0 else 0.12), -18)
		await _wait(0.45)
	player.global_position = last_paving_pos
	player.velocity = Vector3.ZERO
	step_phase = 0.0
	var tw2 := create_tween()
	tw2.tween_property(fade, "color:a", 0.0, 0.8)
	await tw2.finished
	await _helper_say("여기 발밑부터 점자블록이 다시 이어져요. 조심히 가세요!", 4.0)
	_notify("나: “고맙습니다!”", 2.5)
	helping = false
