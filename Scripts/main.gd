extends Node2D

@export var spawnpoints: Array[NodePath]
@export var wave_curves: Array[Curve]
@export var energy: float = 0.0
@export var energy_rate: float = 1.0
@export var health: float = 4.0
@export var health_icons: Array[NodePath]
@export var wave_display: WaveCurveDisplay
@export var max_events_per_wave: int = 1
@export var extra_spawn_chance: float = 0.3
@export var min_event_delay: float = 80.0
@export var max_event_delay: float = 30.0
@export var coins_int: int = 0

@onready var energy_bar = $CanvasLayer/ProgressBar
@onready var energy_label = $CanvasLayer/ProgressBar/Label
@onready var hand = $Hand
@onready var event_label = $Left_Tab/Event
@onready var wave_label = $Left_Tab/Wave
@onready var wave_bar = $Left_Tab/Wave/WaveBar
@onready var shop = $Shop
@onready var card_pile = $CanvasLayer/Retake/Cards
@onready var countdown = $CanvasLayer/Countdown
@onready var coin_count = $Left_Tab/Coin_Label
@onready var mod_zone = $CanvasLayer/ModZone

var enemies_data: Dictionary
var banned_enemies: Array = []
var wave_settings: Dictionary
var enemy_scenes: Dictionary = {}
var current_wave: int = 0
var is_resting: bool = false
var wave_timer: Timer
var spawn_timer: Timer
var spawn_weights: Dictionary
var first_spawn: bool = true
var active_events: Dictionary = {}
var dead_enemies: Array = []
var active_enemies: int = 0
var connected_coins = []
enum EventType { CENTRAL_LANES, SINGLE_TYPE, RESURRECT }
const EVENT_PROBABILITY = 0.6
const RESURRECT_TIME_WINDOW = 10.0
const EVENT_DURATIONS = {
	EventType.CENTRAL_LANES: 30.0,
	EventType.SINGLE_TYPE: 35.0,
	EventType.RESURRECT: 20.0
}
var event_timer: Timer
var available_events: Array

signal wave_cleared(wave_number)

func _ready() -> void:
	load_enemies_data()
	if spawnpoints.size() != 10:
		print("Количество спавнпоинтов должно быть 10!")
		return
	init_wave_timers()
	energy_bar.max_value = 10.0
	energy_bar.min_value = 0.0
	energy_bar.value = energy
	hand.card_dropped.connect(update_bar)
	await get_tree().create_timer(3.0).timeout
	start_next_wave() 

func load_enemies_data():
	var file = FileAccess.open("res://Other/enemies_data.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		enemies_data = data.enemies
		wave_settings = data.wave_settings
		preload_enemy_scenes()
	else:
		print("Ошибка загрузки файла enemies_data.json")

func preload_enemy_scenes():
	for enemy_id in enemies_data:
		var scene_path = enemies_data[enemy_id].scene_path
		enemy_scenes[enemy_id] = load(scene_path)

func init_wave_timers():
	wave_timer = Timer.new()
	wave_timer.one_shot = true
	add_child(wave_timer)
	wave_timer.connect("timeout", _on_wave_finished)
	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.connect("timeout", _on_spawn_timeout)
	event_timer = Timer.new()
	event_timer.one_shot = false
	add_child(event_timer)
	event_timer.connect("timeout", _on_event_timer_timeout)

func start_next_wave():
	current_wave += 1
	is_resting = false
	first_spawn = true
	active_events.clear()
	dead_enemies.clear()
	available_events = EventType.values().duplicate()

	var curve_index = (current_wave - 1) % wave_curves.size()
	if current_wave == 1:  
		curve_index = 2  
	elif curve_index >= wave_curves.size():
		curve_index = wave_curves.size() - 1

	if wave_display:
		wave_display.setup(wave_curves[curve_index])
	print("Начало волны ", current_wave)
	wave_label.text = "Wave " + str(current_wave)
	wave_bar.max_value = wave_settings.wave_duration
	wave_bar.value = 0
	wave_timer.start(wave_settings.wave_duration)
	start_next_event_timer()
	update_spawn_weights(0.0)
	_on_spawn_timeout()

func start_next_event_timer():
	if current_wave <= 2:  
		return
	var delay = randf_range(min_event_delay, max_event_delay)
	event_timer.start(delay)

func _on_event_timer_timeout():
	if is_resting or current_wave <= 2: 
		return
	if active_events.size() >= max_events_per_wave:
		return
	var selected_event = available_events[randi() % available_events.size()]
	activate_event(selected_event)
	available_events.erase(selected_event)
	if active_events.size() >= max_events_per_wave:
		event_timer.stop()

func activate_event(event_type: EventType):
	if current_wave <= 2: 
		return
	match event_type:
		EventType.CENTRAL_LANES:
			active_events["central_lanes"] = true
			event_label.text = "Only central lanes"
			start_event_timer(event_type)
		EventType.SINGLE_TYPE:
			var enemy_types = enemies_data.keys().filter(func(key): return key != "basic")
			if enemy_types.size() > 0:
				var selected_type = enemy_types[randi() % enemy_types.size()]
				active_events["single_type"] = {
					"type": selected_type,
					"original_weights": spawn_weights.duplicate()
				}
				event_label.text = "Only " + selected_type
				start_event_timer(event_type)
		EventType.RESURRECT:
			active_events["resurrect"] = true
			event_label.text = "Resurrecting enemies"
			start_event_timer(event_type)

func start_event_timer(event_type: EventType):
	if current_wave <= 2:  
		return
	var timer = Timer.new()
	timer.wait_time = EVENT_DURATIONS[event_type]
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_on_event_timeout.bind(event_type))
	timer.start()

