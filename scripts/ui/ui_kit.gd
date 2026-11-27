class_name UIKit
extends RefCounted
## 코드로 UI를 만들 때 쓰는 공용 헬퍼. (그래픽 작업 전까지 임시 스타일)

const BG_COLOR := Color(0.08, 0.09, 0.13)
const GOLD := Color(1.0, 0.85, 0.45)
const MUTED := Color(0.62, 0.66, 0.75)
const GOOD := Color(0.55, 0.95, 0.65)


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
