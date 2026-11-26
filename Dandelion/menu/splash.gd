extends Control
## 프로그램을 켜면 가장 먼저 나오는 화면: Godot 엔진 로고.
## 엔진의 부팅 화면(project.godot의 boot_splash)과 같은 로고·배경색·위치라서
## 부팅 화면에서 끊김 없이 이어지고, 잠시 보여 준 뒤 메인 메뉴로 넘어간다.
## 아무 키나 클릭으로 건너뛸 수 있다.

const LOGO := preload("res://menu/godot/godot_logo.png")
const BG := Color("faf7f0")       # boot_splash/bg_color 와 같은 색
const HOLD_TIME := 1.6            # 로고를 보여 주는 시간 (초)
const FADE_TIME := 0.5

var leaving := false
var content: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	# 부팅 화면처럼 원래 크기로 화면 한가운데에 둔다
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	logo.offset_left = -LOGO.get_width() * 0.5
	logo.offset_right = LOGO.get_width() * 0.5
	logo.offset_top = -LOGO.get_height() * 0.5
	logo.offset_bottom = LOGO.get_height() * 0.5
	content.add_child(logo)
	var made := Label.new()
	made.text = "Made with"
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	made.anchor_top = 0.5
	made.anchor_bottom = 0.5
	made.offset_left = -200
	made.offset_right = 200
	made.offset_top = -LOGO.get_height() * 0.5 - 44
	made.offset_bottom = -LOGO.get_height() * 0.5 - 10
	made.add_theme_font_size_override("font_size", 22)
	made.add_theme_color_override("font_color", Color(0.25, 0.25, 0.26, 0.85))
	made.modulate.a = 0.0
	content.add_child(made)

	var tw := create_tween()
	tw.tween_property(made, "modulate:a", 1.0, 0.4)
	tw.tween_interval(HOLD_TIME)
	tw.tween_callback(_leave)


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_leave()


func _leave() -> void:
	if leaving:
		return
	leaving = true
	var tw := create_tween()
	tw.tween_property(content, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func(): get_tree().change_scene_to_file(Game.MAIN_MENU))