func _on_event_timeout(event_type: EventType):
	match event_type:
		EventType.CENTRAL_LANES:
			active_events.erase("central_lanes")
			event_label.text = ""
		EventType.SINGLE_TYPE:
			if active_events.has("single_type"):
				var original_weights = active_events["single_type"]["original_weights"]
				for key in original_weights:
					spawn_weights[key] = original_weights[key]
				active_events.erase("single_type")
			event_label.text = ""
		EventType.RESURRECT:
			active_events.erase("resurrect")
			event_label.text = ""

func update_spawn_interval():
	var curve_index = (current_wave - 1) % wave_curves.size()
	var current_curve = wave_curves[curve_index]
	var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
	var intensity = current_curve.sample(wave_progress)
	var min_interval = 0.5
	var max_interval = 10.0
	spawn_timer.wait_time = lerp(max_interval, min_interval, intensity)
	spawn_timer.start()

func _on_spawn_timeout():
	if is_resting:
		return
	if active_events.has("resurrect"):
		resurrect_enemies()
	if first_spawn:
		spawn_enemy(enemy_scenes["basic"], "basic")
		first_spawn = false
	else:
		var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
		var intensity = wave_curves[(current_wave - 1) % wave_curves.size()].sample(wave_progress)
		var base_spawn_count = wave_settings.base_spawn_count

		if current_wave == 1:
			base_spawn_count = 1 
			intensity *= 0.2  

		var wave_multiplier = 1.0 + (current_wave - 1) * 0.5  
		var spawn_count = base_spawn_count * (1 + intensity * 3) * wave_multiplier

		if active_events.has("single_type") && randf() < extra_spawn_chance:
			spawn_count += 1
		for i in range(spawn_count):
			var selected_enemy_id = get_weighted_random_enemy_id()
			spawn_enemy(enemy_scenes[selected_enemy_id], selected_enemy_id)
	update_spawn_interval()

func update_spawn_weights(wave_progress: float):
	spawn_weights = {}
	for enemy_id in enemies_data:
		var enemy = enemies_data[enemy_id]
		if current_wave >= enemy.first_wave: 
			var difficulty = 1.0 + (wave_progress * enemy.difficulty_multiplier)
			spawn_weights[enemy_id] = enemy.base_spawn_weight * difficulty

func ban_enemy(enemy_id: String) -> void:
	if enemy_id != "":
		if not banned_enemies.has(enemy_id):
			banned_enemies.append(enemy_id)
			print("Враг с ID ", enemy_id, " запрещен для спавна.")
	else:
		print("Передан пустой ID, ничего не удаляется.")

func unban_enemy(enemy_id: String) -> void:
	if enemy_id != "":
		if banned_enemies.has(enemy_id):
			banned_enemies.erase(enemy_id)  
			print("Враг с ID ", enemy_id, " снова разрешен для спавна.")
		else:
			print("Враг с ID ", enemy_id, " не был запрещен.")
	else:
		print("Передан пустой ID, ничего не изменяется.")

func get_weighted_random_enemy_id() -> String:
	if active_events.has("single_type"):
		return active_events["single_type"]["type"]
	
	var total_weight = 0.0
	var valid_enemies = {}
	
	for enemy_id in spawn_weights:
		var enemy_data = enemies_data[enemy_id]
		if current_wave >= enemy_data.first_wave and not banned_enemies.has(enemy_id):  # Исключаем запрещенных врагов
			valid_enemies[enemy_id] = spawn_weights[enemy_id]
			total_weight += spawn_weights[enemy_id]
	
	if valid_enemies.is_empty():
		return "basic"

	var random = randf_range(0, total_weight)
	var current = 0.0
	for enemy_id in valid_enemies:
		current += valid_enemies[enemy_id]
		if random < current:
			return enemy_id
	return valid_enemies.keys()[0]

