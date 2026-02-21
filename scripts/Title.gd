extends Control

func _ready():
	if OS.has_feature("web"):
		# 本番環境では特定のURLを固定するか、ホスト名を利用する
		# UIを隠す
		if $ServerUrlInput: $ServerUrlInput.visible = false
		var label = get_node_or_null("Label2") # Input横のラベルなどがあれば
		if label: label.visible = false

func _on_start_button_pressed():
	if OS.has_feature("web"):
		# TODO: 実際のVPSのドメインが決まったらここにハードコードする
		# とりあえず現在のホスト名 + 7000 ポートに繋ぎに行く (NetworkManager内で自動補完されるため空でOK)
		NetworkManager.target_url = ""
	else:
		var input_url = $ServerUrlInput.text.strip_edges()
		if input_url != "":
			if not input_url.begins_with("ws://") and not input_url.begins_with("wss://"):
				input_url = "wss://" + input_url
			NetworkManager.target_url = input_url
		else:
			NetworkManager.target_url = ""
			
	get_tree().change_scene_to_file("res://scenes/Home.tscn")
