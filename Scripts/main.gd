extends Node2D

@export var spawnpoints: Array[NodePath]
@export var wave_curves: Array[Curve]  # Массив кривых для каждой волны
@export var energy: float = 0.0
@export var energy_rate: float = 1.0
@export var health: float = 4.0
@export var health_icons: Array[NodePath]
@export var wave_display: WaveCurveDisplay

@onready var energy_bar = $CanvasLayer/ProgressBar
@onready var energy_label = $CanvasLayer/ProgressBar/Label
@onready var hand = $Hand
@onready var event_label = $Left_Tab/Event
@onready var wave_label = $Left_Tab/Wave
@onready var wave_bar = $Left_Tab/Wave/WaveBar

# Данные о врагах и волнах (загружаются из JSON)
var enemies_data: Dictionary
var wave_settings: Dictionary
var enemy_scenes: Dictionary = {}  # Загруженные сцены врагов

var current_wave: int = 0  # Текущая волна
var is_resting: bool = false  # Фаза отдыха между волнами
var wave_timer: Timer  # Таймер для длительности волны
var spawn_timer: Timer  # Таймер для интервалов спавна
var spawn_weights: Dictionary  # Текущие веса для спавна врагов
var first_spawn: bool = true  # Флаг для первого спавна в волне

# Настройки ивентов
@export var max_events_per_wave: int = 1  # Только 1 ивент за волну
@export var extra_spawn_chance: float = 0.3  # 30% шанс дополнительного спавна
var active_events: Dictionary = {}
var dead_enemies: Array = []  # Хранит информацию о умерших врагах
var active_enemies: int = 0  # Счетчик активных врагов

# Типы ивентов и их настройки
enum EventType { CENTRAL_LANES, SINGLE_TYPE, RESURRECT }
const EVENT_PROBABILITY = 0.6  # 60% шанс ивента на волну
const RESURRECT_TIME_WINDOW = 10.0  # Окно воскрешения в секундах

# Длительность ивентов
const EVENT_DURATIONS = {
	EventType.CENTRAL_LANES: 30.0,  # Длительность ивента "Центральные линии" (30 секунд)
	EventType.SINGLE_TYPE: 35.0,    # Длительность ивента "Один тип врагов" (45 секунд)
	EventType.RESURRECT: 20.0       # Длительность ивента "Воскрешение" (20 секунд)
}

# Настройки для случайного появления ивентов
@export var min_event_delay: float = 80.0  # Минимальная задержка перед первым ивентом
@export var max_event_delay: float = 30.0  # Максимальная задержка между ивентами
var event_timer: Timer  # Таймер для запуска ивентов
var available_events: Array  # Доступные для активации ивенты

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

	# Таймер для ивентов
	event_timer = Timer.new()
	event_timer.one_shot = false
	add_child(event_timer)
	event_timer.connect("timeout", _on_event_timer_timeout)

# Запуск следующей волны
func start_next_wave():
	current_wave += 1
	is_resting = false
	first_spawn = true
	active_events.clear()
	dead_enemies.clear()
	available_events = EventType.values().duplicate()

	# Инициализация отображения кривой
	var curve_index = (current_wave - 1) % wave_curves.size()
	if wave_display:
		wave_display.setup(wave_curves[curve_index])

	print("Начало волны ", current_wave)
	wave_label.text = "Wave " + str(current_wave)
	wave_bar.max_value = wave_settings.wave_duration
	wave_bar.value = 0
	wave_timer.start(wave_settings.wave_duration)

	# Запускаем таймер спавна и ивентов
	start_next_event_timer()
	update_spawn_weights(0.0)
	_on_spawn_timeout()

# Запуск таймера для следующего ивента
func start_next_event_timer():
	var delay = randf_range(min_event_delay, max_event_delay)
	event_timer.start(delay)

func _on_event_timer_timeout():
	# Ивенты активируются только во время волны (не в фазе отдыха)
	if is_resting:
		return

	# Проверяем, можем ли активировать новый ивент
	if active_events.size() >= max_events_per_wave:
		return

	# Выбираем случайный ивент из доступных
	var selected_event = available_events[randi() % available_events.size()]
	activate_event(selected_event)

	# Удаляем ивент из доступных до конца волны
	available_events.erase(selected_event)

	# Останавливаем таймер ивентов, если достигнут лимит
	if active_events.size() >= max_events_per_wave:
		event_timer.stop()


