## 敵の種類と強さの表。数値の調整はここだけ触ればよい。
class_name EnemyData
extends RefCounted

## behavior:
##   "chase"      見えたら追いかけ、見えなければうろつく
##   "erratic"    chase と同じだが、半分の確率でふらふら動く（コウモリ）
##   "caster"     chase に加えて、離れていると魔法の弾を撃つ（魔法使い）
##   "boss"       chase に加えて、離れていると闇の炎（遠距離攻撃）を放つ。10階にだけ出る
##   "stationary" 動かない。となりに来たら攻撃する（おばけキノコ）
##   "fast"       1ターンに2回動く。攻撃は1回まで（ヘビ）
##   "split"      攻撃されて生き残ると、となりに同じHPの分身が出る。分身は分裂しない（大スライム）
##   "archer"     まっすぐ並んだ近くの相手に矢を撃つ。となりなら殴る（弓兵）
##   "explode"    倒されると爆発して、まわり8マスにダメージ（火の精霊）
##   "slow"       2ターンに1回しか動かない（ゴーレム）
const ENEMIES := {
	"slime": {"name": "スライム", "hp": 5, "attack": 3, "defense": 0, "exp": 2, "floors": [1, 3], "behavior": "chase"},
	"bat": {"name": "コウモリ", "hp": 4, "attack": 3, "defense": 0, "exp": 2, "floors": [1, 4], "behavior": "erratic"},
	"rat": {"name": "ネズミ", "hp": 6, "attack": 4, "defense": 1, "exp": 3, "floors": [1, 4], "behavior": "chase"},
	"goblin": {"name": "ゴブリン", "hp": 11, "attack": 6, "defense": 2, "exp": 5, "floors": [2, 6], "behavior": "chase"},
	"skeleton": {"name": "骸骨", "hp": 16, "attack": 7, "defense": 6, "exp": 8, "floors": [4, 8], "behavior": "chase"},
	"ghost": {"name": "ゴースト", "hp": 14, "attack": 8, "defense": 3, "exp": 9, "floors": [4, 9], "behavior": "erratic"},
	"mage": {"name": "魔法使い", "hp": 14, "attack": 10, "defense": 3, "exp": 11, "floors": [6, 10], "behavior": "caster"},
	"orc": {"name": "オーク", "hp": 28, "attack": 11, "defense": 6, "exp": 16, "floors": [7, 10], "behavior": "chase"},
	"mushroom": {"name": "おばけキノコ", "hp": 8, "attack": 4, "defense": 1, "exp": 3, "floors": [1, 3], "behavior": "stationary"},
	"snake": {"name": "ヘビ", "hp": 9, "attack": 5, "defense": 1, "exp": 5, "floors": [3, 6], "behavior": "fast"},
	"big_slime": {"name": "大スライム", "hp": 14, "attack": 5, "defense": 1, "exp": 4, "floors": [3, 6], "behavior": "split"},
	"archer": {"name": "弓兵", "hp": 13, "attack": 7, "defense": 4, "exp": 10, "floors": [5, 9], "behavior": "archer"},
	"fire_spirit": {"name": "火の精霊", "hp": 18, "attack": 10, "defense": 3, "exp": 14, "floors": [7, 10], "behavior": "explode"},
	"golem": {"name": "ゴーレム", "hp": 40, "attack": 14, "defense": 9, "exp": 22, "floors": [8, 10], "behavior": "slow"},
	"boss": {"name": "魔王", "hp": 90, "attack": 14, "defense": 6, "exp": 0, "floors": [], "behavior": "boss"},
}


## その階に出る敵の種類を返す。
static func kinds_for_floor(floor_number: int) -> Array[String]:
	var out: Array[String] = []
	for id in ENEMIES:
		var range_: Array = ENEMIES[id]["floors"]
		# ボスのように floors が空の敵は、ふつうの階には出ない
		if not range_.is_empty() and floor_number >= range_[0] and floor_number <= range_[1]:
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
