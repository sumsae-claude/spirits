extends Node2D
## 헥스 턴제 전투 씬. 맵/유닛은 _draw()로 그리고, UI는 코드로 생성한다.
##
## 아군은 정령사 한 명으로 시작하고, 선봉 정령 1마리가 자동 소환된다.
## 라운드 = 아군 턴 → 적 턴. 아군 턴에는 행동할 유닛을 원하는 순서로 골라 움직인다.
##  - 정령사: (이동) → 소환 / 귀환 / 디스펠 / 스킬 / 공격 / 대기
##  - 정령:   (이동) → 공격 / 스킬 / 귀환 / 대기   ※ 소환된 다음 라운드부터 행동
##  - 이동 후 행동 전이면 이동 취소 가능. 모두 행동하거나 '턴 종료'하면 적 턴.
## 상대는 야생 정령 무리, 또는 정령을 소환하는 적 정령사.
## 정령사가 쓰러지면 패배. 적을 모두 쓰러뜨리거나 계약하면, 또는 적 정령사를 쓰러뜨리면 승리.

const COLS := 8
const ROWS := 10
const HEX_SIZE := 44.0
const MAP_TOP := 130.0
const PANEL_HEIGHT := 460.0
const ENEMY_DELAY := 0.35
const ACTION_DELAY := 0.55
const ENEMY_SPAWN_COLS := [3, 4, 2, 5]
const SUMMONER_CELL := Vector2i(3, 9)   # 맨 아래 행
const VANGUARD_CELL := Vector2i(3, 8)   # 정령사 바로 위
const ENEMY_SUMMONER_CELL := Vector2i(4, 0)  # 맨 위 행
const ENEMY_VANGUARD_CELL := Vector2i(4, 1)  # 적 정령사 바로 아래
## 적 정령사가 아군과 유지하려는 거리
const ENEMY_SUMMONER_KEEP_DISTANCE := 3.0
## 소환되지 않은 계약 정령이 받는 경험치 비율
const BENCH_XP_RATIO := 0.3
## [지형 id, 덩어리 개수, 덩어리 크기] — 출발 행(0~1, 8~9)을 피해 2~7행에 배치
const TERRAIN_PLAN := [["circle", 2, 1], ["forest", 2, 4], ["water", 2, 3], ["hill", 2, 3], ["lava", 1, 3], ["rock", 4, 1]]
const TERRAIN_ROW_MIN := 2
const TERRAIN_ROW_MAX := 7

const COLOR_BG := Color(0.07, 0.08, 0.11)
const COLOR_MOVE := Color(0.25, 0.5, 0.9)
const COLOR_TARGET := Color(0.85, 0.2, 0.22)
const COLOR_ALLY_TARGET := Color(0.3, 0.85, 0.75)
const COLOR_PLACE := Color(0.55, 0.85, 1.0)
const COLOR_ACTIVE_CELL := Color(0.9, 0.8, 0.3)
const COLOR_OUTLINE := Color(0.35, 0.4, 0.5, 0.6)
const COLOR_OWNED_RING := Color(0.75, 0.4, 0.95)
const COLOR_INSPECT_MOVE := Color(0.95, 0.65, 0.2)
const COLOR_ADV_GOOD := Color(0.3, 0.9, 0.4)    # 상성 유리
const COLOR_ADV_EVEN := Color(0.95, 0.8, 0.3)   # 보통
const COLOR_ADV_BAD := Color(0.5, 0.5, 0.58)    # 불리
const COLOR_INSPECT_THREAT := Color(0.9, 0.25, 0.3)

var grid: HexGrid
var units: Array = []        # 전장에 있는 BattleUnit (귀환하면 빠진다)
var round_num := 0
var summoner_unit: BattleUnit = null
var enemy_summoner_unit: BattleUnit = null  # 정령사 대결일 때만
var enemy_bench: Array = []                 # 적 정령사가 아직 소환하지 않은 정령
var active: BattleUnit = null
var inspected: BattleUnit = null
var inspected_cell := Vector2i(-1, -1)  # 유닛 없는 칸을 눌렀을 때 지형 정보 표시용
## select(아군 고르는 중) / player(선택한 유닛 조작) / targeting / placing / busy / enemy / over
var phase := "idle"
var has_moved := false
var move_origin := Vector2i(-1, -1)  # 이동 취소용
var submenu := ""               # "", "skills"(정령 스킬), "sskills"(정령사 스킬), "summon"
var pending: Dictionary = {}
var reachable: Dictionary = {}  # Vector2i -> 비용
var targets: Dictionary = {}    # Vector2i -> BattleUnit
var place_cells: Dictionary = {}  # 소환할 수 있는 칸 Vector2i -> true
## 누른 유닛의 이동 범위 / 공격 가능 범위 (표시용 캐시)
var inspect_move: Dictionary = {}
var inspect_threat: Dictionary = {}
var _inspect_key := ""
## 선택한 아군 기준 표시용 캐시
var preview_cell := Vector2i(-1, -1)  # 이동 미리보기 칸 (한 번 더 누르면 이동)
var range_cells: Dictionary = {}      # 현재(또는 미리보기) 위치에서 공격이 닿는 칸 → 빨간 테두리
var hit_now: Dictionary = {}          # 그 위치에서 바로 공격 가능한 적의 칸 → 빨간 조준
var reach_targets: Dictionary = {}    # 이동하면 공격 가능한 적의 칸 → 주황 링
var _active_key := ""
var choose_target: BattleUnit = null   # 눌러서 행동 메뉴를 연 대상
var summoning := false                 # 이번 정령사 행동에서 소환을 시작함 (연속 소환 중)
var participated: Array = []    # 이번 전투에 소환된 계약 Spirit
var defeated: Array = []        # 쓰러뜨린 야생 Spirit
var captured: Array = []        # 계약한 야생 Spirit
var effects: Array = []         # 떠오르는 텍스트
var rng := RandomNumberGenerator.new()
var font: Font
var time := 0.0

var ui_root: Control
var turn_label: Label
var legend_label: RichTextLabel
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
	if GameState.summoner == null:
		GameState.summoner = Summoner.create_summoner(GameState.DEFAULT_NAME, "fire", 5)
	if GameState.party.is_empty():
		GameState.party = [Spirit.create("emberbean", 5), Spirit.create("dewdrop", 4)]
	if GameState.current_encounter.is_empty() and GameState.current_rival.is_empty():
		GameState.current_encounter = GameState.make_encounter()

	_generate_terrain()
	summoner_unit = _add_unit(GameState.summoner, 0, SUMMONER_CELL)
	summoner_unit.is_summoner = true
	var bench := _summonable()
	if not bench.is_empty():
		_summon(bench[0], VANGUARD_CELL, false, 0)

	if not GameState.current_rival.is_empty():
		_setup_rival(GameState.current_rival)
	else:
		for i in GameState.current_encounter.size():
			_add_unit(GameState.current_encounter[i], 1, Vector2i(ENEMY_SPAWN_COLS[i], 1))
		_log("야생 정령 %d마리가 나타났다!" % GameState.current_encounter.size())
	GameState.current_encounter = []
	GameState.current_rival = {}


func _setup_rival(rival: Dictionary) -> void:
	var m: Summoner = rival["summoner"]
	enemy_summoner_unit = _add_unit(m, 1, ENEMY_SUMMONER_CELL)
	enemy_summoner_unit.is_summoner = true
	enemy_bench = (rival["party"] as Array).duplicate()
	_log("%s의 정령사 %s이(가) 승부를 걸어왔다!" % [GameData.element_name(m.element()), m.display_name()])
	if not enemy_bench.is_empty():
		_summon(enemy_bench[0], ENEMY_VANGUARD_CELL, false, 1)


func _generate_terrain() -> void:
	for plan in TERRAIN_PLAN:
		for i in int(plan[1]):
			_grow_cluster(str(plan[0]), int(plan[2]))


## 빈 칸 하나에서 시작해 이웃으로 번지며 같은 지형 덩어리를 만든다.
func _grow_cluster(tid: String, cluster_size: int) -> void:
	var start := Vector2i(-1, -1)
	for attempt in 30:
		var c := Vector2i(rng.randi_range(0, COLS - 1), rng.randi_range(TERRAIN_ROW_MIN, TERRAIN_ROW_MAX))
		if not grid.terrain.has(c):
			start = c
			break
	if start.x < 0:
		return
	var cells: Array[Vector2i] = [start]
	_set_terrain(start, tid)
	var tries := 0
	while cells.size() < cluster_size and tries < 20:
		tries += 1
		var from: Vector2i = cells[rng.randi() % cells.size()]
		var options: Array = []
		for n in grid.neighbors(from):
			if not grid.terrain.has(n) and n.y >= TERRAIN_ROW_MIN and n.y <= TERRAIN_ROW_MAX:
				options.append(n)
		if options.is_empty():
			continue
		var pick: Vector2i = options[rng.randi() % options.size()]
		cells.append(pick)
		_set_terrain(pick, tid)


