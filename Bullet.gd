extends Area2D

var speed = 400.0
var damage = 10
var type = "normal" # normal, spread, piercing

var lifetime = 3.0

func _ready():
	pass

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
		
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
		if type != "piercing":
			queue_free()
	elif body.is_in_group("players"):
		# PvPはなし？ありならここでhit
		# 今回はなしとする
		pass
	else:
		if body.is_in_group("players"):
			return
		queue_free()
