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
const CMD_MIN_WIDTH := 132.0   # 명령 메뉴 버튼 최소 너비
const ROWS := 12
const HEX_SIZE := 46.0
const MAP_TOP := 84.0          # 위쪽 HUD(라운드·배속) 높이
const ENEMY_DELAY := 0.25
const ACTION_DELAY := 0.3
const ENEMY_SPAWN_COLS := [3, 4, 2, 5]
const SUMMONER_CELL := Vector2i(3, 11)   # 맨 아래 행
const VANGUARD_CELL := Vector2i(3, 10)   # 정령사 바로 위
const ENEMY_SUMMONER_CELL := Vector2i(4, 1)  # 위에서 둘째 행 (뒤로 물러설 칸을 남김)
const ENEMY_VANGUARD_CELL := Vector2i(4, 2)  # 적 정령사 바로 아래
const WILD_SPAWN_ROW := 2
## 적 정령사가 아군과 유지하려는 거리
const ENEMY_SUMMONER_KEEP_DISTANCE := 3.0
## 소환되지 않은 계약 정령이 받는 경험치 비율
## [지형 id, 덩어리 개수, 덩어리 크기] — 출발 행(0~2, 9~11)을 피해 3~8행에 배치
const TERRAIN_PLAN := [["circle", 2, 1], ["forest", 3, 4], ["water", 2, 3], ["hill", 2, 3], ["lava", 1, 3], ["rock", 5, 1]]
const TERRAIN_ROW_MIN := 3
const TERRAIN_ROW_MAX := 8

const COLOR_BG := Color(0.07, 0.08, 0.11)
const COLOR_MOVE := Color(0.25, 0.5, 0.9)
const COLOR_TARGET := Color(0.85, 0.2, 0.22)
const COLOR_ALLY_TARGET := Color(0.3, 0.85, 0.75)
const COLOR_PLACE := Color(0.55, 0.85, 1.0)
const COLOR_ACTIVE_CELL := Color(0.9, 0.8, 0.3)
const COLOR_OUTLINE := Color(0.06, 0.06, 0.1, 0.32)
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
var stage: Dictionary = {}                  # 스토리 스테이지 전투일 때 {"id", "name", "guardian"}
var guardian_unit: BattleUnit = null        # 수호 정령 보스
const GUARDIAN_CELL := Vector2i(4, 1)
const GUARDIAN_REVEAL_RATIO := 0.3
const GUARDIAN_DISPEL_BONUS := 0.3
var active: BattleUnit = null
var inspected: BattleUnit = null
var inspected_cell := Vector2i(-1, -1)  # 유닛 없는 칸을 눌렀을 때 지형 정보 표시용
## select(아군 고르는 중) / player(선택한 유닛 조작) / targeting / placing / busy / enemy / over
var phase := "idle"
var has_moved := false
var move_origin := Vector2i(-1, -1)  # 이동 취소용
var submenu := ""               # "", "attacks"(공격 탭), "sskills"(정령사 스킬), "summon"
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
var xp_gained: Dictionary = {}  # Spirit -> 이번 전투에서 얻은 경험치 (행동할 때마다 바로 받음)
var xp_msgs: Array[String] = [] # 전투 중 레벨업·스킬 습득 메시지 (결과 화면에 다시 보여 줌)
var fx: Array = []              # 공격·소환·퇴장 시각 효과 {"kind", "pos", "color", "t", "dur", ...}
var battle_speed := 1
var rng := RandomNumberGenerator.new()
var font: Font
var time := 0.0

var map_bottom := 0.0          # 맵 아래 끝 (그 아래는 명령 패널)
var bg_tex: Texture2D = null    # 지역 배경 (도트)
var tile_tex: Dictionary = {}   # 지형 id -> 헥스 타일 텍스처
## 마법진 색: 칸 -> {"from": Color, "to": Color, "t": 경과 초}. 우리 편 파랑 / 적 정령사 쪽 빨강 / 야생 정령은 원래 보라
var circle_state: Dictionary = {}
const CIRCLE_BASE := Color(0.78, 0.62, 1.0)
const CIRCLE_ALLY := Color(0.35, 0.7, 1.0)
const CIRCLE_ENEMY := Color(1.0, 0.32, 0.3)
const CIRCLE_SHIFT_TIME := 0.6
var ui_root: Control
var speed_button: Button
var unit_icon: TextureRect
var tut_bubble: PanelContainer
var tut_icon: TextureRect
var tut_label: Label
var tut_queue: Array = []       # 보여 줄 튜토리얼 단계
var tut_focus: Array = []       # 튜토리얼이 가리키는 칸 (Vector2i)
var tut_tap_label: Label
## 고정 튜토리얼 스테이지(1-1) 진행: chapter1.json stages[].script
var script_steps: Array = []
var script_i := -1
var vanguard_unit: BattleUnit = null
var stage_enemy_units: Array = []   # 스테이지 enemies 순서대로 (스크립트의 target 번호)
var turn_label: Label
var info_label: Label
var hint_label: Label
var cmd_panel: PanelContainer   # 유닛 옆에 뜨는 명령 메뉴 (원작처럼)
var cmd_box: VBoxContainer
var detail_label: Label         # 아래 패널: 행동 설명
var unit_card: HBoxContainer
var summon_box: VBoxContainer   # 아래 패널: 소환 목록 (속성 탭 + 카드)
var summon_tabs: HBoxContainer
var summon_grid: GridContainer
var summon_filter := "all"
var end_button: Button
var retreat_button: Button
var log_label: Label
var log_lines: Array = []
var full_log: Array[String] = []
var _ui_dirty := true


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 도트가 흐려지지 않게
	battle_speed = clampi(int(GameState.flags.get("battle_speed", 1)), 1, 3)
	Engine.time_scale = float(battle_speed)
	rng.randomize()
	font = GameData.ui_font
	var vp_w := get_viewport_rect().size.x
	var hex_w := HexGrid.SQRT3 * HEX_SIZE
	var total_w := hex_w * COLS + hex_w * 0.5
	var origin := Vector2((vp_w - total_w) * 0.5 + hex_w * 0.5, MAP_TOP + HEX_SIZE)
	grid = HexGrid.new(COLS, ROWS, HEX_SIZE, origin)
	map_bottom = origin.y + 1.5 * HEX_SIZE * float(ROWS - 1) + HEX_SIZE
	_build_ui()
	_setup_units()
	_load_battle_art()
	script_steps = stage.get("script", [])
	_start_round()
	if not script_steps.is_empty():
		script_i = 0
		_show_script_step()
	_tutorial("start")


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # 배속은 전투에서만


func _toggle_speed() -> void:
	battle_speed = battle_speed % 3 + 1   # 1 → 2 → 3 → 1
	Engine.time_scale = float(battle_speed)
	GameState.flags["battle_speed"] = battle_speed
	_update_speed_button()


func _process(delta: float) -> void:
	time += delta
	for e in effects:
		e["t"] += delta
	effects = effects.filter(func(e): return e["t"] < 1.0)
	for f in fx:
		f["t"] += delta
	fx = fx.filter(func(f): return f["t"] < f["dur"])
	_update_circles(delta)
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
	stage = GameState.current_stage
	GameState.current_stage = {}
	if stage.is_empty() and GameState.current_encounter.is_empty() and GameState.current_rival.is_empty():
		GameState.current_encounter = GameState.make_encounter()

	if not stage.is_empty():
		rng.seed = hash("stage_" + str(stage["id"]))  # 스테이지마다 같은 맵
	var fixed: Dictionary = stage.get("terrain", {})
	if fixed.is_empty():
		_generate_terrain()
	else:
		for tid in fixed:
			for p in fixed[tid]:
				_set_terrain(Vector2i(int(p[0]), int(p[1])), str(tid))
	rng.randomize()
	summoner_unit = _add_unit(GameState.summoner, 0, SUMMONER_CELL)
	summoner_unit.is_summoner = true
	var bench := _summonable()
	if not bench.is_empty():
		vanguard_unit = _summon(bench[0], VANGUARD_CELL, false, 0)

	if not GameState.current_rival.is_empty():
		_setup_rival(GameState.current_rival)
	else:
		var cells: Array = stage.get("enemy_cells", [])
		for i in GameState.current_encounter.size():
			var cell := Vector2i(ENEMY_SPAWN_COLS[i % ENEMY_SPAWN_COLS.size()], WILD_SPAWN_ROW)
			if i < cells.size() and grid.in_bounds(cells[i]):
				cell = cells[i]
			stage_enemy_units.append(_add_unit(GameState.current_encounter[i], 1, cell))
		if not GameState.current_encounter.is_empty():
			_log("야생 정령 %d마리가 나타났다!" % GameState.current_encounter.size())
	if not stage.is_empty() and stage.get("guardian") != null:
		guardian_unit = _add_unit(stage["guardian"], 1, GUARDIAN_CELL)
		guardian_unit.is_guardian = true
		_log("수호 정령 %s이(가) 폭주하고 있다! HP를 %d%% 이하로 줄여 실을 드러내자." % [
			guardian_unit.spirit.display_name(), int(GUARDIAN_REVEAL_RATIO * 100)])
	if not stage.is_empty():
		_log("[%s] %s" % [stage["id"], stage["name"]])
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
## 계약한 정령 전체: 파티 + 보관함 + 이번 전투에서 막 계약한 정령
func _all_contracted() -> Array:
	return GameState.party + GameState.storage + captured