func _set_terrain(c: Vector2i, tid: String) -> void:
	grid.terrain[c] = tid
	if not GameData.terrain_passable(tid):
		grid.blocked[c] = true


func _add_unit(s: Spirit, team: int, cell: Vector2i) -> BattleUnit:
	var u := BattleUnit.new(s, team, cell)
	u.draw_pos = grid.to_pixel(cell)
	u.joined_round = round_num
	units.append(u)
	return u


# ================================================================ 소환 / 귀환

## 지금 소환할 수 있는 계약 정령 (전장에 없고, 이번 전투에서 쓰러지지 않은)
func _summonable() -> Array:
	var result := []
	for o in GameState.party:
		var s: Spirit = o
		if s.hp > 0 and _field_unit_of(s) == null:
			result.append(s)
	return result


func _field_unit_of(s: Spirit) -> BattleUnit:
	for o in units:
		var u: BattleUnit = o
		if u.spirit == s and u.is_active():
			return u
	return null


func _summoned_count(team: int = 0) -> int:
	var n := 0
	for o in units:
		var u: BattleUnit = o
		if u.team == team and not u.is_summoner and u.is_active():
			n += 1
	return n


func _can_summon_more() -> bool:
	return _summoned_count() < GameState.summoner.summon_limit() and not _summonable().is_empty()


func _summoner_of(team: int) -> BattleUnit:
	return summoner_unit if team == 0 else enemy_summoner_unit


## 정령사 주변의 빈 칸
func _free_cells_around(c: Vector2i) -> Dictionary:
	var occ := _occupied(null)
	var result := {}
	for n in grid.neighbors(c):
		if grid.is_walkable(n) and not occ.has(n):
			result[n] = true
	return result


func _summon(s: Spirit, cell: Vector2i, pay: bool, team: int) -> BattleUnit:
	var m: Summoner = _summoner_of(team).spirit
	if pay:
		m.mp = maxi(0, m.mp - m.summon_cost(s))
	var u := _add_unit(s, team, cell)
	if team == 0:
		if not participated.has(s):
			participated.append(s)
		_log("%s을(를) 소환했다! (다음 라운드부터 행동)" % s.display_name())
	else:
		u.owned = true
		enemy_bench.erase(s)
		_log("적 정령사 %s이(가) %s을(를) 소환했다!" % [m.display_name(), s.display_name()])
	_effect("소환!", u.draw_pos, COLOR_PLACE)
	return u


func _recall(u: BattleUnit) -> void:
	u.recalled = true
	units.erase(u)
	_log("%s이(가) 정령사 곁으로 돌아왔다." % u.spirit.display_name())
	_effect("귀환", u.draw_pos, COLOR_ALLY_TARGET)


# ================================================================ 턴 진행

func _start_round() -> void:
	round_num += 1
	for o in units:
		var u: BattleUnit = o
		u.done = false
		if round_num > 1 and u.is_active():
			u.tick_buffs()
			var regen := (u.spirit as Summoner).mp_regen() if u.is_summoner else BattleLogic.MP_REGEN_PER_ROUND
			u.spirit.mp = mini(u.spirit.max_mp(), u.spirit.mp + regen)
	if round_num > 1:
		_apply_round_terrain()
	if _check_end():
		return
	_start_player_phase()


# ---------------------------------------------------------------- 아군 턴

func _start_player_phase() -> void:
	_clear_selection()
	if _ready_allies().is_empty():
		_start_enemy_phase()
		return
	phase = "select"
	_mark_ui()


## 이번 아군 턴에 아직 행동할 수 있는 유닛 (방금 소환된 정령 제외)
func _ready_allies() -> Array:
	var result := []
	for o in units:
		var u: BattleUnit = o
		if _is_ready(u):
			result.append(u)
	return result


func _is_ready(u: BattleUnit) -> bool:
	return u != null and u.team == 0 and u.is_active() and not u.done and u.joined_round < round_num


func _clear_selection() -> void:
	active = null
	preview_cell = Vector2i(-1, -1)
	choose_target = null
	summoning = false
	has_moved = false
	move_origin = Vector2i(-1, -1)
	submenu = ""
	pending = {}
	reachable = {}
	targets = {}
	place_cells = {}


func _select_unit(u: BattleUnit) -> void:
	_clear_selection()
	active = u
	inspected = null
	inspected_cell = Vector2i(-1, -1)
	reachable = _reachable_for(u)
	phase = "player"
	_mark_ui()


func _deselect() -> void:
	_clear_selection()
	phase = "select"
	_mark_ui()


## 선택한 유닛의 행동이 끝났을 때
func _finish_unit() -> void:
	if active != null:
		active.done = true
	_clear_selection()
	if _check_end():
		return
	if _ready_allies().is_empty():
		_start_enemy_phase()
	else:
		phase = "select"
		_mark_ui()


func _on_end_phase() -> void:
	if phase != "select" and phase != "player":
		return
	if phase == "player" and has_moved:
		_log("먼저 행동하거나 이동을 취소하세요.")
		return
	for o in _ready_allies():
		var bu: BattleUnit = o
		bu.done = true
	_start_enemy_phase()


# ---------------------------------------------------------------- 적 턴

func _start_enemy_phase() -> void:
	_clear_selection()
	phase = "enemy"
	_mark_ui()
	var order := []
	for o in units:
		var u: BattleUnit = o
		if u.team == 1 and u.is_active() and u.joined_round < round_num:
			order.append(u)
	order.sort_custom(_compare_speed)
	for o in order:
		var u: BattleUnit = o
		if not u.is_active():
			continue
		active = u
		_mark_ui()
		if u.is_summoner:
			await _run_enemy_summoner_turn(u)
		else:
			await _run_enemy_turn(u)
		active = null
		if _check_end():
			return
	_start_round()


## 라운드 시작 시 지형 효과: 물가/용암/마법진의 회복, 용암 화상
func _apply_round_terrain() -> void:
	for o in units.duplicate():
		var u: BattleUnit = o
		if not u.is_active():
			continue
		var tid := grid.terrain_at(u.cell)
		var mp_ratio := GameData.terrain_round_mp(tid)
		if mp_ratio > 0.0 and u.spirit.mp < u.spirit.max_mp():
			var mp_gain := mini(u.spirit.max_mp() - u.spirit.mp, maxi(1, int(round(u.spirit.max_mp() * mp_ratio))))
			u.spirit.mp += mp_gain
			_effect("MP+%d" % mp_gain, u.draw_pos + Vector2(0, 18), Color(0.55, 0.75, 1.0))
		var ratio := GameData.terrain_round_hp(tid, u.spirit.element())
		if ratio == 0.0:
			continue
		var amount := maxi(1, int(round(u.spirit.max_hp() * absf(ratio))))
		if ratio > 0.0:
			if u.spirit.hp >= u.spirit.max_hp():
				continue
			u.spirit.hp = mini(u.spirit.max_hp(), u.spirit.hp + amount)
			_effect("+%d" % amount, u.draw_pos, Color(0.5, 1.0, 0.6))
			_log("%s이(가) %s에서 기운을 회복했다. (+%d)" % [u.spirit.display_name(), GameData.terrain_name(tid), amount])
		else:
			u.spirit.hp = maxi(0, u.spirit.hp - amount)
			_effect("-%d" % amount, u.draw_pos, Color(1.0, 0.55, 0.25))
			_log("%s이(가) %s의 열기에 %d 피해를 입었다." % [u.spirit.display_name(), GameData.terrain_name(tid), amount])
			if u.spirit.hp <= 0:
				_knock_out(u)


func _compare_speed(a: BattleUnit, b: BattleUnit) -> bool:
	var sa := a.spirit.stat("spd")
	var sb := b.spirit.stat("spd")
	if sa == sb:
		return a.team < b.team
	return sa > sb


func _check_end() -> bool:
	if phase == "over":
		return true
	if not summoner_unit.is_active():
		_finish(false)
		return true
	if enemy_summoner_unit != null and not enemy_summoner_unit.is_active():
		_finish(true)
		return true
	for o in units:
		var u: BattleUnit = o
		if u.team == 1 and u.is_active():
			return false
	_finish(true)
	return true


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
		var beat_rival := enemy_summoner_unit != null and not enemy_summoner_unit.is_active()
		if beat_rival:
			var bonus := BattleLogic.xp_reward(enemy_summoner_unit.spirit) * 2
			total_xp += bonus
			lines.append("적 정령사 %s을(를) 쓰러뜨렸다! (보너스 경험치 %d)" % [enemy_summoner_unit.spirit.display_name(), bonus])
		lines.append("획득 경험치 %d (소환하지 않은 정령은 %d%%)" % [total_xp, int(BENCH_XP_RATIO * 100)])
		lines.append_array(GameState.summoner.gain_xp(total_xp))
		for o in GameState.party:
			var s: Spirit = o
			var amount := total_xp if participated.has(s) else int(round(total_xp * BENCH_XP_RATIO))
			lines.append_array(s.gain_xp(amount))
		if beat_rival or rng.randf() < 0.4:
			var eid := GameData.random_equipment(rng)
			GameState.inventory.append(eid)
			lines.append("장비 획득: %s" % GameData.equipment_desc(eid))
		GameState.battles_won += 1
	else:
		lines.append("%s이(가) 쓰러졌다..." % GameState.summoner.display_name())
		lines.append("정령들과 함께 거점으로 돌아가 회복합니다.")
	lines.append_array(_keep_captured())
	GameState.heal_all()
	GameState.save_game()
	_mark_ui()
	_show_result(victory, lines)


