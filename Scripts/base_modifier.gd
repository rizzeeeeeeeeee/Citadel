extends Node2D

signal mod_purchased(modifier)
signal mod_deleted(modifier)

@export var id: int 
@export var value: int

var dragging : bool = false  
var tween: Tween
var original_position : Vector2
var hover_offset : Vector2 = Vector2(0, -5) 
var drag_offset : Vector2
var in_buy_zone : bool = false  
var can_drag : bool = true

func _ready():
	original_position = self.position  

func set_original_position(new_position: Vector2) -> void:
	original_position = new_position

func _on_area_2d_mouse_entered() -> void:
	z_index = 5
	$Info.visible = true
	if not dragging and can_drag:
		if tween:
			tween.kill()  
		tween = create_tween()
		tween.tween_property(self, "position", original_position + hover_offset, 0.1)

func _on_area_2d_mouse_exited() -> void:
	z_index = 0 
	$Info.visible = false 
	if not dragging and can_drag:
		if tween:
			tween.kill()  
		tween = create_tween()
		tween.tween_property(self, "position", original_position, 0.1)

func _on_area_2d_input_event(viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and can_drag:
		dragging = true
		drag_offset = global_position - event.global_position

func _input(event: InputEvent) -> void:
	var shop = get_tree().get_first_node_in_group("buy_zone")
	var main = get_tree().get_first_node_in_group("main")
	if dragging:
		if event is InputEventMouseMotion:
			$Info.visible = false
			global_position = event.global_position + drag_offset
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			dragging = false
			if shop.get_parent().get_parent().mouse_in_buy_zone and main.coins_int >= value: 
				mod_purchased.emit(id)  
				queue_free() 
			else:
				position = original_position  

func change_status():
	$Button.visible = true
	$Label.visible = false
	can_drag = false

func _on_button_pressed() -> void:
	mod_deleted.emit(self)
	queue_free()
