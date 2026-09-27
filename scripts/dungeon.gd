## ダンジョン1フロア分のデータと生成処理。
## マップを 3x3 の区画に分け、4〜8 区画に部屋を置いて通路でつなぐ（部屋と通路型）。
class_name Dungeon
extends RefCounted

enum Tile { WALL, FLOOR, CORRIDOR, STAIRS }

const WIDTH := 57
const HEIGHT := 36
const GRID_COLS := 3
const GRID_ROWS := 3

var tiles := PackedInt32Array()
## 部屋の番号（部屋の床なら 0 以上、それ以外は -1）。視界の計算に使う。
var room_of := PackedInt32Array()
var rooms: Array[Rect2i] = []
var start := Vector2i.ZERO
var stairs := Vector2i.ZERO
## ボス部屋でボスが最初にいる場所
var boss_pos := Vector2i(-1, -1)


## 10 階のボス部屋：大きな部屋が 1 つだけ。下の端から入り、上の端にボスがいる。階段はない。
static func generate_boss_room() -> Dungeon:
	var d := Dungeon.new()
	d.tiles.resize(WIDTH * HEIGHT)
	d.tiles.fill(Tile.WALL)
	d.room_of.resize(WIDTH * HEIGHT)
	d.room_of.fill(-1)
	var room := Rect2i(16, 9, 25, 18)
	d.rooms.append(room)
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			d.tiles[d._index(Vector2i(x, y))] = Tile.FLOOR
			d.room_of[d._index(Vector2i(x, y))] = 0
	var center_x := room.position.x + room.size.x / 2
	d.start = Vector2i(center_x, room.end.y - 2)
	d.boss_pos = Vector2i(center_x, room.position.y + 2)
	d.stairs = Vector2i(-1, -1)
	return d


static func generate(rng: RandomNumberGenerator) -> Dungeon:
	var d := Dungeon.new()
	d._build(rng)
	return d


func tile_at(p: Vector2i) -> Tile:
	if not in_bounds(p):
		return Tile.WALL
	return tiles[_index(p)] as Tile


func room_at(p: Vector2i) -> int:
	if not in_bounds(p):
		return -1
	return room_of[_index(p)]


func is_walkable(p: Vector2i) -> bool:
	return tile_at(p) != Tile.WALL


## from から dir へ 1 歩進めるか。斜めは壁の角をすり抜けられない（攻撃も同じ）。
func can_step(from: Vector2i, dir: Vector2i) -> bool:
	if not is_walkable(from + dir):
		return false
	if dir.x != 0 and dir.y != 0:
		return is_walkable(from + Vector2i(dir.x, 0)) and is_walkable(from + Vector2i(0, dir.y))
	return true


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < WIDTH and p.y < HEIGHT


func _index(p: Vector2i) -> int:
	return p.y * WIDTH + p.x


func _build(rng: RandomNumberGenerator) -> void:
	tiles.resize(WIDTH * HEIGHT)
	tiles.fill(Tile.WALL)
	room_of.resize(WIDTH * HEIGHT)
	room_of.fill(-1)

	var cell_w := WIDTH / GRID_COLS
	var cell_h := HEIGHT / GRID_ROWS
	var cells: Array[Vector2i] = []
	for cy in GRID_ROWS:
		for cx in GRID_COLS:
			cells.append(Vector2i(cx, cy))
	_shuffle(cells, rng)
	var room_count := rng.randi_range(4, 8)

	for i in room_count:
		var cell := cells[i]
		# 区画の端は壁として残し、隣の区画の部屋とくっつかないようにする
		var w := rng.randi_range(5, cell_w - 4)
		var h := rng.randi_range(4, cell_h - 4)
		var x := cell.x * cell_w + rng.randi_range(2, cell_w - w - 2)
		var y := cell.y * cell_h + rng.randi_range(2, cell_h - h - 2)
		var room := Rect2i(x, y, w, h)
		rooms.append(room)
		for yy in range(y, y + h):
			for xx in range(x, x + w):
				tiles[_index(Vector2i(xx, yy))] = Tile.FLOOR
				room_of[_index(Vector2i(xx, yy))] = i

	# 全部屋がつながるように、つながった部屋のうち一番近いものへ順に通路を引く
	var linked: Array[int] = [0]
	var rest: Array[int] = []
	for i in range(1, rooms.size()):
		rest.append(i)
	while not rest.is_empty():
		var best_from := -1
		var best_to := -1
		var best_dist := 1 << 30
		for r in rest:
			for l in linked:
				var dist := _distance(rooms[r], rooms[l])
				if dist < best_dist:
					best_dist = dist
					best_from = l
					best_to = r
		_connect(rooms[best_from], rooms[best_to], rng)
		linked.append(best_to)
		rest.erase(best_to)

	# 回り道ができるよう、ときどき余分な通路を 1 本足す
	if rooms.size() >= 4 and rng.randf() < 0.6:
		var a := rng.randi_range(0, rooms.size() - 1)
		var b := (a + rng.randi_range(1, rooms.size() - 1)) % rooms.size()
		_connect(rooms[a], rooms[b], rng)

	start = _random_floor_in(rooms[0], rng)
	stairs = _random_floor_in(rooms[rng.randi_range(1, rooms.size() - 1)], rng)
	tiles[_index(stairs)] = Tile.STAIRS


func _connect(a: Rect2i, b: Rect2i, rng: RandomNumberGenerator) -> void:
	# L 字の通路。どちらの角で曲がるかはランダム。
	var ca := _center(a)
	var cb := _center(b)
	if rng.randf() < 0.5:
		for x in range(mini(ca.x, cb.x), maxi(ca.x, cb.x) + 1):
			_carve(Vector2i(x, ca.y))
		for y in range(mini(ca.y, cb.y), maxi(ca.y, cb.y) + 1):
			_carve(Vector2i(cb.x, y))
	else:
		for y in range(mini(ca.y, cb.y), maxi(ca.y, cb.y) + 1):
			_carve(Vector2i(ca.x, y))
		for x in range(mini(ca.x, cb.x), maxi(ca.x, cb.x) + 1):
			_carve(Vector2i(x, cb.y))


func _carve(p: Vector2i) -> void:
	if tiles[_index(p)] == Tile.WALL:
		tiles[_index(p)] = Tile.CORRIDOR


static func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


static func _distance(a: Rect2i, b: Rect2i) -> int:
	var d := _center(a) - _center(b)
	return absi(d.x) + absi(d.y)


static func _random_floor_in(r: Rect2i, rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	# Array.shuffle() はシードを指定できないので、rng を使って自前で混ぜる
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
