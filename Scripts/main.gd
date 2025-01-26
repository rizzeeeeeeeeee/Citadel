extends Node2D

@export var spawnpoints: Array[NodePath] # Массив спавнпоинтов
@export var base_enemy: PackedScene   # Сцена врага
@export var spawn_interval: float = 5.0 # Интервал между спавнами (в секундах)
@export var energy: float = 0.0        # Начальное значение энергии
@export var energy_rate: float = 0.3  # Скорость накопления энергии (единиц в секунду)

@onready var energy_bar = $CanvasLayer/ProgressBar
@onready var hand = $Hand

var spawn_index: int = 0 # Текущий индекс спавнпоинта
var spawn_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if base_enemy == null:
		print("base_enemy не установлен!")
		return

	if spawnpoints.size() != 10:
		print("Количество спавнпоинтов должно быть 10!")
		return

	# Настройка таймера
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "spawn_next_enemy"))

	# Инициализация прогресс-бара
	energy_bar.max_value = 10.0   # Максимальное значение энергии
	energy_bar.min_value = 0.0    # Минимальное значение энергии
	energy_bar.value = energy     # Начальное значение энергии

	# Подключаем сигнал только один раз
	hand.card_dropped.connect(update_bar)

# Спавн врага в следующем спавнпоинте
func spawn_next_enemy() -> void:
	var spawnpoint_path = spawnpoints[spawn_index]
	var spawnpoint = get_node_or_null(spawnpoint_path)
	if spawnpoint and spawnpoint is Node2D:
		spawn_enemy(spawnpoint.global_position)
	else:
		print("Спавнпоинт по индексу %d не является Node2D или не задан.".format(spawn_index))

	spawn_index = (spawn_index + 1) % spawnpoints.size()

# Функция спавна врага в заданной позиции
func spawn_enemy(position: Vector2) -> void:
	var enemy_instance = base_enemy.instantiate()
	if enemy_instance:
		add_child(enemy_instance)
		enemy_instance.position = position
	else:
		print("Не удалось создать экземпляр врага.")

# Обновление энергии каждый кадр
func _process(delta: float) -> void:
	# Постепенное увеличение энергии
	energy = clamp(energy + energy_rate * delta, 0.0, 10.0)
	# Обновление прогресс-бара
	energy_bar.value = energy

# Обновление энергии при сбросе карты
func update_bar(value):
	energy -= value
	energy_bar.value -= value
