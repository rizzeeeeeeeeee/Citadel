extends Node2D
 
signal energy_plus

@onready var local_enegy_bar = $ProgressBar
var local_energy: float = 0.0
var local_energy_rate: float = 5.0
var hp : float = 50.0

func _process(delta: float) -> void:
	local_energy = clamp(local_energy + local_energy_rate * delta, 0.0, 100.0)
	local_enegy_bar.value = local_energy
	energy_update()

func energy_update():
	if local_energy >= 100:
		energy_plus.emit()
		local_energy = 0

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		await get_tree().create_timer(0.2).timeout
		body.get_parent().attack(self)  # Вызываем метод атаки у врага

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("enemy") or body.is_in_group("invisible_enemy"):
		body.get_parent().stop_attack(self)  # Вызываем метод атаки у врага

func take_damage(amount: float) -> void:
	if hp <= 0:
		return  # Если пушка уже уничтожена, ничего не делаем

	hp -= amount
	if hp <= 0:
		destroy()

func destroy() -> void:
	if is_instance_valid(self):  # Проверяем, что объект всё ещё существует
		queue_free()
