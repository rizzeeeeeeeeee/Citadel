extends Node2D

@export var bullet_scene: PackedScene # Сцена пули, должна быть назначена в инспекторе
@export var fire_rate: float = 0.5 # Скорость стрельбы (выстрелы в секунду)

@onready var muzzle: Marker2D = $TextureRect/Muzzle # Точка выхода пуль
@onready var raycast: RayCast2D = $TextureRect/RayCast2D

var _fire_timer: Timer
var _is_timer_active: bool = false
var _can_shoot: bool = true
var hp: float = 150

func _ready() -> void:
	_fire_timer = Timer.new()
	_fire_timer.wait_time = 1.0 / fire_rate
	_fire_timer.one_shot = false
	_fire_timer.timeout.connect(_shoot)
	add_child(_fire_timer)

func _process(delta: float) -> void:
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider and collider.is_in_group("enemy"):
			if _can_shoot: # Первый выстрел
				_shoot()
				_can_shoot = false
			if not _is_timer_active:
				_fire_timer.start()
				_is_timer_active = true
	else:
		_fire_timer.stop()
		_is_timer_active = false
		_can_shoot = true
		
func _shoot() -> void:
	$TextureRect.play("shoot")
	var bullet = bullet_scene.instantiate()
	await get_tree().create_timer(0.1).timeout
	if bullet and muzzle:
		bullet.position = muzzle.position
		get_parent().add_child(bullet)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		body.get_parent().attack(self)  # Вызываем метод атаки у врага

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		body.get_parent().stop_attack(self)  # Вызываем метод атаки у врага

func take_damage(amount: float) -> void:
	if hp <= 0:
		return  

	hp -= amount
	if hp <= 0:
		destroy()

func destroy() -> void:
	if is_instance_valid(self):  
		queue_free()
