extends Node2D

@export var base_speed: float = 20.0
@export var step_speed_variation: float = 10.0  
@export var step_scale_variation: float = 0.03 
@export var step_frequency: float = 0.3 
@export var hp: float = 999.0

@onready var sprite: AnimatedSprite2D = $CharacterBody2D/Sprite2D  
@onready var collision_shape: CollisionShape2D = $CharacterBody2D/CollisionShape2D

var time: float = 0.0  
var original_scale: Vector2  
var is_dead: bool = false
var current_tween: Tween = null 

func _ready():
	original_scale = sprite.scale

func _process(delta: float) -> void:
	if is_dead:
		return
	
	if hp <= 0:
		die()
	else:
		time += delta

		var step_phase = sin(time * step_frequency * 2 * PI)
		var current_speed = base_speed + step_speed_variation * step_phase

		position.y += current_speed * delta

		var scale_variation = 1.0 + step_scale_variation * abs(step_phase)
		sprite.scale = original_scale * scale_variation

		# Обработка всех пуль в группе "bullet"
		var bullets = get_tree().get_nodes_in_group("bullet")
		var mines = get_tree().get_nodes_in_group("mine")
		var expls = get_tree().get_nodes_in_group("expl")
		var rays = get_tree().get_nodes_in_group("ray")
		for bullet in bullets:
			bullet.deal_damage.connect(bullet_damage)
		for expl in expls:
			expl.explosion_emit.connect(explosion_damage)
		for mine in mines:
			mine.on_mine_step.connect(mine_damage)
		for ray in rays:
			ray.ray_collide.connect(mine_damage)

func bullet_damage(victim: Node2D):
	if victim == self:
		take_damage(25)

func explosion_damage(victim: Node2D):
	if victim == self:
		take_damage(100)

func ray_damage(victim: Node2D):
	if victim == self:
		take_damage(999)

func mine_damage(victim: Node2D):
	if victim == self:
		take_damage(999)

func take_damage(amount: float):
	if is_dead:
		return
	
	hp -= amount
	if hp <= 0:
		die()
	else:
		if current_tween:
			current_tween.kill()
		
		# Эффект покраснения
		sprite.modulate = Color(1, 0.5, 0.5)
		current_tween = create_tween()
		current_tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.5)  

		var knockback = Vector2(0, -2)  
		current_tween.parallel().tween_property(self, "position", position + knockback, 0.1)
		current_tween.parallel().tween_property(self, "position", position, 0.1)

func die():
	if is_dead:
		return
	
	is_dead = true

	sprite.modulate = Color(0.5, 0.5, 0.5)

	collision_shape.set_deferred("disabled", true)

	set_process(false)

	await get_tree().create_timer(1.0).timeout
	queue_free()
