## ゲーム本体：フロアの進行、ターンの処理、画面の更新。
extends Node2D

const TILE_SIZE := 16
const LOG_LINES := 3
## 何ターンごとに HP が 1 回復するか
const REGEN_TURNS := 6
## 1 フロアの敵の数 = ENEMY_BASE_MIN〜ENEMY_BASE_MAX + 階数/3
const ENEMY_BASE_MIN := 3
const ENEMY_BASE_MAX := 5
## 1 フロアに落ちているアイテムの数
const ITEM_MIN := 3
const ITEM_MAX := 5
## ボスがいる最後の階
const BOSS_FLOOR := 10
## 闇の炎の威力（ボスの攻撃力に対する割合）
const BOLT_POWER := 0.6
## リザルトを出してから Enter を受け付けるまでの時間（ミリ秒）
const RESULT_INPUT_DELAY_MS := 800

## キー → 移動方向（8 方向）。斜めは Q/E/Z/C かテンキー。
const MOVE_KEYS := {
	KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0),
	KEY_Q: Vector2i(-1, -1), KEY_E: Vector2i(1, -1), KEY_Z: Vector2i(-1, 1), KEY_C: Vector2i(1, 1),
	KEY_KP_8: Vector2i(0, -1), KEY_KP_2: Vector2i(0, 1), KEY_KP_4: Vector2i(-1, 0), KEY_KP_6: Vector2i(1, 0),
	KEY_KP_7: Vector2i(-1, -1), KEY_KP_9: Vector2i(1, -1), KEY_KP_1: Vector2i(-1, 1), KEY_KP_3: Vector2i(1, 1),
}
## その場で 1 ターン待つキー
const WAIT_KEYS := [KEY_SPACE, KEY_KP_5, KEY_PERIOD]
## 持ち物画面を開くキー
const MENU_KEYS := [KEY_I, KEY_TAB]
const PLAYER_FRAMES := [
	preload("res://assets/art/player_0.png"),
	preload("res://assets/art/player_1.png"),
]
const DAMAGE_COLOR := Color("#ffcd75")
const HURT_COLOR := Color("#ef7d57")

## 0 以外にすると毎回同じダンジョンになる（確認用）
@export var fixed_seed := 0

var rng := RandomNumberGenerator.new()
var floor_number := 1
var turn := 0
var kills := 0
var map: Dungeon
var player: Actor
var enemies: Array[Actor] = []
var floor_items: Array[Item] = []
var visible_cells := {}
var player_frame := 0
var game_over := false
## タイトル画面を出しているあいだ true
var in_title := false
var records: Records
## リザルトを出した時刻。直後の Enter の押しすぎでタイトルまで飛ばないようにする
var result_shown_at := 0
var log_lines: Array[String] = []
var enemy_textures := {}
var item_textures := {}

@onready var map_view: Node2D = $MapView
@onready var enemy_layer: Node2D = $Enemies
@onready var item_layer: Node2D = $Items
@onready var inventory_menu = $HUD/InventoryMenu
@onready var audio = $Audio
@onready var effects: Node2D = $Effects
@onready var player_sprite: Sprite2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var status_label: Label = $HUD/TopBar/StatusLabel
@onready var log_label: Label = $HUD/LogPanel/LogLabel
@onready var result_panel: Control = $HUD/Result
@onready var result_header: Label = $HUD/Result/Header
@onready var result_body: Label = $HUD/Result/Body
@onready var title_panel: Control = $HUD/Title
@onready var title_records: Label = $HUD/Title/Records
@onready var title_start: Label = $HUD/Title/Start


func _ready() -> void:
	if fixed_seed != 0:
		rng.seed = fixed_seed
	else:
		rng.randomize()
	print("seed: ", rng.seed)
	for id in EnemyData.ENEMIES:
		enemy_textures[id] = [
			load("res://assets/art/enemies/%s_0.png" % id),
			load("res://assets/art/enemies/%s_1.png" % id),
		]
	for id in ItemData.ITEMS:
		item_textures[id] = load(ItemData.icon_path(id))
	inventory_menu.item_chosen.connect(_on_item_chosen)
	inventory_menu.audio = audio
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = Dungeon.WIDTH * TILE_SIZE
	camera.limit_bottom = Dungeon.HEIGHT * TILE_SIZE
	$IdleTimer.timeout.connect(_on_idle_timer)
	records = Records.load_from()
	show_title()


