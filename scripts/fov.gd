## 視界：部屋の中にいるときは部屋全体（まわりの壁と出入口を含む）、通路では周囲 1 マスが見える。
class_name Fov
extends RefCounted


## 見えているマスの集合を返す（キーが Vector2i の Dictionary）。
static func compute(map: Dungeon, pos: Vector2i) -> Dictionary:
	var visible := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			visible[pos + Vector2i(dx, dy)] = true

	# 部屋の中なら、その部屋全体が見える。
	# 通路でも、部屋の床に縦横で接している（=入口に立っている）なら、その部屋が見える。
	var room_ids := {}
	var here := map.room_at(pos)
	if here >= 0:
		room_ids[here] = true
	else:
		for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var r := map.room_at(pos + dir)
			if r >= 0:
				room_ids[r] = true

	for r in room_ids:
		var room: Rect2i = map.rooms[r]
		for y in range(room.position.y - 1, room.end.y + 1):
			for x in range(room.position.x - 1, room.end.x + 1):
				visible[Vector2i(x, y)] = true
	return visible
