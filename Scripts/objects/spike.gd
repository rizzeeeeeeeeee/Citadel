extends Node2D

signal inside
signal outside

func _ready() -> void:
	SoundManager.play_placement_sound()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"): 
		inside.emit(body.get_parent())

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"): 
		outside.emit(body.get_parent())
