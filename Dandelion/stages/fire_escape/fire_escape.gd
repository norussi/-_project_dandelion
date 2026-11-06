extends Node
## 화재 대피 체험을 민들레에 연결하는 껍데기 씬.
## 게임 본체(res://main.tscn, map.tscn, scripts/, parts/, materials/, shaders/)는
## 원본 그대로 두고, 민들레에 필요한 것만 여기서 더한다.
##   · 일시정지 화면 (계속하기, 처음부터, 설정, 메인 메뉴)
##   · 나갈 때 Sfx 반복음 끄기 (Sfx는 오토로드라 씬이 바뀌어도 계속 울린다)
##   · 좌클릭 상호작용 (민들레의 interact 액션이 먼저 있어서 본체가 좌클릭을 등록하지 못한다)

const GAME_SCENE := preload("res://main.tscn")
const END_STATES := ["escaped", "fainted"]

var game: Node
var ui: Control
var panel: PanelContainer
var end_hint: Label
var paused := false
var settings_open := false
var mouse_was_captured := false
var interact_click: InputEventMouseButton


func _ready() -> void:
	# 일시정지 중에도 이 스크립트는 돌고, 게임 본체만 멈춘다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = GAME_SCENE.instantiate()
	game.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(game)
	_add_interact_click()
	Settings.changed.connect(_add_interact_click)
	_build_ui()


func _exit_tree() -> void:
	Sfx.stop_all_loops()
	if interact_click:
		InputMap.action_erase_event("interact", interact_click)


func _add_interact_click() -> void:
	# 키 설정을 바꾸면 Settings가 액션을 다시 만들기 때문에 그때마다 확인한다.
	if interact_click == null:
		interact_click = InputEventMouseButton.new()
		interact_click.button_index = MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("interact", interact_click):
		InputMap.action_add_event("interact", interact_click)


func _process(_delta: float) -> void:
	if paused:
		# 본체의 타이머는 일시정지 중에도 끝나서 마우스를 잡아 갈 수 있다.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	end_hint.visible = not paused and game.get("_state") in END_STATES


func _input(event: InputEvent) -> void:
	if settings_open:
		return
	if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_set_paused(not paused)


func _set_paused(on: bool) -> void:
	if on:
		mouse_was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	paused = on
	get_tree().paused = on
	panel.visible = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif mouse_was_captured or game.get("player").controls_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _open_settings() -> void:
	settings_open = true
	panel.hide()
	var menu: Control = preload("res://menu/settings_menu.gd").new()
	menu.closed.connect(func():
		settings_open = false
		panel.show())
	ui.add_child(menu)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10   # 본체 HUD(1)보다 위
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.make(Settings.text_scale)
	layer.add_child(ui)

	end_hint = Label.new()
	end_hint.text = "%s: 일시정지 · 메인 메뉴" % Settings.key("pause_game")
	end_hint.add_theme_font_size_override("font_size", Settings.font_size(15))
	end_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	end_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	end_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	end_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	end_hint.offset_left = -24
	end_hint.offset_right = -24
	end_hint.offset_top = -18
	end_hint.offset_bottom = -18
	end_hint.hide()
	ui.add_child(end_hint)

	panel = PanelContainer.new()
	panel.hide()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(640, 0)
	ui.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = "일시정지"
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.add_theme_font_size_override("font_size", Settings.font_size(30))
	title.add_theme_color_override("font_color", UiTheme.BROWN)
	col.add_child(title)

	var body := Label.new()
	body.text = ("W A S D 이동 · 마우스 / ← → 시선\n"
		+ "C 또는 Ctrl 자세 낮추기 · F 또는 우클릭 코와 입 막기\n"
		+ "%s 또는 좌클릭 문 손잡이 확인·열기, 비상벨 누르기\n\n" % Settings.key("interact")
		+ "연기는 위로 모입니다. 자세를 낮추고 코와 입을 막은 채 유도등을 따라가세요.")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", UiTheme.INK)
	body.add_theme_font_size_override("font_size", Settings.font_size(17))
	col.add_child(body)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	col.add_child(buttons)
	_button(buttons, "계속하기", func(): _set_paused(false), true)
	_button(buttons, "처음부터", _restart)
	_button(buttons, "설정", _open_settings)
	_button(buttons, "메인 메뉴", func(): Game.goto_main_menu())


func _button(row: Control, text: String, on_press: Callable, expand := false) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 48)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	row.add_child(b)
