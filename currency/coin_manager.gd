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


## Replaces the total, e.g. when loading a save or starting a new game.
func set_coins(amount: int) -> void:
	var new_total := maxi(amount, 0)

	if new_total == coins:
		return

	coins = new_total
	coins_changed.emit(coins)


func can_afford(amount: int) -> bool:
	return amount >= 0 and coins >= amount


func spend_coins(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false

	coins -= amount
	coins_changed.emit(coins)

	return true
