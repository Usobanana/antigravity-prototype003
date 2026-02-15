extends Node

const PORT = 7000
var server_ip = "127.0.0.1"

const CERT_FILE = "res://server.pem"
const KEY_FILE = "res://key.pem"

signal connection_established
signal game_started

var peer: WebSocketMultiplayerPeer

# プレイヤー情報（ID: {score: 0, etc}）
var players = {}
var last_score = 0

func _ready():
	# Web版の場合、ブラウザのURL（ホスト名）をサーバーIPとして採用する
	if OS.has_feature("web"):
		var hostname = JavaScriptBridge.eval("window.location.hostname")
		if hostname and hostname != "":
			server_ip = hostname
			print("Web environment detected. Server IP set to: ", server_ip)
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# 接続先URL（空の場合は自動検出/ローカル）
var target_url = ""

# 自動接続ロジック（クライアントとして試行 -> 失敗ならホスト）
func try_auto_connect():
	var url = ""
	if target_url != "":
		url = target_url
		print("Connecting to custom URL: ", url)
	else:
		# デフォルト動作
		print("Auto-connecting to ", server_ip, ":", PORT)
		# Web版はHTTPSで配信されているため、WSS (Secure WebSocket) 必須
		# 自己署名証明書のため verify_unsafe を使用
		url = "wss://" + server_ip + ":" + str(PORT)

	var peer = WebSocketMultiplayerPeer.new()
	var tls_options = TLSOptions.client_unsafe()
	
	var error = peer.create_client(url, tls_options)
	if error != OK:
		print("Client creation failed.")
		_try_start_host()
		return
	
	multiplayer.multiplayer_peer = peer

func _try_start_host():
	# Webエクスポートではサーバーになれないため、ホスト起動はスキップ
	if OS.has_feature("web"):
		print("Cannot host on Web platform.")
		return

	print("Starting as Host...")
	peer = WebSocketMultiplayerPeer.new()
	
	# サーバー側も証明書を読み込んで WSS 対応にする
	var tls_options = null
	if FileAccess.file_exists(CERT_FILE) and FileAccess.file_exists(KEY_FILE):
		var cert = X509Certificate.new()
		var err_cert = cert.load(CERT_FILE)
		var key = CryptoKey.new()
		var err_key = key.load(KEY_FILE)
		
		if err_cert == OK and err_key == OK:
			tls_options = TLSOptions.server(key, cert)
			print("WSS (Secure) mode enabled for Host.")
		else:
			print("Failed to load certificates. Falling back to WS (Insecure).")
	else:
		print("Certificates not found. Falling back to WS (Insecure).")

	var err = peer.create_server(PORT, "*", tls_options)
	if err != OK:
		print("Failed to create server: ", err)
		return
		
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
	_try_start_host()

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
