extends Control

@onready var score_label = $ScoreLabel

func _ready():
	# NetworkManagerなどに保存された前回のスコアを表示したいが
	# 簡易的に引数で渡せないので、NetworkManagerに持たせるか、Global変数が必要
	# ここでは NetworkManager.last_score を参照する形にする（後で追加）
	if "last_score" in NetworkManager:
		score_label.text = "Score: " + str(NetworkManager.last_score)

func _on_home_button_pressed():
	# 切断してホームへ戻るか、接続維持したまま戻るか
	# 要件では「ホームへ戻る」。接続維持した方がUXは良いが、リセットのために再接続が無難か
	# ここでは接続維持でHomeへ
	get_tree().change_scene_to_file("res://Home.tscn")
