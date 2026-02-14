extends CharacterBody2D

const SPEED = 100.0

# 同期する必要がある場合は @export var health = 3 などにして
# MultiplayerSynchronizerに登録するが、今回はサーバー管理で十分
var health = 3

func _ready():
	# サーバー権限を持つピアのみが計算を行う
	set_physics_process(is_multiplayer_authority())

func _physics_process(_delta):
	# 最も近いプレイヤーを探す
	var target = _find_nearest_player()
	
	if target:
		# ターゲットに向かって移動
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * SPEED
		move_and_slide()
		
		# 衝突判定（攻撃）
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider.is_in_group("players"):
				if collider.has_method("hit"):
					# サーバー権限で実行しているので直接呼ぶか、RPCで呼ぶ
					# ここではRPC経由でダメージを与える
					collider.rpc("hit", 10) # 10ダメージ
					
					# 敵は特攻して消滅する（簡易的な攻撃表現）
					queue_free()
					break

func _find_nearest_player():
	var players = get_tree().get_nodes_in_group("players")
	var nearest_player = null
	var min_distance = INF
	
	for player in players:
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest_player = player
			
	return nearest_player

# ダメージ処理（全クライアントで呼ばれるようにRPC化も可能だが、
# 基本はサーバーで処理し、結果（消滅など）を同期する形が良い）
# 今回はシンプルに any_peer から呼び出せるようにして、
# サーバーで実行 -> 死亡処理 という流れにする
@rpc("any_peer")
func hit(damage):
	# サーバーのみが体力を管理・判定する
	if not is_multiplayer_authority():
		return
		
	health -= damage
	print("Enemy hit! HP:", health)
	
	if health <= 0:
		# サーバーでfreeすれば、Spawner経由で全クライアントから消える
		queue_free()
