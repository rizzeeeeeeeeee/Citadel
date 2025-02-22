extends Node2D

var modifiers = []

func _ready() -> void:
	load_modifiers()
	display_random_modifiers()

# Загружаем модификаторы из JSON файла
func load_modifiers():
	if FileAccess.file_exists("res://Other/modifiers_data.json"):
		var file = FileAccess.open("res://Other/modifiers_data.json", FileAccess.READ)
		var json_result = JSON.parse_string(file.get_as_text())
		if json_result != null:
			modifiers = json_result
		else:
			print("Error parsing JSON")
		file.close()
	else:
		print("File not found")

func display_random_modifiers():
	# Сохраняем позиции старых модификаторов
	var old_positions = []
	for child in get_children():
		if child.is_in_group("mods"):
			old_positions.append(child.position)
			child.queue_free()

	randomize() 
	for i in range(3):
		if modifiers.size() > 0:
			var random_index = randi() % modifiers.size()
			var modifier = modifiers[random_index]
			load_and_display_modifier(modifier, old_positions[i] if i < old_positions.size() else Vector2(70 * i, 100))
		else:
			print("No modifiers available")

func load_and_display_modifier(modifier: Dictionary, position: Vector2):
	var modifier_scene_path = modifier.get("path")
	if modifier_scene_path and ResourceLoader.exists(modifier_scene_path):
		var modifier_scene = load(modifier_scene_path)
		if modifier_scene:
			var modifier_instance = modifier_scene.instantiate()
			add_child(modifier_instance)
			modifier_instance.position = position
			modifier_instance.set_original_position(position)
