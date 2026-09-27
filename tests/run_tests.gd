## ダンジョン生成と視界のテスト。
## 実行方法: godot --headless --path . -s tests/run_tests.gd
extends SceneTree

var failures := 0


func _init() -> void:
	test_all_rooms_reachable()
	test_border_is_wall()
	test_same_seed_same_map()
	test_fov()
	test_damage()
	test_level_up()
	test_enemy_table()
	test_monster_ai()
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


func test_damage() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 200:
		var d := Combat.roll_damage(5, 2, rng)
		check(d >= 4 and d <= 5, "攻撃5・防御2 のダメージが %d" % d)
		check(Combat.roll_damage(1, 30, rng) == 1, "ダメージが最低 1 になっていない")


func test_level_up() -> void:
	var p := Actor.new_player()
	check(Combat.gain_exp(p, 5) == 0, "経験値 5 でレベルが上がった")
	check(Combat.gain_exp(p, 1) == 1 and p.level == 2, "経験値 6 で Lv2 にならない")
	check(p.max_hp == 25 and p.attack == 6, "レベルアップで HP・攻撃力が上がっていない")
	check(Combat.gain_exp(p, 100) >= 2, "大量の経験値で複数レベル上がらない")


func test_enemy_table() -> void:
	for f in range(1, 11):
		check(not EnemyData.kinds_for_floor(f).is_empty(), "%d階に出る敵がいない" % f)
	for id in EnemyData.ENEMIES:
		for frame in 2:
			var path := "res://assets/art/enemies/%s_%d.png" % [id, frame]
			check(ResourceLoader.exists(path), "画像がない: " + path)
	# 各階のタイル画像がそろっている
	var map_view := load("res://scripts/map_view.gd")
	for f in range(1, 11):
		for file in map_view.TILE_FILES.values():
			var path: String = map_view.theme_dir(f) + file
			check(ResourceLoader.exists(path), "タイル画像がない: " + path)


func test_monster_ai() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var map := make(11)
	var room: Rect2i = map.rooms[0]
	var e := EnemyData.create("slime")
	e.pos = room.position
	# 隣にいれば攻撃する
	var action := MonsterAI.decide(map, e, room.position + Vector2i(1, 1), true, {}, rng)
	check(action["type"] == "attack", "隣のプレイヤーを攻撃しない")
	# 離れていれば近づく
	var goal := room.end - Vector2i.ONE
	var before := maxi(absi(goal.x - e.pos.x), absi(goal.y - e.pos.y))
	action = MonsterAI.decide(map, e, goal, true, {}, rng)
	if before > 1:
		check(action["type"] == "move", "見えているプレイヤーに近づかない")
		var after_pos: Vector2i = e.pos + action["dir"]
		check(maxi(absi(goal.x - after_pos.x), absi(goal.y - after_pos.y)) < before, "近づく方向に動いていない")
	# 壁の角越しには攻撃しない
	for y in Dungeon.HEIGHT:
		for x in Dungeon.WIDTH:
			var p := Vector2i(x, y)
			if map.is_walkable(p) and map.is_walkable(p + Vector2i(1, 1)) and not map.is_walkable(p + Vector2i(1, 0)):
				check(not map.can_step(p, Vector2i(1, 1)), "壁の角を斜めに通れてしまう")
				return
