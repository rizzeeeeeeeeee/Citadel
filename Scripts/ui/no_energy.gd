extends Label

var shake_intensity: float = 5.0
var fade_duration: float = 0.3
var appear_duration: float = 0.1
var shake_duration: float = 0.2

func animate_label(label: Label):
	label.modulate.a = 0.0  
	label.visible = true    

	var tween = label.create_tween()

	tween.tween_property(label, "modulate:a", 1.0, appear_duration)

	tween.tween_callback(_start_shake.bind(label))
	tween.tween_interval(shake_duration)

	tween.tween_property(label, "modulate:a", 0.0, fade_duration)

func _start_shake(label: Label):
	var tween = label.create_tween()
	var initial_position = label.position

	for i in range(10):  
		var offset = Vector2(randf_range(-shake_intensity, shake_intensity),
							 randf_range(-shake_intensity, shake_intensity))
		tween.tween_property(label, "position", initial_position + offset, 0.05)
		tween.tween_property(label, "position", initial_position, 0.05)
