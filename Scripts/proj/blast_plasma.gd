extends Node2D

@export var speed: float = 1000.0 # Скорость движения пули в пикселях в секунду
@export var explosion : PackedScene 
@onready var sprite = $Sprite2D
var is_hit = false

func _process(delta: float) -> void:
	if !is_hit:
		position.y -= speed * delta # Двигаем пулю вверх

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"): # Проверяем, принадлежит ли объект группе врагов
		call_deferred("_handle_explosion", body)

func _handle_explosion(body: Node2D) -> void:
	var explosion_instance = explosion.instantiate()
	# Устанавливаем Z-index для взрыва, чтобы он отрисовывался выше других объектов
	explosion_instance.z_index = 1
	explosion_instance.z_as_relative = false
	add_child(explosion_instance)
	sprite.visible = false
	is_hit = true

	# Плавное появление и исчезновение взрыва
	animate_explosion(explosion_instance)

	await get_tree().create_timer(1.5).timeout # Ждем завершения анимации
	queue_free() # Удаляем пулю

func animate_explosion(explosion_instance: Node2D) -> void:
	# Создаем Tween для анимации
	var tween = create_tween()

	# Начальные параметры взрыва (прозрачный и маленький)
	explosion_instance.modulate.a = 0
	explosion_instance.scale = Vector2(0.9, 0.9)

	# Плавное появление (увеличиваем прозрачность и масштаб)
	tween.tween_property(explosion_instance, "modulate:a", 1.0, 0.01) # Появление
	tween.parallel().tween_property(explosion_instance, "scale", Vector2(1.0, 1.0), 0.1) # Увеличение

	# Плавное исчезновение (уменьшаем прозрачность)
	tween.tween_property(explosion_instance, "modulate:a", 0.0, 1.5) # Исчезновение
	tween.tween_callback(explosion_instance.queue_free) # Удаляем взрыв после анимации
