## 持ち物（最大 10 個）と装備。
class_name Inventory
extends RefCounted

const CAPACITY := 10

var items: Array[Item] = []
var weapon: Item
var shield: Item


func is_full() -> bool:
	return items.size() >= CAPACITY


func add(item: Item) -> bool:
	if is_full():
		return false
	items.append(item)
	return true


## 持ち物から外す。装備中なら装備も外れる。
func remove(item: Item) -> void:
	if weapon == item:
		weapon = null
	if shield == item:
		shield = null
	items.erase(item)


func is_equipped(item: Item) -> bool:
	return item != null and (item == weapon or item == shield)


## 装備する。すでに装備中なら外す。装備したら true を返す。
func toggle_equip(item: Item) -> bool:
	match item.type():
		"weapon":
			weapon = null if weapon == item else item
			return weapon == item
		"shield":
			shield = null if shield == item else item
			return shield == item
	return false


func attack_bonus() -> int:
	return weapon.bonus() if weapon else 0


func defense_bonus() -> int:
	return shield.bonus() if shield else 0
