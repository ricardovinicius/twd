class_name SpellShop
extends Resource

## Stardust cost to unlock one spell.
@export_range(0, 100000, 1, "or_greater") var price: int = 100
## Spells whose sequence has at least this many tokens are sold in the shop
## and must be bought before they can be cast.
@export_range(1, 10, 1) var min_sequence_length: int = 2


func get_offers(registry: SpellRegistry) -> Array[SpellDefinition]:
	var offers: Array[SpellDefinition] = []

	if registry == null or registry.database == null:
		return offers

	for spell in registry.database.get_spells():
		if is_for_sale(spell):
			offers.append(spell)

	return offers


func is_for_sale(spell: SpellDefinition) -> bool:
	return spell != null and spell.sequence.size() >= min_sequence_length


func is_owned(registry: SpellRegistry, spell: SpellDefinition) -> bool:
	return registry != null and spell != null and registry.has_spell(spell.id)


func can_buy(registry: SpellRegistry, spell: SpellDefinition) -> bool:
	return (
		registry != null
		and is_for_sale(spell)
		and not is_owned(registry, spell)
		and registry.database != null
		and registry.database.has_spell(spell.id)
		and CoinManager.can_afford(price)
	)


func buy(registry: SpellRegistry, spell: SpellDefinition) -> bool:
	if not can_buy(registry, spell):
		return false

	if price > 0 and not CoinManager.spend_coins(price):
		return false

	if not registry.register_spell(spell.id):
		# Registration was validated above; refund if it still fails.
		CoinManager.add_coins(price)
		return false

	return true
