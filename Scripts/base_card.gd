extends Node2D

signal card_drag_started
signal card_drag_ended
signal card_clicked
signal mouse_enter
signal mouse_exit

var original_position : Vector2
var hover_offset : Vector2 = Vector2(0, -20) 
var dragging : bool = false  
var drag_offset : Vector2  
var hand_node : Node  
var tween: Tween

@onready var sprite = $TextureRect

func _ready():
	original_position = sprite.position  
	hand_node = get_parent() 

func _on_texture_rect_mouse_entered() -> void:
	z_index = 5
	mouse_enter.emit()
	if not dragging:
		var sprite = $TextureRect
		if tween:
			tween.kill()  
		tween = create_tween()
		tween.tween_property(sprite, "position", original_position + hover_offset, 0.03)  

func _on_texture_rect_mouse_exited() -> void:
	z_index = 0
	mouse_exit.emit()
	if not dragging:
		var sprite = $TextureRect
		if tween:
			tween.kill()  
		tween = create_tween()
		tween.tween_property(sprite, "position", original_position, 0.03) 

func _on_area_2d_input_event(viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("card_clicked")
		SoundManager.play_take_card_sound()
		SoundManager.set_volume(0.10)
		dragging = true
		drag_offset = global_position - event.global_position
		emit_signal("card_drag_started")

func _input(event: InputEvent) -> void:
	if dragging:
		if event is InputEventMouseMotion:
			global_position = event.global_position + drag_offset
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			dragging = false
			position = original_position
			emit_signal("card_drag_ended")
