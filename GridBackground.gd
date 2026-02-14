extends Node2D

# グリッド設定
const GRID_SIZE = 64
const GRID_RANGE = 5000 # -5000 ~ +5000
const MAJOR_LINE_INTERVAL = 10 # 10本ごとに太い線

# 色設定
const LINE_COLOR = Color(0.2, 0.2, 0.2)
const MAJOR_LINE_COLOR = Color(0.5, 0.5, 0.5)
const LINE_WIDTH = 1.0
const MAJOR_LINE_WIDTH = 2.0

func _draw():
	var start = -GRID_RANGE
	var end = GRID_RANGE
	
	# 垂直線 (Vertical Lines)
	for x in range(start, end, GRID_SIZE):
		var color = LINE_COLOR
		var width = LINE_WIDTH
		
		# 太線判定 (Major Line Interval)
		if x % (GRID_SIZE * MAJOR_LINE_INTERVAL) == 0:
			color = MAJOR_LINE_COLOR
			width = MAJOR_LINE_WIDTH
			
		draw_line(Vector2(x, start), Vector2(x, end), color, width)

	# 水平線 (Horizontal Lines)
	for y in range(start, end, GRID_SIZE):
		var color = LINE_COLOR
		var width = LINE_WIDTH
		
		if y % (GRID_SIZE * MAJOR_LINE_INTERVAL) == 0:
			color = MAJOR_LINE_COLOR
			width = MAJOR_LINE_WIDTH
			
		draw_line(Vector2(start, y), Vector2(end, y), color, width)
