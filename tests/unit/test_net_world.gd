extends GutTest

## #23 Coop Fase 2 (contrato #5 D/E): spots e itens no chão em rede — partes testáveis
## sem rede (o fluxo com 2 peers é provado por tools/bot/run_coop.sh com coop2_*.json).

const PRAIA: MapData = preload("res://items/maps/praia.tres")
const MOEDA: ItemData = preload("res://items/catalog/moeda_antiga.tres")

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func test_dig_result_round_trips_item_by_id() -> void:
	var res: Dictionary = {"revealed": true, "item": MOEDA, "final_value": 150, "integrity": 1.0}
	var net: Dictionary = BuriedSpot.result_to_net(res)
	assert_eq(net["item"], "moeda_antiga", "pela rede vai so o id")
	var back: Dictionary = BuriedSpot.result_from_net(net)
	assert_eq(back["item"], MOEDA)
	assert_eq(back["final_value"], 150)
	assert_null(BuriedSpot.result_from_net({"item": "../tools/x"})["item"])
	assert_null(BuriedSpot.result_from_net({"item": ""})["item"])


func test_spot_spawner_builds_spot_from_host_data() -> void:
	var spawner: SpotSpawner = SpotSpawner.new()
	spawner.map_data = null  # sem map_data: não sorteia nada sozinho
	_root.add_child(spawner)
	var spot: BuriedSpot = spawner._create_spot({"n": 7, "item_id": "moeda_antiga", "rare": true, "pos": Vector3(1, 0, 2)})
	assert_eq(spot.name, &"Spot7")
	assert_true(spot.networked)
	assert_eq(spot.item, MOEDA)
	assert_true(spot.is_rare_variant)
	spawner.add_child(spot)
	assert_true(spot.is_rare_variant, "o cliente nao volta a sortear a raridade")
	assert_eq(spot.position, Vector3(1, 0, 2))
	assert_not_null(spot.get_node_or_null("NetSync"), "dirt_layers/integrity replicados")


func test_mound_follows_replicated_dirt_layers() -> void:
	var spot: BuriedSpot = preload("res://items/buried_spot.tscn").instantiate() as BuriedSpot
	spot.item = MOEDA
	_root.add_child(spot)
	var mound: Node3D = spot.get_node("DirtMound") as Node3D
	assert_false(mound.visible)
	spot.dirt_layers = 2  # como chega pelo NetSync num cliente
	assert_true(mound.visible, "o buraco aparece na 1.a camada")
	assert_gt(mound.scale.x, 1.0)


func test_host_dig_without_noise_flag() -> void:
	var spot: BuriedSpot = preload("res://items/buried_spot.tscn").instantiate() as BuriedSpot
	spot.item = MOEDA
	_root.add_child(spot)
	var res: Dictionary = spot.dig(true, 1.0, false)
	assert_eq(res["dirt_layers"], 2)
	assert_eq(spot.dirt_layers, 2)


func test_pickups_root_spawns_items_from_dicts() -> void:
	var root: PickupsRoot = PickupsRoot.new()
	_root.add_child(root)
	assert_eq(PickupsRoot.find(get_tree()), root)
	# Host (offline = host): drop cria o item já em rede, a partir do dicionário.
	var pickup: ItemPickup = root.drop(CarriedItem.create(MOEDA, 120, 0.9, false), Vector3(2, 1, 3))
	assert_not_null(pickup)
	assert_true(pickup.networked)
	assert_eq(pickup.get_parent(), root)
	assert_eq(pickup.carried.item, MOEDA)
	assert_eq(pickup.carried.final_value, 120)
	assert_not_null(pickup.get_node_or_null("NetSync"))
	# ItemPickup.spawn encontra o PickupsRoot sozinho, seja qual for o parent pedido.
	var other: ItemPickup = ItemPickup.spawn(_root, CarriedItem.create(MOEDA, 100, 1.0, false), Vector3.ZERO)
	assert_eq(other.get_parent(), root)
	# Apanhar no host: o item sai do mundo e volta inteiro.
	var c: CarriedItem = root.take(pickup)
	assert_eq(c.final_value, 120)
	assert_null(pickup.carried)


func test_pickups_root_rejects_forged_items() -> void:
	var root: PickupsRoot = PickupsRoot.new()
	_root.add_child(root)
	var forged: Node = root._create_pickup({"n": 1, "carried": {"kind": "item", "item_id": "moeda_antiga",
		"final_value": 999999, "integrity": 1.0, "rare": false}, "pos": Vector3.ZERO})
	assert_null((forged as ItemPickup).carried, "valor acima do teto nao vira item")
	forged.free()


func test_item_pickup_spawn_without_root_stays_local() -> void:
	var pickup: ItemPickup = ItemPickup.spawn(_root, CarriedItem.create(MOEDA, 50, 1.0, false), Vector3(0, 1, 0))
	assert_eq(pickup.get_parent(), _root)
	assert_false(pickup.networked)
