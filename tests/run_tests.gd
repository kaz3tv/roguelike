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
	test_items()
	test_inventory()
	test_audio_files()
	test_boss()
	test_records()
	test_save_game()
	test_font_has_all_characters()
	test_new_enemies()
	test_item_floors()
	test_pad_input()
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


func test_items() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := {}
	for i in 2000:
		var item := ItemData.roll(9, rng)
		seen[item.id] = true
		check(ItemData.ITEMS.has(item.id), "知らないアイテム: " + item.id)
		if not item.is_equipment():
			check(item.plus == 0, "装備品以外に強化値が付いた")
	check(seen.size() == ItemData.ITEMS.size(), "出てこないアイテムがある")
	for id in ItemData.ITEMS:
		check(ResourceLoader.exists(ItemData.icon_path(id)), "アイテム画像がない: " + id)
	var sword := Item.new("sword")
	sword.plus = 2
	check(sword.display_name() == "剣+2" and sword.bonus() == 5, "剣+2 の名前か強さが違う")


func test_inventory() -> void:
	var p := Actor.new_player()
	var inv := p.inventory
	for i in Inventory.CAPACITY:
		check(inv.add(Item.new("potion")), "持ち物に入らない")
	check(not inv.add(Item.new("potion")), "11 個目が入ってしまう")
	inv.items.clear()
	var sword := Item.new("sword")
	var shield := Item.new("shield")
	inv.add(sword)
	inv.add(shield)
	var base_atk := p.total_attack()
	var base_def := p.total_defense()
	check(inv.toggle_equip(sword) and p.total_attack() == base_atk + 3, "剣を装備しても攻撃力が上がらない")
	check(inv.toggle_equip(shield) and p.total_defense() == base_def + 2, "盾を装備しても防御力が上がらない")
	var sword2 := Item.new("sword")
	sword2.plus = 1
	inv.add(sword2)
	inv.toggle_equip(sword2)
	check(inv.weapon == sword2 and not inv.is_equipped(sword), "剣の持ち替えができない")
	check(not inv.toggle_equip(sword2) and p.total_attack() == base_atk, "剣を外せない")
	inv.remove(shield)
	check(inv.shield == null and p.total_defense() == base_def, "置いた盾が装備されたまま")


func test_audio_files() -> void:
	var audio := load("res://scripts/audio.gd")
	for sfx_name in audio.SFX_NAMES:
		var path: String = audio.SFX_DIR + sfx_name + ".wav"
		check(ResourceLoader.exists(path), "効果音がない: " + path)
	var bgms := ["game_over", "title", "clear"]
	for f in range(1, 11):
		bgms.append(audio.bgm_for_floor(f))
	for bgm in bgms:
		check(ResourceLoader.exists(audio.BGM_DIR + bgm + ".ogg"), "BGM がない: " + bgm)
	# game.gd の中で鳴らしている効果音が、すべて一覧にあるか
	var code := FileAccess.get_file_as_string("res://scripts/game.gd") + FileAccess.get_file_as_string("res://scripts/inventory_menu.gd")
	var re := RegEx.create_from_string("audio\\.play\\(\"([a-z_]+)\"\\)")
	for m in re.search_all(code):
		check(m.get_string(1) in audio.SFX_NAMES, "一覧にない効果音を鳴らしている: " + m.get_string(1))
	for effect in ["fire", "warp", "map"]:
		check("scroll_" + effect in audio.SFX_NAMES, "巻物の効果音がない: " + effect)
	for id in ItemData.ITEMS:
		var item_sound: String = ItemData.ITEMS[id].get("sound", "")
		check(item_sound == "" or item_sound in audio.SFX_NAMES, "アイテムの効果音が一覧にない: " + id)


