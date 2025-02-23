extends Node2D

var modifiers = []
var modifier_positions = [Vector2(0, 100), Vector2(70, 100), Vector2(140, 100)]

func _ready() -> void:
	load_modifiers()
	first_display()

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

func first_display():
	for i in range(modifier_positions.size()):
		if modifiers.size() == 0:
			return
		var random_index = randi() % modifiers.size()
		var modifier = modifiers[random_index]
		var modifier_instance = load_and_display_modifier(modifier, modifier_positions[i])

func display_random_modifiers():
	for child in get_children():
		if child.is_in_group("mods"):
			# Отключаем старые обработчики сигналов
			if child.has_signal("mod_purchased"):
				child.mod_purchased.disconnect(_on_mod_purchased)
			if child.has_signal("mod_deleted"):
				child.mod_deleted.disconnect(_on_mod_deleted)
			child.queue_free()
	for i in range(modifier_positions.size()):
		if modifiers.size() == 0:
			return
		var random_index = randi() % modifiers.size()
		var modifier = modifiers[random_index]
		var modifier_instance = load_and_display_modifier(modifier, modifier_positions[i])
		if modifier_instance:
			modifier_instance.mod_purchased.connect(_on_mod_purchased)
			modifier_instance.mod_deleted.connect(_on_mod_deleted)

func load_and_display_modifier(modifier: Dictionary, position: Vector2):
	var modifier_scene_path = modifier.get("path")
	if modifier_scene_path and ResourceLoader.exists(modifier_scene_path):
		var modifier_scene = load(modifier_scene_path)
		if modifier_scene:
			var modifier_instance = modifier_scene.instantiate()
			add_child(modifier_instance)
			modifier_instance.position = position
			modifier_instance.set_original_position(position)
			return modifier_instance
	return null

func get_modifier_at_position(position: Vector2):
	for child in get_children():
		if child.is_in_group("mods") and child.position == position:
			return child
	return null

func _on_mod_purchased(modifier_id: int):
	print("Modifier purchased:", modifier_id)

	var mod_zone = get_tree().get_first_node_in_group("mod_zone")
	if mod_zone:
		mod_zone.add_modifier(modifier_id)
	else:
		print("Mod zone not found!")

func _on_mod_deleted(modifier):
	print("Modifier deleted:", modifier)