func show_title() -> void:
	in_title = true
	game_over = false
	result_panel.hide()
	inventory_menu.hide()
	title_panel.show()
	title_records.text = records_text()
	audio.play_bgm("title")


## タイトルに出す、これまでの記録
func records_text() -> String:
	if records.runs == 0:
		return "記録はまだありません"
	var lines := ["挑戦 %d回   クリア %d回" % [records.runs, records.clears]]
	lines.append("最高到達  地下%d階   最多撃破  %d体" % [records.best_floor, records.best_kills])
	if records.fastest_clear > 0:
		lines.append("最速クリア  %dターン" % records.fastest_clear)
	return "\n".join(lines)


func start_run() -> void:
	player = Actor.new_player()
	player.node = player_sprite
	floor_number = 1
	turn = 0
	kills = 0
	game_over = false
	in_title = false
	title_panel.hide()
	result_panel.hide()
	inventory_menu.hide()
	log_lines.clear()
	enter_floor()


func enter_floor() -> void:
	var is_boss_floor := floor_number == BOSS_FLOOR
	map = Dungeon.generate_boss_room() if is_boss_floor else Dungeon.generate(rng)
	map_view.map = map
	map_view.set_floor_theme(floor_number)
	map_view.explored = {}
	player.pos = map.start
	if is_boss_floor:
		clear_floor_objects()
		spawn_enemy("boss", map.boss_pos)
	else:
		spawn_enemies()
		spawn_items()
	update_view()
	camera.reset_smoothing()
	add_message("地下%d階に着いた。" % floor_number)
	if is_boss_floor:
		add_message("まがまがしい気配がする…魔王だ！")
		audio.play_bgm("boss")
	else:
		audio.play_bgm(audio.bgm_for_floor(floor_number))


## 前の階の敵とアイテムを片付ける
func clear_floor_objects() -> void:
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	for item in floor_items:
		item.node.queue_free()
	floor_items.clear()


func spawn_enemy(kind: String, pos: Vector2i) -> Actor:
	var e := EnemyData.create(kind)
	e.pos = pos
	e.node = Sprite2D.new()
	e.node.centered = false
	e.node.texture = enemy_textures[e.kind][0]
	e.node.position = Vector2(pos * TILE_SIZE)
	enemy_layer.add_child(e.node)
	enemies.append(e)
	return e


func spawn_enemies() -> void:
	for e in enemies:
		e.node.queue_free()
	enemies.clear()
	var kinds := EnemyData.kinds_for_floor(floor_number)
	if kinds.is_empty():
		return
	var count := rng.randi_range(ENEMY_BASE_MIN, ENEMY_BASE_MAX) + floor_number / 3
	var taken := {map.start: true, map.stairs: true}
	for i in count:
		# スタートの部屋（0 番）には置かない
		var room := map.rooms[rng.randi_range(1, map.rooms.size() - 1)]
		var pos := Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))
		if taken.has(pos):
			continue
		taken[pos] = true
		spawn_enemy(kinds[rng.randi_range(0, kinds.size() - 1)], pos)


func spawn_items() -> void:
	for item in floor_items:
		item.node.queue_free()
	floor_items.clear()
	var taken := {map.start: true, map.stairs: true}
	for e in enemies:
		taken[e.pos] = true
	for i in rng.randi_range(ITEM_MIN, ITEM_MAX):
		var room := map.rooms[rng.randi_range(0, map.rooms.size() - 1)]
		var pos := Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))
		if taken.has(pos):
			continue
		taken[pos] = true
		place_item(ItemData.roll(floor_number, rng), pos)


func place_item(item: Item, pos: Vector2i) -> void:
	item.pos = pos
	item.node = Sprite2D.new()
	item.node.centered = false
	item.node.texture = item_textures[item.id]
	item.node.position = Vector2(pos * TILE_SIZE)
	item_layer.add_child(item.node)
	floor_items.append(item)


