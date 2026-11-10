extends Node
## 게임 설정과 키 설정을 저장하고 적용한다 (user://settings.cfg).
## 다른 스크립트는 Settings.값 으로 읽고, 바뀌면 changed 시그널을 받는다.

signal changed

const PATH := "user://settings.cfg"

## 키 설정 화면에서 나누어 보여 주는 체험. [id, 표시 이름]
const KEY_STAGES := [
	["visual_walk", "시각장애 보행"],
	["fire_escape", "화재 대피"],
]

## 키 설정 화면에 나오는 순서. [액션 이름, 표시 이름, 기본 입력, 쓰는 체험, (체험별 표시 이름)]
## 기본 입력: "key:<physical keycode>" 또는 "mouse:<button index>"
## 두 체험이 함께 쓰는 동작은 키가 하나라서, 한쪽에서 바꾸면 다른 쪽도 같이 바뀐다.
const ACTIONS := [
	# 공통
	["forward", "앞으로 이동", "key:%d" % KEY_W, ["visual_walk", "fire_escape"]],
	["back", "뒤로 이동", "key:%d" % KEY_S, ["visual_walk", "fire_escape"]],
	["left", "왼쪽으로 이동", "key:%d" % KEY_A, ["visual_walk", "fire_escape"]],
	["right", "오른쪽으로 이동", "key:%d" % KEY_D, ["visual_walk", "fire_escape"]],
	["crouch", "몸 낮추기 (누르고 있기)", "key:%d" % KEY_CTRL, ["visual_walk", "fire_escape"],
		{"visual_walk": "웅크리기 (누르고 있기)", "fire_escape": "자세 낮추기 (누르고 있기)"}],
	["interact", "상호작용", "key:%d" % KEY_E, ["visual_walk", "fire_escape"],
		{"visual_walk": "손으로 더듬기", "fire_escape": "문 손잡이 확인·열기, 비상벨 누르기"}],
	["pause_game", "일시정지", "key:%d" % KEY_ESCAPE, ["visual_walk", "fire_escape"],
		{"visual_walk": "일시정지 · 도움말"}],
	# 시각장애 보행
	["sprint", "서두르기", "key:%d" % KEY_SHIFT, ["visual_walk"]],
	["cane_tap", "바라보는 곳 짚기", "mouse:%d" % MOUSE_BUTTON_LEFT, ["visual_walk"]],
	["tap", "발 앞 짚기", "key:%d" % KEY_SPACE, ["visual_walk"]],
	["phone", "휴대폰 음성 안내", "key:%d" % KEY_Q, ["visual_walk"]],
	["restart_game", "처음부터 다시 (일시정지 중)", "key:%d" % KEY_R, ["visual_walk"]],
	# 화재 대피
	["crouch_toggle", "자세 낮추기 켜고 끄기", "key:%d" % KEY_C, ["fire_escape"]],
	["cover", "코와 입 막기 (누르고 있기)", "key:%d" % KEY_F, ["fire_escape"]],
	["turn_left", "왼쪽으로 돌기", "key:%d" % KEY_LEFT, ["fire_escape"]],
	["turn_right", "오른쪽으로 돌기", "key:%d" % KEY_RIGHT, ["fire_escape"]],
]

## 화재 대피 본체(FireEscape)는 이동과 자세 낮추기에 다른 액션 이름을 쓴다.
## 같은 키를 이 이름으로도 등록해서 공통 키 설정이 그대로 적용되게 한다.
## (본체는 액션이 이미 있으면 자기 기본 키를 등록하지 않는다)
const ACTION_ALIASES := {
	"move_forward": "forward",
	"move_back": "back",
	"move_left": "left",
	"move_right": "right",
	"crouch_hold": "crouch",
}

const DEFAULTS := {
	"mouse_sensitivity": 1.0,   # 배율. 실제 값 = 0.0022 × 배율
	"invert_y": false,
	"fov": 78.0,
	"master_volume": 80.0,      # %
	"tts_enabled": true,
	"tts_volume": 60.0,         # %
	"tts_rate": 1.0,
	"text_scale": 1.0,          # 1.0 / 1.15 / 1.3
	"screen_effects": true,     # 부딪힐 때 흔들림·번쩍임
	"show_aim": true,
	"auto_sweep": true,         # 걸을 때 지팡이가 걸음에 맞춰 자동으로 좌우를 짚는다
	"fullscreen": false,
}

var values := DEFAULTS.duplicate()
var bindings := {}             # action -> "key:..." / "mouse:..."
var tts_voice := ""            # 쓸 수 있는 한국어 음성 (없으면 "")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in ACTIONS:
		bindings[a[0]] = a[2]
	load_settings()
	_find_tts_voice()
	apply_all()


# ---------------------------------------------------------------- 값 읽기

func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


var mouse_sensitivity: float:
	get: return 0.0022 * float(get_value("mouse_sensitivity"))
var invert_y: bool:
	get: return bool(get_value("invert_y"))
var fov: float:
	get: return float(get_value("fov"))
var text_scale: float:
	get: return float(get_value("text_scale"))
var screen_effects: bool:
	get: return bool(get_value("screen_effects"))
var show_aim: bool:
	get: return bool(get_value("show_aim"))
var auto_sweep: bool:
	get: return bool(get_value("auto_sweep"))


func font_size(base: int) -> int:
	return int(round(base * text_scale))


# ---------------------------------------------------------------- 값 바꾸기

func set_value(key: String, value) -> void:
	values[key] = value
	apply_all()
	save_settings()
	changed.emit()


