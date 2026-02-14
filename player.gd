extends CharacterBody2D

const SPEED = 300.0

func _enter_tree():
	# プレイヤーをグループに追加（敵が追跡するため）
	add_to_group("players")
	
	# このプレイヤーが「自分」のものか、ネットワークIDで判定
	var id = name.to_int()
	set_multiplayer_authority(id)

# カメラ設定
@export var camera_smoothing_speed : float = 20.0
@export var drag_margin : float = 0.2

# 重量・スコア管理
@export var score = 0
@export var current_weight = 0.0
@export var max_carry_capacity = 10.0
# 視覚的スタック表示用
var held_items = 0

func _ready():
	if is_multiplayer_authority():
		var camera = $Camera2D
		if camera:
			camera.enabled = true
			camera.make_current()
			camera.position_smoothing_speed = camera_smoothing_speed
			camera.drag_left_margin = drag_margin
			camera.drag_top_margin = drag_margin
			camera.drag_right_margin = drag_margin
			camera.drag_bottom_margin = drag_margin


var _fire_cooldown = 0.0
const FIRE_RATE = 0.2 # 0.2秒に1発

# 体力管理
@export var health = 100
const MAX_HEALTH = 100

func _physics_process(delta):
	# UI更新（自分の場合のみ）
	if is_multiplayer_authority():
		var ui_node = get_node_or_null("/root/Main/UI")
		if ui_node:
			var hp_bar = ui_node.get_node_or_null("HealthBar")
			if hp_bar:
				hp_bar.value = health
				
				# ダメージ演出（赤点滅など）はシェーダーやAnimationPlayerでやるのが本格的だが
				# 簡易的に色を変える例
				var style_box = hp_bar.get_theme_stylebox("fill")
				if style_box is StyleBoxFlat:
					# HPが減った割合に応じて色を変える（緑->赤）
					style_box.bg_color = Color(1.0 - (float(health)/MAX_HEALTH), float(health)/MAX_HEALTH, 0.2)

			var score_label = ui_node.get_node_or_null("ScoreLabel")
			if score_label:
				score_label.text = "Score: " + str(score)
				
			var weight_label = ui_node.get_node_or_null("WeightLabel")
			if weight_label:
				weight_label.text = "Weight: " + str(int(current_weight)) + " / " + str(int(max_carry_capacity))
				if current_weight > max_carry_capacity:
					weight_label.modulate = Color(1, 0, 0) # Overweight warning
				else:
					weight_label.modulate = Color(1, 1, 1)

	# 死亡時は操作不能
	if health <= 0:
		visible = false
		return

	visible = true

	# クールダウン更新
	if _fire_cooldown > 0:
		_fire_cooldown -= delta

	# 「自分」のキャラクターだけがキー入力を受け付ける
	if is_multiplayer_authority():
		var direction = Vector2.ZERO
		var ui_node = get_node_or_null("/root/Main/UI")
		var has_joystick_input = false
		
		# 1. 左スティック（移動）の入力を取得
		if ui_node:
			var left_stick = ui_node.get_node("LeftStick")
			if left_stick:
				var stick_vector = left_stick.get_output()
				if stick_vector.length() > 0:
					direction = stick_vector
					has_joystick_input = true

		# スティック入力がない場合はキーボードを使用
		if not has_joystick_input:
			direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

		# 重量による速度制限
		var current_speed = SPEED
		if current_weight > max_carry_capacity:
			current_speed *= 0.5 # 50%減速

		velocity = direction * current_speed
		move_and_slide()
		

		# 2. 右スティック（エイム＆攻撃）の処理
		var use_mouse_aim = true
		if ui_node:
			var right_stick = ui_node.get_node("RightStick")
			if right_stick:
				var aim_vector = right_stick.get_output()
				if aim_vector.length() > 0:
					rotation = aim_vector.angle()
					fire()
					use_mouse_aim = false
		
		# マウス操作（PC用）も維持（右スティック入力がない場合のみ）
		if use_mouse_aim:
			look_at(get_global_mouse_position())

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			fire()

func fire():
	if _fire_cooldown > 0:
		return
		
	_fire_cooldown = FIRE_RATE
	
	if multiplayer.is_server():
		# 自分がサーバー（ホスト）なら直接実行
		get_node("/root/Main").fire_bullet(global_position, rotation)
	else:
		# クライアントならサーバーへリクエスト
		get_node("/root/Main").rpc_id(1, "fire_bullet", global_position, rotation)

@rpc("any_peer", "call_local")
func hit(damage):
	# サーバー権限でのみHPを減らす（同期変数がクライアントに伝播する）
	if not is_multiplayer_authority():
		return
		
	health -= damage
	print("Player hit! HP:", health)
	
	if health <= 0:
		die()

func _respawn_after_delay():
	await get_tree().create_timer(3.0).timeout
	health = MAX_HEALTH
	# ランダムな位置にリスポーン
	position = Vector2(randf_range(100, 700), randf_range(100, 500))

# アイテム取得（ローカル呼び出しだが、結果は同期変数を通じて伝播）
func pickup(item_node):
	if not is_multiplayer_authority():
		return
		
	# 重量加算
	current_weight += item_node.weight
	held_items += 1
	
	# アイテム削除リクエスト（サーバーにて実行）
	if multiplayer.is_server():
		item_node.queue_free()
	else:
		item_node.queue_free() # クライアント側で先に見えなくする
		get_node("/root/Main").rpc_id(1, "remove_item", item_node.get_path())

	_update_visuals()

# 荷物の可視化更新
func _update_visuals():
	var visual = ColorRect.new()
	visual.size = Vector2(10, 10)
	visual.color = Color(0, 0.5, 1) # 青色
	visual.position = Vector2(-5, -25 - (held_items * 10)) # 頭上に積み上げ
	add_child(visual)

# 荷物リセット（納品時など）
@rpc("call_local")
func reset_carry():
	current_weight = 0
	held_items = 0
	# 視覚的な荷物を削除
	for child in get_children():
		if child is ColorRect and child.color == Color(0, 0.5, 1):
			child.queue_free()

@rpc("call_local")
func add_score(points):
	score += points

# 死亡時ドロップ処理
func die():
	# 持っていたアイテムをばら撒く
	if held_items > 0:
		if multiplayer.is_server():
			get_node("/root/Main").drop_items(global_position, held_items)
		else:
			get_node("/root/Main").rpc_id(1, "drop_items", global_position, held_items)
	
	current_weight = 0
	held_items = 0
	# 視覚的な荷物を削除
	for child in get_children():
		if child is ColorRect and child.color == Color(0, 0.5, 1):
			child.queue_free()

	health = 0
	# 演出として少し待ってからリスポーン
	if multiplayer.is_server():
		_respawn_after_delay()
