## 戦闘の計算：命中、ダメージ、経験値とレベルアップ。
class_name Combat
extends RefCounted

const HIT_CHANCE := 0.95
## レベルアップ時の上昇量
const LEVEL_UP_HP := 5
const LEVEL_UP_ATTACK := 1


## 攻撃 1 回分の結果を返す。{"hit": bool, "damage": int}。defender の HP も減らす。
static func attack(attacker: Actor, defender: Actor, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= HIT_CHANCE:
		return {"hit": false, "damage": 0}
	var damage := roll_damage(attacker.attack, defender.defense, rng)
	defender.hp = maxi(defender.hp - damage, 0)
	return {"hit": true, "damage": damage}


## ダメージ = 攻撃力 − 防御力/2 に ±12.5% のゆらぎ。最低 1。
static func roll_damage(atk: int, def: int, rng: RandomNumberGenerator) -> int:
	var base := atk - def / 2.0
	return maxi(1, roundi(base * rng.randf_range(0.875, 1.125)))


## 次のレベルに必要な累計経験値。Lv2 は 6、Lv3 は 18、Lv4 は 36…
static func exp_for_next_level(level: int) -> int:
	return 3 * level * (level + 1)


## 経験値を足し、上がったレベル数を返す。
static func gain_exp(player: Actor, amount: int) -> int:
	player.xp += amount
	var gained := 0
	while player.xp >= exp_for_next_level(player.level):
		player.level += 1
		player.max_hp += LEVEL_UP_HP
		player.hp = mini(player.hp + LEVEL_UP_HP, player.max_hp)
		player.attack += LEVEL_UP_ATTACK
		gained += 1
	return gained
