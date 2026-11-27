extends Node
## 정적 게임 데이터(정령/스킬/장비)와 속성 상성, 공용 테마를 관리한다.

const ELEMENT_NAMES := {"fire": "불", "water": "물", "earth": "흙", "wind": "바람"}
const ELEMENT_COLORS := {
	"fire": Color(0.92, 0.38, 0.25),
	"water": Color(0.25, 0.55, 0.95),
	"earth": Color(0.68, 0.52, 0.28),
	"wind": Color(0.35, 0.78, 0.5),
}
## key 속성이 value 속성에 강하다: 불 > 바람 > 흙 > 물 > 불
const STRONG_AGAINST := {"fire": "wind", "wind": "earth", "earth": "water", "water": "fire"}
const STRONG_MULT := 1.5
const WEAK_MULT := 0.75
const SLOT_NAMES := {"weapon": "무기", "accessory": "장신구"}
const SLOTS := ["weapon", "accessory"]

var species: Dictionary = {}
var skills: Dictionary = {}
var equipment: Dictionary = {}
var terrains: Dictionary = {}
var summoner_data: Dictionary = {}
var summoner_skills: Dictionary = {}

var ui_font: Font
var theme: Theme


func _ready() -> void:
	species = _load_json("res://data/spirits.json")
	skills = _load_json("res://data/skills.json")
	equipment = _load_json("res://data/equipment.json")
	terrains = _load_json("res://data/terrain.json")
	summoner_data = _load_json("res://data/summoner.json")
	summoner_skills = _load_json("res://data/summoner_skills.json")
	_setup_theme()


func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("데이터 파일을 열 수 없음: %s" % path)
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("JSON 파싱 실패: %s" % path)
		return {}
	return data


func _setup_theme() -> void:
	# 한글 표시를 위해 기기 시스템 폰트를 사용한다. (나중에 전용 폰트 파일로 교체 예정)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"Noto Sans CJK KR", "Noto Sans KR", "Malgun Gothic", "Apple SD Gothic Neo",
		"NanumGothic", "sans-serif",
	])
	ui_font = sf
	theme = Theme.new()
	theme.default_font = sf
	theme.default_font_size = 28
	ThemeDB.fallback_font = sf
	ThemeDB.fallback_font_size = 28
	get_tree().root.theme = theme


func element_multiplier(attack_element: String, defend_element: String) -> float:
	if STRONG_AGAINST.get(attack_element, "") == defend_element:
		return STRONG_MULT
	if STRONG_AGAINST.get(defend_element, "") == attack_element:
		return WEAK_MULT
	return 1.0


func element_name(el: String) -> String:
	return str(ELEMENT_NAMES.get(el, el))


func element_color(el: String) -> Color:
	return ELEMENT_COLORS.get(el, Color.GRAY)


## 야생에서 등장하는 (진화 전) 정령 목록
func wild_pool() -> Array:
	var result := []
	for sid in species:
		if bool(species[sid].get("wild", false)):
			result.append(sid)
	return result


func random_equipment(rng: RandomNumberGenerator) -> String:
	var keys := equipment.keys()
	return str(keys[rng.randi() % keys.size()])


func bonus_text(bonus: Dictionary) -> String:
	var parts := PackedStringArray()
	for key in Spirit.STAT_KEYS:
		if bonus.has(key):
			parts.append("%s+%d" % [Spirit.STAT_NAMES[key], int(bonus[key])])
	return " ".join(parts)


# ---------------------------------------------------------------- 지형

func terrain_info(tid: String) -> Dictionary:
	if terrains.has(tid):
		return terrains[tid]
	return terrains.get("plain", {})


func terrain_name(tid: String) -> String:
	return str(terrain_info(tid).get("name", tid))


func terrain_passable(tid: String) -> bool:
	return bool(terrain_info(tid).get("passable", true))


func terrain_color(tid: String) -> Color:
	var c = terrain_info(tid).get("color", [0.17, 0.2, 0.26])
	return Color(float(c[0]), float(c[1]), float(c[2]))


## 이 지형 칸에 들어갈 때 드는 이동력
func terrain_move_cost(tid: String, el: String) -> int:
	var t := terrain_info(tid)
	var by: Dictionary = t.get("move_by", {})
	return int(by.get(el, t.get("move", 1)))


## 이 지형 위에서 공격할 때 피해 배율 (공격자 속성 기준)
func terrain_attack_mult(tid: String, el: String) -> float:
	var by: Dictionary = terrain_info(tid).get("attack_by", {})
	return float(by.get(el, 1.0))


## 이 지형 위에서 공격받을 때 피해 배율
func terrain_defense_mult(tid: String) -> float:
	return float(terrain_info(tid).get("defense", 1.0))


## 원거리(최대 사거리 2 이상) 스킬 사거리 보너스
func terrain_range_bonus(tid: String) -> int:
	return int(terrain_info(tid).get("range_bonus", 0))


## 라운드 시작 시 최대 HP 대비 회복(+)/피해(-) 비율
func terrain_round_hp(tid: String, el: String) -> float:
	var t := terrain_info(tid)
	if t.has("regen_all"):
		return float(t["regen_all"])
	var regen: Dictionary = t.get("regen_by", {})
	if regen.has(el):
		return float(regen[el])
	return -float(t.get("burn", 0.0))


## 라운드 시작 시 최대 MP 대비 회복 비율 (마법진)
func terrain_round_mp(tid: String) -> float:
	return float(terrain_info(tid).get("mp_regen_all", 0.0))


## "불 ▶ 바람 ▶ 흙 ▶ 물 ▶ 불" (속성 색 BBCode)
func element_chart_bbcode() -> String:
	var parts := PackedStringArray()
	for el in ["fire", "wind", "earth", "water", "fire"]:
		parts.append("[color=#%s]%s[/color]" % [element_color(el).lightened(0.3).to_html(false), element_name(el)])
	return " ▶ ".join(parts)


func element_chart_text() -> String:
	return "불 ▶ 바람 ▶ 흙 ▶ 물 ▶ 불 (▶ 방향으로 공격하면 1.5배, 반대는 0.75배)"


func equipment_desc(eid: String) -> String:
	if not equipment.has(eid):
		return "없음"
	var e: Dictionary = equipment[eid]
	return "%s (%s)" % [e["name"], bonus_text(e["bonus"])]
