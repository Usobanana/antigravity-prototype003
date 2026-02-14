extends Node2D

@onready var network_status_label = $UI/Header/NetworkStatus
@onready var materials_label = $UI/Header/MaterialsLabel
@onready var interaction_panel = $UI/InteractionPanel
@onready var panel_title = $UI/InteractionPanel/Title
@onready var panel_desc = $UI/InteractionPanel/Description
@onready var action_btn = $UI/InteractionPanel/ActionBtn

# プレイヤー参照（ダイナミック生成）
var player_scene = preload("res://Player.tscn")
var player

# インタラクション状態
var current_facility = ""

func _ready():
	NetworkManager.connection_established.connect(_on_connection_established)
	NetworkManager.game_started.connect(_on_game_started)
	# 切断時や接続失敗時もプレイヤーを再生成（IDリセットのため）
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	_spawn_local_player()
		
	# UI初期化
	update_materials_ui()
	interaction_panel.visible = false
	
	# ネットワーク初期化
	if multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		# 既に接続済みなら再接続しない
		if multiplayer.is_server():
			network_status_label.text = "Status: Hosted Session"
		else:
			network_status_label.text = "Status: Connected as Client"
		_spawn_local_player()
	else:
		network_status_label.text = "Initializing Network..."
		await get_tree().create_timer(0.5).timeout
		NetworkManager.try_auto_connect()
		network_status_label.text = "Searching for session..."

func _spawn_local_player():
	# ツリーに含まれていない、またはマルチプレイヤーAPIがない場合は中止
	if not is_inside_tree() or not multiplayer:
		return

	# 既存プレイヤーがいれば即座に削除（名前衝突防止）
	if player:
		player.free()
		player = null

	player = player_scene.instantiate()
	
	# Homeシーンでは同期を行わないため、MultiplayerSynchronizerを削除する
	# ツリーに追加する前に削除することで、同期パケットが送信されるのを防ぐ
	var synchronizer = player.get_node_or_null("MultiplayerSynchronizer")
	if synchronizer:
		synchronizer.free()
		
	# 名前と権限を設定
	player.name = str(multiplayer.get_unique_id())
	player.set_multiplayer_authority(multiplayer.get_unique_id())
	
	# 拠点用設定
	player.set_peace_mode(true)
	
	# 位置を中心に
	player.position = Vector2(0, 0)
	
	add_child(player)
	
	# カメラ設定（ツリー追加後）
	if player.is_multiplayer_authority():
		var camera = player.get_node("Camera2D")
		if camera:
			camera.enabled = true
			camera.make_current()


func update_materials_ui():
	# Autoloadがなぜか認識されない場合があるため、明示的にノードを取得
	var pdm = get_node_or_null("/root/PlayerDataManager")
	var amount = 0
	if pdm:
		amount = pdm.get_materials()
	materials_label.text = "Materials: " + str(amount)

func _on_connection_established():
	if not multiplayer: return
	
	if multiplayer.is_server():
		network_status_label.text = "Status: Hosted Session"
	else:
		network_status_label.text = "Status: Connected as Client"
		
	# プレイヤーID再設定
	_spawn_local_player()

func _on_server_disconnected():
	network_status_label.text = "Status: Disconnected"
	_spawn_local_player() # ID 1 (Offline) で再生成

func _on_connection_failed():
	network_status_label.text = "Status: Connection Failed"
	_spawn_local_player() # ID 1 (Offline) で再生成

func _on_game_started():
	pass

func _process(_delta):
	# マルチプレイヤーAPI確認
	if not multiplayer: return

	# デバッグ用情報表示
	var status = "ID: " + str(multiplayer.get_unique_id())
	if player:
		status += " | P_Name: " + player.name
		status += " | P_Auth: " + str(player.get_multiplayer_authority())
		status += " | Is_Auth: " + str(player.is_multiplayer_authority())
		status += " | Pos: " + str(player.position)
		if player.is_multiplayer_authority():
			var ui_node = get_node_or_null("UI")
			if ui_node:
				var stick = ui_node.get_node_or_null("LeftStick")
				if stick:
					status += " | Stick: " + str(stick.get_output())
				else:
					status += " | No Stick"
			else:
				status += " | No UI"
	
	network_status_label.text = status

