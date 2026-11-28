extends Node
## 헤드리스 자동 플레이 테스트 (사람 대신 게임을 끝까지 진행해 보며 오류를 찾는다).
## 실행: godot --headless --path . res://tests/smoke_test.tscn
## 출력의 "SCRIPT ERROR" / "ERROR" 줄이 버그. "SMOKE:" 줄은 진행 기록.
## 진행: 새 게임 → 1-1 고정 튜토리얼(지시대로 입력) → 1장 나머지 자동 전투 → 대륙 지도 → 2장(이벤트·상점·마을·전투·보스)

const TIME_SCALE := 6.0
var failures: Array[String] = []


func _ready() -> void:
	# 안전장치: 너무 오래 걸리면 끝낸다
	get_tree().create_timer(1500.0, true, false, true).timeout.connect(func():
		print("SMOKE FAIL: 시간 초과로 중단")
		get_tree().quit(2))
	# 이 노드는 장면이 바뀌어도 남아 있도록 루트에 두고, 빈 노드를 '현재 장면'으로 둔다
	ItemPopup.auto_close = true   # 아이템 획득 팝업은 저절로 닫히게
	var ph := Node.new()
	get_tree().root.add_child.call_deferred(ph)
	await get_tree().process_frame
	get_tree().current_scene = ph
	await _run()


func say(t: String) -> void:
	print("SMOKE: ", t)


func fail(t: String) -> void:
	failures.append(t)
	print("SMOKE FAIL: ", t)


func scene() -> Node:
	return get_tree().current_scene


func frames(n: int = 1) -> void:
	for i in n:
		_skip_dialogues()
		Engine.time_scale = TIME_SCALE
		await get_tree().process_frame


## 대화창은 바로 넘긴다
func _skip_dialogues() -> void:
	var sc := scene()
	if sc == null:
		return
	for c in sc.get_children():
		if c is DialogueBox:
			(c as DialogueBox)._finish()


func wait_scene(path_part: String, max_frames: int = 600) -> bool:
	for i in max_frames:
		await frames()
		var sc := scene()
		if sc != null and sc.scene_file_path.contains(path_part):
			await frames(5)
			return true
	fail("장면 전환 안 됨: " + path_part)
	return false


