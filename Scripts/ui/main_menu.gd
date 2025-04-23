extends Control

func _ready() -> void:
	create_run_cards_data()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_info_pressed() -> void:
	$Camera2D/Menu.hide()
	$Camera2D/Info.show()

func _on_back_pressed() -> void:
	$Camera2D/Menu.show()
	$Camera2D/Info.hide()

func _on_exit_pressed() -> void:
	get_tree().quit()

func create_run_cards_data():
	var file_path = "user://run_cards_data.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file:
		# Файл существует, ничего не делаем
		file.close()
		print("Файл уже существует, ничего не делаем.")
	else:
		# Файл не существует, создаем его и записываем данные
		var data = [
			{
				"id": 1,
				"name": "single_gun",
				"path": "res://Scenes/cards/single_gun_card.tscn",
				"value": 3,
				"rarity": "common"
			},
			{
				"id": 2,
				"name": "generator",
				"path": "res://Scenes/cards/generator_card.tscn",
				"value": 5,
				"rarity": "common"
			}
		]
		
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data))
			file.close()
			print("Файл создан и данные записаны.")
		else:
			print("Ошибка при создании файла.")