## 소환할 수 있는 정령 (쓰러지지 않았고 전장에 없는 계약 정령 전부, 보관함 포함)
func _summonable() -> Array:
	var result := []
	for o in _all_contracted():
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
	# 등장 연출: 마법진 + 빛기둥 → 통! 하고 나타남
	u.pop = 0.0
	u.fade = 0.0
	_add_fx("summon", u.draw_pos, GameData.element_color(s.element()).lightened(0.25), 0.8)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(u, "pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(u, "fade", 1.0, 0.2)
	return u


func _recall(u: BattleUnit) -> void:
	u.recalled = true
	_vanish(u, "capture", COLOR_ALLY_TARGET)
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
	if round_num == 2:
		_tutorial("round2")
	_script_event("round%d" % round_num)


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
	_tutorial("select_summoner" if u.is_summoner else "select")
	_script_event("select")


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
	_tutorial("enemy_phase")
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
	tut_queue.clear()
	tut_focus = []
	tut_bubble.visible = false
	var lines: Array[String] = []
	if victory:
		var beat_rival := enemy_summoner_unit != null and not enemy_summoner_unit.is_active()
		if beat_rival:
			lines.append("적 정령사 %s을(를) 쓰러뜨렸다!" % enemy_summoner_unit.spirit.display_name())
		var lv_total := 0
		for o in defeated + captured:
			lv_total += (o as Spirit).level
		if beat_rival:
			lv_total += enemy_summoner_unit.spirit.level * 2
		var won_gold := GameState.battle_gold(lv_total)
		GameState.gold += won_gold
		lines.append("@gold:%d:보유 %d" % [won_gold, GameState.gold])
		if beat_rival or rng.randf() < 0.4:
			var eid := GameData.random_equipment(rng)
			GameState.inventory.append(eid)
			lines.append("장비 획득: %s" % GameData.equipment_desc(eid))
		GameState.battles_won += 1
		if not stage.is_empty():
			lines.append_array(GameState.complete_stage(str(stage["id"])))
	else:
		lines.append("%s이(가) 쓰러졌다..." % GameState.summoner.display_name())
		lines.append("정령들과 함께 돌아가 회복합니다." + (" 월드맵에서 다시 도전할 수 있어요." if not stage.is_empty() else ""))
	lines.append_array(_xp_summary())
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
	if mb.position.y > map_bottom + 4.0 or mb.position.y < MAP_TOP:
		return
	_on_tap(mb.position)


func _on_tap(pos: Vector2) -> void:
	var c := grid.from_pixel(pos)
	if not grid.in_bounds(c):
		return
	var u := _unit_at(c)
	if _script_active():
		_script_tap(c, u)
		return
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


## 전장에 서 있는 유닛과 위치의 요약값. 쓰러짐·계약·귀환한 유닛은 units에 남아 있으므로
## units.size() 대신 이것으로 범위 표시를 다시 계산할지 판단한다.
func _board_sig() -> int:
	var parts := []
	for o in units:
		var u: BattleUnit = o
		if u.is_active():
			parts.append([u.get_instance_id(), u.cell])
	return hash(parts)


## 누른 유닛이 다음 차례에 갈 수 있는 칸과, 거기서 공격이 닿는 칸을 계산해 둔다.
func _update_inspect_overlay() -> void:
	var key := ""
	if inspected != null and inspected.is_active():
		key = "%d:%s:%d:%d" % [inspected.get_instance_id(), str(inspected.cell), round_num, _board_sig()]
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
		key = "%d:%s:%s:%s:%d" % [active.get_instance_id(), str(active.cell), str(has_moved), str(preview_cell), _board_sig()]
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
	_tutorial("moved")
	_script_event("moved")


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


## 정령은 정령사 바로 옆 칸이나 마법진 위에 있을 때만 귀환할 수 있다 (이동 후 위치 기준)
func _can_recall(u: BattleUnit) -> bool:
	if u == null or u.is_summoner or not u.is_active():
		return false
	if grid.terrain_at(u.cell) == "circle":
		return true
	var m := _summoner_of(u.team)
	return m != null and m.is_active() and grid.distance(u.cell, m.cell) <= 1


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
	_script_event("summoned")
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


func _can_retreat() -> bool:
	return phase == "select" or (phase == "player" and not has_moved)


## 후퇴 확인 창 (턴 종료 옆이라 잘못 누르지 않게)
func _confirm_retreat() -> void:
	if not _can_retreat():
		return
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	var box := PanelContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_stylebox_override("panel", _pill_style(Color(0.08, 0.09, 0.14, 0.98), UIKit.GOLD.darkened(0.2), 16))
	overlay.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	box.add_child(vb)
	vb.add_child(UIKit.label("후퇴할까요?", 32, UIKit.GOLD, true))
	vb.add_child(UIKit.label("이번 전투에서 계약한 정령은 데려갑니다.\n경험치와 보상은 받지 못합니다.", 22, Color.WHITE, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	row.add_child(UIKit.button("후퇴", _on_retreat))
	row.add_child(UIKit.button("계속 싸우기", overlay.queue_free))


## 후퇴해도 디스펠로 계약한 정령은 데려간다. (경험치·장비 보상은 없음)
func _on_retreat() -> void:
	if not _can_retreat():
		return
	phase = "over"
	var lines := _keep_captured()
	GameState.heal_all()
	GameState.save_game()
	if lines.is_empty():
		GameState.hub_message = "전투에서 후퇴했습니다."
	else:
		GameState.hub_message = "후퇴했습니다. " + " / ".join(PackedStringArray(lines))
	get_tree().change_scene_to_file(_exit_scene())


# ---------------------------------------------------------------- 대상을 눌러 행동 고르기

func _open_target_menu(t: BattleUnit) -> void:
	choose_target = t
	inspected = t
	inspected_cell = Vector2i(-1, -1)
	targets = {t.cell: t}
	submenu = ""
	phase = "choose"
	_mark_ui()
	_tutorial("choose")


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
		# 공격 탭 먼저 (기본 공격 · 스킬 / 정령사: 기본 공격 · 공격 스킬 · 디스펠)
		for o in _attack_tab(u):
			var action: Dictionary = o
			if str(action["type"]) == "dispel" and t.is_summoner:
				continue
			opts.append(_make_option(u, t, action, _action_name(u, action), _action_mp(u, action)))
		if u.is_summoner:
			var m: Summoner = u.spirit
			for o in m.support_skill_ids():
				var sk: Dictionary = GameData.summoner_skills[str(o)]
				if str(sk.get("target", "")) == "enemy":
					opts.append(_make_option(u, t, {"type": "sskill", "skill_id": str(o)}, str(sk["name"]), int(sk["mp"])))
	elif u.is_summoner:
		var m: Summoner = u.spirit
		for o in m.skill_ids:
			var sk: Dictionary = GameData.summoner_skills[str(o)]
			if str(sk.get("target", "")) == "ally":
				opts.append(_make_option(u, t, {"type": "sskill", "skill_id": str(o)}, str(sk["name"]), int(sk["mp"])))
	return opts


func _make_option(u: BattleUnit, t: BattleUnit, action: Dictionary, name_text: String, mp_cost: int) -> Dictionary:
	var reason := ""
	if str(action.get("type", "")) == "dispel" and t.is_guardian and not t.revealed:
		reason = "HP %d%% 이하에서 가능" % int(GUARDIAN_REVEAL_RATIO * 100)
	elif u.spirit.mp < mp_cost:
		reason = "MP 부족"
	elif not _targets_for(u, u.cell, action).has(t.cell):
		reason = "사거리 밖"
	var title := name_text if mp_cost == 0 else "%s (MP %d)" % [name_text, mp_cost]
	var detail := reason if reason != "" else _preview_for(u, action, t)
	if reason == "" and _is_tab_attack(action) and t.team != u.team:
		var est := _expected_damage(u, u.cell, t, action)
		if est < t.spirit.hp and _can_counter(t, u):
			detail += " 반격-%d" % _counter_damage(t, u, false)
	var el := _action_element(u, action)
	if reason == "" and el != "" and t.team != u.team:
		var mult := GameData.element_multiplier(el, t.spirit.element())
		if mult > 1.0:
			detail += " 유리×1.5"
		elif mult < 1.0:
			detail += " 불리×0.75"
	return {"label": "%s\n%s" % [title, detail], "action": action, "ok": reason == ""}


## 반격을 부르는 공격인가 (공격 탭의 피해 행동)
func _is_tab_attack(action: Dictionary) -> bool:
	match str(action.get("type", "")):
		"attack", "skill":
			return true
		"sskill":
			return str(GameData.summoner_skills[action["skill_id"]].get("type", "")) == "attack"
	return false


## 난수 없는 예상 피해 (미리보기·AI)
func _expected_damage(u: BattleUnit, from_cell: Vector2i, t: BattleUnit, action: Dictionary) -> int:
	match str(action.get("type", "")):
		"attack":
			return _damage(u, from_cell, t, _attack_power(u), u.spirit.element(), false)
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			return _damage(u, from_cell, t, int(sk["power"]), str(sk["element"]), false)
		"sskill":
			var ssk: Dictionary = GameData.summoner_skills[action["skill_id"]]
			if str(ssk.get("type", "")) == "attack":
				return _damage(u, from_cell, t, int(ssk["power"]), str(ssk["element"]), false)
	return 0


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
		return "%s · %s" % [title, reason]
	if mp_cost > 0:
		return "%s  MP%d" % [title, mp_cost]
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
	var actor := active
	await _perform(actor, action, target)
	_script_event("acted", {"type": str(action.get("type", "")), "target": target})
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
		if kind == "dispel" and other.is_guardian and not other.revealed:
			continue  # 수호 정령은 실이 드러나야 디스펠 가능
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
			await _anim_melee(u, target, s.element())
			var dmg := _damage(u, u.cell, target, _attack_power(u), s.element(), true)
			_hit(u, target, dmg, "공격", s.element())
			await _try_counter(u, target)
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			s.mp = maxi(0, s.mp - int(sk["mp"]))
			await _anim_cast(u, target, str(sk["element"]))
			var skill_dmg := _damage(u, u.cell, target, int(sk["power"]), str(sk["element"]), true)
			_hit(u, target, skill_dmg, str(sk["name"]), str(sk["element"]))
			await _try_counter(u, target)
		"dispel":
			s.mp = maxi(0, s.mp - GameState.summoner.dispel_cost())
			await _anim_thread(u, target)
			_try_dispel(u, target)
		"recall":
			_recall(target)
		"sskill":
			var ssk: Dictionary = GameData.summoner_skills[action["skill_id"]]
			if str(ssk["type"]) == "attack":
				await _anim_cast(u, target, str(ssk["element"]))
			else:
				await _anim_hop(u, GameData.element_color(u.spirit.element()))
			_cast_summoner_skill(u, target, ssk)
			if str(ssk["type"]) != "attack":
				_award_xp(u, BattleLogic.SUPPORT_XP, false)
			if str(ssk["type"]) == "attack":
				await _try_counter(u, target)
	await get_tree().create_timer(ACTION_DELAY).timeout


# ---------------------------------------------------------------- 반격

## 공격 탭의 공격(기본 공격·정령 스킬·정령사 공격 스킬)을 받고 살아남은 쪽은,
## 공격한 상대가 기본 공격 사거리(1) 안이면 기본 공격으로 반격한다. 반격에는 다시 반격하지 않는다.
## → 원거리 스킬로 떨어져서 치면 반격을 피할 수 있다.
func _try_counter(attacker: BattleUnit, defender: BattleUnit) -> void:
	if not _can_counter(defender, attacker):
		return
	await get_tree().create_timer(0.12).timeout
	_log("%s의 반격!" % defender.spirit.display_name())
	_tutorial("counter")
	await _anim_melee(defender, attacker, defender.spirit.element())
	_hit(defender, attacker, _counter_damage(defender, attacker, true), "반격", defender.spirit.element())


func _can_counter(defender: BattleUnit, attacker: BattleUnit) -> bool:
	return defender.is_active() and attacker.is_active() \
		and grid.distance(defender.cell, attacker.cell) <= BattleLogic.BASIC_ATTACK_RANGE


func _counter_damage(defender: BattleUnit, attacker: BattleUnit, use_rng: bool) -> int:
	var dmg := _damage(defender, defender.cell, attacker, _attack_power(defender), defender.spirit.element(), use_rng)
	return maxi(1, int(round(dmg * BattleLogic.COUNTER_RATIO)))


# ---------------------------------------------------------------- 연출 (애니메이션)

## 근접 공격: 살짝 물러났다가 돌진 → 베기 효과
func _anim_melee(u: BattleUnit, t: BattleUnit, element: String) -> void:
	var dir := (t.draw_pos - u.draw_pos).normalized()
	var tw := create_tween()
	tw.tween_property(u, "anim_offset", -dir * 6.0, 0.08)
	tw.tween_property(u, "anim_offset", dir * 22.0, 0.08).set_ease(Tween.EASE_IN)
	await tw.finished
	_add_fx("slash", t.draw_pos, GameData.element_color(element).lightened(0.35), 0.3, {"dir": dir})
	var back := create_tween()
	back.tween_property(u, "anim_offset", Vector2.ZERO, 0.15)


## 스킬: 깡충 기를 모으고 → 속성 투사체 발사 → 착탄 폭발
func _anim_cast(u: BattleUnit, t: BattleUnit, element: String) -> void:
	var col := GameData.element_color(element).lightened(0.2)
	await _anim_hop(u, col)
	var dur := clampf(0.1 + 0.05 * grid.distance(u.cell, t.cell), 0.12, 0.3)
	_add_fx("projectile", u.draw_pos + Vector2(0, -8), col, dur, {"to": t.draw_pos, "el": element})
	await get_tree().create_timer(dur).timeout
	_add_fx("burst", t.draw_pos, col, 0.4, {"el": element})


## 기 모으기: 깡충 뛰며 빛이 모여든다
func _anim_hop(u: BattleUnit, col: Color) -> void:
	_add_fx("charge", u.draw_pos, col, 0.25)
	var tw := create_tween()
	tw.tween_property(u, "anim_offset", Vector2(0, -12), 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(u, "anim_offset", Vector2.ZERO, 0.1).set_ease(Tween.EASE_IN)
	await tw.finished


## 디스펠: 정령사에게서 금빛 실이 뻗어 나간다
func _anim_thread(u: BattleUnit, t: BattleUnit) -> void:
	await _anim_hop(u, Color(1.0, 0.85, 0.4))
	_add_fx("thread", u.draw_pos, Color(1.0, 0.85, 0.4), 0.4, {"to": t.draw_pos})
	await get_tree().create_timer(0.3).timeout


## 피격: 붉게 번쩍 + 좌우 흔들림
func _hit_react(t: BattleUnit) -> void:
	t.flash = 1.0
	var tw := create_tween()
	tw.tween_property(t, "flash", 0.0, 0.3)
	var sh := create_tween()
	sh.tween_property(t, "anim_offset", Vector2(5, 0), 0.04)
	sh.tween_property(t, "anim_offset", Vector2(-5, 0), 0.05)
	sh.tween_property(t, "anim_offset", Vector2(3, 0), 0.04)
	sh.tween_property(t, "anim_offset", Vector2.ZERO, 0.04)


## 사라지기: kind = "vanish"(빛이 되어 흩어짐) / "capture"(금빛 고리로 봉인·귀환)
func _vanish(u: BattleUnit, kind: String, color: Color) -> void:
	u.vanishing = true
	_add_fx(kind, u.draw_pos, color, 0.75)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(u, "fade", 0.0, 0.6).set_delay(0.1)
	if kind == "vanish":
		tw.tween_property(u, "pop", 0.6, 0.6).set_delay(0.1)
		tw.tween_property(u, "anim_offset", Vector2(0, -14), 0.6).set_delay(0.1)
	else:
		tw.tween_property(u, "pop", 0.2, 0.6).set_delay(0.1)


## 행동한 아군에게 바로 경험치. 레벨이 오르면 그 자리에서 LEVEL UP 연출.
func _award_xp(u: BattleUnit, amount: int, big: bool) -> void:
	if u == null or u.team != 0 or amount <= 0:
		return
	var s := u.spirit
	xp_gained[s] = int(xp_gained.get(s, 0)) + amount
	var old_level := s.level
	var msgs: Array[String] = s.gain_xp(amount)
	effects.append({"text": "+%d EXP" % amount, "pos": u.draw_pos + Vector2(0, -26), "color": Color(0.55, 0.85, 1.0) if not big else Color(0.7, 0.95, 1.0), "t": 0.15})
	if s.level > old_level:
		_effect("LEVEL UP!", u.draw_pos + Vector2(0, -50), UIKit.GOLD)
		_add_fx("rise", u.draw_pos, UIKit.GOLD, 0.9)
	for m in msgs:
		_log(m)
		xp_msgs.append(m)
	_mark_ui()


## 결과 화면용: 정령별 획득 경험치 + 레벨업 메시지
func _xp_summary() -> Array[String]:
	var lines: Array[String] = []
	for o in xp_gained:
		var s: Spirit = o
		lines.append("%s 경험치 +%d  (Lv.%d)" % [s.display_name(), int(xp_gained[o]), s.level])
	if lines.is_empty():
		lines.append("이번 전투에서 얻은 경험치가 없습니다.")
	lines.append_array(xp_msgs)
	return lines


func _add_fx(kind: String, pos: Vector2, color: Color, dur: float, extra: Dictionary = {}) -> void:
	var f := {"kind": kind, "pos": pos, "color": color, "t": 0.0, "dur": dur}
	f.merge(extra)
	fx.append(f)


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
				_add_fx("heal", t.draw_pos, Color(0.5, 1.0, 0.6), 0.7)
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
				_add_fx("buff" if up else "debuff", t.draw_pos, Color(0.5, 1.0, 0.6) if up else COLOR_OWNED_RING, 0.7)
				_effect("%s%s" % [Spirit.STAT_NAMES.get(stat_key, stat_key), "▲" if up else "▼"], t.draw_pos,
					Color(0.5, 1.0, 0.6) if up else COLOR_OWNED_RING)
				_log("%s의 %s! %s — %s" % [s.display_name(), skill_name, t.spirit.display_name(), str(sk.get("desc", ""))])


func _hit(attacker: BattleUnit, target: BattleUnit, dmg: int, action_name: String, element: String) -> void:
	var hp_before := target.spirit.hp
	if target == summoner_unit:
		# 정령사 보호: 한 번에 최대 HP의 40%까지만 (한 방에 패배하지 않게)
		dmg = mini(dmg, ceili(target.spirit.max_hp() * BattleLogic.SUMMONER_HIT_CAP))
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
	_hit_react(target)
	if target.spirit.hp <= 0 and _script_protects(target):
		target.spirit.hp = 1  # 튜토리얼: 디스펠할 정령이 먼저 쓰러지지 않게
	if target.spirit.hp <= 0:
		_knock_out(target)
	elif target.team == 1 and not target.is_summoner and not target.is_guardian and target.spirit.hp * 2 < target.spirit.max_hp():
		_tutorial("weak")
	# 경험치: 때릴 때마다 입힌 피해만큼, 마무리하면 크게
	if attacker.team == 0 and target.team == 1:
		var xp := BattleLogic.hit_xp(target.spirit, hp_before - target.spirit.hp)
		if not target.alive:
			xp += int(round(BattleLogic.xp_reward(target.spirit) * BattleLogic.KILL_XP_MULT))
		_award_xp(attacker, xp, not target.alive)
	_check_guardian_reveal(target)


func _knock_out(target: BattleUnit) -> void:
	if target.is_guardian:
		# 수호 정령은 쓰러지지 않는다 — 디스펠로 구해야 한다
		target.spirit.hp = 1
		_check_guardian_reveal(target)
		return
	target.alive = false
	_vanish(target, "vanish", Color(1.0, 1.0, 1.0))
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
			_vanish(u, "vanish", COLOR_OWNED_RING)
			_effect("도주", u.draw_pos, COLOR_OWNED_RING)
			fled += 1
	if fled > 0:
		_log("주인을 잃은 정령 %d마리가 흩어졌다." % fled)


func _dispel_chance(u: BattleUnit, t: BattleUnit) -> float:
	if _script_step_is("dispel") and t == _script_target():
		return 1.0  # 튜토리얼 디스펠은 반드시 성공
	var chance := BattleLogic.dispel_chance(u.spirit, t.spirit, t.owned)
	if t.is_guardian:
		chance = minf(0.95, chance + GUARDIAN_DISPEL_BONUS)
	return chance


## 수호 정령: HP가 일정 이하로 내려가면 실이 드러난다
func _check_guardian_reveal(t: BattleUnit) -> void:
	if not t.is_guardian or t.revealed:
		return
	if float(t.spirit.hp) <= float(t.spirit.max_hp()) * GUARDIAN_REVEAL_RATIO:
		t.revealed = true
		_log("%s의 엉킨 실이 드러났다! 지금 디스펠하면 구할 수 있다!" % t.spirit.display_name())
		_effect("실이 드러났다!", t.draw_pos + Vector2(0, -20), Color(1.0, 0.9, 0.5))
		_tutorial("revealed")


func _try_dispel(u: BattleUnit, target: BattleUnit) -> void:
	var chance := _dispel_chance(u, target)
	var pct := int(round(chance * 100.0))
	_log("%s이(가) 디스펠을 시도했다... (성공률 %d%%)" % [u.spirit.display_name(), pct])
	if rng.randf() < chance:
		target.captured = true
		captured.append(target.spirit)
		_award_xp(u, int(round(BattleLogic.xp_reward(target.spirit) * BattleLogic.DISPEL_XP_MULT)), true)
		# 계약한 정령은 다음 차례부터 바로 소환할 수 있다 (HP는 깎인 그대로)
		_vanish(target, "capture", Color(1.0, 0.85, 0.4))
		if target.is_guardian:
			_log("디스펠 성공! %s의 실이 풀려 정신을 되찾았다!" % target.spirit.display_name())
			for o in units:
				var other: BattleUnit = o
				if other.team == 1 and other.is_active():
					other.recalled = true
					_vanish(other, "vanish", COLOR_OWNED_RING)
					_effect("물러남", other.draw_pos, COLOR_OWNED_RING)
			_log("수호 정령이 진정되자 남은 정령들도 물러났다.")
		elif target.owned:
			_log("디스펠 성공! %s을(를) 적 정령사에게서 빼앗아 계약했다!" % target.spirit.display_name())
		else:
			_log("디스펠 성공! %s과(와) 계약했다!" % target.spirit.display_name())
			_tutorial("captured")
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
				if expected < target.spirit.hp and target.is_active() and grid.distance(cell, target.cell) <= BattleLogic.BASIC_ATTACK_RANGE:
					# 바로 옆에서 치면 반격 받을 피해도 고려 (떨어져서 스킬로 치면 반격 없음)
					var ce := _counter_damage(target, u, false)
					score -= ce * 0.6
					if ce >= u.spirit.hp:
						score -= 30.0
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
	_draw_background()
	var tile_size := Vector2(HexGrid.SQRT3 * HEX_SIZE, HEX_SIZE * 2.0)
	for row in ROWS:
		for col in COLS:
			var c := Vector2i(col, row)
			var center := grid.to_pixel(c)
			var pts := grid.corners(center, HEX_SIZE - 1.5)
			var tid := grid.terrain_at(c)
			var tile: Texture2D = tile_tex.get(tid, null)
			if tile != null:
				draw_texture_rect(tile, Rect2(center - tile_size * 0.5, tile_size), false)
			elif bg_tex != null:
				draw_colored_polygon(pts, Color(1, 1, 1, 0.055))  # 평지: 배경이 비치게
			else:
				draw_colored_polygon(pts, GameData.terrain_color(tid))
			_draw_terrain_deco(tid, center)
			var outline := pts.duplicate()
			outline.append(pts[0])
			draw_polyline(outline, COLOR_OUTLINE, 2.0)
			var over := _cell_overlay(c)
			if over.a > 0.0:
				draw_colored_polygon(grid.corners(center, HEX_SIZE - 3.0), over)
			if c == inspected_cell:
				draw_polyline(outline, Color(0.6, 0.9, 1.0), 3.0)
			if range_cells.has(c):
				var inner := grid.corners(center, HEX_SIZE - 6.0)
				inner.append(inner[0])
				draw_polyline(inner, Color(1.0, 0.35, 0.35, 0.85), 2.5)

	_draw_preview_ghost()
	for o in units:
		var u: BattleUnit = o
		if u.is_active() or (u.vanishing and u.fade > 0.01):
			_draw_unit(u)
	_draw_target_marks()
	_draw_fx()
	_draw_tutorial_focus()

	if phase == "targeting":
		for tcell in targets:
			var t: BattleUnit = targets[tcell]
			_draw_text(_preview_text(t), t.draw_pos + Vector2(0, -44), 20, Color(1.0, 0.9, 0.4))

	for e in effects:
		var a := 1.0 - float(e["t"])
		var col: Color = e["color"]
		col.a = a
		_draw_text(str(e["text"]), e["pos"] + Vector2(0, -50.0 * float(e["t"]) - 10.0), 28, col)


## 지형 위에 덧칠할 표시 색 (이동 가능/대상/현재 차례). 알파 = 진하기, 표시 없음은 투명.
func _cell_overlay(c: Vector2i) -> Color:
	if grid.blocked.has(c):
		return Color(0, 0, 0, 0)
	var pulse := 0.5 + 0.5 * sin(time * 6.0)
	var adv := _advantage_color(c)
	if phase == "targeting" and targets.has(c):
		if _pending_targets_allies():
			return Color(COLOR_ALLY_TARGET, 0.5 + 0.2 * pulse)
		return Color(adv if adv.a > 0.0 else COLOR_TARGET, 0.5 + 0.25 * pulse)
	if phase == "choose" and choose_target != null and choose_target.cell == c:
		var tint2 := COLOR_ALLY_TARGET if choose_target.team == 0 else COLOR_TARGET
		return Color(tint2, 0.5 + 0.2 * pulse)
	if adv.a > 0.0 and phase in ["player", "choose", "targeting"]:
		return Color(adv, 0.45)
	if phase == "placing" and place_cells.has(c):
		return Color(COLOR_PLACE, 0.45 + 0.2 * pulse)
	if phase == "player" and not has_moved and reachable.has(c):
		return Color(COLOR_MOVE, 0.7 if c == preview_cell else 0.42)
	if active != null and active.cell == c:
		return Color(COLOR_ACTIVE_CELL, 0.35)
	if phase in ["select", "player"]:
		if inspect_move.has(c):
			return Color(COLOR_INSPECT_MOVE, 0.4)
		if inspect_threat.has(c):
			return Color(COLOR_INSPECT_THREAT, 0.3)
	return Color(0, 0, 0, 0)


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


## 지형 위 움직이는 효과(물결·용암 빛·마법진 빛). 타일 그림이 없으면 간단한 도형으로 대신한다.
func _draw_terrain_deco(tid: String, center: Vector2) -> void:
	if tile_tex.has(tid):
		match tid:
			"water":
				var wp := PackedVector2Array()
				for i in 7:
					wp.append(center + Vector2(-18.0 + 6.0 * i, 6.0 + sin(i * 1.6 + time * 2.0) * 2.5))
				draw_polyline(wp, Color(0.8, 0.92, 1.0, 0.45), 2.0)
			"lava":
				draw_circle(center, HEX_SIZE * 0.55, Color(1.0, 0.45, 0.1, 0.10 + 0.08 * sin(time * 3.0)))
			"circle":
				_draw_circle_mark(grid.from_pixel(center), center)
		return
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
			_draw_circle_mark(grid.from_pixel(center), center)
		"rock":
			draw_circle(center, HEX_SIZE * 0.45, Color(0.3, 0.28, 0.25))
			draw_circle(center + Vector2(-6, -6), HEX_SIZE * 0.18, Color(0.4, 0.37, 0.33))


## 지역 배경: 화면을 꽉 채우도록 확대 (도트라 NEAREST)
func _draw_background() -> void:
	var vp := get_viewport_rect().size
	if bg_tex == null:
		draw_rect(Rect2(Vector2.ZERO, vp), COLOR_BG)
		return
	var ts := bg_tex.get_size()
	var k := maxf(vp.x / ts.x, vp.y / ts.y)
	var sz := ts * k
	draw_texture_rect(bg_tex, Rect2((vp - sz) * 0.5, sz), false)


## 전투 지역: 스토리 = 고향, 정령사 대결 = 상대 속성, 야생 = 가장 많은 적의 속성
func _battle_region() -> String:
	if not stage.is_empty():
		return GameState.region_element()
	if enemy_summoner_unit != null:
		return enemy_summoner_unit.spirit.element()
	var count := {}
	var best := GameState.home_element()
	var best_n := 0
	for o in units:
		var u: BattleUnit = o
		if u.team == 1:
			var el := u.spirit.element()
			count[el] = int(count.get(el, 0)) + 1
			if int(count[el]) > best_n:
				best_n = int(count[el])
				best = el
	return best


## 마법진 위에 선 유닛에 따라 색을 바꾼다. 비면 마지막 색 유지. 바뀔 때 번짐·회전·빛 입자 연출.
func _update_circles(delta: float) -> void:
	for c in grid.terrain:
		if str(grid.terrain[c]) != "circle":
			continue
		if not circle_state.has(c):
			circle_state[c] = {"from": CIRCLE_BASE, "to": CIRCLE_BASE, "t": CIRCLE_SHIFT_TIME}
		var st: Dictionary = circle_state[c]
		st["t"] = float(st["t"]) + delta
		var u := _unit_at(c)
		if u == null:
			continue
		var want := CIRCLE_BASE
		if u.team == 0:
			want = CIRCLE_ALLY
		elif u.is_summoner or u.owned:
			want = CIRCLE_ENEMY
		if want != st["to"]:
			st["from"] = _circle_color(c)
			st["to"] = want
			st["t"] = 0.0
			_add_fx("rise", grid.to_pixel(c), want, 0.9)


func _circle_color(c: Vector2i) -> Color:
	if not circle_state.has(c):
		return CIRCLE_BASE
	var st: Dictionary = circle_state[c]
	var k := clampf(float(st["t"]) / CIRCLE_SHIFT_TIME, 0.0, 1.0)
	return (st["from"] as Color).lerp(st["to"], k)


func _draw_circle_mark(c: Vector2i, center: Vector2) -> void:
	var col := _circle_color(c)
	var st: Dictionary = circle_state.get(c, {"t": CIRCLE_SHIFT_TIME, "to": CIRCLE_BASE})
	var k := clampf(float(st["t"]) / CIRCLE_SHIFT_TIME, 0.0, 1.0)
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	var owned: bool = st["to"] != CIRCLE_BASE
	var glow := 0.55 + 0.35 * sin(time * 2.5)
	# 가운데 빛 (차지한 진영 색)
	if owned:
		draw_circle(center, HEX_SIZE * 0.34, Color(col, 0.35 + 0.2 * glow))
		draw_circle(center, HEX_SIZE * 0.16, Color(col.lightened(0.4), 0.6 + 0.3 * glow))
	# 바뀌는 중: 가운데에서 새 색이 번져 나감
	if k < 1.0:
		draw_circle(center, HEX_SIZE * 0.66 * ease_k, Color(st["to"], 0.45 * (1.0 - k)))
	# 바깥 고리 (바뀔 때 한 번 크게 맥박)
	var ring_r := HEX_SIZE * 0.62 + 9.0 * sin(k * PI) * (1.0 if k < 1.0 else 0.0)
	draw_arc(center, ring_r, 0.0, TAU, 36, Color(col, 0.55 + 0.4 * glow), 3.0)
	draw_arc(center, HEX_SIZE * 0.42, 0.0, TAU, 32, Color(col, 0.5 + 0.3 * glow), 1.5)
	# 별 문양 (바뀔 때 한 바퀴 회전)
	var rot := ease_k * TAU if k < 1.0 else 0.0
	var star := PackedVector2Array()
	for i in 6:
		var ang := deg_to_rad(-90.0 + 144.0 * i) + rot
		star.append(center + Vector2(cos(ang), sin(ang)) * HEX_SIZE * 0.56)
	draw_polyline(star, Color(col, 0.75 + 0.25 * glow), 2.0)


func _load_battle_art() -> void:
	bg_tex = GameData.battle_tex("bg_" + _battle_region())
	for tid in ["forest", "water", "hill", "lava", "circle", "rock"]:
		var t := GameData.battle_tex("tile_" + tid)
		if t != null:
			tile_tex[tid] = t


func _draw_unit(u: BattleUnit) -> void:
	var p := u.draw_pos + u.anim_offset
	var el_color := GameData.element_color(u.spirit.element())
	var tex := GameData.sprite_for(u.spirit)
	if u.vanishing:
		# 사라지는 중: 스프라이트만 옅어지며 그린다
		var vs := (70.0 if u.is_guardian else 60.0) * u.pop
		if tex != null:
			draw_texture_rect(tex, Rect2(p + Vector2(-vs * 0.5, -vs * 0.5 - 6.0), Vector2(vs, vs)), false, Color(1, 1, 1, u.fade))
		else:
			draw_circle(p, 28.0 * u.pop, Color(el_color, u.fade))
		return
	# 진영 색: 아군 흰색(정령사 금색) / 야생 빨강 / 적 정령사의 정령 보라 / 적 정령사 빨강
	var team_col := Color(0.95, 0.95, 1.0)
	if u.team == 0 and u.is_summoner:
		team_col = Color(1.0, 0.85, 0.4)
	elif u.team == 1:
		team_col = COLOR_OWNED_RING if u.owned else Color(0.95, 0.3, 0.35)
	var resting := u.team == 0 and phase in ["select", "player", "choose", "targeting", "placing", "busy"] \
		and (u.done or u.joined_round >= round_num)

	if u == active:
		var pulse := 0.5 + 0.5 * sin(time * 6.0)
		draw_arc(p, 38.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.3, 0.4 + 0.6 * pulse), 4.0)
	if u == inspected:
		draw_arc(p, 38.0, 0.0, TAU, 40, Color(0.6, 0.9, 1.0), 3.0)

	# 발밑 받침 (진영 색)
	var base_col := team_col
	base_col.a = 0.35
	draw_colored_polygon(_ellipse(p + Vector2(0, 22), 27.0, 9.0), base_col)
	draw_polyline(_ellipse(p + Vector2(0, 22), 27.0, 9.0, true), team_col, 2.0)
	if u.joined_round >= round_num and (u.team == 0 or u.owned):
		# 이번 라운드에 소환되어 아직 행동하지 못하는 정령
		draw_arc(p, 34.0, 0.0, TAU, 40, Color(0.55, 0.85, 1.0, 0.5), 2.0)

	if u.is_guardian:
		var gp := 0.5 + 0.5 * sin(time * 3.0)
		draw_arc(p, 38.0, 0.0, TAU, 48, Color(1.0, 0.85, 0.35, 0.6 + 0.4 * gp), 3.0)

	if tex != null:
		var size := (70.0 if u.is_guardian else 60.0) * u.pop
		var bob := 0.0 if resting else sin(time * 3.0 + float(u.get_instance_id() % 7)) * 1.5
		var rect := Rect2(p + Vector2(-size * 0.5, -size * 0.5 - 6.0 + bob), Vector2(size, size))
		var mod := Color(0.45, 0.45, 0.5) if resting else Color.WHITE
		if u.flash > 0.0:
			mod = mod.lerp(Color(1.0, 0.35, 0.35), u.flash)
		mod.a = u.fade
		draw_texture_rect(tex, rect, false, mod)
	else:
		draw_circle(p, 28.0, el_color.darkened(0.2))
		draw_arc(p, 28.0, 0.0, TAU, 40, team_col, 3.0)
		_draw_text(u.spirit.display_name(), p + Vector2(0, 2), 16, Color.WHITE)

	if u.is_guardian:
		# 엉킨 회색 실 / 드러난 금빛 실
		var thread_col := Color(1.0, 0.9, 0.5, 0.9) if u.revealed else Color(0.6, 0.6, 0.65, 0.8)
		for k in 3:
			var a0 := time * 1.5 + k * TAU / 3.0
			draw_arc(p + Vector2(0, -4), 26.0 + k * 3.0, a0, a0 + 2.2, 12, thread_col, 2.0)
		_draw_text("수호", p + Vector2(0, -44), 15, Color(1.0, 0.85, 0.35))
	if u.team == 0 and not resting and u != active and phase in ["select", "player", "choose"]:
		draw_circle(p + Vector2(25, -25), 6.0, Color(0.45, 1.0, 0.55))  # 행동 가능
	_draw_buff_marks(u, p)
	_draw_text("Lv%d" % u.spirit.level, p + Vector2(-24, -24), 13, Color(1, 1, 1, 0.9))
	var ratio := float(u.spirit.hp) / float(maxi(1, u.spirit.max_hp()))
	var bar := Rect2(p + Vector2(-28, 33), Vector2(56, 6))
	draw_rect(bar, Color(0, 0, 0, 0.75))
	var hp_color := Color(0.4, 0.9, 0.45) if ratio > 0.5 else (Color(0.95, 0.8, 0.3) if ratio > 0.25 else Color(0.95, 0.35, 0.3))
	draw_rect(Rect2(bar.position, Vector2(56.0 * ratio, 6)), hp_color)


## 공격·소환·퇴장 시각 효과
func _draw_fx() -> void:
	for f in fx:
		var k := float(f["t"]) / float(f["dur"])   # 0 → 1
		var c: Color = f["color"]
		var p: Vector2 = f["pos"]
		match str(f["kind"]):
			"slash":
				var d: Vector2 = f.get("dir", Vector2.RIGHT)
				var base_a := d.angle() - 1.2
				for i in 3:
					var a0 := base_a + i * 0.25 + k * 1.4
					draw_arc(p, 20.0 + i * 5.0, a0, a0 + 1.3, 10, Color(c, 1.0 - k), 4.0 - i)
				draw_circle(p, 14.0 * (1.0 - k), Color(1, 1, 1, 0.5 * (1.0 - k)))
			"charge":
				draw_arc(p, 38.0 * (1.0 - k) + 6.0, 0.0, TAU, 24, Color(c, k), 3.0)
				for i in 6:
					var a := i * TAU / 6.0 + k * 2.0
					draw_circle(p + Vector2(cos(a), sin(a)) * 30.0 * (1.0 - k), 2.5, Color(c, k))
			"projectile":
				var to: Vector2 = f["to"]
				var el := str(f.get("el", ""))
				for i in 4:
					var pp := p.lerp(to, maxf(0.0, k - 0.07 * i))
					draw_circle(pp, 8.0 - i * 1.8, Color(c, 0.85 - 0.2 * i))
				var cur := p.lerp(to, k)
				match el:
					"fire":
						draw_circle(cur, 9.0, Color(1.0, 0.55, 0.15))
						draw_circle(cur, 5.0, Color(1.0, 0.95, 0.5))
					"water":
						var dir := (to - p).normalized()
						draw_colored_polygon(PackedVector2Array([cur + dir * 12.0, cur + dir.orthogonal() * 6.0, cur - dir * 6.0, cur - dir.orthogonal() * 6.0]), Color(0.6, 0.85, 1.0))
					"grass":
						var r := time * 12.0
						draw_colored_polygon(PackedVector2Array([cur + Vector2(cos(r), sin(r)) * 10.0, cur + Vector2(cos(r + 1.57), sin(r + 1.57)) * 4.0,
							cur + Vector2(cos(r + 3.14), sin(r + 3.14)) * 10.0, cur + Vector2(cos(r + 4.71), sin(r + 4.71)) * 4.0]), Color(0.5, 0.95, 0.4))
					"wind":
						var ang := (to - p).angle()
						draw_arc(cur, 11.0, ang - 1.4, ang + 1.4, 12, Color(0.95, 1.0, 1.0), 4.0)
					_:
						draw_circle(cur, 8.0, Color(1, 1, 1))
			"burst":
				draw_circle(p, 22.0 * (1.0 - k), Color(1, 1, 1, 0.6 * (1.0 - k)))
				draw_arc(p, 10.0 + 42.0 * k, 0.0, TAU, 32, Color(c, 1.0 - k), 4.0)
				for i in 8:
					var a := i * TAU / 8.0 + 0.3
					draw_circle(p + Vector2(cos(a), sin(a)) * (8.0 + 36.0 * k), 4.0 * (1.0 - k) + 1.0, Color(c, 1.0 - k))
			"heal":
				for i in 6:
					var a := i * TAU / 6.0
					var pp := p + Vector2(cos(a) * 22.0, sin(a) * 8.0 - 44.0 * k)
					draw_line(pp + Vector2(-4, 0), pp + Vector2(4, 0), Color(c, 1.0 - k), 2.5)
					draw_line(pp + Vector2(0, -4), pp + Vector2(0, 4), Color(c, 1.0 - k), 2.5)
				draw_arc(p, 30.0, 0.0, TAU, 32, Color(c, 0.6 * (1.0 - k)), 3.0)
			"buff", "debuff":
				var up := str(f["kind"]) == "buff"
				for i in 3:
					var x := -18.0 + 18.0 * i
					var y := (-10.0 - 34.0 * k) if up else (-44.0 + 34.0 * k)
					_draw_text("▲" if up else "▼", p + Vector2(x, y), 20, Color(c, 1.0 - k))
			"summon":
				var r := 38.0 * minf(1.0, k * 2.5)
				var ring := _ellipse(p + Vector2(0, 20), r, r * 0.4, true)
				draw_polyline(ring, Color(c, 1.0 - k * 0.7), 3.0)
				var star := PackedVector2Array()
				for i in 7:
					var a := (i * 2) * TAU / 6.0 + time * 2.0
					star.append(p + Vector2(0, 20) + Vector2(cos(a) * r, sin(a) * r * 0.4))
				draw_polyline(star, Color(c, 0.8 * (1.0 - k)), 2.0)
				var w := 26.0 * (1.0 - k)
				draw_rect(Rect2(p.x - w * 0.5, p.y - 70.0, w, 90.0), Color(c, 0.45 * (1.0 - k)))
				for i in 6:
					draw_circle(p + Vector2(-20.0 + 8.0 * i, 10.0 - 70.0 * fmod(k + i * 0.17, 1.0)), 2.5, Color(1, 1, 1, 1.0 - k))
			"rise":
				for i in 10:
					var rx := (i - 5) * 6.0 + sin(i * 2.3) * 5.0
					var ry := -10.0 - 70.0 * k * (0.5 + 0.08 * (i % 5))
					draw_circle(p + Vector2(rx, ry), 3.0 * (1.0 - k) + 0.8, Color(c, 1.0 - k))
			"vanish":
				for i in 12:
					var x := (i - 6) * 5.0 + sin(i * 1.7) * 4.0
					var y := -60.0 * k * (0.6 + 0.1 * (i % 4)) - 6.0
					draw_circle(p + Vector2(x, y), 3.5 * (1.0 - k) + 0.5, Color(c, 1.0 - k))
			"capture":
				draw_arc(p, 50.0 * (1.0 - k) + 8.0, 0.0, TAU, 32, Color(c, 1.0 - k * 0.5), 3.0)
				for i in 6:
					var a := i * TAU / 6.0 + k * 5.0
					draw_circle(p + Vector2(cos(a), sin(a)) * 40.0 * (1.0 - k), 3.0, Color(1, 1, 1, 1.0 - k))
			"thread":
				var to2: Vector2 = f["to"]
				var pts := PackedVector2Array()
				var n := 16
				for i in n + 1:
					var q := float(i) / n
					if q > k * 1.6:
						break
					var nrm := (to2 - p).normalized().orthogonal()
					pts.append(p.lerp(to2, q) + nrm * sin(q * 12.0 + time * 10.0) * 5.0)
				if pts.size() >= 2:
					draw_polyline(pts, Color(c, 1.0 - k * 0.6), 3.0)


func _ellipse(c: Vector2, rx: float, ry: float, closed: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 24
	for k in n:
		var a := TAU * k / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if closed:
		pts.append(pts[0])
	return pts


## 이동 미리보기: 선택한 유닛이 그 칸에 섰을 때의 모습
func _draw_preview_ghost() -> void:
	if active == null or phase != "player" or not grid.in_bounds(preview_cell):
		return
	var p := grid.to_pixel(preview_cell)
	var tex := GameData.sprite_for(active.spirit)
	if tex != null:
		draw_texture_rect(tex, Rect2(p + Vector2(-30, -36), Vector2(60, 60)), false, Color(1, 1, 1, 0.45))
	else:
		var col := GameData.element_color(active.spirit.element())
		col.a = 0.45
		draw_circle(p, 28.0, col)
	draw_arc(p, 30.0, 0.0, TAU, 40, Color(1, 1, 1, 0.7), 2.0)
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
			return "%d%%" % int(round(_dispel_chance(u, t) * 100.0))
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

	# ---- 위쪽 HUD: 라운드 알약 / 도움말 / 배속
	var turn_pill := PanelContainer.new()
	turn_pill.position = Vector2(14, 14)
	turn_pill.custom_minimum_size = Vector2(0, 56)
	turn_pill.add_theme_stylebox_override("panel", _pill_style(Color(0.07, 0.08, 0.12, 0.82), UIKit.GOLD.darkened(0.25), 28))
	turn_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(turn_pill)
	turn_label = Label.new()
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 21)
	turn_pill.add_child(turn_label)

	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_top = 14
	right.offset_right = -14
	right.add_theme_constant_override("separation", 8)
	ui_root.add_child(right)
	end_button = _hud_button("턴 종료", _on_end_phase)
	end_button.custom_minimum_size = Vector2(0, 56)
	right.add_child(end_button)
	retreat_button = _hud_button("후퇴", _confirm_retreat)
	retreat_button.custom_minimum_size = Vector2(0, 56)
	right.add_child(retreat_button)
	var help := _hud_button("?", _show_help)
	help.custom_minimum_size = Vector2(52, 56)
	right.add_child(help)
	speed_button = _hud_button("", _toggle_speed)
	speed_button.custom_minimum_size = Vector2(108, 56)
	right.add_child(speed_button)
	_update_speed_button()

	# ---- 아래쪽 명령 패널 (맵 바로 아래부터 화면 끝까지)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_top = map_bottom + 6.0
	panel.offset_bottom = 12.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.95)
	style.border_width_top = 3
	style.border_color = UIKit.GOLD.darkened(0.3)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	var card := HBoxContainer.new()
	card.add_theme_constant_override("separation", 12)
	vb.add_child(card)
	unit_card = card
	unit_icon = TextureRect.new()
	unit_icon.custom_minimum_size = Vector2(72, 72)
	unit_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	unit_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card.add_child(unit_icon)
	info_label = UIKit.label("", 22)
	card.add_child(info_label)

	hint_label = UIKit.label("", 22, UIKit.GOLD)
	vb.add_child(hint_label)
	detail_label = UIKit.label("", 20, Color(0.85, 0.88, 0.95))
	detail_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(detail_label)
	summon_box = VBoxContainer.new()
	summon_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summon_box.add_theme_constant_override("separation", 6)
	summon_box.visible = false
	vb.add_child(summon_box)
	summon_tabs = HBoxContainer.new()
	summon_tabs.add_theme_constant_override("separation", 6)
	summon_box.add_child(summon_tabs)
	var sscroll := ScrollContainer.new()
	sscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	summon_box.add_child(sscroll)
	summon_grid = GridContainer.new()
	summon_grid.columns = 2
	summon_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summon_grid.add_theme_constant_override("h_separation", 8)
	summon_grid.add_theme_constant_override("v_separation", 8)
	sscroll.add_child(summon_grid)
	log_label = UIKit.label("", 19, UIKit.MUTED)
	log_label.clip_text = true
	log_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	vb.add_child(log_label)

	# 명령 메뉴: 유닛 옆에 뜨는 세로 목록
	cmd_panel = PanelContainer.new()
	var cst := StyleBoxFlat.new()
	cst.bg_color = Color(0.06, 0.07, 0.11, 0.93)
	cst.border_color = UIKit.GOLD.darkened(0.15)
	cst.set_border_width_all(2)
	cst.set_corner_radius_all(12)
	cst.content_margin_left = 6
	cst.content_margin_right = 6
	cst.content_margin_top = 6
	cst.content_margin_bottom = 6
	cst.shadow_color = Color(0, 0, 0, 0.5)
	cst.shadow_size = 8
	cmd_panel.add_theme_stylebox_override("panel", cst)
	cmd_panel.visible = false
	ui_root.add_child(cmd_panel)
	cmd_box = VBoxContainer.new()
	cmd_box.add_theme_constant_override("separation", 2)
	cmd_panel.add_child(cmd_box)

	_build_tutorial_bubble()


func _pill_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(radius)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 4
	return st


## HUD용 둥근 버튼 (어두운 바탕 + 금테, 누르면 밝아짐)
func _hud_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", UIKit.GOLD)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.75))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.05))
	var normal := _pill_style(Color(0.07, 0.08, 0.12, 0.85), UIKit.GOLD.darkened(0.25), 28)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = UIKit.GOLD
	hover.bg_color = Color(0.13, 0.13, 0.18, 0.92)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = UIKit.GOLD
	pressed.border_color = Color(1, 0.95, 0.75)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


## 배속 표시: ▶ ×1 / ▶▶ ×2 / ▶▶▶ ×3 (빠를수록 밝은 금색)
func _update_speed_button() -> void:
	if speed_button == null:
		return
	speed_button.text = "%s×%d" % ["▶".repeat(battle_speed), battle_speed]
	var col := UIKit.GOLD if battle_speed == 1 else Color(1.0, 0.95, 0.6)
	speed_button.add_theme_color_override("font_color", col)
	var st := speed_button.get_theme_stylebox("normal") as StyleBoxFlat
	if st != null:
		st.border_color = UIKit.GOLD.darkened(0.25) if battle_speed == 1 else Color(1.0, 0.8, 0.3)
		st.bg_color = Color(0.07, 0.08, 0.12, 0.85) if battle_speed == 1 else Color(0.22, 0.16, 0.06, 0.9)


## 도움말: 상성·지형·조작 요약 (예전 상단 범례를 옮김)
func _show_help() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(overlay)
	var vb := UIKit.screen(overlay, 120, 120, false)
	vb.add_child(UIKit.label("전투 도움말", 36, UIKit.GOLD, true))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.text = "[b]상성[/b]  %s\n[color=#9aa3b5]▶ 방향으로 공격하면 ×1.5, 반대는 ×0.75[/color]\n적 칸 색: [color=#4de566]유리[/color] / [color=#f2cc4d]보통[/color] / [color=#80808f]불리[/color]\n\n[b]지형[/b]\n숲: 받는 피해 -20%%\n물가: 물↑ 불↓, 물 정령 회복\n모래밭: 이동 느림(바람은 빠름), 바람↑, 원거리 사거리 +1\n용암: 불↑, 그 밖엔 화상\n마법진: 라운드마다 HP·MP 회복\n바위: 지나갈 수 없음\n\n[b]조작[/b]\n아군을 누름 → 파란 칸(이동) → 적을 눌러 행동\n적을 누르면 주황 = 이동 범위, 빨강 = 공격 범위\n공격 탭(기본 공격·스킬·정령사 공격)으로 맞고 버틴 쪽은, 공격한 상대가 바로 옆이면 반격\n정령사 스킬(회복·버프·디버프)에는 반격 없음" % GameData.element_chart_bbcode()
	vb.add_child(rt)
	vb.add_child(UIKit.spacer())
	vb.add_child(UIKit.button("닫기", overlay.queue_free))


# ---------------------------------------------------------------- 튜토리얼 (전투 중 안내)
## data/chapter1.json "tutorials": {"<스테이지 id>" 또는 "*": [{"id", "on", "s", "t", "focus"}]}
##  - on: 이 이벤트가 일어나면 표시 (start, select, select_summoner, moved, choose, weak, captured,
##        counter, enemy_phase, round2, revealed, summon)
##  - focus: 가리킬 칸 (allies, summoner, enemies, enemy_summoner, weak, circle, guardian, advantage, disadvantage) — 금빛 테두리 + 화살표
##  - 한 번 본 안내는 GameState.flags["tut_<id>"]에 기록해 다시 나오지 않는다.

func _build_tutorial_bubble() -> void:
	tut_bubble = PanelContainer.new()
	tut_bubble.anchor_left = 0.0
	tut_bubble.anchor_right = 1.0
	tut_bubble.offset_left = 16
	tut_bubble.offset_right = -16
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.98, 0.95, 0.86, 0.97)
	st.border_color = Color(0.55, 0.4, 0.2)
	st.set_border_width_all(3)
	st.set_corner_radius_all(16)
	st.content_margin_left = 12
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 8
	tut_bubble.add_theme_stylebox_override("panel", st)
	tut_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	tut_bubble.gui_input.connect(_on_tut_input)
	tut_bubble.visible = false
	ui_root.add_child(tut_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_bubble.add_child(row)
	tut_icon = TextureRect.new()
	tut_icon.custom_minimum_size = Vector2(112, 112)
	tut_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tut_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tut_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tut_icon)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	tut_label = UIKit.label("", 26, Color(0.2, 0.15, 0.12))
	tut_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tut_label)
	tut_tap_label = UIKit.label("눌러서 닫기 ▶", 19, Color(0.5, 0.4, 0.3))
	tut_tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tut_tap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tut_tap_label)


