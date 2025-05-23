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
var spike_timer: Timer
var current_target: Node2D = null
var is_attacking: bool = false
var is_buff_immune: bool = false  
var should_stop_attack: bool = false
var attack_cooldown: float = 0.5

var buff_data: Array = []
var audio_pool: Array[AudioStreamPlayer] = []
const AUDIO_POOL_SIZE: int = 1  # Только один звук одновременно
var hit_sounds: Array[AudioStream] = [
	preload("res://Sounds/Robot Damage/hit_1.mp3"),
	preload("res://Sounds/Robot Damage/hit_2.mp3"),
	preload("res://Sounds/Robot Damage/hit_3.mp3")
]

func _ready():
	original_scale = sprite.scale
	poison_timer = Timer.new()
	poison_timer.wait_time = 1.0
	poison_timer.one_shot = false
	poison_timer.timeout.connect(_on_poison_timer_timeout)
	add_child(poison_timer)
	spike_timer = Timer.new()
	spike_timer.wait_time = 2.0
	spike_timer.one_shot = false
	spike_timer.timeout.connect(_on_spike_timer_timeout)
	add_child(spike_timer)
	load_buff_data()
	if randi() % 4 == 0:
		apply_random_buff()
	connect_signals()
	get_tree().node_added.connect(_on_node_added)
	initialize_audio_pool()  # Инициализация пула звуков

func initialize_audio_pool():
	for i in range(AUDIO_POOL_SIZE):
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_pool.append(audio_player)

func play_sound():
	if audio_pool.size() == 0:
		return

	# Выбираем случайный звук из hit_sounds
	var random_sound = hit_sounds[randi() % hit_sounds.size()]

	# Используем первый доступный аудиоплеер
	var player = audio_pool[0]
	if player.playing:
		player.stop()  # Останавливаем текущий звук, если он играет
	player.stream = random_sound
	player.play()

func set_buff_immune(value: bool):
	is_buff_immune = value

func attack(target: Node2D) -> void:
	if is_dead or is_attacking:
		return  

	current_target = target
	is_attacking = true 
	should_stop_attack = false 

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

		# Проверка на смерть персонажа или уничтожение цели
		if is_dead or not is_instance_valid(current_target):
			break

		# Задержка между атаками
		var timer = get_tree().create_timer(1.0 / attack_speed)
		await timer.timeout

		# Проверка на уничтожение цели после задержки
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
	elif node.is_in_group("burst"):
		node.deal_damage.connect(burst_damage)
	elif node.is_in_group("mine"):
		node.on_mine_step.connect(mine_damage)
	elif node.is_in_group("expl"):
		node.explosion_emit.connect(explosion_damage)
	elif node.is_in_group("ray"):
		node.ray_collide.connect(ray_damage)
	elif node.is_in_group("blast"):
		node.blast_damage.connect(blast_damage)
	elif node.is_in_group("poison"):
		node.poisoned.connect(on_poison_entered)
		node.unpoisoned.connect(on_poison_exited)
	elif node.is_in_group("tesla"):
		node.lightning_attack.connect(on_tesla_attack)
	elif node.is_in_group("bolt"):
		node.deal_damage.connect(bolt_damage)
	elif node.is_in_group("nuke"):
		node.deal_damage.connect(mine_damage)
	elif node.is_in_group("spike"):
		node.inside.connect(on_spike_entered)
		node.outside.connect(on_spike_exited)
	elif node.is_in_group("orbital"):
		node.deal_damage.connect(explosion_damage)

func load_buff_data():
	var file = FileAccess.open("res://Other/buff_data.json", FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		var json = JSON.new() 
		var result = json.parse(json_data)  
		if result == OK:
			buff_data = json.get_data() 
		else:
			print("Failed to parse JSON: ", json.get_error_message())
		file.close()
	else:
		print("Failed to load buff data.")

func apply_random_buff():
	if is_buff_immune:  
		return

	if buff_data.size() > 0:
		var random_index = randi() % buff_data.size()
		var buff = buff_data[random_index]
		var buff_scene = load(buff["path"])
		if buff_scene:
			var buff_instance = buff_scene.instantiate()
			buff_instance.position = position 
			add_child(buff_instance) 
			hp += buff.get("hp", 0)
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
	
	var bursts = get_tree().get_nodes_in_group("burst")
	for burst in bursts:
		burst.deal_damage.connect(burst_damage)
	
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
		
	var nukes = get_tree().get_nodes_in_group("nuke")
	for nuke in nukes:
		nuke.deal_damage.connect(mine_damage)
		
	var spikes = get_tree().get_nodes_in_group("spike")
	for spike in spikes:
		spike.inside.connect(on_spike_entered)
		spike.outside.connect(on_spike_exited)
	
	var orbitals = get_tree().get_nodes_in_group("orbital")
	for orbital in orbitals:
		orbital.deal_damage.connect(explosion_damage)
	
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

func on_spike_entered(victim: Node2D):
	if victim == self:
		spike_timer.start()

func on_spike_exited(victim: Node2D):
	if victim == self:
		spike_timer.stop()

func _on_spike_timer_timeout():
	take_damage(15)

func bullet_damage(victim: Node2D):
	if victim == self:
		take_damage(25)

func burst_damage(victim: Node2D):
	if victim == self:
		take_damage(5)

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
		take_damage(9999)

func take_electric_damage(amount: float, freeze_time: float = 0.0):
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

	current_tween.tween_property(sprite, "modulate", Color(0.5, 0.5, 1), 0.1)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 1.4).set_delay(0.1)

	var original_pos = position
	current_tween.tween_property(self, "position", original_pos + Vector2(0, -2), 0.1)
	current_tween.tween_property(self, "position", original_pos, 0.2).set_delay(0.1)

	if freeze_time > 0:
		set_process(false)
		set_physics_process(false)
		await get_tree().create_timer(freeze_time).timeout
		if not is_dead:  
			set_process(true)
			set_physics_process(true)

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
	SoundManager.play_random_hit_sound()
	SoundManager.set_volume(0.15)

	current_tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.4).set_delay(0.1)
	
	var original_pos = position
	current_tween.tween_property(self, "position", original_pos + Vector2(0, -50), 0.2)

func take_damage(amount: float):
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
	SoundManager.play_random_hit_sound()
	SoundManager.set_volume(0.15)

	current_tween.tween_property(sprite, "modulate", Color(1, 0.5, 0.5), 0.1)
	current_tween.tween_property(sprite, "modulate", Color.WHITE, 0.4).set_delay(0.1)
	
	var original_pos = position
	current_tween.tween_property(self, "position", original_pos + Vector2(0, -2), 0.1)
	current_tween.tween_property(self, "position", original_pos, 0.2).set_delay(0.1)

func die():
	if is_dead: 
		return

	is_dead = true  

	sprite.modulate = Color(0.5, 0.5, 0.5)

	$CharacterBody2D/Sprite2D.stop()
	collision_shape.set_deferred("disabled", true)

	set_process(false)  
	
	if is_instance_valid(self):
		await get_tree().create_timer(1.0).timeout
		died.emit()

		if randf() * 100.0 <= coin_spawn_chance:
			var coin_path = load("res://Scenes/obj/coin.tscn")
			var coin_instance = coin_path.instantiate()

			coin_instance.global_position = global_position

			get_parent().add_child(coin_instance)
		
		queue_free()
