extends Node2D
## 헥스 턴제 전투 씬. 맵/유닛은 _draw()로 그리고, UI는 코드로 생성한다.
##
## 진행: 라운드마다 속도 순으로 행동. 아군 차례에는 (선택) 이동 1회 → 행동 1회.
## 행동: 공격 / 스킬 / 디스펠(인접한 야생 정령과 계약 시도) / 대기 / 후퇴

const COLS := 8
const ROWS := 10
const HEX_SIZE := 44.0
const MAP_TOP := 130.0
const PANEL_HEIGHT := 440.0
const ENEMY_DELAY := 0.35
const ACTION_DELAY := 0.55
const OBSTACLE_COUNT := 7
const SPAWN_COLS := [3, 4, 2, 5]

const COLOR_BG := Color(0.07, 0.08, 0.11)
const COLOR_CELL := Color(0.17, 0.2, 0.26)
const COLOR_BLOCKED := Color(0.12, 0.12, 0.14)
const COLOR_MOVE := Color(0.2, 0.38, 0.62)
const COLOR_ACTIVE_CELL := Color(0.42, 0.4, 0.2)
const COLOR_OUTLINE := Color(0.35, 0.4, 0.5, 0.6)

var grid: HexGrid
var units: Array = []        # BattleUnit
var turn_queue: Array = []   # BattleUnit
var turn_index := -1
var round_num := 0
var active: BattleUnit = null
var inspected: BattleUnit = null
## idle / player / targeting / busy / enemy / over
var phase := "idle"
var has_moved := false
var show_skills := false
var pending: Dictionary = {}
var reachable: Dictionary = {}  # Vector2i -> 비용
var targets: Dictionary = {}    # Vector2i -> BattleUnit
var defeated: Array = []        # 쓰러뜨린 야생 Spirit
var captured: Array = []        # 계약한 야생 Spirit
var effects: Array = []         # 떠오르는 텍스트
var rng := RandomNumberGenerator.new()
var font: Font
var time := 0.0

var ui_root: Control
var turn_label: Label
var info_label: Label
var hint_label: Label
var action_box: GridContainer
var log_label: Label
var log_lines: Array = []
var _ui_dirty := true


func _ready() -> void:
	rng.randomize()
	font = GameData.ui_font
	var vp_w := get_viewport_rect().size.x
	var hex_w := HexGrid.SQRT3 * HEX_SIZE
	var total_w := hex_w * COLS + hex_w * 0.5
	var origin := Vector2((vp_w - total_w) * 0.5 + hex_w * 0.5, MAP_TOP + HEX_SIZE)
	grid = HexGrid.new(COLS, ROWS, HEX_SIZE, origin)
	_build_ui()
	_setup_units()
	_start_round()


func _process(delta: float) -> void:
	time += delta
	for e in effects:
		e["t"] += delta
	effects = effects.filter(func(e): return e["t"] < 1.0)
	queue_redraw()
	if _ui_dirty:
		_ui_dirty = false
		_rebuild_ui()


# ================================================================ 준비

func _setup_units() -> void:
	# 에디터에서 이 씬만 단독 실행(F6)했을 때를 위한 기본값
	if GameState.party.is_empty():
		GameState.party = [Spirit.create("emberbean", 5)]
	if GameState.current_encounter.is_empty():
		GameState.current_encounter = GameState.make_encounter()

	_place_obstacles()
	for i in GameState.party.size():
		_add_unit(GameState.party[i], 0, Vector2i(SPAWN_COLS[i], ROWS - 2))
	for i in GameState.current_encounter.size():
		_add_unit(GameState.current_encounter[i], 1, Vector2i(SPAWN_COLS[i], 1))
	_log("야생 정령 %d마리가 나타났다!" % GameState.current_encounter.size())
	GameState.current_encounter = []


func _place_obstacles() -> void:
	var placed := 0
	var tries := 0
	while placed < OBSTACLE_COUNT and tries < 200:
		tries += 1
		var c := Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(3, ROWS - 4))
		if not grid.blocked.has(c):
			grid.blocked[c] = true
			placed += 1


