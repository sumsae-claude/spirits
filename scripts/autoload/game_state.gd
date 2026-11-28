extends Node
## 진행 상태(정령사, 계약 정령, 보관함, 인벤토리)와 저장/불러오기.

## 저장: 0번 = 자동 저장 칸 (전투 후·지도 이동 때 자동), 1~99번 = 직접 저장하는 슬롯
const OLD_SAVE_PATH := "user://save.json"   # 슬롯 도입 전 저장 → 자동 저장 칸으로 옮김
const SAVE_SLOTS := 99
const SAVE_VERSION := 2
## 정령사 속성 -> 첫 계약 정령
const STARTERS := {"wind": "breezebird", "fire": "emberbean", "grass": "pebble", "water": "dewdrop"}
const STARTER_LEVEL := 3
const DEFAULT_NAME := "리안"
## 속성별 진화 전 정령 계열 [첫 정령 계열, 두 번째 계열]
const FAMILIES := {
	"wind": ["breezebird", "whirlmouse"], "fire": ["emberbean", "ashfox"],
	"grass": ["pebble", "mossturtle"], "water": ["dewdrop", "mistwhale"],
}
## 상성 중립 속성 (라이벌 속성)
const NEUTRAL_OF := {"wind": "grass", "grass": "wind", "fire": "water", "water": "fire"}
const GUARDIANS := {"wind": "guardian_wind", "fire": "guardian_fire", "grass": "guardian_grass", "water": "guardian_water"}
const RIVAL_NAMES := ["카렌", "도윤", "세라", "모로", "이안", "루카", "하린", "벨"]

var summoner: Summoner = null
var party: Array = []      # 계약한 정령 전부 = 보관함 (Spirit). 첫 번째가 선봉 (전투 시작 때 자동 소환)
var storage: Array = []    # 예전 저장 데이터 호환용. 불러올 때 party로 합치므로 늘 비어 있음
var inventory: Array = []  # 장착하지 않은 장비 id
var battles_won: int = 0
var gold: int = 0
## 마을 의뢰: 의뢰 id -> {"state": "active"|"claimed", "progress": int, "el": 속성(계약·퇴치 의뢰)}
var quests: Dictionary = {}
## 지금 모험 중인 챕터 번호 (GameData.chapters 기준). 지역 표식(@reg_a 등)과 전투 배경이 이 챕터 지역을 따른다.
var active_chapter: int = 0
var current_encounter: Array = []  # 다음 전투에 나올 야생 정령 (Spirit)
var current_rival: Dictionary = {}
var hub_message := ""  # 거점 화면에 한 번 보여줄 알림 (후퇴 결과 등)
## 스토리 진행
var cleared_stages: Array = []      # 클리어한 스테이지 id
var flags: Dictionary = {}          # 프롤로그 봤음 등
var current_stage: Dictionary = {}  # 다음 전투가 스토리 스테이지면 그 정보
var pending_dialogue := ""          # 월드맵으로 돌아왔을 때 보여줄 대화 키  # 다음 전투의 적 정령사 {"summoner": Summoner, "party": [Spirit]}


func new_game(p_name: String, element: String) -> void:
	var nm := p_name.strip_edges()
	if nm == "":
		nm = DEFAULT_NAME
	summoner = Summoner.create_summoner(nm.left(8), element, STARTER_LEVEL)
	party = [Spirit.create(str(STARTERS[element]), STARTER_LEVEL)]
	storage = []
	inventory = ["wood_wand", "leaf_charm", "conductor_staff", "sage_robe"]
	battles_won = 0
	gold = 50
	quests = {}
	active_chapter = 0
	current_encounter = []
	cleared_stages = []
	flags = {}
	current_stage = {}
	pending_dialogue = ""
	save_game()


func slot_path(slot: int) -> String:
	return "user://save_auto.json" if slot == 0 else "user://save_%02d.json" % slot


func _migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE_PATH) and not FileAccess.file_exists(slot_path(0)):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(OLD_SAVE_PATH), ProjectSettings.globalize_path(slot_path(0)))


func has_save() -> bool:
	return latest_slot() >= 0


## 가장 최근에 저장된 칸 번호 (없으면 -1)
func latest_slot() -> int:
	_migrate_old_save()
	var best := -1
	var best_time := -1
	for i in range(0, SAVE_SLOTS + 1):
		var path := slot_path(i)
		if FileAccess.file_exists(path):
			var t := int(FileAccess.get_modified_time(path))
			if t > best_time:
				best_time = t
				best = i
	return best


