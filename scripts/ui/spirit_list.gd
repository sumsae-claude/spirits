class_name SpiritList
extends VBoxContainer
## 정령 목록 (보관함·소환 창 공통): 위에 속성 탭(전체/불/물/바람/풀) + 정렬 버튼, 아래에 카드.
## 고른 탭·정렬은 GameState.flags에 기억해 다음에 열 때도 그대로.
##
## 사용:
##   var sl := SpiritList.new()
##   sl.setup("hub", spirits, info_fn, ["기본순", "레벨순", "이름순"])
##   sl.picked.connect(func(s): ...)
## info_fn(s: Spirit) -> {"line": 둘째 줄 글, "disabled": bool, "score": 기본/추천 정렬 점수(클수록 위),
##                        "tag": 이름 옆 표시, "gold": 강조(금색) 여부, "selected": 선택 표시}

signal picked(spirit)

const ELEMENTS := ["all", "fire", "water", "wind", "grass"]

var context := "list"
var spirits: Array = []
var info_fn: Callable
var sort_names: Array = ["기본순", "레벨순", "이름순"]
var columns := 2
var card_height := 66.0

var _tabs: HBoxContainer
var _grid: GridContainer
var _scroll: ScrollContainer
## 끌어서 스크롤: 카드 위에서 끌어도 목록이 움직이고, 끈 뒤 손을 떼면 선택되지 않게
const TAP_SLOP := 14.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false


func setup(p_context: String, p_spirits: Array, p_info_fn: Callable, p_sort_names: Array = ["기본순", "레벨순", "이름순"]) -> void:
	context = p_context
	spirits = p_spirits
	info_fn = p_info_fn
	sort_names = p_sort_names
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	add_child(_tabs)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = int(TAP_SLOP)
	scroll.gui_input.connect(_on_scroll_input)
	scroll.get_v_scroll_bar().custom_minimum_size = Vector2(16, 0)  # 잡기 쉽게 굵은 스크롤 막대
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_rebuild()


func filter() -> String:
	return str(GameState.flags.get("list_filter_" + context, "all"))


func sort_mode() -> int:
	return clampi(int(GameState.flags.get("list_sort_" + context, 0)), 0, sort_names.size() - 1)


## 기본 방향을 뒤집었는가 (기본: 점수·레벨은 높은 순, 이름은 가나다순)
func reversed() -> bool:
	return bool(GameState.flags.get("list_rev_" + context, false))


## 지금 보이는 방향이 내림차순인가 (버튼 표시용)
func _is_descending() -> bool:
	var natural_desc := sort_mode() != 2   # 이름순만 기본이 오름차순
	return natural_desc != reversed()


func refresh() -> void:
	_rebuild()


func _rebuild() -> void:
	if _grid == null:
		return
	UIKit.clear(_tabs)
	UIKit.clear(_grid)
	var counts := {"all": spirits.size()}
	for o in spirits:
		var el := (o as Spirit).element()
		counts[el] = int(counts.get(el, 0)) + 1
	for key in ELEMENTS:
		var label := "전체" if key == "all" else GameData.element_name(key)
		var tb := _pill("%s %d" % [label, int(counts.get(key, 0))], key == filter(),
			GameData.element_color(key).lightened(0.35) if key != "all" else UIKit.GOLD)
		tb.pressed.connect(_set_filter.bind(key))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs.add_child(tb)
	var sb := _pill("⇅ " + str(sort_names[sort_mode()]), false, Color(0.85, 0.9, 1.0))
	sb.pressed.connect(_next_sort)
	sb.custom_minimum_size = Vector2(108, 44)
	_tabs.add_child(sb)
	var db := _pill("▼" if _is_descending() else "▲", false, Color(0.85, 0.9, 1.0))
	db.tooltip_text = "내림차순" if _is_descending() else "오름차순"
	db.pressed.connect(_flip_dir)
	db.custom_minimum_size = Vector2(48, 44)
	_tabs.add_child(db)

	var entries: Array = []
	for o in spirits:
		var s: Spirit = o
		if filter() != "all" and s.element() != filter():
			continue
		var info: Dictionary = info_fn.call(s) if info_fn.is_valid() else {}
		entries.append({"s": s, "info": info})
	entries.sort_custom(_before)
	for o in entries:
		_grid.add_child(_card(o["s"], o["info"]))
	if entries.is_empty():
		_grid.add_child(UIKit.label("이 속성의 정령이 없습니다.", 20, UIKit.MUTED))