## 디스펠로 계약한 정령은 승패·후퇴와 관계없이 내 정령이 된다.
func _keep_captured() -> Array[String]:
	var lines: Array[String] = []
	for o in captured:
		var s: Spirit = o
		var where := GameState.add_captured(s)
		lines.append("%s 계약 완료 → %s" % [s.display_name(), where])
	captured = []
	return lines


# ================================================================ 이동/피해 공용

func _move_cost_fn(u: BattleUnit) -> Callable:
	var el := u.spirit.element()
	return func(c: Vector2i) -> int: return GameData.terrain_move_cost(grid.terrain_at(c), el)


func _reachable_for(u: BattleUnit) -> Dictionary:
	return grid.reachable(u.cell, u.spirit.stat("mov") + u.stat_add("mov"), _occupied(u), _move_cost_fn(u))


func _attack_power(u: BattleUnit) -> int:
	if u.is_summoner:
		return (u.spirit as Summoner).attack_power()
	return BattleLogic.BASIC_ATTACK_POWER


## 지형까지 반영한 피해 계산. use_rng=false면 기대값.
func _damage(attacker: BattleUnit, from_cell: Vector2i, target: BattleUnit, power: int, element: String, use_rng: bool) -> int:
	return BattleLogic.calc_damage(attacker.spirit, target.spirit, power, element,
		rng if use_rng else null, grid.terrain_at(from_cell), grid.terrain_at(target.cell),
		attacker.stat_mult("atk"), target.stat_mult("def"))


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
		"select":
			if _is_ready(u):
				_select_unit(u)
			else:
				_inspect(u, c)
		"player":
			if summoning:
				_inspect(u if u != active else null, c)
			elif not has_moved and reachable.has(c):
				if c == preview_cell:
					_move_player(c)
				else:
					preview_cell = c
					_mark_ui()
			elif u == active and not has_moved:
				if grid.in_bounds(preview_cell):
					preview_cell = Vector2i(-1, -1)
					_mark_ui()
				else:
					_deselect()
			elif u != null and u.team != 0 and grid.in_bounds(preview_cell) and not has_moved:
				# 미리보기 칸으로 이동한 뒤 그 적에 대한 행동 메뉴
				_move_then_menu(preview_cell, u)
			elif _is_ready(u) and u != active:
				if has_moved:
					_log("먼저 행동하거나 이동을 취소하세요.")
				else:
					_select_unit(u)
			elif u != null and u != active and not _target_options(active, u).is_empty():
				_open_target_menu(u)
			else:
				_inspect(u if u != active else null, c)
		"choose":
			if u != null and u != active and not _target_options(active, u).is_empty():
				_open_target_menu(u)
			else:
				_cancel_choose()
		"targeting":
			if targets.has(c):
				_execute_player_action(targets[c])
			else:
				_cancel_targeting()
		"placing":
			if place_cells.has(c):
				_execute_summon(pending["spirit"], c)
			else:
				_cancel_targeting()


## 이 유닛이 쓸 수 있는 가장 긴 공격 사거리 (일반 공격 / 정령 스킬 / 정령사 공격 스킬)
func _max_attack_range(u: BattleUnit) -> int:
	var r := BattleLogic.BASIC_ATTACK_RANGE
	if u.is_summoner:
		for o in (u.spirit as Summoner).skill_ids:
			var sk: Dictionary = GameData.summoner_skills[str(o)]
			if str(sk.get("type", "")) in ["attack", "debuff"]:
				r = maxi(r, int(sk.get("range_max", 1)))
	else:
		for sid in u.spirit.known_skills():
			r = maxi(r, int(GameData.skills[sid]["range_max"]))
	return r


## 누른 유닛이 다음 차례에 갈 수 있는 칸과, 거기서 공격이 닿는 칸을 계산해 둔다.
func _update_inspect_overlay() -> void:
	var key := ""
	if inspected != null and inspected.is_active():
		key = "%d:%s:%d:%d" % [inspected.get_instance_id(), str(inspected.cell), round_num, units.size()]
	if key == _inspect_key:
		return
	_inspect_key = key
	inspect_move = {}
	inspect_threat = {}
	if key == "":
		return
	inspect_move = _reachable_for(inspected)
	inspect_move[inspected.cell] = 0
	var rmax := _max_attack_range(inspected)
	for row in ROWS:
		for col in COLS:
			var c := Vector2i(col, row)
			if inspect_move.has(c) or grid.blocked.has(c):
				continue
			for m in inspect_move:
				var d := grid.distance(m, c)
				if d >= 1 and d <= rmax:
					inspect_threat[c] = true
					break


## from_cells(칸 -> any) 중 하나에서 거리 1~rmax 안에 드는 칸 (from_cells와 바위 제외)
func _threat_from(from_cells: Dictionary, rmax: int) -> Dictionary:
	var result := {}
	for row in ROWS:
		for col in COLS:
			var c := Vector2i(col, row)
			if from_cells.has(c) or grid.blocked.has(c):
				continue
			for f in from_cells:
				var d := grid.distance(f, c)
				if d >= 1 and d <= rmax:
					result[c] = true
					break
	return result


func _update_active_overlay() -> void:
	var key := ""
	if active != null and active.team == 0 and phase in ["player", "choose"]:
		key = "%d:%s:%s:%s:%d" % [active.get_instance_id(), str(active.cell), str(has_moved), str(preview_cell), units.size()]
	if key == _active_key:
		return
	_active_key = key
	range_cells = {}
	hit_now = {}
	reach_targets = {}
	if key == "":
		return
	var rmax := _max_attack_range(active)
	var origin_cell := preview_cell if grid.in_bounds(preview_cell) else active.cell
	for row in ROWS:
		for col in COLS:
			var c := Vector2i(col, row)
			var d := grid.distance(origin_cell, c)
			if not grid.blocked.has(c) and d >= 1 and d <= rmax:
				range_cells[c] = true
	var from := {active.cell: 0}
	if not has_moved:
		for c in reachable:
			from[c] = 0
	for o in units:
		var e: BattleUnit = o
		if e.team == 0 or not e.is_active():
			continue
		if range_cells.has(e.cell):
			hit_now[e.cell] = true
		for f in from:
			var d2 := grid.distance(f, e.cell)
			if d2 >= 1 and d2 <= rmax:
				reach_targets[e.cell] = true
				break


func _inspect(u: BattleUnit, c: Vector2i) -> void:
	inspected = u
	inspected_cell = c if u == null else Vector2i(-1, -1)
	_mark_ui()


# ================================================================ 아군 행동

func _move_player(c: Vector2i) -> void:
	phase = "busy"
	submenu = ""
	inspected = null
	inspected_cell = Vector2i(-1, -1)
	move_origin = active.cell
	preview_cell = Vector2i(-1, -1)
	_mark_ui()
	await _animate_move(active, c)
	has_moved = true
	reachable = {}
	phase = "player"
	_mark_ui()


func _move_then_menu(c: Vector2i, t: BattleUnit) -> void:
	await _move_player(c)
	if phase == "player" and t.is_active():
		_open_target_menu(t)


func _confirm_preview_move() -> void:
	if grid.in_bounds(preview_cell) and not has_moved:
		_move_player(preview_cell)


func _undo_move() -> void:
	if phase != "player" or not has_moved or summoning:
		return
	phase = "busy"
	submenu = ""
	_mark_ui()
	await _animate_move(active, move_origin)
	has_moved = false
	move_origin = Vector2i(-1, -1)
	reachable = _reachable_for(active)
	phase = "player"
	_mark_ui()


func _on_attack() -> void:
	_begin_targeting({"type": "attack"})


func _open_submenu(which: String) -> void:
	submenu = which
	_mark_ui()


func _close_submenu() -> void:
	submenu = ""
	_mark_ui()


func _choose_skill(sid: String) -> void:
	submenu = ""
	_begin_targeting({"type": "skill", "skill_id": sid})


func _choose_summoner_skill(sid: String) -> void:
	submenu = ""
	_begin_targeting({"type": "sskill", "skill_id": sid})


func _on_dispel() -> void:
	_begin_targeting({"type": "dispel"})


func _on_recall() -> void:
	if active.is_summoner:
		_begin_targeting({"type": "recall"})
	else:
		# 정령 스스로 귀환
		phase = "busy"
		_recall(active)
		_mark_ui()
		await get_tree().create_timer(ACTION_DELAY).timeout
		_finish_unit()


