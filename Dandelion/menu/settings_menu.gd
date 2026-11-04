extends Control
## 설정 화면. 메인 메뉴와 게임 일시정지 화면에서 함께 쓴다.
## 바꾼 값은 바로 적용되고 자동으로 저장된다 (Settings 참고).

signal closed

var tabs: TabContainer
var key_buttons := {}          # action -> Button
var listening := ""            # 지금 새 입력을 기다리는 동작
var listen_hint: Label
var _sliders := {}             # key -> [HSlider, value Label, format callable]
var _checks := {}              # key -> CheckButton
var _text_option: OptionButton
var _suppress := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.make(Settings.text_scale)
	_build()
	Settings.changed.connect(_on_settings_changed)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.04, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 600)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var head := HBoxContainer.new()
	col.add_child(head)
	var title := Label.new()
	title.text = "설정"
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.add_theme_font_size_override("font_size", Settings.font_size(30))
	title.add_theme_color_override("font_color", UiTheme.BROWN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var saved := Label.new()
	saved.text = "바꾼 값은 바로 적용되고 자동으로 저장됩니다"
	saved.add_theme_color_override("font_color", UiTheme.MUTED)
	saved.add_theme_font_size_override("font_size", Settings.font_size(14))
	saved.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(saved)

	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	_build_control_tab()
	_build_keys_tab()
	_build_sound_tab()
	_build_display_tab()

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	var reset := Button.new()
	reset.text = "기본값으로 되돌리기"
	reset.pressed.connect(_on_reset)
	foot.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size.x = 160
	close.pressed.connect(close_menu)
	foot.add_child(close)
	close.call_deferred("grab_focus")


# ---------------------------------------------------------------- 탭 만들기

func _page(name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 14)
	scroll.add_child(box)
	return box


func _row(parent: Control, label: String, control: Control, hint := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_theme_constant_override("separation", 2)
	row.add_child(left)
	var l := Label.new()
	l.text = label
	l.add_theme_color_override("font_color", UiTheme.INK)
	left.add_child(l)
	if hint != "":
		var h := Label.new()
		h.text = hint
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_theme_color_override("font_color", UiTheme.MUTED)
		h.add_theme_font_size_override("font_size", Settings.font_size(14))
		left.add_child(h)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)


func _slider(parent: Control, key: String, label: String, lo: float, hi: float, step: float, fmt: Callable, hint := "") -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(280, 28)
	s.value = float(Settings.get_value(key))
	var v := Label.new()
	v.custom_minimum_size.x = 70
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", UiTheme.BROWN)
	v.text = fmt.call(s.value)
	s.value_changed.connect(func(val):
		v.text = fmt.call(val)
		if not _suppress:
			Settings.set_value(key, val))
	box.add_child(s)
	box.add_child(v)
	_sliders[key] = [s, v, fmt]
	_row(parent, label, box, hint)


func _check(parent: Control, key: String, label: String, hint := "") -> void:
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(key))
	c.toggled.connect(func(on):
		if not _suppress:
			Settings.set_value(key, on))
	_checks[key] = c
	_row(parent, label, c, hint)


func _build_control_tab() -> void:
	var p := _page("조작")
	_slider(p, "mouse_sensitivity", "마우스 감도", 0.2, 3.0, 0.05, func(v): return "×%.2f" % v,
		"몸을 돌리고 고개를 숙이는 속도입니다.")
	_check(p, "auto_sweep", "걸을 때 지팡이 자동으로 짚기", "걸음에 맞춰 지팡이가 좌우를 번갈아 짚습니다(이점 촉타법). 끄면 클릭으로만 짚습니다.")
	_check(p, "invert_y", "마우스 상하 반전", "마우스를 위로 올리면 고개를 숙입니다.")
	_slider(p, "fov", "시야각", 60.0, 100.0, 1.0, func(v): return "%d°" % int(v),
		"넓을수록 화면에 더 많이 보이지만 멀미가 날 수 있습니다.")
	_check(p, "show_aim", "조준점 표시", "지팡이로 짚을 곳을 가리키는 화면 가운데 + 표시입니다.")


func _build_keys_tab() -> void:
	var p := _page("키 설정")
	listen_hint = Label.new()
	listen_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	listen_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	listen_hint.add_theme_font_size_override("font_size", Settings.font_size(14))
	listen_hint.text = "바꿀 동작의 버튼을 누른 뒤 새 키나 마우스 버튼을 누르세요. 이미 쓰고 있는 키를 고르면 두 동작의 키가 서로 바뀝니다. Esc로 취소합니다."
	p.add_child(listen_hint)
	for a in Settings.ACTIONS:
		var action: String = a[0]
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 40)
		b.text = Settings.label_for_code(Settings.bindings[action])
		b.pressed.connect(_start_listen.bind(action))
		key_buttons[action] = b
		_row(p, a[1], b)
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", UiTheme.MUTED)
	note.add_theme_font_size_override("font_size", Settings.font_size(14))
	note.text = "손으로 더듬기 화면에서 버튼을 누르는 것은 마우스 왼쪽 클릭으로 고정입니다."
	p.add_child(note)


