class_name Spirit
extends RefCounted
## 플레이어/야생 정령 한 마리의 상태. 능력치는 종족 기본치 + 성장치 × (레벨-1) + 장비 보너스.

const STAT_KEYS := ["hp", "mp", "atk", "def", "spd", "mov"]
const STAT_NAMES := {"hp": "체력", "mp": "마력", "atk": "공격", "def": "방어", "spd": "속도", "mov": "이동"}
## 공격 탭 = 기본 공격 + 스킬 최대 2개
const MAX_ATTACK_SKILLS := 2
## 진화 레벨 + 이만큼 올렸는데 진화하지 않았으면 히든 스킬
const HIDDEN_SKILL_GAP := 5

var species_id: String = ""
var nickname: String = ""
var level: int = 1
var xp: int = 0
var hp: int = 0
var mp: int = 0
## 소지창 3칸 (장비·도구 id, 빈 칸 ""). 장비는 능력치가 쌓이고, 도구는 전투 중에 쓴다
var items: Array = ["", "", ""]
## 친밀도 0~100: 자주 소환하면 오르고, 귀환·쓰러짐·폭주로 내린다. 높을수록 적의 디스펠에 강하다 (원작과 같음)
var affinity: int = 20


## 이 특수 효과(revive·bind) 장비를 들었는가 (여러 개여도 효과는 한 번)
func has_special(sp: String) -> bool:
	for o in items:
		if GameData.equipment.has(str(o)) and str(GameData.equipment[str(o)].get("special", "")) == sp:
			return true
	return false


## 든 도구 [칸 번호...]
func tool_slots() -> Array:
	var out := []
	for i in items.size():
		if GameData.item_kind(str(items[i])) == "tool":
			out.append(i)
	return out


func free_slot() -> int:
	for i in items.size():
		if str(items[i]) == "":
			return i
	return -1


## 옛 저장(무기·장신구 칸) 또는 새 저장(3칸 배열)을 읽는다
func load_items(d: Dictionary) -> void:
	items = ["", "", ""]
	var arr = d.get("items", null)
	if typeof(arr) == TYPE_ARRAY:
		for i in mini(arr.size(), GameData.HOLD_SLOTS):
			items[i] = str(arr[i]) if GameData.holdable(str(arr[i])) else ""
		return
	var eq = d.get("equipment", {})
	if typeof(eq) == TYPE_DICTIONARY:
		var i := 0
		for slot in ["weapon", "accessory"]:
			var eid := str(eq.get(slot, ""))
			if GameData.holdable(eid):
				items[i] = eid
				i += 1


func add_affinity(n: int) -> void:
	affinity = clampi(affinity + n, 0, 100)


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
	for o in items:
		var eid := str(o)
		if GameData.equipment.has(eid):
			value += float(GameData.equipment[eid].get("bonus", {}).get(key, 0))
	return int(round(value))


## HP·MP는 최대 99 (원작과 같음)
const VITAL_CAP := 99


func max_hp() -> int:
	return mini(VITAL_CAP, stat("hp"))


func max_mp() -> int:
	return mini(VITAL_CAP, stat("mp"))


## 소환 유지비: 소환해 둔 동안 매 라운드 정령사 MP에서 빠진다 (종족 데이터 "cost")
func upkeep() -> int:
	return int(species().get("cost", 1))


func full_heal() -> void:
	hp = max_hp()
	mp = max_mp()


func clamp_vitals() -> void:
	hp = clampi(hp, 0, max_hp())
	mp = clampi(mp, 0, max_mp())


func xp_to_next() -> int:
	return 8 + level * level * 4


## 공격 탭의 스킬 (최대 2개, 기본 공격은 따로). 진화 전 정령은 거의 기본 공격만 쓴다.
## 진화 레벨보다 HIDDEN_SKILL_GAP 이상 높은데도 진화하지 않았으면 히든 스킬이 생긴다.
func known_skills() -> Array[String]:
	var result: Array[String] = []
	for entry in species()["skills"]:
		if int(entry["level"]) <= level and result.size() < MAX_ATTACK_SKILLS:
			result.append(str(entry["id"]))
	var hidden := hidden_skill()
	if hidden != "" and has_hidden_skill() and not result.has(hidden):
		if result.size() >= MAX_ATTACK_SKILLS:
			result.pop_back()
		result.append(hidden)
	return result


## 이 종족의 히든 스킬 id (없으면 "")
func hidden_skill() -> String:
	var sid := str(species().get("hidden_skill", ""))
	return sid if GameData.skills.has(sid) else ""


## 히든 스킬이 생기는 레벨 (없으면 0)
func hidden_skill_level() -> int:
	var evo := next_evolution()
	if hidden_skill() == "" or evo.is_empty():
		return 0
	return int(evo["level"]) + HIDDEN_SKILL_GAP


func has_hidden_skill() -> bool:
	var lv := hidden_skill_level()
	return lv > 0 and level >= lv


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


func can_evolve() -> bool:
	var evo := next_evolution()
	return not evo.is_empty() and level >= int(evo["level"])


## 진화 조건을 만족하면 진화하고 메시지를 반환. 아니면 "". (거점에서 플레이어가 직접 진화시킨다)
func try_evolve() -> String:
	if not can_evolve():
		return ""
	var evo := next_evolution()
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
		full_heal()  # 레벨업하면 HP·MP 전부 회복 (원작과 같음)
		msgs.append("%s 레벨 %d 달성!" % [display_name(), level])
		var evo := next_evolution()
		if not evo.is_empty() and level == int(evo["level"]):
			msgs.append("%s이(가) 진화할 수 있다! (거점에서 진화)" % display_name())
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
		"items": items.duplicate(),
		"affinity": affinity,
	}


static func from_dict(d: Dictionary) -> Spirit:
	var s := Spirit.new()
	s.species_id = str(d.get("species", ""))
	s.nickname = str(d.get("nickname", ""))
	s.level = maxi(1, int(d.get("level", 1)))
	s.xp = maxi(0, int(d.get("xp", 0)))
	s.load_items(d)
	s.affinity = clampi(int(d.get("affinity", 20)), 0, 100)
	s.hp = int(d.get("hp", 0))
	s.mp = int(d.get("mp", 0))
	s.clamp_vitals()
	return s
