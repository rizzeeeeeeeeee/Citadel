extends Control
class_name WaveCurveDisplay

var curve: Curve
var progress: float = 0.0  # Прогресс волны (от 0.0 до 1.0)

func setup(new_curve: Curve):
	curve = new_curve
	progress = 0.0  # Сбрасываем прогресс
	if is_inside_tree():
		queue_redraw()

func update_progress(new_progress: float):
	progress = clamp(new_progress, 0.0, 1.0)  # Обновляем прогресс
	if is_inside_tree():
		queue_redraw()

func _draw():
	if not curve:
		return
	
	var width = size.x
	var height = size.y
	
	# Рисуем фон
	draw_rect(Rect2(0, 0, width, height), Color(0.2, 0.2, 0.2, 0.5), true)
	
	# Рисуем кривую волны
	var points: PackedVector2Array = []
	for i in width * progress:  # Ограничиваем отрисовку по текущему прогрессу
		var x = float(i) / width
		var y = curve.sample(x)
		points.append(Vector2(i, height - y * height))
	
	if points.size() > 1:
		draw_polyline(points, Color.WHITE, 2.0)
	
	# Рисуем текущую позицию
	if progress > 0:
		var current_x = progress * width
		var current_y = curve.sample(progress) * height
		draw_circle(Vector2(current_x, height - current_y), 5, Color.RED)
		draw_line(
			Vector2(current_x, 0), 
			Vector2(current_x, height), 
			Color.RED, 
			1.0
		)
