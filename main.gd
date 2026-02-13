extends Node2D

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
# プレイヤーの設計図を読み込んでおく
@export var player_scene: PackedScene = preload("res://Player.tscn")

func _ready():
	print("スクリプトが起動しました！")

func _on_host_button_pressed():
	print("Hostボタンが押されました")
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	
	# ホスト自身のプレイヤーを作成
	_add_player(1)
	
	# 新しい誰かが接続してきたら _add_player 関数を呼ぶ
	multiplayer.peer_connected.connect(_add_player)
	_hide_ui()

func _on_join_button_pressed():
	print("Joinボタンが押されました")
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(DEFAULT_SERVER_IP, PORT)
	multiplayer.multiplayer_peer = peer
	_hide_ui()

# プレイヤーを作成して画面に出す関数
func _add_player(id):
	print("プレイヤー追加: ", id)
	var player = player_scene.instantiate()
	player.name = str(id) # 名前をネットワークIDにして区別する
	add_child(player)

func _hide_ui():
	print("UIを非表示にします")
	$HostButton.hide()
	$JoinButton.hide()
