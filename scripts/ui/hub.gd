extends Control
## 거점 화면: 정령사 정보, 계약 정령/보관함 관리, 선봉 지정, 장비 장착, 전투 출발.

var selected: Spirit = null
var picking_slot := ""
var message := ""


func _ready() -> void:
	theme = GameData.theme
	message = GameState.hub_message
	GameState.hub_message = ""
	_rebuild()


func _refresh() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	UIKit.clear(self)
	var vb := UIKit.screen(self, 56, 36)
	if selected == null:
		_build_list(vb)
	else:
		_build_detail(vb)


# ---------------------------------------------------------------- 목록

func _build_list(vb: VBoxContainer) -> void:
	vb.add_child(UIKit.label("거점", 44, UIKit.GOLD))
	vb.add_child(UIKit.label("승리 %d회 · 파티 평균 Lv.%d · 보유 장비 %d개" % [
		GameState.battles_won, GameState.average_party_level(), GameState.inventory.size()], 22, UIKit.MUTED))
	if message != "":
		vb.add_child(UIKit.label(message, 22, UIKit.GOOD))

	var list := UIKit.scroll_list(vb)
	list.add_child(UIKit.label("상성: " + GameData.element_chart_text(), 20, UIKit.GOLD))
	list.add_child(UIKit.label("정령사 (가장 중요! 쓰러지면 패배)", 28))
	list.add_child(_summoner_card())
	list.add_child(UIKit.label("계약 정령 (%d/%d) — 전투에서 소환 가능, ★ 선봉은 자동 소환" % [
		GameState.party.size(), GameState.MAX_PARTY], 26))
	for i in GameState.party.size():
		list.add_child(_spirit_button(GameState.party[i], i == 0))
	list.add_child(UIKit.label("보관함 (%d)" % GameState.storage.size(), 30))
	if GameState.storage.is_empty():
		list.add_child(UIKit.label("비어 있음 — 전투에서 야생 정령을 디스펠해 계약하세요.", 22, UIKit.MUTED))
	for s in GameState.storage:
		list.add_child(_spirit_button(s))

	var adv := UIKit.button("모험 — %s" % str(GameData.chapter1.get("title", "1장")), _on_adventure, false, 84)
	adv.add_theme_font_size_override("font_size", 30)
	adv.add_theme_color_override("font_color", UIKit.GOLD)
	vb.add_child(adv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.button("사냥터 (야생)", _on_explore))
	row.add_child(UIKit.button("연습 대결", _on_rival))
	vb.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	row2.add_child(UIKit.button("저장", _on_save, false, 64))
	row2.add_child(UIKit.button("타이틀", _on_title, false, 64))
	vb.add_child(row2)


## 정령사 카드: 누르면 상세(장비 변경) 화면
func _summoner_card() -> Button:
	var m := GameState.summoner
	var text := "%s\nHP %d · MP %d · 공 %d · 방 %d · 이동 %d   EXP %d/%d\n동시 소환 %d · 장비: %s / %s\n▸ 눌러서 장비 변경" % [
		m.summary(), m.max_hp(), m.max_mp(), m.stat("atk"), m.stat("def"), m.stat("mov"),
		m.xp, m.xp_to_next(), m.summon_limit(),
		_equip_short(m, "weapon"), _equip_short(m, "accessory")]
	var b := UIKit.button(text, func(): _select(m), false, 140)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_icon(b, m)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", GameData.element_color(m.element()).lightened(0.4))
	return b


## 버튼 왼쪽에 도트 스프라이트 아이콘
func _set_icon(b: Button, s: Spirit) -> void:
	var tex := GameData.sprite_for(s)
	if tex == null:
		return
	b.icon = tex
	b.expand_icon = true
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_constant_override("icon_max_width", 72)


func _equip_short(s: Spirit, slot: String) -> String:
	var eid := str(s.equipment.get(slot, ""))
	return str(GameData.equipment[eid]["name"]) if GameData.equipment.has(eid) else "없음"


func _spirit_button(s: Spirit, vanguard: bool = false) -> Button:
	var text := "%s%s\nHP %d · 공 %d · 방 %d · 속 %d · 소환 MP %d   EXP %d/%d" % [
		"★ " if vanguard else "", s.summary(), s.max_hp(), s.stat("atk"), s.stat("def"), s.stat("spd"),
		GameState.summoner.summon_cost(s), s.xp, s.xp_to_next()]
	var b := UIKit.button(text, func(): _select(s), false, 100)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_set_icon(b, s)
	b.add_theme_color_override("font_color", GameData.element_color(s.element()).lightened(0.35))
	b.add_theme_font_size_override("font_size", 24)
	return b


func _select(s: Spirit) -> void:
	selected = s
	picking_slot = ""
	message = ""
	_refresh()


func _on_adventure() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")


func _on_explore() -> void:
	GameState.save_game()
	GameState.start_battle("wild")


func _on_rival() -> void:
	GameState.save_game()
	GameState.start_battle("rival")


func _on_save() -> void:
	GameState.save_game()
	message = "저장했습니다."
	_refresh()


func _on_title() -> void:
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- 상세

