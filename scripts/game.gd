## ゲーム本体：フロアの進行、プレイヤーの移動、画面の更新。
extends Node2D

const TILE_SIZE := 16
const LOG_LINES := 3

## キー → 移動方向（8 方向）。斜めは Q/E/Z/C かテンキー。
const MOVE_KEYS := {
	KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1), KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0),
	KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1), KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0),
	KEY_Q: Vector2i(-1, -1), KEY_E: Vector2i(1, -1), KEY_Z: Vector2i(-1, 1), KEY_C: Vector2i(1, 1),
	KEY_KP_8: Vector2i(0, -1), KEY_KP_2: Vector2i(0, 1), KEY_KP_4: Vector2i(-1, 0), KEY_KP_6: Vector2i(1, 0),
	KEY_KP_7: Vector2i(-1, -1), KEY_KP_9: Vector2i(1, -1), KEY_KP_1: Vector2i(-1, 1), KEY_KP_3: Vector2i(1, 1),
}
const PLAYER_FRAMES := [
	preload("res://assets/placeholder/player_0.png"),
	preload("res://assets/placeholder/player_1.png"),
]

## 0 以外にすると毎回同じダンジョンになる（確認用）
@export var fixed_seed := 0

var rng := RandomNumberGenerator.new()
var floor_number := 1
var turn := 0
var map: Dungeon
var player_pos := Vector2i.ZERO
var player_frame := 0
var log_lines: Array[String] = []

@onready var map_view: Node2D = $MapView
@onready var player: Sprite2D = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var floor_label: Label = $HUD/TopBar/FloorLabel
@onready var log_label: Label = $HUD/LogPanel/LogLabel


func _ready() -> void:
	if fixed_seed != 0:
		rng.seed = fixed_seed
	else:
		rng.randomize()
	print("seed: ", rng.seed)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = Dungeon.WIDTH * TILE_SIZE
	camera.limit_bottom = Dungeon.HEIGHT * TILE_SIZE
	enter_floor()


func enter_floor() -> void:
	map = Dungeon.generate(rng)
	map_view.map = map
	map_view.explored = {}
	player_pos = map.start
	update_view()
	camera.reset_smoothing()
	add_message("地下%d階に着いた。" % floor_number)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var code := key.physical_keycode
	if MOVE_KEYS.has(code):
		# 押しっぱなしで歩き続けられるよう、キーリピートも受け付ける
		try_move(MOVE_KEYS[code])
	elif (code == KEY_ENTER or code == KEY_KP_ENTER) and not key.echo:
		descend()
	else:
		return
	get_viewport().set_input_as_handled()


func try_move(dir: Vector2i) -> bool:
	var target := player_pos + dir
	if not map.is_walkable(target):
		return false
	# 斜め移動は、壁の角をすり抜けられない
	if dir.x != 0 and dir.y != 0:
		if not map.is_walkable(player_pos + Vector2i(dir.x, 0)) or not map.is_walkable(player_pos + Vector2i(0, dir.y)):
			return false
	player_pos = target
	if dir.x != 0:
		player.flip_h = dir.x < 0
	player_frame ^= 1
	turn += 1
	update_view()
	if map.tile_at(player_pos) == Dungeon.Tile.STAIRS:
		add_message("階段がある。Enter で降りる。")
	return true


func descend() -> void:
	if map.tile_at(player_pos) != Dungeon.Tile.STAIRS:
		add_message("ここに階段はない。")
		return
	floor_number += 1
	enter_floor()


func update_view() -> void:
	var visible_cells := Fov.compute(map, player_pos)
	for cell in visible_cells:
		if map.in_bounds(cell):
			map_view.explored[cell] = true
	map_view.visible_cells = visible_cells
	map_view.queue_redraw()
	player.position = Vector2(player_pos * TILE_SIZE)
	player.texture = PLAYER_FRAMES[player_frame]
	floor_label.text = "B%dF    ターン %d" % [floor_number, turn]


func add_message(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > LOG_LINES:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