func _run() -> void:
	var only := OS.get_environment("SMOKE_STAGE")
	if only != "":
		await _stage_trial(only, int(OS.get_environment("SMOKE_TRIES")) if OS.get_environment("SMOKE_TRIES") != "" else 5)
		return _end()
	say("새 게임 (불)")
	GameState.new_game("테스트", "fire")
	# 전체 실행은 길어서 전투 연출 창은 끈다 (SMOKE_ANIM=1이면 켬. 스테이지 시험은 켠 채로)
	GameState.flags["battle_anim"] = OS.get_environment("SMOKE_ANIM") == "1"
	var from_ch2 := OS.get_environment("SMOKE_FROM_CH2") != ""
	if from_ch2:
		# 1장을 깬 상태로 시작 (파티는 2장 권장 레벨 근처)
		for o in GameState.chapter_nodes(0):
			GameState.cleared_stages.append(str((o as Dictionary)["id"]))
		GameState.flags["prologue_seen"] = true
		GameState.flags["demo_end_seen"] = true
		GameState.summoner = Summoner.create_summoner("테스트", "fire", 8)
		GameState.party = [Spirit.create("emberbean", 8)]
		for sid in ["breezebird", "pebble", "dewdrop", "whirlmouse"]:
			GameState.party.append(Spirit.create(sid, 7))
		say("2장부터 시작: 파티 %s" % _levels())
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	if not await wait_scene("world_map"):
		return _end()
	await frames(30)

	# ---- 1장
	var nodes: Array = GameState.chapter_nodes(0) if not from_ch2 else []
	for i in nodes.size():
		var n: Dictionary = nodes[i]
		say("1장 %s %s (권장 Lv.%d, 정령사 Lv.%d, 파티 %s)" % [n["id"], n["name"], int(n.get("rec_level", 0)), GameState.summoner.level, _levels()])
		var ok := await _play_node_battle(0, i)
		if not ok:
			fail("1장 %s 클리어 실패" % n["id"])
			break
	say("1장 완료? %s" % str(GameState.chapter_complete(0)))

	# ---- 대륙 지도 → 2장
	if GameState.chapter_complete(0) and GameData.chapters.size() > 1:
		await frames(60)
		var wm := scene()
		say("지도 모드: %s" % str(wm.get("mode")))
		wm.selected_region = GameState.chapter_element(1)
		wm._on_enter_region()   # 대화는 frames()가 넘겨 준다 (await 하면 대화를 기다리다 멈춤)
		await frames(60)
		var n2: Array = GameState.chapter_nodes(1)
		for i in n2.size():
			var n: Dictionary = n2[i]
			var t := str(n.get("type", ""))
			say("2장 %s (%s) %s (권장 Lv.%d, 파티 %s)" % [n["id"], t, n["name"], int(n.get("rec_level", 0)), _levels()])
			match t:
				"battle", "boss":
					if not await _play_node_battle(1, i):
						fail("2장 %s 실패" % n["id"])
				"event":
					await _do_event(i)
				"shop":
					await _do_shop(i)
				"town":
					await _do_town(i)
		say("2장 완료? %s" % str(GameState.chapter_complete(1)))
		# 마을에 돌아가 의뢰 보고
		for i in n2.size():
			if str(n2[i].get("type", "")) == "town" and GameState.is_cleared(str(n2[i]["id"])):
				await _do_town(i)
	# 거점도 한 번 열어 보기
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
	await wait_scene("hub")
	await frames(30)
	var hub := scene()
	if GameState.party.size() > 0:
		hub.selected = GameState.party[0]
		hub._refresh()
		await frames(20)
	# 가방 · 합성: 약초 2개 → 회복약 (레시피 기록), 틀린 조합은 재료 1개 잃음
	hub.selected = null
	hub._refresh()
	await frames(5)
	GameState.add_item("herb", 3)
	var cw := CraftScreen.open(hub)
	await frames(5)
	cw._put("herb")
	cw._put("herb")
	cw._craft()
	await frames(5)
	say("합성: %s, 레시피 %s" % [cw.message, str(GameState.known_recipes)])
	if GameState.known_recipes.is_empty():
		fail("합성 성공했는데 레시피가 기록되지 않음")
	cw.mix = {"herb": 1}
	cw._craft()
	await frames(5)
	say("합성 실패 시험: %s" % cw.message)
	cw._close()
	# 소지창: 정령사 3칸에 회복약 넣기
	var sm := GameState.summoner
	if GameState.inventory.has("herb_potion") and sm.free_slot() >= 0:
		GameState.equip(sm, "herb_potion")
	say("정령사 소지: %s" % str(sm.items))
	# 저장 슬롯: 3번에 저장 → 요약 확인 → 창 열기 → 불러오기
	var gold_before := GameState.gold
	GameState.save_to_slot(3)
	var info := GameState.slot_info(3)
	say("슬롯 3: %s" % str(info))
	if info.is_empty():
		fail("슬롯 3 저장 안 됨")
	var w := SaveSlots.open(scene(), "save")
	await frames(10)
	w._close()
	w = SaveSlots.open(scene(), "load")
	await frames(10)
	GameState.gold = 1
	w._on_slot(3, false)
	await wait_scene("world_map")
	await frames(10)
	if GameState.gold != gold_before:
		fail("슬롯 3 불러오기 후 골드가 다름 (%d / %d)" % [GameState.gold, gold_before])
	say("불러오기 확인: 골드 %d, 최근 칸 %d" % [GameState.gold, GameState.latest_slot()])
	_end()


func _levels() -> String:
	var lv := PackedStringArray()
	for s in GameState.party:
		lv.append(str((s as Spirit).level))
	return ",".join(lv)


