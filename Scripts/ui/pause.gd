extends Node

var is_paused = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass  # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"): 
		if !is_paused:
			self.visible = true
			get_tree().paused = true
			is_paused = true
		else:
			self.visible = false
			get_tree().paused = false
			is_paused = false

func _on_to_menu_pressed() -> void:
	var file_path = "user://run_cards_data.json"
	DirAccess.remove_absolute(file_path)

	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main.tscn")
