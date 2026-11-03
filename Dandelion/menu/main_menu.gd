extends Control
## 메인 메뉴: 길가에 핀 민들레 배경 + 플레이 / 설정 / 종료, 오른쪽 아래 GitHub 바로가기.

const RoadsideScene := preload("res://menu/roadside_scene.gd")
const ModeSelect := preload("res://menu/mode_select.gd")
const SettingsMenu := preload("res://menu/settings_menu.gd")

var scene_bg: Control
var home: Control
var mode_select: Control
var settings_menu: Control
var play_button: Button
var github_button: Button
var ui_layer: Control
var built_scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene_bg = RoadsideScene.new()
	scene_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scene_bg)
	_build_ui()
	Settings.changed.connect(_on_settings_changed)
	if Game.return_to_mode_select:
		Game.return_to_mode_select = false
		_show_mode_select(false)
	else:
		play_button.call_deferred("grab_focus")
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)


func _build_ui() -> void:
	built_scale = Settings.text_scale
	ui_layer = Control.new()
	ui_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.theme = UiTheme.make(Settings.text_scale)
	add_child(ui_layer)

	# ---- 첫 화면
	home = Control.new()
	home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(home)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	col.custom_minimum_size = Vector2(420, 0)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.grow_vertical = Control.GROW_DIRECTION_BOTH
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	home.add_child(col)

	var title := Label.new()
	title.text = "민들레"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.add_theme_font_size_override("font_size", Settings.font_size(76))
	title.add_theme_color_override("font_color", UiTheme.CREAM)
	title.add_theme_color_override("font_shadow_color", Color(0.12, 0.06, 0.03, 0.45))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	col.add_child(title)
	var sub := Label.new()
	sub.text = "D A N D E L I O N"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", Settings.font_size(17))
	sub.add_theme_color_override("font_color", UiTheme.YELLOW)
	col.add_child(sub)
	var tag := Label.new()
	tag.text = "경험해 보지 못한 상황을, 게임으로 체험하다"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", Settings.font_size(17))
	tag.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.88))
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	tag.add_theme_constant_override("shadow_offset_y", 1)
	col.add_child(tag)

	var gap := Control.new()
	gap.custom_minimum_size.y = 26
	col.add_child(gap)

	play_button = _menu_button(col, "플레이", _on_play, true)
	_menu_button(col, "설정", _on_settings, true)
	_menu_button(col, "종료", func(): get_tree().quit(), false)

	# ---- 오른쪽 아래: GitHub 바로가기
	github_button = Button.new()
	github_button.text = "GitHub 바로가기  ↗"
	github_button.tooltip_text = Game.GITHUB_URL
	github_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	github_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	github_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	github_button.offset_right = -28
	github_button.offset_bottom = -26
	github_button.custom_minimum_size = Vector2(210, 46)
	github_button.pressed.connect(Game.open_github)
	ui_layer.add_child(github_button)
	var gh_note := Label.new()
	gh_note.text = "소스 코드 · 의견 남기기"
	gh_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	gh_note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	gh_note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	gh_note.offset_right = -32
	gh_note.offset_bottom = -78
	gh_note.add_theme_font_size_override("font_size", Settings.font_size(13))
	gh_note.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.75))
	ui_layer.add_child(gh_note)

	# ---- 왼쪽 아래: 버전
	var ver := Label.new()
	ver.text = "v%s  ·  Team 2" % Game.VERSION
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_left = 28
	ver.offset_bottom = -30
	ver.add_theme_font_size_override("font_size", Settings.font_size(13))
	ver.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.6))
	ui_layer.add_child(ver)

	# ---- 체험 선택 화면
	mode_select = ModeSelect.new()
	mode_select.visible = false
	mode_select.back_requested.connect(_show_home)
	mode_select.stage_chosen.connect(_on_stage_chosen)
	ui_layer.add_child(mode_select)


func _menu_button(parent: Control, text: String, cb: Callable, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 58 if primary else 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if primary:
		b.add_theme_font_override("font", UiTheme.bold_font())
		b.add_theme_font_size_override("font_size", Settings.font_size(22))
	else:
		b.add_theme_font_size_override("font_size", Settings.font_size(16))
		b.modulate = Color(1, 1, 1, 0.85)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- 화면 전환

func _fade_in(c: CanvasItem) -> void:
	c.visible = true
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.25)


func _on_play() -> void:
	_show_mode_select(true)


func _show_mode_select(animate: bool) -> void:
	home.visible = false
	if animate:
		_fade_in(mode_select)
	else:
		mode_select.visible = true
	mode_select.call_deferred("focus_first")


func _show_home() -> void:
	mode_select.visible = false
	_fade_in(home)
	play_button.call_deferred("grab_focus")


func _on_settings() -> void:
	if settings_menu:
		return
	settings_menu = SettingsMenu.new()
	settings_menu.closed.connect(_on_settings_closed)
	add_child(settings_menu)


func _on_settings_closed() -> void:
	settings_menu = null
	if home.visible:
		play_button.call_deferred("grab_focus")


func _on_stage_chosen(id: String) -> void:
	set_process_input(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0, 0, 0, 1), 0.6)
	tw.tween_callback(func(): Game.start_stage(id))


func _unhandled_input(event: InputEvent) -> void:
	if settings_menu:
		return
	if event.is_action_pressed("ui_cancel") and mode_select.visible:
		_show_home()
		get_viewport().set_input_as_handled()


func _on_settings_changed() -> void:
	# 글자 크기가 바뀌었을 때만 메뉴를 새 크기로 다시 만든다
	if absf(Settings.text_scale - built_scale) < 0.01:
		return
	var was_mode := mode_select.visible
	ui_layer.queue_free()
	_build_ui()
	if settings_menu:
		move_child(settings_menu, get_child_count() - 1)
	if was_mode:
		_show_mode_select(false)
