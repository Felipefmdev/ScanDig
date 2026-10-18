extends GutTest

## Testes unitários para Ladrões de Achados no Campo e Ninho de Corvo (#106).

const CROW_SCRIPT: Script = preload("res://gameplay/enemies/crow/crow.gd")
const CROW_NEST_SCRIPT: Script = preload("res://gameplay/enemies/crow/crow_nest.gd")

var arena: Node3D = null


func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)


func _create_find(id: String = "moeda_ouro", val: int = 150) -> CarriedItem:
	var item: ItemData = ItemData.new()
	item.id = id
	item.display_name = "Moeda de Ouro"
	item.base_value = val
	var c: CarriedItem = CarriedItem.new()
	c.item = item
	c.final_value = val
	c.is_clean = true
	c.integrity = 1.0
	return c


func test_crow_nest_creation_and_storage() -> void:
	var nest: Node3D = CROW_NEST_SCRIPT.new() as Node3D
	arena.add_child(nest)

	assert_true(nest.is_in_group(&"crow_nests"))
	assert_eq(int(nest.call("get_item_count")), 0)

	var find1: CarriedItem = _create_find("lingote_prata", 200)
	nest.call("store_item", find1)
	assert_eq(int(nest.call("get_item_count")), 1)

	var find2: CarriedItem = _create_find("anel_rubi", 350)
	nest.call("store_item", find2)
	assert_eq(int(nest.call("get_item_count")), 2)

	var items: Array = nest.call("take_all_items") as Array
	assert_eq(items.size(), 2)
	assert_eq(int(nest.call("get_item_count")), 0)


func test_crow_nest_nearest_lookup() -> void:
	var nest_a: Node3D = CROW_NEST_SCRIPT.new() as Node3D
	arena.add_child(nest_a)
	nest_a.global_position = Vector3(5.0, 0.0, 0.0)

	var nest_b: Node3D = CROW_NEST_SCRIPT.new() as Node3D
	arena.add_child(nest_b)
	nest_b.global_position = Vector3(30.0, 0.0, 0.0)

	var closest: Node3D = CROW_NEST_SCRIPT.call("get_nearest_nest", arena.get_tree(), Vector3(7.0, 0.0, 0.0)) as Node3D
	assert_eq(closest, nest_a)

	var closest_b: Node3D = CROW_NEST_SCRIPT.call("get_nearest_nest", arena.get_tree(), Vector3(28.0, 0.0, 0.0)) as Node3D
	assert_eq(closest_b, nest_b)


const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

func test_crow_nest_search_nest_with_player() -> void:
	var nest: Node3D = CROW_NEST_SCRIPT.new() as Node3D
	arena.add_child(nest)
	nest.call("store_item", _create_find("tesouro1", 100))
	nest.call("store_item", _create_find("tesouro2", 200))

	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.name = "1"
	arena.add_child(player)

	assert_eq(int(nest.call("get_item_count")), 2)
	var recovered: int = int(nest.call("search_nest", player))
	assert_eq(recovered, 2)
	assert_eq(int(nest.call("get_item_count")), 0)
	assert_eq(player.inventory.get_count(), 2)


func test_crow_find_ground_loot() -> void:
	var crow: Node3D = CROW_SCRIPT.new() as Node3D
	arena.add_child(crow)
	crow.global_position = Vector3(0.0, 6.0, 0.0)

	var find: CarriedItem = _create_find("artefato_campo", 180)
	var pickup: ItemPickup = ItemPickup.create(find)
	arena.add_child(pickup)
	pickup.global_position = Vector3(10.0, 0.0, 0.0)

	var target_loot: ItemPickup = crow.call("find_ground_loot", crow.global_position) as ItemPickup
	assert_not_null(target_loot)
	assert_eq(target_loot, pickup)


func test_crow_flee_to_nest_deposits_item() -> void:
	var nest: Node3D = CROW_NEST_SCRIPT.new() as Node3D
	arena.add_child(nest)
	nest.global_position = Vector3(12.0, 0.0, 0.0)

	var crow: Node3D = CROW_SCRIPT.new() as Node3D
	arena.add_child(crow)
	crow.global_position = Vector3(0.0, 2.0, 0.0)

	var loot: CarriedItem = _create_find("relogio_bolso", 220)
	crow.set("stolen", loot)
	crow.set("has_stolen", true)
	crow.set("target_nest", nest)

	crow.call("_start_escape", Vector3.ZERO)
	assert_eq(crow.get("state"), Seagull.State.ESCAPE)
	assert_eq(crow.get("target_nest"), nest)

	# Simula voo em direção ao ninho
	for f: int in 120:
		if crow.get("stolen") == null:
			break
		crow.call("_process_escape", 1.0 / 30.0)

	assert_null(crow.get("stolen"), "corvo entregou o item roubado")
	assert_false(bool(crow.get("has_stolen")))
	assert_eq(int(nest.call("get_item_count")), 1, "ninho guardou o item")


func test_crow_drops_stolen_item_on_damage() -> void:
	var crow: Node3D = CROW_SCRIPT.new() as Node3D
	arena.add_child(crow)
	crow.global_position = Vector3(5.0, 3.0, 5.0)

	var loot: CarriedItem = _create_find("calice_sagrado", 400)
	crow.set("stolen", loot)
	crow.set("has_stolen", true)

	var pickups_before: int = arena.get_tree().get_nodes_in_group(ItemPickup.GROUP).size()

	# Jogador acerta o corvo com estilingue ou pá (take_damage)
	crow.call("take_damage", 15.0, Vector3(5.0, 0.0, 5.0))

	assert_null(crow.get("stolen"), "corvo largou o item roubado ao tomar dano")
	assert_false(bool(crow.get("has_stolen")))

	var pickups_after: int = arena.get_tree().get_nodes_in_group(ItemPickup.GROUP).size()
	assert_eq(pickups_after, pickups_before + 1, "item caiu no chão como pickup físico")