# --- Interaction Signals ---

func _on_lab_entered(body):
	if body == player:
		$Facilities/Laboratory/Indicator.visible = true
		current_facility = "LAB"
		var pdm = get_node_or_null("/root/PlayerDataManager")
		var cost = 0
		if pdm: cost = pdm.get_upgrade_cost("weight")
		_show_interaction_popup("Laboratory", "Upgrade Max Weight (+2.0)?\nCost: " + str(cost) + " Mats", "Upgrade")

func _on_lab_exited(body):
	if body == player:
		$Facilities/Laboratory/Indicator.visible = false
		_close_interaction_panel()

func _on_armory_entered(body):
	if body == player:
		$Facilities/Armory/Indicator.visible = true
		current_facility = "ARMORY"
		_show_interaction_popup("Armory", "Access Weapon Storage?", "OPEN")

func _on_armory_exited(body):
	if body == player:
		$Facilities/Armory/Indicator.visible = false
		_close_interaction_panel()
		# UIも閉じる
		var ui = get_node_or_null("UI/ArmoryUI")
		if ui: ui.visible = false

func _on_gate_entered(body):
	if body == player:
		$Facilities/MissionGate/Indicator.visible = true
		current_facility = "GATE"
		if multiplayer.is_server():
			_show_interaction_popup("Mission Gate", "Start Battle?", "DEPART")
		else:
			_show_interaction_popup("Mission Gate", "Waiting for Host...", "Wait")
			action_btn.disabled = true

func _on_gate_exited(body):
	if body == player:
		$Facilities/MissionGate/Indicator.visible = false
		_close_interaction_panel()

# --- UI Logic ---

func _show_interaction_popup(title, desc, btn_text):
	panel_title.text = title
	panel_desc.text = desc
	action_btn.text = btn_text
	action_btn.disabled = (current_facility == "GATE" and not multiplayer.is_server())
	interaction_panel.visible = true

func _close_interaction_panel():
	interaction_panel.visible = false
	current_facility = ""

func _on_close_btn_pressed():
	_close_interaction_panel()

func _on_action_btn_pressed():
	match current_facility:
		"LAB":
	# 既存のパネルは閉じてLabUIを見せる
			_close_interaction_panel()
			_toggle_lab_ui()
			
		"ARMORY":
			_toggle_armory_ui()
			_close_interaction_panel() # パネルは閉じてArmoryUIを見せる
			
		"GATE":
			if multiplayer.is_server():
				NetworkManager.rpc("start_game")

func _toggle_lab_ui():
	var ui = get_node_or_null("UI/LabUI")
	if not ui: return
	
	ui.visible = not ui.visible
	if ui.visible:
		_refresh_lab_ui()
		
		# ボタン接続（初回のみ行うガードが必要だが、簡易的に毎回切断・接続するか、
		# _readyでやるのが良い。今回は簡易的にここでConnect（重複防止付き））
		var w_btn = ui.get_node("Panel/VBoxContainer/WeightUpgrade/Button")
		var h_btn = ui.get_node("Panel/VBoxContainer/HPUpgrade/Button")
		var c_btn = ui.get_node("Panel/CloseBtn")
		
		if not w_btn.pressed.is_connected(_upgrade_weight): w_btn.pressed.connect(_upgrade_weight)
		if not h_btn.pressed.is_connected(_upgrade_hp): h_btn.pressed.connect(_upgrade_hp)
		if not c_btn.pressed.is_connected(_close_lab_ui): c_btn.pressed.connect(_close_lab_ui)

func _close_lab_ui():
	var ui = get_node_or_null("UI/LabUI")
	if ui: ui.visible = false