## 한 스테이지만 여러 번: 그 앞까지 클리어하고 파티를 권장 레벨 근처로 맞춘 뒤 승률을 본다
## 실행: SMOKE_STAGE=1-6 SMOKE_TRIES=5 SMOKE_ELEMENT=fire godot --headless --path . res://tests/smoke_test.tscn
func _stage_trial(stage_id: String, tries: int) -> void:
	var el := OS.get_environment("SMOKE_ELEMENT")
	GameState.new_game("테스트", el if el != "" else "fire")
	var found := GameData.find_node(stage_id)
	if found.is_empty():
		fail("스테이지 없음: " + stage_id)
		return
	var ci: int = found["chapter"]
	var rec := int((found["node"] as Dictionary).get("rec_level", 5))
	for c in range(0, ci + 1):
		for o in GameState.chapter_nodes(c):
			var nid := str((o as Dictionary)["id"])
			if nid == stage_id:
				break
			GameState.cleared_stages.append(nid)
	GameState.flags["prologue_seen"] = true
	GameState.flags["demo_end_seen"] = true
	GameState.flags["intro_seen_%d" % ci] = true
	GameState.active_chapter = ci
	GameState.summoner = Summoner.create_summoner("테스트", GameState.home_element(), rec)
	GameState.party = [Spirit.create(str(GameState.STARTERS[GameState.home_element()]), rec)]
	for sid in [GameState.FAMILIES[GameState.prey_element()][0], GameState.FAMILIES[GameState.strong_element()][0], GameState.FAMILIES[GameState.rival_element()][1]]:
		GameState.party.append(Spirit.create(str(sid), maxi(1, rec - 1)))
	say("시험: %s (권장 Lv.%d) 파티 %s, 정령사 Lv.%d" % [stage_id, rec, _levels(), GameState.summoner.level])
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	if not await wait_scene("world_map"):
		return
	await frames(20)
	var idx := 0
	var nodes := GameState.chapter_nodes(ci)
	for i in nodes.size():
		if str(nodes[i]["id"]) == stage_id:
			idx = i
	var wins := 0
	for t in tries:
		GameState.cleared_stages.erase(stage_id)
		GameState.heal_all()
		var wm := _select_node(ci, idx)
		wm._busy = false
		wm._on_node_action()
		if not await wait_scene("battle"):
			return
		if await _play_battle():
			wins += 1
		await wait_scene("world_map")
		await frames(20)
	say("결과: %s %d/%d 승" % [stage_id, wins, tries])


func _end() -> void:
	say("골드 %d, 파티 %d, 보관함 %d, 정령사 Lv.%d" % [GameState.gold, GameState.party.size(), 0, GameState.summoner.level])
	for s in GameState.party:
		say("  %s Lv.%d" % [(s as Spirit).display_name(), (s as Spirit).level])
	say("실패 %d건" % failures.size())
	for f in failures:
		say("  - " + f)
	Engine.time_scale = 1.0
	get_tree().quit(1 if not failures.is_empty() else 0)


# ================================================================ 지도 지점

func _select_node(ci: int, i: int) -> Node:
	var wm := scene()
	if not wm.scene_file_path.contains("world_map"):
		fail("지도가 아님")
		return wm
	if wm.chapter != ci:
		wm.chapter = ci
		wm._enter_mode("region")
	wm.selected = i
	wm._rebuild_panel()
	return wm


func _play_node_battle(ci: int, i: int) -> bool:
	var tries := 0
	while tries < 3:
		tries += 1
		var wm := _select_node(ci, i)
		wm._busy = false
		wm._on_node_action()
		if not await wait_scene("battle"):
			return false
		var won := await _play_battle()
		if not await wait_scene("world_map"):
			return false
		await frames(30)
		var nid := str(GameState.chapter_nodes(ci)[i]["id"])
		if won and GameState.is_cleared(nid):
			return true
		say("  재도전 (%d)" % tries)
	return false


func _do_event(i: int) -> void:
	var wm := _select_node(1, i)
	var n: Dictionary = GameState.chapter_nodes(1)[i]
	wm._busy = false
	wm._on_node_action()
	await frames(40)
	await frames(20)
	var choices: Array = n.get("choices", [])
	if choices.is_empty():
		fail("이벤트 선택지 없음")
		return
	# 첫 이벤트는 정령 계약, 둘째는 전투 선택지를 골라 본다
	var pick: Dictionary = choices[0] if str(n["id"]) == "2-e1" else choices[choices.size() - 1]
	wm._choose_event(n, pick)
	await frames(20)
	for o in pick.get("effects", []):
		if (o as Dictionary).has("battle"):
			# "싸운다!" 버튼 대신 같은 일을 한다
			var b: Dictionary = o["battle"]
			GameState.start_stage({"id": str(n["id"]) + "_battle", "name": "이벤트 전투", "enemies": b.get("enemies", [])})
			if await wait_scene("battle"):
				await _play_battle()
				await wait_scene("world_map")
				await frames(20)
			return
	wm._close_overlay()
	await frames(10)


