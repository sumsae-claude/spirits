extends Control
## 모험 지도.
##  - 대륙 지도: 네 속성 지역 + 가운데 무색의 도시. 챕터마다 한 지역을 여행한다. (1장 = 고향, 2장 = 다음 지역 …)
##  - 지역 지도: 지점(전투·보스·이벤트·상점·마을)을 길로 이은 지도. 지나온 지점과 이어진 곳이 열린다.
##    상점·마을은 몇 번이고 다시 들를 수 있고, 이벤트는 한 번만.
## 대화(프롤로그 / 스테이지 전후 / 챕터 시작·끝)도 여기서 띄운다.

const MAP_TOP := 120.0
const PANEL_HEIGHT := 470.0
const NODE_RADIUS := 34.0
const ICON_SIZE := 72.0
## 대륙 지도에서 각 속성 지역의 위치 (지도 영역 비율)
const REGION_POS := {"wind": Vector2(0.27, 0.2), "fire": Vector2(0.75, 0.27), "water": Vector2(0.72, 0.76), "grass": Vector2(0.26, 0.72)}
const CITY_POS := Vector2(0.5, 0.48)
const TYPE_LABEL := {"battle": "전투", "boss": "수호", "event": "?", "shop": "상점", "town": "마을"}
const TYPE_COLOR := {
	"battle": Color(0.72, 0.32, 0.3), "boss": Color(0.85, 0.2, 0.35), "event": Color(0.55, 0.4, 0.8),
	"shop": Color(0.85, 0.65, 0.25), "town": Color(0.3, 0.65, 0.45),
}

var mode := "region"          # "continent" | "region"
var chapter := 0              # 보고 있는 챕터 (지역)
var selected := 0             # 지역 지도에서 고른 지점 번호
var selected_region := ""     # 대륙 지도에서 고른 속성
var time := 0.0
var font: Font
var _busy := false
var token_pos := Vector2.ZERO  # 지도 위 정령사 말 (그리기 좌표)

var panel_box: VBoxContainer
var title_label: Label
var overlay: Control = null


func _ready() -> void:
	theme = GameData.theme
	font = GameData.ui_font
	chapter = clampi(GameState.active_chapter, 0, maxi(0, GameData.chapters.size() - 1))
	mode = str(GameState.flags.get("map_mode", "region"))
	selected_region = GameState.chapter_element(chapter)
	_build_ui()
	_enter_mode(mode)
	_run_entry_dialogues()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


# ---------------------------------------------------------------- 진행·대화

func _nodes() -> Array:
	return GameState.chapter_nodes(chapter)


func _node_id(i: int) -> String:
	return str(_nodes()[i]["id"])


## 처음 들어왔을 때 프롤로그, 돌아왔을 때 클리어 대화, 챕터 시작/끝 대화
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
	# 1장을 다 깼으면: 대륙 지도가 열린다
	if GameState.chapter_complete(0) and not bool(GameState.flags.get("demo_end_seen", false)):
		GameState.flags["demo_end_seen"] = true
		GameState.save_game()
		await _play("demo_end")
		if GameData.chapters.size() > 1:
			selected_region = GameState.chapter_element(1)
			_enter_mode("continent")
	# 그 밖의 챕터 끝
	for ci in range(1, GameData.chapters.size()):
		var end_key := str(GameState.chapter_data(ci).get("end", ""))
		if end_key != "" and GameState.chapter_complete(ci) and not bool(GameState.flags.get("end_seen_%d" % ci, false)):
			GameState.flags["end_seen_%d" % ci] = true
			GameState.save_game()
			await _play(end_key)
	await _play_chapter_intro()
	_busy = false
	_rebuild_panel()


func _play_chapter_intro() -> void:
	if mode != "region":
		return
	var key := str(GameState.chapter_data(chapter).get("intro", ""))
	if key != "" and not bool(GameState.flags.get("intro_seen_%d" % chapter, false)):
		GameState.flags["intro_seen_%d" % chapter] = true
		GameState.save_game()
		await _play(key)


func _play(key: String) -> void:
	var box := DialogueBox.play(self, key)
	if box != null:
		await box.finished


