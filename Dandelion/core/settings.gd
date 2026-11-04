extends Node
## 게임 설정과 키 설정을 저장하고 적용한다 (user://settings.cfg).
## 다른 스크립트는 Settings.값 으로 읽고, 바뀌면 changed 시그널을 받는다.

signal changed

const PATH := "user://settings.cfg"

## 키 설정 화면에 나오는 순서. [액션 이름, 표시 이름, 기본 입력]
## 기본 입력: "key:<physical keycode>" 또는 "mouse:<button index>"
const ACTIONS := [
	["forward", "앞으로 걷기", "key:%d" % KEY_W],
	["back", "뒤로 걷기", "key:%d" % KEY_S],
	["left", "왼쪽 옆걸음", "key:%d" % KEY_A],
	["right", "오른쪽 옆걸음", "key:%d" % KEY_D],
	["sprint", "서두르기", "key:%d" % KEY_SHIFT],
	["crouch", "웅크리기 (누르고 있기)", "key:%d" % KEY_CTRL],
	["cane_tap", "바라보는 곳 짚기", "mouse:%d" % MOUSE_BUTTON_LEFT],
	["tap", "발 앞 짚기", "key:%d" % KEY_SPACE],
	["interact", "손으로 더듬기", "key:%d" % KEY_E],
	["phone", "휴대폰 음성 안내", "key:%d" % KEY_Q],
	["pause_game", "일시정지 · 도움말", "key:%d" % KEY_ESCAPE],
	["restart_game", "처음부터 다시 (일시정지 중)", "key:%d" % KEY_R],
]

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


func set_binding(action: String, code: String) -> void:
	# 같은 입력을 쓰던 다른 동작과는 서로 맞바꾼다.
	var old: String = bindings.get(action, "")
	for other in bindings:
		if other != action and bindings[other] == code:
			bindings[other] = old
	bindings[action] = code
	_apply_inputs()
	save_settings()
	changed.emit()


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
