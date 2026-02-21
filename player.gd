extends CharacterBody2D

const SPEED = 300.0

func _enter_tree():
	# プレイヤーをグループに追加（敵が追跡するため）
	add_to_group("players")
	
	# このプレイヤーが「自分」のものか、ネットワークIDで判定
	var id = name.to_int()
	if id != 0:
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

var is_peace_mode = false
var has_weapon_box = false # 武器ボックスを持っているか

var _fire_cooldown = 0.0
var fire_rate = 0.2 # デフォルト
var bullet_speed = 400.0
var weapon_damage = 10
var weapon_weight = 0.0
var weapon_type = "normal" # normal, spread, piercing

# 弾薬・リロード
var max_ammo = 12
var current_ammo = 12
var reload_time = 1.5
var is_reloading = false
var weapon_icon_color = Color(0.6, 0.6, 0.6)
var weapon_name = "Pistol"

# 体力管理
@export var health = 100
var MAX_HEALTH = 100 

func _ready():
	# PlayerDataManagerからステータス反映
	var pdm = get_node_or_null("/root/PlayerDataManager")
	if pdm:
		max_carry_capacity = pdm.get_max_weight()
		health = pdm.get_max_hp()
		MAX_HEALTH = pdm.get_max_hp()
		
		# 武器ステータス反映
		var weapon_stats = pdm.get_equipped_weapon_stats()
		fire_rate = weapon_stats.get("fire_rate", 0.5)
		bullet_speed = weapon_stats.get("bullet_speed", 400.0)
		weapon_damage = weapon_stats.get("damage", 10)
		weapon_weight = weapon_stats.get("weight", 0.0)
		weapon_type = weapon_stats.get("type", "normal")
		
		max_ammo = weapon_stats.get("max_ammo", 12)
		reload_time = weapon_stats.get("reload_time", 1.5)
		weapon_icon_color = weapon_stats.get("icon_color", Color(0.6, 0.6, 0.6))
		weapon_name = weapon_stats.get("name", "Pistol")
		
		current_ammo = max_ammo
		
		# 武器重量を加算（現在の重量に）
		current_weight += weapon_weight
	else:
		health = 100
		MAX_HEALTH = 100
	
	# IDが設定された後にも呼ばれるように、Authorityチェックをここでも行う
	if name == str(multiplayer.get_unique_id()):
		set_multiplayer_authority(multiplayer.get_unique_id())
		_update_weapon_hud_init()
		_update_weapon_hud()

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

			# カメラズーム調整
			if is_peace_mode:
				camera.zoom = Vector2(1.5, 1.5) # 拠点は少し寄る
			else:
				camera.zoom = Vector2(1.0, 1.0) # バトルは標準