func _enter_mode(m: String) -> void:
	mode = m
	GameState.flags["map_mode"] = m
	if m == "region":
		GameState.active_chapter = chapter
		selected = _default_node()
		token_pos = _node_pos(_token_node())
	_update_title()
	_rebuild_panel()


## 처음 고를 지점: 아직 안 지나간 열린 지점, 없으면 말이 있는 곳
func _default_node() -> int:
	var nodes := _nodes()
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var t := str(n.get("type", "battle"))
		if GameState.node_unlocked(chapter, n) and not GameState.is_cleared(str(n["id"])) and t != "shop" and t != "town":
			return i
	return _token_node()


## 정령사 말이 서 있는 지점 번호
func _token_node() -> int:
	var nid := str(GameState.flags.get("pos_%d" % chapter, ""))
	var nodes := _nodes()
	for i in nodes.size():
		if str(nodes[i]["id"]) == nid:
			return i
	return 0


func _update_title() -> void:
	if mode == "continent":
		title_label.text = "대륙 지도\n골드 %d" % GameState.gold
	else:
		title_label.text = "%s · %s\n골드 %d" % [str(GameState.chapter_data(chapter).get("title", "")),
			GameState.chapter_region_name(chapter), GameState.gold]


# ---------------------------------------------------------------- 그리기

func _map_rect() -> Rect2:
	var vp := get_viewport_rect().size
	return Rect2(Vector2(40, MAP_TOP + 40), Vector2(vp.x - 80, vp.y - PANEL_HEIGHT - MAP_TOP - 90))


func _node_pos(i: int) -> Vector2:
	var nodes := _nodes()
	if nodes.is_empty():
		return Vector2.ZERO
	var r := _map_rect()
	var mp: Array = nodes[clampi(i, 0, nodes.size() - 1)].get("pos", [0.5, 0.5])
	return r.position + Vector2(float(mp[0]) * r.size.x, float(mp[1]) * r.size.y)


func _region_pos(el: String) -> Vector2:
	var r := _map_rect()
	var f: Vector2 = REGION_POS.get(el, CITY_POS)
	return r.position + f * r.size


## 이 속성 지역을 여행하는 챕터 번호 (없으면 -1)
func _chapter_of_region(el: String) -> int:
	for ci in GameData.chapters.size():
		if GameState.chapter_element(ci) == el:
			return ci
	return -1


func _draw() -> void:
	var vp := get_viewport_rect().size
	if mode == "continent":
		_draw_continent(vp)
	else:
		_draw_region(vp)


func _draw_region(vp: Vector2) -> void:
	var el := GameState.chapter_element(chapter)
	var base := GameData.element_color(el).darkened(0.78)
	draw_rect(Rect2(Vector2.ZERO, vp), base)
	for k in 70:
		var p := Vector2(fmod(k * 137.5, vp.x), fmod(k * 91.3 + 40.0, vp.y - PANEL_HEIGHT))
		draw_circle(p, 3.0, base.lightened(0.12))
	var nodes := _nodes()
	# 길
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		for l in n.get("links", []):
			var j := _index_of(str(l))
			if j < 0:
				continue
			var open := GameState.node_unlocked(chapter, nodes[j]) and GameState.node_unlocked(chapter, n)
			_draw_dashed(_node_pos(i), _node_pos(j), Color(0.9, 0.78, 0.45, 0.85) if open else Color(0.45, 0.45, 0.5, 0.45))
	# 지점
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		var p := _node_pos(i)
		var t := str(n.get("type", "battle"))
		var unlocked := GameState.node_unlocked(chapter, n)
		var done := GameState.is_cleared(str(n["id"]))
		var radius := NODE_RADIUS + (8.0 if t == "boss" else 0.0)
		var fill: Color = TYPE_COLOR.get(t, Color.GRAY)
		if not unlocked:
			fill = Color(0.25, 0.25, 0.3)
		elif done and (t == "battle" or t == "boss" or t == "event"):
			fill = fill.darkened(0.45)
		if i == selected:
			draw_arc(p, radius + 10.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.5 + 0.5 * pulse), 4.0)
		draw_circle(p, radius, fill)
		draw_arc(p, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.85) if unlocked else Color(0.6, 0.6, 0.65), 3.0)
		var mark := "잠김" if not unlocked else str(TYPE_LABEL.get(t, "?"))
		if unlocked and done and (t == "battle" or t == "boss" or t == "event"):
			mark = "✓"
		_draw_text(mark, p + Vector2(0, 8), 22 if mark.length() <= 2 else 18, Color.WHITE)
		_draw_text(GameState.fill_text(str(n.get("name", ""))), p + Vector2(0, radius + 26), 18,
			Color(1, 1, 1, 0.95) if unlocked else Color(0.6, 0.6, 0.65))
	# 정령사 말
	var tex := GameData.sprite_for(GameState.summoner)
	var bob := sin(time * 3.0) * 3.0
	if tex != null:
		draw_texture_rect(tex, Rect2(token_pos + Vector2(-26, -NODE_RADIUS - 52 + bob), Vector2(52, 52)), false)
	else:
		draw_circle(token_pos + Vector2(0, -NODE_RADIUS - 20 + bob), 12.0, UIKit.GOLD)