func _do_shop(i: int) -> void:
	var wm := _select_node(1, i)
	wm._busy = false
	wm._on_node_action()
	await frames(40)
	await frames(10)
	var stock: Array = wm._shop_stock()
	say("  상점 재고 %s, 골드 %d" % [str(stock), GameState.gold])
	for eid in stock:
		if GameState.gold >= GameData.equipment_price(str(eid)):
			wm._buy(str(eid))
			say("  구매 %s → 골드 %d" % [eid, GameState.gold])
			break
	await frames(5)
	wm._set_shop_tab("sell")
	await frames(5)
	if not GameState.inventory.is_empty():
		wm._sell(str(GameState.inventory[0]))
		say("  판매 → 골드 %d" % GameState.gold)
	await frames(5)
	wm._close_overlay()
	await frames(5)


func _do_town(i: int) -> void:
	var wm := _select_node(1, i)
	wm._busy = false
	wm._on_node_action()
	await frames(40)
	await frames(10)
	var n: Dictionary = GameState.chapter_nodes(1)[i]
	for q in GameState.quest_defs(n):
		if GameState.quest_ready(q):
			wm._claim_quest(q)
			say("  의뢰 보고: %s → 골드 %d" % [q["id"], GameState.gold])
		elif GameState.quest_state(str(q["id"])) == "":
			wm._accept_quest(q)
			say("  의뢰 받음: %s" % GameState.quest_text(q, "title"))
		await frames(5)
	say("  진행 중 의뢰: %s" % str(GameState.active_quest_lines()))
	wm._close_overlay()
	await frames(5)


# ================================================================ 전투 자동 진행

func _play_battle() -> bool:
	var b := scene()
	await frames(10)
	if not b.script_steps.is_empty() and b.script_i >= 0:
		await _play_tutorial_script(b)
	var guard := 0
	while str(b.phase) != "over" and guard < 6000:
		guard += 1
		if str(b.phase) == "select":
			var ready: Array = b._ready_allies()
			if ready.is_empty():
				await frames()
				continue
			await _ally_turn(b, ready[0])
		else:
			await frames()
		if b.round_num > 25:
			say("  라운드 초과 → 후퇴")
			var fl: Array = b.full_log
			for k in range(maxi(0, fl.size() - 16), fl.size()):
				say("    | " + str(fl[k]))
			b._on_retreat()
			return false
	await frames(10)
	var victory: bool = b.summoner_unit.is_active()
	say("  전투 끝: %s (라운드 %d)" % ["승리" if victory else "패배", b.round_num])
	var counts := {}
	for line in b.full_log:
		for key in ["쓰러졌다", "제어를 벗어나", "넘어갔다", "상태가 되었다", "피했다", "빗나갔다", "소환했다", "계약했다", "방어"]:
			if str(line).contains(key):
				counts[key] = int(counts.get(key, 0)) + 1
	say("    사건: %s" % str(counts))
	if not victory:
		var fl: Array = b.full_log
		if b.guardian_unit != null:
			var g: Object = b.guardian_unit
			var hits := 0
			for line in fl:
				if str(line).contains(g.spirit.display_name() + "에게"):
					hits += 1
			say("    수호 정령 남은 HP %d/%d, 맞은 횟수 %d" % [g.spirit.hp, g.spirit.max_hp(), hits])
		for k in range(maxi(0, fl.size() - 14), fl.size()):
			say("    | " + str(fl[k]))
	b._return_to_hub()
	return victory


func _wait_phase(b: Node, phases: Array, max_frames: int = 1200) -> void:
	for i in max_frames:
		if str(b.phase) in phases:
			return
		await frames()
	fail("phase 대기 시간 초과: 지금 %s, 기다린 것 %s" % [str(b.phase), str(phases)])


func _tap_cell(b: Node, c: Vector2i) -> void:
	b._on_tap(b.grid.to_pixel(c))