func _add_unit(s: Spirit, team: int, cell: Vector2i) -> void:
	var u := BattleUnit.new(s, team, cell)
	u.draw_pos = grid.to_pixel(cell)
	units.append(u)


# ================================================================ 턴 진행

func _start_round() -> void:
	round_num += 1
	turn_queue = []
	for o in units:
		var u: BattleUnit = o
		if u.is_active():
			turn_queue.append(u)
			if round_num > 1:
				u.spirit.mp = mini(u.spirit.max_mp(), u.spirit.mp + BattleLogic.MP_REGEN_PER_ROUND)
	turn_queue.sort_custom(_compare_speed)
	turn_index = -1
	_next_turn()


func _compare_speed(a: BattleUnit, b: BattleUnit) -> bool:
	var sa := a.spirit.stat("spd")
	var sb := b.spirit.stat("spd")
	if sa == sb:
		return a.team < b.team
	return sa > sb


func _next_turn() -> void:
	if _check_end():
		return
	turn_index += 1
	while turn_index < turn_queue.size() and not (turn_queue[turn_index] as BattleUnit).is_active():
		turn_index += 1
	if turn_index >= turn_queue.size():
		_start_round()
		return
	active = turn_queue[turn_index]
	has_moved = false
	show_skills = false
	inspected = null
	pending = {}
	targets = {}
	if active.team == 0:
		phase = "player"
		reachable = grid.reachable(active.cell, active.spirit.stat("mov"), _occupied(active))
		_mark_ui()
	else:
		reachable = {}
		_run_enemy_turn()


func _end_turn() -> void:
	active = null
	phase = "idle"
	reachable = {}
	targets = {}
	pending = {}
	_next_turn()


func _check_end() -> bool:
	if phase == "over":
		return true
	var allies := false
	var foes := false
	for o in units:
		var u: BattleUnit = o
		if u.is_active():
			if u.team == 0:
				allies = true
			else:
				foes = true
	if not foes:
		_finish(true)
		return true
	if not allies:
		_finish(false)
		return true
	return false


func _finish(victory: bool) -> void:
	phase = "over"
	active = null
	var lines: Array[String] = []
	if victory:
		var total_xp := 0
		for s in defeated:
			total_xp += BattleLogic.xp_reward(s)
		for s in captured:
			total_xp += BattleLogic.xp_reward(s)
		lines.append("획득 경험치 %d" % total_xp)
		for s in GameState.party:
			lines.append_array((s as Spirit).gain_xp(total_xp))
		for s in captured:
			var where := GameState.add_captured(s)
			lines.append("%s 계약 완료 → %s" % [(s as Spirit).display_name(), where])
		if rng.randf() < 0.4:
			var eid := GameData.random_equipment(rng)
			GameState.inventory.append(eid)
			lines.append("장비 획득: %s" % GameData.equipment_desc(eid))
		GameState.battles_won += 1
	else:
		lines.append("정령들이 모두 지쳐 쓰러졌다...")
		lines.append("거점으로 돌아가 회복합니다.")
	GameState.heal_all()
	GameState.save_game()
	_mark_ui()
	_show_result(victory, lines)


# ================================================================ 입력

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.position.y > get_viewport_rect().size.y - PANEL_HEIGHT:
		return
	_on_tap(mb.position)


func _on_tap(pos: Vector2) -> void:
	var c := grid.from_pixel(pos)
	if not grid.in_bounds(c):
		return
	var u := _unit_at(c)
	match phase:
		"player":
			if not has_moved and reachable.has(c):
				_move_player(c)
			else:
				inspected = u if u != active else null
				_mark_ui()
		"targeting":
			if targets.has(c):
				_execute_player_action(targets[c])
			else:
				_cancel_targeting()


func _unit_at(c: Vector2i) -> BattleUnit:
	for o in units:
		var u: BattleUnit = o
		if u.is_active() and u.cell == c:
			return u
	return null


func _occupied(exclude: BattleUnit) -> Dictionary:
	var result := {}
	for o in units:
		var u: BattleUnit = o
		if u != exclude and u.is_active():
			result[u.cell] = u
	return result


