## マップの描画。一度見た場所だけを描き、今見えていない場所は暗くする。
extends Node2D

const TILE_SIZE := 16
const FOG_COLOR := Color(0, 0, 0, 0.55)

var textures := {
	Dungeon.Tile.WALL: preload("res://assets/placeholder/wall.png"),
	Dungeon.Tile.FLOOR: preload("res://assets/placeholder/floor.png"),
	Dungeon.Tile.CORRIDOR: preload("res://assets/placeholder/corridor.png"),
	Dungeon.Tile.STAIRS: preload("res://assets/placeholder/stairs.png"),
}

var map: Dungeon
var explored := {}
var visible_cells := {}


func _draw() -> void:
	if map == null:
		return
	for cell in explored:
		var pos := Vector2(cell) * TILE_SIZE
		draw_texture(textures[map.tile_at(cell)], pos)
		if not visible_cells.has(cell):
			draw_rect(Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE)), FOG_COLOR)