func _tutorial_steps() -> Array:
	return GameData.tutorials_for(str(stage["id"]) if not stage.is_empty() else "")


## 이벤트가 일어났을 때 아직 안 본 안내가 있으면 띄운다.
func _tutorial(event: String) -> void:
	if _script_active():
		return  # 고정 튜토리얼 진행 중에는 일반 안내를 띄우지 않는다 (나중 스테이지에서 나옴)
	for o in _tutorial_steps():
		var step: Dictionary = o
		if str(step.get("on", "")) != event:
			continue
		var key := "tut_" + str(step.get("id", ""))
		if bool(GameState.flags.get(key, false)):
			continue
		GameState.flags[key] = true
		tut_queue.append(step)
		break
	if not tut_bubble.visible:
		_show_next_tutorial()


func _show_next_tutorial() -> void:
	tut_focus = []
	if tut_queue.is_empty() or phase == "over":
		tut_bubble.visible = false
		return
	var step: Dictionary = tut_queue.pop_front()
	var raw := str(step.get("s", "촌장"))
	tut_icon.texture = GameData.portrait_by_key(GameState.speaker_portrait_key(raw))
	tut_icon.visible = tut_icon.texture != null
	var who := GameState.fill_text(raw)
	tut_label.text = ("%s: " % who if who != "" else "") + GameState.fill_text(str(step.get("t", "")))
	tut_focus = step["_cells"] if step.has("_cells") else _tutorial_focus_cells(str(step.get("focus", "")))
	# 가리키는 칸이 위쪽이면 말풍선을 아래(패널 바로 위)에, 아니면 위(HUD 아래)에 둔다
	var avg_y := map_bottom
	if not tut_focus.is_empty():
		avg_y = 0.0
		for c in tut_focus:
			avg_y += grid.to_pixel(c).y
		avg_y /= float(tut_focus.size())
	tut_bubble.anchor_top = 0.0
	tut_bubble.anchor_bottom = 0.0
	if avg_y < (MAP_TOP + map_bottom) * 0.5:
		tut_bubble.offset_top = map_bottom - 196.0
	else:
		tut_bubble.offset_top = MAP_TOP + 4.0
	tut_bubble.offset_bottom = tut_bubble.offset_top + 180.0
	tut_bubble.visible = true
	tut_tap_label.visible = true
	tut_bubble.modulate.a = 0.0
	create_tween().tween_property(tut_bubble, "modulate:a", 1.0, 0.2)


