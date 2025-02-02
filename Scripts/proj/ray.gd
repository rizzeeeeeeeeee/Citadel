extends Node2D

signal ray_collide

@onready var ray: Sprite2D = $Ray

var fade_in_duration: float = 0.1  
var fade_out_duration: float = 0.2  
var visible_duration: float = 0.2  

func _ready() -> void:
	ray.modulate.a = 0  
	start_fade_in()

func start_fade_in() -> void:
	var tween = create_tween()
	tween.tween_property(ray, "modulate:a", 1.0, fade_in_duration) 
	tween.tween_callback(start_visible_timer) 

func start_visible_timer() -> void:
	var timer = Timer.new()  
	timer.wait_time = visible_duration  
	timer.one_shot = true  
	timer.timeout.connect(start_fade_out)  
	add_child(timer)  
	timer.start()  

func start_fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(ray, "modulate:a", 0.0, fade_out_duration)  
	tween.tween_callback(self.queue_free) 

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"): 
		ray_collide.emit(body.get_parent())
