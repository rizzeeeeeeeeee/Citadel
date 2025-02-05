extends Node2D

signal lightning_attack

func _ready() -> void:
	$AnimatedSprite2D.visible = false
	await get_tree().create_timer(0.1).timeout  # Ждем 0.1 секунды
	$AnimatedSprite2D.visible = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	lightning_attack.emit(body.get_parent())
