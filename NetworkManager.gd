extends Node

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"

signal connection_established
signal game_started

var peer: WebSocketMultiplayerPeer

# プレイヤー情報（ID: {score: 0, etc}）
var players = {}
var last_score = 0

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# 自動接続ロジック（クライアントとして試行 -> 失敗ならホスト）
func try_auto_connect():
	print("Auto-connecting...")
	peer = WebSocketMultiplayerPeer.new()
	var error = peer.create_client("ws://" + DEFAULT_SERVER_IP + ":" + str(PORT))
	if error != OK:
		print("Client creation failed, starting as host.")
		start_host()
		return
	
	multiplayer.multiplayer_peer = peer
	
	# 接続タイムアウト監視（簡易的）
	# 実際には connection_failed が呼ばれるのを待つが、
	# WebSocketの場合、サーバーがいなければ即座に切断されるか、タイムアウトする
	# ここでは少し待って繋がらなければホストになるタイマーを仕掛ける手もあるが
	# GodotのWebSocketは接続できないと割とすぐに connection_failed か closed になる
	
func start_host():
	print("Starting as Host...")
	peer = WebSocketMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	_on_connected_to_server() # ホスト自身も準備完了扱い
	
func _on_peer_connected(id):
	print("Peer connected: ", id)
	# プレイヤー情報の初期化など

func _on_peer_disconnected(id):
	print("Peer disconnected: ", id)
	players.erase(id)

func _on_connected_to_server():
	print("Connected to server!")
	connection_established.emit()
	# ホーム画面で「Connected」表示などに利用

func _on_connection_failed():
	print("Connection failed. Switching to Host mode...")
	multiplayer.multiplayer_peer = null
	start_host()

func _on_server_disconnected():
	print("Server disconnected")
	# タイトルに戻るなどの処理
	get_tree().change_scene_to_file("res://Title.tscn")

# ゲーム開始（シーン遷移）
@rpc("any_peer", "call_local")
func start_game():
	# 物理演算中の呼び出しエラー回避のため deferred で実行
	call_deferred("_change_scene", "res://main.tscn", true)

# リザルト遷移
@rpc("any_peer", "call_local")
func end_game():
	call_deferred("_change_scene", "res://Result.tscn")

func _change_scene(path, emit_start_signal = false):
	get_tree().change_scene_to_file(path)
	if emit_start_signal:
		game_started.emit()
