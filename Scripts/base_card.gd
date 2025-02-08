extends Node2D

signal card_drag_started
signal card_drag_ended

var original_position : Vector2
var hover_offset : Vector2 = Vector2(0, -20)  # Смещение по оси Y при наведении
var dragging : bool = false  # Флаг для отслеживания состояния перетаскивания
var drag_offset : Vector2  # Смещение между позицией мыши и позицией объекта при начале перетаскивания
var hand_node : Node  # Ссылка на родительский узел, который управляет картами (например, hand)

@onready var sprite = $TextureRect

func _ready():
	original_position = sprite.position  # Сохраняем исходную позицию
	hand_node = get_parent()  # Получаем родительский узел, которым управляется список карт

func _on_texture_rect_mouse_entered() -> void:
	if not dragging:
		var sprite = $TextureRect
		sprite.position = original_position + hover_offset  # Поднимаем объект вверх

func _on_texture_rect_mouse_exited() -> void:
	if not dragging:  # Возвращаем объект в исходную позицию только если не перетаскиваем
		var sprite = $TextureRect
		sprite.position = original_position

func _on_area_2d_input_event(viewport, event: InputEvent, shape_idx: int) -> void:
	# Обрабатываем начало перетаскивания, когда мышь находится внутри `Area2D`
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		drag_offset = global_position - event.global_position
		emit_signal("card_drag_started")

func _input(event: InputEvent) -> void:
	if dragging:
		if event is InputEventMouseMotion:
			# Перемещение карты
			global_position = event.global_position + drag_offset
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# Завершение перетаскивания
			dragging = false
			position = original_position
			emit_signal("card_drag_ended")
