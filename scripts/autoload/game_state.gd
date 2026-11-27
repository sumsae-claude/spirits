extends Node
## 진행 상태(정령사, 계약 정령, 보관함, 인벤토리)와 저장/불러오기.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
## 전투에 데려가 소환할 수 있는 계약 정령 수 (첫 번째가 선봉)
const MAX_PARTY := 6
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
var party: Array = []      # Spirit
var storage: Array = []    # Spirit
var inventory: Array = []  # 장착하지 않은 장비 id
var battles_won: int = 0
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
	current_encounter = []
	cleared_stages = []
	flags = {}
	current_stage = {}
	pending_dialogue = ""
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"summoner": summoner.to_dict() if summoner != null else {},
		"party": party.map(func(s): return s.to_dict()),
		"storage": storage.map(func(s): return s.to_dict()),
		"inventory": inventory,
		"battles_won": battles_won,
		"cleared_stages": cleared_stages,
		"flags": flags,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("저장 실패: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
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
	storage = _load_spirits(data.get("storage", []))
	inventory = []
	var inv = data.get("inventory", [])
	if typeof(inv) == TYPE_ARRAY:
		for e in inv:
			if GameData.equipment.has(str(e)):
				inventory.append(str(e))
	battles_won = int(data.get("battles_won", 0))
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


## 계약한 정령을 파티(빈자리 있을 때) 또는 보관함에 넣고 위치 이름을 반환.
func add_captured(s: Spirit) -> String:
	s.full_heal()
	if party.size() < MAX_PARTY:
		party.append(s)
		return "파티 합류"
	storage.append(s)
	return "보관함으로 이동"


func move_to_storage(s: Spirit) -> bool:
	if party.size() <= 1 or not party.has(s):
		return false
	party.erase(s)
	storage.append(s)
	return true


func move_to_party(s: Spirit) -> bool:
	if party.size() >= MAX_PARTY or not storage.has(s):
		return false
	storage.erase(s)
	party.append(s)
	return true


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


## 시작 속성에 강한 속성 (회색 결사가 쓰는 속성)
func strong_element() -> String:
	for el in GameData.STRONG_AGAINST:
		if GameData.STRONG_AGAINST[el] == home_element():
			return str(el)
	return "wind"


func chapter_stages() -> Array:
	return GameData.chapter1.get("stages", [])


func stage_index(stage_id: String) -> int:
	var stages := chapter_stages()
	for i in stages.size():
		if str(stages[i]["id"]) == stage_id:
			return i
	return -1


func is_cleared(stage_id: String) -> bool:
	return cleared_stages.has(stage_id)


func is_unlocked(index: int) -> bool:
	if index <= 0:
		return true
	var stages := chapter_stages()
	return index < stages.size() and is_cleared(str(stages[index - 1]["id"]))


func chapter_complete() -> bool:
	for st in chapter_stages():
		if not is_cleared(str(st["id"])):
			return false
	return true


## 대화·이름 속 {player} {rival} {home} {guardian} {next} 치환
func fill_text(text: String) -> String:
	var ch: Dictionary = GameData.chapter1
	var guardian_id := str(GUARDIANS.get(home_element(), ""))
	var guardian_name := str(GameData.species[guardian_id]["name"]) if GameData.species.has(guardian_id) else "수호 정령"
	return text.replace("{player}", summoner.display_name() if summoner != null else DEFAULT_NAME) \
		.replace("{rival}", str(ch.get("rival_name", "세라"))) \
		.replace("{home}", str(ch.get("regions", {}).get(home_element(), "고향"))) \
		.replace("{next}", str(ch.get("next_regions", {}).get(home_element(), "새로운"))) \
		.replace("{guardian}", guardian_name)


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
	var table: Dictionary = GameData.chapter1.get("speaker_portraits", {})
	return str(table.get(raw_speaker, ""))


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
		out.append({"key": "summoner_%s" % resolve_element(str(sm["element"])), "boss": true})
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
	current_stage = {"id": str(stage["id"]), "name": str(stage["name"]), "guardian": guardian}
	heal_all()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


## 스테이지 클리어 처리. 첫 클리어면 보상. 보상 메시지 반환.
func complete_stage(stage_id: String) -> Array[String]:
	var lines: Array[String] = []
	var idx := stage_index(stage_id)
	if idx < 0:
		return lines
	var stage: Dictionary = chapter_stages()[idx]
	if not is_cleared(stage_id):
		cleared_stages.append(stage_id)
		lines.append("스테이지 %s 첫 클리어!" % stage_id)
		for item in stage.get("rewards", {}).get("items", []):
			if GameData.equipment.has(str(item)):
				inventory.append(str(item))
				lines.append("클리어 보상: %s" % GameData.equipment_desc(str(item)))
		pending_dialogue = str(stage.get("dialogue_post", ""))
	save_game()
	return lines
