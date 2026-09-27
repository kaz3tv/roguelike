## ゲームパッドの方向入力（十字キーと左スティック）を、8 方向の「1 歩」に変える。
## 押しっぱなしのときは、キーボードのキーリピートと同じように歩き続ける。
class_name PadInput
extends RefCounted

## スティックをこれ以上倒したら入力ありとみなす
const DEADZONE := 0.5
## 押し始めてから 1 歩目を出すまでの待ち（十字キーの 2 つ同時押しで斜めにするための猶予）
const FIRST_WAIT := 0.05
## 押しっぱなしで 2 歩目が出るまでの時間と、その後の間隔
const REPEAT_DELAY := 0.25
const REPEAT_INTERVAL := 0.12

var held := {}  ## 押されている十字キー（JoyButton → true）
var stick := Vector2.ZERO
var last_dir := Vector2i.ZERO
var timer := 0.0
## まだ 1 歩目を出していないか
var waiting_first := false


func set_button(button: JoyButton, pressed: bool) -> void:
	if pressed:
		held[button] = true
	else:
		held.erase(button)


func set_axis(axis: JoyAxis, value: float) -> void:
	if axis == JOY_AXIS_LEFT_X:
		stick.x = value
	elif axis == JOY_AXIS_LEFT_Y:
		stick.y = value


static func is_dpad(button: JoyButton) -> bool:
	return button in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]


## 今の入力の向き。十字キーを優先し、押されていなければスティック。
func direction() -> Vector2i:
	var d := Vector2i.ZERO
	if held.has(JOY_BUTTON_DPAD_UP):
		d.y -= 1
	if held.has(JOY_BUTTON_DPAD_DOWN):
		d.y += 1
	if held.has(JOY_BUTTON_DPAD_LEFT):
		d.x -= 1
	if held.has(JOY_BUTTON_DPAD_RIGHT):
		d.x += 1
	if d != Vector2i.ZERO:
		return d
	return quantize(stick)


## スティックの傾きを 8 方向に丸める
static func quantize(v: Vector2) -> Vector2i:
	if v.length() < DEADZONE:
		return Vector2i.ZERO
	var step := roundi(v.angle() / (PI / 4))
	var dir := Vector2.RIGHT.rotated(step * PI / 4)
	return Vector2i(roundi(dir.x), roundi(dir.y))


## delta 秒進める。この間に出す「1 歩」の向きを返す（なければ ZERO）。
## 2 つ目の戻り値は押しっぱなしによる 2 歩目以降かどうか。
func update(delta: float) -> Array:
	var dir := direction()
	if dir != last_dir:
		var was := last_dir
		last_dir = dir
		if dir == Vector2i.ZERO:
			return [Vector2i.ZERO, false]
		# 斜めから片方を離しただけのときは、すぐには歩かない（離した瞬間に余計な 1 歩が出ないように）
		if was != Vector2i.ZERO and was.x != 0 and was.y != 0 and (dir.x == 0 or dir.x == was.x) and (dir.y == 0 or dir.y == was.y):
			waiting_first = false
			timer = REPEAT_DELAY
			return [Vector2i.ZERO, false]
		if was == Vector2i.ZERO:
			waiting_first = true
			timer = FIRST_WAIT
		else:
			# 向きを変えたらすぐ歩く
			waiting_first = false
			timer = REPEAT_DELAY
			return [dir, false]
	if dir == Vector2i.ZERO:
		return [Vector2i.ZERO, false]
	timer -= delta
	if timer > 0:
		return [Vector2i.ZERO, false]
	if waiting_first:
		waiting_first = false
		timer = REPEAT_DELAY
		return [dir, false]
	timer = REPEAT_INTERVAL
	return [dir, true]