func _build_detail(vb: VBoxContainer) -> void:
	var s := selected
	var is_summoner := s is Summoner
	var tex := GameData.portrait_for(s)
	if tex != null:
		var pic := TextureRect.new()
		pic.texture = tex
		pic.custom_minimum_size = Vector2(0, 240)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not GameData.has_illustration(s):
			pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 도트는 또렷하게
		vb.add_child(pic)
	var el_color := GameData.element_color(s.element()).lightened(0.3)
	vb.add_child(UIKit.label(s.display_name(), 44, el_color))
	vb.add_child(UIKit.label("Lv.%d · %s 속성 · EXP %d/%d" % [
		s.level, GameData.element_name(s.element()), s.xp, s.xp_to_next()], 24, UIKit.MUTED))
	if message != "":
		vb.add_child(UIKit.label(message, 22, UIKit.GOOD))

	var list := UIKit.scroll_list(vb)
	list.add_child(UIKit.label(str(s.species()["desc"]), 22, UIKit.MUTED))

	# 능력치
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	for key in Spirit.STAT_KEYS:
		grid.add_child(UIKit.label("%s %d" % [Spirit.STAT_NAMES[key], s.stat(key)], 26))
	list.add_child(grid)

	if is_summoner:
		var m: Summoner = s
		list.add_child(UIKit.label("동시 소환 %d마리 · 디스펠 MP %d (사거리 %d) · 라운드당 MP +%d" % [
			m.summon_limit(), m.dispel_cost(), m.dispel_range(), m.mp_regen()], 22, UIKit.MUTED))
		list.add_child(UIKit.label("정령사 스킬", 30))
		for o in m.skill_ids:
			var sk: Dictionary = GameData.summoner_skills[str(o)]
			list.add_child(UIKit.label("· %s (MP %d) — %s" % [sk["name"], int(sk["mp"]), sk.get("desc", "")], 22))
	else:
		# 진화
		var evo := s.next_evolution()
		if evo.is_empty():
			list.add_child(UIKit.label("진화: 최종 단계", 24, UIKit.MUTED))
		else:
			list.add_child(UIKit.label("진화: Lv.%d에 %s(으)로 진화" % [
				int(evo["level"]), GameData.species[evo["species"]]["name"]], 24, UIKit.GOLD))

		# 스킬
		list.add_child(UIKit.label("스킬", 30))
		for sid in s.known_skills():
			list.add_child(UIKit.label(_skill_text(sid), 22))
		for entry in s.upcoming_skills():
			list.add_child(UIKit.label("(Lv.%d 습득) %s" % [entry["level"], _skill_text(entry["id"])], 22, UIKit.MUTED))

	# 장비
	list.add_child(UIKit.label("장비", 30))
	for slot in GameData.SLOTS:
		var eid := str(s.equipment[slot])
		var eq_text := GameData.equipment_desc(eid) if eid != "" else "없음"
		var b := UIKit.button("%s: %s" % [GameData.SLOT_NAMES[slot], eq_text], func(): _toggle_slot(slot), false, 72)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 24)
		list.add_child(b)
		if picking_slot == slot:
			_build_slot_picker(list, slot, eid)

	if is_summoner:
		vb.add_child(UIKit.button("뒤로", _on_back))
		return

	list.add_child(UIKit.label("소환 MP: %d%s" % [GameState.summoner.summon_cost(s),
		" (같은 속성 할인)" if s.element() == GameState.summoner.element() else ""], 24, UIKit.MUTED))

	# 파티 이동
	if GameState.party.has(s):
		var is_vanguard: bool = GameState.party[0] == s
		list.add_child(UIKit.button("★ 선봉" if is_vanguard else "선봉으로 지정", _on_vanguard, is_vanguard))
		list.add_child(UIKit.button("보관함으로 보내기", _on_to_storage, GameState.party.size() <= 1))
	else:
		list.add_child(UIKit.button("파티에 넣기", _on_to_party, GameState.party.size() >= GameState.MAX_PARTY))

	vb.add_child(UIKit.button("뒤로", _on_back))


func _skill_text(sid: String) -> String:
	var sk: Dictionary = GameData.skills[sid]
	return "· %s [%s] 위력 %d · MP %d · 사거리 %d~%d" % [
		sk["name"], GameData.element_name(sk["element"]), int(sk["power"]), int(sk["mp"]),
		int(sk["range_min"]), int(sk["range_max"])]


func _build_slot_picker(list: VBoxContainer, slot: String, current: String) -> void:
	var counts := {}
	for item in GameState.inventory:
		if str(GameData.equipment[item]["slot"]) == slot:
			counts[item] = int(counts.get(item, 0)) + 1
	for item in counts:
		var b := UIKit.button("   ▸ 장착: %s ×%d" % [GameData.equipment_desc(item), counts[item]], func(): _equip(item), false, 64)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22)
		list.add_child(b)
	if current != "":
		list.add_child(UIKit.button("   ▸ 장비 해제", func(): _unequip(slot), false, 64))
	if counts.is_empty() and current == "":
		list.add_child(UIKit.label("   장착할 수 있는 장비가 없습니다.", 22, UIKit.MUTED))


func _toggle_slot(slot: String) -> void:
	picking_slot = "" if picking_slot == slot else slot
	_refresh()


func _equip(eid: String) -> void:
	GameState.equip(selected, eid)
	picking_slot = ""
	message = "장착: %s" % GameData.equipment[eid]["name"]
	GameState.save_game()
	_refresh()


func _unequip(slot: String) -> void:
	GameState.unequip(selected, slot)
	picking_slot = ""
	message = "장비를 해제했습니다."
	GameState.save_game()
	_refresh()


func _on_vanguard() -> void:
	GameState.set_vanguard(selected)
	message = "%s이(가) 선봉이 되었습니다." % selected.display_name()
	GameState.save_game()
	_refresh()


func _on_to_storage() -> void:
	if GameState.move_to_storage(selected):
		message = "%s을(를) 보관함으로 보냈습니다." % selected.display_name()
		GameState.save_game()
	_refresh()


func _on_to_party() -> void:
	if GameState.move_to_party(selected):
		message = "%s이(가) 파티에 합류했습니다." % selected.display_name()
		GameState.save_game()
	_refresh()


func _on_back() -> void:
	selected = null
	picking_slot = ""
	message = ""
	_refresh()
