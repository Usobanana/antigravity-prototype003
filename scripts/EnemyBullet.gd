extends Area2D

var speed = 300.0
var damage = 10
var type = "normal" 

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
		
	if body.is_in_group("enemies"):
		# 敵には当たらない
		pass
	elif body.is_in_group("players"):
		if body.has_method("hit"):
			body.rpc("hit", damage)
		if type != "piercing":
			queue_free()
	else:
		queue_free()