# Активация ивента
func activate_event(event_type: EventType):
	match event_type:
		EventType.CENTRAL_LANES:
			active_events["central_lanes"] = true
			event_label.text = "Only central lanes"  # Обновляем текст в Label
			print("Ивент активирован: Все идут по центральным линиям")
			start_event_timer(event_type)

		EventType.SINGLE_TYPE:
			var enemy_types = enemies_data.keys().filter(func(key): return key != "basic")
			if enemy_types.size() > 0:
				var selected_type = enemy_types[randi() % enemy_types.size()]
				active_events["single_type"] = {
					"type": selected_type,
					"original_weights": spawn_weights.duplicate()  # Сохраняем оригинальные веса
				}
				event_label.text = "Only " + selected_type  # Обновляем текст в Label
				print("Ивент активирован: Спавнятся только ", selected_type)
				start_event_timer(event_type)

		EventType.RESURRECT:
			active_events["resurrect"] = true
			event_label.text = "Resurrecting enemies"  # Обновляем текст в Label
			print("Ивент активирован: Воскрешение врагов")
			start_event_timer(event_type)

# Запуск таймера для деактивации ивента
func start_event_timer(event_type: EventType):
	var timer = Timer.new()
	timer.wait_time = EVENT_DURATIONS[event_type]
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_event_timeout.bind(event_type))
	timer.start()

# Обработка завершения ивента
func _on_event_timeout(event_type: EventType):
	match event_type:
		EventType.CENTRAL_LANES:
			active_events.erase("central_lanes")
			event_label.text = ""  # Очищаем текст в Label
			print("Ивент завершен: Все идут по центральным линиям")

		EventType.SINGLE_TYPE:
			# Восстанавливаем оригинальные веса
			if active_events.has("single_type"):
				var original_weights = active_events["single_type"]["original_weights"]
				for key in original_weights:
					spawn_weights[key] = original_weights[key]
				active_events.erase("single_type")
			event_label.text = ""  # Очищаем текст в Label
			print("Ивент завершен: Усиление типа врагов")

		EventType.RESURRECT:
			active_events.erase("resurrect")
			event_label.text = ""  # Очищаем текст в Label
			print("Ивент завершен: Воскрешение врагов")

# Обновление интервала спавна на основе прогресса волны
func update_spawn_interval():
	var curve_index = (current_wave - 1) % wave_curves.size()
	var current_curve = wave_curves[curve_index]

	var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
	var intensity = current_curve.sample(wave_progress)

	# Динамически изменяем интервал спавна
	var min_interval = 0.5  # Минимальный интервал (пик волны)
	var max_interval = 10.0  # Максимальный интервал (начало/конец волны)
	spawn_timer.wait_time = lerp(max_interval, min_interval, intensity)
	spawn_timer.start()

# Обработка спавна врагов
func _on_spawn_timeout():
	if is_resting:  # Не спавним врагов, если волна завершена
		return

	# Обработка воскрешения
	if active_events.has("resurrect"):
		resurrect_enemies()

	if first_spawn:
		# Спавним врага типа "basic" первым
		spawn_enemy(enemy_scenes["basic"], "basic")
		first_spawn = false
	else:
		var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
		var intensity = wave_curves[(current_wave - 1) % wave_curves.size()].sample(wave_progress)

		# Вычисляем количество врагов для спавна
		var base_spawn_count = wave_settings.base_spawn_count
		var spawn_count = base_spawn_count * (1 + intensity * 3)

		# Дополнительный спавн для ивента "Один тип врагов"
		if active_events.has("single_type") && randf() < extra_spawn_chance:
			spawn_count += 1

		# Спавним врагов
		for i in range(spawn_count):
			var selected_enemy_id = get_weighted_random_enemy_id()
			spawn_enemy(enemy_scenes[selected_enemy_id], selected_enemy_id)

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
func get_weighted_random_enemy_id() -> String:
	# Если активен ивент "Один тип врагов", возвращаем только выбранный тип
	if active_events.has("single_type"):
		return active_events["single_type"]["type"]

	# Иначе используем стандартную логику выбора
	var total_weight = 0.0
	for enemy_id in spawn_weights:
		total_weight += spawn_weights[enemy_id]

	var random = randf_range(0, total_weight)
	var current = 0.0

	for enemy_id in spawn_weights:
		current += spawn_weights[enemy_id]
		if random < current:
			return enemy_id

	return spawn_weights.keys()[0]

