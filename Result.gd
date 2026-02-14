extends Control

@onready var score_label = $ScoreLabel
@onready var materials_label = $MaterialsLabel

func _ready():
	var score = 0
	if "last_score" in NetworkManager:
		score = NetworkManager.last_score
		score_label.text = "Score: " + str(score)
	
	# スコアを素材に換算（例: 10%）
	var earned_materials = int(score * 0.1)
	materials_label.text = "Materials Earned: " + str(earned_materials)
	
	if earned_materials > 0:
		# 保存
		PlayerDataManager.add_materials(earned_materials)
		_play_material_animation(earned_materials)
	else:
		$HomeButton.visible = true

func _play_material_animation(amount):
	$HomeButton.visible = false
	
	var anim_label = Label.new()
	anim_label.text = "Materials +" + str(amount)
	anim_label.add_theme_font_size_override("font_size", 40) # Godot 4 style
	anim_label.modulate = Color(1, 1, 0, 0) # 透明から開始
	anim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 画面中央より少し下
	anim_label.position = Vector2(576 - 100, 400) # 簡易中央配置
	add_child(anim_label)
	
	# Tweenでアニメーション
	var tween = create_tween()
	tween.tween_property(anim_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(anim_label, "position:y", 350.0, 0.5).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(anim_label, "modulate:a", 0.0, 0.5).set_delay(1.0)
	
	await tween.finished
	anim_label.queue_free()
	
	$HomeButton.visible = true

func _on_home_button_pressed():
	# ホームへ戻る（接続は維持）
	# シーン遷移
	get_tree().change_scene_to_file("res://Home.tscn")
