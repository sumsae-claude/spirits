class_name EquipEditor
extends VBoxContainer
## 장비 칸 편집 (거점 상세·전투 소환 창 공통): 무기/장신구 칸을 누르면 가진 장비 목록이 열리고,
## 장비마다 지금 장비와 비교한 능력치 변화(공+3▲ 속-1▼)를 보여 준다. 고르면 바로 착용, '해제'도 가능.

signal changed

var spirit: Spirit = null
var picking := ""
var compact := false   # 전투 소환 창: 글자 작게


func set_spirit(s: Spirit) -> void:
	if s != spirit:
		picking = ""
	spirit = s
	_rebuild()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rebuild()


func _rebuild() -> void:
	UIKit.clear(self)
	if spirit == null:
		return
	var fs := 19 if compact else 23
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for slot in GameData.SLOTS:
		var eid := str(spirit.equipment.get(slot, ""))
		var name_text := str(GameData.equipment[eid]["name"]) if GameData.equipment.has(eid) else "비어 있음"
		var b := UIKit.button("%s %s\n%s" % ["▾" if picking == slot else "▸", GameData.SLOT_NAMES[slot], name_text],
			_toggle.bind(slot), false, 62 if compact else 72)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", fs)
		if picking == slot:
			b.add_theme_color_override("font_color", UIKit.GOLD)
		row.add_child(b)
	if picking != "":
		_build_picker(picking, fs)


func _build_picker(slot: String, fs: int) -> void:
	var current := str(spirit.equipment.get(slot, ""))
	var counts := {}
	for item in GameState.inventory:
		if GameData.equipment.has(str(item)) and str(GameData.equipment[str(item)]["slot"]) == slot:
			counts[str(item)] = int(counts.get(str(item), 0)) + 1
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	for item in counts:
		var e: Dictionary = GameData.equipment[item]
		var b := UIKit.button("%s ×%d   %s" % [e["name"], int(counts[item]), _diff_text(current, str(item))],
			_equip.bind(str(item)), false, 52 if compact else 60)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", fs - 1)
		box.add_child(b)
	if current != "":
		var ub := UIKit.button("장비 해제", _unequip.bind(slot), false, 48 if compact else 56)
		ub.focus_mode = Control.FOCUS_NONE
		ub.add_theme_font_size_override("font_size", fs - 1)
		box.add_child(ub)
	if counts.is_empty() and current == "":
		box.add_child(UIKit.label("가진 %s이(가) 없습니다." % GameData.SLOT_NAMES[slot], fs - 2, UIKit.MUTED))


## 지금 장비 → 새 장비로 바꿀 때 능력치 변화: "공+3▲ 속-1▼"
static func _diff_text(current: String, new_eid: String) -> String:
	var cur: Dictionary = GameData.equipment[current]["bonus"] if GameData.equipment.has(current) else {}
	var nxt: Dictionary = GameData.equipment[new_eid]["bonus"] if GameData.equipment.has(new_eid) else {}
	var parts := PackedStringArray()
	for key in Spirit.STAT_KEYS:
		var d := int(nxt.get(key, 0)) - int(cur.get(key, 0))
		if d != 0:
			parts.append("%s%s%d%s" % [str(Spirit.STAT_NAMES[key]).left(1), "+" if d > 0 else "-", absi(d), "▲" if d > 0 else "▼"])
	return " ".join(parts) if not parts.is_empty() else "변화 없음"


func _toggle(slot: String) -> void:
	picking = "" if picking == slot else slot
	_rebuild.call_deferred()


func _equip(eid: String) -> void:
	GameState.equip(spirit, eid)
	picking = ""
	GameState.save_game()
	_rebuild.call_deferred()
	changed.emit()


func _unequip(slot: String) -> void:
	GameState.unequip(spirit, slot)
	picking = ""
	GameState.save_game()
	_rebuild.call_deferred()
	changed.emit()
