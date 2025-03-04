extends Node2D

signal explosion_emit

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	$Area2D/CollisionShape2D.set_deferred("disabled", true)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"): 
		explosion_emit.emit(body.get_parent())