func _physics_process(delta):
	# UI更新（自分の場合のみ）
	if is_multiplayer_authority():
		var ui_node = get_parent().get_node_or_null("UI")
		if not ui_node:
			# Mainシーンの構造に依存している場合のフォールバック
			ui_node = get_tree().current_scene.get_node_or_null("UI")
			
		if ui_node:
			var hp_bar = ui_node.get_node_or_null("HealthBar")
			if hp_bar:
				hp_bar.value = health
				var style_box = hp_bar.get_theme_stylebox("fill")
				if style_box is StyleBoxFlat:
					style_box.bg_color = Color(1.0 - (float(health)/MAX_HEALTH), float(health)/MAX_HEALTH, 0.2)
			
			var score_label = ui_node.get_node_or_null("ScoreLabel")
			if score_label:
				score_label.text = "Score: " + str(score)
				
			var weight_label = ui_node.get_node_or_null("WeightLabel")
			if weight_label:
				weight_label.text = "Weight: " + str(int(current_weight)) + " / " + str(int(max_carry_capacity))
				if current_weight > max_carry_capacity:
					weight_label.modulate = Color(1, 0, 0)
				else:
					weight_label.modulate = Color(1, 1, 1)

			# リロードバー（HUD側）のアニメーション更新
			if is_reloading:
				var hud_reload_bar = ui_node.get_node_or_null("WeaponHUD/ReloadBar")
				if hud_reload_bar:
					hud_reload_bar.value += (100.0 / reload_time) * delta
					if hud_reload_bar.value >= 100: hud_reload_bar.value = 100

	# オーバーヘッドリロードバーの更新（全員の分）
	if is_reloading:
		var overhead_bar = $ReloadBar
		if overhead_bar:
			overhead_bar.value += (100.0 / reload_time) * delta

	# 死亡時は操作不能
	if health <= 0 and not is_peace_mode:
		visible = false
		return
		
	# Peace Modeなら強制表示
	if is_peace_mode:
		visible = true
		health = MAX_HEALTH

	visible = true

	# クールダウン更新
	if _fire_cooldown > 0:
		_fire_cooldown -= delta

	# 「自分」のキャラクターだけがキー入力を受け付ける
	if is_multiplayer_authority():
		var direction = Vector2.ZERO
		# UIノードを動的に探す（BattleでもHomeでも対応）
		var ui_node = get_parent().get_node_or_null("UI")
		if not ui_node:
			# Mainシーンの構造に依存している場合のフォールバック
			ui_node = get_tree().current_scene.get_node_or_null("UI")
			
		var has_joystick_input = false
		
		# 1. 左スティック（移動）の入力を取得
		if ui_node:
			var left_stick = ui_node.get_node_or_null("LeftStick")
			if left_stick:
				var stick_vector = left_stick.get_output()
				if stick_vector.length() > 0:
					direction = stick_vector
					has_joystick_input = true
			else:
				pass
		else:
			pass

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
			var right_stick = ui_node.get_node_or_null("RightStick")
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
	if is_peace_mode: return
	if _fire_cooldown > 0: return
	
	if is_reloading: return
	if current_ammo <= 0:
		start_reload()
		return

	# 弾薬消費
	current_ammo -= 1
	_update_weapon_hud()
		
	_fire_cooldown = fire_rate
	
	if weapon_type == "spread":
		# ショットガン：5発散弾
		var pellet_count = 5
		var spread_angle = deg_to_rad(30.0) # 全体の広がり角度(30度)
		var start_angle = rotation - (spread_angle / 2.0)
		var angle_step = spread_angle / float(pellet_count - 1)
		
		for i in range(pellet_count):
			var current_angle = start_angle + (angle_step * i)
			if multiplayer.is_server():
				get_node("/root/Main").fire_bullet(global_position, current_angle, bullet_speed, weapon_damage, weapon_type)
			else:
				get_node("/root/Main").rpc_id(1, "fire_bullet", global_position, current_angle, bullet_speed, weapon_damage, weapon_type)
	else:
		# 通常 / 貫通
		if multiplayer.is_server():
			get_node("/root/Main").fire_bullet(global_position, rotation, bullet_speed, weapon_damage, weapon_type)
		else:
			get_node("/root/Main").rpc_id(1, "fire_bullet", global_position, rotation, bullet_speed, weapon_damage, weapon_type)

	if current_ammo <= 0:
		start_reload()

func start_reload():
	if is_reloading: return
	rpc("set_reloading_state", true)
	
	# リロード完了待ち
	await get_tree().create_timer(reload_time).timeout
	
	# 完了処理
	current_ammo = max_ammo
	rpc("set_reloading_state", false)
	_update_weapon_hud()

@rpc("call_local")
func set_reloading_state(state):
	is_reloading = state
	
	# オーバーヘッドバーの表示切替
	var overhead_bar = $ReloadBar
	if overhead_bar:
		overhead_bar.visible = state
		if state:
			overhead_bar.value = 0
			
	# 自分自身のUI更新
	if is_multiplayer_authority():
		var ui_node = get_parent().get_node_or_null("UI")
		if not ui_node:
			ui_node = get_tree().current_scene.get_node_or_null("UI")
		if ui_node:
			var hud = ui_node.get_node_or_null("WeaponHUD")
			var hud_bar = hud.get_node_or_null("ReloadBar") if hud else null
			if hud_bar:
				hud_bar.visible = state
				if state:
					hud_bar.value = 0
					
		if not state:
			_update_weapon_hud() # 弾数を最大に戻す表示

func _update_weapon_hud_init():
	var ui_node = get_parent().get_node_or_null("UI")
	if not ui_node:
		ui_node = get_tree().current_scene.get_node_or_null("UI")
	if not ui_node: return
	
	var hud = ui_node.get_node_or_null("WeaponHUD")
	if not hud: return
	
	hud.get_node("Icon").color = weapon_icon_color
	hud.get_node("NameLabel").text = weapon_name

func _update_weapon_hud():
	if not is_multiplayer_authority(): return
	
	var ui_node = get_parent().get_node_or_null("UI")
	if not ui_node:
		ui_node = get_tree().current_scene.get_node_or_null("UI")
	if not ui_node: return
	
	var hud = ui_node.get_node_or_null("WeaponHUD")
	if not hud: return
	
	var ammo_label = hud.get_node("AmmoLabel")
	ammo_label.text = str(current_ammo) + " / " + str(max_ammo)
	
	if float(current_ammo) / max_ammo <= 0.3:
		ammo_label.modulate = Color(1, 0, 0) # Red
	else:
		ammo_label.modulate = Color(1, 1, 1) # White

