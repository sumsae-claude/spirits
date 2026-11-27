class_name DialogueBox
extends Control
## 화면 아래에 뜨는 대화창. 화면을 누르면 다음 줄, '건너뛰기'로 전부 넘김.
## 사용: var box := DialogueBox.play(self, "1-1_pre")
##       if box != null: await box.finished

signal finished

var lines: Array = []
var index := 0
var speaker_label: Label
var text_label: Label
var _done := false


## data/chapter1.json의 dialogues[key]를 parent 위에 띄운다. 대화가 없으면 null.
static func play(parent: Node, key: String) -> DialogueBox:
	var all: Dictionary = GameData.chapter1.get("dialogues", {})
	if key == "" or not all.has(key):
		return null
	var box := DialogueBox.new()
	box.lines = all[key]
	parent.add_child(box)
	return box


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GameData.theme

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 18
	panel.offset_right = -18
	panel.offset_top = -400
	panel.offset_bottom = -36
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.17, 0.96)
	style.border_color = Color(0.85, 0.72, 0.4)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	speaker_label = UIKit.label("", 30, UIKit.GOLD)
	vb.add_child(speaker_label)
	text_label = UIKit.label("", 27)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(text_label)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := UIKit.label("▼ 화면을 눌러 계속", 20, UIKit.MUTED)
	row.add_child(hint)
	var skip := UIKit.button("건너뛰기", _finish, false, 56)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.custom_minimum_size = Vector2(180, 56)
	skip.add_theme_font_size_override("font_size", 22)
	row.add_child(skip)
	vb.add_child(row)

	_show_line()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _advance() -> void:
	index += 1
	if index >= lines.size():
		_finish()
	else:
		_show_line()


func _show_line() -> void:
	if lines.is_empty():
		_finish.call_deferred()
		return
	var line: Dictionary = lines[index]
	var speaker := GameState.fill_text(str(line.get("s", "")))
	speaker_label.text = speaker
	speaker_label.visible = speaker != ""
	var text := GameState.fill_text(str(line.get("t", "")))
	text_label.text = text
	# 나레이션/튜토리얼(▶)은 색을 다르게
	text_label.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0) if speaker == "" else Color.WHITE)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()
