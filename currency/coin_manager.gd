extends Node

signal coins_changed(coins)

var coins := 0


func add_coin():
	add_coins(1)


func add_coins(amount: int) -> void:
	if amount <= 0:
		return

	coins += amount
	coins_changed.emit(coins)
