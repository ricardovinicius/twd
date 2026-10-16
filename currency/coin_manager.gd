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


func can_afford(amount: int) -> bool:
	return amount >= 0 and coins >= amount


func spend_coins(amount: int) -> bool:
	if amount <= 0 or not can_afford(amount):
		return false

	coins -= amount
	coins_changed.emit(coins)

	return true
