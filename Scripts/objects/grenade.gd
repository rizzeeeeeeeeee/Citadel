extends Node2D

@onready var sprite : Sprite2D = $Sprite2D
@export var explosion : PackedScene 


# Скорость уменьшения масштаба
var scale_speed: float = 3.0
# Скорость вращения
var rotation_speed: float = 30.0

# Таймер для удаления гранаты и создания взрыва
var grenade_timer: float = 0.7
# Таймер для удаления взрыва
var explosion_timer: float = 0.55
# Флаг для отслеживания, был ли создан взрыв
var explosion_spawned: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SoundManager.play_grenade_sound()
	SoundManager.set_volume(2.0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Уменьшаем масштаб спрайта
	sprite.scale -= Vector2(scale_speed * delta, scale_speed * delta)
	
	# Вращаем спрайт влево
	sprite.rotation_degrees -= rotation_speed * delta
	
	# Останавливаем уменьшение и вращение, если масштаб стал слишком маленьким
	if sprite.scale.x <= 0.1 or sprite.scale.y <= 0.1:
		sprite.scale = Vector2(0.1, 0.1)
		rotation_speed = 0.0
		scale_speed = 0.0
	
	# Уменьшаем таймер гранаты
	grenade_timer -= delta
	
	# Если таймер гранаты истек и взрыв еще не создан
	if grenade_timer <= 0 and not explosion_spawned:
		# Скрываем гранату
		sprite.visible = false
		
		# Создаем взрыв
		var explosion_instance = explosion.instantiate()
		add_child(explosion_instance)
		explosion_spawned = true
	
	# Если взрыв был создан, уменьшаем таймер взрыва
	if explosion_spawned:
		explosion_timer -= delta
		
		# Если таймер взрыва истек, удаляем взрыв и гранату
		if explosion_timer <= 0:
			queue_free()
