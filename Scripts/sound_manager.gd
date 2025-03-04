extends Node

const AUDIO_POOL_SIZE: int = 15 
const MAX_SIMULTANEOUS_SOUNDS: int = 10  
var audio_pool: Array[AudioStreamPlayer] = []

var take_cards_sounds = preload("res://Sounds/Cards/card_take.ogg")
var ready_cards_sounds = preload("res://Sounds/Cards/card_ready.ogg")

var placement_sound = preload("res://Sounds/Objects/object_placement.mp3")

var hit_sounds: Array[AudioStream] = [
	preload("res://Sounds/Robot Damage/hit_1.mp3"),
	preload("res://Sounds/Robot Damage/hit_2.mp3"),
	preload("res://Sounds/Robot Damage/hit_3.mp3")
]

var gun_sounds: Array[AudioStream] = [
	preload("res://Sounds/Objects/Single Gun/gun_shoot_1.mp3"),
	preload("res://Sounds/Objects/Single Gun/gun_shoot_2.mp3"),
	preload("res://Sounds/Objects/Single Gun/gun_shoot_3.mp3")
]

var gatling_sound = preload("res://Sounds/Objects/Gatling/gatling_shoot.mp3")

var grenade_sound = preload("res://Sounds/Objects/Grenade/greanade_epxl.mp3")

var railgun_sound = preload("res://Sounds/Objects/Railgun/railgun_shoot.mp3")

var sound_cooldown: float = 0.03 
var last_sound_time: float = 0.0

func _ready():
	for i in range(AUDIO_POOL_SIZE):
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_pool.append(audio_player)

func play_placement_sound():
	play_sound(placement_sound)

func play_grenade_sound():
	play_sound(grenade_sound)

func play_take_card_sound():
	play_sound(take_cards_sounds)

func play_ready_card_sound():
	play_sound(ready_cards_sounds)

func play_railgun_sound():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_sound_time < sound_cooldown:
		return 

	play_sound(railgun_sound)
	last_sound_time = current_time

func play_random_hit_sound():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_sound_time < sound_cooldown:
		return 

	var random_sound = hit_sounds[randi() % hit_sounds.size()]
	play_sound(random_sound)
	last_sound_time = current_time

func play_random_gun_sound():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_sound_time < sound_cooldown:
		return 

	var random_sound = gun_sounds[randi() % gun_sounds.size()]
	play_sound(random_sound)
	last_sound_time = current_time

func play_gatling_sound():
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_sound_time < sound_cooldown:
		return 

	play_sound(gatling_sound)
	last_sound_time = current_time

func play_sound(sound: AudioStream):
	var active_sounds = 0
	for player in audio_pool:
		if player.playing:
			active_sounds += 1

	if active_sounds >= MAX_SIMULTANEOUS_SOUNDS:
		return

	for player in audio_pool:
		if not player.playing:
			player.stream = sound
			player.play()
			return

	var oldest_player = audio_pool[0]
	oldest_player.stop()
	oldest_player.stream = sound
	oldest_player.play()
	audio_pool.append(audio_pool.pop_front())  
	
func set_volume(volume: float):
	for player in audio_pool:
		player.volume_db = linear_to_db(volume)
