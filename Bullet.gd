extends Area2D

const SPEED = 600.0

func _ready():
	# サーバー権限を持つピアのみが計算を行う
	set_process(is_multiplayer_authority())
	
	# 画面外に出たら削除（サーバー側で実行されれば同期される）
	if is_multiplayer_authority():
		$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)

func _process(delta):
	# 右方向へ進む（回転は生成時に設定される想定）
	position += Vector2.RIGHT.rotated(rotation) * SPEED * delta

func _on_body_entered(body):
	if not is_multiplayer_authority():
		return
	
	# 敵に当たった場合
	if body.is_in_group("enemies"):
		if body.has_method("hit"):
			# サーバー同士なので直接呼んでも良いが、念のためRPC経由または直接呼び出し
			# ここでは直接関数を叩く（サーバー権限内なので）
			body.hit(1)
		queue_free()
	# 他の物体（壁など）に当たった場合も消える
	else:
		if body.is_in_group("players"):
			return
		queue_free()
