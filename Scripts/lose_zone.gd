extends Area2D

signal enemy_reach_end

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		enemy_reach_end.emit(body.get_parent())
