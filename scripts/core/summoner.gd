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


## 공격 탭에 들어가는 정령사 공격 스킬 (속성 공격 스킬 중 첫 번째). 없으면 "".
func attack_skill_id() -> String:
	for o in skill_ids:
		var sid := str(o)
		if str(GameData.summoner_skills[sid].get("type", "")) == "attack":
			return sid
	return ""


## '스킬' 메뉴에 들어가는 나머지 정령사 스킬 (회복·버프·디버프 등)
func support_skill_ids() -> Array:
	var atk := attack_skill_id()
	var result := []
	for o in skill_ids:
		if str(o) != atk:
			result.append(str(o))
	return result


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
			"base": _scaled(d.get("base", {})),
			"growth": _scaled(d.get("growth", {})),
			"skills": [],
			"evolves_to": "",
			"evolve_level": 0,
		}
	return _species_cache


## 정령사 속성별 개성 (summoner.json profiles): 물 = 공격↓ 마력↑ 디스펠↑, 불 = 공격↑ 마력↓ 디스펠↓, 풀·바람 = 보통 + 동반자
func profile() -> Dictionary:
	return (GameData.summoner_data.get("profiles", {}) as Dictionary).get(element_id, {})


func _scaled(stats: Dictionary) -> Dictionary:
	var mult: Dictionary = profile().get("stat", {})
	var out := {}
	for k in stats:
		out[k] = float(stats[k]) * float(mult.get(k, 1.0))
	return out


## 정령사 공격(기본 공격·공격 마법) 위력 배율
func power_mult() -> float:
	return float(profile().get("power", 1.0))


## 디스펠 기본 성공률 (대상 HP·레벨·상성 보정 전)
func dispel_base() -> float:
	return float(profile().get("dispel_base", 0.15))


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
	return int(GameData.summoner_data.get("dispel_range", 3))


func attack_power() -> int:
	return int(round(float(GameData.summoner_data.get("attack_power", 30)) * power_mult()))


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
	s.load_items(d)
	var saved = d.get("skills", [])
	if typeof(saved) == TYPE_ARRAY:
		for sid in saved:
			if GameData.summoner_skills.has(str(sid)) and not s.skill_ids.has(str(sid)):
				s.skill_ids.append(str(sid))
	s.hp = int(d.get("hp", s.max_hp()))
	s.mp = int(d.get("mp", s.max_mp()))
	s.clamp_vitals()
	return s