func _refresh_lab_ui():
	var ui = get_node_or_null("UI/LabUI")
	if not ui: return
	
	var pdm = get_node_or_null("/root/PlayerDataManager")
	if not pdm: return
	
	# Weight
	var w_info = ui.get_node("Panel/VBoxContainer/WeightUpgrade/Info")
	var w_btn = ui.get_node("Panel/VBoxContainer/WeightUpgrade/Button")
	var w_current = pdm.get_max_weight()
	var w_next = w_current + pdm.WEIGHT_UPGRADE_AMOUNT
	var w_cost = pdm.get_upgrade_cost("weight")
	w_info.text = "Max Weight: " + str(w_current) + " -> " + str(w_next)
	w_btn.text = "Upgrade (" + str(w_cost) + " Mats)"
	w_btn.disabled = (pdm.get_materials() < w_cost)
	
	# HP
	var h_info = ui.get_node("Panel/VBoxContainer/HPUpgrade/Info")
	var h_btn = ui.get_node("Panel/VBoxContainer/HPUpgrade/Button")
	var h_current = pdm.get_max_hp()
	var h_next = h_current + pdm.HP_UPGRADE_AMOUNT
	var h_cost = pdm.get_upgrade_cost("hp")
	h_info.text = "Max HP: " + str(h_current) + " -> " + str(h_next)
	h_btn.text = "Upgrade (" + str(h_cost) + " Mats)"
	h_btn.disabled = (pdm.get_materials() < h_cost)
	
	# Update Header
	update_materials_ui()

func _upgrade_weight():
	var pdm = get_node_or_null("/root/PlayerDataManager")
	if pdm and pdm.upgrade_weight():
		_refresh_lab_ui()
		# Playerステータス即時反映
		if player: player.max_carry_capacity = pdm.get_max_weight()

func _upgrade_hp():
	var pdm = get_node_or_null("/root/PlayerDataManager")
	if pdm and pdm.upgrade_hp():
		_refresh_lab_ui()
		# Playerステータス即時反映（HP満タン化するかは選択だが、今回は最大値のみ更新）
		# player.MAX_HEALTH 更新機能が必要だが、Player.gdが _ready で取得するだけなら再取得メソッドが必要
		# とりあえず簡易的に
		if player: 
			player.MAX_HEALTH = pdm.get_max_hp()
			player.health = player.MAX_HEALTH

func _toggle_armory_ui():
	var ui = get_node_or_null("UI/ArmoryUI")
	if not ui: return
	
	ui.visible = not ui.visible
	if ui.visible:
		# Closeボタンの接続も確認
		# ArmoryUIにはCloseBtnあったっけ？
		# ArmoryUIの構造を確認すると、Panel直下にCloseBtnがないかも。
		# Home.tscn の定義を見ると... ArmoryUIにはCloseBtnがない！
		# 追加するか、ESCキー、あるいはトグルで閉じるか。
		# 既存コードでは `_close_interaction_panel()` で InteractionPanel は閉じている。
		# ArmoryUIを閉じる手段がないと詰む。
		# 後でHome.tscnにArmoryUIのCloseBtnも足すべき。
		_refresh_weapon_list()

func _refresh_weapon_list():
	var list_container = get_node_or_null("UI/ArmoryUI/Panel/ScrollContainer/VBoxContainer")
	if not list_container: return
	
	# クリア
	for child in list_container.get_children():
		child.queue_free()
		
	# データ取得
	var pdm = get_node_or_null("/root/PlayerDataManager")
	if not pdm: return
	
	var unlocked = pdm.data.get("weapons_unlocked", ["pistol"])
	var equipped = pdm.get_equipped_weapon_id()
	var db = pdm.WEAPON_DB
	
	for w_id in unlocked:
		var data = db.get(w_id, {})
		var btn = Button.new()
		var text = data.get("name", w_id)
		if w_id == equipped:
			text += " [EQUIPPED]"
			btn.disabled = true
		
		btn.text = text
		btn.pressed.connect(func(): _equip_weapon(w_id))
		list_container.add_child(btn)
		
	# 閉じるボタン（簡易的にリストの最後に追加しておく？）
	# いや、UI外クリックか、ArmoryUI内にCloseボタンを追加するのが筋。
	var close_btn = Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(func(): get_node("UI/ArmoryUI").visible = false)
	list_container.add_child(close_btn)

func _equip_weapon(weapon_id):
	var pdm = get_node_or_null("/root/PlayerDataManager")
	if pdm:
		pdm.equip_weapon(weapon_id)
		_refresh_weapon_list()
