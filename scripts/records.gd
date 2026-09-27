## これまでの記録（遊んだ回数・最高到達階など）。Godot のユーザーデータ領域に保存する。
## 中断セーブとは別で、死んでも消えない。
class_name Records
extends RefCounted

const DEFAULT_PATH := "user://records.cfg"

var path := DEFAULT_PATH
var runs := 0
var clears := 0
var best_floor := 0
var best_kills := 0
## いちばん少ないターン数でのクリア（0 はまだクリアしていない）
var fastest_clear := 0


static func load_from(file_path: String = DEFAULT_PATH) -> Records:
	var r := Records.new()
	r.path = file_path
	var cfg := ConfigFile.new()
	if cfg.load(file_path) == OK:
		r.runs = cfg.get_value("records", "runs", 0)
		r.clears = cfg.get_value("records", "clears", 0)
		r.best_floor = cfg.get_value("records", "best_floor", 0)
		r.best_kills = cfg.get_value("records", "best_kills", 0)
		r.fastest_clear = cfg.get_value("records", "fastest_clear", 0)
	return r


## 1 回分の結果を記録に足して保存する。塗り替えた項目の名前を返す（リザルトで「新記録」と出す用）。
func add_run(floor_number: int, kills: int, turns: int, cleared: bool) -> Array[String]:
	var new_records: Array[String] = []
	runs += 1
	if floor_number > best_floor:
		best_floor = floor_number
		new_records.append("floor")
	if kills > best_kills:
		best_kills = kills
		new_records.append("kills")
	if cleared:
		clears += 1
		if fastest_clear == 0 or turns < fastest_clear:
			fastest_clear = turns
			new_records.append("turns")
	save()
	return new_records


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "runs", runs)
	cfg.set_value("records", "clears", clears)
	cfg.set_value("records", "best_floor", best_floor)
	cfg.set_value("records", "best_kills", best_kills)
	cfg.set_value("records", "fastest_clear", fastest_clear)
	cfg.save(path)