func test_boss() -> void:
	var map := Dungeon.generate_boss_room()
	check(map.is_walkable(map.start) and map.is_walkable(map.boss_pos), "ボス部屋のスタートかボスの位置が壁")
	check(reachable(map, map.start).has(map.boss_pos), "ボスのところまで歩いて行けない")
	check(Fov.compute(map, map.start).has(map.boss_pos), "部屋に入ってもボスが見えない")
	for f in range(1, 11):
		check(not ("boss" in EnemyData.kinds_for_floor(f)), "%d階にボスがふつうの敵として出る" % f)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var boss := EnemyData.create("boss")
	boss.pos = map.boss_pos
	check(MonsterAI.decide(map, boss, boss.pos + Vector2i.DOWN, true, {}, rng)["type"] == "attack", "ボスが隣のプレイヤーを攻撃しない")
	var bolts := 0
	for i in 200:
		var t: String = MonsterAI.decide(map, boss, map.start, true, {}, rng)["type"]
		check(t == "bolt" or t == "move", "離れたボスの行動がおかしい: " + t)
		if t == "bolt":
			bolts += 1
	check(bolts > 30 and bolts < 120, "闇の炎の回数が確率と合わない: %d" % bolts)
	check(ResourceLoader.exists("res://assets/art/enemies/boss_0.png"), "ボスの画像がない")
	var audio := load("res://scripts/audio.gd")
	for bgm in ["boss", "clear"]:
		check(ResourceLoader.exists(audio.BGM_DIR + bgm + ".ogg"), "BGM がない: " + bgm)


func test_records() -> void:
	var path := "user://test_records.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var r := Records.load_from(path)
	check(r.runs == 0 and r.best_floor == 0, "記録ファイルがないのに記録がある")
	check(r.add_run(3, 5, 200, false) == ["floor", "kills"], "初回の新記録の判定が違う")
	check(r.add_run(2, 9, 150, false) == ["kills"], "撃破数だけの新記録の判定が違う")
	check(r.add_run(10, 4, 900, true) == ["floor", "turns"], "初クリアの新記録の判定が違う")
	check(r.add_run(10, 4, 950, true).is_empty(), "遅いクリアが新記録になった")
	var again := Records.load_from(path)
	check(again.runs == 4 and again.clears == 2, "遊んだ回数が保存されていない")
	check(again.best_floor == 10 and again.best_kills == 9 and again.fastest_clear == 900, "最高記録が保存されていない")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_save_game() -> void:
	var path := "user://test_suspend.save"
	SaveGame.delete(path)
	check(not SaveGame.exists(path) and SaveGame.read(path).is_empty(), "セーブがないのに読めた")
	var map := make(21)
	var p := Actor.new_player()
	p.pos = map.start
	p.hp = 13
	p.level = 4
	var sword := Item.new("sword")
	sword.plus = 2
	p.inventory.add(Item.new("potion"))
	p.inventory.add(sword)
	p.inventory.toggle_equip(sword)
	var slime := EnemyData.create("slime")
	slime.pos = map.stairs
	slime.hp = 2
	var floor_item := Item.new("shield")
	floor_item.pos = Vector2i(3, 4)
	check(SaveGame.write({
		"map": map.to_dict(),
		"player": p.to_dict(),
		"enemies": [slime.to_dict()],
		"items": [floor_item.to_dict()],
		"explored": [Vector2i(1, 2)],
	}, path), "中断セーブを書けない")
	check(SaveGame.exists(path), "中断セーブのファイルがない")
	var data := SaveGame.read(path)
	var map2 := Dungeon.from_dict(data["map"])
	check(map2.tiles == map.tiles and map2.rooms == map.rooms and map2.stairs == map.stairs, "マップが元に戻らない")
	var p2 := Actor.from_dict(data["player"])
	check(p2.pos == p.pos and p2.hp == 13 and p2.level == 4, "プレイヤーの状態が元に戻らない")
	check(p2.inventory.items.size() == 2 and p2.inventory.weapon == p2.inventory.items[1], "装備が元に戻らない")
	check(p2.total_attack() == p.total_attack(), "装備込みの攻撃力が変わった")
	var e2 := Actor.from_dict(data["enemies"][0])
	check(e2.kind == "slime" and e2.hp == 2 and e2.pos == map.stairs and e2.display_name == "スライム", "敵が元に戻らない")
	var item2 := Item.from_dict(data["items"][0])
	check(item2.id == "shield" and item2.pos == Vector2i(3, 4), "落ちているアイテムが元に戻らない")
	check(data["explored"] == [Vector2i(1, 2)], "見た場所が元に戻らない")
	# 古い形のセーブは読まない
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_var({"version": SaveGame.VERSION - 1})
	f.close()
	check(SaveGame.read(path).is_empty(), "古い形のセーブを読んでしまった")
	SaveGame.delete(path)
	check(not SaveGame.exists(path), "中断セーブを消せない")


