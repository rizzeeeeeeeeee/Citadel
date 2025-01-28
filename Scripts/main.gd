extends Node2D

@export var spawnpoints: Array[NodePath] 
@export var base_enemy: PackedScene  
@export var spawn_interval: float = 5.0 
@export var energy: float = 0.0        
@export var energy_rate: float = 1.0

@onready var energy_bar = $CanvasLayer/ProgressBar
@onready var energy_label = $CanvasLayer/ProgressBar/Label
@onready var hand = $Hand


var spawn_index: int = 0 
var spawn_timer: Timer

func _ready() -> void:
	if base_enemy == null:
		print("base_enemy не установлен!")
		return

	if spawnpoints.size() != 10:
		print("Количество спавнпоинтов должно быть 10!")
		return

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	spawn_timer.connect("timeout", Callable(self, "spawn_next_enemy"))

	energy_bar.max_value = 10.0  
	energy_bar.min_value = 0.0   
	energy_bar.value = energy   

	hand.card_dropped.connect(update_bar)

func spawn_next_enemy() -> void:
	var spawnpoint_path = spawnpoints[spawn_index]
	var spawnpoint = get_node_or_null(spawnpoint_path)
	if spawnpoint and spawnpoint is Node2D:
		spawn_enemy(spawnpoint.global_position)
	else:
		print("Спавнпоинт по индексу %d не является Node2D или не задан.".format(spawn_index))

	spawn_index = (spawn_index + 1) % spawnpoints.size()

func spawn_enemy(position: Vector2) -> void:
	var enemy_instance = base_enemy.instantiate()
	if enemy_instance:
		add_child(enemy_instance)
		enemy_instance.position = position
	else:
		print("Не удалось создать экземпляр врага.")

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
