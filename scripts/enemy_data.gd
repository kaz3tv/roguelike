## 敵の種類と強さの表。数値の調整はここだけ触ればよい。
class_name EnemyData
extends RefCounted

## behavior:
##   "chase"   見えたら追いかけ、見えなければうろつく
##   "erratic" chase と同じだが、半分の確率でふらふら動く（コウモリ）
const ENEMIES := {
	"slime": {"name": "スライム", "hp": 5, "attack": 3, "defense": 0, "exp": 2, "floors": [1, 3], "behavior": "chase"},
	"bat": {"name": "コウモリ", "hp": 4, "attack": 3, "defense": 0, "exp": 2, "floors": [1, 4], "behavior": "erratic"},
	"rat": {"name": "ネズミ", "hp": 6, "attack": 4, "defense": 1, "exp": 3, "floors": [1, 4], "behavior": "chase"},
	"goblin": {"name": "ゴブリン", "hp": 11, "attack": 6, "defense": 2, "exp": 5, "floors": [2, 6], "behavior": "chase"},
	"skeleton": {"name": "骸骨", "hp": 16, "attack": 7, "defense": 6, "exp": 8, "floors": [4, 8], "behavior": "chase"},
	"ghost": {"name": "ゴースト", "hp": 14, "attack": 8, "defense": 3, "exp": 9, "floors": [4, 9], "behavior": "erratic"},
	"mage": {"name": "魔法使い", "hp": 14, "attack": 10, "defense": 3, "exp": 11, "floors": [6, 10], "behavior": "chase"},
	"orc": {"name": "オーク", "hp": 28, "attack": 11, "defense": 6, "exp": 16, "floors": [7, 10], "behavior": "chase"},
}


## その階に出る敵の種類を返す。
static func kinds_for_floor(floor_number: int) -> Array[String]:
	var out: Array[String] = []
	for id in ENEMIES:
		var range_: Array = ENEMIES[id]["floors"]
		if floor_number >= range_[0] and floor_number <= range_[1]:
			out.append(id)
	return out


static func create(id: String) -> Actor:
	var d: Dictionary = ENEMIES[id]
	var a := Actor.new()
	a.kind = id
	a.display_name = d["name"]
	a.max_hp = d["hp"]
	a.hp = d["hp"]
	a.attack = d["attack"]
	a.defense = d["defense"]
	a.xp = d["exp"]
	a.behavior = d["behavior"]
	return a
