extends Node
## 정적 게임 데이터(정령/스킬/장비)와 속성 상성, 공용 테마를 관리한다.

const ELEMENT_NAMES := {"fire": "불", "water": "물", "grass": "풀", "wind": "바람"}
const ELEMENT_COLORS := {
	"fire": Color(0.92, 0.38, 0.25),
	"water": Color(0.25, 0.55, 0.95),
	"grass": Color(0.38, 0.78, 0.32),
	"wind": Color(0.72, 0.9, 0.95),
}
## key 속성이 value 속성에 강하다: 바람 > 불 > 풀 > 물 > 바람
const STRONG_AGAINST := {"wind": "fire", "fire": "grass", "grass": "water", "water": "wind"}
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
var chapter1: Dictionary = {}
## 챕터 목록 (chapter1, chapter2 …). 각 챕터에 "nodes"(지도 지점) 배열이 있다.
## chapter1의 stages는 한 줄로 이어진 전투 지점으로 자동 변환한다.
var chapters: Array = []

var ui_font: Font
var _sprite_cache: Dictionary = {}
var theme: Theme


func _ready() -> void:
	species = _load_json("res://data/spirits.json")
	skills = _load_json("res://data/skills.json")
	equipment = _load_json("res://data/equipment.json")
	terrains = _load_json("res://data/terrain.json")
	summoner_data = _load_json("res://data/summoner.json")
	summoner_skills = _load_json("res://data/summoner_skills.json")
	chapter1 = _load_json("res://data/chapter1.json")
	_setup_chapters()
	_setup_theme()


func _setup_chapters() -> void:
	chapters = [chapter1]
	var ch2 := _load_json("res://data/chapter2.json")
	if not ch2.is_empty():
		chapters.append(ch2)
	# 1장: stages → nodes (일직선)
	var nodes: Array = []
	var stages: Array = chapter1.get("stages", [])
	for i in stages.size():
		var st: Dictionary = (stages[i] as Dictionary).duplicate()
		st["type"] = "boss" if st.has("guardian") else "battle"
		st["pos"] = st.get("map_pos", [0.5, 0.5])
		st["links"] = [str(stages[i + 1]["id"])] if i + 1 < stages.size() else []
		if i == stages.size() - 1:
			st["goal"] = true
		nodes.append(st)
	chapter1["nodes"] = nodes


## 모든 챕터에서 지점 찾기. {"node": Dictionary, "chapter": 번호}, 없으면 빈 딕셔너리.
func find_node(node_id: String) -> Dictionary:
	for ci in chapters.size():
		for n in (chapters[ci] as Dictionary).get("nodes", []):
			if str(n["id"]) == node_id:
				return {"node": n, "chapter": ci}
	return {}


## 대화 (모든 챕터의 dialogues에서 찾음)
func dialogue(key: String) -> Array:
	for ch in chapters:
		var all: Dictionary = (ch as Dictionary).get("dialogues", {})
		if all.has(key):
			return all[key]
	return []


## 전투 중 튜토리얼 (모든 챕터 합침)
func tutorials_for(stage_id: String) -> Array:
	var result: Array = []
	for ch in chapters:
		var all: Dictionary = (ch as Dictionary).get("tutorials", {})
		result.append_array(all.get(stage_id, []))
	result.append_array(chapter1.get("tutorials", {}).get("*", []))
	return result


func speaker_portrait_table() -> Dictionary:
	var table := {}
	for ch in chapters:
		table.merge((ch as Dictionary).get("speaker_portraits", {}), true)
	return table


## 장비 가격 (equipment.json의 price, 없으면 능력치로 계산)
func equipment_price(eid: String) -> int:
	if not equipment.has(eid):
		return 0
	var e: Dictionary = equipment[eid]
	if e.has("price"):
		return int(e["price"])
	var weights := {"hp": 4, "mp": 5, "atk": 16, "def": 15, "spd": 12, "mov": 70}
	var total := 20
	for k in e.get("bonus", {}):
		total += int(weights.get(k, 10)) * int(e["bonus"][k])
	return int(round(total / 10.0)) * 10


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


## 전투용 도트 스프라이트 (assets/sprites). 없으면 null → 도형으로 대신 그린다.
func sprite_for(s: Spirit) -> Texture2D:
	var path := ""
	if s is Summoner:
		path = "res://assets/sprites/summoner_%s.png" % s.element()
	else:
		path = "res://assets/sprites/spirits/%s.png" % s.species_id
	if _sprite_cache.has(path):
		return _sprite_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sprite_cache[path] = tex
	return tex


## 초상화: assets/portraits/<종족>.png(2D 일러스트)가 있으면 그것, 없으면 도트 스프라이트
func portrait_for(s: Spirit) -> Texture2D:
	var path := _portrait_path(s)
	if ResourceLoader.exists(path):
		return load(path)
	return sprite_for(s)