func _choose_summon(s: Spirit) -> void:
	submenu = ""
	var cells := _free_cells_around(active.cell)
	if cells.is_empty():
		_log("정령사 주변에 소환할 빈 칸이 없습니다.")
		_mark_ui()
		return
	pending = {"type": "summon", "spirit": s}
	place_cells = cells
	inspected = null
	inspected_cell = Vector2i(-1, -1)
	phase = "placing"
	_mark_ui()


## 소환 후에도 MP·한도·빈 칸이 남으면 계속 소환할 수 있다. '소환 완료'로 정령사 행동 종료.
func _execute_summon(s: Spirit, cell: Vector2i) -> void:
	phase = "busy"
	pending = {}
	place_cells = {}
	_summon(s, cell, true, 0)
	summoning = true
	has_moved = true          # 소환을 시작하면 더 이상 이동/이동 취소 불가
	move_origin = Vector2i(-1, -1)
	reachable = {}
	_mark_ui()
	await get_tree().create_timer(0.3).timeout
	var stop := _summon_stop_reason()
	if stop == "":
		phase = "player"
		submenu = "summon"
		_mark_ui()
	else:
		_log("더 소환할 수 없어 정령사의 행동을 마쳤다. (%s)" % stop)
		_finish_unit()


## 계속 소환할 수 없는 이유. 가능하면 "".
func _summon_stop_reason() -> String:
	var m := GameState.summoner
	if _summoned_count() >= m.summon_limit():
		return "소환 한도 %d/%d" % [_summoned_count(), m.summon_limit()]
	if _summonable().is_empty():
		return "남은 계약 정령 없음"
	if _free_cells_around(active.cell).is_empty():
		return "주변에 빈 칸 없음"
	for o in _summonable():
		if m.mp >= m.summon_cost(o):
			return ""
	return "MP 부족"


func _on_summon_done() -> void:
	_log("%s이(가) 소환을 마쳤다." % active.spirit.display_name())
	_finish_unit()


func _on_wait() -> void:
	if phase != "player":
		return
	_log("%s은(는) 대기했다." % active.spirit.display_name())
	_finish_unit()


## 후퇴해도 디스펠로 계약한 정령은 데려간다. (경험치·장비 보상은 없음)
func _on_retreat() -> void:
	if phase != "select" and not (phase == "player" and not has_moved):
		return
	phase = "over"
	var lines := _keep_captured()
	GameState.heal_all()
	GameState.save_game()
	if lines.is_empty():
		GameState.hub_message = "전투에서 후퇴했습니다."
	else:
		GameState.hub_message = "후퇴했습니다. " + " / ".join(PackedStringArray(lines))
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


# ---------------------------------------------------------------- 대상을 눌러 행동 고르기

func _open_target_menu(t: BattleUnit) -> void:
	choose_target = t
	inspected = t
	inspected_cell = Vector2i(-1, -1)
	targets = {t.cell: t}
	submenu = ""
	phase = "choose"
	_mark_ui()


func _cancel_choose() -> void:
	choose_target = null
	inspected = null
	targets = {}
	phase = "player"
	_mark_ui()


func _choose_option(action: Dictionary) -> void:
	var t := choose_target
	choose_target = null
	inspected = null
	pending = action
	_execute_player_action(t)


## u가 t에게 할 수 있는 행동 목록: [{"label", "action", "ok"}]. 못 쓰는 것도 이유와 함께 포함.
func _target_options(u: BattleUnit, t: BattleUnit) -> Array:
	var opts := []
	if u == null or t == null:
		return opts
	if t.team != u.team:
		opts.append(_make_option(u, t, {"type": "attack"}, "공격", 0))
		if u.is_summoner:
			var m: Summoner = u.spirit
			if not t.is_summoner:
				opts.append(_make_option(u, t, {"type": "dispel"}, "디스펠", m.dispel_cost()))
			for o in m.skill_ids:
				var sk: Dictionary = GameData.summoner_skills[str(o)]
				if str(sk.get("target", "")) == "enemy":
					opts.append(_make_option(u, t, {"type": "sskill", "skill_id": str(o)}, str(sk["name"]), int(sk["mp"])))
		else:
			for sid in u.spirit.known_skills():
				var sk: Dictionary = GameData.skills[sid]
				opts.append(_make_option(u, t, {"type": "skill", "skill_id": sid}, str(sk["name"]), int(sk["mp"])))
	elif u.is_summoner:
		var m: Summoner = u.spirit
		for o in m.skill_ids:
			var sk: Dictionary = GameData.summoner_skills[str(o)]
			if str(sk.get("target", "")) == "ally":
				opts.append(_make_option(u, t, {"type": "sskill", "skill_id": str(o)}, str(sk["name"]), int(sk["mp"])))
		if not t.is_summoner:
			opts.append(_make_option(u, t, {"type": "recall"}, "귀환", 0))
	return opts


func _make_option(u: BattleUnit, t: BattleUnit, action: Dictionary, name_text: String, mp_cost: int) -> Dictionary:
	var reason := ""
	if u.spirit.mp < mp_cost:
		reason = "MP 부족"
	elif not _targets_for(u, u.cell, action).has(t.cell):
		reason = "사거리 밖"
	var title := name_text if mp_cost == 0 else "%s (MP %d)" % [name_text, mp_cost]
	var detail := reason if reason != "" else _preview_for(u, action, t)
	var el := _action_element(u, action)
	if reason == "" and el != "" and t.team != u.team:
		var mult := GameData.element_multiplier(el, t.spirit.element())
		if mult > 1.0:
			detail += " 유리×1.5"
		elif mult < 1.0:
			detail += " 불리×0.75"
	return {"label": "%s\n%s" % [title, detail], "action": action, "ok": reason == ""}


## 피해를 주는 행동의 속성 (피해가 없으면 "")
func _action_element(u: BattleUnit, action: Dictionary) -> String:
	match str(action.get("type", "")):
		"attack":
			return u.spirit.element()
		"skill":
			return str(GameData.skills[action["skill_id"]]["element"])
		"sskill":
			var sk: Dictionary = GameData.summoner_skills[action["skill_id"]]
			if str(sk["type"]) == "attack":
				return str(sk["element"])
	return ""


## 대상 없이 고르는 버튼(스킬 목록 등)이 지금 쓸 수 없는 이유. 쓸 수 있으면 "".
func _block_reason(u: BattleUnit, action: Dictionary, mp_cost: int) -> String:
	if u.spirit.mp < mp_cost:
		return "MP 부족"
	if _targets_for(u, u.cell, action).is_empty():
		return "대상 없음"
	return ""


func _labeled(title: String, mp_cost: int, reason: String) -> String:
	if reason != "":
		return "%s\n%s" % [title, reason]
	if mp_cost > 0:
		return "%s\nMP %d" % [title, mp_cost]
	return title


func _begin_targeting(action: Dictionary) -> void:
	var t := _targets_for(active, active.cell, action)
	if t.is_empty():
		_log("사거리 안에 대상이 없습니다.")
		_mark_ui()
		return
	pending = action
	targets = t
	inspected = null
	inspected_cell = Vector2i(-1, -1)
	phase = "targeting"
	_mark_ui()


func _cancel_targeting() -> void:
	phase = "player"
	submenu = "summon" if summoning else ""
	pending = {}
	targets = {}
	place_cells = {}
	_mark_ui()


func _execute_player_action(target: BattleUnit) -> void:
	var action := pending
	phase = "busy"
	pending = {}
	targets = {}
	_mark_ui()
	await _perform(active, action, target)
	_finish_unit()


## from_cell에서 action을 쓸 때 고를 수 있는 대상: 칸 -> BattleUnit
func _targets_for(u: BattleUnit, from_cell: Vector2i, action: Dictionary) -> Dictionary:
	var result := {}
	var kind := str(action["type"])
	if kind == "sskill":
		return _summoner_skill_targets(u, from_cell, GameData.summoner_skills[action["skill_id"]])
	if kind == "recall":
		for o in units:
			var ally: BattleUnit = o
			if ally.is_active() and ally.team == u.team and not ally.is_summoner:
				result[ally.cell] = ally
		return result

	var rmin := 1
	var rmax := BattleLogic.BASIC_ATTACK_RANGE
	match kind:
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			rmin = int(sk["range_min"])
			rmax = int(sk["range_max"])
			if rmax >= 2:
				rmax += GameData.terrain_range_bonus(grid.terrain_at(from_cell))
		"dispel":
			rmax = GameState.summoner.dispel_range()
	for o in units:
		var other: BattleUnit = o
		if not other.is_active() or other.team == u.team:
			continue
		if kind == "dispel" and other.is_summoner:
			continue  # 정령사는 디스펠할 수 없다
		var d := grid.distance(from_cell, other.cell)
		if d >= rmin and d <= rmax:
			result[other.cell] = other
	return result