func _on_tut_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		tut_bubble.accept_event()
		if script_i >= 0 and script_i < script_steps.size():
			if _script_step_is("free"):
				script_i = script_steps.size()   # 고정 튜토리얼 끝
				tut_focus = []
				_show_next_tutorial()
				_mark_ui()
			return  # 진행 중인 단계는 지시대로 해야 넘어간다
		_show_next_tutorial()


func _tutorial_focus_cells(spec: String) -> Array:
	var cells: Array = []
	match spec:
		"circle":
			for c in grid.terrain:
				if str(grid.terrain[c]) == "circle":
					cells.append(c)
			return cells
	for o in units:
		var u: BattleUnit = o
		if not u.is_active():
			continue
		var ok := false
		match spec:
			"allies":
				ok = u.team == 0
			"summoner":
				ok = u.team == 0 and u.is_summoner
			"enemies":
				ok = u.team == 1
			"weak":
				ok = u.team == 1 and not u.is_summoner and u.spirit.hp * 2 < u.spirit.max_hp()
			"guardian":
				ok = u.is_guardian
			"enemy_summoner":
				ok = u.team == 1 and u.is_summoner
			"advantage", "disadvantage":
				# 고른 아군(없으면 고향 속성) 기준 상성 유리/불리한 적
				var el := active.spirit.element() if active != null else GameState.home_element()
				var mult := GameData.element_multiplier(el, u.spirit.element())
				ok = u.team == 1 and (mult > 1.0 if spec == "advantage" else mult < 1.0)
		if ok:
			cells.append(u.cell)
	return cells


