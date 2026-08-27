extends Label


func _ready():
	CoinManager.coins_changed.connect(_on_coins_changed)
	text = "Stardust: " + str(CoinManager.coins)


func _on_coins_changed(amount):
	text = "Stardust: " + str(amount)
