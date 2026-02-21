extends Node

func _ready():
	# エラーを起こす前に少し待機（LogManagerの出力が見えるようにするため）
	await get_tree().create_timer(1.0).timeout
	print("DebugTester: 今から意図的なエラーを発生させます...")
	
	# 意図的なエラー：nullオブジェクトに対して存在しないメソッドを呼び出す
	var intentional_null = null
	if intentional_null != null:
		intentional_null.do_something_that_does_not_exist()
	else:
		print("DebugTester: エラーは自動修正により回避されました！")