func _build_sound_tab() -> void:
	var p := _page("소리")
	_slider(p, "master_volume", "전체 음량", 0.0, 100.0, 1.0, func(v): return "%d%%" % int(v),
		"지팡이 소리, 발소리, 차 소리, 안내음 등 게임 소리 전체입니다.")
	_check(p, "tts_enabled", "음성 안내 읽어 주기", "휴대폰 안내, 음향신호기, 엘리베이터 안내를 컴퓨터 음성으로 읽습니다. 자막은 항상 나옵니다.")
	_slider(p, "tts_volume", "음성 안내 음량", 0.0, 100.0, 1.0, func(v): return "%d%%" % int(v))
	_slider(p, "tts_rate", "음성 안내 속도", 0.5, 2.0, 0.05, func(v): return "×%.2f" % v)
	var test := Button.new()
	test.text = "음성 미리 듣기"
	test.pressed.connect(func(): Settings.speak("녹색 신호입니다. 건너가십시오."))
	var hint := "이 컴퓨터의 한국어 음성으로 들려줍니다."
	if Settings.tts_voice == "":
		hint = "이 컴퓨터에서 한국어 음성을 찾지 못했습니다. 음성 안내는 화면 자막으로만 나옵니다."
		test.disabled = true
	_row(p, "음성 확인", test, hint)


func _build_display_tab() -> void:
	var p := _page("화면 · 접근성")
	_check(p, "fullscreen", "전체 화면")
	_text_option = OptionButton.new()
	_text_option.custom_minimum_size.x = 230
	for item in [["보통 (100%)", 1.0], ["크게 (115%)", 1.15], ["아주 크게 (130%)", 1.3]]:
		_text_option.add_item(item[0])
		_text_option.set_item_metadata(_text_option.item_count - 1, item[1])
	_select_text_scale()
	_text_option.item_selected.connect(func(i):
		if not _suppress:
			Settings.set_value("text_scale", _text_option.get_item_metadata(i))
			_rebuild())
	_row(p, "글자 크기", _text_option, "안내 문구, 도움말, 메뉴 글자 크기입니다.")
	_check(p, "screen_effects", "화면 흔들림 · 번쩍임", "부딪히거나 지팡이가 걸릴 때 화면이 흔들리고, 머리를 부딪히면 하얗게 번쩍입니다. 빛이나 움직임에 민감하다면 끄세요.")


func _select_text_scale() -> void:
	var cur := Settings.text_scale
	for i in _text_option.item_count:
		if absf(float(_text_option.get_item_metadata(i)) - cur) < 0.01:
			_text_option.select(i)


# ---------------------------------------------------------------- 키 입력 받기

func _start_listen(action: String) -> void:
	_stop_listen()
	listening = action
	key_buttons[action].text = "입력하세요…"


func _stop_listen() -> void:
	if listening != "" and key_buttons.has(listening):
		key_buttons[listening].text = Settings.label_for_code(Settings.bindings[listening])
	listening = ""


func _input(event: InputEvent) -> void:
	if listening != "":
		var code := ""
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE and listening != "pause_game":
				_stop_listen()
				get_viewport().set_input_as_handled()
				return
			code = Settings.code_from_event(event)
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				return
			code = Settings.code_from_event(event)
		if code != "":
			var action := listening
			listening = ""
			Settings.set_binding(action, code)
			_refresh_keys()
			key_buttons[action].call_deferred("grab_focus")
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func _refresh_keys() -> void:
	for action in key_buttons:
		key_buttons[action].text = Settings.label_for_code(Settings.bindings[action])


# ---------------------------------------------------------------- 기타

func _on_settings_changed() -> void:
	_suppress = true
	for key in _sliders:
		var s: HSlider = _sliders[key][0]
		s.value = float(Settings.get_value(key))
		_sliders[key][1].text = _sliders[key][2].call(s.value)
	for key in _checks:
		_checks[key].button_pressed = bool(Settings.get_value(key))
	_select_text_scale()
	_refresh_keys()
	_suppress = false


func _on_reset() -> void:
	_stop_listen()
	var old_scale := Settings.text_scale
	Settings.reset_all()
	if absf(old_scale - Settings.text_scale) > 0.01:
		_rebuild()


func _rebuild() -> void:
	# 글자 크기가 바뀌면 화면을 새 크기로 다시 만든다
	var tab := tabs.current_tab
	for c in get_children():
		c.queue_free()
	key_buttons.clear()
	_sliders.clear()
	_checks.clear()
	theme = UiTheme.make(Settings.text_scale)
	_build()
	tabs.current_tab = tab


func close_menu() -> void:
	_stop_listen()
	closed.emit()
	queue_free()
