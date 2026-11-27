class_name BattleLogic
extends RefCounted
## 전투 공식 모음. 밸런스 조정은 여기서.

const BASIC_ATTACK_POWER := 40
const BASIC_ATTACK_RANGE := 1
## 디스펠 사거리/MP는 data/summoner.json (정령사 전용)
const MP_REGEN_PER_ROUND := 2
## 일반 공격(근접)을 받고 살아남으면 이 비율의 위력으로 반격. 스킬·원거리에는 반격 없음.
const COUNTER_RATIO := 0.6
## 다른 정령사와 계약된 정령은 디스펠하기 어렵다
const OWNED_DISPEL_MULT := 0.6


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
	mult *= GameData.terrain_defense_mult(defender_terrain)
	var dmg := atk * float(power) / 40.0 * 20.0 / (20.0 + defense) * mult
	if rng != null:
		dmg *= rng.randf_range(0.9, 1.1)
	return maxi(1, int(round(dmg)))


## 디스펠(계약) 성공 확률.
## 대상 체력이 낮을수록, 시전자 레벨이 높을수록, 속성이 유리할수록 높다.
static func dispel_chance(caster: Spirit, target: Spirit, owned: bool = false) -> float:
	var hp_ratio := float(target.hp) / float(maxi(1, target.max_hp()))
	var chance := 0.15 + (1.0 - hp_ratio) * 0.6 + float(caster.level - target.level) * 0.04
	if GameData.STRONG_AGAINST.get(caster.element(), "") == target.element():
		chance += 0.1
	chance *= float(target.species().get("catch", 1.0))
	if owned:
		chance *= OWNED_DISPEL_MULT
	return clampf(chance, 0.05, 0.95)


## 정령사 회복 스킬 회복량
static func heal_amount(caster: Spirit, target: Spirit, sk: Dictionary) -> int:
	return maxi(1, int(round(target.max_hp() * float(sk.get("heal_ratio", 0.3)) + float(sk.get("heal_flat", 0)) + caster.level)))


static func xp_reward(enemy: Spirit) -> int:
	return 6 + enemy.level * 4