## 1-1 고정 튜토리얼: 지시대로 누른다 (잘못된 입력이 막히는지도 확인)
func _play_tutorial_script(b: Node) -> void:
	say("  튜토리얼 스크립트 %d단계" % b.script_steps.size())
	var van: Object = b.vanguard_unit
	var prey: Object = b.stage_enemy_units[0]
	# 1. 엉뚱한 칸(정령사)을 누르면 무시돼야 한다
	_tap_cell(b, b.summoner_unit.cell)
	await frames(3)
	if b.active != null:
		fail("튜토리얼: 지시와 다른 유닛이 선택됨")
	_tap_cell(b, van.cell)
	await frames(5)
	await _expect_step(b, 1)
	# 2. 지정 칸이 아닌 곳은 무시, 지정 칸으로 이동
	_tap_cell(b, Vector2i(2, 9))
	await frames(3)
	_tap_cell(b, Vector2i(3, 8))
	await _wait_phase(b, ["player"])
	await frames(5)
	await _expect_step(b, 2)
	# 3. 적을 눌러 기본 공격
	_tap_cell(b, prey.cell)
	await frames(3)
	if str(b.phase) != "choose":
		fail("튜토리얼: 적을 눌러도 행동 메뉴가 안 열림 (%s)" % str(b.phase))
	b._choose_option({"type": "attack"})
	await _wait_phase(b, ["select"])
	await frames(5)
	await _expect_step(b, 3)
	if not prey.is_active():
		fail("튜토리얼: 디스펠할 정령이 먼저 쓰러짐")
	# 4~6. 정령사 → 이동 → 디스펠
	_tap_cell(b, b.summoner_unit.cell)
	await frames(5)
	await _expect_step(b, 4)
	_tap_cell(b, Vector2i(4, 9))
	await _wait_phase(b, ["player"])
	await frames(5)
	await _expect_step(b, 5)
	_tap_cell(b, prey.cell)
	await frames(3)
	b._choose_option({"type": "dispel"})
	await frames(5)
	await _wait_phase(b, ["select", "enemy", "player"], 3000)
	# 7. 적 턴을 지나 라운드 2
	await _wait_phase(b, ["select"], 3000)
	await frames(5)
	if not prey.captured:
		fail("튜토리얼: 디스펠이 실패함 (반드시 성공해야 함)")
	await _expect_step(b, 7)
	# 8~9. 정령사 → 소환
	_tap_cell(b, b.summoner_unit.cell)
	await frames(5)
	await _expect_step(b, 8)
	b._open_submenu("summon")
	await frames(5)
	var cands: Array = b._summonable()
	if cands.is_empty():
		fail("튜토리얼: 계약한 정령을 소환할 수 없음")
	else:
		b._choose_summon(cands[0])
		await frames(3)
		var cells: Array = b.place_cells.keys()
		_tap_cell(b, cells[0])
		await frames(30)
		if b.summoning:
			b._on_summon_done()
	await frames(10)
	await _expect_step(b, 9)
	# 자유 전투로
	b.script_i = b.script_steps.size()
	b._show_next_tutorial()
	b._mark_ui()
	say("  튜토리얼 스크립트 통과")


func _expect_step(b: Node, want: int) -> void:
	await frames(2)
	if int(b.script_i) != want:
		fail("튜토리얼 단계가 %d여야 하는데 %d (phase %s)" % [want, int(b.script_i), str(b.phase)])


## 아군 한 명의 차례: 정령사는 디스펠·소환 위주, 정령은 적 AI 계획을 빌려 공격
func _ally_turn(b: Node, u: Object) -> void:
	b._select_unit(u)
	await frames(2)
	if u.is_summoner:
		await _summoner_turn(b, u)
	else:
		var plan: Dictionary = b._plan_enemy(u)
		var dest: Vector2i = plan["cell"]
		if dest != u.cell:
			await b._move_player(dest)
			await frames(2)
		if plan.has("action") and plan["target"].is_active():
			# 원작식 '공격 선택' 창을 거쳐 공격 (기술 선택 → 확인)
			b._open_target_menu(plan["target"], plan["action"])
			await frames(2)
			if b.attack_confirm == null:
				fail("공격 선택 창이 열리지 않음")
				b.pending = plan["action"]
				await b._execute_player_action(plan["target"])
			else:
				b._confirm_attack()
		elif b._can_recall(u) and u.spirit.hp * 4 < u.spirit.max_hp():
			await b._on_recall()
		else:
			b._on_wait()
	await _wait_phase(b, ["select", "enemy", "over"], 3000)


