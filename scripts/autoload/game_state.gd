extends Node
## 진행 상태(파티, 보관함, 인벤토리)와 저장/불러오기.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const MAX_PARTY := 4
const STARTERS := ["emberbean", "dewdrop", "pebble", "breezebird"]
const STARTER_LEVEL := 3

var party: Array = []      # Spirit
var storage: Array = []    # Spirit
var inventory: Array = []  # 장착하지 않은 장비 id
var battles_won: int = 0
var current_encounter: Array = []  # 다음 전투에 나올 야생 정령 (Spirit)


func new_game(starter: String) -> void:
	party = [Spirit.create(starter, STARTER_LEVEL)]
	storage = []
	inventory = ["wood_wand", "leaf_charm"]
	battles_won = 0
	current_encounter = []
	save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"party": party.map(func(s): return s.to_dict()),
		"storage": storage.map(func(s): return s.to_dict()),
		"inventory": inventory,
		"battles_won": battles_won,
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
	party = _load_spirits(data.get("party", []))
	storage = _load_spirits(data.get("storage", []))
	inventory = []
	var inv = data.get("inventory", [])
	if typeof(inv) == TYPE_ARRAY:
		for e in inv:
			if GameData.equipment.has(str(e)):
				inventory.append(str(e))
	battles_won = int(data.get("battles_won", 0))
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
	for s in party:
		s.full_heal()
	for s in storage:
		s.full_heal()


func average_party_level() -> int:
	if party.is_empty():
		return 1
	var total := 0
	for s in party:
		total += int(s.level)
	return maxi(1, int(round(float(total) / party.size())))


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


func start_battle() -> void:
	current_encounter = make_encounter()
	heal_all()
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
