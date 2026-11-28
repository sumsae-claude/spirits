class_name UIKit
extends RefCounted
## 코드로 UI를 만들 때 쓰는 공용 헬퍼. (그래픽 작업 전까지 임시 스타일)

const BG_COLOR := Color(0.08, 0.09, 0.13)
const GOLD := Color(1.0, 0.85, 0.45)
const MUTED := Color(0.62, 0.66, 0.75)
const GOOD := Color(0.55, 0.95, 0.65)
const BAD := Color(1.0, 0.55, 0.5)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## parent를 꽉 채우는 세로 레이아웃을 만들어 반환.
static func screen(parent: Control, top: int = 60, bottom: int = 40, with_bg: bool = true) -> VBoxContainer:
	if with_bg:
		var bg := ColorRect.new()
		bg.color = BG_COLOR
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		parent.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)
	return vb


static func label(text: String, font_size: int = 28, color: Color = Color.WHITE, centered: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(text: String, on_press: Callable, disabled: bool = false, min_height: int = 76) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, min_height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(on_press)
	return b


static func scroll_list(parent: Container) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## 골드 표시: 도트 동전 + 금색 숫자, 어두운 알약 모양에 금테. prefix = "+" 같은 앞글자, caption = 뒤에 붙는 설명
static func gold_badge(amount: int, font_size: int = 24, prefix: String = "", caption: String = "") -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.09, 0.04, 0.9)
	st.border_color = Color(0.95, 0.72, 0.25)
	st.set_border_width_all(2)
	st.set_corner_radius_all(font_size + 8)
	st.content_margin_left = 10
	st.content_margin_right = 16
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 3
	pill.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var coin := TextureRect.new()
	coin.texture = GameData.ui_tex("coin")
	coin.custom_minimum_size = Vector2(font_size + 6, font_size + 6)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin)
	var num := Label.new()
	num.text = "%s%s" % [prefix, _with_commas(amount)]
	num.add_theme_font_size_override("font_size", font_size)
	num.add_theme_color_override("font_color", Color(1.0, 0.86, 0.4))
	num.add_theme_color_override("font_outline_color", Color(0.25, 0.14, 0.02))
	num.add_theme_constant_override("outline_size", 4)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(num)
	if caption != "":
		var cap := Label.new()
		cap.text = caption
		cap.add_theme_font_size_override("font_size", maxi(14, font_size - 6))
		cap.add_theme_color_override("font_color", Color(0.9, 0.82, 0.65))
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cap)
	return pill


static func _with_commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## 보상 줄: "@gold:<양>:<설명>"이면 골드 알약, 아니면 글자
static func reward_line(line: String, font_size: int = 26) -> Control:
	if line.begins_with("@gold:"):
		var parts := line.split(":", true, 2)
		var cap := parts[2] if parts.size() > 2 else ""
		return gold_badge(int(parts[1]), font_size, "+", cap)
	return label(line, font_size, Color.WHITE, true)
