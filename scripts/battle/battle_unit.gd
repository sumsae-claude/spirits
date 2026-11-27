class_name BattleUnit
extends RefCounted
## 전투 중인 유닛 하나(정령 또는 정령사). team 0 = 아군, 1 = 야생.

var spirit: Spirit
var team: int
var cell: Vector2i
var draw_pos: Vector2
var alive := true
var captured := false
var recalled := false      # 정령사 곁으로 귀환함 (전장에서 빠짐)
var is_summoner := false
var joined_round := 0      # 전장에 나온 라운드 (그 라운드에는 행동하지 않음)


func _init(p_spirit: Spirit, p_team: int, p_cell: Vector2i) -> void:
	spirit = p_spirit
	team = p_team
	cell = p_cell


func is_active() -> bool:
	return alive and not captured and not recalled
