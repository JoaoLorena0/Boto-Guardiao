extends Node
class_name PollutionCore

signal pollution_changed(current: int, max_value: int)
signal ecosystem_destroyed

@export var max_pollution: int = 80

var pollution: int = 0

func add_pollution(amount: int) -> void:
	pollution = clampi(pollution + amount, 0, max_pollution)
	pollution_changed.emit(pollution, max_pollution)

	if pollution >= max_pollution:
		ecosystem_destroyed.emit()

func reduce_pollution(amount: int) -> void:
	pollution = clampi(pollution - amount, 0, max_pollution)
	pollution_changed.emit(pollution, max_pollution)