## 정령사 스킬 대상. target: enemy / ally(정령사 자신 포함) / self
func _summoner_skill_targets(u: BattleUnit, from_cell: Vector2i, sk: Dictionary) -> Dictionary:
	var result := {}
	var side := str(sk.get("target", "enemy"))
	if side == "self":
		result[u.cell] = u
		return result
	var rmin := int(sk.get("range_min", 1))
	var rmax := int(sk.get("range_max", 1))
	for o in units:
		var other: BattleUnit = o
		if not other.is_active():
			continue
		if (side == "enemy") == (other.team == u.team):
			continue
		var d := grid.distance(from_cell, other.cell)
		if d >= rmin and d <= rmax:
			result[other.cell] = other
	return result


## 범위(area)가 있으면 대상 칸 주변의 같은 편 모두, 없으면 대상 하나
func _skill_area_units(u: BattleUnit, target: BattleUnit, sk: Dictionary) -> Array:
	var area := int(sk.get("area", 0))
	if area <= 0:
		return [target]
	var allies_side := str(sk.get("target", "enemy")) != "enemy"
	var result := []
	for o in units:
		var other: BattleUnit = o
		if not other.is_active() or ((other.team == u.team) != allies_side):
			continue
		if grid.distance(target.cell, other.cell) <= area:
			result.append(other)
	return result


func _pending_targets_allies() -> bool:
	match str(pending.get("type", "")):
		"recall":
			return true
		"sskill":
			return str(GameData.summoner_skills[pending["skill_id"]].get("target", "enemy")) != "enemy"
	return false


# ================================================================ 행동 처리 (공용)

func _perform(u: BattleUnit, action: Dictionary, target: BattleUnit) -> void:
	var s := u.spirit
	match str(action["type"]):
		"attack":
			var dmg := _damage(u, u.cell, target, _attack_power(u), s.element(), true)
			_hit(u, target, dmg, "공격", s.element())
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			s.mp = maxi(0, s.mp - int(sk["mp"]))
			var skill_dmg := _damage(u, u.cell, target, int(sk["power"]), str(sk["element"]), true)
			_hit(u, target, skill_dmg, str(sk["name"]), str(sk["element"]))
		"dispel":
			s.mp = maxi(0, s.mp - GameState.summoner.dispel_cost())
			_try_dispel(u, target)
		"recall":
			_recall(target)
		"sskill":
			_cast_summoner_skill(u, target, GameData.summoner_skills[action["skill_id"]])
	await get_tree().create_timer(ACTION_DELAY).timeout


func _cast_summoner_skill(u: BattleUnit, target: BattleUnit, sk: Dictionary) -> void:
	var s := u.spirit
	s.mp = maxi(0, s.mp - int(sk["mp"]))
	var skill_name := str(sk["name"])
	match str(sk["type"]):
		"attack":
			var dmg := _damage(u, u.cell, target, int(sk["power"]), str(sk["element"]), true)
			_hit(u, target, dmg, skill_name, str(sk["element"]))
		"heal":
			for o in _skill_area_units(u, target, sk):
				var t: BattleUnit = o
				var amount := mini(BattleLogic.heal_amount(s, t.spirit, sk), t.spirit.max_hp() - t.spirit.hp)
				t.spirit.hp += amount
				_effect("+%d" % amount, t.draw_pos, Color(0.5, 1.0, 0.6))
				_log("%s의 %s! %s의 HP %d 회복" % [s.display_name(), skill_name, t.spirit.display_name(), amount])
		"buff", "debuff":
			for o in _skill_area_units(u, target, sk):
				var t: BattleUnit = o
				var stat_key := str(sk["stat"])
				# 같은 스킬을 다시 걸면 덮어쓴다 (중첩 방지)
				t.buffs = t.buffs.filter(func(b): return b["name"] != skill_name)
				t.buffs.append({"name": skill_name, "stat": stat_key, "mult": float(sk.get("mult", 1.0)),
					"add": int(sk.get("add", 0)), "rounds": int(sk.get("rounds", 2))})
				var up := str(sk["type"]) == "buff"
				_effect("%s%s" % [Spirit.STAT_NAMES.get(stat_key, stat_key), "▲" if up else "▼"], t.draw_pos,
					Color(0.5, 1.0, 0.6) if up else COLOR_OWNED_RING)
				_log("%s의 %s! %s — %s" % [s.display_name(), skill_name, t.spirit.display_name(), str(sk.get("desc", ""))])


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
	var def_tid := grid.terrain_at(target.cell)
	if GameData.terrain_defense_mult(def_tid) < 1.0:
		msg += " [%s 엄폐]" % GameData.terrain_name(def_tid)
	_log(msg)
	_effect(str(dmg), target.draw_pos, color)
	if target.spirit.hp <= 0:
		_knock_out(target)


func _knock_out(target: BattleUnit) -> void:
	target.alive = false
	_log("%s이(가) 쓰러졌다!" % target.spirit.display_name())
	if target.team != 1:
		return
	if not target.is_summoner:
		defeated.append(target.spirit)
		return
	# 적 정령사가 쓰러지면 그 정령들은 계약이 풀려 흩어진다
	var fled := 0
	for o in units:
		var u: BattleUnit = o
		if u.owned and u.is_active():
			u.recalled = true
			_effect("도주", u.draw_pos, COLOR_OWNED_RING)
			fled += 1
	if fled > 0:
		_log("주인을 잃은 정령 %d마리가 흩어졌다." % fled)


func _try_dispel(u: BattleUnit, target: BattleUnit) -> void:
	var chance := BattleLogic.dispel_chance(u.spirit, target.spirit, target.owned)
	var pct := int(round(chance * 100.0))
	_log("%s이(가) 디스펠을 시도했다... (성공률 %d%%)" % [u.spirit.display_name(), pct])
	if rng.randf() < chance:
		target.captured = true
		captured.append(target.spirit)
		if target.owned:
			_log("디스펠 성공! %s을(를) 적 정령사에게서 빼앗아 계약했다!" % target.spirit.display_name())
		else:
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

func _run_enemy_turn(u: BattleUnit) -> void:
	await get_tree().create_timer(ENEMY_DELAY).timeout
	var plan := _plan_enemy(u)
	var dest: Vector2i = plan["cell"]
	if dest != u.cell:
		await _animate_move(u, dest)
	if plan.has("action"):
		await _perform(u, plan["action"], plan["target"])


## 적 정령사의 차례: 아군과 거리를 두고 자리를 잡은 뒤
## 소환 → (회복/공격) 스킬 → 옆의 적 공격 순으로 할 수 있는 것을 한다.
func _run_enemy_summoner_turn(u: BattleUnit) -> void:
	await get_tree().create_timer(ENEMY_DELAY).timeout
	var m: Summoner = u.spirit
	var want_summon := not _enemy_summon_choices(m).is_empty()

	var cells := _reachable_for(u)
	cells[u.cell] = 0
	var best_cell := u.cell
	var best_score := -INF
	for cell in cells:
		var d := float(_nearest_foe_distance(u, cell))
		var score := -absf(minf(d, 6.0) - ENEMY_SUMMONER_KEEP_DISTANCE) * 2.0
		if d <= 1.0:
			score -= 6.0
		score += _terrain_score(u, cell) * 0.5
		score -= int(cells[cell]) * 0.2
		if want_summon and _free_cells_around(cell).is_empty():
			score -= 10.0
		if score > best_score:
			best_score = score
			best_cell = cell
	if best_cell != u.cell:
		await _animate_move(u, best_cell)

	if want_summon:
		var place := _enemy_place_cell(u)
		if place.x >= 0:
			_summon(_pick_enemy_summon(m), place, true, 1)
			await get_tree().create_timer(ACTION_DELAY).timeout
			return

	var skill_plan := _enemy_summoner_skill_plan(u, m)
	if not skill_plan.is_empty():
		await _perform(u, skill_plan["action"], skill_plan["target"])
		return

	var t := _targets_for(u, u.cell, {"type": "attack"})
	if not t.is_empty():
		var target: BattleUnit = null
		for tcell in t:
			var cand: BattleUnit = t[tcell]
			if target == null or cand.spirit.hp < target.spirit.hp:
				target = cand
		await _perform(u, {"type": "attack"}, target)
	else:
		_log("적 정령사 %s은(는) 상황을 살피고 있다." % m.display_name())


## 적 정령사 스킬 선택: HP 50% 미만 아군이 있으면 회복, 아니면 기대 피해가 가장 큰 공격 스킬
func _enemy_summoner_skill_plan(u: BattleUnit, m: Summoner) -> Dictionary:
	var best := {}
	var best_score := 0.0
	for o in m.skill_ids:
		var sid := str(o)
		var sk: Dictionary = GameData.summoner_skills[sid]
		if m.mp < int(sk["mp"]):
			continue
		var action := {"type": "sskill", "skill_id": sid}
		var t := _summoner_skill_targets(u, u.cell, sk)
		for tcell in t:
			var target: BattleUnit = t[tcell]
			var score := 0.0
			match str(sk["type"]):
				"heal":
					for p in _skill_area_units(u, target, sk):
						var ally: BattleUnit = p
						var ratio := float(ally.spirit.hp) / float(maxi(1, ally.spirit.max_hp()))
						if ratio < 0.5:
							score += float(mini(BattleLogic.heal_amount(m, ally.spirit, sk), ally.spirit.max_hp() - ally.spirit.hp))
				"attack":
					var dmg := _damage(u, u.cell, target, int(sk["power"]), str(sk["element"]), false)
					score = float(mini(dmg, target.spirit.hp)) + (30.0 if dmg >= target.spirit.hp else 0.0)
			if score > best_score:
				best_score = score
				best = {"action": action, "target": target}
	return best