## 튜토리얼이 가리키는 칸: 금빛 테두리 + 위아래로 움직이는 화살표
func _draw_tutorial_focus() -> void:
	if tut_focus.is_empty() or not tut_bubble.visible:
		return
	var bob := sin(time * 5.0) * 5.0
	var a := 0.6 + 0.4 * sin(time * 6.0)
	for o in tut_focus:
		var c: Vector2i = o
		var center := grid.to_pixel(c)
		var pts := grid.corners(center, HEX_SIZE - 2.0)
		pts.append(pts[0])
		draw_polyline(pts, Color(1.0, 0.85, 0.3, a), 4.0)
		var tip := center + Vector2(0, -HEX_SIZE - 6.0 + bob)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -16), tip + Vector2(12, -16)]), Color(1.0, 0.85, 0.3))
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-12, -16), tip + Vector2(12, -16), tip]), Color(0.35, 0.22, 0.05), 2.0)


# ---------------------------------------------------------------- 고정 튜토리얼 스크립트 (1-1)
## stages[].script: [{"do", "t", "s"?, "unit"?, "cell"?, "target"?, "until"?}]
##  do = select(unit 누르기) / move(unit을 cell로) / attack(target에 공격 탭 공격) / dispel(target 디스펠)
##       / wait(until 이벤트, 예: "round2") / summon(한 마리 소환) / free(설명만, 눌러서 닫으면 자유 전투)
##  unit = "vanguard" | "summoner", target = 스테이지 enemies 번호
##  진행 중에는 지시한 입력만 받는다. 디스펠은 반드시 성공, 대상은 HP 1 아래로 떨어지지 않는다.

