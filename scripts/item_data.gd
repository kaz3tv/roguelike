## アイテムの種類と効果の表。数値の調整はここだけ触ればよい。
class_name ItemData
extends RefCounted

## type:
##   "potion" 使うと HP が power 回復
##   "scroll" 使い捨ての魔法（effect で種類を区別）
##   "weapon" 装備すると攻撃力 +(power + 強化値)
##   "shield" 装備すると防御力 +(power + 強化値)
## weight: 床に落ちている確率の重み
const ITEMS := {
	"potion": {"name": "回復薬", "type": "potion", "power": 25, "weight": 35, "icon": "potion",
		"desc": "HPを25回復する"},
	"scroll_fire": {"name": "炎の巻物", "type": "scroll", "effect": "fire", "power": 15, "weight": 15, "icon": "scroll",
		"desc": "見えている敵すべてに15のダメージ"},
	"scroll_warp": {"name": "ワープの巻物", "type": "scroll", "effect": "warp", "weight": 12, "icon": "scroll",
		"desc": "フロアのどこかへ飛ぶ"},
	"scroll_map": {"name": "地図の巻物", "type": "scroll", "effect": "map", "weight": 12, "icon": "scroll",
		"desc": "フロア全体の地図がわかる"},
	"sword": {"name": "剣", "type": "weapon", "power": 3, "weight": 13, "icon": "sword",
		"desc": "装備すると攻撃力が上がる"},
	"shield": {"name": "盾", "type": "shield", "power": 2, "weight": 13, "icon": "shield",
		"desc": "装備すると防御力が上がる"},
}


static func icon_path(id: String) -> String:
	return "res://assets/art/items/%s.png" % ITEMS[id]["icon"]


## 重みにしたがってアイテムを 1 つ作る。武器と盾は深い階ほど強化値が高くなりやすい。
static func roll(floor_number: int, rng: RandomNumberGenerator) -> Item:
	var total := 0
	for id in ITEMS:
		total += ITEMS[id]["weight"]
	var r := rng.randi_range(1, total)
	for id in ITEMS:
		r -= ITEMS[id]["weight"]
		if r <= 0:
			var item := Item.new(id)
			if item.is_equipment():
				item.plus = rng.randi_range(0, 1 + floor_number / 3)
			return item
	return Item.new("potion")
