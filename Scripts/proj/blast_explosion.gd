extends Node2D

signal blast_damage

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"): 
		blast_damage.emit(body.get_parent())
