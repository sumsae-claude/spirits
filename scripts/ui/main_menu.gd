extends Control
## 타이틀 화면과 첫 정령 선택.

var _message := ""


func _ready() -> void:
	theme = GameData.theme
	_show_title()


func _show_title() -> void:
	UIKit.clear(self)
	var vb := UIKit.screen(self, 160, 80)
	vb.add_child(UIKit.label("정령계약자", 64, UIKit.GOLD, true))
	vb.add_child(UIKit.label("야생 정령을 디스펠하여 계약하고\n함께 성장하는 헥스 전략 RPG", 26, UIKit.MUTED, true))
	vb.add_child(UIKit.spacer())
	if _message != "":
		vb.add_child(UIKit.label(_message, 24, Color(1, 0.6, 0.5), true))
	vb.add_child(UIKit.button("새 게임", _on_new_game))
	vb.add_child(UIKit.button("이어하기", _on_continue, not GameState.has_save()))
	vb.add_child(UIKit.label("프로토타입 v0.1", 20, UIKit.MUTED, true))


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
	vb.add_child(UIKit.label("함께할 첫 정령을 고르세요", 40, UIKit.GOLD, true))
	var list := UIKit.scroll_list(vb)
	for sid in GameState.STARTERS:
		var sp: Dictionary = GameData.species[sid]
		var b := UIKit.button("%s   [%s 속성]" % [sp["name"], GameData.element_name(sp["element"])], func(): _choose(sid), false, 88)
		b.add_theme_color_override("font_color", GameData.element_color(sp["element"]).lightened(0.35))
		list.add_child(b)
		list.add_child(UIKit.label(str(sp["desc"]), 22, UIKit.MUTED))
	vb.add_child(UIKit.button("뒤로", _on_back))


func _on_back() -> void:
	_show_title.call_deferred()


func _choose(sid: String) -> void:
	GameState.new_game(sid)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
