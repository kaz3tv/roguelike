## 効果音と BGM を鳴らす。ファイル名は assets/audio/CREDITS.md の一覧に合わせてある。
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const BGM_DIR := "res://assets/audio/bgm/"
const SFX_NAMES := [
	"attack_miss", "attack_swing", "enemy_attack", "enemy_die", "equip", "error", "footstep",
	"heal", "hit_enemy", "hit_player", "item_pickup", "level_up", "magic_bolt", "menu_cancel",
	"menu_move", "menu_select", "player_die", "scroll_fire", "scroll_map", "scroll_warp",
	"stairs_down", "trap",
]
## 同時に鳴らせる効果音の数
const SFX_VOICES := 6
const SFX_VOLUME_DB := -6.0
const BGM_VOLUME_DB := -12.0

var muted := false
var sfx := {}
var sfx_players: Array[AudioStreamPlayer] = []
var next_voice := 0
var bgm_player := AudioStreamPlayer.new()
var current_bgm := ""


func _ready() -> void:
	for sfx_name in SFX_NAMES:
		sfx[sfx_name] = load(SFX_DIR + sfx_name + ".wav")
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_VOLUME_DB
		add_child(p)
		sfx_players.append(p)
	bgm_player.volume_db = BGM_VOLUME_DB
	add_child(bgm_player)


func play(sfx_name: String) -> void:
	if muted:
		return
	# 空いている再生機を順番に使い回す
	var p := sfx_players[next_voice]
	next_voice = (next_voice + 1) % SFX_VOICES
	p.stream = sfx[sfx_name]
	p.play()


## 曲を切り替える。同じ曲なら最初からやり直さない。
func play_bgm(bgm_name: String) -> void:
	if bgm_name == current_bgm:
		return
	current_bgm = bgm_name
	bgm_player.stop()
	bgm_player.stream = load(BGM_DIR + bgm_name + ".ogg")
	if not muted:
		bgm_player.play()


## 階に合わせた曲：1〜3階、4〜6階、7階〜
static func bgm_for_floor(floor_number: int) -> String:
	if floor_number <= 3:
		return "dungeon_1"
	if floor_number <= 6:
		return "dungeon_2"
	return "dungeon_3"


func toggle_mute() -> void:
	muted = not muted
	if muted:
		bgm_player.stop()
		for p in sfx_players:
			p.stop()
	elif current_bgm != "":
		bgm_player.play()
