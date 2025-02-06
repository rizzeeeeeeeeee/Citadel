extends Node2D

@export var base_speed: float = 20.0
@export var step_speed_variation: float = 10.0
@export var step_scale_variation: float = 0.03
@export var step_frequency: float = 0.3
@export var hp: float = 150.0

@onready var sprite: AnimatedSprite2D = $CharacterBody2D/Sprite2D
@onready var collision_shape: CollisionShape2D = $CharacterBody2D/CollisionShape2D

var time: float = 0.0
var original_scale: Vector2
var is_dead: bool = false
var current_tween: Tween = null
var poison_timer: Timer

# Загрузка данных о баффах из JSON файла
var buff_data: Array = []

func _ready():
	original_scale = sprite.scale

	# Инициализация таймера для урона от яда
	poison_timer = Timer.new()
	poison_timer.wait_time = 1.0  # Интервал урона (1 секунда)
	poison_timer.one_shot = false
	poison_timer.timeout.connect(_on_poison_timer_timeout)
	add_child(poison_timer)

	# Загрузка данных о баффах из JSON файла
	load_buff_data()

	# Проверка на шанс получения баффа при спавне
	if randi() % 4 == 0:  # Шанс 1 из 4
		apply_random_buff()

func load_buff_data():
	var file = FileAccess.open("res://Other/buff_data.json", FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		var json = JSON.new()  # Создаем экземпляр класса JSON
		var result = json.parse(json_data)  # Используем метод parse экземпляра
		if result == OK:
			buff_data = json.get_data()  # Получаем данные
		else:
			print("Failed to parse JSON: ", json.get_error_message())
		file.close()
	else:
		print("Failed to load buff data.")

func apply_random_buff():
	if buff_data.size() > 0:
		var random_index = randi() % buff_data.size()
		var buff = buff_data[random_index]
		var buff_scene = load(buff["path"])
		if buff_scene:
			var buff_instance = buff_scene.instantiate()
			buff_instance.position = position  # Спавн бафа по центру врага
			add_child(buff_instance)  # Добавляем бафф как дочернюю ноду
			hp += buff.get("hp", 0)  # Увеличиваем HP на значение из баффа
		else:
			print("Failed to load buff scene: ", buff["path"])
	else:
		print("No buff data available.")

func _process(delta: float) -> void:
	if is_dead:
		return

	if hp <= 0:
		die()
	else:
		time += delta

		var step_phase = sin(time * step_frequency * 2 * PI)
		var current_speed = base_speed + step_speed_variation * step_phase

		position.y += current_speed * delta

		var scale_variation = 1.0 + step_scale_variation * abs(step_phase)
		sprite.scale = original_scale * scale_variation

		# Обработка всех пуль в группе "bullet"
		var bullets = get_tree().get_nodes_in_group("bullet")
		var mines = get_tree().get_nodes_in_group("mine")
		var expls = get_tree().get_nodes_in_group("expl")
		var rays = get_tree().get_nodes_in_group("ray")
		var blasts = get_tree().get_nodes_in_group("blast")
		var poisons = get_tree().get_nodes_in_group("poison")
		var teslas = get_tree().get_nodes_in_group("tesla")
		var lose_zone = get_tree().get_first_node_in_group("lose_zone")
		lose_zone.enemy_reach_end.connect(reach_end)
		for bullet in bullets:
			bullet.deal_damage.connect(bullet_damage)
		for expl in expls:
			expl.explosion_emit.connect(explosion_damage)
		for mine in mines:
			mine.on_mine_step.connect(mine_damage)
		for ray in rays:
			ray.ray_collide.connect(ray_damage)
		for blast in blasts:
			blast.blast_damage.connect(mine_damage)
		for poison in poisons:
			poison.poisoned.connect(on_poison_entered)
			poison.unpoisoned.connect(on_poison_exited)
		for tesla in teslas:
			tesla.lightning_attack.connect(on_tesla_attack)

func reach_end(victim: Node2D):
	if victim == self:
		queue_free()

func on_tesla_attack(victim: Node2D):
	if victim == self:
		take_electric_damage(0, 1.0)

func on_poison_entered(victim: Node2D):
	if victim == self:
		poison_timer.start()  

func on_poison_exited(victim: Node2D):
	if victim == self:
		poison_timer.stop() 

func _on_poison_timer_timeout():
	take_damage(20)  

func bullet_damage(victim: Node2D):
	if victim == self:
		take_damage(25)

func explosion_damage(victim: Node2D):
	if victim == self:
		take_damage(100)

func ray_damage(victim: Node2D):
	if victim == self:
		take_damage(20)

func mine_damage(victim: Node2D):
	if victim == self:
		take_damage(999)

func take_electric_damage(amount: float, freeze_time: float = 0.0):
	if is_dead:
		return

	hp -= amount
	if hp <= 0:
		die()
	else:
		if current_tween:
			current_tween.kill()

		# Эффект синего цвета
		sprite.modulate = Color(0.5, 0.5, 1)  # Синий оттенок
		current_tween = create_tween()
		current_tween.tween_property(sprite, "modulate", Color(1, 1, 1), 1.5)

		# Остановка на указанное время
		if freeze_time > 0:
			set_process(false)  # Останавливаем обработку логики
			set_physics_process(false)  # Останавливаем физику
			await get_tree().create_timer(freeze_time).timeout # Ждем указанное время
			set_process(true)  # Возобновляем обработку логики
			set_physics_process(true)  # Возобновляем физику

		var knockback = Vector2(0, -2)
		current_tween.parallel().tween_property(self, "position", position + knockback, 0.1)
		current_tween.parallel().tween_property(self, "position", position, 0.1)

func take_damage(amount: float):
	if is_dead:
		return

	hp -= amount
	if hp <= 0:
		die()
	else:
		if current_tween:
			current_tween.kill()

		# Эффект покраснения
		sprite.modulate = Color(1, 0.5, 0.5)
		current_tween = create_tween()
		current_tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.5)

		var knockback = Vector2(0, -2)
		current_tween.parallel().tween_property(self, "position", position + knockback, 0.1)
		current_tween.parallel().tween_property(self, "position", position, 0.1)

func die():
	if is_dead:
		return

	is_dead = true

	sprite.modulate = Color(0.5, 0.5, 0.5)

	collision_shape.set_deferred("disabled", true)

	set_process(false)

	await get_tree().create_timer(1.0).timeout
	queue_free()
