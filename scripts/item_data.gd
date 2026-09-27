## アイテムの種類と効果の表。数値の調整はここだけ触ればよい。
class_name ItemData
extends RefCounted

## type:
##   "potion" 飲むと effect の効き目（"heal": HP を power 回復、"strength": 攻撃力がずっと +power）
##   "scroll" 使い捨ての魔法（effect で種類を区別）
##   "weapon" 装備すると攻撃力 +(power + 強化値)
##   "shield" 装備すると防御力 +(power + 強化値)
##   "amulet" 持っているだけで効く。倒れたとき 1 回だけ HP 半分で生き返る（使うと消える）
## weight: 床に落ちている確率の重み。min_floor: この階より浅いところには落ちていない
## sound: 使ったときの効果音（scripts/audio.gd の SFX_NAMES のどれか）
const ITEMS := {
	"potion": {"name": "回復薬", "type": "potion", "effect": "heal", "power": 25, "weight": 35, "min_floor": 1,
		"icon": "potion", "sound": "heal", "desc": "HPを25回復する"},
	"potion_big": {"name": "大回復薬", "type": "potion", "effect": "heal", "power": 60, "weight": 12, "min_floor": 5,
		"icon": "potion_big", "sound": "heal", "desc": "HPを60回復する"},
	"potion_power": {"name": "力の薬", "type": "potion", "effect": "strength", "power": 1, "weight": 5, "min_floor": 3,
		"icon": "potion_power", "sound": "level_up", "desc": "攻撃力がずっと1上がる"},
	"scroll_fire": {"name": "炎の巻物", "type": "scroll", "effect": "fire", "power": 15, "weight": 15, "min_floor": 1,
		"icon": "scroll_fire", "sound": "scroll_fire", "desc": "見えている敵すべてに15のダメージ"},
	"scroll_warp": {"name": "ワープの巻物", "type": "scroll", "effect": "warp", "weight": 12, "min_floor": 1,
		"icon": "scroll_warp", "sound": "scroll_warp", "desc": "フロアのどこかへ飛ぶ"},
	"scroll_map": {"name": "地図の巻物", "type": "scroll", "effect": "map", "weight": 12, "min_floor": 1,
		"icon": "scroll_map", "sound": "scroll_map", "desc": "フロア全体の地図がわかる"},
	"scroll_sleep": {"name": "眠りの巻物", "type": "scroll", "effect": "sleep", "power": 5, "weight": 10, "min_floor": 2,
		"icon": "scroll_sleep", "sound": "scroll_map", "desc": "見えている敵を5ターン眠らせる"},
	"scroll_thunder": {"name": "雷の巻物", "type": "scroll", "effect": "thunder", "power": 30, "weight": 10, "min_floor": 4,
		"icon": "scroll_thunder", "sound": "magic_bolt", "desc": "一番近い敵1体に30のダメージ"},
	"sword": {"name": "剣", "type": "weapon", "power": 3, "weight": 13, "min_floor": 1, "icon": "sword",
		"desc": "装備すると攻撃力が上がる"},
	"greatsword": {"name": "大剣", "type": "weapon", "power": 6, "weight": 5, "min_floor": 6, "icon": "greatsword",
		"desc": "装備すると攻撃力が大きく上がる"},
	"shield": {"name": "盾", "type": "shield", "power": 2, "weight": 13, "min_floor": 1, "icon": "shield",
		"desc": "装備すると防御力が上がる"},
	"amulet": {"name": "復活の首飾り", "type": "amulet", "weight": 2, "min_floor": 4, "icon": "amulet",
		"desc": "倒れても1回だけ生き返る（持つだけ）"},
}


static func icon_path(id: String) -> String:
	return "res://assets/art/items/%s.png" % ITEMS[id]["icon"]


## 重みにしたがってアイテムを 1 つ作る。浅い階には強いアイテムは落ちていない。
## 武器と盾は深い階ほど強化値が高くなりやすい。
static func roll(floor_number: int, rng: RandomNumberGenerator) -> Item:
	var ids := ITEMS.keys().filter(func(id: String) -> bool: return floor_number >= ITEMS[id]["min_floor"])
	var total := 0
	for id in ids:
		total += ITEMS[id]["weight"]
	var r := rng.randi_range(1, total)
	for id in ids:
		r -= ITEMS[id]["weight"]
		if r <= 0:
			var item := Item.new(id)
			if item.is_equipment():
				item.plus = rng.randi_range(0, 1 + floor_number / 3)
			return item
	return Item.new("potion")
