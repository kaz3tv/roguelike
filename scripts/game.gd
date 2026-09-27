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
## 闇の炎・魔法の弾の威力（攻撃力に対する割合）
const BOLT_POWER := 0.6
## 遠くから撃つ魔法の名前
const BOLT_NAMES := {"boss": "闇の炎", "caster": "魔法の弾"}
## 火の精霊が倒れたときの爆発のダメージ（まわり 8 マス）
const EXPLOSION_DAMAGE := 8
## 眠っている敵の色
const SLEEP_TINT := Color(0.55, 0.6, 1.0)
## リザルトを出してから Enter を受け付けるまでの時間（ミリ秒）
const RESULT_INPUT_DELAY_MS := 800

## 1 マス歩くのにかける時間（秒）
const MOVE_TIME := 0.07
## 階段で暗くなる・明るくなる時間（秒）
const FADE_OUT_TIME := 0.2
const FADE_IN_TIME := 0.3
## 暗転中に階数を見せておく時間（秒）
const FLOOR_BANNER_TIME := 0.4

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
## ゲームパッドの方向 → 同じ働きのキー（斜めはテンキー）
const PAD_DIR_KEYS := {
	Vector2i(0, -1): KEY_UP, Vector2i(0, 1): KEY_DOWN, Vector2i(-1, 0): KEY_LEFT, Vector2i(1, 0): KEY_RIGHT,
	Vector2i(-1, -1): KEY_KP_7, Vector2i(1, -1): KEY_KP_9, Vector2i(-1, 1): KEY_KP_1, Vector2i(1, 1): KEY_KP_3,
}
## 持ち物画面を開くキー
const MENU_KEYS := [KEY_I, KEY_TAB]
## 素材のクレジット（タイトル画面の C キーで表示）。素材を差し替えたらここも直す
const CREDITS_PATH := "res://assets/credits.txt"
## ミニマップを出す／隠すキー
const MINIMAP_KEY := KEY_N
const PLAYER_FRAMES := [
	preload("res://assets/art/player_0.png"),
	preload("res://assets/art/player_1.png"),
]
const DAMAGE_COLOR := Color("#ffcd75")
const HURT_COLOR := Color("#ef7d57")

## 0 以外にすると毎回同じダンジョンになる（確認用）
@export var fixed_seed := 0

var rng := RandomNumberGenerator.new()
var pad := PadInput.new()
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
## 暗転などの演出中は操作を受け付けない
var busy := false
## true のあいだは、絵をなめらかに動かさずにその場所へ置く（階に着いたときなど）
var snap_sprites := true
## タイトル画面を出しているあいだ true
var in_title := false
## タイトルで選んでいる項目（中断セーブがあるときだけ使う）。0: つづきから 1: はじめから
var title_choice := 0
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
@onready var suspend_panel: Control = $HUD/Suspend
@onready var credits_panel: Control = $HUD/Title/Credits
@onready var credits_label: Label = $HUD/Title/Credits/Label
@onready var minimap = $HUD/Minimap
@onready var fade: Control = $HUD/Fade
@onready var fade_label: Label = $HUD/Fade/Label


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
	suspend_panel.hide()
	title_panel.show()
	title_choice = 0
	refresh_title_menu()
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


func refresh_title_menu() -> void:
	if not SaveGame.exists():
		title_start.text = "Enter / A ではじめる"
		return
	var names := ["つづきから", "はじめから"]
	var lines := []
	for i in names.size():
		lines.append(("＞" if i == title_choice else "　") + names[i])
	title_start.text = "\n".join(lines)


func title_input(code: Key) -> void:
	if credits_panel.visible:
		if code in [KEY_ESCAPE, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_C]:
			audio.play("menu_cancel")
			credits_panel.hide()
		return
	if code == KEY_C:
		audio.play("menu_select")
		credits_label.text = FileAccess.get_file_as_string(CREDITS_PATH)
		credits_panel.show()
		return
	var has_save := SaveGame.exists()
	if has_save and (code in [KEY_UP, KEY_W, KEY_KP_8, KEY_DOWN, KEY_S, KEY_KP_2]):
		title_choice = 1 - title_choice
		audio.play("menu_move")
		refresh_title_menu()
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		audio.play("menu_select")
		if has_save and title_choice == 0:
			continue_run()
		else:
			# はじめからを選ぶと、中断セーブは消える
			SaveGame.delete()
			start_run()