## 적 정령사가 지금 MP로 소환할 수 있는 정령들
func _enemy_summon_choices(m: Summoner) -> Array:
	if _summoned_count(1) >= m.summon_limit():
		return []
	var result := []
	for o in enemy_bench:
		var s: Spirit = o
		if s.hp > 0 and m.mp >= m.summon_cost(s):
			result.append(s)
	return result


## 아군 전장 정령들에게 속성이 유리한 정령을 고른다.
func _pick_enemy_summon(m: Summoner) -> Spirit:
	var best: Spirit = null
	var best_score := -INF
	for o in _enemy_summon_choices(m):
		var s: Spirit = o
		var score := float(s.level) * 0.2
		for p in units:
			var ally: BattleUnit = p
			if ally.team == 0 and ally.is_active():
				score += GameData.element_multiplier(s.element(), ally.spirit.element()) - 1.0
		if score > best_score:
			best_score = score
			best = s
	return best


## 적 정령사 옆 빈 칸 중 아군에 가장 가까운 칸. 없으면 (-1, -1).
func _enemy_place_cell(u: BattleUnit) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 9999
	for c in _free_cells_around(u.cell):
		var d := _nearest_foe_distance(u, c)
		if d < best_d:
			best_d = d
			best = c
	return best


## 이동 가능한 모든 칸 × 모든 행동 × 모든 대상 중 점수가 가장 높은 조합을 고른다.
## 정령사를 쓰러뜨리면 이기므로 정령사를 우선 노린다.
## 공격할 수 없으면 가장 가까운 아군 쪽으로 다가간다.
func _plan_enemy(u: BattleUnit) -> Dictionary:
	var cells := _reachable_for(u)
	cells[u.cell] = 0
	var actions := [{"type": "attack"}]
	for sid in u.spirit.known_skills():
		if u.spirit.mp >= int(GameData.skills[sid]["mp"]):
			actions.append({"type": "skill", "skill_id": sid})

	var best := {}
	var best_score := -1.0
	for cell in cells:
		for action in actions:
			var power := _attack_power(u)
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
				var expected := _damage(u, cell, target, power, element, false)
				var score := float(mini(expected, target.spirit.hp)) - mp_cost * 0.3
				if expected >= target.spirit.hp:
					score += 50.0
				if target.is_summoner:
					score += 12.0
				score += _terrain_score(u, cell)
				score -= int(cells[cell]) * 0.1  # 같은 값이면 덜 움직이는 쪽
				if score > best_score:
					best_score = score
					best = {"cell": cell, "action": action, "target": target}
	if not best.is_empty():
		return best

	var best_cell := u.cell
	var best_value := INF
	for cell in cells:
		# 가까울수록, 유리한 지형일수록 좋다
		var value := float(_nearest_foe_distance(u, cell)) - _terrain_score(u, cell) * 0.25
		if value < best_value:
			best_value = value
			best_cell = cell
	return {"cell": best_cell}


## AI가 칸을 고를 때 쓰는 지형 선호도 (엄폐 + 라운드 회복/화상)
func _terrain_score(u: BattleUnit, cell: Vector2i) -> float:
	var tid := grid.terrain_at(cell)
	var score := (1.0 - GameData.terrain_defense_mult(tid)) * 20.0
	score += GameData.terrain_round_hp(tid, u.spirit.element()) * 40.0
	return score


func _nearest_foe_distance(u: BattleUnit, cell: Vector2i) -> int:
	var best := 9999
	for o in units:
		var other: BattleUnit = o
		if other.is_active() and other.team != u.team:
			best = mini(best, grid.distance(cell, other.cell))
	return best


# ================================================================ 그리기

func _draw() -> void:
	_update_inspect_overlay()
	_update_active_overlay()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), COLOR_BG)
	for row in ROWS:
		for col in COLS:
			var c := Vector2i(col, row)
			var center := grid.to_pixel(c)
			var pts := grid.corners(center, HEX_SIZE - 1.5)
			draw_colored_polygon(pts, _cell_color(c))
			_draw_terrain_deco(grid.terrain_at(c), center)
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, COLOR_OUTLINE, 2.0)
			if c == inspected_cell:
				draw_polyline(outline, Color(0.6, 0.9, 1.0), 3.0)
			if range_cells.has(c):
				var inner := grid.corners(center, HEX_SIZE - 6.0)
				inner.append(inner[0])
				draw_polyline(inner, Color(1.0, 0.35, 0.35, 0.85), 2.5)

	_draw_preview_ghost()
	for o in units:
		var u: BattleUnit = o
		if u.is_active():
			_draw_unit(u)
	_draw_target_marks()

	if phase == "targeting":
		for tcell in targets:
			var t: BattleUnit = targets[tcell]
			_draw_text(_preview_text(t), t.draw_pos + Vector2(0, -44), 20, Color(1.0, 0.9, 0.4))

	for e in effects:
		var a := 1.0 - float(e["t"])
		var col: Color = e["color"]
		col.a = a
		_draw_text(str(e["text"]), e["pos"] + Vector2(0, -50.0 * float(e["t"]) - 10.0), 28, col)


## 지형 색 위에 이동 가능/대상/현재 차례 표시를 섞는다.
func _cell_color(c: Vector2i) -> Color:
	var base := GameData.terrain_color(grid.terrain_at(c))
	if grid.blocked.has(c):
		return base
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	var adv := _advantage_color(c)
	if phase == "targeting" and targets.has(c):
		if _pending_targets_allies():
			return base.lerp(COLOR_ALLY_TARGET, 0.5 + 0.2 * pulse)
		return base.lerp(adv if adv.a > 0.0 else COLOR_TARGET, 0.5 + 0.25 * pulse)
	if phase == "choose" and choose_target != null and choose_target.cell == c:
		var tint2 := COLOR_ALLY_TARGET if choose_target.team == 0 else COLOR_TARGET
		return base.lerp(tint2, 0.5 + 0.2 * pulse)
	if adv.a > 0.0 and phase in ["player", "choose", "targeting"]:
		return base.lerp(adv, 0.45)
	if phase == "placing" and place_cells.has(c):
		return base.lerp(COLOR_PLACE, 0.45 + 0.2 * pulse)
	if phase == "player" and not has_moved and reachable.has(c):
		return base.lerp(COLOR_MOVE, 0.85 if c == preview_cell else 0.45)
	if active != null and active.cell == c:
		return base.lerp(COLOR_ACTIVE_CELL, 0.35)
	if phase in ["select", "player"]:
		if inspect_move.has(c):
			return base.lerp(COLOR_INSPECT_MOVE, 0.4)
		if inspect_threat.has(c):
			return base.lerp(COLOR_INSPECT_THREAT, 0.3)
	return base


## 선택한 아군이 c에 있는 적을 칠 때의 상성 색: 초록 유리 / 노랑 보통 / 회색 불리. 해당 없음은 투명.
## 대상을 고르는 중이면 그 행동의 속성 기준.
func _advantage_color(c: Vector2i) -> Color:
	if active == null or active.team != 0:
		return Color(0, 0, 0, 0)
	var e := _unit_at(c)
	if e == null or e.team == 0:
		return Color(0, 0, 0, 0)
	var el := active.spirit.element()
	if phase == "targeting":
		var ael := _action_element(active, pending)
		if ael == "":
			return Color(0, 0, 0, 0)
		el = ael
	var mult := GameData.element_multiplier(el, e.spirit.element())
	if mult > 1.0:
		return COLOR_ADV_GOOD
	if mult < 1.0:
		return COLOR_ADV_BAD
	return COLOR_ADV_EVEN


