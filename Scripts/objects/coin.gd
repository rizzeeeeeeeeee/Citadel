extends Node2D

@onready var sprite = $Sprite
@export var jump_height: float = -100.0 
@export var jump_distance: float = 200.0  
@export var jump_duration: float = 0.4 
@export var fade_duration: float = 0.2  # Длительность исчезновения
@export var rise_duration: float = 0.4  # Длительность подъема вверх при сборе

signal add_coin

var start_position: Vector2
var target_position: Vector2
var elapsed_time: float = 0.0
var is_jumping: bool = false
var is_fading: bool = false
var is_rising: bool = false  # Флаг для подъема вверх

func _ready() -> void:
	start_position = sprite.position  
	start_jump()

func _process(delta: float) -> void:
	if is_jumping:
		elapsed_time += delta

		var t = elapsed_time / jump_duration
		if t > 1.0:
			t = 1.0
			is_jumping = false  # Завершаем прыжок

		var horizontal_progress = t  
		var vertical_progress = -4 * (t - 0.5) ** 2 + 1  

		sprite.position.x = start_position.x + horizontal_progress * (target_position.x - start_position.x)
		sprite.position.y = start_position.y + vertical_progress * jump_height

	if is_rising:
		elapsed_time += delta
		var t = elapsed_time / rise_duration
		if t > 1.0:
			t = 1.0
			is_rising = false
			start_fade()  # Начинаем исчезновение после подъема

		# Плавно поднимаем монетку вверх
		sprite.position.y = start_position.y + jump_height * t

	if is_fading:
		elapsed_time += delta
		var t = elapsed_time / fade_duration
		if t > 1.0:
			t = 1.0
			is_fading = false
			queue_free()  # Удаляем объект после завершения исчезновения

		sprite.modulate.a = 1.0 - t  # Постепенно уменьшаем прозрачность

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		add_coin.emit(self)
		$Sprite.play("take")
		start_rise()  # Начинаем подъем вверх при клике

func start_jump() -> void:
	var random_angle = randf_range(0, 2 * PI)  
	var random_distance = randf_range(0, jump_distance) 
	target_position = start_position + Vector2(cos(random_angle), sin(random_angle)) * random_distance
	elapsed_time = 0.0
	is_jumping = true

func start_rise() -> void:
	elapsed_time = 0.0
	is_rising = true
	start_position = sprite.position  # Обновляем начальную позицию для подъема

func start_fade() -> void:
	elapsed_time = 0.0
	is_fading = true
