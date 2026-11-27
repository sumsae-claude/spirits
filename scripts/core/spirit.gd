class_name Spirit
extends RefCounted
## 플레이어/야생 정령 한 마리의 상태. 능력치는 종족 기본치 + 성장치 × (레벨-1) + 장비 보너스.

const STAT_KEYS := ["hp", "mp", "atk", "def", "spd", "mov"]
const STAT_NAMES := {"hp": "체력", "mp": "마력", "atk": "공격", "def": "방어", "spd": "속도", "mov": "이동"}

var species_id: String = ""
var nickname: String = ""
var level: int = 1
var xp: int = 0
var hp: int = 0
var mp: int = 0
var equipment: Dictionary = {"weapon": "", "accessory": ""}


static func create(p_species: String, p_level: int) -> Spirit:
	var s := Spirit.new()
	s.species_id = p_species
	s.level = maxi(1, p_level)
	# 진화 레벨을 넘긴 상태로 생성되면 바로 진화형으로
	while s.try_evolve() != "":
		pass
	s.full_heal()
	return s


func species() -> Dictionary:
	return GameData.species[species_id]


func element() -> String:
	return str(species()["element"])


func display_name() -> String:
	if nickname != "":
		return nickname
	return str(species()["name"])


func stat(key: String) -> int:
	var sp := species()
	var value: float = float(sp["base"].get(key, 0)) + float(sp["growth"].get(key, 0)) * float(level - 1)
	for slot in equipment:
		var eid: String = equipment[slot]
		if eid != "" and GameData.equipment.has(eid):
			value += float(GameData.equipment[eid]["bonus"].get(key, 0))
	return int(round(value))


func max_hp() -> int:
	return stat("hp")


func max_mp() -> int:
	return stat("mp")


func full_heal() -> void:
	hp = max_hp()
	mp = max_mp()


func clamp_vitals() -> void:
	hp = clampi(hp, 0, max_hp())
	mp = clampi(mp, 0, max_mp())


func xp_to_next() -> int:
	return 8 + level * level * 4


func known_skills() -> Array[String]:
	var result: Array[String] = []
	for entry in species()["skills"]:
		if int(entry["level"]) <= level:
			result.append(str(entry["id"]))
	return result


## 아직 배우지 않은 스킬: [{"id", "level"}]
func upcoming_skills() -> Array:
	var result := []
	for entry in species()["skills"]:
		if int(entry["level"]) > level:
			result.append({"id": str(entry["id"]), "level": int(entry["level"])})
	return result


## 다음 진화 정보. 없으면 빈 딕셔너리.
func next_evolution() -> Dictionary:
	var sp := species()
	var target := str(sp.get("evolves_to", ""))
	if target == "" or not GameData.species.has(target):
		return {}
	return {"species": target, "level": int(sp.get("evolve_level", 0))}


## 진화 조건을 만족하면 진화하고 메시지를 반환. 아니면 "".
func try_evolve() -> String:
	var evo := next_evolution()
	if evo.is_empty() or level < int(evo["level"]):
		return ""
	var old_name := display_name()
	var old_max_hp := max_hp()
	var old_max_mp := max_mp()
	species_id = str(evo["species"])
	hp += max_hp() - old_max_hp
	mp += max_mp() - old_max_mp
	clamp_vitals()
	return "%s이(가) %s(으)로 진화했다!" % [old_name, display_name()]


## 경험치 획득. 레벨업/진화/스킬 습득 메시지를 반환.
func gain_xp(amount: int) -> Array[String]:
	var msgs: Array[String] = []
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		var old_max_hp := max_hp()
		var old_max_mp := max_mp()
		var old_skills := known_skills()
		level += 1
		hp += max_hp() - old_max_hp
		mp += max_mp() - old_max_mp
		msgs.append("%s 레벨 %d 달성!" % [display_name(), level])
		var evo_msg := try_evolve()
		if evo_msg != "":
			msgs.append(evo_msg)
		for sid in known_skills():
			if not old_skills.has(sid):
				msgs.append("%s이(가) [%s]을(를) 배웠다!" % [display_name(), GameData.skills[sid]["name"]])
	clamp_vitals()
	return msgs


func summary() -> String:
	return "%s  Lv.%d  [%s]" % [display_name(), level, GameData.element_name(element())]


func to_dict() -> Dictionary:
	return {
		"species": species_id,
		"nickname": nickname,
		"level": level,
		"xp": xp,
		"hp": hp,
		"mp": mp,
		"equipment": equipment.duplicate(),
	}


static func from_dict(d: Dictionary) -> Spirit:
	var s := Spirit.new()
	s.species_id = str(d.get("species", ""))
	s.nickname = str(d.get("nickname", ""))
	s.level = maxi(1, int(d.get("level", 1)))
	s.xp = maxi(0, int(d.get("xp", 0)))
	var eq = d.get("equipment", {})
	if typeof(eq) == TYPE_DICTIONARY:
		for slot in GameData.SLOTS:
			var eid := str(eq.get(slot, ""))
			s.equipment[slot] = eid if GameData.equipment.has(eid) else ""
	s.hp = int(d.get("hp", 0))
	s.mp = int(d.get("mp", 0))
	s.clamp_vitals()
	return s
