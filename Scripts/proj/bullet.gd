extends Node2D

@export var speed: float = 400.0  # Скорость движения пули в пикселях в секунду
@export var damage: float = 25.0  # Урон, который наносит пуля

var direction: Vector2 = Vector2.UP  # Направление движения пули (по умолчанию вверх)

signal deal_damage(victim: Node2D)

func _process(delta: float) -> void:
	# Двигаем пулю в направлении, заданном вектором direction
	position += direction * speed * delta

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):  # Проверяем, принадлежит ли объект группе врагов
		deal_damage.emit(body.get_parent())
		queue_free()  # Удаляем пулю
