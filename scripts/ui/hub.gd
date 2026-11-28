extends Control
## 거점 화면: 정령사 정보, 보관함(계약 정령 전부, 속성 탭·정렬), 선봉 지정, 진화, 장비 장착, 전투 출발.

var selected: Spirit = null
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
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	var g := UIKit.gold_badge(GameState.gold, 24)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(g)
	top.add_child(UIKit.label("승리 %d회 · 파티 평균 Lv.%d · 가방 %d개" % [
		GameState.battles_won, GameState.average_party_level(), GameState.inventory.size()], 22, UIKit.MUTED))
	vb.add_child(top)
	if message != "":
		vb.add_child(UIKit.label(message, 22, UIKit.GOOD))

	vb.add_child(UIKit.label("정령사 (쓰러지면 패배)", 24))
	vb.add_child(_summoner_card())
	vb.add_child(UIKit.label("보관함 (%d) — 모두 전투에서 소환 가능 · ★ 선봉은 전투 시작 때 자동 소환" % GameState.party.size(), 22))
	var sl := SpiritList.new()
	sl.setup("hub", GameState.party, _storage_info, ["기본순", "레벨순", "이름순"])
	sl.picked.connect(_select)
	vb.add_child(sl)

	var adv := UIKit.button("모험 — %s" % str(GameState.chapter_data(GameState.active_chapter).get("title", "지도")), _on_adventure, false, 84)
	adv.add_theme_font_size_override("font_size", 30)
	adv.add_theme_color_override("font_color", UIKit.GOLD)
	vb.add_child(adv)
	var row0 := HBoxContainer.new()
	row0.add_theme_constant_override("separation", 12)
	var cb := UIKit.button("⚗ 가방 · 합성", _on_craft, false, 72)
	cb.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	row0.add_child(cb)
	vb.add_child(row0)
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
	var text := "%s\nHP %d · MP %d · 공 %d · 방 %d · 이동 %d   EXP %d/%d\n동시 소환 %d · 소지: %s\n▸ 눌러서 소지품 변경" % [
		m.summary(), m.max_hp(), m.max_mp(), m.stat("atk"), m.stat("def"), m.stat("mov"),
		m.xp, m.xp_to_next(), m.summon_limit(), _items_short(m)]
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


func _items_short(s: Spirit) -> String:
	var names := PackedStringArray()
	for o in s.items:
		if str(o) != "":
			names.append(GameData.item_name(str(o)))
	return " / ".join(names) if not names.is_empty() else "없음"


## 보관함 카드 정보: 기본순 = 선봉 → 진화 가능 → 레벨
func _storage_info(s: Spirit) -> Dictionary:
	var vanguard: bool = not GameState.party.is_empty() and GameState.party[0] == s
	var tags := PackedStringArray()
	if vanguard:
		tags.append("★선봉")
	if s.can_evolve():
		tags.append("진화 가능")
	return {
		"tag": " ".join(tags),
		"line": "HP %d · 공 %d · 방 %d · 속 %d" % [s.max_hp(), s.stat("atk"), s.stat("def"), s.stat("spd")],
		"score": (1000 if vanguard else 0) + (100 if s.can_evolve() else 0),
		"gold": s.can_evolve(),
	}


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
	SaveSlots.open(self, "save")


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
		list.add_child(UIKit.label("공격 탭", 30))
		list.add_child(UIKit.label("· 기본 공격 (사거리 1)", 22))
		var atk_sid := m.attack_skill_id()
		if atk_sid != "":
			var ask: Dictionary = GameData.summoner_skills[atk_sid]
			list.add_child(UIKit.label("· %s (MP %d) — %s" % [ask["name"], int(ask["mp"]), ask.get("desc", "")], 22))
		list.add_child(UIKit.label("· 디스펠 (MP %d) — 약해진 정령과 계약" % m.dispel_cost(), 22))
		list.add_child(UIKit.label("스킬", 30))
		for o in m.support_skill_ids():
			var sk: Dictionary = GameData.summoner_skills[str(o)]
			list.add_child(UIKit.label("· %s (MP %d) — %s" % [sk["name"], int(sk["mp"]), sk.get("desc", "")], 22))
	else:
		# 진화
		var evo := s.next_evolution()
		if evo.is_empty():
			list.add_child(UIKit.label("진화: 최종 단계", 24, UIKit.MUTED))
		else:
			var evo_name := str(GameData.species[evo["species"]]["name"])
			list.add_child(UIKit.label("진화: Lv.%d부터 %s(으)로 진화 가능" % [int(evo["level"]), evo_name], 24, UIKit.GOLD))
			if s.can_evolve():
				list.add_child(UIKit.button("✦ %s(으)로 진화시키기" % evo_name, _on_evolve))
			if s.hidden_skill_level() > 0 and not s.has_hidden_skill():
				list.add_child(UIKit.label("진화하지 않고 Lv.%d까지 키우면 숨은 기술을 익힌다는데…" % s.hidden_skill_level(), 21, UIKit.MUTED))

		# 공격 탭: 기본 공격 + 스킬 최대 2
		list.add_child(UIKit.label("공격 탭", 30))
		list.add_child(UIKit.label("· 기본 공격 [%s] 사거리 1 · MP 0" % GameData.element_name(s.element()), 22))
		for sid in s.known_skills():
			list.add_child(UIKit.label(_skill_text(sid), 22, UIKit.GOLD if bool(GameData.skills[sid].get("hidden", false)) else Color.WHITE))
		for entry in s.upcoming_skills():
			list.add_child(UIKit.label("(Lv.%d 습득) %s" % [entry["level"], _skill_text(entry["id"])], 22, UIKit.MUTED))

	# 소지창 3칸 (전투 소환 창과 같음)
	list.add_child(UIKit.label("소지품 (3칸 · 장비·도구)", 30))
	var ed := EquipEditor.new()
	ed.set_spirit(s)
	ed.changed.connect(_refresh)
	list.add_child(ed)

	if is_summoner:
		vb.add_child(UIKit.button("뒤로", _on_back))
		return

	list.add_child(UIKit.label("소환 MP: %d%s" % [GameState.summoner.summon_cost(s),
		" (같은 속성 할인)" if s.element() == GameState.summoner.element() else ""], 24, UIKit.MUTED))

	# 선봉
	if GameState.party.has(s):
		var is_vanguard: bool = GameState.party[0] == s
		list.add_child(UIKit.button("★ 선봉" if is_vanguard else "선봉으로 지정 (전투 시작 때 자동 소환)", _on_vanguard, is_vanguard))

	vb.add_child(UIKit.button("뒤로", _on_back))


func _on_evolve() -> void:
	var msg := selected.try_evolve()
	if msg != "":
		message = msg
		GameState.save_game()
	_refresh()


func _skill_text(sid: String) -> String:
	var sk: Dictionary = GameData.skills[sid]
	return "· %s%s [%s] 위력 %d · MP %d · 사거리 %d~%d" % [
		sk["name"], " (숨은 기술)" if bool(sk.get("hidden", false)) else "", GameData.element_name(sk["element"]), int(sk["power"]), int(sk["mp"]),
		int(sk["range_min"]), int(sk["range_max"])]


func _on_craft() -> void:
	var w := CraftScreen.open(self)
	w.closed.connect(_refresh)


func _on_vanguard() -> void:
	GameState.set_vanguard(selected)
	message = "%s이(가) 선봉이 되었습니다." % selected.display_name()
	GameState.save_game()
	_refresh()


func _on_back() -> void:
	selected = null
	message = ""
	_refresh()
