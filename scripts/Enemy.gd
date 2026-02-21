extends CharacterBody2D

# サーバー側でのみ設定される基本パラメータ
var SPEED = 100.0
var MAX_HEALTH = 3
var health = 3
var enemy_type = "normal" # scout, tank, shooter

var shoot_cooldown = 0.0
var shoot_interval = 2.0

func _ready():
	set_physics_process(is_multiplayer_authority())

func initialize(type: String, wave_multiplier: float):
	enemy_type = type
	match type:
		"scout":
			SPEED = BalanceConfig.BASE_SCOUT_SPEED + (wave_multiplier * 10)
			MAX_HEALTH = max(1, int(BalanceConfig.BASE_SCOUT_HEALTH * wave_multiplier))
		"tank":
			SPEED = BalanceConfig.BASE_TANK_SPEED + (wave_multiplier * 5)
			MAX_HEALTH = max(10, int(BalanceConfig.BASE_TANK_HEALTH * wave_multiplier))
		"shooter":
			SPEED = BalanceConfig.BASE_SHOOTER_SPEED + (wave_multiplier * 5)
			MAX_HEALTH = max(3, int(BalanceConfig.BASE_SHOOTER_HEALTH * wave_multiplier))
		_:
			SPEED = BalanceConfig.BASE_ENEMY_SPEED_NORMAL + (wave_multiplier * 10)
			MAX_HEALTH = max(3, int(BalanceConfig.BASE_ENEMY_HEALTH_NORMAL * wave_multiplier))
			
	health = MAX_HEALTH
	
	# ツリーに入っているか確認してからRPC（main.gd側の修正と併算）
	if is_inside_tree():
		rpc("update_visuals", type)
	else:
		# ツリーに入る前なら自分だけ実行（後で他のクライアントには同期時に伝わる想定）
		update_visuals(type)

@rpc("call_local")
func update_visuals(type: String):
	# クライアント側でも見た目を更新
	var rect = $ColorRect
	var col = $CollisionShape2D
	if not rect or not col: return
	
	match type:
		"scout":
			rect.color = Color(1.0, 0.5, 0.5) # 薄い赤
			rect.size = Vector2(10, 10)
			rect.position = Vector2(-5, -5)
			col.shape.size = Vector2(10, 10)
		"tank":
			rect.color = Color(0.5, 0.0, 0.0) # 濃い赤（大きめ）
			rect.size = Vector2(40, 40)
			rect.position = Vector2(-20, -20)
			col.shape.size = Vector2(40, 40)
		"shooter":
			rect.color = Color(1.0, 0.0, 1.0) # 紫
			# サイズはデフォルト(20)

func _physics_process(delta):
	var target = _find_nearest_player()
	
	if target:
		var distance = global_position.distance_to(target.global_position)
		var direction = (target.global_position - global_position).normalized()
		
		if enemy_type == "shooter" and distance < 250.0:
			# Shooter: 距離を保つ
			velocity = Vector2.ZERO
			_process_shooting(target, direction, delta)
		else:
			# 通常・Scout・Tankの場合は突撃
			velocity = direction * SPEED
			
		move_and_slide()
		
		# 衝突判定（接触攻撃）
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider.is_in_group("players"):
				if collider.has_method("hit"):
					collider.rpc("hit", 10)
					queue_free()
					break

func _process_shooting(_target, direction, delta):
	if shoot_cooldown > 0:
		shoot_cooldown -= delta
		return
		
	shoot_cooldown = shoot_interval
	# メインシーンに敵用弾の発射を依頼
	# 今回はBullet.tscnを流用し、「敵の弾」として扱う。弾のグループや衝突判定に依存。
	get_node("/root/Main").fire_enemy_bullet(global_position, direction.angle(), 300.0, 10)

func _find_nearest_player():
	var players = get_tree().get_nodes_in_group("players")
	var nearest = null
	var min_dist = INF
	
	for p in players:
		var d = global_position.distance_to(p.global_position)
		if d < min_dist:
			min_dist = d
			nearest = p
	return nearest

@rpc("any_peer", "call_local")
func hit(damage):
	if not is_multiplayer_authority():
		return
		
	health -= damage
	rpc("show_damage_visuals", damage)
	
	if health <= 0:
		queue_free()

@rpc("call_local")
func show_damage_visuals(damage_amount):
	AudioManager.play_se("hit", randf_range(1.0, 1.3))
	
	# 1. 視覚的ヒットストップ（フラッシュ）
	var rect = $ColorRect
	if rect:
		var original_color = rect.color
		rect.color = Color(1, 1, 1) # 白フラッシュ
		var t = Timer.new()
		t.wait_time = 0.05
		t.one_shot = true
		t.autostart = true
		t.timeout.connect(_on_flash_timeout.bind(original_color, t))
		add_child(t)
		
	# 2. ダメージ数字のポップアップ（親に追加してEnemy消滅後も残す）
	var label = Label.new()
	label.text = str(damage_amount)
	label.modulate = Color(1, 0.8, 0) # 黄色
	
	var parent = get_parent()
	if parent:
		parent.add_child(label)
		label.global_position = global_position + Vector2(-10, -30)
		
		# Tweenによるアニメーション（上へ浮かびながら消える）
		var tween = label.create_tween()
		tween.tween_property(label, "global_position", label.global_position + Vector2(0, -30), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(label.queue_free)

func _on_flash_timeout(original_color, timer):
	var rect = get_node_or_null("ColorRect")
	if is_instance_valid(rect):
		rect.color = original_color
	if is_instance_valid(timer):
		timer.queue_free()
