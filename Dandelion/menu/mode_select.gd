extends Control
## 체험 선택 화면. Game.STAGES 목록으로 카드를 만든다.

signal back_requested
signal stage_chosen(id: String)

var t := 0.0
var previews: Array[Control] = []
var first_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	for p in previews:
		p.queue_redraw()


func _build() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 28
	col.offset_bottom = -28
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var title := Label.new()
	title.text = "체험 선택"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.add_theme_font_size_override("font_size", Settings.font_size(36))
	title.add_theme_color_override("font_color", UiTheme.CREAM)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	title.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	for stage in Game.STAGES:
		row.add_child(_card(stage))

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(back_row)
	var back := Button.new()
	back.text = "←  뒤로"
	back.custom_minimum_size = Vector2(180, 46)
	back.pressed.connect(func(): back_requested.emit())
	back_row.add_child(back)


func _card(stage: Dictionary) -> Control:
	var ok: bool = stage["available"]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(390, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UiTheme.CREAM, 0.96) if ok else Color("e9e1d3", 0.9)
	style.border_color = Color(UiTheme.BROWN, 0.45 if ok else 0.25)
	style.set_border_width_all(2 if ok else 1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	style.shadow_color = Color(0, 0, 0, 0.25 if ok else 0.1)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(346, int(150 - (Settings.text_scale - 1.0) * 260))
	preview.clip_contents = true
	var kind: String = stage["preview"]
	preview.draw.connect(func(): _draw_preview(preview, kind))
	previews.append(preview)
	col.add_child(preview)

	var title := Label.new()
	title.text = stage["title"]
	title.add_theme_font_override("font", UiTheme.bold_font())
	title.add_theme_font_size_override("font_size", Settings.font_size(26))
	title.add_theme_color_override("font_color", UiTheme.BROWN if ok else Color(UiTheme.BROWN, 0.6))
	col.add_child(title)
	var sub := Label.new()
	sub.text = stage["subtitle"]
	sub.add_theme_color_override("font_color", UiTheme.TAN)
	sub.add_theme_font_size_override("font_size", Settings.font_size(16))
	col.add_child(sub)
	var desc := Label.new()
	desc.text = stage["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(346, 80)
	desc.add_theme_color_override("font_color", UiTheme.INK if ok else UiTheme.MUTED)
	desc.add_theme_font_size_override("font_size", Settings.font_size(16))
	col.add_child(desc)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 8)
	col.add_child(tags)
	for tag in stage["tags"]:
		var chip := Label.new()
		chip.text = " %s " % tag
		chip.add_theme_font_size_override("font_size", Settings.font_size(13))
		chip.add_theme_color_override("font_color", UiTheme.BROWN)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(UiTheme.YELLOW, 0.35 if ok else 0.18)
		cs.set_corner_radius_all(8)
		cs.content_margin_left = 6
		cs.content_margin_right = 6
		cs.content_margin_top = 2
		cs.content_margin_bottom = 2
		chip.add_theme_stylebox_override("normal", cs)
		tags.add_child(chip)

	var b := Button.new()
	b.custom_minimum_size.y = 50
	if ok:
		b.text = "시작하기"
		var id: String = stage["id"]
		b.pressed.connect(func(): stage_chosen.emit(id))
		if first_button == null:
			first_button = b
	else:
		b.text = "준비 중"
		b.disabled = true
		b.focus_mode = Control.FOCUS_NONE
	col.add_child(b)
	return panel


func focus_first() -> void:
	if first_button:
		first_button.grab_focus()


func _draw_preview(c: Control, kind: String) -> void:
	var s := c.size
	if kind == "cane":
		# 검은 화면 위 지팡이와 짚은 자리에서 퍼지는 윤곽 (게임 화면을 닮은 그림)
		c.draw_rect(Rect2(Vector2.ZERO, s), Color("08080a"))
		var vp := Vector2(s.x * 0.5, s.y * 0.18)
		for i in range(-3, 4):
			c.draw_line(Vector2(s.x * 0.5 + i * s.x * 0.28, s.y), vp.lerp(Vector2(s.x * 0.5 + i * s.x * 0.28, s.y), 0.35), Color(1, 1, 1, 0.08), 1.0)
		var tap_phase := fmod(t, 1.6) / 1.6
		var side := 1.0 if fmod(t, 3.2) < 1.6 else -1.0
		var tip := Vector2(s.x * (0.5 + side * 0.12), s.y * 0.72)
		var hand := Vector2(s.x * 0.53, s.y * 1.05)
		# 점자블록 줄무늬가 짚은 자리 주변에만 드러난다
		var glow := clampf(1.0 - tap_phase * 1.2, 0.0, 1.0)
		for k in 4:
			var x := s.x * 0.44 + k * s.x * 0.04
			c.draw_line(Vector2(x, s.y * 0.6), Vector2(x - s.x * 0.02, s.y * 0.86), Color(1, 1, 1, 0.75 * glow), 1.5, true)
		for r in 3:
			var rr := (tap_phase + r * 0.18) * s.y * 0.6
			c.draw_arc(tip, rr, 0, TAU, 40, Color(1, 1, 1, maxf(0.0, 0.5 - tap_phase - r * 0.12)), 1.2, true)
		c.draw_line(hand, tip, Color(0.75, 0.75, 0.75), 3.0, true)
		c.draw_circle(tip, 4.0, Color(1, 1, 1, 0.9))
	else:
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(UiTheme.PAPER, 0.5))
		# 점선 테두리
		var col := Color(UiTheme.BROWN, 0.35)
		var dash := 10.0
		var x := 0.0
		while x < s.x:
			c.draw_line(Vector2(x, 1), Vector2(minf(x + dash, s.x), 1), col, 2.0)
			c.draw_line(Vector2(x, s.y - 1), Vector2(minf(x + dash, s.x), s.y - 1), col, 2.0)
			x += dash * 2
		var y := 0.0
		while y < s.y:
			c.draw_line(Vector2(1, y), Vector2(1, minf(y + dash, s.y)), col, 2.0)
			c.draw_line(Vector2(s.x - 1, y), Vector2(s.x - 1, minf(y + dash, s.y)), col, 2.0)
			y += dash * 2
		# 아직 피지 않은 봉오리 하나
		var base := Vector2(s.x * 0.5, s.y * 0.88)
		var sway := sin(t * 1.2) * 0.06
		var top := base + Vector2(sin(sway) * s.y * 0.5, -cos(sway) * s.y * 0.5)
		c.draw_line(base, top, Color("7c9c52"), 3.0, true)
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(top + Vector2(cos(a) * 9, sin(a) * 15).rotated(sway))
		c.draw_colored_polygon(pts, Color("5e8a3a"))
		c.draw_circle(top + Vector2(0, -12).rotated(sway), 5, Color(UiTheme.YELLOW, 0.8))
		for i in 2:
			var d := -1.0 if i == 0 else 1.0
			var lp := PackedVector2Array([base, base + Vector2(d * 50, -16), base + Vector2(d * 70, -4), base + Vector2(d * 30, 2)])
			c.draw_colored_polygon(lp, Color("5e8a3a"))
