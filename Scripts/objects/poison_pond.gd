extends Node2D

signal poisoned
signal unpoisoned

func _ready() -> void:
	var tween = create_tween()
	$Sprite2D.scale = Vector2(0.9, 0.9)
	tween.tween_property($Sprite2D, "modulate:a", 1.0, 0.01) # Появление
	tween.parallel().tween_property($Sprite2D, "scale", Vector2(7.0, 7.0), 0.1) # Увеличение
	await get_tree().create_timer(10.0).timeout
	$Sprite2D.play("end")



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"): # Проверяем, принадлежит ли объект группе врагов
		poisoned.emit(body.get_parent())

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy"): # Проверяем, принадлежит ли объект группе врагов
		unpoisoned.emit(body.get_parent())
