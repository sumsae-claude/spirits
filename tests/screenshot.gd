extends Node
## 화면 확인용: 전투 화면을 열고 상태창 · 공격 선택 창 · 전투 연출 창을 PNG로 저장한다.
## xvfb-run godot --path . res://tests/screenshot.tscn  (SHOT_DIR 환경 변수 = 저장 폴더)

var out := ""


func _ready() -> void:
	var ph := Node.new()
	get_tree().root.add_child.call_deferred(ph)
	await get_tree().process_frame
	get_tree().current_scene = ph
	out = OS.get_environment("SHOT_DIR")
	if out == "":
		out = "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	GameState.new_game("테스트", "fire")
	GameState.party.append(Spirit.create("dewdrop", 4))
	GameState.flags["battle_anim"] = true
	var node: Dictionary = GameData.find_node("1-3")["node"]
	GameState.cleared_stages = ["1-1", "1-2"]
	GameState.start_stage(node)
	await _frames(90)
	var b := get_tree().current_scene
	b.inspected = b.summoner_unit
	b._mark_ui()
	await _frames(10)
	_shot("1_status_summoner")
	# 정령사를 고르고 이동 범위
	b.inspected = null
	b._select_unit(b.summoner_unit)
	await _frames(10)
	_shot("2_move_range")
	# 아군 정령을 적 옆으로 옮기고 공격 선택 창
	var ally = b.vanguard_unit
	var foe = null
	for o in b.units:
		if o.team == 1 and o.is_active():
			foe = o
			break
	b._deselect()
	await _frames(3)
	for c in b.grid.neighbors(foe.cell):
		if b._unit_at(c) == null and not b.grid.blocked.has(c):
			ally.cell = c
			ally.draw_pos = b.grid.to_pixel(c)
			break
	b._select_unit(ally)
	await _frames(5)
	b.has_moved = true
	b.reachable = {}
	var pre := {}
	ally.spirit.species_id = "blazebean"
	ally.spirit.level = maxi(ally.spirit.level, 12)
	for sid in ally.spirit.known_skills():
		pre = {"type": "skill", "skill_id": sid}
	ally.spirit.full_heal()
	b._open_target_menu(foe, pre)
	await _frames(10)
	_shot("3_attack_confirm")
	b._confirm_attack()
	await _frames(22)
	_shot("4_duel")
	await _frames(30)
	_shot("5_duel_later")
	await _frames(120)
	# 디스펠 연출: 정령사를 적 옆에 두고 약해진 적 정령에게 디스펠
	var weak = null
	for o in b.units:
		if o.team == 1 and o.is_active() and not o.is_summoner:
			weak = o
	if weak == null:
		weak = b._add_unit(Spirit.create("pebble", 3), 1, Vector2i(2, 6))
	if weak != null:
		weak.spirit.hp = 1
		var su = b.summoner_unit
		b.phase = "select"
		b._select_unit(su)
		await _frames(3)
		b.has_moved = true
		b.reachable = {}
		su.spirit.mp = su.spirit.max_mp()
		for c in b.grid.neighbors(weak.cell):
			if b._unit_at(c) == null and not b.grid.blocked.has(c):
				su.cell = c
				su.draw_pos = b.grid.to_pixel(c)
				break
		b.pending = {"type": "dispel"}
		b._execute_player_action(weak)
		await _frames(40)
		_shot("6_dispel")
		await _frames(25)
		_shot("7_dispel_result")
	# 아이템 획득 팝업
	ItemPopup.show_items(b.ui_root, ["herb", "herb", "ember_charm"], "보물 상자를 열었다!", "전투가 끝나면 가방에 들어간다")
	await _frames(10)
	_shot("8_item_popup")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("SHOT ", name)
