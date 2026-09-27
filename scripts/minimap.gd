## 画面右上の小さな地図。1 マスを 1 ドットで描く。一度見た場所だけが出る。
extends Control

const WALL_COLOR := Color("#333c57")
const FLOOR_COLOR := Color("#94b0c2")
const CORRIDOR_COLOR := Color("#566c86")
const STAIRS_COLOR := Color("#ffcd75")
const ITEM_COLOR := Color("#73eff7")
const ENEMY_COLOR := Color("#ef7d57")
const PLAYER_COLOR := Color.WHITE
const BACK_COLOR := Color(0, 0, 0, 0.5)

var map: Dungeon
var explored := {}
var visible_cells := {}
var player_pos := Vector2i.ZERO
var enemy_cells: Array[Vector2i] = []
var item_cells: Array[Vector2i] = []
## プレイヤーの点を点滅させる
var blink := true


func _ready() -> void:
	size = Vector2(Dungeon.WIDTH + 2, Dungeon.HEIGHT + 2)
	var timer := Timer.new()
	timer.wait_time = 0.3
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		blink = not blink
		queue_redraw())
	add_child(timer)


func _draw() -> void:
	if map == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BACK_COLOR)
	for cell in explored:
		var color: Color
		match map.tile_at(cell):
			Dungeon.Tile.WALL:
				continue
			Dungeon.Tile.FLOOR:
				color = FLOOR_COLOR
			Dungeon.Tile.CORRIDOR:
				color = CORRIDOR_COLOR
			Dungeon.Tile.STAIRS:
				color = STAIRS_COLOR
		_dot(cell, color)
	for cell in item_cells:
		if explored.has(cell):
			_dot(cell, ITEM_COLOR)
	for cell in enemy_cells:
		if visible_cells.has(cell):
			_dot(cell, ENEMY_COLOR)
	if blink:
		_dot(player_pos, PLAYER_COLOR)


func _dot(cell: Vector2i, color: Color) -> void:
	draw_rect(Rect2(Vector2(cell) + Vector2.ONE, Vector2.ONE), color)
