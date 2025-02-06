extends Node2D

@export var spawnpoints: Array[NodePath]
@export var wave_curve: Curve  # Кривая для управления интенсивностью волны
@export var energy: float = 0.0
@export var energy_rate: float = 1.0
@export var health: float = 4.0
@export var health_icons : Array[NodePath]

@onready var energy_bar = $CanvasLayer/ProgressBar
@onready var energy_label = $CanvasLayer/ProgressBar/Label
@onready var hand = $Hand

# Данные о врагах и волнах (загружаются из JSON)
var enemies_data: Dictionary
var wave_settings: Dictionary
var enemy_scenes: Dictionary = {}  # Загруженные сцены врагов

var current_wave: int = 0  # Текущая волна
var is_resting: bool = false  # Фаза отдыха между волнами
var wave_timer: Timer  # Таймер для длительности волны
var spawn_timer: Timer  # Таймер для интервалов спавна
var spawn_weights: Dictionary  # Текущие веса для спавна врагов

func _ready() -> void:
	# Загрузка данных из JSON
	load_enemies_data()
	
	if spawnpoints.size() != 10:
		print("Количество спавнпоинтов должно быть 10!")
		return

	# Инициализация таймеров
	init_wave_timers()
	
	# Инициализация интерфейса
	energy_bar.max_value = 10.0
	energy_bar.min_value = 0.0
	energy_bar.value = energy

	# Подключение сигналов
	hand.card_dropped.connect(update_bar)
	start_next_wave()

# Загрузка данных из JSON
func load_enemies_data():
	var file = FileAccess.open("res://Other/enemies_data.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		enemies_data = data.enemies
		wave_settings = data.wave_settings
		preload_enemy_scenes()
	else:
		print("Ошибка загрузки файла enemies_data.json")

# Предзагрузка сцен врагов
func preload_enemy_scenes():
	for enemy_id in enemies_data:
		var scene_path = enemies_data[enemy_id].scene_path
		enemy_scenes[enemy_id] = load(scene_path)

# Инициализация таймеров
func init_wave_timers():
	wave_timer = Timer.new()
	wave_timer.one_shot = true
	add_child(wave_timer)
	wave_timer.connect("timeout", _on_wave_finished)
	
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.connect("timeout", _on_spawn_timeout)

# Запуск следующей волны
func start_next_wave():
	current_wave += 1
	is_resting = false
	print("Начало волны ", current_wave)
	
	# Запуск таймера волны
	wave_timer.start(wave_settings.wave_duration)
	
	# Первый спавн сразу
	_on_spawn_timeout()

# Обновление интервала спавна на основе прогресса волны
func update_spawn_interval():
	var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
	var intensity = wave_curve.sample(wave_progress)
	
	# Динамически изменяем интервал спавна
	var min_interval = 0.5  # Минимальный интервал (пик волны)
	var max_interval = 10.0  # Максимальный интервал (начало/конец волны)
	spawn_timer.wait_time = lerp(max_interval, min_interval, intensity)
	spawn_timer.start()

# Обработка спавна врагов
func _on_spawn_timeout():
	if is_resting:
		return
	
	var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
	var intensity = wave_curve.sample(wave_progress)
	
	# Вычисляем количество врагов для спавна
	var base_spawn_count = wave_settings.base_spawn_count
	var spawn_count = base_spawn_count * (1 + intensity * 3)
	
	# Обновляем веса для спавна
	update_spawn_weights(wave_progress)
	
	# Спавним врагов
	for i in range(spawn_count):
		var selected_enemy = get_weighted_random_enemy()
		spawn_enemy(selected_enemy)
	
	# Обновляем интервал спавна
	update_spawn_interval()

# Обновление весов для спавна на основе прогресса волны
func update_spawn_weights(wave_progress: float):
	spawn_weights = {}
	for enemy_id in enemies_data:
		var enemy = enemies_data[enemy_id]
		var difficulty = 1.0 + (wave_progress * enemy.difficulty_multiplier)
		spawn_weights[enemy_id] = enemy.base_spawn_weight * difficulty

# Выбор случайного врага с учетом весов
func get_weighted_random_enemy() -> PackedScene:
	var total_weight = 0.0
	for enemy_id in spawn_weights:
		total_weight += spawn_weights[enemy_id]
	
	var random = randf_range(0, total_weight)
	var current = 0.0
	
	for enemy_id in spawn_weights:
		current += spawn_weights[enemy_id]
		if random < current:
			return enemy_scenes[enemy_id]
	
	return enemy_scenes.values()[0]

# Спавн врага на сцене
func spawn_enemy(enemy_scene: PackedScene):
	var spawnpoint_path = spawnpoints[randi() % spawnpoints.size()]
	var spawnpoint = get_node_or_null(spawnpoint_path)
	if spawnpoint and spawnpoint is Node2D:
		var enemy_instance = enemy_scene.instantiate()
		add_child(enemy_instance)
		enemy_instance.position = spawnpoint.global_position
	else:
		print("Ошибка: спавнпоинт не найден или не является Node2D")

# Завершение волны
func _on_wave_finished():
	is_resting = true
	print("Волна ", current_wave, " завершена. Отдых...")
	
	# Пауза перед следующей волной
	await get_tree().create_timer(wave_settings.rest_time).timeout
	start_next_wave()

# Остальные функции
func _process(delta: float) -> void:
	var generators = get_tree().get_nodes_in_group("generator")
	for generator in generators:
		generator.energy_plus.connect(energy_plus)
	
	energy = clamp(energy + energy_rate * delta, 0.0, 10.0)
	energy_bar.value = energy
	energy_label.text = str(int(energy))

func update_bar(value):
	energy -= value
	energy_bar.value -= value

func energy_plus():
	energy += 1.0

func _on_retake_pressed() -> void:
	energy -= 1.0

func _on_lose_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		# Уменьшаем здоровье
		health -= 1.0
		
		# Проверяем, чтобы здоровье не ушло в минус
		if health < 0:
			health = 0
		
		# Удаляем одно сердечко
		if health_icons.size() > 0:
			var heart_to_remove = health_icons.pop_back()  # Удаляем последнее сердечко
			var heart_node = get_node_or_null(heart_to_remove)
			if heart_node:
				heart_node.queue_free()  # Удаляем ноду сердечка из сцены