# ================================================================ 아군 행동

func _move_player(c: Vector2i) -> void:
	phase = "busy"
	show_skills = false
	inspected = null
	_mark_ui()
	await _animate_move(active, c)
	has_moved = true
	reachable = {}
	phase = "player"
	_mark_ui()


func _on_attack() -> void:
	_begin_targeting({"type": "attack"})


func _on_skills() -> void:
	show_skills = true
	_mark_ui()


func _on_close_skills() -> void:
	show_skills = false
	_mark_ui()


func _choose_skill(sid: String) -> void:
	show_skills = false
	_begin_targeting({"type": "skill", "skill_id": sid})


func _on_dispel() -> void:
	_begin_targeting({"type": "dispel"})


func _on_wait() -> void:
	if phase != "player":
		return
	_log("%s은(는) 대기했다." % active.spirit.display_name())
	_end_turn()


func _on_retreat() -> void:
	if phase != "player":
		return
	phase = "over"
	GameState.heal_all()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _begin_targeting(action: Dictionary) -> void:
	var t := _targets_for(active, active.cell, action)
	if t.is_empty():
		_log("사거리 안에 대상이 없습니다.")
		_mark_ui()
		return
	pending = action
	targets = t
	inspected = null
	phase = "targeting"
	_mark_ui()


func _cancel_targeting() -> void:
	phase = "player"
	pending = {}
	targets = {}
	_mark_ui()


func _execute_player_action(target: BattleUnit) -> void:
	var action := pending
	phase = "busy"
	pending = {}
	targets = {}
	_mark_ui()
	await _perform(active, action, target)
	_end_turn()


## from_cell에서 action을 쓸 때 노릴 수 있는 적: 칸 -> BattleUnit
func _targets_for(u: BattleUnit, from_cell: Vector2i, action: Dictionary) -> Dictionary:
	var rmin := 1
	var rmax := BattleLogic.BASIC_ATTACK_RANGE
	match str(action["type"]):
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			rmin = int(sk["range_min"])
			rmax = int(sk["range_max"])
		"dispel":
			rmax = BattleLogic.DISPEL_RANGE
	var result := {}
	for o in units:
		var other: BattleUnit = o
		if not other.is_active() or other.team == u.team:
			continue
		var d := grid.distance(from_cell, other.cell)
		if d >= rmin and d <= rmax:
			result[other.cell] = other
	return result


# ================================================================ 행동 처리 (공용)

func _perform(u: BattleUnit, action: Dictionary, target: BattleUnit) -> void:
	var s := u.spirit
	match str(action["type"]):
		"attack":
			var dmg := BattleLogic.calc_damage(s, target.spirit, BattleLogic.BASIC_ATTACK_POWER, s.element(), rng)
			_hit(u, target, dmg, "공격", s.element())
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			s.mp = maxi(0, s.mp - int(sk["mp"]))
			var skill_dmg := BattleLogic.calc_damage(s, target.spirit, int(sk["power"]), str(sk["element"]), rng)
			_hit(u, target, skill_dmg, str(sk["name"]), str(sk["element"]))
		"dispel":
			_try_dispel(u, target)
	await get_tree().create_timer(ACTION_DELAY).timeout


func _hit(attacker: BattleUnit, target: BattleUnit, dmg: int, action_name: String, element: String) -> void:
	target.spirit.hp = maxi(0, target.spirit.hp - dmg)
	var mult := GameData.element_multiplier(element, target.spirit.element())
	var msg := "%s의 %s! %s에게 %d 피해" % [
		attacker.spirit.display_name(), action_name, target.spirit.display_name(), dmg]
	var color := Color.WHITE
	if mult > 1.0:
		msg += " (효과가 굉장하다!)"
		color = Color(1.0, 0.8, 0.3)
	elif mult < 1.0:
		msg += " (효과가 별로...)"
		color = Color(0.7, 0.7, 0.8)
	_log(msg)
	_effect(str(dmg), target.draw_pos, color)
	if target.spirit.hp <= 0:
		target.alive = false
		_log("%s이(가) 쓰러졌다!" % target.spirit.display_name())
		if target.team == 1:
			defeated.append(target.spirit)


