extends Node2D

@export var base_speed: float = 20.0  # Базовая скорость движения
@export var step_speed_variation: float = 10.0  # Изменение скорости при шаге
@export var step_scale_variation: float = 0.03  # Изменение размера спрайта при шаге
@export var step_frequency: float = 0.3  # Частота шагов (шагов в секунду)
@export var hp: float = 999.0

@onready var sprite: AnimatedSprite2D = $CharacterBody2D/Sprite2D  # Спрайт объекта

var time: float = 0.0  # Время для расчета шагов
var original_scale: Vector2  # Исходный размер спрайта

func _ready():
	# Сохраняем исходный размер спрайта
	original_scale = sprite.scale

func _process(delta: float) -> void:
	if hp <= 0:
		self.queue_free()
	else:
		# Увеличиваем время для расчета шагов
		time += delta

		# Рассчитываем фазу шага (от 0 до 1)
		var step_phase = sin(time * step_frequency * 2 * PI)

		# Изменяем скорость в зависимости от фазы шага
		var current_speed = base_speed + step_speed_variation * step_phase

		# Движение объекта по прямой (по оси Y)
		position.y += current_speed * delta

		# Изменяем размер спрайта в зависимости от фазы шага
		var scale_variation = 1.0 + step_scale_variation * abs(step_phase)
		sprite.scale = original_scale * scale_variation

		# Обработка всех пуль в группе "bullet"
		var bullets = get_tree().get_nodes_in_group("bullet")
		for bullet in bullets:
			bullet.deal_damage.connect(damage)

func damage(victim: Node2D):
	if victim == self:
		$CharacterBody2D/Sprite2D.play("damage")
		hp -= 10
