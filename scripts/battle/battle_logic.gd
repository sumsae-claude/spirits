class_name BattleLogic
extends RefCounted
## 전투 공식 모음. 밸런스 조정은 여기서.

const BASIC_ATTACK_POWER := 40
const BASIC_ATTACK_RANGE := 1
## 디스펠 사거리/MP는 data/summoner.json (정령사 전용)
const MP_REGEN_PER_ROUND := 2
## 일반 공격(근접)을 받고 살아남으면 이 비율의 위력으로 반격. 스킬·원거리에는 반격 없음.
const COUNTER_RATIO := 0.6
## '방어'로 대응하면 받는 피해 배율 (정령사의 공격 마법은 예외)
const DEFEND_MULT := 0.5
## 다른 정령사와 계약된 정령은 디스펠하기 어렵다
const OWNED_DISPEL_MULT := 0.6
## 플레이어 정령사가 한 번에 받는 피해 상한 (최대 HP 비율). 한 방 패배 방지
const SUMMONER_HIT_CAP := 0.4


## 피해량 = 공격 × (위력/40) × 20/(20+방어) × 속성배율 × 지형배율 × 난수(0.9~1.1)
## 지형배율 = 공격자 지형의 공격 보정(공격자 속성 기준) × 방어자 지형의 방어 보정
## atk_mult / def_mult = 버프·디버프 배율
## rng가 null이면 난수 없이 기대값을 계산 (AI, 미리보기용).
static func calc_damage(attacker: Spirit, defender: Spirit, power: int, element: String,
		rng: RandomNumberGenerator = null, attacker_terrain: String = "plain", defender_terrain: String = "plain",
		atk_mult: float = 1.0, def_mult: float = 1.0) -> int:
	var atk := float(attacker.stat("atk")) * atk_mult
	var defense := float(defender.stat("def")) * def_mult
	var mult := GameData.element_multiplier(element, defender.element())
	mult *= GameData.terrain_attack_mult(attacker_terrain, attacker.element())
	mult *= GameData.terrain_defense_mult(defender_terrain, defender.element())
	var dmg := atk * float(power) / 40.0 * 20.0 / (20.0 + defense) * mult
	if rng != null:
		dmg *= rng.randf_range(0.9, 1.1)
	return maxi(1, int(round(dmg)))


## 디스펠(계약) 성공 확률.
## 대상 체력이 낮을수록, 시전자 레벨이 높을수록, 속성이 유리할수록 높다.
## 친밀도가 높을수록 빼앗기 어렵다: 친밀도 100이면 확률 ×0.2 (한 자리 수)
static func affinity_mult(target: Spirit) -> float:
	return 1.0 - float(target.affinity) / 125.0


static func dispel_chance(caster: Spirit, target: Spirit, owned: bool = false) -> float:
	var hp_ratio := float(target.hp) / float(maxi(1, target.max_hp()))
	var base := (caster as Summoner).dispel_base() if caster is Summoner else 0.15   # 정령사 속성별 기본치
	var chance := base + (1.0 - hp_ratio) * 0.6 + float(caster.level - target.level) * 0.04
	if GameData.STRONG_AGAINST.get(caster.element(), "") == target.element():
		chance += 0.1
	chance *= float(target.species().get("catch", 1.0))
	if owned:
		chance *= affinity_mult(target)   # 다른 정령사와 계약된 정령: 친밀도만큼 어려움
	return clampf(chance, 0.05, 0.95)


## 정령사 회복 스킬 회복량
static func heal_amount(caster: Spirit, target: Spirit, sk: Dictionary) -> int:
	return maxi(1, int(round(target.max_hp() * float(sk.get("heal_ratio", 0.3)) + float(sk.get("heal_flat", 0)) + caster.level)))


## 행동마다 경험치: 공격(기본·스킬·반격)으로 입힌 피해 비율 × 이 값 × xp_reward
const HIT_XP_RATIO := 1.0
## 마무리(쓰러뜨림)·디스펠 성공 보너스 = xp_reward × 이 값
const KILL_XP_MULT := 1.5
const DISPEL_XP_MULT := 1.5
## 회복·버프·디버프 정령사 스킬 1회
const SUPPORT_XP := 5


static func hit_xp(target: Spirit, dealt: int) -> int:
	if dealt <= 0:
		return 0
	var ratio := float(dealt) / float(maxi(1, target.max_hp()))
	return maxi(1, int(round(float(xp_reward(target)) * HIT_XP_RATIO * ratio)))


static func xp_reward(enemy: Spirit) -> int:
	return 6 + enemy.level * 4
