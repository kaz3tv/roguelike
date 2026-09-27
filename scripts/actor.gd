## プレイヤーと敵に共通のパラメータ。
class_name Actor
extends RefCounted

var kind := ""  ## "player" または敵の種類（EnemyData のキー）
var display_name := ""
var pos := Vector2i.ZERO
var max_hp := 1
var hp := 1
var attack := 1
var defense := 0
var level := 1
var xp := 0  ## プレイヤーは累計経験値、敵は倒したときにもらえる経験値
var behavior := ""  ## 敵の動き方（EnemyData 参照）
var sleep_turns := 0  ## 眠っている残りターン（眠りの巻物）。攻撃されると 0 に戻る
var rested := false  ## 遅い敵（ゴーレム）が前のターンに休んだか
var node: Sprite2D  ## 画面上の絵
var inventory: Inventory  ## プレイヤーだけが持つ


func is_dead() -> bool:
	return hp <= 0


## 装備込みの攻撃力・防御力
func total_attack() -> int:
	return attack + (inventory.attack_bonus() if inventory else 0)


func total_defense() -> int:
	return defense + (inventory.defense_bonus() if inventory else 0)


static func new_player() -> Actor:
	var a := Actor.new()
	a.kind = "player"
	a.display_name = "あなた"
	a.max_hp = 20
	a.hp = 20
	a.attack = 5
	a.defense = 2
	a.inventory = Inventory.new()
	return a


## 中断セーブ用。敵は種類・位置・HP だけ、プレイヤーは成長と持ち物も残す。
func to_dict() -> Dictionary:
	var d := {"kind": kind, "pos": pos, "hp": hp, "max_hp": max_hp, "attack": attack, "defense": defense, "level": level, "xp": xp,
		"behavior": behavior, "sleep_turns": sleep_turns, "rested": rested}
	if inventory:
		d["items"] = inventory.items.map(func(item: Item) -> Dictionary: return item.to_dict())
		d["weapon"] = inventory.items.find(inventory.weapon)
		d["shield"] = inventory.items.find(inventory.shield)
	return d


static func from_dict(d: Dictionary) -> Actor:
	var a := new_player() if d["kind"] == "player" else EnemyData.create(d["kind"])
	for key in ["pos", "hp", "max_hp", "attack", "defense", "level", "xp"]:
		a.set(key, d[key])
	# あとから足した項目。古い中断セーブにはないので、なければ初期値のまま
	for key in ["behavior", "sleep_turns", "rested"]:
		if d.has(key):
			a.set(key, d[key])
	if a.inventory:
		for item_data in d["items"]:
			a.inventory.add(Item.from_dict(item_data))
		if d["weapon"] >= 0:
			a.inventory.weapon = a.inventory.items[d["weapon"]]
		if d["shield"] >= 0:
			a.inventory.shield = a.inventory.items[d["shield"]]
	return a
