extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@export var lightning: PackedScene  # Сцена молнии

# Скорость уменьшения масштаба
var scale_speed: float = 3.0
# Скорость вращения
var rotation_speed: float = 30.0

# Таймер для удаления гранаты и создания взрыва
var grenade_timer: float = 0.7

# Флаг, чтобы молния выпускалась только один раз
var has_attacked: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Уменьшаем масштаб спрайта
	sprite.scale -= Vector2(scale_speed * delta, scale_speed * delta)
	
	# Вращаем спрайт влево
	sprite.rotation_degrees -= rotation_speed * delta
	
	# Останавливаем уменьшение и вращение, если масштаб стал слишком маленьким
	if sprite.scale.x <= 0.1 or sprite.scale.y <= 0.1:
		sprite.scale = Vector2(0.1, 0.1)
		rotation_speed = 0.0
		scale_speed = 0.0
	
	# Уменьшаем таймер гранаты
	grenade_timer -= delta
	
	# Если таймер истек и атака еще не была выполнена
	if grenade_timer <= 0 and not has_attacked:
		$Sprite2D.visible = false
		_attack_all_enemies_in_range()
		has_attacked = true
		await get_tree().create_timer(1.0).timeout
		queue_free()  # Уничтожаем гранату после атаки

# Атака всех врагов в зоне
func _attack_all_enemies_in_range() -> void:
	# Получаем все тела в зоне атаки
	var bodies = $"Attack Area".get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):  # Проверяем, что тело — враг
			_create_lightning(body)

# Создание молнии для атаки врага
func _create_lightning(enemy: Node2D) -> void:
	if lightning:
		var lightning_instance = lightning.instantiate()
		add_child(lightning_instance)
		
		# Направляем молнию на врага
		var direction = enemy.global_position - global_position
		var angle = atan2(direction.y, direction.x)
		lightning_instance.rotation = angle
		
		# Устанавливаем позицию молнии
		lightning_instance.global_position = global_position
		
		# Масштабируем молнию в зависимости от расстояния до врага
		var distance = direction.length()
		var base_length = 190.0
		var scale_factor = distance / base_length
		lightning_instance.scale.x = scale_factor

		# Запускаем таймер для удаления молнии через секунду
		var remove_timer = Timer.new()
		remove_timer.wait_time = 1.0  # Через 1 секунду
		remove_timer.one_shot = true
		remove_timer.timeout.connect(_on_lightning_timer_timeout.bind(lightning_instance))
		add_child(remove_timer)
		remove_timer.start()

# Удаление молнии по истечении таймера
func _on_lightning_timer_timeout(lightning_instance: Node2D) -> void:
	if lightning_instance:
		lightning_instance.queue_free()
