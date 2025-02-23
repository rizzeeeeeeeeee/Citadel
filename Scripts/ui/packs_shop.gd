extends Node2D

var packs = []

func _ready() -> void:
	load_packs()
	display_random_packs()

# Загружаем пакеты из JSON файла
func load_packs():
	if FileAccess.file_exists("res://Other/card_packs_data.json"):
		var file = FileAccess.open("res://Other/card_packs_data.json", FileAccess.READ)
		var json_result = JSON.parse_string(file.get_as_text())
		if json_result != null:
			packs = json_result
		else:
			print("Error parsing JSON")
		file.close()
	else:
		print("File not found")

func display_random_packs():
	for child in get_children():
		if child.is_in_group("packs"):  
			child.queue_free()

	randomize() 
	for i in range(3):
		if packs.size() > 0:
			var random_index = randi() % packs.size()
			var pack = packs[random_index]
			load_and_display_pack(pack, i) 
		else:
			print("No packs available")

# Загружаем и отображаем пакет
func load_and_display_pack(pack: Dictionary, index: int):
	var pack_scene_path = pack.get("path")
	if pack_scene_path and ResourceLoader.exists(pack_scene_path):
		var pack_scene = load(pack_scene_path)
		if pack_scene:
			var pack_instance = pack_scene.instantiate()
			add_child(pack_instance)
			pack_instance.scale = Vector2(0.65, 0.65)
			var position = Vector2(110 * index, 100) 
			pack_instance.position = position
			pack_instance.set_original_position(position)
