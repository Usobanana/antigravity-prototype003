extends Area2D

@export var weight: float = 1.0
@export var score: int = 100

var magnet_radius = 120.0
var magnet_speed = 300.0

func _ready():
	connect("body_entered", _on_body_entered)

func _physics_process(delta):
	# ローカルクライアント（自分）に向かってだけ吸い寄せられる処理（見た目重視）
	# またはサーバー上で全員に対して判定するか。
	# アイテム同期はサーバーベースなので、サーバーで処理するのが安全。
	if not multiplayer.is_server():
		return
		
	var players = get_tree().get_nodes_in_group("players")
	for p in players:
		# 死亡状態などはスキップ
		if "health" in p and p.health <= 0: continue
		if "is_peace_mode" in p and p.is_peace_mode: continue
		
		var dist = global_position.distance_to(p.global_position)
		if dist < magnet_radius:
			var dir = (p.global_position - global_position).normalized()
			# 近づくほど速く
			var speed_mult = 1.0 - (dist / magnet_radius)
			global_position += dir * magnet_speed * speed_mult * delta
			break # 1人のプレイヤーに吸い寄せられればOK

func _on_body_entered(body):
	if body.is_in_group("players"):
		# プレイヤー（権限持ち）に拾わせる
		if body.is_multiplayer_authority():
			if body.has_method("pickup"):
				body.pickup(self)