func set_peace_mode(enabled: bool):
	is_peace_mode = enabled
	var camera = $Camera2D
	if camera:
		if enabled:
			camera.zoom = Vector2(1.5, 1.5)
		else:
			camera.zoom = Vector2(1.0, 1.0)
	
	if enabled:
		# 拠点ではUI隠す？今回は表示したままでOK
		pass

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
	if is_peace_mode: return
	
	await get_tree().create_timer(3.0).timeout
	health = MAX_HEALTH
	# ランダムな位置にリスポーン
	position = Vector2(randf_range(100, 700), randf_range(100, 500))
	current_ammo = max_ammo # リスポーンで弾補充
	is_reloading = false
	rpc("set_reloading_state", false)
	_update_weapon_hud()

# アイテム取得（ローカル呼び出しだが、結果は同期変数を通じて伝播）
func pickup(item_node):
	if not is_multiplayer_authority():
		return
		
	# 武器ボックスの場合
	if item_node.is_in_group("weapon_box"):
		if has_weapon_box: return # すでに持っているなら拾わない
		
		current_weight += item_node.weight
		has_weapon_box = true
		# サーバーに同期
		rpc("set_has_weapon_box_server", true)
		_update_visuals()
		
		# 削除リクエスト
		if multiplayer.is_server():
			item_node.queue_free()
		else:
			call_deferred("_disable_item", item_node)
			get_node("/root/Main").rpc_id(1, "remove_item", item_node.get_path())
		return

	# 通常アイテムの場合
	# 重量加算
	current_weight += item_node.weight
	held_items += 1
	
	# アイテム削除リクエスト（サーバーにて実行）
	if multiplayer.is_server():
		item_node.queue_free()
	else:
		call_deferred("_disable_item", item_node)
		get_node("/root/Main").rpc_id(1, "remove_item", item_node.get_path())

	_update_visuals()

# 荷物の可視化更新
func _update_visuals():
	# 既存の可視化をクリア（再描画）
	for child in get_children():
		if child is ColorRect and child.color == Color(0, 0.5, 1):
			child.queue_free()
		if child is ColorRect and child.color == Color(1, 0.5, 0): # WeaponBox色
			child.queue_free()

	for i in range(held_items):
		var visual = ColorRect.new()
		visual.size = Vector2(10, 10)
		visual.color = Color(0, 0.5, 1) # 青色
		visual.position = Vector2(-5, -25 - (i * 10)) # 頭上に積み上げ
		add_child(visual)

	if has_weapon_box:
		var visual = ColorRect.new()
		visual.size = Vector2(20, 20)
		visual.color = Color(1, 0.5, 0) # オレンジ色
		# 通常アイテムの上に積む
		visual.position = Vector2(-10, -25 - (held_items * 10) - 20)
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
	if is_peace_mode: return

	# 持っていたアイテムをばら撒く
	if held_items > 0:
		if multiplayer.is_server():
			get_node("/root/Main").drop_items(global_position, held_items)
		else:
			get_node("/root/Main").rpc_id(1, "drop_items", global_position, held_items)
	
	current_weight = 0
	held_items = 0
	is_reloading = false
	rpc("set_reloading_state", false)
	
	# 視覚的な荷物を削除
	for child in get_children():
		if child is ColorRect and (child.color == Color(0, 0.5, 1) or child.color == Color(1, 0.5, 0)):
			child.queue_free()

	health = 0
	# 演出として少し待ってからリスポーン
	if multiplayer.is_server():
		_respawn_after_delay()

@rpc("any_peer", "call_local")
func unlock_weapon(weapon_id):
	if not is_multiplayer_authority(): return
	
	# PlayerDataManager経由で解禁
	var pdm = get_node_or_null("/root/PlayerDataManager")
	if pdm:
		pdm.unlock_weapon(weapon_id)
		# 通知表示（簡易）
		var ui_node = get_parent().get_node_or_null("UI")
		if ui_node:
			var label = Label.new()
			label.text = "NEW WEAPON UNLOCKED: " + weapon_id
			label.modulate = Color(1, 1, 0)
			label.position = Vector2(500, 100)
			ui_node.add_child(label)
			await get_tree().create_timer(3.0).timeout
			label.queue_free()

@rpc("any_peer", "call_local")
func set_has_weapon_box_server(value):
	if multiplayer.is_server():
		has_weapon_box = value
		# 必要なら他のクライアントにも通知する（visuals用）が、今回はpickupした本人のvisualsとServerのロジック用で十分

func _disable_item(item_node):
	if is_instance_valid(item_node):
		item_node.visible = false
		# process_modeを変えると同期が切れる可能性があるので、物理と可視性だけを切る
		item_node.set_deferred("monitorable", false)
		item_node.set_deferred("monitoring", false)
		
		var collision_shape = item_node.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.set_deferred("disabled", true)
