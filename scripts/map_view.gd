## マップの描画。一度見た場所だけを描き、今見えていない場所は暗くする。
extends Node2D

const TILE_SIZE := 16
const FOG_COLOR := Color(0, 0, 0, 0.55)
## 3 階ごとにタイルの見た目が変わる：石（1〜3階）、苔の洞窟（4〜6階）、魔界（7階〜）
const THEMES := [
	{"until": 3, "dir": "res://assets/art/"},
	{"until": 6, "dir": "res://assets/art/tiles_cave/"},
	{"until": 999, "dir": "res://assets/art/tiles_abyss/"},
]
const TILE_FILES := {
	Dungeon.Tile.WALL: "wall.png",
	Dungeon.Tile.FLOOR: "floor.png",
	Dungeon.Tile.CORRIDOR: "corridor.png",
	Dungeon.Tile.STAIRS: "stairs.png",
}

var textures := {}
var map: Dungeon
var explored := {}
var visible_cells := {}


static func theme_dir(floor_number: int) -> String:
	for theme in THEMES:
		if floor_number <= theme["until"]:
			return theme["dir"]
	return THEMES[-1]["dir"]


func set_floor_theme(floor_number: int) -> void:
	var dir := theme_dir(floor_number)
	for tile in TILE_FILES:
		textures[tile] = load(dir + TILE_FILES[tile])


func _draw() -> void:
	if map == null:
		return
	for cell in explored:
		var pos := Vector2(cell) * TILE_SIZE
		draw_texture(textures[map.tile_at(cell)], pos)
		if not visible_cells.has(cell):
			draw_rect(Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE)), FOG_COLOR)
