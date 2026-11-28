class_name EquipEditor
extends VBoxContainer
## 소지창 편집 (거점 상세·전투 소환 창 공통): 3칸에 장비·도구 아무거나.
## 칸을 누르면 가방의 장비·도구 목록이 열리고, 장비는 지금 칸의 것과 비교한 능력치 변화(공+3▲)를 보여 준다.
## 같은 장비 여러 개 가능 (능력치는 쌓임, 특수 효과는 전투마다 한 번). 재료는 가방에만.

signal changed

var spirit: Spirit = null
var picking := -1
var compact := false   # 전투 소환 창: 글자 작게


func set_spirit(s: Spirit) -> void:
	if s != spirit:
		picking = -1
	spirit = s
	_rebuild()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rebuild()


func _rebuild() -> void:
	UIKit.clear(self)
	if spirit == null:
		return
	var fs := 18 if compact else 22
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	for i in GameData.HOLD_SLOTS:
		var iid := str(spirit.items[i])
		var kind := GameData.item_kind(iid)
		var tag := "" if iid == "" else ("[도구]" if kind == "tool" else "[장비]")
		var b := UIKit.button("%s %d %s\n%s" % ["▾" if picking == i else "▸", i + 1, tag, GameData.item_name(iid) if iid != "" else "비어 있음"],
			_toggle.bind(i), false, 62 if compact else 72)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", fs)
		if picking == i:
			b.add_theme_color_override("font_color", UIKit.GOLD)
		elif kind == "tool":
			b.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
		row.add_child(b)
	if picking >= 0:
		_build_picker(picking, fs)


func _build_picker(idx: int, fs: int) -> void:
	var current := str(spirit.items[idx])
	var counts := {}
	var order := []
	for item in GameState.inventory:
		var iid := str(item)
		if GameData.holdable(iid):
			if not counts.has(iid):
				order.append(iid)
			counts[iid] = int(counts.get(iid, 0)) + 1
	order.sort_custom(func(a, b): return GameData.item_kind(a) < GameData.item_kind(b))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	if current != "":
		box.add_child(UIKit.label(GameData.item_info(current), fs - 3, UIKit.MUTED))
	for iid in order:
		var e: Dictionary = GameData.items[iid]
		var extra := _diff_text(current, iid) if GameData.item_kind(iid) == "equip" else "도구 · " + str(e.get("desc", ""))
		if e.has("special"):
			extra += " · " + GameData.special_name(str(e["special"]))
		var b := UIKit.button("%s ×%d   %s" % [e["name"], int(counts[iid]), extra], _equip.bind(iid), false, 52 if compact else 60)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", fs - 1)
		if GameData.item_kind(iid) == "tool":
			b.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
		box.add_child(b)
	if current != "":
		var ub := UIKit.button("가방에 넣기 (칸 비우기)", _unequip.bind(idx), false, 48 if compact else 56)
		ub.focus_mode = Control.FOCUS_NONE
		ub.add_theme_font_size_override("font_size", fs - 1)
		box.add_child(ub)
	if order.is_empty() and current == "":
		box.add_child(UIKit.label("가방에 장비·도구가 없습니다.", fs - 2, UIKit.MUTED))


## 지금 칸의 것 → 새 장비로 바꿀 때 능력치 변화: "공+3▲ 속-1▼"
static func _diff_text(current: String, new_eid: String) -> String:
	var cur: Dictionary = GameData.equipment[current].get("bonus", {}) if GameData.equipment.has(current) else {}
	var nxt: Dictionary = GameData.equipment[new_eid].get("bonus", {}) if GameData.equipment.has(new_eid) else {}
	var parts := PackedStringArray()
	for key in Spirit.STAT_KEYS:
		var d := int(nxt.get(key, 0)) - int(cur.get(key, 0))
		if d != 0:
			parts.append("%s%s%d%s" % [str(Spirit.STAT_NAMES[key]).left(1), "+" if d > 0 else "-", absi(d), "▲" if d > 0 else "▼"])
	return " ".join(parts) if not parts.is_empty() else "능력치 변화 없음"


func _toggle(idx: int) -> void:
	picking = -1 if picking == idx else idx
	_rebuild.call_deferred()


func _equip(eid: String) -> void:
	GameState.equip(spirit, eid, picking)
	picking = -1
	GameState.save_game()
	_rebuild.call_deferred()
	changed.emit()


func _unequip(idx: int) -> void:
	GameState.unequip(spirit, idx)
	picking = -1
	GameState.save_game()
	_rebuild.call_deferred()
	changed.emit()
