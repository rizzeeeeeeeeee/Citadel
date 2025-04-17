extends Node2D

signal deal_damage(victim: Node2D)

@export var laser_length: float = 999999
@export var laser_duration: float = 0.7
@export var laser_width: float = 20
@export var laser_color: Color = Color(1, 0, 0, 0.8)
@export var aim_scene: PackedScene
@export var min_angle: float = -65
@export var max_angle: float = 65
@export var marker_count: int = 8
@export var marker_color: Color = Color(1, 0, 0, 1)
@export var marker_size: Vector2 = Vector2(25, 25)
@export var marker_spawn_delay: float = 0.2
@export var attack_interval: float = 2.0  # Интервал между атаками

var active_aims: Dictionary = {}  # {враг: aim}
var enemies_in_area: Array = []
var activation_markers: Array = []
var active_lasers: Array = []
var attack_timer: Timer

func _ready():
	# Таймер для автоматического удаления через 10 секунд
	var self_destruct_timer = Timer.new()
	add_child(self_destruct_timer)
	self_destruct_timer.wait_time = 10.0
	self_destruct_timer.one_shot = true
	self_destruct_timer.timeout.connect(queue_free)
	self_destruct_timer.start()
	
	# Инициализация таймера атаки
	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_perform_attack_phase)
	
	# Запуск маркеров при старте
	_spawn_activation_markers()

func _spawn_activation_markers():
	# Очистка старых маркеров
	for marker in activation_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	activation_markers.clear()
	
	var radius = $"Attack Area/CollisionShape2D".shape.radius * 3.5
	var angle_step = TAU / marker_count
	var indices = range(marker_count)
	indices.shuffle()
	
	for i in range(indices.size()):
		var timer = Timer.new()
		add_child(timer)
		timer.wait_time = i * marker_spawn_delay
		timer.one_shot = true
		timer.timeout.connect(_create_single_marker.bind(indices[i], angle_step, radius))
		timer.start()

func _create_single_marker(index: int, angle_step: float, radius: float):
	var angle = angle_step * index
	var marker = ColorRect.new()
	add_child(marker)
	
	marker.color = marker_color
	marker.size = marker_size
	marker.pivot_offset = marker_size / 2
	marker.position = Vector2(cos(angle), sin(angle)) * radius - marker_size / 2
	
	marker.scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(marker, "scale", Vector2(1, 1), 0.3)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	
	activation_markers.append(marker)
	
	# После последнего маркера запускаем таймер атаки
	if index == marker_count - 1:
		attack_timer.start()

func _perform_attack_phase():
	if enemies_in_area.is_empty():
		return
	
	# Создаем aim для всех врагов, у которых его нет
	for enemy in enemies_in_area:
		if not is_instance_valid(enemy) or active_aims.has(enemy):
			continue
		
		var new_aim = aim_scene.instantiate()
		enemy.add_child(new_aim)
		new_aim.position = Vector2.ZERO
		active_aims[enemy] = new_aim
	
	# Атакуем всех врагов
	for enemy in enemies_in_area:
		if not is_instance_valid(enemy):
			continue
		
		_attack_enemy(enemy)

func _attack_enemy(enemy: Node2D):
	# Генерируем случайный угол
	var random_angle = deg_to_rad(randf_range(min_angle, max_angle))
	var end_point = Vector2(
		laser_length * sin(random_angle),
		-laser_length * cos(random_angle)
	)
	
	# Создаем луч
	var laser = Line2D.new()
	enemy.add_child(laser)
	active_lasers.append(laser)
	
	# Настройки луча
	laser.width = 0
	laser.default_color = laser_color
	laser.add_point(end_point)
	laser.add_point(end_point)
	
	# Анимация
	var appear_tween = create_tween()
	appear_tween.tween_property(laser, "width", laser_width, 0.01)
	var shoot_tween = create_tween()
	shoot_tween.tween_method(
		func(progress): 
			laser.set_point_position(1, end_point * (1 - progress)),
		0.0, 1.0, 0.2
	)
	await get_tree().create_timer(0.15).timeout
	deal_damage.emit(enemy.get_parent())
	# Удаление луча
	var timer = Timer.new()
	laser.add_child(timer)
	timer.wait_time = laser_duration
	timer.timeout.connect(func():
		if is_instance_valid(laser):
			var disappear_tween = create_tween()
			disappear_tween.tween_property(laser, "width", 0, 0.1)
			disappear_tween.tween_callback(laser.queue_free)
			active_lasers.erase(laser)
	)
	timer.start()

func _on_attack_area_body_entered(body: Node2D):
	if body.is_in_group("enemy") and not body in enemies_in_area:
		enemies_in_area.append(body)
		
		# Если маркеры уже показаны, сразу создаем aim
		if activation_markers.size() >= marker_count:
			var new_aim = aim_scene.instantiate()
			body.add_child(new_aim)
			new_aim.position = Vector2.ZERO
			active_aims[body] = new_aim

func _on_attack_area_body_exited(body: Node2D):
	if body.is_in_group("enemy") and body in enemies_in_area:
		enemies_in_area.erase(body)
		
		if active_aims.has(body):
			var old_aim = active_aims[body]
			old_aim.queue_free()
			active_aims.erase(body)