func _try_dispel(u: BattleUnit, target: BattleUnit) -> void:
	var chance := BattleLogic.dispel_chance(u.spirit, target.spirit)
	var pct := int(round(chance * 100.0))
	_log("%s이(가) 디스펠을 시도했다... (성공률 %d%%)" % [u.spirit.display_name(), pct])
	if rng.randf() < chance:
		target.captured = true
		captured.append(target.spirit)
		_log("디스펠 성공! %s과(와) 계약했다!" % target.spirit.display_name())
		_effect("계약!", target.draw_pos, Color(0.5, 1.0, 0.7))
	else:
		_log("디스펠 실패! %s이(가) 저항했다." % target.spirit.display_name())
		_effect("실패", target.draw_pos, Color(0.8, 0.8, 0.9))


func _animate_move(u: BattleUnit, c: Vector2i) -> void:
	u.cell = c
	var tw := create_tween()
	tw.tween_property(u, "draw_pos", grid.to_pixel(c), 0.22)
	await tw.finished


# ================================================================ 적 AI

func _run_enemy_turn() -> void:
	phase = "enemy"
	_mark_ui()
	await get_tree().create_timer(ENEMY_DELAY).timeout
	var u := active
	var plan := _plan_enemy(u)
	var dest: Vector2i = plan["cell"]
	if dest != u.cell:
		await _animate_move(u, dest)
	if plan.has("action"):
		await _perform(u, plan["action"], plan["target"])
	_end_turn()


## 이동 가능한 모든 칸 × 모든 행동 × 모든 대상 중 점수가 가장 높은 조합을 고른다.
## 공격할 수 없으면 가장 가까운 아군 쪽으로 다가간다.
func _plan_enemy(u: BattleUnit) -> Dictionary:
	var cells := grid.reachable(u.cell, u.spirit.stat("mov"), _occupied(u))
	cells[u.cell] = 0
	var actions := [{"type": "attack"}]
	for sid in u.spirit.known_skills():
		if u.spirit.mp >= int(GameData.skills[sid]["mp"]):
			actions.append({"type": "skill", "skill_id": sid})

	var best := {}
	var best_score := -1.0
	for cell in cells:
		for action in actions:
			var power := BattleLogic.BASIC_ATTACK_POWER
			var element := u.spirit.element()
			var mp_cost := 0
			if action["type"] == "skill":
				var sk: Dictionary = GameData.skills[action["skill_id"]]
				power = int(sk["power"])
				element = str(sk["element"])
				mp_cost = int(sk["mp"])
			var t := _targets_for(u, cell, action)
			for tcell in t:
				var target: BattleUnit = t[tcell]
				var expected := BattleLogic.calc_damage(u.spirit, target.spirit, power, element)
				var score := float(mini(expected, target.spirit.hp)) - mp_cost * 0.3
				if expected >= target.spirit.hp:
					score += 50.0
				score -= int(cells[cell]) * 0.1  # 같은 값이면 덜 움직이는 쪽
				if score > best_score:
					best_score = score
					best = {"cell": cell, "action": action, "target": target}
	if not best.is_empty():
		return best

	var best_cell := u.cell
	var best_dist := 9999
	for cell in cells:
		var d := _nearest_foe_distance(u, cell)
		if d < best_dist:
			best_dist = d
			best_cell = cell
	return {"cell": best_cell}


func _nearest_foe_distance(u: BattleUnit, cell: Vector2i) -> int:
	var best := 9999
	for o in units:
		var other: BattleUnit = o
		if other.is_active() and other.team != u.team:
			best = mini(best, grid.distance(cell, other.cell))
	return best


