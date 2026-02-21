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

# 永続化データ
var data = {
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
	load_data()

func save_data():
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(data)
		file.store_string(json_str)
		print("Data saved.")
	else:
		print("Failed to save data.")

func load_data():
	if not FileAccess.file_exists(SAVE_FILE):
		print("No save file found. Creating new.")
		save_data()
		return

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file:
		var json_str = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(json_str)
		if parse_result == OK:
			# 既存セーブデータとデフォルトデータのマージ
			for key in data.keys():
				if json.data.has(key):
					# weapons_unlockedの場合は配列をマージ（重複排除）
					if key == "weapons_unlocked":
						for w in json.data[key]:
							if not w in data[key]:
								data[key].append(w)
					else:
						data[key] = json.data[key]
						
			print("Data loaded and merged:", data)
		else:
			print("JSON Parse Error: ", json.get_error_message())

func add_materials(amount: int):
	data["materials"] += amount
	save_data()

func get_materials() -> int:
	return data.get("materials", 0)

func get_max_weight() -> float:
	var level = data.get("max_weight_level", 0)
	return BASE_MAX_WEIGHT + (level * WEIGHT_UPGRADE_AMOUNT)

func get_max_hp() -> int:
	var level = data.get("hp_level", 0)
	return BASE_MAX_HP + (level * HP_UPGRADE_AMOUNT)

func upgrade_weight() -> bool:
	var cost = get_upgrade_cost("weight")
	if data["materials"] >= cost:
		data["materials"] -= cost
		data["max_weight_level"] += 1
		save_data()
		return true
	return false

func upgrade_hp() -> bool:
	var cost = get_upgrade_cost("hp")
	if data["materials"] >= cost:
		data["materials"] -= cost
		data["hp_level"] += 1
		save_data()
		return true
	return false

func get_upgrade_cost(type: String) -> int:
	var level = 0
	if type == "weight":
		level = data.get("max_weight_level", 0)
	elif type == "hp":
		level = data.get("hp_level", 0)
	
	# コスト計算式: 基本コスト 100 + (レベル * 50)
	# コスト計算式: 基本コスト 100 + (レベル * 50)
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

func unlock_weapon(weapon_id: String):
	var unlocked = data.get("weapons_unlocked", ["pistol"])
	if not weapon_id in unlocked:
		unlocked.append(weapon_id)
		data["weapons_unlocked"] = unlocked
		save_data()
		print("Weapon unlocked: ", weapon_id)

func equip_weapon(weapon_id: String):
	if is_weapon_unlocked(weapon_id):
		data["equipped_weapon"] = weapon_id
		save_data()
		print("Weapon equipped: ", weapon_id)
