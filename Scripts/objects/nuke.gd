extends Node2D

signal deal_damage

var explosion_duration: float = 7.5
var explosion_timer: float = 0.0
var timer_radius: float = 30.0
var explosion_radius: float = 1000.0
var exploded: bool = false

var flash_duration: float = 7.5  
var max_brightness: float = 10.0
var flash_timer: float = 0.0

func _ready():
	$Area2D/CollisionShape2D.set_deferred("disabled", true)
	explosion_timer = explosion_duration

func _process(delta):
	if explosion_timer > 0:
		explosion_timer -= delta
		queue_redraw()
	elif not exploded:
		exploded = true
		start_explosion()
	elif flash_timer > 0:
		flash_timer -= delta
		queue_redraw()
	else:
		queue_free()

func _draw():
	if explosion_timer > 0:
		var angle = (1.0 - explosion_timer / explosion_duration) * 360.0
		draw_circle_arc(Vector2.ZERO, timer_radius, -90, angle - 90, Color(1.0, 0.0, 0.0, 0.5))
	elif exploded:
		draw_explosion()

func draw_circle_arc(center, radius, angle_from, angle_to, color):
	var nb_points = 32
	var points_arc = PackedVector2Array()
	points_arc.push_back(center)
	for i in range(nb_points + 1):
		var angle_point = deg_to_rad(angle_from + i * (angle_to - angle_from) / nb_points)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
	for index_point in range(nb_points):
		draw_line(points_arc[index_point], points_arc[index_point + 1], color, 7.0)

func start_explosion():
	$Area2D/CollisionShape2D.set_deferred("disabled", false)
	$Nuke.play()
	flash_timer = flash_duration

func draw_explosion():
	var alpha = flash_timer / flash_duration
	var brightness = max_brightness * (1.0 - alpha)

	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 0.5, 0.0, alpha))  
	gradient.set_color(1, Color(1.0, 0.0, 0.0, alpha))  

	for i in range(explosion_radius, 0, -10):
		var color = gradient.sample(float(i) / explosion_radius)
		draw_circle(Vector2.ZERO, i, color * brightness)

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		deal_damage.emit(body.get_parent())