## 지형을 알아볼 수 있게 간단한 도형을 그린다. (아트 작업 전 임시)
func _draw_terrain_deco(tid: String, center: Vector2) -> void:
	match tid:
		"forest":
			for off in [Vector2(-18, -14), Vector2(16, -16), Vector2(-2, 20)]:
				var p: Vector2 = center + off
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -10), p + Vector2(8, 6), p + Vector2(-8, 6)]),
					Color(0.2, 0.5, 0.25))
		"water":
			for dy in [-18.0, 22.0]:
				var pts := PackedVector2Array()
				for i in 9:
					var x := -20.0 + 5.0 * i
					pts.append(center + Vector2(x, dy + sin(i * 1.6 + time * 2.0) * 3.0))
				draw_polyline(pts, Color(0.45, 0.7, 1.0, 0.8), 2.0)
		"hill":
			draw_arc(center + Vector2(0, 20), 24.0, PI * 1.1, PI * 1.9, 12, Color(0.6, 0.52, 0.32), 3.0)
			draw_arc(center + Vector2(-14, -12), 12.0, PI * 1.1, PI * 1.9, 8, Color(0.6, 0.52, 0.32), 2.0)
		"lava":
			var glow := 0.6 + 0.4 * sin(time * 3.0)
			for off in [Vector2(-18, -12), Vector2(17, -8), Vector2(-6, 22), Vector2(14, 18)]:
				draw_circle(center + off, 4.0, Color(1.0, 0.5, 0.15, glow))
		"circle":
			var glow2 := 0.55 + 0.45 * sin(time * 2.5)
			var ring_col := Color(0.75, 0.6, 1.0, glow2)
			draw_arc(center, HEX_SIZE * 0.62, 0.0, TAU, 32, ring_col, 2.5)
			draw_arc(center, HEX_SIZE * 0.42, 0.0, TAU, 32, ring_col, 1.5)
			var star := PackedVector2Array()
			for k in 6:
				var ang := deg_to_rad(-90.0 + 144.0 * k)
				star.append(center + Vector2(cos(ang), sin(ang)) * HEX_SIZE * 0.58)
			draw_polyline(star, ring_col, 1.5)
		"rock":
			draw_circle(center, HEX_SIZE * 0.45, Color(0.3, 0.28, 0.25))
			draw_circle(center + Vector2(-6, -6), HEX_SIZE * 0.18, Color(0.4, 0.37, 0.33))


func _draw_unit(u: BattleUnit) -> void:
	var p := u.draw_pos
	var el_color := GameData.element_color(u.spirit.element())
	if u == active:
		var pulse := 0.5 + 0.5 * sin(time * 6.0)
		draw_arc(p, 38.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.4 + 0.6 * pulse), 4.0)
	if u == inspected:
		draw_arc(p, 38.0, 0.0, TAU, 40, Color(0.6, 0.9, 1.0), 3.0)
	if u.is_summoner:
		# 정령사는 마름모 + 금색 테두리
		var body := PackedVector2Array([p + Vector2(0, -33), p + Vector2(30, 0), p + Vector2(0, 33), p + Vector2(-30, 0)])
		draw_colored_polygon(body, el_color.darkened(0.5))
		var edge := body.duplicate()
		edge.append(body[0])
		draw_polyline(edge, Color(1.0, 0.85, 0.4) if u.team == 0 else Color(0.95, 0.3, 0.35), 3.0)
	else:
		var ring := Color(0.95, 0.95, 1.0) if u.team == 0 else (COLOR_OWNED_RING if u.owned else Color(0.9, 0.2, 0.25))
		draw_circle(p, 30.0, el_color.darkened(0.2))
		draw_arc(p, 30.0, 0.0, TAU, 40, ring, 3.0)
		if u.joined_round >= round_num and (u.team == 0 or u.owned):
			# 이번 라운드에 소환되어 아직 행동하지 못하는 정령
			draw_arc(p, 34.0, 0.0, TAU, 40, Color(0.55, 0.85, 1.0, 0.5), 2.0)
	if u.team == 0 and phase in ["select", "player", "choose", "targeting", "placing", "busy"]:
		if u.done or u.joined_round >= round_num:
			draw_circle(p, 31.0, Color(0, 0, 0, 0.45))  # 이번 턴 행동 끝
		elif u != active:
			draw_circle(p + Vector2(24, -24), 6.0, Color(0.45, 1.0, 0.55))  # 행동 가능
	_draw_buff_marks(u, p)
	_draw_text(u.spirit.display_name(), p + Vector2(0, 2), 16, Color.WHITE)
	_draw_text("Lv%d" % u.spirit.level, p + Vector2(0, 20), 14, Color(1, 1, 1, 0.85))
	var ratio := float(u.spirit.hp) / float(maxi(1, u.spirit.max_hp()))
	var bar := Rect2(p + Vector2(-28, 35), Vector2(56, 6))
	draw_rect(bar, Color(0, 0, 0, 0.75))
	var hp_color := Color(0.4, 0.9, 0.45) if ratio > 0.5 else (Color(0.95, 0.8, 0.3) if ratio > 0.25 else Color(0.95, 0.35, 0.3))
	draw_rect(Rect2(bar.position, Vector2(56.0 * ratio, 6)), hp_color)


## 이동 미리보기: 선택한 유닛이 그 칸에 섰을 때의 모습
func _draw_preview_ghost() -> void:
	if active == null or phase != "player" or not grid.in_bounds(preview_cell):
		return
	var p := grid.to_pixel(preview_cell)
	var col := GameData.element_color(active.spirit.element())
	col.a = 0.45
	draw_circle(p, 28.0, col)
	draw_arc(p, 28.0, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 2.0)
	_draw_text("여기로?", p + Vector2(0, 6), 15, Color(1, 1, 1, 0.9))
	draw_line(active.draw_pos, p, Color(1, 1, 1, 0.35), 2.0)


## 선택한 유닛 기준: 공격 가능한 적(빨간 조준 ⚔), 이동하면 가능한 적(주황 링), 속성 유불리
func _draw_target_marks() -> void:
	if active == null or active.team != 0 or not phase in ["player", "choose"]:
		return
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	for o in units:
		var e: BattleUnit = o
		if e.team == 0 or not e.is_active():
			continue
		var p := e.draw_pos
		if hit_now.has(e.cell):
			var red := Color(1.0, 0.25, 0.25, 0.6 + 0.4 * pulse)
			draw_arc(p, 40.0, 0.0, TAU, 40, red, 3.0)
			for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(p + dir * 34.0, p + dir * 46.0, red, 3.0)
			_draw_text("⚔", p + Vector2(0, -44), 20, Color(1.0, 0.4, 0.4))
		elif reach_targets.has(e.cell):
			draw_arc(p, 39.0, 0.0, TAU, 40, Color(1.0, 0.65, 0.2, 0.75), 2.0)
		var mult := GameData.element_multiplier(active.spirit.element(), e.spirit.element())
		if mult > 1.0:
			_draw_text("유리", p + Vector2(30, -26), 14, Color(0.5, 1.0, 0.55))
		elif mult < 1.0:
			_draw_text("불리", p + Vector2(30, -26), 14, Color(0.75, 0.7, 0.75))


func _draw_buff_marks(u: BattleUnit, p: Vector2) -> void:
	var up := false
	var down := false
	for b in u.buffs:
		if float(b.get("mult", 1.0)) > 1.0 or int(b.get("add", 0)) > 0:
			up = true
		else:
			down = true
	if up:
		_draw_text("▲", p + Vector2(-26, -20), 16, Color(0.5, 1.0, 0.6))
	if down:
		_draw_text("▼", p + Vector2(-26, -2), 16, COLOR_OWNED_RING)


## pos.y는 글자 아랫선(baseline) 기준, x는 가운데 정렬
func _draw_text(text: String, pos: Vector2, size: int, color: Color) -> void:
	var width := 160.0
	var at := Vector2(pos.x - width * 0.5, pos.y)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, 4, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, color)


func _preview_text(t: BattleUnit) -> String:
	return _preview_for(active, pending, t)


