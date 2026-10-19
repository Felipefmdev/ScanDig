extends GutTest

## Testes unitários para a Issue #108:
## Geleira: lago congelado que trinca e revela itens afundados.
## Cobre:
##   1) Placas de gelo (IceFloe) e ciclo de vida: trinca por estresse, quebra e recongelamento;
##   2) Destruição em massa por dinamite;
##   3) Lago congelado (FrozenLake): malha de água, placas poligonais concêntricas e itens afundados;
##   4) Perigo da água gélida: hipotermia e dreno de fome em nadadores;
##   5) Resgate de itens afundados via Arpão de Corda.

const IceFloe = preload("res://gameplay/environment/ice_floe.gd")
const FrozenLake = preload("res://gameplay/environment/frozen_lake.gd")
const ICE_FLOE_SCRIPT: Script = IceFloe
const FROZEN_LAKE_SCRIPT: Script = FrozenLake
const DYNAMITE_SCRIPT: Script = preload("res://gameplay/weapons/dynamite/dynamite.gd")
const HARPOON_TOOL_DATA: Resource = preload("res://items/tools/arpao_corda.tres")
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _world: Node3D = null


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)


func test_ice_floe_stress_states_and_signals() -> void:
	var floe: IceFloe = ICE_FLOE_SCRIPT.new() as IceFloe
	_world.add_child(floe)
	floe.set_physics_process(false)

	watch_signals(floe)

	assert_eq(floe.state, IceFloe.STATE_INTACT, "Placa começa intacta")
	assert_almost_eq(floe.health, 1.0, 0.01, "Vida inicial 1.0")
	assert_false(floe.is_broken(), "Não está quebrada")

	# 1. Aplica estresse leve -> STATE_CRACKED
	floe.take_stress(0.40)
	assert_eq(floe.state, IceFloe.STATE_CRACKED, "Transiciona para trincada")
	assert_signal_emitted(floe, "cracked", "Sinal cracked emitido")

	# 2. Mais estresse -> STATE_SEVERELY_CRACKED
	floe.take_stress(0.35)
	assert_eq(floe.state, IceFloe.STATE_SEVERELY_CRACKED, "Transiciona para severamente trincada")

	# 3. Quebra total -> STATE_BROKEN
	floe.take_stress(0.30)
	assert_eq(floe.state, IceFloe.STATE_BROKEN, "Placa quebrou")
	assert_true(floe.is_broken(), "is_broken() retorna true")
	assert_signal_emitted(floe, "shattered", "Sinal shattered emitido")


func test_ice_floe_refreeze_lifecycle() -> void:
	var floe: IceFloe = ICE_FLOE_SCRIPT.new() as IceFloe
	_world.add_child(floe)
	floe.set_physics_process(false)

	watch_signals(floe)

	floe.shatter()
	assert_eq(floe.state, IceFloe.STATE_BROKEN, "Quebrou com shatter()")

	# Simula tempo decorrido até o início do recongelamento
	floe._time_broken = IceFloe.REFREEZE_DELAY + 0.1
	floe._process_refreeze(2.0)

	assert_gt(floe.health, 0.35, "Vida recuperada pelo recongelamento")
	assert_eq(floe.state, IceFloe.STATE_CRACKED, "Recongelou para estado trincado")
	assert_signal_emitted(floe, "refrozen", "Sinal refrozen emitido")


func test_dynamite_blast_shatters_floes() -> void:
	var floe: IceFloe = ICE_FLOE_SCRIPT.new() as IceFloe
	_world.add_child(floe)
	floe.global_position = Vector3(1.5, 0.0, 1.0)
	floe.set_physics_process(false)

	assert_false(floe.is_broken(), "Placa intacta antes da explosão")

	var blast_res: Dictionary = DYNAMITE_SCRIPT.apply_blast(get_tree(), Vector3.ZERO, null)
	assert_true(blast_res.has("ice_floes"), "Resultado inclui contagem de placas")
	assert_gt(blast_res["ice_floes"], 0, "Dinamite atingiu a placa de gelo")
	assert_true(floe.is_broken(), "Placa foi estraçalhada pela explosão")


