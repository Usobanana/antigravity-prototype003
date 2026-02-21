extends Node2D

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
# プレイヤーの設計図を読み込んでおく
@export var player_scene: PackedScene = preload("res://Player.tscn")
@export var bullet_scene: PackedScene = preload("res://Bullet.tscn")
@export var enemy_bullet_scene: PackedScene = preload("res://EnemyBullet.tscn")
@export var enemy_scene: PackedScene = preload("res://Enemy.tscn")
@export var item_scene: PackedScene = preload("res://Item.tscn")

# ウェーブ管理
enum WaveState { WAVE, INTERVAL }
var current_state = WaveState.WAVE
var current_wave = 1
var wave_timer: Timer
var enemy_timer: Timer
var item_timer: Timer

func _ready():
	print("Main Scene Started")
	
	# ホストの場合のみ、ゲーム初期化処理
	if multiplayer.is_server():
		# ウェーブ管理タイマー
		wave_timer = Timer.new()
		wave_timer.autostart = false
		wave_timer.one_shot = true
		wave_timer.timeout.connect(_on_wave_timer_timeout)
		add_child(wave_timer)
		
		# 敵・アイテム生成タイマー開始
		enemy_timer = Timer.new()
		enemy_timer.wait_time = 3.0
		enemy_timer.autostart = false
		enemy_timer.timeout.connect(_on_enemy_spawn_timer_timeout)
		add_child(enemy_timer)

		item_timer = Timer.new()
		item_timer.wait_time = 2.0
		item_timer.autostart = false
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
		
		# ホストのみウェーブ開始
		if multiplayer.is_server():
			_start_wave(1)

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
	
	# スポーン位置を分散させる（ベース: 576, 324）
	var center = Vector2(576, 324)
	var radius = 100.0
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * radius
	player.position = center + offset
	
	add_child(player, true) # trueで自動同期
	# 今回の構成ではPlayers用のSpawnerがないため、add_childの第2引数trueだけでは同期されない可能性がある
	# しかし、main.tscnの末尾に `MultiplayerSpawner` (spawn_path="..") があるので、ルート直下へのaddは同期されるはず

func _remove_player(id):
	if has_node(str(id)):
		get_node(str(id)).queue_free()

func _on_enemy_spawn_timer_timeout():
	if current_state == WaveState.WAVE:
		_spawn_enemy()

# --- Wave System Logic ---

func _start_wave(wave_num):
	current_wave = wave_num
	current_state = WaveState.WAVE
	
	# ウェーブ進行による難易度上昇
	# 敵の出現間隔を短くする（最小1.0秒）
	enemy_timer.wait_time = max(1.0, 3.0 - (wave_num * 0.2))
	enemy_timer.start()
	item_timer.start()
	
	# ウェーブ期間: 60秒
	wave_timer.wait_time = 60.0
	wave_timer.start()
	
	# 全員にUI更新を通知
	rpc("update_wave_ui", current_state, current_wave, 60.0)
	print("Started WAVE ", current_wave)

func _start_interval():
	current_state = WaveState.INTERVAL
	
	# インターバル中は敵が出ない
	enemy_timer.stop()
	# アイテムは出るようにするかどうかは自由だが、今回は少しだけ出やすくする等でも良い。
	# そのまましておく。
	
	# インターバル期間: 20秒
	wave_timer.wait_time = 20.0
	wave_timer.start()
	
	# 全員にUI更新を通知
	rpc("update_wave_ui", current_state, current_wave, 20.0)
	print("Started INTERVAL after WAVE ", current_wave)

func _on_wave_timer_timeout():
	if current_state == WaveState.WAVE:
		_start_interval()
	else:
		_start_wave(current_wave + 1)

@rpc("call_local")
func update_wave_ui(state, wave_num, duration):
	var ui_node = get_tree().current_scene.get_node_or_null("UI")
	if not ui_node: return
	var wave_label = ui_node.get_node_or_null("WaveLabel")
	if not wave_label: return
	
	if state == WaveState.WAVE:
		wave_label.text = "WAVE " + str(wave_num)
		wave_label.modulate = Color(1, 0.2, 0.2) # Red-ish for combat
	else:
		wave_label.text = "INTERVAL - NEXT: WAVE " + str(wave_num + 1)
		wave_label.modulate = Color(0.2, 1, 0.2) # Green-ish for safe time

	# （オプション）残り時間を表示したい場合は _process で wave_timer.time_left を使う仕組みが必要。
	# ここでは簡易的にフェーズ切り替え時にラベルが変わるだけにする。

# -----------------------------

func _spawn_enemy():
	var enemy = enemy_scene.instantiate()
	var screen_size = Vector2(1152, 648) # 簡易
	enemy.global_position = Vector2(randf() * screen_size.x, randf() * screen_size.y)
	
	# ウェーブ進行による種類とステータスの決定
	var wave_multiplier = 1.0 + ((current_wave - 1) * 0.2)
	var type = "normal"
	
	var r = randf()
	if current_wave >= 3 and r < 0.15:
		type = "tank"
	elif current_wave >= 2 and r < 0.35:
		type = "shooter"
	elif r < 0.5:
		type = "scout"
		
	enemy.initialize(type, wave_multiplier)
	$Enemies.add_child(enemy, true)

