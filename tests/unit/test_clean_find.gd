extends GutTest

## Issue #78: Testes para Achado Limpo (Clean Find)
## Item desenterrado sem quebrar (100% integridade) e sem o jogador levar dano
## recebe a marca 'limpo' (is_clean = true) e bónus de 20% no SellPoint / Museu.

const MOEDA: ItemData = preload("res://items/catalog/moeda_antiga.tres")
const LATA: ItemData = preload("res://items/catalog/lata_enferrujada.tres")
const REPELENTE: ToolData = preload("res://items/tools/repelente.tres")


class MockPlayer extends Node3D:
	signal health_changed(current: float, max_value: float)
	signal died
	var health: float = 100.0
	var max_health: float = 100.0

	func take_damage(amount: float) -> void:
		health = clampf(health - amount, 0.0, max_health)
		health_changed.emit(health, max_health)
		if health <= 0.0:
			died.emit()


var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func test_carried_item_clean_properties_and_serialization() -> void:
	var item_normal: CarriedItem = CarriedItem.create(MOEDA, 100, 1.0, false)
	assert_false(item_normal.is_clean, "Default de is_clean deve ser false")
	assert_eq(item_normal.get_display_name(), MOEDA.display_name)

	var item_clean: CarriedItem = CarriedItem.create(MOEDA, 100, 1.0, false, true)
	assert_true(item_clean.is_clean, "is_clean deve ser true quando passado no create")
	assert_string_contains(item_clean.get_display_name(), "✨", "Achado limpo deve ter indicador visual")

	# Serialização to_dict
	var dict_clean: Dictionary = item_clean.to_dict()
	assert_true(dict_clean.has("clean"), "to_dict deve conter a chave 'clean'")
	assert_true(dict_clean["clean"], "to_dict deve ter clean = true")

	# Deserialização from_dict
	var restored: CarriedItem = CarriedItem.from_dict(dict_clean)
	assert_not_null(restored)
	assert_true(restored.is_clean, "from_dict deve restaurar is_clean = true")
	assert_eq(restored.final_value, 100)

	# Compatibilidade com dicionário antigo sem chave 'clean'
	var dict_legacy: Dictionary = dict_clean.duplicate()
	dict_legacy.erase("clean")
	var restored_legacy: CarriedItem = CarriedItem.from_dict(dict_legacy)
	assert_not_null(restored_legacy)
	assert_false(restored_legacy.is_clean, "from_dict sem chave 'clean' deve ter is_clean = false")


func test_buried_spot_clean_find_when_perfect_and_undamaged() -> void:
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = MOEDA
	spot.dirt_layers = 2
	spot.integrity = 1.0
	_root.add_child(spot)

	var player: MockPlayer = MockPlayer.new()
	_root.add_child(player)

	# 1.ª pazada cuidadosa
	var res1: Dictionary = spot.dig(true, 1.0, false, player)
	assert_false(res1["revealed"])
	assert_eq(res1["dirt_layers"], 1)
	assert_almost_eq(res1["integrity"], 1.0, 0.001)

	# 2.ª pazada cuidadosa (revela o item)
	var res2: Dictionary = spot.dig(true, 1.0, false, player)
	assert_true(res2["revealed"])
	assert_true(res2["is_perfect"], "Integridade 100% é perfeita")
	assert_true(res2["is_clean"], "Sem quebrar e sem dano deve ser achado limpo")
	assert_true(spot.is_clean)


func test_buried_spot_not_clean_when_integrity_damaged() -> void:
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = MOEDA
	spot.dirt_layers = 1
	spot.integrity = 1.0
	_root.add_child(spot)

	var player: MockPlayer = MockPlayer.new()
	_root.add_child(player)

	# Pazada rápida danifica a integridade na última camada
	var res: Dictionary = spot.dig(false, 1.0, false, player)
	assert_true(res["revealed"])
	assert_true(res["damaged"])
	assert_lt(res["integrity"], 1.0)
	assert_false(res["is_clean"], "Item com integridade danificada não pode ser limpo")
	assert_false(spot.is_clean)


func test_buried_spot_not_clean_when_player_takes_damage_during_dig() -> void:
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = MOEDA
	spot.dirt_layers = 3
	spot.integrity = 1.0
	_root.add_child(spot)

	var player: MockPlayer = MockPlayer.new()
	_root.add_child(player)

	# 1.ª pazada cuidadosa
	spot.dig(true, 1.0, false, player)
	assert_false(spot.player_took_damage)

	# Jogador sofre dano de inimigo no meio da escavação!
	player.take_damage(15.0)
	assert_true(spot.player_took_damage, "BuriedSpot deve detectar o dano sofrido pelo jogador")

	# Continua a escavar com cuidado até ao fim
	spot.dig(true, 1.0, false, player)
	var res: Dictionary = spot.dig(true, 1.0, false, player)
	assert_true(res["revealed"])
	assert_almost_eq(res["integrity"], 1.0, 0.001, "Integridade manteve-se perfeita")
	assert_false(res["is_clean"], "Jogador levou dano, portanto não é achado limpo")
	assert_false(spot.is_clean)


func test_buried_spot_not_clean_when_player_dies() -> void:
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = MOEDA
	spot.dirt_layers = 2
	spot.integrity = 1.0
	_root.add_child(spot)

	var player: MockPlayer = MockPlayer.new()
	_root.add_child(player)

	spot.dig(true, 1.0, false, player)
	player.take_damage(100.0) # Mata o jogador

	var res: Dictionary = spot.dig(true, 1.0, false, player)
	assert_true(res["revealed"])
	assert_false(res["is_clean"], "Morte do jogador anula achado limpo")


func test_sell_point_clean_bonus_value() -> void:
	var item_normal: CarriedItem = CarriedItem.create(MOEDA, 100, 1.0, false, false)
	var item_clean: CarriedItem = CarriedItem.create(MOEDA, 100, 1.0, false, true)

	assert_eq(SellPoint.CLEAN_BONUS_MULTIPLIER, 1.2, "Bónus de achado limpo deve ser 20% (1.2x)")

	var val_normal: int = SellPoint.get_delivery_value(item_normal)
	assert_eq(val_normal, 100, "Item normal mantém o valor final")

	var val_clean: int = SellPoint.get_delivery_value(item_clean)
	assert_eq(val_clean, 120, "Item limpo deve receber +20% de bónus")


func test_sell_point_deliver_batch_with_clean_bonus() -> void:
	var sell_point: SellPoint = SellPoint.new()
	_root.add_child(sell_point)

	var item1: CarriedItem = CarriedItem.create(MOEDA, 100, 1.0, false, false) # 100
	var item2: CarriedItem = CarriedItem.create(MOEDA, 100, 1.0, false, true)  # 120 (limpo)
	var item3: CarriedItem = CarriedItem.create(LATA, 50, 1.0, false, true)    # 60 (50 * 1.2 = 60, limpo)
	var tool_rep: CarriedItem = CarriedItem.create_from_tool_data(REPELENTE)   # Ignorado (ferramenta)

	var batch: Array[CarriedItem] = [item1, item2, item3, tool_rep]

	watch_signals(sell_point)
	var total: int = sell_point.deliver(batch)

	assert_eq(total, 280, "Total deve ser 100 + 120 + 60 = 280")
	assert_signal_emitted_with_parameters(sell_point, "items_delivered", [3, 280])
