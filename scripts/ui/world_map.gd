extends Control
## 챕터 1 월드맵: 스테이지 노드를 길로 잇고, 누르면 정보 패널 → 출발.
## 대화(프롤로그 / 스테이지 전후 / 체험판 끝)도 여기서 띄운다.

const MAP_TOP := 130.0
const PANEL_HEIGHT := 400.0
const NODE_RADIUS := 34.0

var stages: Array = []
var selected := 0
var time := 0.0
var font: Font
var _busy := false

var panel_box: VBoxContainer
var title_label: Label


func _ready() -> void:
	theme = GameData.theme
	font = GameData.ui_font
	stages = GameState.chapter_stages()
	selected = _first_open_stage()
	_build_ui()
	_rebuild_panel()
	_run_entry_dialogues()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _first_open_stage() -> int:
	for i in stages.size():
		if GameState.is_unlocked(i) and not GameState.is_cleared(str(stages[i]["id"])):
			return i
	return maxi(0, stages.size() - 1)


## 처음 들어왔을 때 프롤로그, 스테이지에서 돌아왔을 때 클리어 대화, 챕터를 다 깼으면 체험판 끝 안내
func _run_entry_dialogues() -> void:
	_busy = true
	if not bool(GameState.flags.get("prologue_seen", false)):
		GameState.flags["prologue_seen"] = true
		GameState.save_game()
		await _play("prologue")
	if GameState.pending_dialogue != "":
		var key := GameState.pending_dialogue
		GameState.pending_dialogue = ""
		await _play(key)
	if GameState.chapter_complete() and not bool(GameState.flags.get("demo_end_seen", false)):
		GameState.flags["demo_end_seen"] = true
		GameState.save_game()
		await _play("demo_end")
	_busy = false
	_rebuild_panel()


func _play(key: String) -> void:
	var box := DialogueBox.play(self, key)
	if box != null:
		await box.finished


# ---------------------------------------------------------------- 그리기

func _map_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(Vector2(40, MAP_TOP + 40), Vector2(vp.x - 80, vp.y - PANEL_HEIGHT - MAP_TOP - 90))


func _node_pos(i: int) -> Vector2:
	var r := _map_rect()
	var mp: Array = stages[i]["map_pos"]
	return r.position + Vector2(float(mp[0]) * r.size.x, float(mp[1]) * r.size.y)


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.09, 0.13, 0.12))
	# 바탕 무늬 (임시): 흩어진 풀/점
	for k in 60:
		var p := Vector2(fmod(k * 137.5, vp.x), fmod(k * 91.3 + 40.0, vp.y - PANEL_HEIGHT))
		draw_circle(p, 3.0, Color(0.16, 0.24, 0.19))
	var el_color := GameData.element_color(GameState.home_element())

	# 길
	for i in range(1, stages.size()):
		var col := Color(0.85, 0.75, 0.45, 0.8) if GameState.is_unlocked(i) else Color(0.4, 0.4, 0.45, 0.5)
		_draw_dashed(_node_pos(i - 1), _node_pos(i), col)

	# 노드
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	for i in stages.size():
		var p := _node_pos(i)
		var sid := str(stages[i]["id"])
		var unlocked := GameState.is_unlocked(i)
		var cleared := GameState.is_cleared(sid)
		var is_boss := (stages[i] as Dictionary).has("guardian")
		var radius := NODE_RADIUS + (8.0 if is_boss else 0.0)
		var fill := Color(0.25, 0.25, 0.3)
		if cleared:
			fill = Color(0.25, 0.55, 0.35)
		elif unlocked:
			fill = el_color.darkened(0.25)
		if i == selected:
			draw_arc(p, radius + 10.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.5 + 0.5 * pulse), 4.0)
		draw_circle(p, radius, fill)
		draw_arc(p, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.85) if unlocked else Color(0.6, 0.6, 0.65), 3.0)
		var mark := sid
		if cleared:
			mark = "✓"
		elif not unlocked:
			mark = "잠김"
		elif is_boss:
			mark = "수호"
		_draw_text(mark, p + Vector2(0, 8), 22 if mark.length() <= 3 else 18, Color.WHITE)
		_draw_text("%s %s" % [sid, stages[i]["name"]], p + Vector2(0, radius + 26), 18,
			Color(1, 1, 1, 0.95) if unlocked else Color(0.6, 0.6, 0.65))


func _draw_dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var length := a.distance_to(b)
	var dir := (b - a) / maxf(1.0, length)
	var t := 0.0
	while t < length:
		var seg_end := minf(t + 14.0, length)
		draw_line(a + dir * t, a + dir * seg_end, col, 4.0)
		t += 24.0


func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	var width := 260.0
	var at := Vector2(pos.x - width * 0.5, pos.y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _gui_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in stages.size():
			if (event as InputEventMouseButton).position.distance_to(_node_pos(i)) <= NODE_RADIUS + 14.0:
				selected = i
				_rebuild_panel()
				return


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 30
	title_label.offset_bottom = 120
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", UIKit.GOLD)
	title_label.text = "%s\n%s" % [str(GameData.chapter1.get("title", "1장")), GameState.home_region_name()]
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -PANEL_HEIGHT
	panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.17, 0.97)
	style.border_width_top = 2
	style.border_color = Color(0.35, 0.4, 0.55)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 10)
	margin.add_child(panel_box)


func _rebuild_panel() -> void:
	UIKit.clear(panel_box)
	if stages.is_empty():
		return
	var st: Dictionary = stages[selected]
	var sid := str(st["id"])
	var unlocked := GameState.is_unlocked(selected)
	var cleared := GameState.is_cleared(sid)
	var status := "클리어" if cleared else ("도전 가능" if unlocked else "이전 스테이지를 클리어하면 열립니다")
	panel_box.add_child(UIKit.label("%s  %s" % [sid, st["name"]], 32, UIKit.GOLD))
	panel_box.add_child(UIKit.label("%s · 권장 Lv.%d · 파티 평균 Lv.%d" % [
		status, int(st.get("rec_level", 1)), GameState.average_party_level()], 21, UIKit.MUTED))
	panel_box.add_child(UIKit.label(GameState.fill_text(str(st.get("desc", ""))), 23))
	panel_box.add_child(UIKit.label("적: " + GameState.describe_stage_enemies(st), 21, Color(1.0, 0.7, 0.6)))
	var rewards := PackedStringArray()
	for item in st.get("rewards", {}).get("items", []):
		if GameData.equipment.has(str(item)):
			rewards.append(str(GameData.equipment[str(item)]["name"]))
	if not rewards.is_empty():
		panel_box.add_child(UIKit.label("첫 클리어 보상: " + ", ".join(rewards) + (" (받음)" if cleared else ""), 20, UIKit.GOOD))
	panel_box.add_child(UIKit.spacer())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.button("출발" if not cleared else "다시 도전", _on_start, not unlocked or _busy))
	row.add_child(UIKit.button("거점으로", _on_hub, _busy))
	panel_box.add_child(row)


func _on_start() -> void:
	if _busy:
		return
	var st: Dictionary = stages[selected]
	_busy = true
	_rebuild_panel.call_deferred()
	await _play(str(st.get("dialogue_pre", "")))
	GameState.save_game()
	GameState.start_stage(st)


func _on_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
