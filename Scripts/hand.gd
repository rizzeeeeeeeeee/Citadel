extends Node2D

@export var card_scenes: Array = [
	{ "id": 1, "scene": "res://Scenes/normal_card.tscn" },
	{ "id": 2, "scene": "res://Scenes/rare_card.tscn" }
]

@export var obj_scenes: Array = [
	{ "id": 1, "scene": "res://Scenes/normal_object.tscn"},
	{ "id": 2, "scene": "res://Scenes/rare_object.tscn"}
]

var card_count: int = 0
var max_card_count: int = 5
var card_spacing: float = 5.0
var cards: Array = []
var saved_positions: Array = []
var dragging_card_unique_id: int = -1
var current_card_index: int = 0
var unique_card_id: int = 1

var zone_states: Dictionary = {}
var spawned_objects: Dictionary = {}

func _ready() -> void:
	for zone_id in range(1, 11):
		var zone_path = "../TestFeld/SpawnZones/Zone%d" % zone_id
		var zone = get_node(zone_path)
		zone_states[zone_id] = false
		spawned_objects[zone_id] = null
		zone.area_entered.connect(_on_zone_area_entered.bind(zone_id))
		zone.area_exited.connect(_on_zone_area_exited.bind(zone_id))

func _on_add_card_pressed():
	if card_count < max_card_count:
		var card_data = card_scenes[current_card_index]
		var card = create_card(unique_card_id, card_data["id"], card_data["scene"])
		unique_card_id += 1
		cards.append(card)
		add_child(card)
		card_count += 1
		current_card_index = (current_card_index + 1) % card_scenes.size()
		adjust_cards_positions()

func _on_delete_card_pressed():
	if card_count > 0:
		card_count -= 1
		var card = cards.pop_back()
		card.queue_free()
		adjust_cards_positions()
		update_saved_positions()

func create_card(unique_id: int, card_id: int, scene_path: String) -> Node2D:
	var card_scene = load(scene_path)
	if not card_scene:
		return null
	
	var card = card_scene.instantiate()
	card.set_meta("card_data", { "id": card_id, "type": scene_path })
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
		card.position = Vector2(offset + position_index * (card_width + card_spacing), 0)
		position_index += 1

func _on_card_drag_started(unique_id: int):
	dragging_card_unique_id = unique_id
	update_saved_positions()
	
	var card_to_drag = get_card_by_unique_id(unique_id)
	if card_to_drag:
		var card_size = card_to_drag.get_child(0).get_rect().size
		var center_offset = card_to_drag.position + card_size / 2
		card_to_drag.scale = Vector2(0.65, 0.65)
		card_to_drag.position = center_offset - card_size * 0.65 / 2

	adjust_cards_positions(unique_id)

func _on_card_drag_ended(unique_id: int) -> void:
	if unique_id != dragging_card_unique_id:
		return
	
	var card_to_drag = get_card_by_unique_id(unique_id)
	if card_to_drag:
		card_to_drag.scale = Vector2(1, 1)
		var card_size = card_to_drag.get_child(0).get_rect().size
		card_to_drag.position = card_to_drag.position + card_size / 2 - card_size / 2

	for zone_id in zone_states.keys():
		if zone_states[zone_id]:
			if spawned_objects[zone_id] == null:
				var card_data = card_to_drag.get_meta("card_data")
				var obj_scene = get_object_scene_by_id(card_data["id"])
				if obj_scene:
					var obj = obj_scene.instantiate()
					var zone_path = "../TestFeld/SpawnZones/Zone%d" % zone_id
					var zone_node = get_node(zone_path)
					var spawn_marker = zone_node.get_node("spawn_marker")
					zone_node.add_child(obj)
					obj.position = spawn_marker.position
					card_to_drag.queue_free()
					card_count -= 1
					cards.erase(card_to_drag)
					update_saved_positions()
					spawned_objects[zone_id] = obj
			else:
				return

	for i in range(card_count):
		if i < saved_positions.size():
			cards[i].position = saved_positions[i]
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

func update_saved_positions():
	saved_positions.clear()
	for card in cards:
		saved_positions.append(card.position)

func _on_zone_area_entered(area: Area2D, zone_id: int) -> void:
	zone_states[zone_id] = true
	var texture_rect = get_node("../TestFeld/SpawnZones/Zone%d/TextureRect" % zone_id)
	texture_rect.visible = true

func _on_zone_area_exited(area: Area2D, zone_id: int) -> void:
	zone_states[zone_id] = false
	var texture_rect = get_node("../TestFeld/SpawnZones/Zone%d/TextureRect" % zone_id)
	texture_rect.visible = false