## 슬롯 목록에 보여 줄 요약. 빈 칸이면 빈 딕셔너리.
func slot_info(slot: int) -> Dictionary:
	if slot == 0:
		_migrate_old_save()
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return {"broken": true}
	var meta: Dictionary = data.get("meta", {})
	meta["time"] = Time.get_datetime_string_from_unix_time(int(FileAccess.get_modified_time(path)) + _tz_offset_sec(), true)
	return meta


func _tz_offset_sec() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## 슬롯에 저장 (자동 저장 칸에도 같이 남긴다)
func save_to_slot(slot: int) -> void:
	save_game()
	if slot > 0:
		_write_save(slot_path(slot))


func load_slot(slot: int) -> bool:
	return _read_save(slot_path(slot))


func save_game() -> void:
	_write_save(slot_path(0))


func _write_save(path: String) -> void:
	var data := {
		"meta": {
			"name": summoner.display_name() if summoner != null else DEFAULT_NAME,
			"element": home_element(),
			"level": summoner.level if summoner != null else 1,
			"chapter": str(chapter_data(active_chapter).get("title", "")),
			"region": chapter_region_name(active_chapter),
			"gold": gold,
			"spirits": party.size(),
		},
		"version": SAVE_VERSION,
		"summoner": summoner.to_dict() if summoner != null else {},
		"party": party.map(func(s): return s.to_dict()),
		"storage": storage.map(func(s): return s.to_dict()),
		"inventory": inventory,
		"battles_won": battles_won,
		"gold": gold,
		"quests": quests,
		"active_chapter": active_chapter,
		"cleared_stages": cleared_stages,
		"flags": flags,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))


## 가장 최근 저장 불러오기 (타이틀의 '이어하기')
func load_game() -> bool:
	var slot := latest_slot()
	return slot >= 0 and _read_save(slot_path(slot))


