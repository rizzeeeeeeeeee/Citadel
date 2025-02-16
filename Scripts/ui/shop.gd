extends Node2D

@onready var card_pack = $"Card Pack"
signal shop_visible

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Подключаем сигнал, который будет срабатывать при исчезновении card_pack
	card_pack.tree_exited.connect(_on_card_pack_exited)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Функция, которая вызывается, когда card_pack исчезает
func _on_card_pack_exited():
	# Создаем новый экземпляр card_pack
	self.visible = false
	shop_visible.emit()
	var new_card_pack = load("res://Scenes/UI/cards_pack.tscn").instantiate()
	call_deferred("add_child", new_card_pack) 
	# Подключаем сигнал для нового экземпляра
	new_card_pack.tree_exited.connect(_on_card_pack_exited)
	# Обновляем ссылку на card_pack
	card_pack = new_card_pack
