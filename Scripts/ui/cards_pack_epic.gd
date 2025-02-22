extends Node2D

@onready var pack_sprite := $Sprite2D
@onready var selection_container := $Control
@onready var sprite = $Sprite2D

var cards_data = []
var original_position : Vector2
var chosen_cards = []
var tween: Tween
var hover_offset : Vector2 = Vector2(0, -20) 

# Переменная для определения, нужно ли спавнить только карты класса epic
@export var only_epic: bool = false

func _ready() -> void:
	original_position = sprite.position  
	selection_container.hide() 

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		$Label.visible = true
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

	# Если only_epic = true, фильтруем карты, оставляя только epic
	if only_epic:
		cards_data = cards_data.filter(func(card): return card["rarity"] == "epic")

	# Проверяем, есть ли карты с редкостью epic
	if cards_data.size() == 0:
		printerr("Нет карт с редкостью epic!")
		return

	# Выбираем 3 случайные карты из отфильтрованного списка
	chosen_cards = []
	while chosen_cards.size() < 3 and cards_data.size() > 0:
		var random_index = randi() % cards_data.size()
		var random_card = cards_data[random_index]
		chosen_cards.append(random_card)
		cards_data.remove_at(random_index)  # Удаляем выбранную карту, чтобы избежать дубликатов

	# Спавним их в сцене
	for i in range(chosen_cards.size()):
		var card_data = chosen_cards[i]
		var card_scene = load(card_data["path"]).instantiate()
		card_scene.position = Vector2(i * 150, 0)  # Расставляем карты в ряд
		card_scene.set_meta("card_data", card_data) # Запоминаем данные карты
		card_scene.connect("card_clicked", _on_card_selected.bind(card_scene))
		selection_container.add_child(card_scene)

		# Создаем Label для отображения редкости карты
		var rarity_label = Label.new()
		var font = load("res://Fonts/MegamaxJonathanToo-YqOq2.ttf")
		rarity_label.add_theme_font_override("font", font)
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

func _on_area_2d_mouse_exited() -> void:
	if tween:
		tween.kill()  
	tween = create_tween()
	tween.tween_property(sprite, "position", original_position, 0.03) 

func _on_area_2d_mouse_entered() -> void:
	if tween:
		tween.kill()  
	tween = create_tween()
	tween.tween_property(sprite, "position", original_position + hover_offset, 0.03)