func spawn_enemy(enemy_scene: PackedScene, enemy_id: String):
	var valid_spawnpoints = get_valid_spawnpoints()
	if valid_spawnpoints.size() == 0:
		return
	var spawnpoint_path = valid_spawnpoints[randi() % valid_spawnpoints.size()]
	var spawnpoint = get_node_or_null(spawnpoint_path)
	if spawnpoint and spawnpoint is Node2D:
		var enemy_instance = enemy_scene.instantiate()
		enemy_instance.enemy_type = enemy_id

		enemy_instance.connect("died", _on_enemy_died.bind(enemy_instance))
		add_child(enemy_instance)
		enemy_instance.position = spawnpoint.global_position
		active_enemies += 1

func get_valid_spawnpoints():
	if active_events.has("central_lanes"):
		return spawnpoints.slice(4, 6)
	return spawnpoints

func _on_enemy_died(enemy):
	active_enemies -= 1
	dead_enemies.append({
		"position": enemy.position,
		"type": enemy.enemy_type,
		"death_time": Time.get_unix_time_from_system()
	})
	await get_tree().create_timer(RESURRECT_TIME_WINDOW + 1.0).timeout
	dead_enemies = dead_enemies.filter(func(e):
		return Time.get_unix_time_from_system() - e.death_time <= RESURRECT_TIME_WINDOW
	)

func resurrect_enemies():
	var now = Time.get_unix_time_from_system()
	var resurrected = 0
	for enemy_data in dead_enemies:
		if now - enemy_data.death_time > RESURRECT_TIME_WINDOW:
			continue
		if enemy_data.type in enemy_scenes:
			var enemy_scene = enemy_scenes[enemy_data.type]
			var enemy_instance = enemy_scene.instantiate()
			enemy_instance.enemy_type = enemy_data.type
			add_child(enemy_instance)
			enemy_instance.position = enemy_data.position
			apply_resurrect_effect(enemy_instance)
			resurrected += 1
	if resurrected > 0:
		print("Воскрешено врагов: ", resurrected)

func apply_resurrect_effect(enemy_instance):
	enemy_instance.modulate = Color(0.5, 0.5, 0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(enemy_instance, "modulate", Color(1, 1, 1, 1), 1.0)

func _on_wave_finished():
	is_resting = true
	coin_count.text = str(coins_int)
	print("Волна ", current_wave, " завершена. Отдых...")
	spawn_timer.stop()
	event_timer.stop()
	await _wait_for_all_enemies_defeated()
	$Shop.visible = true
	get_tree().paused = true
	emit_signal("wave_cleared", current_wave)
	shop.shop_visible.connect(toggle_pause)

func _wait_for_all_enemies_defeated():
	while active_enemies > 0:
		await get_tree().create_timer(0.5).timeout

func _process(delta: float) -> void:
	coin_update()
	mod_update()
	if health <= 0:
		$CanvasLayer/Death.visible = true
		get_tree().paused = true
	var generators = get_tree().get_nodes_in_group("generator")
	for generator in generators:
		call_deferred("_connect_generator_signal", generator)
	energy = clamp(energy + energy_rate * delta, 0.0, 10.0)
	energy_bar.value = energy
	energy_label.text = str(int(energy))
	if not is_resting:
		var wave_progress = 1.0 - (wave_timer.time_left / wave_settings.wave_duration)
		wave_bar.value = wave_settings.wave_duration - wave_timer.time_left
		if wave_display:
			wave_display.update_progress(wave_progress)

func toggle_pause():
	var tree = get_tree()
	if tree:
		tree.paused = not tree.paused
		await get_tree().create_timer(wave_settings.rest_time).timeout
		start_next_wave()

func _connect_generator_signal(generator):
	if not generator.energy_plus.is_connected(energy_plus):
		generator.energy_plus.connect(energy_plus)

func update_bar(value):
	energy -= value
	energy_bar.value -= value

func energy_plus():
	energy += 1.0

func _on_retake_pressed() -> void:
	energy -= 1.0

func _on_lose_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		health -= 1.0
		if health < 0:
			health = 0
		if health_icons.size() > 0:
			var heart_to_remove = health_icons.pop_back()
			var heart_node = get_node_or_null(heart_to_remove)
			if heart_node:
				heart_node.queue_free()
		active_enemies -= 1
		if active_enemies <= 0 and not is_resting:
			_on_wave_finished()

func coin_update():
	var coins = get_tree().get_nodes_in_group("coins")
	for coin in coins:
		if not coin in connected_coins: 
			coin.add_coin.connect(on_coin_collected)
			connected_coins.append(coin) 
	coin_count.text = str(coins_int)

func on_coin_collected(coin_instance):
	if coin_instance in connected_coins:
		coins_int += 1
		coin_count.text = str(coins_int)
		coin_instance.remove_from_group("coins")
		coin_instance.add_coin.disconnect(on_coin_collected)
		connected_coins.erase(coin_instance)

func mod_update():
	for mod in get_tree().get_nodes_in_group("mods"):
		if not mod.mod_purchased.is_connected(_on_mod_purchased):
			mod.mod_purchased.connect(_on_mod_purchased)

func _on_mod_purchased(modifier_id: int):
	mod_zone.add_modifier(modifier_id)
	coin_update()
