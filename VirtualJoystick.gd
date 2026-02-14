extends Control

# 公開プロパティ
@export var deadzone := 0.2
@export var clampzone := 75.0 # ジョイスティックの動く範囲
var output := Vector2.ZERO

# 内部変数
var _touch_index := -1
@onready var _base = $Base
@onready var _tip = $Base/Tip
@onready var _original_position = _tip.position

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_point_inside_base(event.position):
				if _touch_index == -1:
					_touch_index = event.index
					_update_joystick(event.position)
		elif event.index == _touch_index:
			_reset()
			
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_joystick(event.position)

func _is_point_inside_base(point: Vector2) -> bool:
	var center = _base.global_position + _base.size / 2
	return point.distance_to(center) <= clampzone + 20 # 少し余裕を持たせる

func _update_joystick(touch_position: Vector2):
	var center = _base.global_position + _base.size / 2
	var local_vector = touch_position - center
	
	if local_vector.length() > clampzone:
		local_vector = local_vector.normalized() * clampzone
		
	_tip.global_position = center + local_vector
	
	# 出力計算
	output = local_vector / clampzone
	if output.length() < deadzone:
		output = Vector2.ZERO

func _reset():
	_touch_index = -1
	output = Vector2.ZERO
	_tip.position = _original_position

func get_output() -> Vector2:
	return output
