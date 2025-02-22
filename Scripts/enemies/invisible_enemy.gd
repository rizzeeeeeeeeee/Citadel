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
var is_buff_immune: bool = false  # Добавлено: флаг иммунитета к баффам
var received_damage_timer: Timer = Timer.new()  # Таймер для отслеживания времени без получения урона
var should_stop_attack: bool = false
var attack_cooldown: float = 0.5

# Загрузка данных о баффах из JSON файла
var buff_data: Array = []

func _ready():
	original_scale = sprite.scale
	poison_timer = Timer.new()
	poison_timer.wait_time = 1.0
	poison_timer.one_shot = false
	poison_timer.timeout.connect(_on_poison_timer_timeout)
	add_child(poison_timer)
	
	received_damage_timer.wait_time = 1.0
	received_damage_timer.one_shot = true
	received_damage_timer.timeout.connect(_on_received_damage_timeout)
	add_child(received_damage_timer)
	
	load_buff_data()
	if randi() % 4 == 0:
		apply_random_buff()
	connect_signals()
	get_tree().node_added.connect(_on_node_added)
	
	# Изначально враг невидим и без коллизии
	set_invisible()

func set_invisible():
	$CharacterBody2D.set_collision_layer_value(2, false)
	$CharacterBody2D.set_collision_layer_value(10, false)
	sprite.modulate.a = 0.5  # Полупрозрачный
	$CharacterBody2D.remove_from_group("enemy")

func _set_visible():
	$CharacterBody2D.set_collision_layer_value(2, true)
	$CharacterBody2D.set_collision_layer_value(10, false)
	sprite.modulate.a = 1.0  # Полностью видимый
	$CharacterBody2D.add_to_group("enemy")

func set_buff_immune(value: bool):
	is_buff_immune = value


func attack(target: Node2D) -> void:
	if is_dead or is_attacking:
		return  

	current_target = target
	is_attacking = true 
	should_stop_attack = false  # Сбрасываем флаг остановки атаки

	while current_target and not is_dead and not should_stop_attack:
		_set_visible()
		if not is_instance_valid(current_target) or not current_target.has_method("take_damage"):
			break

		if current_target.hp <= 0:
			break  

		$CharacterBody2D/Sprite2D.play("attack")
		current_target.take_damage(25)

		if is_dead or not is_instance_valid(current_target):
			break

		var timer = get_tree().create_timer(1.0 / attack_speed)
		await timer.timeout

		if not is_instance_valid(current_target) or current_target.hp <= 0:
			break

	is_attacking = false
	current_target = null

	if not is_dead:
		set_process(true)

func stop_attack(target: Node2D) -> void:
	if current_target == target:
		await get_tree().create_timer(1.0).timeout
		set_invisible()
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
	if is_buff_immune:  # Добавлено: проверка на иммунитет к баффам
		return

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
	if is_dead or is_attacking:
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
		await get_tree().create_timer(0.5).timeout
		_set_visible()

func on_poison_exited(victim: Node2D):
	if victim == self:
		poison_timer.stop()
		await get_tree().create_timer(0.5).timeout
		set_invisible()

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

	received_damage_timer.start()

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

func _on_received_damage_timeout():
	if not is_dead and not is_attacking:
		set_invisible()
