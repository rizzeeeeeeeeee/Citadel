extends Node2D

signal explosion_emit

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"): # Проверяем, принадлежит ли объект группе врагов
		explosion_emit.emit(body.get_parent())