func _draw_continent(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.07, 0.12, 0.2))
	# 바다 물결
	for k in 40:
		var p := Vector2(fmod(k * 173.3, vp.x), fmod(k * 67.7 + 30.0, vp.y - PANEL_HEIGHT))
		draw_arc(p, 10.0, PI * 1.15, PI * 1.85, 6, Color(0.3, 0.45, 0.6, 0.35), 2.0)
	var r := _map_rect()
	# 대륙 (울퉁불퉁한 원)
	var land := PackedVector2Array()
	var c := r.position + r.size * 0.5
	for i in 48:
		var a := TAU * i / 48.0
		var wob := 1.0 + 0.06 * sin(a * 5.0) + 0.04 * sin(a * 11.0 + 1.3)
		land.append(c + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.5) * wob)
	draw_colored_polygon(land, Color(0.33, 0.42, 0.3))
	var outline := land.duplicate()
	outline.append(land[0])
	draw_polyline(outline, Color(0.85, 0.78, 0.55, 0.8), 3.0)
	# 지역 영역 (속성 색 얼룩)
	for el in REGION_POS:
		draw_circle(_region_pos(el), r.size.x * 0.2, Color(GameData.element_color(el), 0.28))
	# 길 (도시 ↔ 지역, 이웃 지역끼리)
	var city := r.position + CITY_POS * r.size
	for el in REGION_POS:
		_draw_dashed(city, _region_pos(el), Color(0.9, 0.8, 0.5, 0.5))
	_draw_dashed(_region_pos("wind"), _region_pos("fire"), Color(0.9, 0.8, 0.5, 0.35))
	_draw_dashed(_region_pos("fire"), _region_pos("water"), Color(0.9, 0.8, 0.5, 0.35))
	_draw_dashed(_region_pos("water"), _region_pos("grass"), Color(0.9, 0.8, 0.5, 0.35))
	_draw_dashed(_region_pos("grass"), _region_pos("wind"), Color(0.9, 0.8, 0.5, 0.35))
	# 지역 표시
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	for el in REGION_POS:
		var p := _region_pos(el)
		var ci := _chapter_of_region(el)
		var open := ci >= 0 and GameState.chapter_unlocked(ci)
		var col := GameData.element_color(el)
		if el == selected_region:
			draw_arc(p, 50.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.5 + 0.5 * pulse), 4.0)
		draw_circle(p, 40.0, col.darkened(0.2) if open else Color(0.3, 0.3, 0.34))
		draw_arc(p, 40.0, 0.0, TAU, 40, Color.WHITE if open else Color(0.6, 0.6, 0.65), 3.0)
		var tag := "%d장" % (ci + 1) if ci >= 0 else "준비 중"
		if ci >= 0 and GameState.chapter_complete(ci):
			tag = "✓"
		_draw_text(tag, p + Vector2(0, 8), 20, Color.WHITE)
		_draw_text(str(GameData.chapter1.get("regions", {}).get(el, el)), p + Vector2(0, 66), 19,
			Color(1, 1, 1, 0.95) if open else Color(0.65, 0.65, 0.7))
	# 무색의 도시
	draw_circle(city, 30.0, Color(0.5, 0.5, 0.55))
	draw_arc(city, 30.0, 0.0, TAU, 32, Color(0.8, 0.8, 0.85), 3.0)
	_draw_text("5장", city + Vector2(0, 7), 18, Color.WHITE)
	_draw_text("무색의 도시 (준비 중)", city + Vector2(0, 52), 17, Color(0.75, 0.75, 0.8))
	# 지금 여행 중인 지역에 정령사 말
	var tex := GameData.sprite_for(GameState.summoner)
	var here := _region_pos(GameState.chapter_element(GameState.active_chapter))
	var bob := sin(time * 3.0) * 3.0
	if tex != null:
		draw_texture_rect(tex, Rect2(here + Vector2(-24, -96 + bob), Vector2(48, 48)), false)