# 敵の弾を発射する関数
@rpc("any_peer", "call_local")
func fire_enemy_bullet(pos, rot, speed=300.0, damage=10):
	# サーバーのみが発射を許可（Enemy.gdはサーバーで動いているため）
	if not multiplayer.is_server(): return
	
	var bullet = enemy_bullet_scene.instantiate()
	bullet.global_position = pos
	bullet.rotation = rot
	bullet.speed = speed
	bullet.damage = damage
	$Projectiles.add_child(bullet, true)

# 弾を発射する関数
@rpc("any_peer", "call_local")
func fire_bullet(pos, rot, speed=400.0, damage=10, type="normal"):
	var bullet = bullet_scene.instantiate()
	bullet.global_position = pos
	bullet.rotation = rot
	bullet.speed = speed
	bullet.damage = damage
	if "type" in bullet:
		bullet.type = type
	$Projectiles.add_child(bullet, true)

	# Base納品処理
func _on_base_body_entered(body):
	if not multiplayer.is_server():
		return
		
	if body.is_in_group("players"):
		# 武器ボックスを持っているかチェック（held_itemsの仕組みとは別に管理するか、
		# もしくはpickup時に判別フラグを持たせるか。今回は簡易的にpickup時に即時判定せず、
		# 納品時に持っているアイテムの種類をチェックする必要があるが、
		# 現在のpickup実装は単に数をカウントしているだけ。
		# -> WeaponBoxはPickup時に「持ってるフラグ」をPlayerに立てるか、
		#    あるいはWeaponBox自体をPlayerの子ノードとして物理的に持たせるのが本来だが、
		#    今回は「held_items」カウント方式なので、WeaponBoxを拾った瞬間にフラグを立てる方式にする。
		#    ただし、Playerスクリプトの改修が必要。
		#    
		#    代替案：WeaponBoxを拾うと、その場で「WeaponBoxアイテム」としてカウントしつつ、
		#    Player側に「weapon_box_held = true」みたいなフラグを立てる。
		
		# Playerスクリプト改修前なので、ここでは「スコアによる納品」とは別に、
		# 「武器ボックスを持っているなら解禁」という処理を入れる。
		# そのためにPlayer.gdに `has_weapon_box` フラグを追加する必要がある。
		
		if "has_weapon_box" in body and body.has_weapon_box:
			# 武器解禁通知（RPC）
			body.rpc("unlock_weapon", "smg") # 今回はSMG固定
			body.has_weapon_box = false
			print("Weapon Unlocked: SMG for ", body.name)
			
		if "held_items" in body and body.held_items > 0:
			var points = body.held_items * 100
			body.rpc("add_score", points)
			print("Delivered! Score:", body.score + points)
			
			body.rpc("reset_carry")
			rpc("spawn_delivery_effect", body.global_position)
			
			# ゲーム終了判定
			if body.score + points >= 500:
				print("Game Over! Winner: ", body.name)
				rpc("game_over", body.score + points)

# 武器ボックスのスポーン（敵死亡時やランダムなど）
# 今回はItemTimerで稀に出現させる
func _on_item_spawn_timer_timeout():
	if not multiplayer.is_server():
		return
	if $Items.get_child_count() >= 20:
		return
		
	# 10%の確率で武器ボックス
	var is_weapon_box = randf() < 0.1
	var item
	
	if is_weapon_box:
		# WeaponBox シーンをロード（変数定義が必要）
		var weapon_box_scene = load("res://WeaponBox.tscn")
		item = weapon_box_scene.instantiate()
	else:
		item = item_scene.instantiate()
		# ウェーブ進行に応じてスクラップ（アイテム）の価値を上げる
		# 基本score 100, ウェーブごとに+50。weightも少しずつ増やす(リスク増)
		item.score = 100 + ((current_wave - 1) * 50)
		item.weight = 1.0 + ((current_wave - 1) * 0.2)
		
	var screen_size = Vector2(1152, 648)
	item.position = Vector2(randf_range(50, screen_size.x - 50), randf_range(50, screen_size.y - 50))
	if item.position.distance_to(Vector2(576, 324)) < 150:
		return
	$Items.add_child(item, true)

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

@rpc("call_local")
func drop_items(pos, amount):
	if not multiplayer.is_server():
		return
		
	for i in range(amount):
		var item = item_scene.instantiate()
		# 少し散らばらせる
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		item.global_position = pos + offset
		$Items.add_child(item, true) # Spawnerが監視しているのはItemsノード

@rpc("any_peer", "call_local")
func remove_item(item_path):
	if not multiplayer.is_server():
		return
		
	var item_node = get_node_or_null(item_path)
	if item_node:
		item_node.queue_free()
