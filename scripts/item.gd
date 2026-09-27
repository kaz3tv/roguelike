## アイテム 1 個。床に落ちているときは pos を使う。
class_name Item
extends RefCounted

var id := ""
var plus := 0  ## 武器・盾の強化値（+1 など）
var pos := Vector2i.ZERO
var node: Sprite2D  ## 床に落ちているときの絵


func _init(item_id: String = "potion") -> void:
	id = item_id


func data() -> Dictionary:
	return ItemData.ITEMS[id]


func type() -> String:
	return data()["type"]


func is_equipment() -> bool:
	return type() == "weapon" or type() == "shield"


func display_name() -> String:
	if is_equipment() and plus > 0:
		return "%s+%d" % [data()["name"], plus]
	return data()["name"]


## 装備したときに上がる攻撃力・防御力
func bonus() -> int:
	return data()["power"] + plus if is_equipment() else 0
