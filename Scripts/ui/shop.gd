extends Node2D

@onready var card_pack = $"Card Pack"
var pending_card_pack: Node2D = null  
signal shop_visible
signal shop_invisible
var mouse_in_buy_zone: bool = false

func _ready() -> void:
	card_pack.tree_exited.connect(_on_card_pack_exited)

func _process(delta: float) -> void:
	pass

func _on_card_pack_exited():
	pending_card_pack = load("res://Scenes/UI/cards_pack.tscn").instantiate()
	pending_card_pack.tree_exited.connect(_on_card_pack_exited)
	$MainShop.visible = true
	if not self.visible:
		call_deferred("add_child", pending_card_pack)
		card_pack = pending_card_pack
		pending_card_pack = null  

func spawn_default_card_pack():
	var pack = load("res://Scenes/UI/cards_pack.tscn").instantiate()
	call_deferred("add_child", pack)

func spawn_epic_card_pack():
	var pack = load("res://Scenes/UI/epic_pack.tscn").instantiate()
	call_deferred("add_child", pack)

func _on_button_pressed() -> void:
	self.visible = false
	$MainShop.visible = false

	shop_visible.emit()
	
	if pending_card_pack:
		call_deferred("add_child", pending_card_pack)
		card_pack = pending_card_pack
		pending_card_pack = null  

func _on_buy_zone_mouse_entered() -> void:
	mouse_in_buy_zone = true

func _on_buy_zone_mouse_exited() -> void:
	mouse_in_buy_zone = false

func _on_refresh_pressed() -> void:
	$MainShop/ModifierShop.display_random_modifiers()
	$MainShop/PackShop.display_random_packs()
