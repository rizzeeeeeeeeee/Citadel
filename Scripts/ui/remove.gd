extends Sprite2D

var original_position : Vector2
var dragging : bool = false
var drag_offset : Vector2

signal remover_drag_started
signal remover_drag_ended


func _ready():
	var sprite = $"."
	original_position = sprite.position  

func _on_area_2d_input_event(viewport, event: InputEvent, shape_idx: int) -> void:
	# Обрабатываем начало перетаскивания, когда мышь находится внутри `Area2D`
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		drag_offset = global_position - event.global_position
		emit_signal("remover_drag_started")

func _input(event: InputEvent) -> void:
	if dragging:
		if event is InputEventMouseMotion:
			# Перемещение карты
			global_position = event.global_position + drag_offset
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# Завершение перетаскивания
			dragging = false
			position = original_position
			emit_signal("remover_drag_ended")
