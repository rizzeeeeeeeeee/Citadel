extends Node2D
 
@onready var local_enegy_bar = $ProgressBar
var local_energy: float = 0.0
var local_energy_rate: float = 10.0
signal energy_plus

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	local_energy = clamp(local_energy + local_energy_rate * delta, 0.0, 100.0)
	local_enegy_bar.value = local_energy
	energy_update()

func energy_update():
	if local_energy >= 100:
		energy_plus.emit()
		local_energy = 0

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		self.queue_free()