# Спавн врага на сцене
func spawn_enemy(enemy_scene: PackedScene, enemy_id: String):
	var valid_spawnpoints = get_valid_spawnpoints()
	if valid_spawnpoints.size() == 0:
		return

	var spawnpoint_path = valid_spawnpoints[randi() % valid_spawnpoints.size()]
	var spawnpoint = get_node_or_null(spawnpoint_path)

	if spawnpoint and spawnpoint is Node2D:
		var enemy_instance = enemy_scene.instantiate()
		enemy_instance.enemy_type = enemy_id  # Устанавливаем тип врага
		enemy_instance.connect("died", _on_enemy_died.bind(enemy_instance))
		add_child(enemy_instance)
		enemy_instance.position = spawnpoint.global_position
		active_enemies += 1  # Увеличиваем счетчик активных врагов

# Получение допустимых спавнпоинтов
func get_valid_spawnpoints():
	if active_events.has("central_lanes"):
		# Возвращаем центральные линии (3,4,5,6,7 индексы для 10 спавнпоинтов)
		return spawnpoints.slice(4, 6)
	return spawnpoints

# Обработка смерти врага
func _on_enemy_died(enemy):
	active_enemies -= 1  # Уменьшаем счетчик активных врагов
	# Сохраняем информацию об умершем враге
	dead_enemies.append({
		"position": enemy.position,
		"type": enemy.enemy_type,
		"death_time": Time.get_unix_time_from_system()
	})

	# Запускаем таймер очистки старых записей
	await get_tree().create_timer(RESURRECT_TIME_WINDOW + 1.0).timeout
	dead_enemies = dead_enemies.filter(func(e):
		return Time.get_unix_time_from_system() - e.death_time <= RESURRECT_TIME_WINDOW
	)

# Воскрешение врагов
func resurrect_enemies():
	var now = Time.get_unix_time_from_system()
	var resurrected = 0

	for enemy_data in dead_enemies:
		if now - enemy_data.death_time > RESURRECT_TIME_WINDOW:
			continue

		if enemy_data.type in enemy_scenes:
			var enemy_scene = enemy_scenes[enemy_data.type]
			var enemy_instance = enemy_scene.instantiate()
			enemy_instance.enemy_type = enemy_data.type  # Устанавливаем тип врага
			add_child(enemy_instance)
			enemy_instance.position = enemy_data.position

			# Применяем эффект полупрозрачности и обесцвечивания
			apply_resurrect_effect(enemy_instance)

			resurrected += 1

	if resurrected > 0:
		print("Воскрешено врагов: ", resurrected)

# Применение эффекта воскрешения
func apply_resurrect_effect(enemy_instance):
	# Устанавливаем начальные значения: полупрозрачность и серый цвет
	enemy_instance.modulate = Color(0.5, 0.5, 0.5, 0.5)  # Серый и полупрозрачный

	# Создаем Tween для плавного перехода к нормальному виду
	var tween = create_tween()
	tween.tween_property(enemy_instance, "modulate", Color(1, 1, 1, 1), 1.0)  # Возвращаем нормальный цвет и прозрачность за 1 секунду

# Завершение волны
func _on_wave_finished():
	is_resting = true
	print("Волна ", current_wave, " завершена. Отдых...")

	# Останавливаем таймер спавна и ивентов
	spawn_timer.stop()
	event_timer.stop()

	# Пауза перед следующей волной
	await get_tree().create_timer(wave_settings.rest_time).timeout
	start_next_wave()

# Остальные функции
func _process(delta: float) -> void:
	if health <= 0:
		$CanvasLayer/Death.visible = true
		get_tree().paused = true
	
	var generators = get_tree().get_nodes_in_group("generator")
	for generator in generators:
		call_deferred("_connect_generator_signal", generator)

	energy = clamp(energy + energy_rate * delta, 0.0, 10.0)
	energy_bar.value = energy
	energy_label.text = str(int(energy))

	if not is_resting:
		var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
		wave_bar.value = wave_settings.wave_duration - wave_timer.time_left
		
		# Обновляем отображение кривой
		if wave_display:
			wave_display.update_progress(wave_progress)

func _connect_generator_signal(generator):
	if not generator.energy_plus.is_connected(energy_plus):
		generator.energy_plus.connect(energy_plus)

func update_bar(value):
	energy -= value
	energy_bar.value -= value

func energy_plus():
	energy += 1.0

func _on_retake_pressed() -> void:
	energy -= 1.0

func _on_lose_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
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