func _summoner_turn(b: Node, u: Object) -> void:
	var m: Summoner = GameState.summoner
	# 다쳤으면 도구(회복약) 사용
	if m.hp * 2 < m.max_hp():
		for i in m.tool_slots():
			var iid := str(m.items[i])
			if str(GameData.items[iid]["effect"]["type"]) == "heal":
				b._open_submenu("tools")
				await frames(2)
				b._choose_tab_action({"type": "item", "item_id": iid, "slot": int(i)})
				await frames(2)
				if b.targets.has(u.cell):
					say("  도구 사용: %s" % GameData.item_name(iid))
					await b._execute_player_action(u)
					return
				b._cancel_targeting()
	# 디스펠 대상: 드러난 수호 정령 > 약해진 야생 정령
	var target: Object = null
	for o in b.units:
		var e: Object = o
		if e.team != 1 or not e.is_active() or e.is_summoner:
			continue
		if e.is_guardian and e.revealed:
			target = e
			break
		if not e.is_guardian and e.spirit.hp * 3 < e.spirit.max_hp() and target == null:
			target = e
	if target != null and m.mp >= m.dispel_cost():
		var cells: Dictionary = b.reachable.duplicate()
		cells[u.cell] = 0
		var best := Vector2i(-1, -1)
		for c in cells:
			if b.grid.distance(c, target.cell) <= m.dispel_range() and (best.x < 0 or int(cells[c]) < int(cells[best])):
				best = c
		if best.x >= 0:
			if best != u.cell:
				await b._move_player(best)
				await frames(2)
			b.pending = {"type": "dispel"}
			await b._execute_player_action(target)
			return
	# 소환할 수 있으면 소환 (계약 정령·보관함 소환 목록 시험)
	if b._can_summon_more():
		b._open_submenu("summon")
		await frames(3)
		var cands: Array = b._summonable()
		var cost_ok := false
		for o in cands:
			if m.mp >= m.summon_cost(o):
				b._choose_summon(o)
				cost_ok = true
				break
		if cost_ok and not b.place_cells.is_empty():
			await frames(2)
			_tap_cell(b, b.place_cells.keys()[0])
			await frames(20)
			if b.summoning:
				b._on_summon_done()
			return
		b._close_submenu()
	# 사거리 안에 적이 있으면 공격 마법/기본 공격 (공격 선택 창 사용)
	var best_act: Dictionary = {}
	var best_t: Object = null
	var best_d := 0
	for o in b._attack_tab(u):
		var act: Dictionary = o
		if str(act["type"]) == "dispel" or m.mp < int(b._action_mp(u, act)):
			continue
		var ts: Dictionary = b._targets_for(u, u.cell, act)
		for c in ts:
			var d: int = b._expected_damage(u, u.cell, ts[c], act)
			if d > best_d:
				best_d = d
				best_act = act
				best_t = ts[c]
	if best_t != null and (m.hp * 2 > m.max_hp() or best_d >= best_t.spirit.hp):
		b._open_target_menu(best_t, best_act)
		await frames(2)
		b._confirm_attack()
		return
	# 할 일이 없으면 적에게서 멀어지는 칸으로 물러선다 (사람처럼 정령사를 지킴)
	var safest: Vector2i = u.cell
	var best_threat: int = _threat(b, u.cell)
	for c in b.reachable:
		var th: int = _threat(b, c)
		if th < best_threat:
			best_threat = th
			safest = c
	if safest != u.cell:
		await b._move_player(safest)
		await frames(2)
	b._on_wait()


## 그 칸에 다음 적 턴에 닿을 수 있는 적 수
func _threat(b: Node, c: Vector2i) -> int:
	var n := 0
	for o in b.units:
		var e: Object = o
		if e.team == 1 and e.is_active() and b.grid.distance(c, e.cell) <= e.spirit.stat("mov") + 2:
			n += 1
	return n
