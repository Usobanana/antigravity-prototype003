extends Node2D

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
# プレイヤーの設計図を読み込んでおく
@export var player_scene: PackedScene = preload("res://Player.tscn")
@export var bullet_scene: PackedScene = preload("res://Bullet.tscn")
@export var enemy_scene: PackedScene = preload("res://Enemy.tscn")
@export var item_scene: PackedScene = preload("res://Item.tscn")

func _ready():
	print("Main Scene Started")
	
	# ホストの場合のみ、ゲーム初期化処理
	if multiplayer.is_server():
		# 敵・アイテム生成タイマー開始
		var enemy_timer = Timer.new()
		enemy_timer.wait_time = 3.0
		enemy_timer.autostart = true
		enemy_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
		add_child(enemy_timer)

		var item_timer = Timer.new()
		item_timer.wait_time = 2.0
		item_timer.autostart = true
		item_timer.timeout.connect(_on_item_spawn_timer_timeout)
		add_child(item_timer)
		
		# 新規接続・切断時の処理（途中参加用）
		multiplayer.peer_connected.connect(_spawn_player)
		multiplayer.peer_disconnected.connect(_remove_player)

	# 自身（Host含む）のロード完了を通知
	rpc_id(1, "_on_player_scene_ready")

# 全員（または該当プレイヤー）がシーン読み込み完了したらスポーンさせる
var ready_players_count = 0

@rpc("any_peer", "call_local")
func _on_player_scene_ready():
	if not multiplayer.is_server():
		return
		
	ready_players_count += 1
	var total_players = multiplayer.get_peers().size() + 1
	print("Player ready: ", ready_players_count, "/", total_players)
	
	# 今回は「全員揃ったら一斉スタート」方式を採用
	# ※途中参加を考慮するなら、個別にスポーンさせるロジックにするが、
	#   Title->Home->Battleのフローでは一斉開始が自然
	if ready_players_count >= total_players:
		print("All players ready. Spawning...")
		_spawn_initial_players()

func _spawn_initial_players():
	_spawn_player(1)
	for id in multiplayer.get_peers():
		_spawn_player(id)

func _spawn_player(id):
	# 既に存在するかチェック（重複防止）
	if has_node(str(id)):
		return
	print("Spawning player: ", id)
	# 既に存在するかチェック
	if has_node(str(id)):
		return
		
	var player = player_scene.instantiate()
	player.name = str(id)
	add_child(player, true) # trueで自動同期（MultiplayerSpawnerがルートにあればだが、ここでは手動add_childなのでSpawner設定次第）
	# 今回の構成ではPlayers用のSpawnerがないため、add_childの第2引数trueだけでは同期されない可能性がある
	# しかし、main.tscnの末尾に `MultiplayerSpawner` (spawn_path="..") があるので、ルート直下へのaddは同期されるはず

func _remove_player(id):
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func _on_enemy_spawn_timer_timeout():
	_spawn_enemy()

func _spawn_enemy():
	var enemy = enemy_scene.instantiate()
	var screen_size = Vector2(1152, 648) # 簡易
	enemy.global_position = Vector2(randf() * screen_size.x, randf() * screen_size.y)
	$Enemies.add_child(enemy, true)

# 弾を発射する関数
@rpc("any_peer", "call_local")
func fire_bullet(pos, rot):
	var bullet = bullet_scene.instantiate()
	bullet.global_position = pos
	bullet.rotation = rot
	$Projectiles.add_child(bullet, true)

func _on_item_spawn_timer_timeout():
	if not multiplayer.is_server():
		return
	if $Items.get_child_count() >= 20:
		return
		
	var item = item_scene.instantiate()
	var screen_size = Vector2(1152, 648)
	item.position = Vector2(randf_range(50, screen_size.x - 50), randf_range(50, screen_size.y - 50))
	if item.position.distance_to(Vector2(576, 324)) < 150:
		return
	$Items.add_child(item, true)

@rpc("any_peer", "call_local")
func remove_item(item_path):
	if not multiplayer.is_server():
		return
	var item = get_node_or_null(item_path)
	if item:
		item.queue_free()

@rpc("any_peer", "call_local")
func drop_items(pos, count):
	if not multiplayer.is_server():
		return
	for i in range(count):
		var item = item_scene.instantiate()
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		item.global_position = pos + offset
		$Items.add_child(item, true)

# Base納品処理
func _on_base_body_entered(body):
	if not multiplayer.is_server():
		return
		
	if body.is_in_group("players"):
		if "held_items" in body and body.held_items > 0:
			var points = body.held_items * 100
			body.rpc("add_score", points)
			print("Delivered! Score:", body.score + points)
			
			body.rpc("reset_carry")
			rpc("spawn_delivery_effect", body.global_position)
			
			# ゲーム終了判定 (今回は簡易的にサーバー側でスコア計算していないので、クライアントのスコアを信じるか、
			# 本来はサーバーで各プレイヤーのスコアを管理すべき)
			# ここでは簡易的に「納品後のスコアが500以上なら終了」とする
			# body.score は同期前の値なので + points する
			if body.score + points >= 500:
				print("Game Over! Winner: ", body.name)
				# 全員をリザルトへ (スコアを渡す)
				# RPCで全員に通知し、NetworkManagerにスコアを保存させてから遷移
				rpc("game_over", body.score + points)

@rpc("call_local")
func game_over(final_score):
	NetworkManager.last_score = final_score
	NetworkManager.end_game()

@rpc("call_local")
func spawn_delivery_effect(pos):
	var particle = CPUParticles2D.new()
	particle.global_position = pos
	particle.emitting = true
	particle.amount = 20
	particle.one_shot = true
	particle.explosiveness = 1.0
	particle.spread = 180.0
	particle.gravity = Vector2(0, 0)
	particle.initial_velocity_min = 100.0
	particle.initial_velocity_max = 200.0
	particle.scale_amount_min = 3.0
	particle.scale_amount_max = 5.0
	particle.color = Color(1, 1, 0) # 黄色
	add_child(particle)
	
	var timer = Timer.new()
	timer.wait_time = 2.0
	timer.autostart = true
	timer.one_shot = true
	timer.timeout.connect(func(): particle.queue_free(); timer.queue_free())
	add_child(timer)