func _read_save(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var sd = data.get("summoner", {})
	if typeof(sd) == TYPE_DICTIONARY and not sd.is_empty():
		summoner = Summoner.from_summoner_dict(sd)
	else:
		# 정령사가 없던 v1 저장 데이터
		summoner = Summoner.create_summoner(DEFAULT_NAME, "fire", STARTER_LEVEL)
	party = _load_spirits(data.get("party", []))
	party.append_array(_load_spirits(data.get("storage", [])))  # 파티·보관함 구분 없앰 → 하나로
	storage = []
	inventory = []
	var inv = data.get("inventory", [])
	if typeof(inv) == TYPE_ARRAY:
		for e in inv:
			if GameData.equipment.has(str(e)):
				inventory.append(str(e))
	battles_won = int(data.get("battles_won", 0))
	gold = maxi(0, int(data.get("gold", 0)))
	var qd = data.get("quests", {})
	quests = qd if typeof(qd) == TYPE_DICTIONARY else {}
	active_chapter = clampi(int(data.get("active_chapter", 0)), 0, maxi(0, GameData.chapters.size() - 1))
	cleared_stages = []
	var cs = data.get("cleared_stages", [])
	if typeof(cs) == TYPE_ARRAY:
		for sid in cs:
			cleared_stages.append(str(sid))
	var fl = data.get("flags", {})
	flags = fl if typeof(fl) == TYPE_DICTIONARY else {}
	current_stage = {}
	pending_dialogue = ""
	current_encounter = []
	if party.is_empty():
		if storage.is_empty():
			return false
		party.append(storage.pop_front())
	return true


func _load_spirits(arr) -> Array:
	var result := []
	if typeof(arr) != TYPE_ARRAY:
		return result
	for d in arr:
		if typeof(d) == TYPE_DICTIONARY and GameData.species.has(str(d.get("species", ""))):
			result.append(Spirit.from_dict(d))
	return result


func heal_all() -> void:
	if summoner != null:
		summoner.full_heal()
	for s in party:
		s.full_heal()
	for s in storage:
		s.full_heal()


## 정령사와 계약 정령의 평균 레벨 (야생 정령 레벨 기준)
func average_party_level() -> int:
	var total := 0
	var count := 0
	if summoner != null:
		total += summoner.level
		count += 1
	for s in party:
		total += int(s.level)
		count += 1
	if count == 0:
		return 1
	return maxi(1, int(round(float(total) / count)))


## 선봉(전투 시작 시 자동 소환)으로 지정
func set_vanguard(s: Spirit) -> void:
	if party.has(s):
		party.erase(s)
		party.push_front(s)


## 계약한 정령을 보관함에 넣는다.
func add_captured(s: Spirit) -> String:
	quest_event("capture", s.element())
	s.full_heal()
	party.append(s)
	return "보관함에 들어감"


func equip(s: Spirit, eid: String) -> void:
	if not inventory.has(eid) or not GameData.equipment.has(eid):
		return
	var slot := str(GameData.equipment[eid]["slot"])
	unequip(s, slot)
	inventory.erase(eid)
	s.equipment[slot] = eid
	s.clamp_vitals()


func unequip(s: Spirit, slot: String) -> void:
	var current := str(s.equipment.get(slot, ""))
	if current != "":
		inventory.append(current)
	s.equipment[slot] = ""
	s.clamp_vitals()


func make_encounter() -> Array:
	var avg := average_party_level()
	var count := 2 + randi() % 2
	if battles_won >= 3:
		count += 1
	count = mini(count, 4)
	var pool := GameData.wild_pool()
	var enemies := []
	for i in count:
		var lv := maxi(1, avg + randi_range(-1, 1))
		enemies.append(Spirit.create(str(pool[randi() % pool.size()]), lv))
	return enemies


## 적 정령사: 평균 레벨 +1, 계약 정령 2~4마리 (첫 정령은 같은 속성 = 선봉)
func make_rival() -> Dictionary:
	var avg := average_party_level()
	var elements: Array = GameData.ELEMENT_NAMES.keys()
	var el := str(elements.pick_random())
	var m := Summoner.create_summoner(str(RIVAL_NAMES.pick_random()), el, avg + 1)
	var pool := GameData.wild_pool()
	var same: Array = pool.filter(func(sid): return GameData.species[sid]["element"] == el)
	var spirits := [Spirit.create(str(same.pick_random()), avg)]
	var count := mini(4, 2 + floori(battles_won / 3.0))
	for i in count - 1:
		spirits.append(Spirit.create(str(pool.pick_random()), maxi(1, avg + randi_range(-1, 1))))
	return {"summoner": m, "party": spirits}


## kind: "wild" = 야생 정령 무리, "rival" = 적 정령사와 대결
func start_battle(kind: String = "wild") -> void:
	current_stage = {}
	current_encounter = []
	current_rival = {}
	if kind == "rival":
		current_rival = make_rival()
	else:
		current_encounter = make_encounter()
	heal_all()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


# ================================================================ 스토리 (챕터 1)

func home_element() -> String:
	return summoner.element_id if summoner != null else "fire"


func rival_element() -> String:
	return str(NEUTRAL_OF.get(home_element(), "water"))


## 시작 속성이 강한 속성 (첫 스테이지에서 '상성 유리'를 보여 주는 상대)
func prey_element() -> String:
	return str(GameData.STRONG_AGAINST.get(home_element(), "grass"))


## 시작 속성에 강한 속성 (회색 결사가 쓰는 속성)
func strong_element() -> String:
	for el in GameData.STRONG_AGAINST:
		if GameData.STRONG_AGAINST[el] == home_element():
			return str(el)
	return "wind"


# ---------------------------------------------------------------- 챕터·지도 지점

func chapter_data(ci: int) -> Dictionary:
	if ci < 0 or ci >= GameData.chapters.size():
		return {}
	return GameData.chapters[ci]


func chapter_nodes(ci: int) -> Array:
	return chapter_data(ci).get("nodes", [])


## 챕터 지역의 속성: 1장 = 고향, 2장 = 다음 지역(라이벌 속성), 그 뒤는 데이터의 "region"
func chapter_element(ci: int) -> String:
	match str(chapter_data(ci).get("region", "home" if ci == 0 else "next")):
		"home":
			return home_element()
		"next":
			return rival_element()
		"strong":
			return strong_element()
		"prey":
			return prey_element()
	return home_element()


func region_element() -> String:
	return chapter_element(active_chapter)


func chapter_region_name(ci: int) -> String:
	return str(GameData.chapter1.get("regions", {}).get(chapter_element(ci), "???"))


func is_cleared(stage_id: String) -> bool:
	return cleared_stages.has(stage_id)


## 지점이 열렸는가: 챕터 첫 지점이거나, 이 지점으로 이어진 지점 중 하나를 지나왔으면 열림
func node_unlocked(ci: int, node: Dictionary) -> bool:
	if not chapter_unlocked(ci):
		return false
	var nodes := chapter_nodes(ci)
	if nodes.is_empty() or str(nodes[0]["id"]) == str(node["id"]):
		return true
	for o in nodes:
		var n: Dictionary = o
		if is_cleared(str(n["id"])) and (n.get("links", []) as Array).has(str(node["id"])):
			return true
	return false


func chapter_complete(ci: int) -> bool:
	for o in chapter_nodes(ci):
		var n: Dictionary = o
		if bool(n.get("goal", false)):
			return is_cleared(str(n["id"]))
	return false


func chapter_unlocked(ci: int) -> bool:
	return ci == 0 or (ci < GameData.chapters.size() and chapter_complete(ci - 1))


## 이벤트·상점·마을 지점을 지나간 것으로 기록
func mark_visited(node_id: String) -> void:
	if not cleared_stages.has(node_id):
		cleared_stages.append(node_id)
	save_game()


# ---------------------------------------------------------------- 마을 의뢰

## 데이터의 의뢰 목록 (마을 지점의 "quests")
func quest_defs(node: Dictionary) -> Array:
	return node.get("quests", [])


func quest_state(qid: String) -> String:
	if not quests.has(qid):
		return ""
	return str((quests[qid] as Dictionary).get("state", ""))


func accept_quest(q: Dictionary) -> void:
	var qid := str(q["id"])
	if quests.has(qid):
		return
	quests[qid] = {"state": "active", "progress": 0, "el": resolve_element(str(q.get("element", "")))}
	save_game()


## 진행도 (0 ~ 목표). 지점 의뢰는 그 지점을 지나왔는지로 판단
func quest_progress(q: Dictionary) -> int:
	var qid := str(q["id"])
	if str(q.get("type", "")) == "clear":
		return 1 if is_cleared(str(q.get("target", ""))) else 0
	if not quests.has(qid):
		return 0
	return int((quests[qid] as Dictionary).get("progress", 0))


func quest_goal(q: Dictionary) -> int:
	return 1 if str(q.get("type", "")) == "clear" else int(q.get("count", 1))


func quest_ready(q: Dictionary) -> bool:
	return quest_state(str(q["id"])) == "active" and quest_progress(q) >= quest_goal(q)


## 계약(capture)·퇴치(defeat) 이벤트로 진행 중인 의뢰를 채운다
func quest_event(kind: String, el: String) -> void:
	for ci in GameData.chapters.size():
		for o in chapter_nodes(ci):
			for qo in quest_defs(o):
				var q: Dictionary = qo
				var qid := str(q["id"])
				if quest_state(qid) != "active" or str(q.get("type", "")) != kind:
					continue
				var st: Dictionary = quests[qid]
				var want := str(st.get("el", ""))
				if want == "" or want == el:
					st["progress"] = mini(quest_goal(q), int(st.get("progress", 0)) + 1)


## 보상 받기. 받은 보상 줄 목록을 반환 (골드는 "@gold:" 줄)
func claim_quest(q: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if not quest_ready(q):
		return lines
	(quests[str(q["id"])] as Dictionary)["state"] = "claimed"
	var rw: Dictionary = q.get("reward", {})
	if int(rw.get("gold", 0)) > 0:
		gold += int(rw["gold"])
		lines.append("@gold:%d:의뢰 보상" % int(rw["gold"]))
	for item in rw.get("items", []):
		if GameData.equipment.has(str(item)):
			inventory.append(str(item))
			lines.append("의뢰 보상: %s" % GameData.equipment_desc(str(item)))
	save_game()
	return lines


## 의뢰 글의 {el}(속성 이름) 치환
func quest_text(q: Dictionary, key: String) -> String:
	var qid := str(q["id"])
	var el := str((quests[qid] as Dictionary).get("el", "")) if quests.has(qid) else resolve_element(str(q.get("element", "")))
	return fill_text(str(q.get(key, ""))).replace("{el}", GameData.element_name(el) if el != "" else "")


## 진행 중인 의뢰 요약 (지도 패널용)
func active_quest_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for ci in GameData.chapters.size():
		for o in chapter_nodes(ci):
			for qo in quest_defs(o):
				var q: Dictionary = qo
				if quest_state(str(q["id"])) == "active":
					var mark := " (보고 가능!)" if quest_ready(q) else ""
					out.append("%s %d/%d%s" % [quest_text(q, "title"), quest_progress(q), quest_goal(q), mark])
	return out


## 전투 승리 골드: 기본 + 쓰러뜨리거나 계약한 정령 레벨 합 × 3
func battle_gold(levels_total: int) -> int:
	return 10 + levels_total * 3


## 대화·이름 속 {player} {rival} {home} {guardian} {next} 치환
func fill_text(text: String) -> String:
	var ch: Dictionary = GameData.chapter1
	var guardian_id := str(GUARDIANS.get(home_element(), ""))
	var guardian_name := str(GameData.species[guardian_id]["name"]) if GameData.species.has(guardian_id) else "수호 정령"
	return text.replace("{player}", summoner.display_name() if summoner != null else DEFAULT_NAME) \
		.replace("{rival}", str(ch.get("rival_name", "세라"))) \
		.replace("{home}", str(ch.get("regions", {}).get(home_element(), "고향"))) \
		.replace("{next}", str(ch.get("next_regions", {}).get(home_element(), "새로운"))) \
		.replace("{guardian}", guardian_name) \
		.replace("{region}", chapter_region_name(active_chapter)) \
		.replace("{reg_guardian}", _species_name(str(GUARDIANS.get(region_element(), ""))))


func _species_name(sid: String) -> String:
	return str(GameData.species[sid]["name"]) if GameData.species.has(sid) else "수호 정령"


## 대화 화자(치환 전 원문: "{player}", "{rival}", "{guardian}", "촌장" …)의 초상화 키.
## 초상화가 없으면 "" → 대화창은 이름만 표시한다.
func speaker_portrait_key(raw_speaker: String) -> String:
	match raw_speaker:
		"":
			return ""
		"{player}":
			return "summoner_%s" % home_element()
		"{rival}":
			return "summoner_%s" % rival_element()
		"{guardian}":
			return str(GUARDIANS.get(home_element(), ""))
		"{reg_guardian}":
			return str(GUARDIANS.get(region_element(), ""))
	var table: Dictionary = GameData.speaker_portrait_table()
	return resolve_portrait(str(table.get(raw_speaker, "")))


## 초상화 표식: "@summoner_reg" = 그 지역 속성 정령사, "@harin_reg" = 그 지역 속성 하린
func resolve_portrait(key: String) -> String:
	match key:
		"@summoner_reg":
			return "summoner_%s" % region_element()
		"@harin_reg":
			return "npc_harin_%s" % region_element()
	return key


func home_region_name() -> String:
	return fill_text("{home}")


## "@home_a" 같은 표식을 실제 정령 id로 바꾼다.
func resolve_species(token: String) -> String:
	match token:
		"@home_a":
			return str(FAMILIES[home_element()][0])
		"@home_b":
			return str(FAMILIES[home_element()][1])
		"@rival_a":
			return str(FAMILIES[rival_element()][0])
		"@rival_b":
			return str(FAMILIES[rival_element()][1])
		"@reg_a":
			return str(FAMILIES[region_element()][0])
		"@reg_b":
			return str(FAMILIES[region_element()][1])
		"@reg_guardian":
			return str(GUARDIANS[region_element()])
		"@prey_a":
			return str(FAMILIES[prey_element()][0])
		"@prey_b":
			return str(FAMILIES[prey_element()][1])
		"@strong_a":
			return str(FAMILIES[strong_element()][0])
		"@strong_b":
			return str(FAMILIES[strong_element()][1])
		"@guardian":
			return str(GUARDIANS[home_element()])
		"@any":
			var pool := GameData.wild_pool()
			return str(pool[randi() % pool.size()])
	return token


func resolve_element(token: String) -> String:
	match token:
		"@home":
			return home_element()
		"@rival":
			return rival_element()
		"@strong":
			return strong_element()
		"@prey":
			return prey_element()
		"@reg":
			return region_element()
	return token


## 월드맵 미리보기용 적 구성 설명
func describe_stage_enemies(stage: Dictionary) -> String:
	var parts := PackedStringArray()
	if stage.has("guardian"):
		var gid := resolve_species(str(stage["guardian"]["species"]))
		parts.append("수호 정령 %s Lv.%d" % [GameData.species[gid]["name"], int(stage["guardian"]["level"])])
	var sm = stage.get("summoner", null)
	if typeof(sm) == TYPE_DICTIONARY:
		var nm := str(sm["name"])
		nm = fill_text("{rival}") if nm == "@rival" else nm
		parts.append("정령사 %s (%s) + 정령 %d" % [nm, GameData.element_name(resolve_element(str(sm["element"]))), (sm["party"] as Array).size()])
	var wild := 0
	for e in stage.get("enemies", []):
		wild += 1
	if wild > 0:
		parts.append("야생 정령 %d" % wild)
	return " · ".join(parts)


## 월드맵 미리보기용 적 초상화 목록: [{"key": 초상화 키 ("" = 무작위 정령), "boss": bool}]
## 수호 정령 → 적 정령사 → 정령사의 정령 → 야생 정령 순. 무작위(@any)는 key ""로 둔다.
func stage_preview(stage: Dictionary) -> Array:
	var out := []
	if stage.has("guardian"):
		out.append({"key": resolve_species(str(stage["guardian"]["species"])), "boss": true})
	var sm = stage.get("summoner", null)
	if typeof(sm) == TYPE_DICTIONARY:
		var pkey := resolve_portrait(str(sm.get("portrait", "")))
		out.append({"key": pkey if pkey != "" else "summoner_%s" % resolve_element(str(sm["element"])), "boss": true})
		for e in sm["party"]:
			out.append({"key": _preview_species(str(e["species"])), "boss": false})
	for e in stage.get("enemies", []):
		out.append({"key": _preview_species(str(e["species"])), "boss": false})
	return out


func _preview_species(token: String) -> String:
	return "" if token == "@any" else resolve_species(token)


## 스테이지 전투 시작: 적 구성을 만들어 전투 씬으로
func start_stage(stage: Dictionary) -> void:
	current_encounter = []
	current_rival = {}
	for e in stage.get("enemies", []):
		current_encounter.append(Spirit.create(resolve_species(str(e["species"])), int(e["level"])))
	var sm = stage.get("summoner", null)
	if typeof(sm) == TYPE_DICTIONARY:
		var nm := str(sm["name"])
		if nm == "@rival":
			nm = fill_text("{rival}")
		var m := Summoner.create_summoner(nm, resolve_element(str(sm["element"])), int(sm["level"]))
		var party_list := []
		for e in sm["party"]:
			party_list.append(Spirit.create(resolve_species(str(e["species"])), int(e["level"])))
		current_rival = {"summoner": m, "party": party_list}
	var guardian = null
	if stage.has("guardian"):
		guardian = Spirit.create(resolve_species(str(stage["guardian"]["species"])), int(stage["guardian"]["level"]))
	current_stage = {"id": str(stage["id"]), "name": str(stage["name"]), "guardian": guardian,
		"terrain": stage.get("terrain", {}), "enemy_cells": [], "script": []}
	for e in stage.get("enemies", []):
		var cell = e.get("cell", null)
		current_stage["enemy_cells"].append(Vector2i(int(cell[0]), int(cell[1])) if typeof(cell) == TYPE_ARRAY else Vector2i(-1, -1))
	# 고정 튜토리얼 스크립트는 처음 깰 때만
	if not is_cleared(str(stage["id"])):
		current_stage["script"] = stage.get("script", [])
	heal_all()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


## 스테이지 클리어 처리. 첫 클리어면 보상. 보상 메시지 반환.
func complete_stage(stage_id: String) -> Array[String]:
	var lines: Array[String] = []
	var found := GameData.find_node(stage_id)
	if found.is_empty():
		# 이벤트 속 전투 등: 지점으로만 기록
		if not is_cleared(stage_id):
			cleared_stages.append(stage_id)
		save_game()
		return lines
	var stage: Dictionary = found["node"]
	if not is_cleared(stage_id):
		cleared_stages.append(stage_id)
		lines.append("스테이지 %s 첫 클리어!" % stage_id)
		var rw: Dictionary = stage.get("rewards", {})
		for item in rw.get("items", []):
			if GameData.equipment.has(str(item)):
				inventory.append(str(item))
				lines.append("클리어 보상: %s" % GameData.equipment_desc(str(item)))
		if int(rw.get("gold", 0)) > 0:
			gold += int(rw["gold"])
			lines.append("@gold:%d:첫 클리어 보상" % int(rw["gold"]))
		pending_dialogue = str(stage.get("dialogue_post", ""))
	save_game()
	return lines
