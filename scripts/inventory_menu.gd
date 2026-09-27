## 持ち物画面。上下で選び、Enter で使う（装備品なら装備／外す）、X で足元に置く。
extends ColorRect

signal item_chosen(item: Item, action: String)  ## action は "use" か "drop"
signal closed

const UP_KEYS := [KEY_UP, KEY_W, KEY_KP_8]
const DOWN_KEYS := [KEY_DOWN, KEY_S, KEY_KP_2]
const CLOSE_KEYS := [KEY_ESCAPE, KEY_I, KEY_TAB, KEY_BACKSPACE]

var inventory: Inventory
var audio: Node  ## 効果音（game.gd が設定する）
var cursor := 0

@onready var list_label: Label = $List
@onready var desc_label: Label = $Desc


func open(inv: Inventory) -> void:
	inventory = inv
	cursor = clampi(cursor, 0, maxi(inventory.items.size() - 1, 0))
	refresh()
	show()


func close() -> void:
	audio.play("menu_cancel")
	hide()
	closed.emit()


func handle_key(code: Key) -> void:
	var count := inventory.items.size()
	if code in CLOSE_KEYS:
		close()
	elif count == 0:
		return
	elif code in UP_KEYS:
		cursor = (cursor - 1 + count) % count
		audio.play("menu_move")
		refresh()
	elif code in DOWN_KEYS:
		cursor = (cursor + 1) % count
		audio.play("menu_move")
		refresh()
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		var item := inventory.items[cursor]
		hide()
		item_chosen.emit(item, "use")
	elif code == KEY_X:
		var item := inventory.items[cursor]
		hide()
		item_chosen.emit(item, "drop")


func refresh() -> void:
	var lines: Array[String] = ["持ち物  %d/%d" % [inventory.items.size(), Inventory.CAPACITY]]
	if inventory.items.is_empty():
		lines.append("  （なにも持っていない）")
		desc_label.text = "Esc/B: 閉じる"
	for i in inventory.items.size():
		var item := inventory.items[i]
		var mark := "＞" if i == cursor else "　"
		var equipped := "[E]" if inventory.is_equipped(item) else ""
		lines.append("%s %s%s" % [mark, item.display_name(), equipped])
	if not inventory.items.is_empty():
		var item := inventory.items[cursor]
		var verb := "外す" if inventory.is_equipped(item) else ("装備" if item.is_equipment() else "使う")
		desc_label.text = "%s\nEnter/A:%s  X:置く  Esc/B:閉じる" % [item.data()["desc"], verb]
	list_label.text = "\n".join(lines)