func test_frozen_lake_generation_and_components() -> void:
	var lake: FrozenLake = FROZEN_LAKE_SCRIPT.new() as FrozenLake
	_world.add_child(lake)
	lake.set_physics_process(false)

	assert_not_null(lake.get_node_or_null("WaterSurface"), "Superfície de água gerada")
	assert_not_null(lake.get_node_or_null("WaterHazardArea"), "Área de perigo aquático gerada")

	# 1 centro + 6 anel 1 + 12 anel 2 = 19 placas
	assert_eq(lake.floes.size(), 19, "19 placas geradas na malha concêntrica")

	var center_floe: IceFloe = lake.get_floe_at(Vector3(14.0, 0.0, -8.0))
	assert_not_null(center_floe, "Encontra placa central no centro do lago")
	assert_almost_eq(center_floe.floe_radius, 1.85, 0.05, "Raio da placa central")

	# Testa busca de placa fora do lago
	var outside_floe: IceFloe = lake.get_floe_at(Vector3(0.0, 0.0, 0.0))
	assert_null(outside_floe, "Sem placa fora dos limites do lago")


func test_water_hazard_hypothermia_drain() -> void:
	var lake: FrozenLake = FROZEN_LAKE_SCRIPT.new() as FrozenLake
	_world.add_child(lake)

	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.set_physics_process(false)

	player.set_hunger(80.0)
	var hp_before: float = player.health

	# 1. Jogador em pé sobre placa intacta -> não sofre dano nem dreno
	var center_floe: IceFloe = lake.get_floe_at(Vector3(14.0, 0.0, -8.0))
	player.global_position = center_floe.global_position
	lake._on_water_body_entered(player)

	lake._physics_process(0.5)
	assert_almost_eq(player.hunger, 80.0, 0.01, "Sem dreno de fome sobre gelo intacto")
	assert_almost_eq(player.health, hp_before, 0.01, "Sem dano de frio sobre gelo intacto")

	# 2. Placa central quebra -> jogador submerso na água gélida
	center_floe.shatter()
	player.global_position.y = center_floe.global_position.y - 0.20 # afunda na água

	lake._physics_process(1.0)
	assert_lt(player.hunger, 80.0, "Água gélida drena fome continuamente")

	lake._physics_process(FrozenLake.HYPOTHERMIA_TICK_INTERVAL)
	assert_lt(player.health, hp_before, "Hipotermia aplica dano periódico à vida")


func test_harpoon_pull_sunken_item_and_stresses_ice() -> void:
	var lake: FrozenLake = FROZEN_LAKE_SCRIPT.new() as FrozenLake
	_world.add_child(lake)
	lake.set_physics_process(false)

	# Cria item afundado debaixo da placa central
	var item_data: ItemData = load("res://items/catalog/bussola_congelada.tres") as ItemData
	var carried: CarriedItem = CarriedItem.create(item_data, 2200, 1.0, false)
	var sunken_pos: Vector3 = Vector3(14.0, -0.65, -8.0)
	var pickup: ItemPickup = ItemPickup.spawn(lake, carried, sunken_pos)
	assert_not_null(pickup, "Item afundado instanciado")

	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.global_position = Vector3(14.0, 0.0, -5.0) # 3 metros ao sul
	player.set_physics_process(false)

	# Equipa arpão
	player.inventory.slots[0] = CarriedItem.create_from_tool_data(HARPOON_TOOL_DATA as ToolData)
	player.inventory.select(0)
	player._update_tool_in_hand()

	# Vira o jogador para o norte (em direção ao item afundado)
	player.rotation = Vector3.ZERO

	var center_floe: IceFloe = lake.get_floe_at(sunken_pos)
	assert_not_null(center_floe)
	var floe_hp_before: float = center_floe.health

	# Dispara arpão no item
	var hits: int = player.fire_harpoon()
	assert_gte(hits, 1, "Arpão fisgou o item afundado")
	assert_lt(center_floe.health, floe_hp_before, "Puxar o item através do gelo trinca a placa")