func start_run() -> void:
	start_run_state()
	enter_floor()


## 新しく始めるときも続きから始めるときも共通の、画面と状態の片付け
func start_run_state() -> void:
	player = Actor.new_player()
	player.node = player_sprite
	floor_number = 1
	turn = 0
	kills = 0
	game_over = false
	in_title = false
	title_panel.hide()
	suspend_panel.hide()
	result_panel.hide()
	inventory_menu.hide()
	log_lines.clear()


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
	snap_sprites = true
	update_view()
	snap_sprites = false
	camera.reset_smoothing()
	add_message("地下%d階に着いた。" % floor_number)
	if is_boss_floor:
		add_message("まがまがしい気配がする…魔王だ！")
		audio.play_bgm("boss")
	else:
		audio.play_bgm(audio.bgm_for_floor(floor_number))
	# 階に着くたびに自動で中断セーブしておく（ブラウザのタブを閉じられたときの備え）
	save_run()


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
	var handled := false
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed:
			handled = handle_key(key.physical_keycode, key.echo)
	elif event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if PadInput.is_dpad(button.button_index):
			# 十字キーは押している間ずっと歩けるよう、_process でまとめて扱う
			pad.set_button(button.button_index, button.pressed)
			handled = true
		elif button.pressed:
			var code := pad_button_key(button.button_index)
			if code != KEY_NONE:
				handled = handle_key(code, false)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		pad.set_axis(motion.axis, motion.axis_value)
	if handled:
		get_viewport().set_input_as_handled()


## ゲームパッドの十字キー・左スティックを、押しっぱなしも含めて方向キーとして扱う
func _process(delta: float) -> void:
	var step: Array = pad.update(delta)
	if step[0] != Vector2i.ZERO:
		handle_key(PAD_DIR_KEYS[step[0]], step[1])


## ゲームパッドのボタンを、同じ働きのキーに置きかえる。場面によって働きが変わるボタンもある
func pad_button_key(button: JoyButton) -> Key:
	match button:
		JOY_BUTTON_A:
			return KEY_ENTER
		JOY_BUTTON_B:
			return KEY_BACKSPACE
		JOY_BUTTON_X:
			# 持ち物画面では「置く」、それ以外は「その場で待つ」
			return KEY_X if inventory_menu.visible else KEY_SPACE
		JOY_BUTTON_Y:
			# タイトルでは「クレジット」、それ以外は「持ち物」
			return KEY_C if in_title else KEY_I
		JOY_BUTTON_START:
			return KEY_ESCAPE
		JOY_BUTTON_BACK:
			return MINIMAP_KEY
	return KEY_NONE


