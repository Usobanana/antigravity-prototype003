extends CharacterBody2D

const SPEED = 300.0

func _enter_tree():
	# このプレイヤーが「自分」のものか、ネットワークIDで判定
	# 名前をIDにしているので、名前が自分のIDと一致するか確認します
	set_multiplayer_authority(name.to_int())

func _physics_process(delta):
	# 「自分」のキャラクターだけがキー入力を受け付ける
	if is_multiplayer_authority():
		var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = direction * SPEED
		move_and_slide()
