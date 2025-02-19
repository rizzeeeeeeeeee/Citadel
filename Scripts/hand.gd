extends Node2D

var card_scenes: Array = []
var obj_scenes: Array = []
var preview_scenes: Array = []

var card_count: int = 0
var max_card_count: int = 4
var card_spacing: float = 5.0
var cards: Array = []
var saved_positions: Array = []
var active_zones: Array = []
var dragging_card_unique_id: int = -1
var current_card_index: int = 0
var unique_card_id: int = 1
var zone_states: Dictionary = {}
var spawned_objects: Dictionary = {}
var card_positions: Dictionary = {}
var remover_dragging: bool = false
var active_zones_remover: Array = []
var preview_objects: Dictionary = {}  # Для хранения превью объектов

signal card_dropped(value: float)

@onready var remover = $"../Remove"
@onready var energy_bar = $"../CanvasLayer/ProgressBar"
@onready var no_energy_label = $"../CanvasLayer/No Energy"

func _ready():
	#load_json_data("user://run_cards_data.json", card_scenes)
	load_json_data("res://Other/cards_data.json", card_scenes)
	load_json_data("res://Other/obj_data.json", obj_scenes)
	load_json_data("res://Other/prv_obj_data.json", preview_scenes)

	for zone_id in range(1, 61):
		var zone_path = "../TestFeld/SpawnZones/Zone%d" % zone_id
		var zone = get_node(zone_path)
		zone_states[zone_id] = false
		spawned_objects[zone_id] = null
		zone.mouse_entered.connect(_on_zone_mouse_entered.bind(zone_id))
		zone.mouse_exited.connect(_on_zone_mouse_exited.bind(zone_id))
	
	remover.set_meta("is_remover", true)
	remover.remover_drag_started.connect(_on_remover_drag_started)
	remover.remover_drag_ended.connect(_on_remover_drag_ended)
	
	_on_retake_pressed()

func load_json_data(file_path: String, target_array: Array):
	var file = FileAccess.open(file_path, FileAccess.ModeFlags.READ)
	if file == null:
		print("Не удалось открыть файл:", file_path)
		return

	var json_data = file.get_as_text()
	file.close()

	var json_parser = JSON.new()

	var result = json_parser.parse(json_data)
	if result != OK:
		print("Ошибка парсинга JSON:", json_parser.error_string())
		return

	for item in json_parser.get_data():
		target_array.append({
			"id": item.get("id"),
			"scene": item.get("path"),
			"value": item.get("value") 
		})

func reload_cards_data():
	card_scenes.clear() 
	load_json_data("user://run_cards_data.json", card_scenes) 

func get_preview_scene_by_id(card_id: int) -> PackedScene:
	for preview_data in preview_scenes:
		if preview_data["id"] == card_id:
			return load(preview_data["scene"])
	return null

func _on_retake_pressed():
	# Удаляем все карты, если они есть
	for card in cards:
		card.queue_free()
	cards.clear()
	card_count = 0

	# Заполняем руку случайными картами
	while card_count < max_card_count:
		if card_scenes.size() == 0:
			print("card_scenes array is empty.")
			return
		
		var random_index = randi() % card_scenes.size()
		var card_data = card_scenes[random_index]
		var card = create_card(unique_card_id, card_data["id"], card_data["scene"], card_data["value"])
		unique_card_id += 1
		cards.append(card)
		add_child(card)
		card_count += 1
		adjust_cards_positions()

func create_card(unique_id: int, card_id: int, scene_path: String, card_value: int) -> Node2D:
	var card_scene = load(scene_path)
	if not card_scene:
		return null
	
	var card = card_scene.instantiate()
	card.set_meta("card_data", { "id": card_id, "type": scene_path, "value": card_value })
	card.set_meta("unique_id", unique_id)
	card.card_drag_started.connect(_on_card_drag_started.bind(unique_id))
	card.card_drag_ended.connect(_on_card_drag_ended.bind(unique_id))
	return card

func adjust_cards_positions(exclude_id: int = -1):
	if card_count == 0:
		return
	var card_instance = cards[0].duplicate()
	var card_width = card_instance.get_child(0).get_rect().size.x
	var total_width = (card_count - (1 if exclude_id >= 0 else 0)) * card_width + (card_count - 1) * card_spacing
	var offset = -total_width / 2
	var position_index = 0
	for card in cards:
		var card_unique_id = card.get_meta("unique_id")
		if card_unique_id == exclude_id:
			continue
		var target_position = Vector2(offset + position_index * (card_width + card_spacing), 0)
		var tween = create_tween()
		tween.tween_property(card, "position", target_position, 0.1)
		position_index += 1

func update_saved_positions():
	card_positions.clear()
	for card in cards:
		card_positions[card.get_meta("unique_id")] = card.position

func _on_card_drag_started(unique_id: int):
	dragging_card_unique_id = unique_id
	update_saved_positions()
	
	var card_to_drag = get_card_by_unique_id(unique_id)
	if card_to_drag:
		# Устанавливаем прозрачность карты
		card_to_drag.modulate.a = 0.3
		var card_size = card_to_drag.get_child(0).get_rect().size
		var center_offset = card_to_drag.position + card_size / 2
		card_to_drag.scale = Vector2(0.85, 0.85)
		card_to_drag.position = center_offset - card_size * 0.65 / 2
	
	adjust_cards_positions(unique_id)