# ================================================================ 그리기

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_BG)
	for row in ROWS:
		for col in COLS:
			var c := Vector2i(col, row)
			var center := grid.to_pixel(c)
			var pts := grid.corners(center, HEX_SIZE - 1.5)
			draw_colored_polygon(pts, _cell_color(c))
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, COLOR_OUTLINE, 2.0)
			if grid.blocked.has(c):
				draw_circle(center, HEX_SIZE * 0.45, Color(0.3, 0.28, 0.25))
				draw_circle(center + Vector2(-6, -6), HEX_SIZE * 0.18, Color(0.4, 0.37, 0.33))

	for o in units:
		var u: BattleUnit = o
		if u.is_active():
			_draw_unit(u)

	if phase == "targeting":
		for tcell in targets:
			var t: BattleUnit = targets[tcell]
			_draw_text(_preview_text(t), t.draw_pos + Vector2(0, -44), 20, Color(1.0, 0.9, 0.4))

	for e in effects:
		var a := 1.0 - float(e["t"])
		var col: Color = e["color"]
		col.a = a
		_draw_text(str(e["text"]), e["pos"] + Vector2(0, -50.0 * float(e["t"]) - 10.0), 28, col)


func _cell_color(c: Vector2i) -> Color:
	if grid.blocked.has(c):
		return COLOR_BLOCKED
	if phase == "targeting" and targets.has(c):
		var pulse := 0.5 + 0.5 * sin(time * 6.0)
		return Color(0.55 + 0.15 * pulse, 0.2, 0.22)
	if phase == "player" and not has_moved and reachable.has(c):
		return COLOR_MOVE
	if active != null and active.cell == c:
		return COLOR_ACTIVE_CELL
	return COLOR_CELL


func _draw_unit(u: BattleUnit) -> void:
	var p := u.draw_pos
	var el_color := GameData.element_color(u.spirit.element())
	var ring := Color(0.95, 0.95, 1.0) if u.team == 0 else Color(0.9, 0.2, 0.25)
	if u == active:
		var pulse := 0.5 + 0.5 * sin(time * 6.0)
		draw_arc(p, 38.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.4 + 0.6 * pulse), 4.0)
	if u == inspected:
		draw_arc(p, 38.0, 0.0, TAU, 40, Color(0.6, 0.9, 1.0), 3.0)
	draw_circle(p, 30.0, el_color.darkened(0.2))
	draw_arc(p, 30.0, 0.0, TAU, 40, ring, 3.0)
	_draw_text(u.spirit.display_name(), p + Vector2(0, 2), 16, Color.WHITE)
	_draw_text("Lv%d" % u.spirit.level, p + Vector2(0, 20), 14, Color(1, 1, 1, 0.85))
	var ratio := float(u.spirit.hp) / float(maxi(1, u.spirit.max_hp()))
	var bar := Rect2(p + Vector2(-28, 33), Vector2(56, 6))
	draw_rect(bar, Color(0, 0, 0, 0.75))
	var hp_color := Color(0.4, 0.9, 0.45) if ratio > 0.5 else (Color(0.95, 0.8, 0.3) if ratio > 0.25 else Color(0.95, 0.35, 0.3))
	draw_rect(Rect2(bar.position, Vector2(56.0 * ratio, 6)), hp_color)


## pos.y는 글자 아랫선(baseline) 기준, x는 가운데 정렬
func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	var width := 160.0
	var at := Vector2(pos.x - width * 0.5, pos.y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _preview_text(t: BattleUnit) -> String:
	match str(pending.get("type", "")):
		"dispel":
			return "%d%%" % int(round(BattleLogic.dispel_chance(active.spirit, t.spirit) * 100.0))
		"skill":
			var sk: Dictionary = GameData.skills[pending["skill_id"]]
			return "-%d" % BattleLogic.calc_damage(active.spirit, t.spirit, int(sk["power"]), str(sk["element"]))
		"attack":
			return "-%d" % BattleLogic.calc_damage(active.spirit, t.spirit, BattleLogic.BASIC_ATTACK_POWER, active.spirit.element())
	return ""


func _effect(text: String, pos: Vector2, color: Color) -> void:
	effects.append({"text": text, "pos": pos, "color": color, "t": 0.0})


# ================================================================ UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.theme = GameData.theme
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_root)

	turn_label = Label.new()
	turn_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	turn_label.offset_top = 36
	turn_label.offset_bottom = 110
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 28)
	ui_root.add_child(turn_label)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -PANEL_HEIGHT
	panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.17, 0.97)
	style.border_width_top = 2
	style.border_color = Color(0.35, 0.4, 0.55)
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	info_label = UIKit.label("", 23)
	vb.add_child(info_label)
	hint_label = UIKit.label("", 21, UIKit.GOLD)
	vb.add_child(hint_label)
	action_box = GridContainer.new()
	action_box.columns = 3
	action_box.add_theme_constant_override("h_separation", 10)
	action_box.add_theme_constant_override("v_separation", 10)
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(action_box)
	log_label = UIKit.label("", 19, UIKit.MUTED)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.clip_text = true
	vb.add_child(log_label)


