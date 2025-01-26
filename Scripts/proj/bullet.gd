extends Node2D

@export var speed: float = 400.0 # Скорость движения пули в пикселях в секунду
@export var damage: float = 25.0

signal deal_damage(victim: Node2D)

func _process(delta: float) -> void:
	position.y -= speed * delta # Двигаем пулю вверх


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"): # Проверяем, принадлежит ли объект группе врагов
		deal_damage.emit(body.get_parent())
		queue_free() # Удаляем пулю
