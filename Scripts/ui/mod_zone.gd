extends Control

var modifiers_data = []
var selected_modifiers = []
var modifier_spacing = 10 
var modifier_size = Vector2(64, 64)  

func _ready():
	load_modifiers()

func load_modifiers():
	var file = FileAccess.open("res://Other/modifiers_data.json", FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		file.close()

		var json = JSON.new()
		var json_result = json.parse(json_data)
		
		if json_result == OK:  
			modifiers_data = json.get_data()  
			print("Modifiers loaded successfully.")
		else:
			print("Failed to parse JSON: ", json.get_error_message())
	else:
		print("Failed to open JSON file.")

func add_modifier(modifier_id: int):
	# Проверяем, что модификатор уже не добавлен
	#for modifier in selected_modifiers:
	#	if modifier["id"] == str(modifier_id):
	#		print("Modifier already added:", modifier["name"])
	#		return

	if selected_modifiers.size() >= 3:
		print("Cannot add more than 3 modifiers.")
		return

	for modifier in modifiers_data:
		if modifier["id"] == str(modifier_id):
			if can_afford(int(modifier["value"])):
				selected_modifiers.append(modifier)
				apply_modifier_effects(modifier)
				instantiate_modifier_scene(modifier)  
				print("Modifier added: ", modifier["name"])
			else:
				print("Not enough coins to buy this modifier.")
			break

func instantiate_modifier_scene(modifier):
	if modifier.has("path"):
		var scene_path = modifier["path"]
		var modifier_scene = load(scene_path)
		if modifier_scene:
			var modifier_instance = modifier_scene.instantiate()
			add_child(modifier_instance)

			if modifier_instance.has_signal("mod_deleted"):
				modifier_instance.mod_deleted.connect(_on_modifier_deleted)
			
			modifier_instance.change_status()
			update_modifier_positions()
			print("Modifier scene instantiated: ", modifier["name"])
		else:
			print("Failed to load modifier scene: ", scene_path)
	else:
		print("Modifier does not have a scene path.")

func update_modifier_positions():
	for i in range(selected_modifiers.size()):
		var modifier_instance = get_child(i)  
		if modifier_instance:
			var x_position = i * (modifier_size.x + modifier_spacing)
			modifier_instance.position = Vector2(x_position, 0)

func apply_modifier_effects(modifier):
	if modifier.has("energy_multiplier"):
		var energy_multiplier = float(modifier["energy_multiplier"])
		var hand_capacity = float(modifier["hand_capacity"])
		var enemy_id = modifier["enemy_id"]
		var enegry_back_mod = int(modifier["enegry_back"])
		get_parent().get_parent().energy_rate *= energy_multiplier
		get_tree().get_first_node_in_group("hand").max_card_count += hand_capacity
		get_tree().get_first_node_in_group("hand").energy_back += enegry_back_mod
		get_parent().get_parent().ban_enemy(enemy_id)
	if modifier.has("value"):
		var cost = int(modifier["value"])
		get_parent().get_parent().coins_int -= cost
		print("Coins deducted: ", cost)

func remove_modifier(modifier_instance):
	for i in range(selected_modifiers.size()):
		var modifier = selected_modifiers[i]
		if modifier["id"] == str(modifier_instance.id):
			remove_modifier_effects(modifier)
			selected_modifiers.remove_at(i)
			update_modifier_positions()
			print("Modifier removed: ", modifier["name"])
			return
	print("Modifier not found: ", modifier_instance.id)

func remove_modifier_effects(modifier):
	if modifier.has("energy_multiplier"):
		var energy_multiplier = float(modifier["energy_multiplier"])
		var hand_capacity = float(modifier["hand_capacity"])
		var enemy_id = modifier["enemy_id"]
		var enegry_back_mod = int(modifier["enegry_back"])
		get_parent().get_parent().energy_rate /= energy_multiplier
		get_tree().get_first_node_in_group("hand").max_card_count -= hand_capacity
		get_tree().get_first_node_in_group("hand").energy_back -= enegry_back_mod
		get_parent().get_parent().unban_enemy(enemy_id)
		print("Energy multiplier removed: ", energy_multiplier)
	if modifier.has("value"):
		var cost = int(modifier["value"])
		get_parent().get_parent().coins_int += cost 
		get_parent().get_parent().coin_update()
		print("Coins refunded: ", cost)

func _on_modifier_deleted(modifier_instance):
	remove_modifier(modifier_instance)

func can_afford(cost: int) -> bool:
	return get_parent().get_parent().coins_int >= cost
