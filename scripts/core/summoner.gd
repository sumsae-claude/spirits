class_name Summoner
extends Spirit
## 플레이어 정령사. 정령을 소환·귀환시키고 디스펠로 야생 정령과 계약한다.
## Spirit을 상속해 능력치/경험치/장비/저장 로직을 그대로 쓴다. (정령 스킬·진화 없음)
## 설정값은 data/summoner.json

var element_id: String = "fire"
## 보유한 정령사 스킬 id (data/summoner_skills.json). 지금은 레벨로 습득, 나중에 가챠 등으로 획득 예정.
var skill_ids: Array = []
var _species_cache: Dictionary = {}


static func create_summoner(p_name: String, p_element: String, p_level: int) -> Summoner:
	var s := Summoner.new()
	s.species_id = "summoner"
	s.nickname = p_name
	s.element_id = p_element
	s.level = maxi(1, p_level)
	s.learn_new_skills()
	s.full_heal()
	return s


## 레벨/속성 조건을 만족하는데 아직 없는 스킬을 배운다. 새로 배운 스킬 이름을 반환.
func learn_new_skills() -> Array[String]:
	var learned: Array[String] = []
	for sid in GameData.summoner_skills:
		var sk: Dictionary = GameData.summoner_skills[sid]
		var req := str(sk.get("element_req", ""))
		if req != "" and req != element_id:
			continue
		if int(sk.get("learn_level", 1)) <= level and not skill_ids.has(sid):
			skill_ids.append(sid)
			learned.append(str(sk["name"]))
	return learned


func gain_xp(amount: int) -> Array[String]:
	var msgs: Array[String] = super(amount)
	for skill_name in learn_new_skills():
		msgs.append("%s이(가) [%s]을(를) 익혔다!" % [display_name(), skill_name])
	return msgs


func skill_names() -> String:
	var names := PackedStringArray()
	for sid in skill_ids:
		names.append(str(GameData.summoner_skills[sid]["name"]))
	return ", ".join(names)


## Spirit의 종족 데이터 자리에 정령사 능력치를 넣어준다.
func species() -> Dictionary:
	if _species_cache.is_empty():
		var d: Dictionary = GameData.summoner_data
		_species_cache = {
			"name": "정령사",
			"element": element_id,
			"wild": false,
			"catch": 0.0,
			"desc": "%s의 정령사. 정령을 소환하고, 디스펠로 야생 정령과 계약한다." % GameData.element_name(element_id),
			"base": d.get("base", {}),
			"growth": d.get("growth", {}),
			"skills": [],
			"evolves_to": "",
			"evolve_level": 0,
		}
	return _species_cache


func _cfg(key: String) -> Variant:
	return GameData.summoner_data.get(key, {})


## 동시에 전장에 소환해 둘 수 있는 정령 수
func summon_limit() -> int:
	var cfg: Dictionary = _cfg("summon_limit")
	var per := maxf(1.0, float(cfg.get("per_levels", 5)))
	return mini(int(cfg.get("max", 4)), int(cfg.get("base", 2)) + floori(float(level) / per))


## 정령 하나를 소환하는 데 드는 MP. 같은 속성 정령은 할인.
func summon_cost(sp: Spirit) -> int:
	var cfg: Dictionary = _cfg("summon_cost")
	var cost := float(cfg.get("base", 4)) + float(cfg.get("per_level", 1)) * float(sp.level)
	if sp.element() == element_id:
		cost *= float(cfg.get("same_element", 0.7))
	return maxi(1, int(round(cost)))


func dispel_cost() -> int:
	return int(GameData.summoner_data.get("dispel_mp", 4))


func dispel_range() -> int:
	return int(GameData.summoner_data.get("dispel_range", 2))


func attack_power() -> int:
	return int(GameData.summoner_data.get("attack_power", 30))


func mp_regen() -> int:
	return int(GameData.summoner_data.get("mp_regen", 3))


func summary() -> String:
	return "%s  Lv.%d  [%s의 정령사]" % [display_name(), level, GameData.element_name(element_id)]


func to_dict() -> Dictionary:
	var d: Dictionary = super()
	d["element"] = element_id
	d["skills"] = skill_ids.duplicate()
	return d


static func from_summoner_dict(d: Dictionary) -> Summoner:
	var el := str(d.get("element", "fire"))
	if el == "earth":
		el = "grass"  # 흙 → 풀 변경 전 저장 데이터
	if not GameData.ELEMENT_NAMES.has(el):
		el = "fire"
	var s := Summoner.create_summoner(str(d.get("nickname", "리안")), el, int(d.get("level", 1)))
	s.xp = maxi(0, int(d.get("xp", 0)))
	var eq = d.get("equipment", {})
	if typeof(eq) == TYPE_DICTIONARY:
		for slot in GameData.SLOTS:
			var eid := str(eq.get(slot, ""))
			s.equipment[slot] = eid if GameData.equipment.has(eid) else ""
	var saved = d.get("skills", [])
	if typeof(saved) == TYPE_ARRAY:
		for sid in saved:
			if GameData.summoner_skills.has(str(sid)) and not s.skill_ids.has(str(sid)):
				s.skill_ids.append(str(sid))
	s.hp = int(d.get("hp", s.max_hp()))
	s.mp = int(d.get("mp", s.max_mp()))
	s.clamp_vitals()
	return s