## キー 1 回分の処理。echo は押しっぱなしによるくり返し。処理したら true を返す
func handle_key(code: Key, echo: bool) -> bool:
	var is_enter := code == KEY_ENTER or code == KEY_KP_ENTER
	if busy:
		return true
	if in_title:
		if not echo:
			title_input(code)
		return true
	if game_over:
		if is_enter and not echo and Time.get_ticks_msec() - result_shown_at > RESULT_INPUT_DELAY_MS:
			audio.play("menu_select")
			show_title()
		return true
	if suspend_panel.visible:
		if is_enter and not echo:
			suspend_run()
		elif code in [KEY_ESCAPE, KEY_BACKSPACE] and not echo:
			audio.play("menu_cancel")
			suspend_panel.hide()
		return true
	if inventory_menu.visible:
		# 決定キーの押しっぱなしで連続して使ってしまわないようにする
		if not echo or code not in [KEY_ENTER, KEY_KP_ENTER, KEY_X]:
			inventory_menu.handle_key(code)
		return true
	if MOVE_KEYS.has(code):
		# 押しっぱなしで歩き続けられるよう、キーリピートも受け付ける
		player_step(MOVE_KEYS[code])
	elif code in WAIT_KEYS:
		end_player_turn()
	elif is_enter and not echo:
		descend()
	elif code in MENU_KEYS and not echo:
		audio.play("menu_select")
		inventory_menu.open(player.inventory)
	elif code == KEY_F9 and not echo and OS.is_debug_build() and floor_number < BOSS_FLOOR:
		# 確認用：エディタから起動したときだけ、F9 ですぐ次の階へ行ける
		floor_number += 1
		enter_floor()
	elif code == KEY_ESCAPE and not echo:
		audio.play("menu_select")
		suspend_panel.show()
	elif code == MINIMAP_KEY and not echo:
		minimap.visible = not minimap.visible
	elif code == KEY_M and not echo:
		audio.toggle_mute()
		add_message("音を消した。M でもとに戻る。" if audio.muted else "音を出した。")
	else:
		return false
	return true


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
			add_message("階段がある。Enter（A ボタン）で降りる。")
		pick_up()
	end_player_turn()


func player_attack(enemy: Actor, dir: Vector2i) -> void:
	bump(player_sprite, dir)
	enemy.sleep_turns = 0
	var result := Combat.attack(player, enemy, rng)
	if not result["hit"]:
		add_message("%sへの攻撃は外れた。" % enemy.display_name)
		audio.play("attack_miss")
		popup("MISS", enemy.pos, Color.WHITE)
		return
	audio.play("hit_enemy")
	if not enemy.is_dead():
		add_message("%sに %d のダメージ。" % [enemy.display_name, result["damage"]])
	after_enemy_hit(enemy, result["damage"])


## 敵に damage を与える（巻物や爆発など、攻撃の命中判定がないもの）
func hurt_enemy(enemy: Actor, damage: int) -> void:
	enemy.hp = maxi(enemy.hp - damage, 0)
	after_enemy_hit(enemy, damage)


## 敵の HP が減ったあとの共通の処理：数字と点滅、目を覚ます、倒れる、分裂する
func after_enemy_hit(enemy: Actor, damage: int) -> void:
	popup(str(damage), enemy.pos, DAMAGE_COLOR)
	flash(enemy.node, DAMAGE_COLOR)
	enemy.sleep_turns = 0
	if enemy.is_dead():
		kill_enemy(enemy)
	elif enemy.behavior == "split":
		split_enemy(enemy)


## 大スライムの分裂：となりの空いたマスに、同じ HP の分身を出す。分身は分裂しない
func split_enemy(enemy: Actor) -> void:
	var first := rng.randi_range(0, MonsterAI.DIRS.size() - 1)
	for i in MonsterAI.DIRS.size():
		var dir := MonsterAI.DIRS[(first + i) % MonsterAI.DIRS.size()]
		var target := enemy.pos + dir
		if map.can_step(enemy.pos, dir) and enemy_at(target) == null and target != player.pos:
			var clone := spawn_enemy(enemy.kind, target)
			clone.hp = enemy.hp
			clone.xp = 1
			clone.behavior = "chase"
			add_message("%sが分裂した！" % enemy.display_name)
			return


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
	if enemy.behavior == "explode":
		explode(enemy)


## 火の精霊の爆発：まわり 8 マスのプレイヤーと敵にダメージ
func explode(source: Actor) -> void:
	add_message("%sが爆発した！" % source.display_name)
	audio.play("scroll_fire")
	popup("BOOM", source.pos, HURT_COLOR)
	for e in enemies.duplicate():
		if e in enemies and chebyshev(e.pos - source.pos) <= 1:
			hurt_enemy(e, EXPLOSION_DAMAGE)
	if not game_over and chebyshev(player.pos - source.pos) <= 1:
		add_message("爆発に巻き込まれた。%d のダメージを受けた。" % EXPLOSION_DAMAGE)
		damage_player(EXPLOSION_DAMAGE, "%sの爆発" % source.display_name)


