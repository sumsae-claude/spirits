class_name CraftScreen
extends ColorRect
## 가방 · 합성 창 (거점 첫 화면 / 마을에서 연다).
## 가방의 아이템을 눌러 솥에 넣고 '합성하기'. 레시피는 비공개 — 맞는 조합이면 결과물이 나오고
## '알게 된 레시피'에 기록된다. 틀리면 재료 하나를 잃는다. 솥에는 3종류·5개까지.

signal closed

const MAX_KINDS := 3
const MAX_PIECES := 5

var mix: Dictionary = {}     # id -> 개수
var message := ""
var message_color := UIKit.GOOD
var _body: VBoxContainer


static func open(parent: Node) -> CraftScreen:
	var w := CraftScreen.new()
	parent.add_child(w)
	return w


func _ready() -> void:
	color = Color(0.02, 0.02, 0.05, 0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GameData.theme
	_body = UIKit.screen(self, 56, 32, false)
	_rebuild()


func _pieces() -> int:
	var n := 0
	for k in mix:
		n += int(mix[k])
	return n


func _rebuild() -> void:
	UIKit.clear(_body)
	_body.add_child(UIKit.label("가방 · 합성", 38, UIKit.GOLD, true))
	_body.add_child(UIKit.label("재료를 골라 솥에 넣고 합성해 보세요. 레시피는 직접 찾아야 합니다. (틀리면 재료 1개를 잃음)", 19, UIKit.MUTED, true))
	if message != "":
		_body.add_child(UIKit.label(message, 22, message_color, true))

	# 솥
	var pot := HBoxContainer.new()
	pot.add_theme_constant_override("separation", 6)
	_body.add_child(pot)
	if mix.is_empty():
		pot.add_child(UIKit.label("솥이 비어 있습니다. 아래 가방에서 눌러 넣으세요.", 21, UIKit.MUTED))
	for k in mix:
		var b := UIKit.button("%s ×%d ✕" % [GameData.item_name(str(k)), int(mix[k])], _take.bind(str(k)), false, 56)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 19)
		pot.add_child(b)
	var go := UIKit.button("⚗ 합성하기 (%d/%d개)" % [_pieces(), MAX_PIECES], _craft, mix.is_empty(), 64)
	go.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_body.add_child(go)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size = Vector2(16, 0)
	_body.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# 가방 (종류별)
	var counts := {}
	for o in GameState.inventory:
		counts[str(o)] = int(counts.get(str(o), 0)) + 1
	for kind in ["material", "tool", "equip"]:
		var ids := []
		for iid in counts:
			if GameData.item_kind(iid) == kind:
				ids.append(iid)
		if ids.is_empty():
			continue
		ids.sort()
		list.add_child(UIKit.label("%s" % GameData.KIND_NAMES[kind], 26, UIKit.GOLD))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 6)
		list.add_child(grid)
		for iid in ids:
			var left := int(counts[iid]) - int(mix.get(iid, 0))
			var b := UIKit.button("%s ×%d" % [GameData.item_name(iid), left], _put.bind(iid), left <= 0, 54)
			b.focus_mode = Control.FOCUS_NONE
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = GameData.item_info(iid)
			b.add_theme_font_size_override("font_size", 20)
			var el := str(GameData.items[iid].get("element", ""))
			if el != "":
				b.add_theme_color_override("font_color", GameData.element_color(el).lightened(0.35))
			grid.add_child(b)
	if counts.is_empty():
		list.add_child(UIKit.label("가방이 비어 있습니다.", 22, UIKit.MUTED))

	# 알게 된 레시피
	list.add_child(UIKit.label("알게 된 레시피 (%d/%d)" % [GameState.known_recipes.size(), GameData.recipes.size()], 26, UIKit.GOLD))
	if GameState.known_recipes.is_empty():
		list.add_child(UIKit.label("아직 없습니다. 이것저것 섞어 보세요. 약초 두 개라면…?", 20, UIKit.MUTED))
	for ri in GameState.known_recipes:
		if int(ri) >= GameData.recipes.size():
			continue
		var r: Dictionary = GameData.recipes[int(ri)]
		var parts := PackedStringArray()
		var can := true
		for k in r["in"]:
			parts.append("%s×%d" % [GameData.item_name(str(k)), int(r["in"][k])])
			if int(counts.get(str(k), 0)) < int(r["in"][k]):
				can = false
		var b := UIKit.button("%s → %s" % [" + ".join(parts), GameData.item_name(str(r["out"]))], _fill.bind(int(ri)), not can, 54)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 19)
		list.add_child(b)
	_body.add_child(UIKit.button("닫기", _close))


func _put(iid: String) -> void:
	if not mix.has(iid) and mix.size() >= MAX_KINDS:
		_say("솥에는 %d종류까지 넣을 수 있습니다." % MAX_KINDS, UIKit.BAD)
		return
	if _pieces() >= MAX_PIECES:
		_say("솥에는 %d개까지 넣을 수 있습니다." % MAX_PIECES, UIKit.BAD)
		return
	mix[iid] = int(mix.get(iid, 0)) + 1
	message = ""
	_rebuild.call_deferred()


func _take(iid: String) -> void:
	mix[iid] = int(mix.get(iid, 0)) - 1
	if int(mix[iid]) <= 0:
		mix.erase(iid)
	_rebuild.call_deferred()


func _fill(ri: int) -> void:
	mix = (GameData.recipes[ri]["in"] as Dictionary).duplicate()
	message = ""
	_rebuild.call_deferred()


func _craft() -> void:
	var res := GameState.craft(mix)
	if res.has("error"):
		_say(str(res["error"]), UIKit.BAD)
		return
	if bool(res["ok"]):
		var out := str(res["out"])
		_say("성공! %s을(를) 만들었습니다.%s" % [GameData.item_name(out), "  ✦ 새 레시피를 알게 되었다!" if bool(res.get("new", false)) else ""], UIKit.GOOD)
		# 같은 조합을 또 할 수 있으면 솥을 그대로 둔다
		for k in mix:
			if GameState.item_count(str(k)) < int(mix[k]):
				mix = {}
				break
	else:
		_say("실패… 아무 일도 일어나지 않았다. (%s 1개를 잃음)" % GameData.item_name(str(res["lost"])), UIKit.BAD)
		mix = {}


func _say(text: String, col: Color) -> void:
	message = text
	message_color = col
	_rebuild.call_deferred()


func _close() -> void:
	closed.emit()
	queue_free()
