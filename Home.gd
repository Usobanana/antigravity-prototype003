extends Control

@onready var status_label = $StatusLabel
@onready var battle_button = $BattleButton

func _ready():
	NetworkManager.connection_established.connect(_on_connection_established)
	NetworkManager.game_started.connect(_on_game_started)
	
	battle_button.disabled = true
	status_label.text = "Initializing Network..."
	
	# 少し待ってから自動接続開始
	await get_tree().create_timer(0.5).timeout
	NetworkManager.try_auto_connect()
	status_label.text = "Searching for session..."

func _on_connection_established():
	if multiplayer.is_server():
		status_label.text = "Hosted Session (Waiting for players)"
		battle_button.disabled = false
		battle_button.text = "BATTLE START"
	else:
		status_label.text = "Connected as Client (Waiting for host)"
		battle_button.disabled = true
		battle_button.text = "Waiting..."

func _on_battle_button_pressed():
	if multiplayer.is_server():
		NetworkManager.rpc("start_game")

func _on_game_started():
	pass # NetworkManagerがシーン遷移を行う
