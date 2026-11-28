class_name HitArrow
extends Control
## 명중률 화살표: 길이 = 명중률(%). 오른쪽(→) = 내 공격, 왼쪽(←) = 상대 반격.
## 글자(명중 n% · 피해 m)는 양쪽 모두 같은 크기로 화살표 위에 쓴다.

var pct := 0.0          # 0 ~ 100
var right := true
var color := Color(1.0, 0.45, 0.4)
var text := ""
const FONT_SIZE := 19
const HEAD := 22.0


static func make(p_pct: float, p_right: bool, p_color: Color, p_text: String) -> HitArrow:
	var a := HitArrow.new()
	a.pct = clampf(p_pct, 0.0, 100.0)
	a.right = p_right
	a.color = p_color
	a.text = p_text
	a.custom_minimum_size = Vector2(0, 40)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return a


## 화살표 다각형 (x0~x1 사이, 머리는 진행 방향 끝)
func _shape(x0: float, x1: float) -> PackedVector2Array:
	var h := size.y
	var t := h * 0.22   # 몸통 위아래 여백
	if right:
		var hx := maxf(x0, x1 - HEAD)
		return PackedVector2Array([Vector2(x0, t), Vector2(hx, t), Vector2(hx, 0), Vector2(x1, h * 0.5),
			Vector2(hx, h), Vector2(hx, h - t), Vector2(x0, h - t)])
	var lx := minf(x1, x0 + HEAD)
	return PackedVector2Array([Vector2(x1, t), Vector2(lx, t), Vector2(lx, 0), Vector2(x0, h * 0.5),
		Vector2(lx, h), Vector2(lx, h - t), Vector2(x1, h - t)])


func _draw() -> void:
	var w := size.x
	# 명중률만큼의 길이로 화살표 하나만 그린다 (빈 틀은 그리지 않음)
	var fill_w := maxf(HEAD + 6.0, w * pct / 100.0) if pct > 0.0 else 0.0
	if fill_w > 0.0:
		var part := _shape(0.0, fill_w) if right else _shape(w - fill_w, w)
		draw_colored_polygon(part, Color(color, 0.9))
		var edge := part.duplicate()
		edge.append(part[0])
		draw_polyline(edge, color.lightened(0.35), 2.0)
	var font := get_theme_default_font()
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var pos := Vector2((w - ts.x) * 0.5, size.y * 0.5 + FONT_SIZE * 0.36)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 5, Color(0, 0, 0, 0.9))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE if pct > 0.0 else Color(0.75, 0.8, 0.9))
