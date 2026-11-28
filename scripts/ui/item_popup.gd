class_name ItemPopup
extends ColorRect
## 아이템을 얻었을 때 가운데에 뜨는 팝업: 아이템마다 아이콘 + 이름 + 종류 + 설명, "가방에 들어감".
## 누르면 닫힌다. await ItemPopup.show_items(parent, ["herb", ...], "보물 상자를 열었다!")
## 테스트: ItemPopup.auto_close = true 이면 잠깐 뒤 저절로 닫힌다.

signal closed

static var auto_close := false

const KIND_COLORS := {"equip": Color(1.0, 0.82, 0.4), "tool": Color(0.78, 0.6, 1.0), "material": Color(0.55, 0.9, 0.6)}


static func show_items(parent: Node, ids: Array, title: String, note: String = "가방에 들어갔다") -> void:
	if ids.is_empty() or parent == null or not parent.is_inside_tree():
		return
	var p := ItemPopup.new()
	parent.add_child(p)
	p._build(ids, title, note)
	var old := Engine.time_scale
	Engine.time_scale = 1.0
	if auto_close:
		p.get_tree().create_timer(0.2).timeout.connect(p._close)
	await p.closed
	Engine.time_scale = old


## 아이템 아이콘 (그림이 없으면 종류 색 동그라미 + 이름 첫 글자)
static func icon_for(iid: String, size: float = 56.0) -> Control:
	var kind := GameData.item_kind(iid)
	var col: Color = KIND_COLORS.get(kind, Color.WHITE)
	var el := str(GameData.items.get(iid, {}).get("element", ""))
	if el != "":
		col = GameData.element_color(el).lightened(0.25)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(size, size)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(col, 0.22)
	st.border_color = col
	st.set_border_width_all(3)
	st.set_corner_radius_all(int(size * 0.5) if kind == "material" else 10)
	panel.add_theme_stylebox_override("panel", st)
	var l := UIKit.label(GameData.item_name(iid).left(1), int(size * 0.45), col.lightened(0.3), true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(l)
	return panel


func _build(ids: Array, title: String, note: String) -> void:
	color = Color(0, 0, 0, 0.5)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GameData.theme
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.1, 0.15, 0.98)
	st.border_color = UIKit.GOLD
	st.set_border_width_all(3)
	st.set_corner_radius_all(16)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	st.shadow_color = Color(0, 0, 0, 0.6)
	st.shadow_size = 12
	panel.add_theme_stylebox_override("panel", st)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vb)
	vb.add_child(UIKit.label(title, 26, UIKit.GOLD, true))
	# 같은 아이템은 묶어서 ×n
	var counts := {}
	var order := []
	for o in ids:
		var iid := str(o)
		if not counts.has(iid):
			order.append(iid)
		counts[iid] = int(counts.get(iid, 0)) + 1
	for iid in order:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)
		row.add_child(icon_for(iid))
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		var kind := GameData.item_kind(iid)
		var head := "%s%s  [%s]" % [GameData.item_name(iid), (" ×%d" % int(counts[iid])) if int(counts[iid]) > 1 else "",
			GameData.KIND_NAMES.get(kind, "")]
		txt.add_child(UIKit.label(head, 22, KIND_COLORS.get(kind, Color.WHITE)))
		var desc := str(GameData.items.get(iid, {}).get("desc", ""))
		if kind == "equip":
			desc = GameData.equipment_desc(iid).trim_prefix(GameData.item_name(iid) + " ") + " · " + desc
		txt.add_child(UIKit.label(desc, 17, UIKit.MUTED))
	vb.add_child(UIKit.label(note + " · 눌러서 닫기", 17, UIKit.MUTED, true))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		_close()


func _close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()
