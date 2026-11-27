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

var ui_font: Font
var theme: Theme


func _ready() -> void:
	species = _load_json("res://data/spirits.json")
	skills = _load_json("res://data/skills.json")
	equipment = _load_json("res://data/equipment.json")
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


func equipment_desc(eid: String) -> String:
	if not equipment.has(eid):
		return "없음"
	var e: Dictionary = equipment[eid]
	return "%s (%s)" % [e["name"], bonus_text(e["bonus"])]