func _mark_ui() -> void:
	_ui_dirty = true


func _rebuild_ui() -> void:
	for c in action_box.get_children():
		action_box.remove_child(c)
		c.queue_free()

	if active != null:
		var who := "아군" if active.team == 0 else "야생"
		turn_label.text = "라운드 %d · %s %s의 차례" % [round_num, who, active.spirit.display_name()]
	elif phase == "over":
		turn_label.text = "전투 종료"
	info_label.text = _unit_info(inspected if inspected != null else active)

	match phase:
		"player":
			if show_skills:
				for sid in active.spirit.known_skills():
					var sk: Dictionary = GameData.skills[sid]
					_add_action("%s\nMP %d" % [sk["name"], int(sk["mp"])], func(): _choose_skill(sid), active.spirit.mp < int(sk["mp"]))
				_add_action("뒤로", _on_close_skills)
				hint_label.text = "사용할 스킬을 고르세요."
			else:
				_add_action("공격", _on_attack)
				_add_action("스킬", _on_skills, active.spirit.known_skills().is_empty())
				_add_action("디스펠", _on_dispel)
				_add_action("대기", _on_wait)
				_add_action("후퇴", _on_retreat)
				hint_label.text = "파란 칸을 눌러 이동하거나 행동을 고르세요." if not has_moved else "행동을 고르세요."
		"targeting":
			_add_action("취소", _cancel_targeting)
			if pending.get("type", "") == "dispel":
				hint_label.text = "계약할 야생 정령을 누르세요. (숫자 = 성공 확률)"
			else:
				hint_label.text = "공격할 대상을 누르세요. (숫자 = 예상 피해)"
		"enemy":
			hint_label.text = "야생 정령이 움직이고 있다..."
		_:
			hint_label.text = ""

	log_label.text = "\n".join(PackedStringArray(log_lines))


func _add_action(text: String, cb: Callable, disabled: bool = false) -> void:
	var b := UIKit.button(text, cb, disabled, 72)
	b.add_theme_font_size_override("font_size", 24)
	action_box.add_child(b)


func _unit_info(u: BattleUnit) -> String:
	if u == null:
		return ""
	var s := u.spirit
	var tag := "아군" if u.team == 0 else "야생"
	return "[%s] %s  Lv.%d  %s 속성\nHP %d/%d   MP %d/%d   공%d 방%d 속%d 이동%d" % [
		tag, s.display_name(), s.level, GameData.element_name(s.element()),
		s.hp, s.max_hp(), s.mp, s.max_mp(),
		s.stat("atk"), s.stat("def"), s.stat("spd"), s.stat("mov")]


func _log(text: String) -> void:
	log_lines.append(text)
	while log_lines.size() > 4:
		log_lines.pop_front()
	_mark_ui()


func _show_result(victory: bool, lines: Array[String]) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	var vb := UIKit.screen(overlay, 180, 100, false)
	vb.add_child(UIKit.label("승리!" if victory else "패배", 60, UIKit.GOLD if victory else Color(1, 0.5, 0.45), true))
	var list := UIKit.scroll_list(vb)
	for line in lines:
		list.add_child(UIKit.label(line, 26, Color.WHITE, true))
	vb.add_child(UIKit.button("거점으로", _return_to_hub))


func _return_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