func _script_step() -> Dictionary:
	if script_i < 0 or script_i >= script_steps.size():
		return {}
	return script_steps[script_i]


func _script_step_is(kind: String) -> bool:
	return str(_script_step().get("do", "")) == kind


## 입력을 제한하는 단계인가 (free·끝이면 false)
func _script_active() -> bool:
	var step := _script_step()
	return not step.is_empty() and str(step.get("do", "")) != "free"


func _script_unit(step: Dictionary) -> BattleUnit:
	match str(step.get("unit", "")):
		"summoner":
			return summoner_unit
		"vanguard":
			return vanguard_unit
	return null


func _script_target() -> BattleUnit:
	var i := int(_script_step().get("target", -1))
	if i >= 0 and i < stage_enemy_units.size():
		return stage_enemy_units[i]
	return null


func _script_cell(step: Dictionary) -> Vector2i:
	var c = step.get("cell", null)
	if typeof(c) == TYPE_ARRAY:
		return Vector2i(int(c[0]), int(c[1]))
	return Vector2i(-1, -1)


## 아직 남은 디스펠 단계의 대상이면 쓰러지지 않게 보호
func _script_protects(t: BattleUnit) -> bool:
	if script_i < 0:
		return false
	for i in range(script_i, script_steps.size()):
		var step: Dictionary = script_steps[i]
		if str(step.get("do", "")) == "dispel":
			var idx := int(step.get("target", -1))
			if idx >= 0 and idx < stage_enemy_units.size() and stage_enemy_units[idx] == t:
				return true
	return false


