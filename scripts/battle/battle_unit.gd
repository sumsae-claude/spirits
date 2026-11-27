class_name BattleUnit
extends RefCounted
## 전투 중인 정령 하나. team 0 = 아군, 1 = 야생.

var spirit: Spirit
var team: int
var cell: Vector2i
var draw_pos: Vector2
var alive := true
var captured := false


func _init(p_spirit: Spirit, p_team: int, p_cell: Vector2i) -> void:
	spirit = p_spirit
	team = p_team
	cell = p_cell


func is_active() -> bool:
	return alive and not captured
