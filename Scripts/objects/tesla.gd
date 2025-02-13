extends Node2D

@export var lightning: PackedScene  # Сцена молнии
@export var attack_interval: float = 2.0  # Интервал между атаками
@export var attack_duration: float = 1.0  # Длительность атаки (длительность молнии)

var enemies_in_range: Array = []  # Список врагов в радиусе
var lightning_instances: Dictionary = {}  # Словарь для хранения молний
var hp: float = 200.0  # Здоровье Теслы
var attack_timer: Timer  # Таймер для периодической атаки

func _ready():
	# Создаем таймер для периодической атаки
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_interval
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)
	attack_timer.start()

func _on_attack_area_body_entered(body: Node2D) -> void:
	# Добавляем врага в список, если он в зоне действия
	if body.is_in_group("enemy") and not enemies_in_range.has(body):
		enemies_in_range.append(body)

func _on_attack_area_body_exited(body: Node2D) -> void:
	# Удаляем врага из списка, если он вышел из зоны действия
	if enemies_in_range.has(body):
		enemies_in_range.erase(body)
		_stop_attack()

func _process(delta: float) -> void:
	# Обновляем текст с HP
	$Label.text = str(hp)

	# Обновляем позиции молний для всех врагов в радиусе
	for enemy in enemies_in_range:
		_update_lightning(enemy)

func _on_attack_timer_timeout() -> void:
	# Запускаем атаку всех врагов в радиусе
	if not enemies_in_range.is_empty():
		_start_attack()

func _start_attack() -> void:
	# Создаем молнии для всех врагов в радиусе
	for enemy in enemies_in_range:
		var lightning_instance = lightning.instantiate()
		add_child(lightning_instance)
		lightning_instances[enemy] = lightning_instance

		# Настраиваем молнию
		_update_lightning(enemy)

	# Запускаем таймер для завершения атаки
	var attack_duration_timer = Timer.new()
	attack_duration_timer.wait_time = attack_duration
	attack_duration_timer.one_shot = true
	attack_duration_timer.timeout.connect(_stop_attack)
	add_child(attack_duration_timer)
	attack_duration_timer.start()

func _stop_attack() -> void:
	# Удаляем все молнии после завершения атаки
	for enemy in lightning_instances.keys():
		lightning_instances[enemy].queue_free()
	lightning_instances.clear()

func _update_lightning(enemy: Node2D) -> void:
	# Обновляем позицию и масштаб молнии для врага
	if lightning_instances.has(enemy):
		var lightning_instance = lightning_instances[enemy]
		var direction = enemy.global_position - global_position
		var distance = direction.length()

		# Настраиваем угол и масштаб молнии
		var angle = atan2(direction.y, direction.x)
		lightning_instance.rotation = angle
		lightning_instance.z_index = 1
		lightning_instance.z_as_relative = false

		var base_length = 190.0
		var scale_factor = distance / base_length
		lightning_instance.scale.x = scale_factor

func _on_area_2d_body_entered(body: Node2D) -> void:
	# Обработка попадания врага в зону урона
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		body.get_parent().attack(self)  # Вызываем метод атаки у врага

func take_damage(amount: float) -> void:
	# Обработка получения урона
	if hp <= 0:
		return  # Если Тесла уже уничтожена, ничего не делаем

	hp -= amount
	if hp <= 0:
		destroy()

func destroy() -> void:
	# Уничтожение Теслы
	if is_instance_valid(self):
		# Удаляем все молнии
		for enemy in lightning_instances.keys():
			lightning_instances[enemy].queue_free()
		lightning_instances.clear()

		queue_free()