func _index_of(node_id: String) -> int:
	var nodes := _nodes()
	for i in nodes.size():
		if str(nodes[i]["id"]) == node_id:
			return i
	return -1


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
	if _busy or overlay != null:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos := (event as InputEventMouseButton).position
	if mode == "continent":
		for el in REGION_POS:
			if pos.distance_to(_region_pos(el)) <= 54.0:
				selected_region = el
				_rebuild_panel()
				return
	else:
		for i in _nodes().size():
			if pos.distance_to(_node_pos(i)) <= NODE_RADIUS + 14.0:
				selected = i
				_rebuild_panel()
				return


# ---------------------------------------------------------------- 아래 패널

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 도트 말이 또렷하게
	title_label = Label.new()
	title_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 24
	title_label.offset_bottom = 116
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", UIKit.GOLD)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -PANEL_HEIGHT
	panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.15, 0.97)
	style.border_width_top = 3
	style.border_color = UIKit.GOLD.darkened(0.3)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
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
	if panel_box == null:
		return
	UIKit.clear(panel_box)
	_update_title()
	if mode == "continent":
		_build_continent_panel()
	else:
		_build_region_panel()


func _build_continent_panel() -> void:
	var ci := _chapter_of_region(selected_region)
	var region_name := str(GameData.chapter1.get("regions", {}).get(selected_region, selected_region))
	panel_box.add_child(UIKit.label(region_name, 32, GameData.element_color(selected_region).lightened(0.35)))
	if ci < 0:
		panel_box.add_child(UIKit.label("정식판에서 여행할 수 있는 지역입니다. (준비 중)", 23, UIKit.MUTED))
	else:
		var ch := GameState.chapter_data(ci)
		var open := GameState.chapter_unlocked(ci)
		var status := "클리어" if GameState.chapter_complete(ci) else ("여행 가능" if open else "이전 장을 마치면 열립니다")
		panel_box.add_child(UIKit.label("%s · %s" % [str(ch.get("title", "")), status], 23, UIKit.MUTED))
		var nodes: Array = ch.get("nodes", [])
		var done := 0
		for o in nodes:
			if GameState.is_cleared(str((o as Dictionary)["id"])):
				done += 1
		panel_box.add_child(UIKit.label("지나온 지점 %d / %d" % [done, nodes.size()], 21, UIKit.MUTED))
	panel_box.add_child(UIKit.spacer())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.button("이 지역으로", _on_enter_region, ci < 0 or not GameState.chapter_unlocked(ci) or _busy))
	row.add_child(UIKit.button("거점으로", _on_hub, _busy))
	panel_box.add_child(row)


