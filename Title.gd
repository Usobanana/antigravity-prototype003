extends Control

func _on_start_button_pressed():
	var input_url = $ServerUrlInput.text.strip_edges()
	if input_url != "":
		# プロトコル補完（wss:// がなければ付与、ローカルならws://でも良いが統一的に扱う）
		if not input_url.begins_with("ws://") and not input_url.begins_with("wss://"):
			input_url = "wss://" + input_url
		NetworkManager.target_url = input_url
	else:
		NetworkManager.target_url = ""
		
	get_tree().change_scene_to_file("res://Home.tscn")