## u가 action으로 t를 노릴 때 보여줄 예상 결과 (피해 / 회복 / 성공률)
func _preview_for(u: BattleUnit, action: Dictionary, t: BattleUnit) -> String:
	match str(action.get("type", "")):
		"dispel":
			return "%d%%" % int(round(BattleLogic.dispel_chance(u.spirit, t.spirit, t.owned) * 100.0))
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			return "-%d" % _damage(u, u.cell, t, int(sk["power"]), str(sk["element"]), false)
		"attack":
			return "-%d" % _damage(u, u.cell, t, _attack_power(u), u.spirit.element(), false)
		"recall":
			return "귀환"
		"sskill":
			var ssk: Dictionary = GameData.summoner_skills[action["skill_id"]]
			match str(ssk["type"]):
				"attack":
					return "-%d" % _damage(u, u.cell, t, int(ssk["power"]), str(ssk["element"]), false)
				"heal":
					return "+%d" % mini(BattleLogic.heal_amount(u.spirit, t.spirit, ssk), t.spirit.max_hp() - t.spirit.hp)
				"buff":
					return "▲"
				"debuff":
					return "▼"
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
	turn_label.offset_top = 20
	turn_label.offset_bottom = 64
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 28)
	ui_root.add_child(turn_label)

	legend_label = RichTextLabel.new()
	legend_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	legend_label.offset_top = 66
	legend_label.offset_bottom = 128
	legend_label.bbcode_enabled = true
	legend_label.scroll_active = false
	legend_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend_label.add_theme_font_size_override("normal_font_size", 19)
	legend_label.text = "[center]상성  %s   [color=#9aa3b5](▶ 방향으로 공격하면 ×1.5)[/color]\n[font_size=16][color=#9aa3b5]적 칸 색: [color=#4de566]유리[/color]/[color=#f2cc4d]보통[/color]/[color=#80808f]불리[/color] · 숲 엄폐 · 물가 물↑불↓ · 언덕 바람↑ · 용암 불↑화상 · 마법진 회복[/color][/font_size][/center]" % GameData.element_chart_bbcode()
	ui_root.add_child(legend_label)

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
	action_box.columns = 4
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

	if phase == "over":
		turn_label.text = "전투 종료"
	elif phase == "enemy":
		var who := "" if active == null else " — %s %s" % [_unit_tag(active), active.spirit.display_name()]
		turn_label.text = "라운드 %d · 적 턴%s" % [round_num, who]
	else:
		turn_label.text = "라운드 %d · 아군 턴 (남은 행동 %d)" % [round_num, _ready_allies().size()]

	if inspected != null:
		info_label.text = _unit_info(inspected)
	elif grid.in_bounds(inspected_cell):
		info_label.text = _terrain_info(inspected_cell)
	else:
		info_label.text = _unit_info(active)

	match phase:
		"select":
			_add_action("턴 종료", _on_end_phase)
			_add_action("후퇴", _on_retreat)
			hint_label.text = "행동할 아군을 고르세요. (초록 점 = 행동 가능, 순서 자유)\n적을 누르면 주황 = 이동 범위, 빨강 = 공격 범위"
		"player":
			if active.is_summoner:
				_build_summoner_actions()
			else:
				_build_spirit_actions()
		"choose":
			for o in _target_options(active, choose_target):
				var opt: Dictionary = o
				var act: Dictionary = opt["action"]
				_add_action(str(opt["label"]), func(): _choose_option(act), not bool(opt["ok"]))
			_add_action("취소", _cancel_choose)
			hint_label.text = "%s에게 할 행동을 고르세요. (흐린 버튼 = MP 부족 / 사거리 밖)" % choose_target.spirit.display_name()
		"targeting":
			_add_action("취소", _cancel_targeting)
			match str(pending.get("type", "")):
				"dispel":
					hint_label.text = "계약할 정령을 누르세요. (숫자 = 성공 확률, 적 정령사의 정령은 더 어려움)"
				"recall":
					hint_label.text = "귀환시킬 정령을 누르세요."
				"sskill":
					var ssk: Dictionary = GameData.summoner_skills[pending["skill_id"]]
					hint_label.text = "%s: 대상을 누르세요. — %s" % [ssk["name"], ssk.get("desc", "")]
				_:
					hint_label.text = "공격할 대상을 누르세요. (숫자 = 예상 피해)"
		"placing":
			_add_action("취소", _cancel_targeting)
			hint_label.text = "%s을(를) 소환할 칸을 누르세요." % (pending["spirit"] as Spirit).display_name()
		"enemy":
			hint_label.text = "적이 움직이고 있다..."
		_:
			hint_label.text = ""

	log_label.text = "\n".join(PackedStringArray(log_lines))


func _move_hint() -> String:
	if has_moved:
		return "⚔ 빨간 조준 = 지금 공격 가능. 적을 눌러 행동 선택. (잘못 움직였다면 '이동 취소')"
	if grid.in_bounds(preview_cell):
		return "미리보기: 빨간 테두리 = 그 자리에서의 사거리, ⚔ = 공격 가능. 같은 칸을 다시 누르거나 적을 누르면 이동."
	return "파란 칸을 눌러 미리보기. ⚔ = 지금 공격 가능, 주황 링 = 이동하면 공격 가능."


func _add_common_actions() -> void:
	if grid.in_bounds(preview_cell) and not has_moved:
		_add_action("여기로 이동", _confirm_preview_move)
	if has_moved:
		_add_action("이동 취소", _undo_move)
	else:
		_add_action("선택 해제", _deselect)
	_add_action("대기", _on_wait)


func _build_summoner_actions() -> void:
	var m := GameState.summoner
	if summoning:
		submenu = "summon"
	if submenu == "summon":
		var full := _summoned_count() >= m.summon_limit()
		var no_room := _free_cells_around(active.cell).is_empty()
		for o in _summonable():
			var s: Spirit = o
			var cost := m.summon_cost(s)
			var reason := "한도 초과" if full else ("MP 부족" if m.mp < cost else ("빈 칸 없음" if no_room else ""))
			var title := "%s Lv%d" % [s.display_name(), s.level]
			_add_action(_labeled(title, cost, reason) if reason != "" else "%s\nMP %d" % [title, cost],
				func(): _choose_summon(s), reason != "")
		if summoning:
			_add_action("소환 완료", _on_summon_done)
			hint_label.text = "계속 소환하거나 '소환 완료'를 누르세요. (%d/%d 소환 중, MP %d)" % [_summoned_count(), m.summon_limit(), m.mp]
		else:
			_add_action("뒤로", _close_submenu)
			hint_label.text = "소환할 정령을 고르세요. 한 번에 여러 마리 소환할 수 있습니다. (%d/%d)" % [_summoned_count(), m.summon_limit()]
		return
	if submenu == "sskills":
		for o in m.skill_ids:
			var sid := str(o)
			var sk: Dictionary = GameData.summoner_skills[sid]
			var reason := _block_reason(active, {"type": "sskill", "skill_id": sid}, int(sk["mp"]))
			_add_action(_labeled(str(sk["name"]), int(sk["mp"]), reason), func(): _choose_summoner_skill(sid), reason != "")
		_add_action("뒤로", _close_submenu)
		hint_label.text = "정령사 스킬을 고르세요. (흐린 버튼 = MP 부족 / 대상 없음)"
		return
	_add_action("소환", _open_submenu.bind("summon"), not _can_summon_more())
	_add_action("귀환", _on_recall, _summoned_count() == 0)
	var dispel_reason := _block_reason(active, {"type": "dispel"}, m.dispel_cost())
	_add_action(_labeled("디스펠", m.dispel_cost(), dispel_reason), _on_dispel, dispel_reason != "")
	_add_action("스킬", _open_submenu.bind("sskills"), m.skill_ids.is_empty())
	var atk_reason := _block_reason(active, {"type": "attack"}, 0)
	_add_action(_labeled("공격", 0, atk_reason), _on_attack, atk_reason != "")
	_add_common_actions()
	hint_label.text = _move_hint()


func _build_spirit_actions() -> void:
	if submenu == "skills":
		for sid in active.spirit.known_skills():
			var sk: Dictionary = GameData.skills[sid]
			var reason := _block_reason(active, {"type": "skill", "skill_id": sid}, int(sk["mp"]))
			_add_action(_labeled(str(sk["name"]), int(sk["mp"]), reason), func(): _choose_skill(sid), reason != "")
		_add_action("뒤로", _close_submenu)
		hint_label.text = "사용할 스킬을 고르세요. (흐린 버튼 = MP 부족 / 사거리 안에 대상 없음)"
		return
	var atk_reason := _block_reason(active, {"type": "attack"}, 0)
	_add_action(_labeled("공격", 0, atk_reason), _on_attack, atk_reason != "")
	_add_action("스킬", _open_submenu.bind("skills"), active.spirit.known_skills().is_empty())
	_add_action("귀환", _on_recall)
	_add_common_actions()
	hint_label.text = _move_hint()


func _add_action(text: String, cb: Callable, disabled: bool = false) -> void:
	var b := UIKit.button(text, cb, disabled, 72)
	b.add_theme_font_size_override("font_size", 21)
	# 쓸 수 없는 행동은 글씨를 흐리게
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 0.5))
	action_box.add_child(b)


func _unit_info(u: BattleUnit) -> String:
	if u == null:
		return ""
	var s := u.spirit
	var tag := _unit_tag(u)
	var extra := ""
	if u.is_summoner:
		extra = "   소환 %d/%d" % [_summoned_count(u.team), (s as Summoner).summon_limit()]
	extra += "  사거리%d" % _max_attack_range(u)
	for b in u.buffs:
		extra += "  [%s %d]" % [b["name"], int(b["rounds"])]
	return "[%s] %s  Lv.%d  %s 속성\nHP %d/%d  MP %d/%d  공%d 방%d 속%d 이동%d%s\n%s" % [
		tag, s.display_name(), s.level, GameData.element_name(s.element()),
		s.hp, s.max_hp(), s.mp, s.max_mp(),
		s.stat("atk"), s.stat("def"), s.stat("spd"), s.stat("mov"), extra,
		_terrain_line(u.cell)]


func _unit_tag(u: BattleUnit) -> String:
	if u.team == 0:
		return "정령사" if u.is_summoner else "아군"
	if u.is_summoner:
		return "적 정령사"
	return "적 정령" if u.owned else "야생"


func _terrain_line(c: Vector2i) -> String:
	var tid := grid.terrain_at(c)
	var info := GameData.terrain_info(tid)
	return "지형: %s — %s" % [GameData.terrain_name(tid), str(info.get("desc", ""))]


func _terrain_info(c: Vector2i) -> String:
	var tid := grid.terrain_at(c)
	var text := "[지형] %s\n%s" % [GameData.terrain_name(tid), str(GameData.terrain_info(tid).get("desc", ""))]
	if active != null and GameData.terrain_passable(tid):
		text += "\n%s의 진입 비용: %d" % [active.spirit.display_name(),
			GameData.terrain_move_cost(tid, active.spirit.element())]
	return text


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