func _build_region_panel() -> void:
	var nodes := _nodes()
	if nodes.is_empty():
		return
	var n: Dictionary = nodes[selected]
	var t := str(n.get("type", "battle"))
	var nid := str(n["id"])
	var unlocked := GameState.node_unlocked(chapter, n)
	var done := GameState.is_cleared(nid)
	var head := GameState.fill_text(str(n.get("name", "")))
	if t == "battle" or t == "boss":
		head = "%s  %s" % [nid, head]
	panel_box.add_child(UIKit.label(head, 32, TYPE_COLOR.get(t, UIKit.GOLD).lightened(0.35)))
	var status := ""
	match t:
		"battle", "boss":
			status = "클리어" if done else ("도전 가능" if unlocked else "이어진 지점을 지나면 열립니다")
			status += " · 권장 Lv.%d · 파티 평균 Lv.%d" % [int(n.get("rec_level", 1)), GameState.average_party_level()]
		"event":
			status = "지나온 곳" if done else ("무슨 일이 일어날까?" if unlocked else "아직 갈 수 없습니다")
		"shop":
			status = "언제든 들를 수 있는 상점" if unlocked else "아직 갈 수 없습니다"
		"town":
			status = "쉬어 갈 수 있는 마을 (회복·저장)" if unlocked else "아직 갈 수 없습니다"
	panel_box.add_child(UIKit.label(status, 21, UIKit.MUTED))
	panel_box.add_child(UIKit.label(GameState.fill_text(str(n.get("desc", ""))), 23))
	if t == "battle" or t == "boss":
		panel_box.add_child(_enemy_icons(n))
		var rewards := PackedStringArray()
		var rw: Dictionary = n.get("rewards", {})
		if int(rw.get("gold", 0)) > 0:
			rewards.append("%d골드" % int(rw["gold"]))
		for item in rw.get("items", []):
			if GameData.equipment.has(str(item)):
				rewards.append(str(GameData.equipment[str(item)]["name"]))
		if not rewards.is_empty():
			panel_box.add_child(UIKit.label("첫 클리어 보상: " + ", ".join(rewards) + (" (받음)" if done else ""), 20, UIKit.GOOD))
	panel_box.add_child(UIKit.spacer())
	var action := "출발"
	var blocked := not unlocked
	match t:
		"battle", "boss":
			action = "다시 도전" if done else "출발"
		"event":
			action = "지나온 곳" if done else "살펴보기"
			blocked = blocked or done
		"shop":
			action = "상점 들어가기"
		"town":
			action = "마을 들어가기"
	panel_box.add_child(UIKit.button(action, _on_node_action, blocked or _busy))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.button("대륙 지도", _on_continent, _busy or GameData.chapters.size() < 2 or not GameState.chapter_complete(0)))
	row.add_child(UIKit.button("거점으로", _on_hub, _busy))
	panel_box.add_child(row)


## 등장하는 적의 초상화를 작은 카드로 나열 (보스·정령사는 금테, 무작위 정령은 "?")
func _enemy_icons(st: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var seen := {}
	for info in GameState.stage_preview(st):
		var key := str(info["key"])
		var boss := bool(info["boss"])
		if seen.has(key) and not boss:
			continue  # 같은 정령은 한 번만
		seen[key] = true
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.17, 0.19, 0.27)
		style.border_color = UIKit.GOLD if boss else Color(0.38, 0.42, 0.55)
		style.set_border_width_all(3 if boss else 2)
		style.set_corner_radius_all(10)
		card.add_theme_stylebox_override("panel", style)
		var tex := GameData.portrait_by_key(key)
		if tex != null:
			var pic := TextureRect.new()
			pic.texture = tex
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.flip_h = true  # 적은 왼쪽(주인공 쪽)을 바라보게
			card.add_child(pic)
		else:
			var q := UIKit.label("?", 34, UIKit.MUTED, true)
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(q)
		row.add_child(card)
		if row.get_child_count() >= 7:
			break
	return row


func _on_enter_region() -> void:
	var ci := _chapter_of_region(selected_region)
	if ci < 0 or not GameState.chapter_unlocked(ci):
		return
	chapter = ci
	_enter_mode("region")
	GameState.save_game()
	_busy = true
	await _play_chapter_intro()
	_busy = false
	_rebuild_panel()


func _on_continent() -> void:
	selected_region = GameState.chapter_element(chapter)
	_enter_mode("continent")
	GameState.save_game()


func _on_hub() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


