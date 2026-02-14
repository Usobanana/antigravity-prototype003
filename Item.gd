extends Area2D

@export var weight: float = 1.0
@export var score: int = 100

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("players"):
		# プレイヤー（権限持ち）に拾わせる
		if body.is_multiplayer_authority():
			if body.has_method("pickup"):
				body.pickup(self)