## 키를 바꾼다. 같은 체험에서 같은 입력을 쓰던 다른 동작과는 서로 맞바꾼다.
## 서로 다른 체험에서만 쓰는 동작끼리는 같은 키를 써도 된다.
## 맞바꾸면 그 동작이 쓰이는 다른 체험에서 키가 겹치게 될 때는 바꾸지 않고
## 겹치는 동작 이름을 돌려준다. 바꾸었으면 "".
func set_binding(action: String, code: String) -> String:
	var old: String = bindings.get(action, "")
	if code == old:
		return ""
	var swaps := []
	for other in bindings:
		if other != action and bindings[other] == code and _share_stage(action, other):
			swaps.append(other)
	for other in swaps:
		for third in bindings:
			if third != action and third != other and bindings[third] == old and _share_stage(other, third):
				return third
	for other in swaps:
		bindings[other] = old
	bindings[action] = code
	_apply_inputs()
	save_settings()
	changed.emit()
	return ""


func reset_all() -> void:
	values = DEFAULTS.duplicate()
	for a in ACTIONS:
		bindings[a[0]] = a[2]
	apply_all()
	save_settings()
	changed.emit()


# ---------------------------------------------------------------- 적용

func apply_all() -> void:
	_apply_inputs()
	var bus := AudioServer.get_bus_index("Master")
	var vol := float(get_value("master_volume")) / 100.0
	AudioServer.set_bus_mute(bus, vol <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(vol, 0.001)))
	if DisplayServer.get_name() != "headless":
		var want_full := bool(get_value("fullscreen"))
		var mode := DisplayServer.window_get_mode()
		var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if want_full != is_full:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_inputs() -> void:
	for a in ACTIONS:
		var action: String = a[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := event_from_code(bindings.get(action, a[2]))
		if ev:
			InputMap.action_add_event(action, ev)
	for alias in ACTION_ALIASES:
		if not InputMap.has_action(alias):
			InputMap.add_action(alias)
		InputMap.action_erase_events(alias)
		for ev in InputMap.action_get_events(ACTION_ALIASES[alias]):
			InputMap.action_add_event(alias, ev.duplicate())


# ---------------------------------------------------------------- 키 설정 목록

static func find_action(action: String) -> Array:
	for a in ACTIONS:
		if a[0] == action:
			return a
	return []


static func action_stages(action: String) -> Array:
	var a := find_action(action)
	return a[3] if a.size() > 3 else []


## 여러 체험이 함께 쓰는 동작인지
static func is_shared_action(action: String) -> bool:
	return action_stages(action).size() > 1


## 키 설정 화면에 보여 줄 이름. 체험별 이름이 있으면 그것을 쓴다.
static func action_label(action: String, stage := "") -> String:
	var a := find_action(action)
	if a.is_empty():
		return action
	if a.size() > 4 and stage != "" and a[4].has(stage):
		return a[4][stage]
	return a[1]


static func actions_for_stage(stage: String) -> Array:
	return ACTIONS.filter(func(a): return stage in a[3])


static func _share_stage(a: String, b: String) -> bool:
	for s in action_stages(a):
		if s in action_stages(b):
			return true
	return false


static func event_from_code(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2:
		return null
	if parts[0] == "key":
		var k := InputEventKey.new()
		k.physical_keycode = int(parts[1]) as Key
		return k
	if parts[0] == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(parts[1]) as MouseButton
		return m
	return null


static func code_from_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode
		if code == 0:
			code = event.keycode
		return "key:%d" % code
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	return ""


static func label_for_code(code: String) -> String:
	var parts := code.split(":")
	if parts.size() != 2:
		return "없음"
	if parts[0] == "mouse":
		match int(parts[1]):
			MOUSE_BUTTON_LEFT: return "마우스 왼쪽"
			MOUSE_BUTTON_RIGHT: return "마우스 오른쪽"
			MOUSE_BUTTON_MIDDLE: return "마우스 휠 클릭"
			MOUSE_BUTTON_XBUTTON1: return "마우스 뒤로"
			MOUSE_BUTTON_XBUTTON2: return "마우스 앞으로"
			_: return "마우스 %s" % parts[1]
	var name := OS.get_keycode_string(int(parts[1]))
	match name:
		"Escape": return "Esc"
		"Space": return "Space"
		"Left": return "←"
		"Right": return "→"
		"Up": return "↑"
		"Down": return "↓"
		"": return "키 %s" % parts[1]
	return name


## 게임 안내 문구에 쓰는 현재 키 이름. 예: Settings.key("interact") -> "E"
func key(action: String) -> String:
	var code: String = bindings.get(action, "")
	var label := label_for_code(code)
	if label == "마우스 왼쪽":
		return "좌클릭"
	if label == "마우스 오른쪽":
		return "우클릭"
	return label


# ---------------------------------------------------------------- 음성 안내

func _find_tts_voice() -> void:
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var voices := DisplayServer.tts_get_voices_for_language("ko")
	if voices.size() > 0:
		tts_voice = voices[0]


func speak(line: String) -> void:
	if tts_voice == "" or not bool(get_value("tts_enabled")):
		return
	DisplayServer.tts_speak(line, tts_voice, int(get_value("tts_volume")), 1.0, float(get_value("tts_rate")), 0, true)


func stop_speaking() -> void:
	if tts_voice != "":
		DisplayServer.tts_stop()


# ---------------------------------------------------------------- 저장

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	for a in bindings:
		cfg.set_value("keys", a, bindings[a])
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in DEFAULTS:
		if cfg.has_section_key("settings", k):
			values[k] = cfg.get_value("settings", k)
	for a in ACTIONS:
		if cfg.has_section_key("keys", a[0]):
			bindings[a[0]] = str(cfg.get_value("keys", a[0]))
