class_name SaveSlots
extends ColorRect
## 저장 / 불러오기 창: 자동 저장 칸(0) + 슬롯 1~99.
## 사용: SaveSlots.open(parent, "save")  /  SaveSlots.open(parent, "load")
## 불러오기에 성공하면 월드맵으로 간다. 이미 쓴 슬롯에 저장하면 한 번 더 눌러 덮어쓰기 확인.

signal closed

var mode := "save"
var pending := -1        # 덮어쓰기 확인 중인 슬롯
var message := ""
var _list: VBoxContainer
var _msg_label: Label


static func open(parent: Node, p_mode: String) -> SaveSlots:
	var w := SaveSlots.new()
	w.mode = p_mode
	parent.add_child(w)
	return w


func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GameData.theme
	var vb := UIKit.screen(self, 70, 40, false)
	vb.add_child(UIKit.label("저장하기" if mode == "save" else "불러오기", 38, UIKit.GOLD, true))
	_msg_label = UIKit.label("", 22, UIKit.GOOD, true)
	vb.add_child(_msg_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size = Vector2(16, 0)
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	vb.add_child(UIKit.button("닫기", _close))
	_rebuild()


func _rebuild() -> void:
	UIKit.clear(_list)
	_msg_label.text = message
	_msg_label.visible = message != ""
	var start := 0 if mode == "load" else 1   # 자동 저장 칸에는 직접 저장하지 않는다
	if mode == "save":
		_list.add_child(UIKit.label("자동 저장은 전투 후·지도 이동 때 따로 남습니다.", 19, UIKit.MUTED, true))
	for i in range(start, GameState.SAVE_SLOTS + 1):
		var info := GameState.slot_info(i)
		if mode == "load" and info.is_empty():
			continue
		_list.add_child(_slot_button(i, info))
	if mode == "load" and _list.get_child_count() == 0:
		_list.add_child(UIKit.label("저장된 데이터가 없습니다.", 22, UIKit.MUTED, true))


func _slot_button(i: int, info: Dictionary) -> Button:
	var head := "자동 저장" if i == 0 else "슬롯 %02d" % i
	var text := ""
	if info.is_empty():
		text = "%s\n— 비어 있음 —" % head
	elif bool(info.get("broken", false)):
		text = "%s\n(읽을 수 없는 데이터)" % head
	else:
		text = "%s   %s\n%s(%s) Lv.%d · %s %s · %d골드 · 정령 %d" % [head, str(info.get("time", "")),
			str(info.get("name", "")), GameData.element_name(str(info.get("element", ""))), int(info.get("level", 1)),
			str(info.get("chapter", "")), str(info.get("region", "")), int(info.get("gold", 0)), int(info.get("spirits", 0))]
	if mode == "save" and pending == i:
		text = "%s\n▶ 한 번 더 누르면 덮어씁니다" % head
	var b := UIKit.button(text, _on_slot.bind(i, info.is_empty()), mode == "load" and bool(info.get("broken", false)), 92)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	if not info.is_empty():
		b.add_theme_color_override("font_color", GameData.element_color(str(info.get("element", ""))).lightened(0.45))
	if pending == i:
		b.add_theme_color_override("font_color", UIKit.GOLD)
	return b


func _on_slot(i: int, empty: bool) -> void:
	if mode == "save":
		if not empty and pending != i:
			pending = i
			message = ""
			_rebuild.call_deferred()
			return
		GameState.save_to_slot(i)
		pending = -1
		message = "슬롯 %02d에 저장했습니다." % i
		_rebuild.call_deferred()
	else:
		if GameState.load_slot(i):
			get_tree().change_scene_to_file("res://scenes/world_map.tscn")
		else:
			message = "불러오지 못했습니다."
			_rebuild.call_deferred()


func _close() -> void:
	closed.emit()
	queue_free()