## 고른 지점으로 정령사 말을 옮긴 뒤 그 지점의 일을 한다
func _on_node_action() -> void:
	if _busy:
		return
	var n: Dictionary = _nodes()[selected]
	_busy = true
	_rebuild_panel()
	var tw := create_tween()
	tw.tween_property(self, "token_pos", _node_pos(selected), 0.4).set_trans(Tween.TRANS_SINE)
	await tw.finished
	GameState.flags["pos_%d" % chapter] = str(n["id"])
	GameState.active_chapter = chapter
	match str(n.get("type", "battle")):
		"battle", "boss":
			await _play(str(n.get("dialogue_pre", "")))
			GameState.save_game()
			GameState.start_stage(n)
			return
		"event":
			await _open_event(n)
		"shop":
			GameState.mark_visited(str(n["id"]))
			_open_shop(n)
		"town":
			GameState.mark_visited(str(n["id"]))
			_open_town(n)
	_busy = false
	_rebuild_panel()


# ---------------------------------------------------------------- 겹쳐 뜨는 창 (상점·마을·이벤트)

func _open_overlay(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var vb := UIKit.screen(overlay, 90, 50, false)
	vb.add_child(UIKit.label(title, 36, UIKit.GOLD, true))
	return vb


func _close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null
	_rebuild_panel()


# ---- 상점: 몇 번 싸우고 오면 물건이 바뀐다. 사기 / 팔기(반값)

var shop_node: Dictionary = {}
var shop_tab := "buy"
var shop_msg := ""


func _open_shop(n: Dictionary) -> void:
	shop_node = n
	shop_tab = "buy"
	shop_msg = ""
	_rebuild_shop()


func _shop_stock() -> Array:
	var pool: Array = (shop_node.get("pool", []) as Array).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [str(shop_node["id"]), GameState.battles_won / 3])
	var stock: Array = []
	var count := mini(int(shop_node.get("count", 4)), pool.size())
	while stock.size() < count and not pool.is_empty():
		var i := rng.randi() % pool.size()
		var eid := str(pool[i])
		pool.remove_at(i)
		if GameData.equipment.has(eid):
			stock.append(eid)
	return stock


func _rebuild_shop() -> void:
	var vb := _open_overlay(GameState.fill_text(str(shop_node.get("name", "상점"))))
	vb.add_child(UIKit.label("보유 골드 %d" % GameState.gold, 26, UIKit.GOLD, true))
	if shop_msg != "":
		vb.add_child(UIKit.label(shop_msg, 22, UIKit.GOOD, true))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	tabs.add_child(UIKit.button("사기", _set_shop_tab.bind("buy"), shop_tab == "buy", 64))
	tabs.add_child(UIKit.button("팔기", _set_shop_tab.bind("sell"), shop_tab == "sell", 64))
	vb.add_child(tabs)
	var list := UIKit.scroll_list(vb)
	if shop_tab == "buy":
		list.add_child(UIKit.label("전투를 몇 번 하고 오면 물건이 바뀝니다.", 20, UIKit.MUTED))
		for o in _shop_stock():
			var eid := str(o)
			var price := GameData.equipment_price(eid)
			list.add_child(_shop_row(eid, "%d골드" % price, "사기", _buy.bind(eid), GameState.gold < price))
	else:
		var counts := {}
		for o in GameState.inventory:
			counts[str(o)] = int(counts.get(str(o), 0)) + 1
		if counts.is_empty():
			list.add_child(UIKit.label("팔 수 있는 장비가 없습니다. (장착 중인 장비는 팔 수 없어요)", 22, UIKit.MUTED))
		for eid in counts:
			var sell := GameData.equipment_price(str(eid)) / 2
			list.add_child(_shop_row(str(eid), "×%d · %d골드" % [int(counts[eid]), sell], "팔기", _sell.bind(str(eid)), false))
	vb.add_child(UIKit.button("나가기", _close_overlay))