func test_font_has_all_characters() -> void:
	# ブラウザ版には代わりのフォントがないので、画面に出す文字はすべてドット絵フォントに入っている必要がある
	var font: FontFile = load("res://fonts/DotGothic16-Regular.ttf")
	var re := RegEx.create_from_string("\"([^\"]*)\"")
	for path in ["res://scripts/", "res://scenes/"]:
		for file in DirAccess.get_files_at(path):
			if not (file.ends_with(".gd") or file.ends_with(".tscn")):
				continue
			for line in FileAccess.get_file_as_string(path + file).split("\n"):
				if line.strip_edges().begins_with("#"):
					continue
				for m in re.search_all(line.split("##")[0]):
					for ch in m.get_string(1):
						if ch.unicode_at(0) > 32:
							check(font.has_char(ch.unicode_at(0)), "フォントにない文字: %s（%s）" % [ch, file])
	# クレジット画面の文章
	var credits := FileAccess.get_file_as_string("res://assets/credits.txt")
	check(credits.contains("Godot") and credits.contains("Komiku"), "クレジットの文章がない")
	for ch in credits:
		if ch.unicode_at(0) > 32:
			check(font.has_char(ch.unicode_at(0)), "フォントにない文字: %s（credits.txt）" % ch)


## 部屋の中の、まわりが床のマスを返す（敵の動きのテスト用）
func open_spot(map: Dungeon) -> Vector2i:
	var room: Rect2i = map.rooms[0]
	return room.position + Vector2i(2, 2)


func test_new_enemies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var map := Dungeon.generate_boss_room()
	var center := map.start + Vector2i(0, -6)
	# おばけキノコは動かない。となりなら攻撃する
	var mush := EnemyData.create("mushroom")
	mush.pos = center
	for i in 20:
		check(MonsterAI.decide(map, mush, center + Vector2i(4, 0), true, {}, rng)["type"] == "wait", "おばけキノコが動いた")
	check(MonsterAI.decide(map, mush, center + Vector2i(1, 1), true, {}, rng)["type"] == "attack", "おばけキノコがとなりを攻撃しない")
	# 弓兵はまっすぐ並んだ相手にだけ矢を撃つ
	var archer := EnemyData.create("archer")
	archer.pos = center
	var arrows := 0
	for i in 200:
		var t: String = MonsterAI.decide(map, archer, center + Vector2i(4, 4), true, {}, rng)["type"]
		check(t == "arrow" or t == "move", "弓兵の行動がおかしい: " + t)
		if t == "arrow":
			arrows += 1
	check(arrows > 60 and arrows < 140, "弓兵の矢の回数が確率と合わない: %d" % arrows)
	for i in 50:
		check(MonsterAI.decide(map, archer, center + Vector2i(4, 2), true, {}, rng)["type"] != "arrow", "並んでいない相手に矢を撃った")
		check(MonsterAI.decide(map, archer, center + Vector2i(0, 6), true, {}, rng)["type"] != "arrow", "遠すぎる相手に矢を撃った")
	check(not MonsterAI.clear_shot(map, center, center + Vector2i(3, 0), {center + Vector2i(1, 0): true}), "敵ごしに矢が通る")
	check(not MonsterAI.clear_shot(map, map.start, map.start + Vector2i(0, 3), {}), "壁ごしに矢が通る")
	# 魔法使いは離れていると魔法を撃つことがある
	var mage := EnemyData.create("mage")
	mage.pos = center
	var bolts := 0
	for i in 200:
		if MonsterAI.decide(map, mage, center + Vector2i(5, 1), true, {}, rng)["type"] == "bolt":
			bolts += 1
	check(bolts > 30 and bolts < 100, "魔法使いの魔法の回数が確率と合わない: %d" % bolts)
	# 新しい敵の絵と表
	for id in ["mushroom", "snake", "big_slime", "archer", "fire_spirit", "golem"]:
		check(EnemyData.ENEMIES.has(id), "敵がいない: " + id)
	for f in range(1, 10):
		check(EnemyData.kinds_for_floor(f).size() >= 3, "%d階の敵が少ない" % f)
	# 中断セーブで眠りや分身の状態が残る
	var clone := EnemyData.create("big_slime")
	clone.behavior = "chase"
	clone.xp = 1
	clone.sleep_turns = 3
	var back := Actor.from_dict(clone.to_dict())
	check(back.behavior == "chase" and back.xp == 1 and back.sleep_turns == 3, "分身や眠りの状態がセーブに残らない")
	var old := clone.to_dict()
	old.erase("behavior")
	old.erase("sleep_turns")
	old.erase("rested")
	check(Actor.from_dict(old).behavior == "split", "古いセーブの敵が読めない")


