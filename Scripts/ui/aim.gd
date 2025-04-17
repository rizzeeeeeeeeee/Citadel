extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

var scale_speed: float = 5.0
var rotation_speed: float = 300.0
var enemies: Array = []  # Массив для хранения врагов

func _ready():
	# Получаем всех врагов (можете заполнить массив по-своему)
	enemies = get_tree().get_nodes_in_group("enemies")
	# Запускаем таймер на 3 секунды
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(_create_beams)
	timer.start()

func _process(delta: float) -> void:
	sprite.scale -= Vector2(scale_speed * delta, scale_speed * delta)
	sprite.rotation_degrees -= rotation_speed * delta
	
	if sprite.scale.x <= 2.5 or sprite.scale.y <= 2.5:
		sprite.scale = Vector2(2.5, 2.5)
		#rotation_speed = 0.0
		scale_speed = 0.0

func _create_beams():
	# Получаем центр экрана по X (верхний край)
	var viewport = get_viewport_rect()
	var start_x = viewport.size.x / 2
	var start_pos = Vector2(start_x, -10)  # Немного выше экрана
	
	for enemy in enemies:
		if is_instance_valid(enemy):  # Проверяем, что враг еще существует
			# Создаем луч (Line2D)
			var beam = Line2D.new()
			add_child(beam)
			
			# Настраиваем внешний вид луча
			beam.width = 3.0
			beam.default_color = Color(1, 0, 0, 0.8)  # Красный с прозрачностью
			beam.add_point(start_pos)
			beam.add_point(enemy.global_position)
			
			# Анимация исчезновения луча
			var tween = create_tween()
			tween.tween_property(beam, "modulate:a", 0.0, 0.5)  # Исчезает за 0.5 сек
			tween.tween_callback(beam.queue_free)  # Удаляем после анимации