func _shop_row(eid: String, price_text: String, verb: String, cb: Callable, disabled: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var e: Dictionary = GameData.equipment[eid]
	var info := UIKit.label("%s [%s]\n%s · %s" % [e["name"], GameData.SLOT_NAMES.get(str(e["slot"]), ""),
		GameData.bonus_text(e["bonus"]), price_text], 22)
	row.add_child(info)
	var b := UIKit.button(verb, cb, disabled, 70)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(130, 70)
	row.add_child(b)
	return row


func _set_shop_tab(tab: String) -> void:
	shop_tab = tab
	shop_msg = ""
	_rebuild_shop.call_deferred()


func _buy(eid: String) -> void:
	var price := GameData.equipment_price(eid)
	if GameState.gold < price:
		return
	GameState.gold -= price
	GameState.inventory.append(eid)
	GameState.save_game()
	shop_msg = "%s을(를) 샀습니다." % GameData.equipment[eid]["name"]
	_rebuild_shop.call_deferred()


func _sell(eid: String) -> void:
	if not GameState.inventory.has(eid):
		return
	GameState.inventory.erase(eid)
	var price := GameData.equipment_price(eid) / 2
	GameState.gold += price
	GameState.save_game()
	shop_msg = "%s을(를) %d골드에 팔았습니다." % [GameData.equipment[eid]["name"], price]
	_rebuild_shop.call_deferred()


# ---- 마을: 여관에서 회복·저장, 거점으로

func _open_town(n: Dictionary) -> void:
	var vb := _open_overlay(GameState.fill_text(str(n.get("name", "마을"))))
	vb.add_child(UIKit.label(GameState.fill_text(str(n.get("desc", ""))), 24, Color.WHITE, true))
	vb.add_child(UIKit.spacer())
	vb.add_child(UIKit.button("여관에서 쉬기 (모두 회복 · 저장)", _rest.bind(vb)))
	vb.add_child(UIKit.button("거점으로 (정령·장비 정리)", _on_hub))
	vb.add_child(UIKit.button("나가기", _close_overlay))


func _rest(vb: VBoxContainer) -> void:
	GameState.heal_all()
	GameState.save_game()
	vb.add_child(UIKit.label("푹 쉬었다. 정령사와 정령들이 모두 회복했다!", 24, UIKit.GOOD, true))


# ---- 이벤트: 대화 → 선택지 → 결과 (한 번만)

func _open_event(n: Dictionary) -> void:
	await _play(str(n.get("lines", "")))
	var vb := _open_overlay(GameState.fill_text(str(n.get("name", "이벤트"))))
	vb.add_child(UIKit.label(GameState.fill_text(str(n.get("desc", ""))), 24, Color.WHITE, true))
	vb.add_child(UIKit.spacer())
	for o in n.get("choices", []):
		var choice: Dictionary = o
		vb.add_child(UIKit.button(GameState.fill_text(str(choice.get("label", ""))), _choose_event.bind(n, choice)))


func _choose_event(n: Dictionary, choice: Dictionary) -> void:
	GameState.mark_visited(str(n["id"]))
	var lines := PackedStringArray([GameState.fill_text(str(choice.get("result", "")))])
	var battle: Dictionary = {}
	for o in choice.get("effects", []):
		var eff: Dictionary = o
		if eff.has("gold"):
			GameState.gold += int(eff["gold"])
		if eff.has("item") and GameData.equipment.has(str(eff["item"])):
			GameState.inventory.append(str(eff["item"]))
			lines.append("장비 획득: %s" % GameData.equipment_desc(str(eff["item"])))
		if eff.has("heal"):
			GameState.heal_all()
			lines.append("모두 회복했다.")
		if eff.has("spirit"):
			var sd: Dictionary = eff["spirit"]
			var s := Spirit.create(GameState.resolve_species(str(sd["species"])), int(sd.get("level", 1)))
			lines.append("%s 계약 완료 → %s" % [s.display_name(), GameState.add_captured(s)])
		if eff.has("battle"):
			battle = eff["battle"]
	GameState.save_game()
	var vb := _open_overlay(GameState.fill_text(str(n.get("name", "이벤트"))))
	vb.add_child(UIKit.label("\n".join(lines), 24, Color.WHITE, true))
	vb.add_child(UIKit.spacer())
	if battle.is_empty():
		vb.add_child(UIKit.button("확인", _close_overlay))
	else:
		var stage := {"id": str(n["id"]) + "_battle", "name": str(battle.get("name", n.get("name", ""))),
			"enemies": battle.get("enemies", [])}
		vb.add_child(UIKit.button("싸운다!", func(): GameState.start_stage(stage)))