func _show_script_step() -> void:
	var step := _script_step()
	if step.is_empty():
		tut_bubble.visible = false
		tut_focus = []
		return
	var focus: Array = []
	match str(step.get("do", "")):
		"select":
			var u := _script_unit(step)
			if u != null:
				focus.append(u.cell)
		"move":
			focus.append(_script_cell(step))
		"attack", "dispel":
			var t := _script_target()
			if t != null and t.is_active():
				focus.append(t.cell)
		"summon":
			focus.append(summoner_unit.cell)
	var shown := step.duplicate()
	shown["_cells"] = focus
	tut_queue.clear()
	tut_queue.append(shown)
	_show_next_tutorial()
	tut_tap_label.visible = _script_step_is("free")
	_mark_ui()


func _script_advance() -> void:
	script_i += 1
	_show_script_step()


## 전투 쪽 이벤트가 지금 단계의 지시와 맞으면 다음 단계로
func _script_event(event: String, data: Dictionary = {}) -> void:
	if not _script_active():
		return
	var step := _script_step()
	var done := false
	match str(step.get("do", "")):
		"select":
			done = event == "select" and active == _script_unit(step)
		"move":
			done = event == "moved" and active != null and active.cell == _script_cell(step)
		"attack":
			done = event == "acted" and str(data.get("type", "")) in ["attack", "skill", "sskill"] and data.get("target") == _script_target()
		"dispel":
			done = event == "acted" and str(data.get("type", "")) == "dispel"
		"wait":
			done = event == str(step.get("until", ""))
		"summon":
			done = event == "summoned"
	if done:
		_script_advance.call_deferred()


## 진행 중에는 지시한 칸·대상만 누를 수 있다
func _script_tap(c: Vector2i, u: BattleUnit) -> void:
	var step := _script_step()
	match str(step.get("do", "")):
		"select":
			if phase in ["select", "player"] and u != null and u == _script_unit(step) and not has_moved:
				_select_unit(u)
		"move":
			if phase == "player" and active == _script_unit(step) and c == _script_cell(step) and reachable.has(c):
				_move_player(c)
		"attack", "dispel":
			var t := _script_target()
			if t == null or u != t:
				return
			if phase == "targeting" and targets.has(c):
				_execute_player_action(t)
			elif phase in ["player", "choose"]:
				_open_target_menu(t)
		"summon":
			if phase == "placing" and place_cells.has(c):
				_execute_summon(pending["spirit"], c)


## 지금 단계에서 이 메뉴 버튼을 눌러도 되는가 (kind는 _add_action에 넘긴 종류)
func _script_allows(kind: String) -> bool:
	if not _script_active():
		return true
	var allowed: Array = []
	match str(_script_step().get("do", "")):
		"attack":
			allowed = ["attacks", "tab_attack", "opt_attack", "back", "cancel"]
		"dispel":
			allowed = ["attacks", "tab_dispel", "opt_dispel", "back", "cancel"]
		"summon":
			allowed = ["summon", "summon_pick", "summon_done", "back", "cancel"]
	return kind in allowed


func _mark_ui() -> void:
	_ui_dirty = true


func _rebuild_ui() -> void:
	for c in cmd_box.get_children():
		cmd_box.remove_child(c)
		c.queue_free()
	detail_label.text = ""
	summon_box.visible = false
	detail_label.visible = true
	unit_card.visible = true
	log_label.visible = true

	if phase == "over":
		turn_label.text = "전투 종료"
		turn_label.add_theme_color_override("font_color", Color.WHITE)
	elif phase == "enemy":
		turn_label.text = "R%d  적 턴" % round_num
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.55))
	else:
		turn_label.text = "R%d 아군 턴 · 행동 %d" % [round_num, _ready_allies().size()]
		turn_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	end_button.visible = (phase == "select" or (phase == "player" and not has_moved)) and not _script_active()
	retreat_button.disabled = not _can_retreat()

	var shown: BattleUnit = inspected if inspected != null else (null if grid.in_bounds(inspected_cell) else active)
	if shown == null and phase == "enemy":
		shown = active
	if inspected == null and grid.in_bounds(inspected_cell):
		info_label.text = _terrain_info(inspected_cell)
		unit_icon.texture = tile_tex.get(grid.terrain_at(inspected_cell), null)
	else:
		info_label.text = _unit_info(shown)
		unit_icon.texture = GameData.sprite_for(shown.spirit) if shown != null else null
	unit_icon.visible = unit_icon.texture != null

	var anchor: BattleUnit = active
	match phase:
		"select":
			hint_label.text = "행동할 아군을 고르세요. 초록 점 = 행동 가능, 순서 자유.\n모두 행동하면 적 턴. 일찍 끝내려면 위쪽 '턴 종료'."
		"player":
			if active.is_summoner:
				_build_summoner_actions()
			else:
				_build_spirit_actions()
		"choose":
			anchor = choose_target
			for o in _target_options(active, choose_target):
				var opt: Dictionary = o
				var act: Dictionary = opt["action"]
				_add_action(str(opt["label"]), func(): _choose_option(act), not bool(opt["ok"]), "opt_" + str(act.get("type", "")))
			_add_action("취소", _cancel_choose, false, "cancel")
			hint_label.text = "%s에게 할 행동을 고르세요. (흐린 버튼 = MP 부족 / 사거리 밖)" % choose_target.spirit.display_name()
		"targeting":
			_add_action("취소", _cancel_targeting, false, "cancel")
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
			detail_label.text = _action_desc(active, pending)
		"placing":
			_add_action("취소", _cancel_targeting, false, "cancel")
			hint_label.text = "%s을(를) 소환할 칸을 누르세요." % (pending["spirit"] as Spirit).display_name()
		"enemy":
			hint_label.text = "적이 움직이고 있다..."
		_:
			hint_label.text = ""

	log_label.text = "\n".join(PackedStringArray(log_lines))
	cmd_panel.visible = cmd_box.get_child_count() > 0 and anchor != null
	# 튜토리얼에서 메뉴를 쓸 수 없는 단계(고르기·이동·대기)는 메뉴를 숨겨 칸을 가리지 않게
	if _script_active() and str(_script_step().get("do", "")) in ["select", "move", "wait"]:
		cmd_panel.visible = false
	if cmd_panel.visible:
		_place_cmd_menu.call_deferred(anchor)


## 명령 메뉴를 유닛 옆에 붙인다 (원작처럼). 오른쪽/왼쪽 × 가운데/위/아래 중에서
## 이동할 칸·대상·튜토리얼 표시 칸을 가장 적게 가리는 자리를 고른다.
func _place_cmd_menu(anchor: BattleUnit) -> void:
	if anchor == null or not cmd_panel.visible:
		return
	cmd_panel.reset_size()
	var sz := cmd_panel.get_combined_minimum_size()
	var vp := get_viewport_rect().size
	var p := anchor.draw_pos
	var top_lim := MAP_TOP + 4.0
	var bottom_lim := maxf(top_lim, map_bottom - sz.y - 4.0)
	var important := _menu_avoid_cells(anchor)
	var best := Vector2.ZERO
	var best_score := INF
	var sides: Array = [1.0, -1.0] if p.x < vp.x * 0.5 else [-1.0, 1.0]
	for side in sides:
		var x := p.x + HEX_SIZE + 6.0 if side > 0.0 else p.x - HEX_SIZE - 6.0 - sz.x
		x = clampf(x, 8.0, vp.x - sz.x - 8.0)
		for ys in [p.y - sz.y * 0.5, p.y - sz.y + HEX_SIZE * 0.5, p.y - HEX_SIZE * 0.5]:
			var y := clampf(float(ys), top_lim, bottom_lim)
			var rect := Rect2(Vector2(x, y), sz).grow(6.0)
			var score := 0.0
			for o in important:
				var item: Array = o
				if rect.has_point(grid.to_pixel(item[0])):
					score += float(item[1])
			if score < best_score - 0.01:
				best_score = score
				best = Vector2(x, y)
	cmd_panel.position = best


## 메뉴가 가리면 곤란한 칸: [칸, 중요도]
func _menu_avoid_cells(anchor: BattleUnit) -> Array:
	var result: Array = [[anchor.cell, 10.0]]
	for c in tut_focus:
		result.append([c, 6.0])
	if phase == "player" and not has_moved:
		for c in reachable:
			result.append([c, 1.0])
	for c in targets:
		result.append([c, 3.0])
	for c in place_cells:
		result.append([c, 2.0])
	if phase == "player" and active != null:
		for c in hit_now:
			result.append([c, 3.0])
		for c in reach_targets:
			result.append([c, 1.5])
	return result


func _move_hint() -> String:
	if has_moved:
		return "⚔ 빨간 조준 = 지금 공격 가능. 적을 누르거나 '공격'을 고르세요."
	if grid.in_bounds(preview_cell):
		return "미리보기: 같은 칸을 다시 누르면 이동. 적을 누르면 그 자리로 가서 행동."
	return "파란 칸 = 이동 가능. ⚔ = 지금 공격 가능, 주황 링 = 이동하면 공격 가능."


func _add_common_actions() -> void:
	if grid.in_bounds(preview_cell) and not has_moved:
		_add_action("여기로 이동", _confirm_preview_move, false, "move_here")
	_add_action("대기", _on_wait, false, "wait")
	if has_moved:
		_add_action("이동 취소", _undo_move, false, "undo")
	else:
		_add_action("닫기", _deselect, false, "close")


## 공격 탭: 정령 = 기본 공격 + 스킬(최대 2) / 정령사 = 기본 공격 + 공격 스킬 + 디스펠
func _attack_tab(u: BattleUnit) -> Array:
	var tab: Array = [{"type": "attack"}]
	if u.is_summoner:
		var m: Summoner = u.spirit
		var sid := m.attack_skill_id()
		if sid != "":
			tab.append({"type": "sskill", "skill_id": sid})
		tab.append({"type": "dispel"})
	else:
		for sid in u.spirit.known_skills():
			tab.append({"type": "skill", "skill_id": sid})
	return tab


func _action_name(u: BattleUnit, action: Dictionary) -> String:
	match str(action.get("type", "")):
		"attack":
			return "기본 공격"
		"dispel":
			return "디스펠"
		"skill":
			return str(GameData.skills[action["skill_id"]]["name"])
		"sskill":
			return str(GameData.summoner_skills[action["skill_id"]]["name"])
	return ""


