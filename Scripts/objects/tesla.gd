extends Node2D

@export var lightning: PackedScene  

var enemies_in_range: Array = []  
var lightning_instances: Dictionary = {}  

enum State { IDLE, ATTACKING }
var current_state: State = State.IDLE  

func _ready():
	pass

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and not enemies_in_range.has(body):
		enemies_in_range.append(body)  
		_start_attack(body)  

func _on_attack_area_body_exited(body: Node2D) -> void:
	if enemies_in_range.has(body):
		enemies_in_range.erase(body)
		_stop_attack(body)

func _process(delta: float) -> void:
	for enemy in enemies_in_range:
		_update_lightning(enemy)

func _start_attack(enemy: Node2D):
	var lightning_instance = lightning.instantiate()
	add_child(lightning_instance)
	lightning_instances[enemy] = lightning_instance

	var attack_timer = Timer.new()
	attack_timer.wait_time = 1.0  
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout.bind(enemy))
	add_child(attack_timer)

	attack_timer.start()

func _stop_attack(enemy: Node2D):
	if lightning_instances.has(enemy):
		lightning_instances[enemy].queue_free()
		lightning_instances.erase(enemy)

func _update_lightning(enemy: Node2D):
	if lightning_instances.has(enemy):
		var lightning_instance = lightning_instances[enemy]
		var direction = enemy.global_position - global_position
		var distance = direction.length() 

		var angle = atan2(direction.y, direction.x)
		lightning_instance.rotation = angle
		lightning_instance.z_index = 1
		lightning_instance.z_as_relative = false
		var base_length = 190.0
		var scale_factor = distance / base_length
		lightning_instance.scale.x = scale_factor  

func _on_attack_timer_timeout(enemy: Node2D):
	# Атака завершена, удаляем молнию
	if lightning_instances.has(enemy):
		lightning_instances[enemy].queue_free()
		lightning_instances.erase(enemy)

	if enemies_in_range.has(enemy):
		var cooldown_timer = Timer.new()
		cooldown_timer.wait_time = 2.0  
		cooldown_timer.one_shot = true
		cooldown_timer.timeout.connect(_on_cooldown_timer_timeout.bind(enemy))
		add_child(cooldown_timer)
		cooldown_timer.start()

func _on_cooldown_timer_timeout(enemy: Node2D):
	if enemies_in_range.has(enemy):
		_start_attack(enemy)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		self.queue_free()