static func chebyshev(d: Vector2i) -> int:
	return maxi(absi(d.x), absi(d.y))


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
			inv.remove(item)
			audio.play(item.data()["sound"])
			match item.data()["effect"]:
				"heal":
					var healed := mini(item.data()["power"], player.max_hp - player.hp)
					player.hp += healed
					add_message("%sを飲んだ。HPが %d 回復した。" % [item.display_name(), healed])
					popup("+%d" % healed, player.pos, Color("#a7f070"))
				"strength":
					player.attack += item.data()["power"]
					add_message("%sを飲んだ。力がみなぎり、攻撃力が %d 上がった。" % [item.display_name(), item.data()["power"]])
					popup("ATK UP", player.pos, Color("#a7f070"))
		"scroll":
			inv.remove(item)
			add_message("%sを読んだ。" % item.display_name())
			audio.play(item.data()["sound"])
			read_scroll(item)
		"amulet":
			# 持っているだけで効くので、使ってもターンは進まない
			add_message("%sは持っているだけで効き目がある。" % item.display_name())
			return
	end_player_turn()


func read_scroll(item: Item) -> void:
	match item.data()["effect"]:
		"fire":
			var targets := enemies.filter(func(e: Actor) -> bool: return visible_cells.has(e.pos))
			if targets.is_empty():
				add_message("しかし、まわりに敵はいなかった。")
			for e: Actor in targets:
				if e in enemies:
					hurt_enemy(e, item.data()["power"])
		"sleep":
			var targets := enemies.filter(func(e: Actor) -> bool: return visible_cells.has(e.pos))
			if targets.is_empty():
				add_message("しかし、まわりに敵はいなかった。")
			for e: Actor in targets:
				if e.kind == "boss":
					add_message("%sには効かなかった。" % e.display_name)
					continue
				e.sleep_turns = item.data()["power"]
				popup("Zz", e.pos, SLEEP_TINT)
				add_message("%sは眠ってしまった。" % e.display_name)
		"thunder":
			var nearest: Actor = null
			for e in enemies:
				if visible_cells.has(e.pos) and (nearest == null or chebyshev(e.pos - player.pos) < chebyshev(nearest.pos - player.pos)):
					nearest = e
			if nearest == null:
				add_message("しかし、まわりに敵はいなかった。")
			else:
				add_message("%sに雷が落ちた！" % nearest.display_name)
				hurt_enemy(nearest, item.data()["power"])
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
	# 自分の行動（爆発など）で倒れていたら、敵はもう動かない
	if game_over:
		update_view()
		return
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
		if e.sleep_turns > 0:
			e.sleep_turns -= 1
			continue
		if e.behavior == "slow":
			# 2 ターンに 1 回だけ動く
			e.rested = not e.rested
			if e.rested:
				continue
		# 速い敵は 2 回まで動ける。攻撃したらそこで終わり（攻撃は 1 回だけ）
		for step in (2 if e.behavior == "fast" else 1):
			var action := MonsterAI.decide(map, e, player.pos, visible_cells.has(e.pos), occupied, rng)
			match action["type"]:
				"attack":
					enemy_attack(e)
				"bolt":
					enemy_bolt(e)
				"arrow":
					enemy_arrow(e)
				"move":
					occupied.erase(e.pos)
					e.pos += action["dir"]
					occupied[e.pos] = true
					if action["dir"].x != 0:
						e.node.flip_h = action["dir"].x < 0
			if game_over:
				return
			if action["type"] != "move":
				break


func enemy_attack(e: Actor) -> void:
	bump(e.node, player.pos - e.pos)
	var result := Combat.attack(e, player, rng)
	if not result["hit"]:
		add_message("%sの攻撃は外れた。" % e.display_name)
		audio.play("enemy_attack")
		popup("MISS", player.pos, Color.WHITE)
		return
	add_message("%sの攻撃。%d のダメージを受けた。" % [e.display_name, result["damage"]])
	audio.play("hit_player")
	after_player_hit(result["damage"], e.display_name)