func test_item_floors() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	for i in 3000:
		var item := ItemData.roll(1, rng)
		check(item.data()["min_floor"] <= 1, "1階に深い階のアイテムが出た: " + item.id)
	for id in ItemData.ITEMS:
		check(ItemData.ITEMS[id].has("min_floor"), "出る階が決まっていない: " + id)


## ゲームパッドの方向入力を dt 刻みで seconds 秒進め、出た歩数を返す
func run_pad(pad: PadInput, seconds: float, dt := 0.01) -> Array:
	var steps := []
	var t := 0.0
	while t < seconds - 0.0001:
		var r: Array = pad.update(dt)
		if r[0] != Vector2i.ZERO:
			steps.append(r)
		t += dt
	return steps


func test_pad_input() -> void:
	# スティックの傾きを 8 方向に丸める
	check(PadInput.quantize(Vector2(0.9, 0.1)) == Vector2i(1, 0), "スティック右が右にならない")
	check(PadInput.quantize(Vector2(0.7, -0.7)) == Vector2i(1, -1), "スティック右上が右上にならない")
	check(PadInput.quantize(Vector2(-0.1, 0.95)) == Vector2i(0, 1), "スティック下が下にならない")
	check(PadInput.quantize(Vector2(0.2, 0.2)) == Vector2i.ZERO, "スティックの遊びが効いていない")
	# 押した直後に 1 歩、押しっぱなしで少し待ってから続けて歩く
	var pad := PadInput.new()
	pad.set_button(JOY_BUTTON_DPAD_RIGHT, true)
	var steps := run_pad(pad, 0.1)
	check(steps.size() == 1 and steps[0][0] == Vector2i(1, 0) and not steps[0][1], "十字キーを押して 1 歩出ない")
	steps = run_pad(pad, 0.6)
	check(steps.size() >= 3 and steps.size() <= 5 and steps.all(func(x): return x[1]), "押しっぱなしで歩き続けない: %d" % steps.size())
	pad.set_button(JOY_BUTTON_DPAD_RIGHT, false)
	check(run_pad(pad, 0.5).is_empty(), "離したのに歩き続ける")
	# 2 つをほぼ同時に押すと斜めの 1 歩になる
	pad.set_button(JOY_BUTTON_DPAD_UP, true)
	pad.update(0.02)
	pad.set_button(JOY_BUTTON_DPAD_LEFT, true)
	steps = run_pad(pad, 0.1)
	check(steps.size() == 1 and steps[0][0] == Vector2i(-1, -1), "同時押しで斜めにならない")
	# 斜めから片方だけ離しても、すぐには余計な 1 歩が出ない
	pad.set_button(JOY_BUTTON_DPAD_LEFT, false)
	check(run_pad(pad, 0.1).is_empty(), "斜めから片方を離したら余計に歩いた")
	pad.set_button(JOY_BUTTON_DPAD_UP, false)
	run_pad(pad, 0.05)
	# 十字キーのほうがスティックより優先
	pad.set_axis(JOY_AXIS_LEFT_X, -1.0)
	pad.set_button(JOY_BUTTON_DPAD_DOWN, true)
	check(pad.direction() == Vector2i(0, 1), "十字キーよりスティックが優先された")
