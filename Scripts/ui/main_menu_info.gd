extends Node2D

@onready var card_plates = $Control
@onready var rarity_label = $InfoTab/Info/Rarity  # Предполагая, что это Label
@onready var energy_number = $InfoTab/Info/Number  # Предполагая, что это Label
@onready var dscr_label = $InfoTab/Info/Description  # Предполагая, что это Label
@onready var card_texture = $InfoTab/Info/TextureRect
var cards_data = []
var hovered_card_id = -1

func _ready() -> void:
	load_cards_data()
	show_cards()

func load_cards_data():
	var file = FileAccess.open("res://Other/cards_data.json", FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_data)
		if parse_result == OK:
			cards_data = json.get_data()
			print("JSON data loaded successfully")
		else:
			print("Failed to parse JSON: ", json.get_error_message())
	else:
		print("Failed to open JSON file.")

func show_cards():
	var cards_per_line = 4
	var card_width = 50
	var card_height = 95
	var spacing = 65
	var padding = 0

	var start_x = padding
	var start_y = padding

	var max_rows = int((card_plates.size.y - 2 * padding) / (card_height + spacing))

	if cards_data.size() > cards_per_line * max_rows:
		var extra_rows = ceil(float(cards_data.size()) / cards_per_line) - max_rows
		start_y -= extra_rows * (card_height + spacing)

	for i in range(cards_data.size()):
		var card_data = cards_data[i]
		var card_scene = load(card_data["path"])
		var card_instance = card_scene.instantiate()
		card_plates.add_child(card_instance)

		# Устанавливаем ID карты
		var card_id = card_data.get("id", i)
		card_instance.set_meta("card_id", card_id)
		
		card_instance.mouse_enter.connect(_on_card_mouse_enter.bind(card_id))
		card_instance.mouse_exit.connect(_on_card_mouse_exit)

		# Позиционирование карты
		var row = i / cards_per_line
		var col = i % cards_per_line
		var x = start_x + col * (card_width + spacing)
		var y = start_y + row * (card_height + spacing)

		if x + card_width > card_plates.size.x - padding:
			x = start_x
			y += card_height + spacing
			row += 1
			col = 0

		card_instance.position = Vector2(x, y)

func update_card_info(card_id: int):
	# Находим данные карты по ID
	var card_data = null
	for data in cards_data:
		if data["id"] == card_id:
			card_data = data
			break
	
	if card_data:
		# Обновляем текстуру карты
		if card_data.has("texture_path"):
			var texture = load(card_data["texture_path"])
			if texture:
				card_texture.texture = texture
		
		# Обновляем описание
		dscr_label.text = card_data.get("dscr", "")
		
		# Обновляем стоимость энергии
		var energy_value = int(card_data.get("value", 0))
		energy_number.text = str(energy_value)
		
		# Обновляем редкость и цвет текста
		var rarity_value = card_data.get("rarity", "common")
		rarity_label.text = rarity_value.capitalize()
		
		match rarity_value:
			"common":
				rarity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # Серый
			"uncommon":
				rarity_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Зеленый
			"rare":
				rarity_label.add_theme_color_override("font_color", Color(0.2, 0.2, 1.0))  # Синий
			"epic":
				rarity_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.8))  # Фиолетовый

func _on_card_mouse_enter(card_id: int):
	hovered_card_id = card_id
	#update_card_info(card_id)

func _on_card_mouse_exit():
	hovered_card_id = -1
	# Можно очистить информацию или оставить последнюю выбранную карту

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hovered_card_id != -1:
			SoundManager.play_take_card_sound()
			SoundManager.set_volume(0.15)
			print("Left mouse button pressed on card ID:", hovered_card_id)
			update_card_info(hovered_card_id)
