class_name UiTheme
## 메뉴 화면이 함께 쓰는 색과 테마. (게임 안 HUD는 각 스테이지가 따로 만든다)

const CREAM := Color("faf7f0")
const PAPER := Color("f3ecdf")
const BROWN := Color("331b0d")
const TAN := Color("8c7753")
const YELLOW := Color("f5c542")
const INK := Color("1e1a16")
const MUTED := Color("6f6253")


static func font() -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR", "sans-serif"])
	return f


static func bold_font() -> SystemFont:
	var f := font()
	f.font_weight = 700
	return f


static func _box(bg: Color, border: Color, width := 0, radius := 14, pad_h := 22, pad_v := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.anti_aliasing = true
	return s


static func make(scale := 1.0) -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = int(round(18 * scale))

	# 버튼: 크림색 바탕, 갈색 글씨. 마우스를 올리면 민들레 노랑
	t.set_stylebox("normal", "Button", _box(Color(CREAM, 0.92), Color(BROWN, 0.25), 1))
	t.set_stylebox("hover", "Button", _box(YELLOW, BROWN, 2))
	t.set_stylebox("pressed", "Button", _box(Color("e7b52f"), BROWN, 2))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), BROWN, 3))
	t.set_stylebox("disabled", "Button", _box(Color(CREAM, 0.45), Color(BROWN, 0.12), 1))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", BROWN)
	t.set_color("font_disabled_color", "Button", Color(BROWN, 0.4))

	t.set_color("font_color", "Label", INK)

	t.set_stylebox("panel", "PanelContainer", _box(Color(CREAM, 0.97), Color(BROWN, 0.35), 1, 18, 28, 24))

	# 탭
	t.set_stylebox("tab_selected", "TabContainer", _box(CREAM, Color(BROWN, 0.35), 1, 10, 18, 8))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(PAPER, 0.6), Color(BROWN, 0.15), 1, 10, 18, 8))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(YELLOW, 0.6), Color(BROWN, 0.3), 1, 10, 18, 8))
	t.set_stylebox("panel", "TabContainer", _box(CREAM, Color(BROWN, 0.25), 1, 12, 22, 18))
	t.set_color("font_selected_color", "TabContainer", BROWN)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", BROWN)

	# 슬라이더
	var track := _box(Color(BROWN, 0.18), Color(0, 0, 0, 0), 0, 4, 0, 3)
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(TAN, Color(0, 0, 0, 0), 0, 4, 0, 3)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(Color("b08a3e"), Color(0, 0, 0, 0), 0, 4, 0, 3))
	t.set_icon("grabber", "HSlider", _circle_icon(18, YELLOW, BROWN))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(20, Color("ffd65c"), BROWN))

	# 체크 버튼, 옵션 버튼
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckButton", INK)
		t.set_color(c, "OptionButton", BROWN)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", _box(Color(0, 0, 0, 0), Color(BROWN, 0.6), 2, 8, 4, 2))
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	var on := _switch_icon(true, 1.0)
	var off := _switch_icon(false, 1.0)
	for nm in ["checked", "checked_mirrored"]:
		t.set_icon(nm, "CheckButton", on)
		t.set_icon(nm + "_disabled" if nm == "checked" else "checked_disabled_mirrored", "CheckButton", _switch_icon(true, 0.4))
	for nm in ["unchecked", "unchecked_mirrored"]:
		t.set_icon(nm, "CheckButton", off)
		t.set_icon(nm + "_disabled" if nm == "unchecked" else "unchecked_disabled_mirrored", "CheckButton", _switch_icon(false, 0.4))
	for st in ["normal", "hover", "pressed", "focus"]:
		t.set_stylebox(st, "OptionButton", t.get_stylebox(st, "Button"))

	t.set_stylebox("panel", "PopupMenu", _box(CREAM, Color(BROWN, 0.35), 1, 8, 10, 8))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", BROWN)
	t.set_stylebox("hover", "PopupMenu", _box(YELLOW, Color(0, 0, 0, 0), 0, 6, 8, 4))

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


static func _switch_icon(on: bool, alpha: float) -> ImageTexture:
	# 켜짐: 민들레 노랑 트랙 + 오른쪽 손잡이 / 꺼짐: 회색 트랙 + 왼쪽 손잡이
	var w := 52
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := Color("e2a92a") if on else Color("cfc6b8")
	var border := BROWN if on else Color("9b8f80")
	var knob_c := Vector2(w - h / 2.0, h / 2.0) if on else Vector2(h / 2.0, h / 2.0)
	var r := h / 2.0
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d := p.distance_to(Vector2(cx, r))
			var c := Color(0, 0, 0, 0)
			if d <= r:
				c = border if d > r - 1.6 else track
				c.a = clampf(r - d + 0.5, 0.0, 1.0)
			var kd := p.distance_to(knob_c)
			if kd <= r - 3.0:
				c = Color("fffaf0") if kd < r - 4.4 else Color(border, 0.8)
			c.a *= alpha
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _circle_icon(d: int, fill: Color, border: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var c := Color(0, 0, 0, 0)
			if dist <= r - 0.5:
				c = border if dist > r - 2.5 else fill
			elif dist <= r:
				c = Color(border, r - dist + 0.5)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