## 弓兵の矢。ふつうの攻撃と同じように当たり外れがある
func enemy_arrow(e: Actor) -> void:
	audio.play("attack_swing")
	var result := Combat.attack(e, player, rng)
	if not result["hit"]:
		add_message("%sの矢は外れた。" % e.display_name)
		popup("MISS", player.pos, Color.WHITE)
		return
	add_message("%sの矢が当たった。%d のダメージを受けた。" % [e.display_name, result["damage"]])
	audio.play("hit_player")
	after_player_hit(result["damage"], e.display_name)


## プレイヤーに damage を与える（命中判定がないもの）
func damage_player(damage: int, killer_name: String) -> void:
	player.hp = maxi(player.hp - damage, 0)
	after_player_hit(damage, killer_name)


## プレイヤーの HP が減ったあと。倒れていたら、復活の首飾りがあれば生き返り、なければゲームオーバー
func after_player_hit(damage: int, killer_name: String) -> void:
	popup(str(damage), player.pos, HURT_COLOR)
	hurt_effect()
	if not player.is_dead():
		return
	var amulet := find_item_of_type("amulet")
	if amulet:
		player.inventory.remove(amulet)
		player.hp = maxi(player.max_hp / 2, 1)
		add_message("%sが砕け散り、よみがえった！" % amulet.display_name())
		audio.play("level_up")
		popup("REVIVE", player.pos, Color("#a7f070"))
		return
	show_game_over(killer_name)


func find_item_of_type(type: String) -> Item:
	for item in player.inventory.items:
		if item.type() == type:
			return item
	return null


## 魔王と魔法使いの遠距離攻撃。必ず当たるが、ふつうの攻撃より弱い。
func enemy_bolt(e: Actor) -> void:
	var damage := Combat.roll_damage(roundi(e.total_attack() * BOLT_POWER), player.total_defense(), rng)
	audio.play("magic_bolt")
	add_message("%sは%sを放った。%d のダメージを受けた。" % [e.display_name, BOLT_NAMES[e.behavior], damage])
	damage_player(damage, e.display_name)


func show_clear() -> void:
	add_message("魔王を倒した！ダンジョンを踏破した！")
	audio.play_bgm("clear")
	show_result("魔王を倒した！", "ダンジョン踏破", true)


func show_game_over(killer_name: String) -> void:
	add_message("%sにやられてしまった…" % killer_name)
	audio.play("player_die")
	audio.play_bgm("game_over")
	show_result("やられてしまった…", "%sに倒された" % killer_name, false)


## リザルト画面。記録を保存して、塗り替えた項目には「新記録」と付ける。
func show_result(header: String, cause: String, cleared: bool) -> void:
	game_over = true
	inventory_menu.hide()
	suspend_panel.hide()
	SaveGame.delete()
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
	audio.play("stairs_down")
	# 暗転 → 次の階を作る → 階数を見せてから明るくする
	busy = true
	fade_label.text = ""
	fade.modulate.a = 0.0
	fade.show()
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, FADE_OUT_TIME)
	await tween.finished
	floor_number += 1
	enter_floor()
	fade_label.text = "地下%d階" % floor_number
	await get_tree().create_timer(FLOOR_BANNER_TIME).timeout
	tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, FADE_IN_TIME)
	await tween.finished
	fade.hide()
	busy = false


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
	move_sprite(player_sprite, player.pos)
	player_sprite.texture = PLAYER_FRAMES[player_frame]
	for e in enemies:
		move_sprite(e.node, e.pos)
		e.node.visible = visible_cells.has(e.pos)
		e.node.self_modulate = SLEEP_TINT if e.sleep_turns > 0 else Color.WHITE
	# アイテムは一度見た場所なら、今見えていなくても表示しておく
	for item in floor_items:
		item.node.visible = map_view.explored.has(item.pos)
	status_label.text = "B%dF   Lv%d   HP %d/%d   攻%d 防%d" % [floor_number, player.level, player.hp, player.max_hp, player.total_attack(), player.total_defense()]
	for e in enemies:
		if e.kind == "boss":
			status_label.text += "   %s %d/%d" % [e.display_name, e.hp, e.max_hp]
	update_minimap()


