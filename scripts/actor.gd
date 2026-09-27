## プレイヤーと敵に共通のパラメータ。
class_name Actor
extends RefCounted

var kind := ""  ## "player" または敵の種類（EnemyData のキー）
var display_name := ""
var pos := Vector2i.ZERO
var max_hp := 1
var hp := 1
var attack := 1
var defense := 0
var level := 1
var xp := 0  ## プレイヤーは累計経験値、敵は倒したときにもらえる経験値
var behavior := ""  ## 敵の動き方（EnemyData 参照）
var node: Sprite2D  ## 画面上の絵


func is_dead() -> bool:
	return hp <= 0


static func new_player() -> Actor:
	var a := Actor.new()
	a.kind = "player"
	a.display_name = "あなた"
	a.max_hp = 20
	a.hp = 20
	a.attack = 5
	a.defense = 2
	return a
