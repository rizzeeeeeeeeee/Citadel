extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#create_run_cards_data()
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

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
				"value": 3
			},
			{
				"id": 2,
				"name": "generator",
				"path": "res://Scenes/cards/generator_card.tscn",
				"value": 5
			}
		]
		
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data))
			file.close()
			print("Файл создан и данные записаны.")
		else:
			print("Ошибка при создании файла.")
