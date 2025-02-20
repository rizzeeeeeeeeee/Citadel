extends Node2D

@export var bullet_scene: PackedScene # Сцена пули, должна быть назначена в инспекторе

var hp: float = 500

func _process(delta: float) -> void:
	if hp <= 500:
		$TextureRect.play("full")
	if hp <= 300:
		$TextureRect.play("half")
	if hp <= 100:
		$TextureRect.play("end")
		
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		body.get_parent().attack(self)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		body.get_parent().stop_attack(self)

func take_damage(amount: float) -> void:
	if hp <= 0:
		return  

	hp -= amount
	if hp <= 0:
		destroy()

func destroy() -> void:
	if is_instance_valid(self):  
		queue_free()
