extends Control

signal countdown_finished

var countdown_label: Label
var countdown_timer: Timer
var scale_tween: Tween
var current_number = 3

func _ready():
	create_countdown_label()
	create_countdown_timer()
	start_countdown()

func create_countdown_label():
	# Создание и настройка Label
	countdown_label = Label.new()
	
	# Настройка шрифта
	var font = load("res://Fonts/MegamaxJonathanToo-YqOq2.ttf")  # Укажите путь к шрифту
	if font:
		countdown_label.add_theme_font_override("font", font)
		countdown_label.add_theme_font_size_override("font_size", 200)
	
	# Настройка обводки
	countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	countdown_label.add_theme_constant_override("outline_size", 30)
	
	# Центрирование текста
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Устанавливаем размер и позицию
	countdown_label.size = Vector2(400, 400)
	countdown_label.position = get_viewport_rect().size / 2 - countdown_label.size / 2
	
	# Устанавливаем точку привязки (pivot) в центр Label
	countdown_label.pivot_offset = countdown_label.size / 2
	
	add_child(countdown_label)

func create_countdown_timer():
	countdown_timer = Timer.new()
	countdown_timer.wait_time = 0.5
	countdown_timer.one_shot = false
	countdown_timer.timeout.connect(_on_countdown_timer_timeout)
	add_child(countdown_timer)

func start_countdown():
	countdown_label.visible = true
	update_countdown_text()
	countdown_timer.start()
	start_scale_animation()

func update_countdown_text():
	match current_number:
		3: countdown_label.text = "3"
		2: countdown_label.text = "2"
		1: countdown_label.text = "1"
		0: 
			countdown_label.text = "GO!"
			await get_tree().create_timer(0.5).timeout
			countdown_timer.stop()
			stop_scale_animation()

func start_scale_animation():
	scale_tween = create_tween().set_parallel(false)
	scale_tween.set_loops()
	scale_tween.tween_property(countdown_label, "scale", Vector2(1.3, 1.3), 0.25)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

func stop_scale_animation():
	if scale_tween:
		scale_tween.kill()
	var final_tween = create_tween()
	final_tween.tween_property(countdown_label, "scale", Vector2(3.5, 3.5), 0.2)
	final_tween.tween_callback(func(): 
		countdown_label.visible = false
		emit_signal("countdown_finished")
		queue_free()
	)

func _on_countdown_timer_timeout():
	current_number -= 1
	if current_number >= 0:
		update_countdown_text()
	else:
		stop_scale_animation()
