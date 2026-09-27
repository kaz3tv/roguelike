## 中断セーブ（1 枠）の読み書き。Godot のユーザーデータ領域に保存する。
## 続きから遊ぶとファイルは消える（やられたところからのやり直しはできない）。
class_name SaveGame
extends RefCounted

const DEFAULT_PATH := "user://suspend.save"
## 保存する中身の形が変わったら上げる。古い形のセーブは読まない。
const VERSION := 1


static func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func write(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	data["version"] = VERSION
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("中断セーブを書けなかった: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_var(data)
	return true


## 読めなければ空の辞書を返す。
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = f.get_var()
	if not data is Dictionary or data.get("version", 0) != VERSION:
		return {}
	return data


static func delete(path: String = DEFAULT_PATH) -> void:
	if exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