## 정렬: 쓸 수 없는 정령은 방향과 상관없이 늘 아래. 0 = 기본/추천(점수), 1 = 레벨, 2 = 이름
func _before(a: Dictionary, b: Dictionary) -> bool:
	var da := bool((a["info"] as Dictionary).get("disabled", false))
	var db := bool((b["info"] as Dictionary).get("disabled", false))
	if da != db:
		return db
	if reversed():
		return _natural_before(b, a)
	return _natural_before(a, b)


func _natural_before(a: Dictionary, b: Dictionary) -> bool:
	var sa: Spirit = a["s"]
	var sb: Spirit = b["s"]
	match sort_mode():
		1:
			if sa.level != sb.level:
				return sa.level > sb.level
			return sa.display_name() < sb.display_name()
		2:
			if sa.display_name() != sb.display_name():
				return sa.display_name() < sb.display_name()
			return sa.level > sb.level
	var pa := int((a["info"] as Dictionary).get("score", 0))
	var pb := int((b["info"] as Dictionary).get("score", 0))
	if pa != pb:
		return pa > pb
	return sa.level > sb.level


func _card(s: Spirit, info: Dictionary) -> Button:
	var b := Button.new()
	var tag := str(info.get("tag", ""))
	b.text = "%s Lv%d%s\n%s" % [s.display_name(), s.level, ("  " + tag) if tag != "" else "",
		str(info.get("line", "HP %d/%d" % [s.hp, s.max_hp()]))]
	b.icon = GameData.sprite_for(s)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 48)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, card_height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55) if bool(info.get("gold", false)) else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.66, 0.55))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.2, 0.19, 0.12) if bool(info.get("selected", false)) else Color(0.13, 0.14, 0.2)
	st.border_color = GameData.element_color(s.element()).darkened(0.1)
	st.border_width_left = 5
	if bool(info.get("selected", false)):
		st.border_color = UIKit.GOLD
		st.set_border_width_all(3)
		st.border_width_left = 5
	st.set_corner_radius_all(8)
	st.content_margin_left = 10
	b.add_theme_stylebox_override("normal", st)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = st.bg_color.lightened(0.08)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("disabled", st)
	b.disabled = bool(info.get("disabled", false))
	# 카드 위에서 끌어도 스크롤되게 터치를 목록으로 넘기고, 끈 경우엔 선택하지 않는다
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.gui_input.connect(_on_card_input)
	b.pressed.connect(func():
		if not _dragged:
			picked.emit(s))
	return b


func _on_card_input(event: InputEvent) -> void:
	_track_drag(event)


func _on_scroll_input(event: InputEvent) -> void:
	_track_drag(event)
	# 마우스(PC)로 끌 때도 스크롤 (터치 화면은 ScrollContainer가 스스로 처리)
	if _pressing and event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		if _dragged:
			_scroll.scroll_vertical -= int((event as InputEventMouseMotion).relative.y)


func _track_drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_pressing = true
			_dragged = false
			_press_pos = mb.global_position
		else:
			_pressing = false
			if mb.global_position.distance_to(_press_pos) > TAP_SLOP:
				_dragged = true
	elif event is InputEventMouseMotion and _pressing:
		if (event as InputEventMouseMotion).global_position.distance_to(_press_pos) > TAP_SLOP:
			_dragged = true


func _pill(text: String, selected: bool, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.2))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.3, 0.24, 0.1, 0.95) if selected else Color(0.07, 0.08, 0.12, 0.85)
	st.border_color = UIKit.GOLD if selected else UIKit.GOLD.darkened(0.45)
	st.set_border_width_all(2)
	st.set_corner_radius_all(22)
	st.content_margin_left = 8
	st.content_margin_right = 8
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _set_filter(key: String) -> void:
	GameState.flags["list_filter_" + context] = key
	_rebuild.call_deferred()


func _flip_dir() -> void:
	GameState.flags["list_rev_" + context] = not reversed()
	_rebuild.call_deferred()


func _next_sort() -> void:
	GameState.flags["list_sort_" + context] = (sort_mode() + 1) % sort_names.size()
	_rebuild.call_deferred()