func item_at(pos: Vector2i) -> Item:
	for item in floor_items:
		if item.pos == pos:
			return item
	return null


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var code := key.physical_keycode
	var is_enter := code == KEY_ENTER or code == KEY_KP_ENTER
	if in_title:
		if is_enter and not key.echo:
			audio.play("menu_select")
			start_run()
		get_viewport().set_input_as_handled()
		return
	if game_over:
		if is_enter and not key.echo and Time.get_ticks_msec() - result_shown_at > RESULT_INPUT_DELAY_MS:
			audio.play("menu_select")
			show_title()
		get_viewport().set_input_as_handled()
		return
	if inventory_menu.visible:
		# 決定キーの押しっぱなしで連続して使ってしまわないようにする
		if not key.echo or code not in [KEY_ENTER, KEY_KP_ENTER, KEY_X]:
			inventory_menu.handle_key(code)
		get_viewport().set_input_as_handled()
		return
	if MOVE_KEYS.has(code):
		# 押しっぱなしで歩き続けられるよう、キーリピートも受け付ける
		player_step(MOVE_KEYS[code])
	elif code in WAIT_KEYS:
		end_player_turn()
	elif is_enter and not key.echo:
		descend()
	elif code in MENU_KEYS and not key.echo:
		audio.play("menu_select")
		inventory_menu.open(player.inventory)
	elif code == KEY_F9 and not key.echo and OS.is_debug_build() and floor_number < BOSS_FLOOR:
		# 確認用：エディタから起動したときだけ、F9 ですぐ次の階へ行ける
		floor_number += 1
		enter_floor()
	elif code == KEY_M and not key.echo:
		audio.toggle_mute()
		add_message("音を消した。M でもとに戻る。" if audio.muted else "音を出した。")
	else:
		return
	get_viewport().set_input_as_handled()


## 方向キーの処理。敵がいれば攻撃、いなければ移動。
func player_step(dir: Vector2i) -> void:
	if dir.x != 0:
		player_sprite.flip_h = dir.x < 0
	if not map.can_step(player.pos, dir):
		return
	var target := player.pos + dir
	var enemy := enemy_at(target)
	if enemy != null:
		player_attack(enemy, dir)
	else:
		player.pos = target
		player_frame ^= 1
		if map.tile_at(target) == Dungeon.Tile.STAIRS:
			add_message("階段がある。Enter で降りる。")
		pick_up()
	end_player_turn()


func player_attack(enemy: Actor, dir: Vector2i) -> void:
	bump(player_sprite, dir)
	var result := Combat.attack(player, enemy, rng)
	if not result["hit"]:
		add_message("%sへの攻撃は外れた。" % enemy.display_name)
		audio.play("attack_miss")
		popup("MISS", enemy.pos, Color.WHITE)
		return
	popup(str(result["damage"]), enemy.pos, DAMAGE_COLOR)
	audio.play("hit_enemy")
	if enemy.is_dead():
		kill_enemy(enemy)
	else:
		add_message("%sに %d のダメージ。" % [enemy.display_name, result["damage"]])


func kill_enemy(enemy: Actor) -> void:
	kills += 1
	audio.play("enemy_die")
	enemies.erase(enemy)
	enemy.node.queue_free()
	if enemy.kind == "boss":
		show_clear()
		return
	add_message("%sを倒した。経験値 %d。" % [enemy.display_name, enemy.xp])
	var levels := Combat.gain_exp(player, enemy.xp)
	if levels > 0:
		add_message("レベル%dに上がった！" % player.level)
		audio.play("level_up")
		popup("LEVEL UP", player.pos, Color("#a7f070"))


## 足元のアイテムを拾う
func pick_up() -> void:
	var item := item_at(player.pos)
	if item == null:
		return
	if not player.inventory.add(item):
		add_message("持ち物がいっぱいで、%sを拾えない。" % item.display_name())
		audio.play("error")
		return
	floor_items.erase(item)
	item.node.queue_free()
	item.node = null
	add_message("%sを拾った。" % item.display_name())
	audio.play("item_pickup")


func _on_item_chosen(item: Item, action: String) -> void:
	if action == "drop":
		drop_item(item)
	else:
		use_item(item)


