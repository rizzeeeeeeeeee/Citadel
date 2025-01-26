extends Node2D

@export var speed: float = 30.0 
@export var hp: float = 125.0

func _process(delta: float) -> void:
	if hp <= 0:
		self.queue_free()
	else:
		# Перемещение объекта
		position.y += speed * delta
		
		# Обработка всех пуль в группе "bullet"
		var bullets = get_tree().get_nodes_in_group("bullet")
		for bullet in bullets:
			bullet.deal_damage.connect(damage)

func damage(victim: Node2D):
	if victim == self:
		hp -= 125
