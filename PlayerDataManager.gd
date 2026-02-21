extends Node

const SAVE_FILE = "user://save_data.json"

# 武器データベース
const WEAPON_DB = {
	"pistol": {
		"name": "Pistol",
		"damage": 10,
		"fire_rate": 0.5,
		"bullet_speed": 400.0,
		"weight": 0.0,
		"max_ammo": 12,
		"reload_time": 1.5,
		"icon_color": Color(0.6, 0.6, 0.6), # Grey
		"type": "normal",
		"description": "Standard issue sidearm."
	},
	"smg": {
		"name": "SMG",
		"damage": 5,
		"fire_rate": 0.1,
		"bullet_speed": 500.0,
		"weight": 3.0,
		"max_ammo": 30,
		"reload_time": 2.5,
		"icon_color": Color(0.2, 0.2, 0.8), # Blue
		"type": "normal",
		"description": "High rate of fire, low damage."
	},
	"shotgun": {
		"name": "Shotgun",
		"damage": 15,
		"fire_rate": 0.8,
		"bullet_speed": 350.0,
		"weight": 6.0,
		"max_ammo": 2,
		"reload_time": 3.0,
		"icon_color": Color(0.8, 0.4, 0.0), # Orange/Brown
		"type": "spread",
		"description": "Fires 5 pellets in a spread. Deadly at close range."
	},
	"sniper": {
		"name": "Sniper Rifle",
		"damage": 50,
		"fire_rate": 1.5,
		"bullet_speed": 1000.0,
		"weight": 5.0,
		"max_ammo": 1,
		"reload_time": 3.0,
		"icon_color": Color(0.1, 0.6, 0.1), # Dark Green
		"type": "piercing",
		"description": "High-velocity piercing rounds."
	},
	"light_smg": {
		"name": "Light SMG",
		"damage": 4,
		"fire_rate": 0.08,
		"bullet_speed": 450.0,
		"weight": 0.5,
		"max_ammo": 30,
		"reload_time": 1.8,
		"icon_color": Color(0.4, 0.8, 0.9), # Light Blue
		"type": "normal",
		"description": "Low damage, extremely light weight."
	}
}

# --- Server Authoritative Data Storage ---
const SERVER_DATA_FILE = "user://server_data.json"
const CLIENT_TOKEN_FILE = "user://client_token.json"

var my_token = ""
var is_data_loaded = false

# サーバー管理用の全プレイヤーデータ (辞書: token -> data)
var server_players_data = {}

# クライアント用の自身のデータキャッシュ（サーバーから同期される）
var data = {
	"materials": 0,
	"max_weight_level": 0,
	"hp_level": 0,
	"weapons_unlocked": ["pistol", "smg", "shotgun", "sniper", "light_smg"], # Default for testing
	"equipped_weapon": "pistol"
}

func get_default_data() -> Dictionary:
	return {
		"materials": 0,
		"max_weight_level": 0,
		"hp_level": 0,
		"weapons_unlocked": ["pistol", "smg", "shotgun", "sniper", "light_smg"],
		"equipped_weapon": "pistol"
	}

# パラメータ設定
const BASE_MAX_WEIGHT = 10.0
const WEIGHT_UPGRADE_AMOUNT = 2.0
const BASE_MAX_HP = 100
const HP_UPGRADE_AMOUNT = 20

func _ready():
	_ensure_my_token()
	
	if multiplayer.is_server():
		_load_server_data()
		# サーバーは定期的にオートセーブを実行
		var save_timer = Timer.new()
		save_timer.wait_time = 60.0 # 60秒ごと
		save_timer.autostart = true
		save_timer.timeout.connect(_save_server_data)
		add_child(save_timer)
		# 自身のデータを設定
		_assign_server_data_to_self()
	else:
		# クライアントは接続完了時にサーバーへデータ要求
		multiplayer.connected_to_server.connect(_request_data_from_server)

# --- Client Authentication ---
func _ensure_my_token():
	if FileAccess.file_exists(CLIENT_TOKEN_FILE):
		var file = FileAccess.open(CLIENT_TOKEN_FILE, FileAccess.READ)
		my_token = file.get_as_text().strip_edges()
	else:
		# ランダムなUUIDを生成（簡易実装：乱数のハッシュ）
		my_token = str(randi()).md5_text()
		var file = FileAccess.open(CLIENT_TOKEN_FILE, FileAccess.WRITE)
		file.store_string(my_token)
	print("My Token: ", my_token)

func _request_data_from_server():
	rpc_id(1, "request_auth_and_data", my_token)

