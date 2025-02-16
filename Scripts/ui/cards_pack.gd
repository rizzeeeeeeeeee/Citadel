extends Node2D

@onready var pack_sprite := $Sprite2D
@onready var selection_container := $Control

var cards_data = []
var chosen_cards = []

# Веса для каждой редкости
var rarity_weights = {
	"common": 50,
	"uncommon": 30,
	"rare": 15,
	"epic": 5
}

func _ready() -> void:
	selection_container.hide() # Скрываем контейнер выбора карт

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_spawn_cards_for_selection()

func _spawn_cards_for_selection() -> void:
	# Загружаем JSON с картами
	var file := FileAccess.open("res://Other/cards_data.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		cards_data = JSON.parse_string(json_string)
		file.close()
	else:
		printerr("Не удалось загрузить cards_data.json")
		return

	# Выбираем 3 случайные карты с учетом редкости
	chosen_cards = []
	while chosen_cards.size() < 3 and cards_data.size() > 0:
		var random_card = _get_random_card_with_rarity()
		chosen_cards.append(random_card)
		cards_data.erase(random_card)

	# Спавним их в сцене
	for i in range(3):
		var card_data = chosen_cards[i]
		var card_scene = load(card_data["path"]).instantiate()
		card_scene.position = Vector2(i * 150, 0)  # Расставляем карты в ряд
		card_scene.set_meta("card_data", card_data) # Запоминаем данные карты
		card_scene.connect("card_clicked", _on_card_selected.bind(card_scene))
		selection_container.add_child(card_scene)

		# Создаем Label для отображения редкости карты
		var rarity_label = Label.new()
		rarity_label.text = card_data["rarity"].capitalize()  # Устанавливаем текст редкости
		rarity_label.position = Vector2(i * 150, 150)  # Позиция под картой
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # Выравнивание по центру

		# Устанавливаем цвет текста в зависимости от редкости
		match card_data["rarity"]:
			"common":
				rarity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # Серый
			"uncommon":
				rarity_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Зеленый
			"rare":
				rarity_label.add_theme_color_override("font_color", Color(0.2, 0.2, 1.0))  # Синий
			"epic":
				rarity_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.8))  # Фиолетовый
		
		rarity_label.add_theme_constant_override("outline_size", 4)  # Размер обводки
		rarity_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		selection_container.add_child(rarity_label)

	# Показываем контейнер и скрываем пак
	selection_container.show()
	pack_sprite.hide()

func _get_random_card_with_rarity() -> Dictionary:
	var total_weight = 0
	for card in cards_data:
		total_weight += rarity_weights[card["rarity"]]

	var random_weight = randi() % total_weight
	var current_weight = 0

	for card in cards_data:
		current_weight += rarity_weights[card["rarity"]]
		if current_weight > random_weight:
			return card

	return cards_data[0] # Если что-то пошло не так, вернем первую карту

func _on_card_selected(card: Node) -> void:
	var hand = get_tree().get_first_node_in_group("hand")
	var card_pile = get_tree().get_first_node_in_group("card_pile")
	var selected_card = card.get_meta("card_data")
	_add_card_to_current_run(selected_card)

	# Удаляем все карты выбора и скрываем контейнер
	for child in selection_container.get_children():
		child.queue_free()
	selection_container.hide()

	await hand.reload_cards_data()
	await card_pile.reload_cards_data()
	# Удаляем этот объект (пак карт)
	queue_free()

func _add_card_to_current_run(card_data: Dictionary) -> void:
	# Загружаем текущий JSON
	var file := FileAccess.open("user://run_cards_data.json", FileAccess.READ)
	var current_cards = []
	if file:
		var json_string = file.get_as_text()
		current_cards = JSON.parse_string(json_string)
		file.close()
	
	# Добавляем выбранную карту
	current_cards.append(card_data)

	# Сохраняем JSON обратно
	file = FileAccess.open("user://run_cards_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(current_cards, "\t"))
	file.close()
