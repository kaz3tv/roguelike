## 敵の動き方。
class_name MonsterAI
extends RefCounted

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
	Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1),
]


## ボスが離れた場所から闇の炎を放つ確率
const BOSS_BOLT_CHANCE := 0.35


## 敵がとる行動を返す。{"type": "attack"} / {"type": "bolt"} / {"type": "move", "dir": Vector2i} / {"type": "wait"}
## sees_player: 敵からプレイヤーが見えているか。occupied: 他の敵がいるマス。
static func decide(map: Dungeon, enemy: Actor, player_pos: Vector2i, sees_player: bool, occupied: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var erratic := enemy.behavior == "erratic" and rng.randf() < 0.5
	if sees_player and not erratic:
		var to_player := player_pos - enemy.pos
		if maxi(absi(to_player.x), absi(to_player.y)) == 1 and map.can_step(enemy.pos, to_player):
			return {"type": "attack"}
		if enemy.behavior == "boss" and rng.randf() < BOSS_BOLT_CHANCE:
			return {"type": "bolt"}
		var dir := step_toward(map, enemy.pos, player_pos, occupied)
		if dir != Vector2i.ZERO:
			return {"type": "move", "dir": dir}
		return {"type": "wait"}
	# 見えていない、またはふらふらしている：ランダムに 1 歩（動けなければ待つ）
	var first := rng.randi_range(0, DIRS.size() - 1)
	for i in DIRS.size():
		var dir := DIRS[(first + i) % DIRS.size()]
		var target := enemy.pos + dir
		if map.can_step(enemy.pos, dir) and not occupied.has(target) and target != player_pos:
			return {"type": "move", "dir": dir}
	return {"type": "wait"}


## goal に一番近づける 1 歩を返す。どこにも進めなければ ZERO。
static func step_toward(map: Dungeon, from: Vector2i, goal: Vector2i, occupied: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_score := _score(goal - from)
	for dir in DIRS:
		var target := from + dir
		if target == goal or occupied.has(target) or not map.can_step(from, dir):
			continue
		var s := _score(goal - target)
		if s < best_score:
			best_score = s
			best = dir
	return best


## 8 方向で何歩か（チェビシェフ距離）を優先し、同じならマンハッタン距離で比べる
static func _score(d: Vector2i) -> int:
	return maxi(absi(d.x), absi(d.y)) * 100 + absi(d.x) + absi(d.y)