func _action_mp(u: BattleUnit, action: Dictionary) -> int:
	match str(action.get("type", "")):
		"dispel":
			return GameState.summoner.dispel_cost()
		"skill":
			return int(GameData.skills[action["skill_id"]]["mp"])
		"sskill":
			return int(GameData.summoner_skills[action["skill_id"]]["mp"])
	return 0


## 아래 패널에 띄울 행동 설명 한 줄
func _action_desc(u: BattleUnit, action: Dictionary) -> String:
	match str(action.get("type", "")):
		"attack":
			return "· 기본 공격 [%s] 사거리 1 · MP 0 — 맞고 버틴 적은 반격한다" % GameData.element_name(u.spirit.element())
		"dispel":
			return "· 디스펠 MP %d · 사거리 %d — 약해진 정령의 실을 풀고 계약" % [GameState.summoner.dispel_cost(), GameState.summoner.dispel_range()]
		"skill":
			var sk: Dictionary = GameData.skills[action["skill_id"]]
			return "· %s%s [%s] 위력 %d · 사거리 %d~%d · MP %d — %s" % [sk["name"], " ★숨은 기술" if bool(sk.get("hidden", false)) else "",
				GameData.element_name(sk["element"]), int(sk["power"]), int(sk["range_min"]), int(sk["range_max"]), int(sk["mp"]), sk.get("desc", "")]
		"sskill":
			var ssk: Dictionary = GameData.summoner_skills[action["skill_id"]]
			return "· %s 사거리 %d~%d · MP %d — %s" % [ssk["name"], int(ssk.get("range_min", 0)), int(ssk.get("range_max", 0)), int(ssk["mp"]), ssk.get("desc", "")]
	return ""


func _build_attack_tab() -> void:
	var lines := PackedStringArray()
	for o in _attack_tab(active):
		var action: Dictionary = o
		var mp_cost := _action_mp(active, action)
		var reason := _block_reason(active, action, mp_cost)
		_add_action(_labeled(_action_name(active, action), mp_cost, reason), func(): _choose_tab_action(action), reason != "", "tab_" + str(action.get("type", "")))
		lines.append(_action_desc(active, action))
	_add_action("뒤로", _close_submenu, false, "back")
	hint_label.text = "공격 탭: 쓸 공격을 고르고 대상을 누르세요. (흐린 버튼 = MP 부족 / 사거리 안에 대상 없음)"
	detail_label.text = "\n".join(lines)


## 소환 목록 (아래 패널): 계약 정령 전체를 속성 탭으로 거르고, 지금 적에게 유리한 정령부터 보여 준다.
func _build_summon_list() -> void:
	unit_card.visible = false
	detail_label.visible = false
	log_label.visible = false
	summon_box.visible = true
	UIKit.clear(summon_tabs)
	UIKit.clear(summon_grid)
	var m := GameState.summoner
	var full := _summoned_count() >= m.summon_limit()
	var no_room := _free_cells_around(active.cell).is_empty()
	var entries: Array = []
	var counts := {"all": 0}
	for o in _all_contracted():
		var s: Spirit = o
		if _field_unit_of(s) != null:
			continue  # 이미 전장에 있음
		counts["all"] = int(counts["all"]) + 1
		counts[s.element()] = int(counts.get(s.element(), 0)) + 1
		if summon_filter != "all" and s.element() != summon_filter:
			continue
		var cost := m.summon_cost(s)
		var reason := ""
		if s.hp <= 0:
			reason = "기절"
		elif full:
			reason = "한도 초과"
		elif m.mp < cost:
			reason = "MP 부족"
		elif no_room:
			reason = "빈 칸 없음"
		entries.append({"s": s, "cost": cost, "reason": reason, "adv": _summon_advantage(s)})
	entries.sort_custom(_summon_entry_before)
	# 속성 탭
	for key in ["all", "wind", "fire", "grass", "water"]:
		var label := "전체" if key == "all" else GameData.element_name(key)
		var tb := _hud_button("%s %d" % [label, int(counts.get(key, 0))], _set_summon_filter.bind(key))
		tb.custom_minimum_size = Vector2(0, 44)
		tb.add_theme_font_size_override("font_size", 18)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key != "all":
			tb.add_theme_color_override("font_color", GameData.element_color(key).lightened(0.35))
		if key == summon_filter:
			var sel := tb.get_theme_stylebox("normal") as StyleBoxFlat
			sel.bg_color = Color(0.3, 0.24, 0.1, 0.95)
			sel.border_color = UIKit.GOLD
		summon_tabs.add_child(tb)
	# 카드
	for o in entries:
		var e: Dictionary = o
		var s: Spirit = e["s"]
		var reason := str(e["reason"])
		var tag := "  ★유리" if int(e["adv"]) > 0 else ("  불리" if int(e["adv"]) < 0 else "")
		var b := Button.new()
		b.text = "%s Lv%d%s\nHP %d/%d · MP %d%s" % [s.display_name(), s.level, tag, s.hp, s.max_hp(), int(e["cost"]),
			"" if reason == "" else " · " + reason]
		b.icon = GameData.sprite_for(s)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 48)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 66)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55) if int(e["adv"]) > 0 else Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.66, 0.55))
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.13, 0.14, 0.2)
		st.border_color = GameData.element_color(s.element()).darkened(0.1)
		st.border_width_left = 5
		st.set_corner_radius_all(8)
		st.content_margin_left = 10
		b.add_theme_stylebox_override("normal", st)
		var hv := st.duplicate() as StyleBoxFlat
		hv.bg_color = Color(0.2, 0.2, 0.28)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("disabled", st)
		b.disabled = reason != "" or not _script_allows("summon_pick")
		b.pressed.connect(func(): _choose_summon(s))
		summon_grid.add_child(b)
	if entries.is_empty():
		summon_grid.add_child(UIKit.label("소환할 수 있는 정령이 없습니다.", 20, UIKit.MUTED))


## 소환 목록 정렬: 지금 소환 가능 → 상성 유리 → 레벨 높은 순
func _summon_entry_before(a: Dictionary, b: Dictionary) -> bool:
	var ra := str(a["reason"]) == ""
	var rb := str(b["reason"]) == ""
	if ra != rb:
		return ra
	if int(a["adv"]) != int(b["adv"]):
		return int(a["adv"]) > int(b["adv"])
	return (a["s"] as Spirit).level > (b["s"] as Spirit).level


func _set_summon_filter(key: String) -> void:
	summon_filter = key
	_mark_ui()


## 전장의 적들에 대한 상성 점수 (유리한 적 수 - 불리한 적 수)
func _summon_advantage(s: Spirit) -> int:
	var score := 0
	for o in units:
		var u: BattleUnit = o
		if u.team != 1 or not u.is_active():
			continue
		var mult := GameData.element_multiplier(s.element(), u.spirit.element())
		if mult > 1.0:
			score += 1
		elif mult < 1.0:
			score -= 1
	return score


func _choose_tab_action(action: Dictionary) -> void:
	submenu = ""
	_begin_targeting(action)


func _build_summoner_actions() -> void:
	var m := GameState.summoner
	if summoning:
		submenu = "summon"
	if submenu == "summon":
		_build_summon_list()
		if summoning:
			_add_action("소환 완료", _on_summon_done, false, "summon_done")
			hint_label.text = "계속 소환하거나 옆 메뉴의 '소환 완료'를 누르세요. (%d/%d, MP %d)" % [_summoned_count(), m.summon_limit(), m.mp]
		else:
			_add_action("뒤로", _close_submenu, false, "back")
			hint_label.text = "아래 목록에서 소환할 정령을 고르세요. 한 번에 여러 마리 가능 (%d/%d, MP %d)" % [_summoned_count(), m.summon_limit(), m.mp]
		return
	if submenu == "attacks":
		_build_attack_tab()
		return
	if submenu == "sskills":
		var lines := PackedStringArray()
		for o in m.support_skill_ids():
			var sid := str(o)
			var sk: Dictionary = GameData.summoner_skills[sid]
			var action := {"type": "sskill", "skill_id": sid}
			var reason := _block_reason(active, action, int(sk["mp"]))
			_add_action(_labeled(str(sk["name"]), int(sk["mp"]), reason), func(): _choose_summoner_skill(sid), reason != "", "sskill_pick")
			lines.append(_action_desc(active, action))
		_add_action("뒤로", _close_submenu, false, "back")
		hint_label.text = "정령사 스킬을 고르세요. (흐린 버튼 = MP 부족 / 대상 없음)"
		detail_label.text = "\n".join(lines)
		return
	_add_action("공격 ▸", _open_submenu.bind("attacks"), false, "attacks")
	_add_action("스킬 ▸", _open_submenu.bind("sskills"), m.support_skill_ids().is_empty(), "sskills")
	_add_action("소환 ▸", _open_submenu.bind("summon"), not _can_summon_more(), "summon")
	_add_common_actions()
	hint_label.text = _move_hint()


func _build_spirit_actions() -> void:
	if submenu == "attacks":
		_build_attack_tab()
		return
	_add_action("공격 ▸", _open_submenu.bind("attacks"), false, "attacks")
	if _can_recall(active):
		_add_action("귀환", _on_recall, false, "recall")
	_add_common_actions()
	hint_label.text = _move_hint()


func _add_action(text: String, cb: Callable, disabled: bool = false, kind: String = "") -> void:
	var b := Button.new()
	b.text = text
	b.disabled = disabled or not _script_allows(kind)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CMD_MIN_WIDTH, 54)   # 글자에 맞춰 늘어남 (공격 탭은 스킬 이름만큼)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	b.add_theme_color_override("font_hover_color", UIKit.GOLD)
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.05))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.66, 0.5))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 14
	normal.content_margin_right = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1, 0.85, 0.45, 0.14)
	hover.set_corner_radius_all(8)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = UIKit.GOLD
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	cmd_box.add_child(b)


func _unit_info(u: BattleUnit) -> String:
	if u == null:
		return ""
	var s := u.spirit
	var tag := _unit_tag(u)
	var extra := ""
	if u.is_summoner:
		extra = " 소환 %d/%d" % [_summoned_count(u.team), (s as Summoner).summon_limit()]
	extra += " 사거리%d" % _max_attack_range(u)
	for b in u.buffs:
		extra += "  [%s %d]" % [b["name"], int(b["rounds"])]
	return "[%s] %s Lv.%d %s · HP %d/%d MP %d/%d\n공%d 방%d 속%d 이동%d%s · %s" % [
		tag, s.display_name(), s.level, GameData.element_name(s.element()),
		s.hp, s.max_hp(), s.mp, s.max_mp(),
		s.stat("atk"), s.stat("def"), s.stat("spd"), s.stat("mov"), extra,
		GameData.terrain_name(grid.terrain_at(u.cell))]


func _unit_tag(u: BattleUnit) -> String:
	if u.team == 0:
		return "정령사" if u.is_summoner else "아군"
	if u.is_summoner:
		return "적 정령사"
	if u.is_guardian:
		return "수호 정령 (실 드러남)" if u.revealed else "수호 정령"
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
	full_log.append("R%d %s" % [round_num, text])  # 전체 기록 (테스트·디버그용)
	log_lines.append(text)
	while log_lines.size() > 1:
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
		list.add_child(UIKit.reward_line(line, 26))
	vb.add_child(UIKit.button("월드맵으로" if not stage.is_empty() else "거점으로", _return_to_hub))


## 스토리 전투면 월드맵, 아니면 거점으로 돌아간다.
func _exit_scene() -> String:
	return "res://scenes/world_map.tscn" if not stage.is_empty() else "res://scenes/hub.tscn"


func _return_to_hub() -> void:
	get_tree().change_scene_to_file(_exit_scene())
