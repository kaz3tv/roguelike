## ゲーム本体：フロアの進行、ターンの処理、画面の更新。
extends Node2D

const TILE_SIZE := 16
const LOG_LINES := 3
## 何ターンごとに HP が 1 回復するか
const REGEN_TURNS := 6
## 1 フロアの敵の数 = ENEMY_BASE_MIN〜ENEMY_BASE_MAX + 階数/3
const ENEMY_BASE_MIN := 3
const ENEMY_BASE_MAX := 5

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
var visible_cells := {}
var player_frame := 0
var game_over := false
var log_lines: Array[String] = []
var enemy_textures := {}

@onready var map_view: Node2D = $MapView
@onready var enemy_layer: Node2D = $Enemies
@onready var effects: Node2D = $Effects
@onready var player_sprite: Sprite2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var status_label: Label = $HUD/TopBar/StatusLabel
@onready var log_label: Label = $HUD/LogPanel/LogLabel
@onready var game_over_panel: Control = $HUD/GameOver
@onready var game_over_label: Label = $HUD/GameOver/Label


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
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = Dungeon.WIDTH * TILE_SIZE
	camera.limit_bottom = Dungeon.HEIGHT * TILE_SIZE
	$IdleTimer.timeout.connect(_on_idle_timer)
	start_run()


func start_run() -> void:
	player = Actor.new_player()
	player.node = player_sprite
	floor_number = 1
	turn = 0
	kills = 0
	game_over = false
	game_over_panel.hide()
	log_lines.clear()
	enter_floor()


func enter_floor() -> void:
	map = Dungeon.generate(rng)
	map_view.map = map
	map_view.set_floor_theme(floor_number)
	map_view.explored = {}
	player.pos = map.start
	spawn_enemies()
	update_view()
	camera.reset_smoothing()
	add_message("地下%d階に着いた。" % floor_number)


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
		var e := EnemyData.create(kinds[rng.randi_range(0, kinds.size() - 1)])
		e.pos = pos
		e.node = Sprite2D.new()
		e.node.centered = false
		e.node.texture = enemy_textures[e.kind][0]
		e.node.position = Vector2(pos * TILE_SIZE)
		enemy_layer.add_child(e.node)
		enemies.append(e)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var code := key.physical_keycode
	var is_enter := code == KEY_ENTER or code == KEY_KP_ENTER
	if game_over:
		if is_enter and not key.echo:
			start_run()
		get_viewport().set_input_as_handled()
		return
	if MOVE_KEYS.has(code):
		# 押しっぱなしで歩き続けられるよう、キーリピートも受け付ける
		player_step(MOVE_KEYS[code])
	elif code in WAIT_KEYS:
		end_player_turn()
	elif is_enter and not key.echo:
		descend()
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
	end_player_turn()


func player_attack(enemy: Actor, dir: Vector2i) -> void:
	bump(player_sprite, dir)
	var result := Combat.attack(player, enemy, rng)
	if not result["hit"]:
		add_message("%sへの攻撃は外れた。" % enemy.display_name)
		popup("MISS", enemy.pos, Color.WHITE)
		return
	popup(str(result["damage"]), enemy.pos, DAMAGE_COLOR)
	if enemy.is_dead():
		kills += 1
		add_message("%sを倒した。経験値 %d。" % [enemy.display_name, enemy.xp])
		enemies.erase(enemy)
		enemy.node.queue_free()
		var levels := Combat.gain_exp(player, enemy.xp)
		if levels > 0:
			add_message("レベル%dに上がった！" % player.level)
			popup("LEVEL UP", player.pos, Color("#a7f070"))
	else:
		add_message("%sに %d のダメージ。" % [enemy.display_name, result["damage"]])


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
		popup("MISS", player.pos, Color.WHITE)
		return
	add_message("%sの攻撃。%d のダメージを受けた。" % [e.display_name, result["damage"]])
	popup(str(result["damage"]), player.pos, HURT_COLOR)
	if player.is_dead():
		show_game_over(e)


func show_game_over(killer: Actor) -> void:
	game_over = true
	add_message("%sにやられてしまった…" % killer.display_name)
	game_over_label.text = "やられてしまった…\n\n地下%d階  レベル%d\n倒した敵  %d体\n\nEnter でもう一度" % [floor_number, player.level, kills]
	game_over_panel.show()


func descend() -> void:
	if map.tile_at(player.pos) != Dungeon.Tile.STAIRS:
		add_message("ここに階段はない。")
		return
	floor_number += 1
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
	status_label.text = "B%dF   Lv%d   HP %d/%d" % [floor_number, player.level, player.hp, player.max_hp]


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