## assets/portraits/<key>.png 를 바로 불러온다 (NPC·정령사 등). 없으면 null.
func portrait_by_key(key: String) -> Texture2D:
	if key == "":
		return null
	var path := "res://assets/portraits/%s.png" % key
	if _sprite_cache.has(path):
		return _sprite_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sprite_cache[path] = tex
	return tex


## UI 아이콘 (assets/ui/<name>.png). 없으면 null.
func ui_tex(name: String) -> Texture2D:
	var path := "res://assets/ui/%s.png" % name
	if _sprite_cache.has(path):
		return _sprite_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sprite_cache[path] = tex
	return tex


## 전투 배경·지형 타일 (assets/battle/<name>.png). 없으면 null.
func battle_tex(name: String) -> Texture2D:
	var path := "res://assets/battle/%s.png" % name
	if _sprite_cache.has(path):
		return _sprite_cache[path]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_sprite_cache[path] = tex
	return tex


func has_illustration(s: Spirit) -> bool:
	return ResourceLoader.exists(_portrait_path(s))


func _portrait_path(s: Spirit) -> String:
	if s is Summoner:
		return "res://assets/portraits/summoner_%s.png" % s.element()
	return "res://assets/portraits/%s.png" % s.species_id


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


## 속성 지형 규칙: 숲=풀, 물가=물, 용암=불, 모래밭=바람.
## 자기 속성 지형이면 이동 1·공격 ×1.2·받는 피해 ×0.8, 다른 속성이면 이동 2·공격 ×0.8·받는 피해 ×1.2
const TERRAIN_OWN_ATK := 1.2
const TERRAIN_OTHER_ATK := 0.8
const TERRAIN_OWN_DEF := 0.8
const TERRAIN_OTHER_DEF := 1.2


func terrain_element(tid: String) -> String:
	return str(terrain_info(tid).get("element", ""))


## 이 지형이 정령 속성 el에게 유리(1)/불리(-1)/상관없음(0)
func terrain_affinity(tid: String, el: String) -> int:
	var te := terrain_element(tid)
	if te == "":
		return 0
	return 1 if te == el else -1


## 이 지형 칸에 들어갈 때 드는 이동력
func terrain_move_cost(tid: String, el: String) -> int:
	if not terrain_passable(tid):
		return 99
	match terrain_affinity(tid, el):
		1:
			return 1
		-1:
			return 2
	return int(terrain_info(tid).get("move", 1))


## 이 지형 위에서 공격할 때 피해 배율 (공격자 속성 기준)
func terrain_attack_mult(tid: String, el: String) -> float:
	match terrain_affinity(tid, el):
		1:
			return TERRAIN_OWN_ATK
		-1:
			return TERRAIN_OTHER_ATK
	return 1.0


## 이 지형 위에서 공격받을 때 피해 배율 (방어자 속성 기준)
func terrain_defense_mult(tid: String, el: String) -> float:
	match terrain_affinity(tid, el):
		1:
			return TERRAIN_OWN_DEF
		-1:
			return TERRAIN_OTHER_DEF
	return 1.0


## 칸 정보에 쓰는 한 줄 설명
func terrain_effect_text(tid: String) -> String:
	var te := terrain_element(tid)
	if te == "":
		return str(terrain_info(tid).get("desc", ""))
	var n := element_name(te)
	return "%s 속성 지형 — %s 정령: 이동↑ 공격↑ 방어↑ / 그 외: 이동↓ 공격↓ 방어↓" % [n, n]


## 원거리 사거리 보너스 (속성 지형 규칙으로 바뀌면서 없음)
func terrain_range_bonus(_tid: String) -> int:
	return 0


## 라운드 시작 시 최대 HP 대비 회복(+) 비율 — 마법진만
func terrain_round_hp(tid: String, _el: String) -> float:
	return float(terrain_info(tid).get("regen_all", 0.0))


## 라운드 시작 시 최대 MP 대비 회복 비율 (마법진)
func terrain_round_mp(tid: String) -> float:
	return float(terrain_info(tid).get("mp_regen_all", 0.0))


## "바람 ▶ 불 ▶ 풀 ▶ 물 ▶ 바람" (속성 색 BBCode)
func element_chart_bbcode() -> String:
	var parts := PackedStringArray()
	for el in ["wind", "fire", "grass", "water", "wind"]:
		parts.append("[color=#%s]%s[/color]" % [element_color(el).lightened(0.3).to_html(false), element_name(el)])
	return " ▶ ".join(parts)


func element_chart_text() -> String:
	return "바람 ▶ 불 ▶ 풀 ▶ 물 ▶ 바람 (▶ 방향으로 공격하면 1.5배, 반대는 0.75배)"


func equipment_desc(eid: String) -> String:
	if not equipment.has(eid):
		return "없음"
	var e: Dictionary = equipment[eid]
	return "%s (%s)" % [e["name"], bonus_text(e["bonus"])]
