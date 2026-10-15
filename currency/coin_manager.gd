extends Node

signal coins_changed(coins)

var coins := 0


func add_coin():
	coins += 1
	coins_changed.emit(coins)
