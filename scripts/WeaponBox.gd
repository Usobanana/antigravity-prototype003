extends Area2D

@export var weapon_id = "smg" # デフォルトはSMG（ピストルは初期装備なので）
var weight = 5.0 # 武器ボックスは重い

func _ready():
	# キラキラエフェクト（簡易的な点滅）
	var tween = create_tween().set_loops()
	tween.tween_property($Sprite2D, "modulate:a", 0.5, 0.5)
	tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.5)

func _on_body_entered(body):
	if body.is_in_group("players"):
		# プレイヤー（権限持ち）に拾わせる
		if body.is_multiplayer_authority():
			if body.has_method("pickup"):
				body.pickup(self)
