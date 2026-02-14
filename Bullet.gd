extends Area2D

var speed = 400.0
var damage = 10

func _ready():
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	var direction = Vector2.RIGHT.rotated(rotation)
	position += direction * speed * delta

func _on_body_entered(body):
	if not multiplayer.is_server():
		return
		
	if body.has_method("hit") and not body.is_in_group("players"): # 自分以外（敵など）
		# フレンドリーファイア防止はCollisionMaskでやるのが基本だが、
		# ここでは簡易的にグループで判定
		pass
		
	if body.is_in_group("enemies"):
		body.hit(damage)
		queue_free()
	elif body.is_in_group("players"):
		# PvPはなし？ありならここでhit
		# 今回はなしとする
		pass
	else:
		if body.is_in_group("players"):
			return
		queue_free()
