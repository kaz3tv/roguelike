## ダンジョン生成と視界のテスト。
## 実行方法: godot --headless --path . -s tests/run_tests.gd
extends SceneTree

var failures := 0


func _init() -> void:
	test_all_rooms_reachable()
	test_border_is_wall()
	test_same_seed_same_map()
	test_fov()
	if failures == 0:
		print("すべてのテストに合格しました")
	quit(1 if failures > 0 else 0)


func check(cond: bool, message: String) -> void:
	if not cond:
		failures += 1
		push_error("失敗: " + message)


func make(seed_value: int) -> Dungeon:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Dungeon.generate(rng)


func reachable(map: Dungeon, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = p + dir
			if not seen.has(n) and map.is_walkable(n):
				seen[n] = true
				queue.append(n)
	return seen


func test_all_rooms_reachable() -> void:
	# 500 通りのシードで、すべての部屋と階段にスタートから歩いて行ける
	for s in range(1, 501):
		var map := make(s)
		check(map.rooms.size() >= 4 and map.rooms.size() <= 8, "seed %d: 部屋数 %d" % [s, map.rooms.size()])
		var seen := reachable(map, map.start)
		check(seen.has(map.stairs), "seed %d: 階段に届かない" % s)
		check(map.start != map.stairs, "seed %d: スタートと階段が同じ場所" % s)
		for room in map.rooms:
			check(seen.has(room.get_center()), "seed %d: 届かない部屋がある" % s)


func test_border_is_wall() -> void:
	for s in range(1, 201):
		var map := make(s)
		for x in Dungeon.WIDTH:
			check(map.tile_at(Vector2i(x, 0)) == Dungeon.Tile.WALL, "seed %d: 上端が壁でない" % s)
			check(map.tile_at(Vector2i(x, Dungeon.HEIGHT - 1)) == Dungeon.Tile.WALL, "seed %d: 下端が壁でない" % s)
		for y in Dungeon.HEIGHT:
			check(map.tile_at(Vector2i(0, y)) == Dungeon.Tile.WALL, "seed %d: 左端が壁でない" % s)
			check(map.tile_at(Vector2i(Dungeon.WIDTH - 1, y)) == Dungeon.Tile.WALL, "seed %d: 右端が壁でない" % s)


func test_same_seed_same_map() -> void:
	check(make(42).tiles == make(42).tiles, "同じシードで違うマップになった")


func test_fov() -> void:
	var map := make(7)
	var room: Rect2i = map.rooms[0]
	var v := Fov.compute(map, room.position)
	check(v.has(room.end - Vector2i.ONE), "部屋の中から部屋の反対の角が見えない")

	# 部屋に接していない通路では、周囲 1 マス（9 マス）だけ見える
	for y in Dungeon.HEIGHT:
		for x in Dungeon.WIDTH:
			var p := Vector2i(x, y)
			if map.tile_at(p) != Dungeon.Tile.CORRIDOR:
				continue
			var near_room := false
			for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if map.room_at(p + dir) >= 0:
					near_room = true
			if near_room:
				continue
			check(Fov.compute(map, p).size() == 9, "通路で見える範囲が 9 マスでない")
			return
	check(false, "部屋に接していない通路が見つからない")