# --- Server Data Management ---
func _load_server_data():
	if not multiplayer.is_server(): return
	
	if FileAccess.file_exists(SERVER_DATA_FILE):
		var file = FileAccess.open(SERVER_DATA_FILE, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			server_players_data = json.data
			print("Server data loaded.")
		else:
			print("Failed to parse server data.")

func _save_server_data():
	if not multiplayer.is_server(): return
	var file = FileAccess.open(SERVER_DATA_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(server_players_data))
		print("Server data auto-saved.")

func _assign_server_data_to_self():
	if not server_players_data.has(my_token):
		server_players_data[my_token] = get_default_data()
	data = server_players_data[my_token]
	is_data_loaded = true

# サーバー：クライアントからの認証とデータ要求を受け付ける
@rpc("any_peer", "call_remote")
func request_auth_and_data(token: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not server_players_data.has(token):
		server_players_data[token] = get_default_data()
		
	# ※ 本格的な実装では、sender_id と token のマッピングをNetworkManagerに保存し、
	# 以降のRPC検証に使用するべきですが、ここでは簡単のため省略
	
	if sender_id != 1:
		rpc_id(sender_id, "receive_player_data", server_players_data[token])
	else:
		if token == my_token:
			data = server_players_data[token]
			is_data_loaded = true
	print("Sent data to peer ", sender_id, " (Token: ", token.substr(0,8), ")")

# クライアント：サーバーからデータを受け取る
@rpc("authority", "call_remote")
func receive_player_data(server_data: Dictionary):
	data = server_data
	is_data_loaded = true
	print("Received latest data from server.")

# --- Server Authoritative Actions ---
# データの変更（add_materials等）は原則サーバー側で行い、クライアントに同期する
# 以下の関数群は、サーバー上でのみ「本来のデータ（server_players_data）」を更新する

# TODO: 今後利用する「特定のプレイヤーのデータを取得・更新する」ヘルパー
func update_server_data(peer_id: int, token: String, mutator_func: Callable):
	if not multiplayer.is_server(): return
	if not server_players_data.has(token): return
	
	var user_data = server_players_data[token]
	mutator_func.call(user_data)
	server_players_data[token] = user_data
	
	if peer_id != 1:
		rpc_id(peer_id, "receive_player_data", user_data)
	
	# もし自分がホストなら、ローカルのdataも更新
	if peer_id == 1 and token == my_token:
		data = user_data
		is_data_loaded = true

# --- Helper Methods (Client Cache Access) ---
# これらのメソッドは「手元にあるキャッシュ」を読むだけに留める（画面表示等用）

func get_materials() -> int:
	return data.get("materials", 0)

func get_max_weight() -> float:
	var level = data.get("max_weight_level", 0)
	return BASE_MAX_WEIGHT + (level * WEIGHT_UPGRADE_AMOUNT)

func get_max_hp() -> int:
	var level = data.get("hp_level", 0)
	return BASE_MAX_HP + (level * HP_UPGRADE_AMOUNT)

func get_upgrade_cost(type: String) -> int:
	var level = 0
	if type == "weight":
		level = data.get("max_weight_level", 0)
	elif type == "hp":
		level = data.get("hp_level", 0)
	return 100 + (level * 50)


# --- Weapon System ---

func get_weapon_stats(weapon_id: String) -> Dictionary:
	return WEAPON_DB.get(weapon_id, WEAPON_DB["pistol"])

func get_equipped_weapon_id() -> String:
	return data.get("equipped_weapon", "pistol")

func get_equipped_weapon_stats() -> Dictionary:
	var id = get_equipped_weapon_id()
	return get_weapon_stats(id)

func is_weapon_unlocked(weapon_id: String) -> bool:
	var unlocked = data.get("weapons_unlocked", ["pistol"])
	return weapon_id in unlocked

# --- Server Action RPCs ---
@rpc("any_peer", "call_local")
func request_equip_weapon(weapon_id: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	var token = NetworkManager.get_token_for_peer(sender_id)
	if token == "": return
	
	update_server_data(sender_id, token, func(user_data):
		var unlocked = user_data.get("weapons_unlocked", ["pistol"])
		if weapon_id in unlocked:
			user_data["equipped_weapon"] = weapon_id
			print("Server: Peer ", sender_id, " equipped ", weapon_id)
	)

@rpc("any_peer", "call_local")
func request_upgrade(upgrade_type: String):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	var token = NetworkManager.get_token_for_peer(sender_id)
	if token == "": return
	
	update_server_data(sender_id, token, func(user_data):
		var materials = user_data.get("materials", 0)
		var cost = 0
		var level_key = ""
		
		if upgrade_type == "weight":
			level_key = "max_weight_level"
		elif upgrade_type == "hp":
			level_key = "hp_level"
		else:
			return
			
		var level = user_data.get(level_key, 0)
		cost = 100 + (level * 50)
		
		if materials >= cost:
			user_data["materials"] = materials - cost
			user_data[level_key] = level + 1
			print("Server: Peer ", sender_id, " upgraded ", upgrade_type)
	)

# サーバー専用呼び出し（他スクリプトから）
func server_add_materials(peer_id: int, amount: int):
	var token = NetworkManager.get_token_for_peer(peer_id)
	if token != "":
		update_server_data(peer_id, token, func(user_data):
			user_data["materials"] = user_data.get("materials", 0) + amount
		)

func server_unlock_weapon(peer_id: int, weapon_id: String):
	var token = NetworkManager.get_token_for_peer(peer_id)
	if token != "":
		update_server_data(peer_id, token, func(user_data):
			var unlocked = user_data.get("weapons_unlocked", ["pistol"])
			if not weapon_id in unlocked:
				unlocked.append(weapon_id)
				user_data["weapons_unlocked"] = unlocked
				print("Server: Peer ", peer_id, " unlocked ", weapon_id)
		)
