extends Node2D

signal on_mine_step
@export var explosion : PackedScene
@onready var sprite = $Sprite2D

func _on_area_2d_body_entered(body: Node2D) -> void:
	on_mine_step.emit(body.get_parent())
	sprite.visible = false
	await get_tree().create_timer(0.1).timeout
	$Area2D/CollisionShape2D.set_deferred("disabled", true)

	var explosion_instance = explosion.instantiate()
	add_child(explosion_instance)
	
	await get_tree().create_timer(1.0).timeout
	explosion_instance.queue_free()
	self.queue_free()
