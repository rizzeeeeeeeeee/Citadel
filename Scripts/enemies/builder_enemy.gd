extends Node2D

signal died

@export var base_speed: float = 20.0
@export var step_speed_variation: float = 10.0
@export var step_scale_variation: float = 0.03
@export var step_frequency: float = 0.3
@export var hp: float = 150.0
@export var enemy_type: String
@export var attack_speed: float = 1.0
@export var coin_spawn_chance: float

@onready var sprite: AnimatedSprite2D = $CharacterBody2D/Sprite2D
@onready var collision_shape: CollisionShape2D = $CharacterBody2D/CollisionShape2D

var time: float = 0.0
var original_scale: Vector2
var is_dead: bool = false
var current_tween: Tween = null
var poison_timer: Timer
var current_target: Node2D = null
var is_attacking: bool = false
var build_timer: Timer
var is_building: bool = false  # Флаг для отслеживания состояния строительства
var should_stop_attack: bool = false
var attack_cooldown: float = 0.5

# Загрузка данных о врагах и баффах из JSON файлов
var enemies_data: Dictionary = {}
var buff_data: Array = []

func _ready():
	original_scale = sprite.scale
	poison_timer = Timer.new()
	poison_timer.wait_time = 1.0
	poison_timer.one_shot = false
	poison_timer.timeout.connect(_on_poison_timer_timeout)
	add_child(poison_timer)
	
	# Таймер для строительства
	build_timer = Timer.new()
	build_timer.wait_time = 5.0
	build_timer.one_shot = false
	build_timer.timeout.connect(_on_build_timer_timeout)
	add_child(build_timer)
	build_timer.start()
	
	# Загрузка данных о врагах и баффах
	load_enemies_data()
	load_buff_data()
	
	# Применение случайного баффа при спавне
	if randi() % 4 == 0:  # 25% шанс на бафф
		apply_random_buff()
	
	connect_signals()
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	if is_dead or is_building:  # Не двигаемся, если строитель занят строительством
		return
	
	# Движение врага
	time += delta
	var step_phase = sin(time * step_frequency * 2 * PI)
	var current_speed = base_speed + step_speed_variation * step_phase
	position.y += current_speed * delta

	# Анимация шага
	var scale_variation = 1.0 + step_scale_variation * abs(step_phase)
	sprite.scale = original_scale * scale_variation

func _on_build_timer_timeout():
	if is_dead:
		return
	
	# Начинаем строительство
	is_building = true
	sprite.play("build")
	await sprite.animation_finished
	
	# Спавним случайного врага
	spawn_random_enemy()
	
	# Возвращаемся к обычной анимации
	sprite.play("default")
	is_building = false

func spawn_random_enemy():
	if enemies_data.has("enemies"):
		var enemies = enemies_data["enemies"]
		var enemy_keys = enemies.keys()
		
		# Убираем строителя из списка возможных врагов для спавна
		enemy_keys.erase("builder")
		
		if enemy_keys.size() > 0:
			var random_key = enemy_keys[randi() % enemy_keys.size()]
			var enemy_info = enemies[random_key]
			
			var enemy_scene = load(enemy_info["scene_path"])
			if enemy_scene:
				var enemy_instance = enemy_scene.instantiate()
				enemy_instance.position = position + Vector2(0, 60)  # Спавн чуть ниже центра строителя
				
				# Убедимся, что спавненный враг не получает баффы
				if enemy_instance.has_method("set_buff_immune"):
					enemy_instance.set_buff_immune(true)  # Предотвращаем применение баффов
				
				get_parent().add_child(enemy_instance)
			else:
				print("Failed to load enemy scene: ", enemy_info["scene_path"])
		else:
			print("No valid enemies available for spawning.")
	else:
		print("No enemies data available.")

func load_enemies_data():
	var file_path = "res://Other/enemies_data.json"  # Убедитесь, что путь правильный
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_data = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var result = json.parse(json_data)
			if result == OK:
				enemies_data = json.get_data()
			else:
				print("Failed to parse JSON: ", json.get_error_message())
		else:
			print("Failed to open file: ", file_path)
	else:
		print("File does not exist: ", file_path)

func load_buff_data():
	var file_path = "res://Other/buff_data.json"  # Убедитесь, что путь правильный
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if file:
			var json_data = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var result = json.parse(json_data)
			if result == OK:
				buff_data = json.get_data()
			else:
				print("Failed to parse JSON: ", json.get_error_message())
		else:
			print("Failed to open file: ", file_path)
	else:
		print("File does not exist: ", file_path)

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
func attack(target: Node2D) -> void:
	if is_dead or is_attacking:
		return  

	current_target = target
	is_attacking = true 
	should_stop_attack = false  # Сбрасываем флаг остановки атаки

	# Остановка движения на время атаки
	set_process(false)  # Отключаем обработку движения
	$CharacterBody2D.velocity = Vector2.ZERO  # Останавливаем движение

	while current_target and not is_dead and not should_stop_attack:
		if not is_instance_valid(current_target) or not current_target.has_method("take_damage"):
			break

		if current_target.hp <= 0:
			break  

		# Запуск анимации атаки
		$CharacterBody2D/Sprite2D.play("attack")

		# Нанесение урона
		current_target.take_damage(25)

		if is_dead or not is_instance_valid(current_target):
			break

		# Задержка между атаками
		var timer = get_tree().create_timer(1.0 / attack_speed)
		await timer.timeout

		if not is_instance_valid(current_target) or current_target.hp <= 0:
			break

	# Завершение атаки
	is_attacking = false
	current_target = null

	# Восстановление обработки движения
	if not is_dead:
		set_process(true)

