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
var owned := false         # 적 정령사가 소환한 정령 (주인이 있음)
var is_guardian := false   # 스토리 보스 수호 정령
var revealed := false      # 수호 정령의 실이 드러남 (디스펠 가능)
## 연출용 (로직에는 영향 없음)
var anim_offset := Vector2.ZERO  # 공격 돌진·피격 흔들림
var flash := 0.0                 # 피격 시 붉게 번쩍
var fade := 1.0                  # 투명도 (소환 등장·퇴장)
var pop := 1.0                   # 크기 배율 (소환 등장·퇴장)
var vanishing := false           # 쓰러짐/계약/귀환으로 사라지는 중
var joined_round := 0      # 전장에 나온 라운드 (그 라운드에는 행동하지 않음)
var done := false          # 이번 진영 턴에 행동을 마침
## 버프/디버프: [{"name", "stat", "mult", "add", "rounds"}]
var buffs: Array = []


func stat_mult(key: String) -> float:
	var m := 1.0
	for b in buffs:
		if b["stat"] == key:
			m *= float(b.get("mult", 1.0))
	return m


func stat_add(key: String) -> int:
	var a := 0
	for b in buffs:
		if b["stat"] == key:
			a += int(b.get("add", 0))
	return a


## 라운드가 지날 때 남은 턴을 줄이고 끝난 효과를 지운다.
func tick_buffs() -> void:
	for b in buffs:
		b["rounds"] = int(b["rounds"]) - 1
	buffs = buffs.filter(func(b): return int(b["rounds"]) > 0)


func _init(p_spirit: Spirit, p_team: int, p_cell: Vector2i) -> void:
	spirit = p_spirit
	team = p_team
	cell = p_cell


func is_active() -> bool:
	return alive and not captured and not recalled