func drop_item(item: Item) -> void:
	if item_at(player.pos) != null or map.tile_at(player.pos) == Dungeon.Tile.STAIRS:
		add_message("ここには置けない。")
		audio.play("error")
		return
	player.inventory.remove(item)
	place_item(item, player.pos)
	add_message("%sを足元に置いた。" % item.display_name())
	end_player_turn()


## アイテムを使う。装備品なら装備する／外す。どれも 1 ターンかかる。
func use_item(item: Item) -> void:
	var inv := player.inventory
	match item.type():
		"weapon", "shield":
			if inv.toggle_equip(item):
				add_message("%sを装備した。" % item.display_name())
				audio.play("equip")
			else:
				add_message("%sを外した。" % item.display_name())
				audio.play("equip")
		"potion":
			var healed := mini(item.data()["power"], player.max_hp - player.hp)
			player.hp += healed
			inv.remove(item)
			add_message("%sを飲んだ。HPが %d 回復した。" % [item.display_name(), healed])
			popup("+%d" % healed, player.pos, Color("#a7f070"))
			audio.play("heal")
		"scroll":
			inv.remove(item)
			add_message("%sを読んだ。" % item.display_name())
			audio.play("scroll_" + item.data()["effect"])
			read_scroll(item)
	end_player_turn()


func read_scroll(item: Item) -> void:
	match item.data()["effect"]:
		"fire":
			var targets := enemies.filter(func(e: Actor) -> bool: return visible_cells.has(e.pos))
			if targets.is_empty():
				add_message("しかし、まわりに敵はいなかった。")
			for e: Actor in targets:
				var damage: int = item.data()["power"]
				e.hp = maxi(e.hp - damage, 0)
				popup(str(damage), e.pos, DAMAGE_COLOR)
				if e.is_dead():
					kill_enemy(e)
		"warp":
			var room := map.rooms[rng.randi_range(0, map.rooms.size() - 1)]
			for i in 50:
				var pos := Vector2i(rng.randi_range(room.position.x, room.end.x - 1), rng.randi_range(room.position.y, room.end.y - 1))
				if enemy_at(pos) == null:
					player.pos = pos
					break
			camera.reset_smoothing()
			pick_up()
		"map":
			for y in Dungeon.HEIGHT:
				for x in Dungeon.WIDTH:
					var cell := Vector2i(x, y)
					if not map.is_walkable(cell):
						continue
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if map.in_bounds(cell + Vector2i(dx, dy)):
								map_view.explored[cell + Vector2i(dx, dy)] = true
			add_message("フロアの地図が頭に浮かんだ。")


func end_player_turn() -> void:
	turn += 1
	if turn % REGEN_TURNS == 0:
		player.hp = mini(player.hp + 1, player.max_hp)
	# 敵はプレイヤーが動いたあとの視界で判断する
	visible_cells = Fov.compute(map, player.pos)
	enemies_act()
	update_view()


func enemies_act() -> void:
	var occupied := {}
	for e in enemies:
		occupied[e.pos] = true
	for e in enemies:
		var action := MonsterAI.decide(map, e, player.pos, visible_cells.has(e.pos), occupied, rng)
		match action["type"]:
			"attack":
				enemy_attack(e)
				if game_over:
					return
			"bolt":
				enemy_bolt(e)
				if game_over:
					return
			"move":
				occupied.erase(e.pos)
				e.pos += action["dir"]
				occupied[e.pos] = true
				if action["dir"].x != 0:
					e.node.flip_h = action["dir"].x < 0


func enemy_attack(e: Actor) -> void:
	bump(e.node, player.pos - e.pos)
	var result := Combat.attack(e, player, rng)
	if not result["hit"]:
		add_message("%sの攻撃は外れた。" % e.display_name)
		audio.play("enemy_attack")
		popup("MISS", player.pos, Color.WHITE)
		return
	add_message("%sの攻撃。%d のダメージを受けた。" % [e.display_name, result["damage"]])
	popup(str(result["damage"]), player.pos, HURT_COLOR)
	audio.play("hit_player")
	if player.is_dead():
		show_game_over(e)


