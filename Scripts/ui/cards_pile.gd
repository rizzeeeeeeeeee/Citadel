extends Node2D

@onready var card_plates = $Control
var cards_data = []
var cards_visible = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	load_cards_data()

func load_cards_data():
	var file = FileAccess.open("user://run_cards_data.json", FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		file.close()
		var json = JSON.new()  # Создаем экземпляр JSON
		var parse_result = json.parse(json_data)  # Парсим данные
		if parse_result == OK:  # Проверяем успешность парсинга
			cards_data = json.get_data()  # Получаем данные
			print("JSON data loaded successfully")
		else:
			print("Failed to parse JSON: ", json.get_error_message())
	else:
		print("Failed to open JSON file.")

func reload_cards_data():
	cards_data.clear() 
	await get_tree().create_timer(0.1).timeout
	load_cards_data()

func _on_area_2d_mouse_entered() -> void:
	$AnimationPlayer.play("mouse_enter")

func _on_area_2d_mouse_exited() -> void:
	$AnimationPlayer.play("mouse_exit")

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_cards_visibility()

func toggle_cards_visibility():
	if cards_visible:
		hide_cards()
	else:
		show_cards()
	cards_visible = !cards_visible

func show_cards():
	var cards_per_line = 5  # Максимум 4 карты в одной линии
	var card_width = 50 # Ширина карты
	var card_height = 75  # Высота карты
	var spacing = 20  # Расстояние между картами
	var padding = 20  # Отступ от краев Control

	# Рассчитываем начальную позицию для первой карты
	var start_x = padding
	var start_y = padding

	# Вычисляем максимальное количество строк, которые могут поместиться в Control
	var max_rows = int((card_plates.size.y - 2 * padding) / (card_height + spacing))

	# Если карты не помещаются по высоте, сдвигаем начальную позицию вверх
	if cards_data.size() > cards_per_line * max_rows:
		var extra_rows = ceil(float(cards_data.size()) / cards_per_line) - max_rows
		start_y -= extra_rows * (card_height + spacing)

	for i in range(cards_data.size()):
		var card_data = cards_data[i]
		var card_scene = load(card_data["path"])
		var card_instance = card_scene.instantiate()
		card_plates.add_child(card_instance)

		# Вычисляем позицию карты
		var row = i / cards_per_line  # Номер строки
		var col = i % cards_per_line  # Номер колонки
		var x = start_x + col * (card_width + spacing)  # Позиция по X
		var y = start_y + row * (card_height + spacing)  # Позиция по Y

		# Убедимся, что карта не выходит за пределы Control по горизонтали
		if x + card_width > card_plates.size.x - padding:
			x = start_x  # Переносим на новую строку
			y += card_height + spacing
			row += 1
			col = 0

		card_instance.position = Vector2(x, y)

func hide_cards():
	for child in card_plates.get_children():
		card_plates.remove_child(child)
		child.queue_free()