func update_minimap() -> void:
	minimap.map = map
	minimap.explored = map_view.explored
	minimap.visible_cells = visible_cells
	minimap.player_pos = player.pos
	minimap.enemy_cells.assign(enemies.map(func(e: Actor) -> Vector2i: return e.pos))
	minimap.item_cells.assign(floor_items.map(func(item: Item) -> Vector2i: return item.pos))
	minimap.queue_redraw()


## 絵を cell の場所へ動かす。隣のマスならなめらかに、遠ければ（ワープなど）すぐ置く。
func move_sprite(sprite: Sprite2D, cell: Vector2i) -> void:
	var target := Vector2(cell * TILE_SIZE)
	if sprite.has_meta("move_tween"):
		var old_tween: Tween = sprite.get_meta("move_tween")
		if old_tween.is_valid():
			old_tween.kill()
	if snap_sprites or sprite.position.distance_to(target) > TILE_SIZE * 1.5:
		sprite.position = target
		return
	if sprite.position == target:
		return
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "position", target, MOVE_TIME)
	sprite.set_meta("move_tween", tween)


## 攻撃を受けたとき：絵を赤く光らせて、画面を少し揺らす
func hurt_effect() -> void:
	flash(player_sprite, HURT_COLOR)
	var tween := create_tween()
	for i in 4:
		var shake := Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2)).round()
		tween.tween_property(camera, "offset", shake, 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.03)


## 絵を一瞬 color に染めて、もとの色に戻す
func flash(sprite: Sprite2D, color: Color) -> void:
	sprite.modulate = color
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)


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


## ゲームを閉じるときは、遊んでいる途中なら中断セーブする
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_playing():
		save_run()


func is_playing() -> bool:
	return not in_title and not game_over and player != null


## 中断してタイトルに戻る
func suspend_run() -> void:
	save_run()
	audio.play("menu_select")
	show_title()


func save_run() -> void:
	SaveGame.write(to_save_data())


func to_save_data() -> Dictionary:
	return {
		"floor": floor_number,
		"turn": turn,
		"kills": kills,
		"rng_seed": rng.seed,
		"rng_state": rng.state,
		"map": map.to_dict(),
		"explored": map_view.explored.keys(),
		"player": player.to_dict(),
		"enemies": enemies.map(func(e: Actor) -> Dictionary: return e.to_dict()),
		"items": floor_items.map(func(item: Item) -> Dictionary: return item.to_dict()),
		"log": log_lines.duplicate(),
	}


## 中断セーブから続きを始める。読めたらセーブは消す（やり直し防止）。
func continue_run() -> void:
	var data := SaveGame.read()
	SaveGame.delete()
	if data.is_empty():
		start_run()
		add_message("中断データを読めなかったので、はじめから始めた。")
		return
	start_run_state()
	floor_number = data["floor"]
	turn = data["turn"]
	kills = data["kills"]
	rng.seed = data["rng_seed"]
	rng.state = data["rng_state"]
	map = Dungeon.from_dict(data["map"])
	map_view.map = map
	map_view.set_floor_theme(floor_number)
	map_view.explored = {}
	for cell in data["explored"]:
		map_view.explored[cell] = true
	var saved_player := Actor.from_dict(data["player"])
	saved_player.node = player_sprite
	player = saved_player
	clear_floor_objects()
	for d in data["enemies"]:
		var e := spawn_enemy(d["kind"], d["pos"])
		e.hp = d["hp"]
	for d in data["items"]:
		var item := Item.from_dict(d)
		place_item(item, item.pos)
	log_lines.assign(data["log"])
	add_message("冒険の続きを始めた。")
	snap_sprites = true
	update_view()
	snap_sprites = false
	camera.reset_smoothing()
	audio.play_bgm("boss" if floor_number == BOSS_FLOOR else audio.bgm_for_floor(floor_number))