func _on_card_drag_ended(unique_id: int) -> void:
	if unique_id != dragging_card_unique_id:
		return
	
	var card_to_drag = get_card_by_unique_id(unique_id)
	if card_to_drag:
		# Возвращаем непрозрачность карты
		card_to_drag.modulate.a = 1.0
		card_to_drag.scale = Vector2(1, 1)
	
	var should_remove_card = false
	
	if active_zones.size() == 1:
		var zone_id = active_zones[0]
		if spawned_objects[zone_id] == null:  
			var card_data = card_to_drag.get_meta("card_data")
			var card_value = card_data["value"] 
			var current_energy = energy_bar.value 

			if current_energy >= card_value:
				var obj_scene = get_object_scene_by_id(card_data["id"])
				if obj_scene:
					var obj = obj_scene.instantiate()
					var zone_path = "../TestFeld/SpawnZones/Zone%d" % zone_id
					var zone_node = get_node(zone_path)
					var spawn_marker = zone_node.get_node("spawn_marker")
					zone_node.add_child(obj)
					obj.position = spawn_marker.position
					should_remove_card = true
					spawned_objects[zone_id] = obj
					card_dropped.emit(card_value)
			else:
				no_energy_label.animate_label(no_energy_label)
				print("Недостаточно энергии для спавна карты!")
		else:
			print("В зоне %d уже находится объект, спавн невозможен." % zone_id)
	
	if should_remove_card:
		card_to_drag.queue_free()  
		card_count -= 1
		cards.erase(card_to_drag)
		update_saved_positions()
	else:
		adjust_cards_positions()
	
	# Удаляем все превью
	for zone_id in preview_objects:
		preview_objects[zone_id].queue_free()
	preview_objects.clear()
	
	adjust_cards_positions()
	dragging_card_unique_id = -1

func get_card_by_unique_id(unique_id: int) -> Node2D:
	for card in cards:
		if card.get_meta("unique_id") == unique_id:
			return card
	return null

func get_object_scene_by_id(card_id: int) -> PackedScene:
	for obj_data in obj_scenes:
		if obj_data["id"] == card_id:
			return load(obj_data["scene"])
	return null

func _on_zone_mouse_entered(zone_id: int) -> void:
	if remover_dragging:
		if not active_zones_remover.has(zone_id):
			active_zones_remover.append(zone_id)
		return

	if not active_zones.has(zone_id):
		active_zones.append(zone_id)
	
	# Создаем превью объекта при перетаскивании карты
	if dragging_card_unique_id != -1:
		var card = get_card_by_unique_id(dragging_card_unique_id)
		if card:
			var card_data = card.get_meta("card_data")
			var preview_scene = get_preview_scene_by_id(card_data["id"])
			if preview_scene:
				# Удаляем старое превью, если есть
				if preview_objects.has(zone_id):
					preview_objects[zone_id].queue_free()
				# Создаем новое превью
				var preview = preview_scene.instantiate()
				preview.modulate.a = 0.6  # Устанавливаем полупрозрачность
				var zone_node = get_node("../TestFeld/SpawnZones/Zone%d" % zone_id)
				var spawn_marker = zone_node.get_node("spawn_marker")
				zone_node.add_child(preview)
				preview.position = spawn_marker.position
				preview_objects[zone_id] = preview

	if active_zones.size() == 1:
		for other_zone_id in active_zones:
			var texture_rect = get_node("../TestFeld/SpawnZones/Zone%d/TextureRect" % other_zone_id)
			texture_rect.visible = other_zone_id == zone_id
			if preview_objects.has(other_zone_id):
				preview_objects[other_zone_id].visible = other_zone_id == zone_id
	else:
		_hide_all_zones()

func _on_zone_mouse_exited(zone_id: int) -> void:
	if remover_dragging:
		if active_zones_remover.has(zone_id):
			active_zones_remover.erase(zone_id)
		return

	if active_zones.has(zone_id):
		active_zones.erase(zone_id)
	
	# Удаляем превью при выходе из зоны
	if preview_objects.has(zone_id):
		preview_objects[zone_id].queue_free()
		preview_objects.erase(zone_id)
	
	if active_zones.size() == 1:
		var remaining_zone_id = active_zones[0]
		var texture_rect = get_node("../TestFeld/SpawnZones/Zone%d/TextureRect" % remaining_zone_id)
		texture_rect.visible = true
		if preview_objects.has(remaining_zone_id):
			preview_objects[remaining_zone_id].visible = true
	elif active_zones.size() == 0:
		_hide_all_zones()

func _hide_all_zones() -> void:
	for other_zone_id in zone_states.keys():
		var texture_rect = get_node("../TestFeld/SpawnZones/Zone%d/TextureRect" % other_zone_id)
		texture_rect.visible = false
		if preview_objects.has(other_zone_id):
			preview_objects[other_zone_id].visible = false

func _on_remover_drag_started():
	remover_dragging = true
	active_zones_remover.clear()

func _on_remover_drag_ended():
	remover_dragging = false
	if active_zones_remover.size() == 1:
		var zone_id = active_zones_remover[0]
		if spawned_objects[zone_id] != null:
			spawned_objects[zone_id].queue_free()
			spawned_objects[zone_id] = null
			print("Объект в зоне %d удален" % zone_id)
	active_zones_remover.clear()