func stop_attack(target: Node2D) -> void:
	if current_target == target:
		should_stop_attack = true
		var timer = get_tree().create_timer(attack_cooldown)
		await timer.timeout
		should_stop_attack = false

func _on_node_added(node: Node):
	if node.is_in_group("bullet"):
		node.deal_damage.connect(bullet_damage)
	elif node.is_in_group("mine"):
		node.on_mine_step.connect(mine_damage)
	elif node.is_in_group("expl"):
		node.explosion_emit.connect(explosion_damage)
	elif node.is_in_group("ray"):
		node.ray_collide.connect(ray_damage)
	elif node.is_in_group("blast"):
		node.blast_damage.connect(mine_damage)
	elif node.is_in_group("poison"):
		node.poisoned.connect(on_poison_entered)
		node.unpoisoned.connect(on_poison_exited)
	elif node.is_in_group("tesla"):
		node.lightning_attack.connect(on_tesla_attack)
	elif node.is_in_group("bolt"):
		node.deal_damage.connect(bolt_damage)

func bolt_damage(victim: Node2D):
	if victim == self:
		take_bolt_damage(40)

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
		take_damage(40)

func blast_damage(victim: Node2D):
	if victim == self:
		take_damage(500)

func mine_damage(victim: Node2D):
	if victim == self:
		take_damage(999)

func connect_signals():
	var lose_zone = get_tree().get_first_node_in_group("lose_zone")
	if lose_zone:
		lose_zone.enemy_reach_end.connect(reach_end)

	var bullets = get_tree().get_nodes_in_group("bullet")
	for bullet in bullets:
		bullet.deal_damage.connect(bullet_damage)

	var mines = get_tree().get_nodes_in_group("mine")
	for mine in mines:
		mine.on_mine_step.connect(mine_damage)

	var expls = get_tree().get_nodes_in_group("expl")
	for expl in expls:
		expl.explosion_emit.connect(explosion_damage)

	var rays = get_tree().get_nodes_in_group("ray")
	for ray in rays:
		ray.ray_collide.connect(ray_damage)

	var blasts = get_tree().get_nodes_in_group("blast")
	for blast in blasts:
		blast.blast_damage.connect(blast_damage)

	var poisons = get_tree().get_nodes_in_group("poison")
	for poison in poisons:
		poison.poisoned.connect(on_poison_entered)
		poison.unpoisoned.connect(on_poison_exited)

	var teslas = get_tree().get_nodes_in_group("tesla")
	for tesla in teslas:
		tesla.lightning_attack.connect(on_tesla_attack)
	
	var bolts = get_tree().get_nodes_in_group("bolt")
	for bolt in bolts:
		bolt.deal_damage.connect(bolt_damage)


func take_electric_damage(amount: float, freeze_time: float = 0.0):
	if is_dead:
		return

	hp -= amount
	if hp <= 0:
		die()
		return  # Важно: немедленный выход после die()

	# Полностью очищаем предыдущий Tween
	if current_tween:
		current_tween.stop()
		current_tween.kill()
		current_tween = null  # Явный сброс ссылки

	# Создаем абсолютно новый Tween
	current_tween = create_tween().set_parallel(true)  # Параллельные анимации

	# Эффект синего цвета
	current_tween.tween_property(sprite, "modulate", Color(0.5, 0.5, 1), 0.1)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 1.4).set_delay(0.1)

	# Knockback эффект
	var original_pos = position
	current_tween.tween_property(self, "position", original_pos + Vector2(0, -2), 0.1)
	current_tween.tween_property(self, "position", original_pos, 0.2).set_delay(0.1)

	# Заморозка (если нужно)
	if freeze_time > 0:
		set_process(false)
		set_physics_process(false)
		await get_tree().create_timer(freeze_time).timeout
		if not is_dead:  # Проверка на случай смерти во время заморозки
			set_process(true)
			set_physics_process(true)

func take_damage(amount: float):
	if is_dead:
		return

	hp -= amount
	if hp <= 0:
		die()
		return

	# Очистка предыдущего Tween
	if current_tween:
		current_tween.stop()
		current_tween.kill()
		current_tween = null

	# Новый Tween с параллельными анимациями
	current_tween = create_tween().set_parallel(true)

	# Эффекты
	current_tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.4).set_delay(0.1)
	
	var original_pos = position
	current_tween.tween_property(self, "position", original_pos + Vector2(0, -2), 0.1)
	current_tween.tween_property(self, "position", original_pos, 0.2).set_delay(0.1)

func take_bolt_damage(amount: float):
	if is_dead:
		return

	hp -= amount
	if hp <= 0:
		die()
		return

	if current_tween:
		current_tween.stop()
		current_tween.kill()
		current_tween = null

	current_tween = create_tween().set_parallel(true)

	current_tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.4).set_delay(0.1)
	
	var original_pos = position
	current_tween.tween_property(self, "position", original_pos + Vector2(0, -50), 0.2)
	#current_tween.tween_property(self, "position", original_pos, 0.2).set_delay(0.1)

func die():
	if is_dead:  # Добавлена проверка на is_dead
		return

	is_dead = true  # Устанавливаем флаг is_dead

	sprite.modulate = Color(0.5, 0.5, 0.5)

	$CharacterBody2D/Sprite2D.stop()
	collision_shape.set_deferred("disabled", true)

	set_process(false)  # Отключаем обработку
	
	if is_instance_valid(self):
		await get_tree().create_timer(1.0).timeout
		died.emit()
		if randf() * 100.0 <= coin_spawn_chance:
			var coin_path = load("res://Scenes/obj/coin.tscn")
			var coin_instance = coin_path.instantiate()

			coin_instance.global_position = global_position

			get_parent().add_child(coin_instance)
		queue_free()
