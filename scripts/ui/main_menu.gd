extends Control
## 타이틀 화면과 정령사 만들기.

var _message := ""
var _name_edit: LineEdit = null


func _ready() -> void:
	theme = GameData.theme
	_show_title()


func _show_title() -> void:
	UIKit.clear(self)
	var vb := UIKit.screen(self, 160, 80)
	vb.add_child(UIKit.label("정령계약자", 64, UIKit.GOLD, true))
	vb.add_child(UIKit.label("정령사가 되어 야생 정령을 디스펠로 계약하고\n소환해서 싸우는 헥스 전략 RPG", 26, UIKit.MUTED, true))
	vb.add_child(UIKit.spacer())
	if _message != "":
		vb.add_child(UIKit.label(_message, 24, Color(1, 0.6, 0.5), true))
	vb.add_child(UIKit.button("새 게임", _on_new_game))
	vb.add_child(UIKit.button("이어하기", _on_continue, not GameState.has_save()))
	vb.add_child(UIKit.label("프로토타입 v0.6", 20, UIKit.MUTED, true))


func _on_new_game() -> void:
	_show_starters.call_deferred()


func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file("res://scenes/hub.tscn")
	else:
		_message = "저장 데이터를 불러오지 못했습니다."
		_show_title.call_deferred()


func _show_starters() -> void:
	UIKit.clear(self)
	var vb := UIKit.screen(self, 80, 60)
	vb.add_child(UIKit.label("정령사 만들기", 40, UIKit.GOLD, true))
	vb.add_child(UIKit.label("이름", 26))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = GameState.DEFAULT_NAME
	_name_edit.max_length = 8
	_name_edit.custom_minimum_size = Vector2(0, 72)
	vb.add_child(_name_edit)
	vb.add_child(UIKit.label("속성 — 같은 속성의 정령은 적은 MP로 소환할 수 있습니다", 22, UIKit.MUTED))
	var list := UIKit.scroll_list(vb)
	for el in GameState.STARTERS:
		var sp: Dictionary = GameData.species[GameState.STARTERS[el]]
		var b := UIKit.button("%s의 정령사   (첫 정령: %s)" % [GameData.element_name(el), sp["name"]], func(): _choose(el), false, 88)
		b.add_theme_color_override("font_color", GameData.element_color(el).lightened(0.35))
		list.add_child(b)
		list.add_child(UIKit.label(str(sp["desc"]), 22, UIKit.MUTED))
	vb.add_child(UIKit.button("뒤로", _on_back))


func _on_back() -> void:
	_show_title.call_deferred()


func _choose(element: String) -> void:
	GameState.new_game(_name_edit.text if _name_edit != null else "", element)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