## ボスの遠距離攻撃。必ず当たるが、ふつうの攻撃より弱い。
func enemy_bolt(e: Actor) -> void:
	var damage := Combat.roll_damage(roundi(e.total_attack() * BOLT_POWER), player.total_defense(), rng)
	player.hp = maxi(player.hp - damage, 0)
	audio.play("magic_bolt")
	add_message("%sは闇の炎を放った。%d のダメージを受けた。" % [e.display_name, damage])
	popup(str(damage), player.pos, HURT_COLOR)
	if player.is_dead():
		show_game_over(e)


func show_clear() -> void:
	add_message("魔王を倒した！ダンジョンを踏破した！")
	audio.play_bgm("clear")
	show_result("魔王を倒した！", "ダンジョン踏破", true)


func show_game_over(killer: Actor) -> void:
	add_message("%sにやられてしまった…" % killer.display_name)
	audio.play("player_die")
	audio.play_bgm("game_over")
	show_result("やられてしまった…", "%sに倒された" % killer.display_name, false)


## リザルト画面。記録を保存して、塗り替えた項目には「新記録」と付ける。
func show_result(header: String, cause: String, cleared: bool) -> void:
	game_over = true
	inventory_menu.hide()
	var new_records := records.add_run(floor_number, kills, turn, cleared)
	var mark := func(key: String) -> String: return "  新記録！" if key in new_records else ""
	result_header.text = header
	var lines := [
		cause,
		"",
		"到達    地下%d階%s" % [floor_number, mark.call("floor")],
		"レベル  %d" % player.level,
		"ターン  %d%s" % [turn, mark.call("turns")],
		"倒した敵  %d体%s" % [kills, mark.call("kills")],
		"",
		"装備  %s / %s" % [
			player.inventory.weapon.display_name() if player.inventory.weapon else "なし",
			player.inventory.shield.display_name() if player.inventory.shield else "なし",
		],
	]
	result_body.text = "\n".join(lines)
	result_shown_at = Time.get_ticks_msec()
	result_panel.show()


func descend() -> void:
	if map.tile_at(player.pos) != Dungeon.Tile.STAIRS:
		add_message("ここに階段はない。")
		audio.play("error")
		return
	floor_number += 1
	audio.play("stairs_down")
	enter_floor()


func enemy_at(pos: Vector2i) -> Actor:
	for e in enemies:
		if e.pos == pos:
			return e
	return null


func update_view() -> void:
	visible_cells = Fov.compute(map, player.pos)
	for cell in visible_cells:
		if map.in_bounds(cell):
			map_view.explored[cell] = true
	map_view.visible_cells = visible_cells
	map_view.queue_redraw()
	player_sprite.position = Vector2(player.pos * TILE_SIZE)
	player_sprite.texture = PLAYER_FRAMES[player_frame]
	for e in enemies:
		e.node.position = Vector2(e.pos * TILE_SIZE)
		e.node.visible = visible_cells.has(e.pos)
	# アイテムは一度見た場所なら、今見えていなくても表示しておく
	for item in floor_items:
		item.node.visible = map_view.explored.has(item.pos)
	status_label.text = "B%dF   Lv%d   HP %d/%d   攻%d 防%d" % [floor_number, player.level, player.hp, player.max_hp, player.total_attack(), player.total_defense()]
	for e in enemies:
		if e.kind == "boss":
			status_label.text += "   %s %d/%d" % [e.display_name, e.hp, e.max_hp]


func add_message(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > LOG_LINES:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


## 攻撃のとき、絵を相手の方へ少し突き出して戻す
func bump(sprite: Sprite2D, dir: Vector2i) -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "offset", Vector2(dir) * 4, 0.05)
	tween.tween_property(sprite, "offset", Vector2.ZERO, 0.08)


## ダメージの数字などを、マスの上にふわっと出して消す
func popup(text: String, cell: Vector2i, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	effects.add_child(label)
	# 文字の幅に合わせて、マスの真上に来るように置く
	label.size = label.get_minimum_size()
	label.position = Vector2(cell * TILE_SIZE) + Vector2((TILE_SIZE - label.size.x) / 2, -8)
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 8, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## 敵の待機アニメーション（2 コマを交互に）
func _on_idle_timer() -> void:
	for e in enemies:
		var frames: Array = enemy_textures[e.kind]
		e.node.texture = frames[1] if e.node.texture == frames[0] else frames[0]
