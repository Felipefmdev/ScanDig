extends GutTest

## Testes abrangentes da Issue #43 (Mapa 4: Geleira Eterna e Arpão de Corda).
## Cobre:
##   1) Arma exclusiva Arpão de Corda (HarpoonModel, HarpoonWorld, ToolData e mecânicas no Player);
##   2) Terreno e estruturas da Geleira (GlacierTerrain, GlacierStructure, GlacierLayout, GroundSnap);
##   3) Cena MapGeleira (WorldEnvironment, EnemySpawner, SpotSpawner, BaseEntrega, Banca 7 ofertas, MammothAltar);
##   4) Missões e segredos (GeleiraSecrets, NPC Björn, lareira, relíquias, interativos e easter eggs).

const HARPOON_MODEL_SCRIPT: Script = preload("res://gameplay/weapons/harpoon/harpoon_model.gd")
const HarpoonModel = preload("res://gameplay/weapons/harpoon/harpoon_model.gd")
const HARPOON_WORLD_SCENE: PackedScene = preload("res://gameplay/weapons/harpoon/harpoon_world.tscn")
const HARPOON_TOOL_DATA: Resource = preload("res://items/tools/arpao_corda.tres")

const GlacierTerrain = preload("res://gameplay/environment/glacier_terrain.gd")
const GlacierStructure = preload("res://gameplay/environment/glacier_structure.gd")
const GlacierLayout = preload("res://gameplay/environment/glacier_layout.gd")
const MammothAltar = preload("res://gameplay/environment/mammoth_altar.gd")
const CabinFireplace = preload("res://gameplay/quests/geleira/cabin_fireplace.gd")

const MAP_GELEIRA_SCENE: PackedScene = preload("res://world/map_geleira.tscn")
const GELEIRA_SECRETS_SCENE: PackedScene = preload("res://gameplay/quests/geleira/geleira_secrets.tscn")
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _world: Node3D = null


func before_each() -> void:
	QuestRewards.reset_session()
	_world = Node3D.new()
	add_child_autofree(_world)


# ---------------------------------------------------------------------------
# 1) Testes do Arpão de Corda
# ---------------------------------------------------------------------------

func test_harpoon_model_and_world_scene() -> void:
	var model: HarpoonModel = HARPOON_MODEL_SCRIPT.new() as HarpoonModel
	_world.add_child(model)
	await wait_frames(2)

	assert_not_null(model.get_node_or_null("WoodStock"), "Coronha de madeira gerada")
	assert_not_null(model.get_node_or_null("MetalParts"), "Cano e partes metálicas geradas")
	assert_not_null(model.get_node_or_null("RopeSpool"), "Carretel de corda gerado")
	assert_not_null(model.get_node_or_null("HarpoonSpear"), "Flecha/arpão farpado gerado")

	# Testa reconstrução sem arpão (disparado)
	model.harpoon_loaded = false
	await wait_frames(1)
	assert_null(model.get_node_or_null("HarpoonSpear"), "Sem flecha quando descarregado")

	# Testa apoio da mão esquerda
	model.show_left_hand = true
	await wait_frames(1)
	assert_not_null(model.get_node_or_null("LeftHand"), "Mão esquerda de apoio presente")

	# Verifica cena de mundo e recurso ToolData
	var world_inst: Node3D = HARPOON_WORLD_SCENE.instantiate() as Node3D
	assert_not_null(world_inst, "HarpoonWorld instancia corretamente")
	assert_true(world_inst.has_node("Model"))
	world_inst.free()

	assert_eq(HARPOON_TOOL_DATA.get("id"), &"arpao_corda")
	assert_eq(HARPOON_TOOL_DATA.get("price"), 6000)
	assert_not_null(HARPOON_TOOL_DATA.get("world_scene"), "world_scene ligada no .tres")


func test_player_harpoon_mechanics_against_enemy() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.global_position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	await wait_frames(2)

	assert_eq(player.harpoon_damage, 40.0)
	assert_eq(player.harpoon_range, 14.0)
	assert_eq(player.harpoon_stun, 0.8)

	# Cria um inimigo Crab de teste à frente do jogador a 5 metros (dentro dos 14m)
	var crab_scene: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")
	var crab: Crab = crab_scene.instantiate() as Crab
	_world.add_child(crab)
	crab.global_position = Vector3(0.0, 0.0, -5.0)
	crab.call(&"_enter_state", Crab.State.CHASE)
	await wait_frames(2)

	# Jogador equipa o arpão
	player.inventory.slots[0] = CarriedItem.create_from_tool_data(HARPOON_TOOL_DATA as ToolData)
	player.inventory.select(0)
	player._update_tool_in_hand()
	await wait_frames(2)

	var initial_z: float = crab.global_position.z
	var initial_hp: float = crab.health

	# Dispara o arpão
	var hits: int = player.fire_harpoon()
	assert_eq(hits, 1, "Arpão acertou no inimigo")
	assert_lt(crab.health, initial_hp, "Inimigo recebeu dano do arpão")
	assert_almost_eq(crab.health, initial_hp - player.harpoon_damage, 0.1, "Dano de 40 aplicado")
	assert_true(crab.is_stunned(), "Inimigo ficou atordoado pelo arpão")
	assert_gt(crab.global_position.z, initial_z, "Inimigo foi puxado na direção do jogador (+Z)")

	# Suporte a coop (request_hit / request_stun)
	crab.replicated = true
	assert_true(crab.has_method("request_hit"), "Suporta request_hit para coop")
	assert_true(crab.has_method("request_stun"), "Suporta request_stun para coop")


func test_player_harpoon_mechanics_pull_pickup() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.global_position = Vector3.ZERO
	await wait_frames(2)

	# Cria um item pickup a 8 metros à frente
	var item_data: ItemData = load("res://items/catalog/bussola_congelada.tres") as ItemData
	var carried: CarriedItem = CarriedItem.create(item_data, 2000, 1.0, false)
	var pickup: ItemPickup = ItemPickup.spawn(_world, carried, Vector3(0.0, 0.2, -8.0))
	assert_not_null(pickup)
	await wait_frames(2)

	var prev_z: float = pickup.global_position.z
	var hits: int = player.fire_harpoon()
	assert_eq(hits, 1, "Arpão fisgou o pickup")
	await wait_frames(5)
	# O item foi puxado em direção a Z=0
	assert_gt(pickup.global_position.z, prev_z, "Pickup foi puxado na direção do jogador")


# ---------------------------------------------------------------------------
# 2) Testes do Terreno e Estruturas da Geleira
# ---------------------------------------------------------------------------

func test_glacier_terrain_and_ground_snap() -> void:
	var terrain: GlacierTerrain = GlacierTerrain.new()
	_world.add_child(terrain)
	await wait_frames(2)

	assert_not_null(terrain.get_node_or_null("Mesh"), "Malha de terreno gerada")
	assert_not_null(terrain.get_node_or_null("Collision"), "Colisor do terreno gerado")

	# Alturas determinísticas
	var spawn_h: float = GlacierTerrain.height_at(0.0, 0.0)
	assert_almost_eq(spawn_h, 0.0, 0.15, "Spawn é plano")

	var lake_h: float = GlacierTerrain.height_at(14.0, -8.0)
	assert_lt(lake_h, -0.4, "Bacia do lago é afundada")

	var wall_h: float = GlacierTerrain.height_at(44.0, 0.0)
	assert_between(wall_h, 0.5, 1.2, "#186: margem baixa preserva horizonte aberto")

	# Cores
	var col: Color = GlacierTerrain.color_at(0.0, 0.0, 0.0)
	assert_gt(col.r, 0.5, "Cor de neve válida")

	# GroundSnap com terrain = 3 (Geleira)
	var snap_node: GroundSnap = GroundSnap.new()
	snap_node.terrain = 3
	_world.add_child(snap_node)
	var marker: Marker3D = Marker3D.new()
	marker.position = Vector3(14.0, 10.0, -8.0)
	snap_node.add_child(marker)
	snap_node.snap()
	assert_almost_eq(marker.global_position.y, lake_h - snap_node.sink, 0.05, "GroundSnap assenta na altura da Geleira")


func test_glacier_structures_and_layout() -> void:
	var layout: GlacierLayout = GlacierLayout.new()
	_world.add_child(layout)
	layout.rebuild()
	await wait_frames(2)
	assert_gt(layout.get_child_count(), 10, "Layout gerou mais de 10 peças de cenário")


# ---------------------------------------------------------------------------
# 3) Testes da Cena do Mapa 4 (map_geleira.tscn)
# ---------------------------------------------------------------------------

func test_map_geleira_scene_structure() -> void:
	var map: Node3D = MAP_GELEIRA_SCENE.instantiate() as Node3D
	_world.add_child(map)
	await wait_frames(2)

	assert_not_null(map.get_node_or_null("WorldEnvironment"), "WorldEnvironment presente")
	assert_not_null(map.get_node_or_null("Terrain/Ground"), "Terreno da geleira presente")
	assert_not_null(map.get_node_or_null("Terrain/Grass"), "Tufo de relva/neve presente")
	assert_not_null(map.get_node_or_null("Decor/Layout"), "Layout presente")

	var spawner: SpotSpawner = map.get_node_or_null("SpotSpawner") as SpotSpawner
	assert_not_null(spawner, "SpotSpawner presente")
	assert_eq(spawner.map_data.id, "geleira", "SpotSpawner configurado para geleira")

	var enemy_spawner: EnemySpawner = map.get_node_or_null("EnemySpawner") as EnemySpawner
	assert_not_null(enemy_spawner, "EnemySpawner presente")
	assert_eq(enemy_spawner.primary_kind, &"ice_wolf")
	assert_eq(enemy_spawner.secondary_kind, &"walrus")
	assert_true(enemy_spawner.ambient_kinds.has(&"ice_wolf"))
	assert_true(enemy_spawner.ambient_kinds.has(&"penguin"))
	assert_true(enemy_spawner.ambient_kinds.has(&"walrus"))

	assert_not_null(map.get_node_or_null("BaseEntrega"), "Base de Entrega presente")

	# Banca com as 7 ofertas completas
	var banca: Node3D = map.get_node_or_null("Banca") as Node3D
	assert_not_null(banca, "Banca presente")
	for i: int in range(1, 8):
		var offer: ShopOffer = banca.get_node_or_null("Offer%d" % i) as ShopOffer
		assert_not_null(offer, "Oferta %d presente na banca" % i)
		assert_not_null(offer.tool_data, "ToolData válido na oferta %d" % i)
	var offer7: ShopOffer = banca.get_node_or_null("Offer7") as ShopOffer
	assert_eq(offer7.tool_data.id, &"arpao_corda", "Oferta 7 é o Arpão de Corda")

	# Altar do chefe principal (Mamute)
	var altar: MammothAltar = map.get_node_or_null("MammothAltar") as MammothAltar
	assert_not_null(altar, "MammothAltar presente")


# ---------------------------------------------------------------------------
# 4) Testes das Missões, Relíquias e Segredos (GeleiraSecrets)
# ---------------------------------------------------------------------------

func test_geleira_secrets_and_bjorn_quest() -> void:
	var secrets: Node3D = GELEIRA_SECRETS_SCENE.instantiate() as Node3D
	_world.add_child(secrets)
	await wait_frames(2)

	var flags: WorldFlags = WorldFlags.find(_world.get_tree())
	assert_not_null(flags, "WorldFlags presente")

	# NPC Velho Björn
	var bjorn: QuestNpc = secrets.get_node_or_null("Ground/Bjorn") as QuestNpc
	assert_not_null(bjorn, "NPC Velho Björn presente")
	assert_eq(bjorn.quest_id, "bjorn_expedicao")
	assert_eq(bjorn.objective_flag, &"expedicao_encontrada")
	assert_eq(bjorn.reward_item_id, "bussola_antiga")
	assert_eq(bjorn.get_quest_state(), QuestNpc.QuestState.OFFER)

	# Lareira com cura lenta
	var hearth: CabinFireplace = secrets.get_node_or_null("Ground/CabinFireplace") as CabinFireplace
	assert_not_null(hearth, "Lareira presente na cabana")

	# Pistas da expedição e contador
	var diary: FlagInteractable = secrets.get_node_or_null("Ground/ExpeditionDiary") as FlagInteractable
	var sled: FlagInteractable = secrets.get_node_or_null("Ground/ExpeditionSled") as FlagInteractable
	var counter: QuestCounter = secrets.get_node_or_null("ExpeditionCounter") as QuestCounter
	assert_not_null(diary)
	assert_not_null(sled)
	assert_not_null(counter)

	# Interage com as duas pistas
	assert_false(flags.has_flag(&"expedicao_encontrada"))
	diary.request_interact()
	assert_eq(counter.count, 1)
	assert_false(flags.has_flag(&"expedicao_encontrada"))
	sled.request_interact()
	assert_eq(counter.count, 2)
	assert_true(flags.has_flag(&"expedicao_encontrada"), "As duas pistas ativam a bandeira expedicao_encontrada")

	# Björn reage às pistas
	bjorn.request_interact()  # aceita a missão
	assert_true(flags.has_flag(&"bjorn_missao"))
	await wait_frames(1)
	assert_eq(bjorn.get_quest_state(), QuestNpc.QuestState.READY, "Björn pronto para acionar o chefe")

	# 3 Relíquias escondidas
	var relic_mammoth: FlagInteractable = secrets.get_node_or_null("Ground/BabyMammothRelic") as FlagInteractable
	var relic_axe: FlagInteractable = secrets.get_node_or_null("Ground/LakeAxeRelic") as FlagInteractable
	var relic_compass: FlagInteractable = secrets.get_node_or_null("Ground/IglooCompassRelic") as FlagInteractable

	assert_not_null(relic_mammoth)
	assert_eq(relic_mammoth.item_id, "fossil_gelo")
	assert_eq(relic_mammoth.secret_id, "geleira_reliquia_mamute")

	assert_not_null(relic_axe)
	assert_eq(relic_axe.item_id, "machado_viking")
	assert_eq(relic_axe.secret_id, "geleira_reliquia_lago")

	assert_not_null(relic_compass)
	assert_eq(relic_compass.item_id, "bussola_congelada")
	assert_eq(relic_compass.secret_id, "geleira_reliquia_iglu")

	# 2 Easter Eggs
	var egg_snowman: FlagInteractable = secrets.get_node_or_null("Ground/SnowmanGoldCarrot") as FlagInteractable
	var egg_penguin: FlagInteractable = secrets.get_node_or_null("Ground/PartyPenguin") as FlagInteractable

	assert_not_null(egg_snowman)
	assert_eq(egg_snowman.secret_id, "geleira_ovo_boneco")

	assert_not_null(egg_penguin)
	assert_eq(egg_penguin.secret_id, "geleira_ovo_pinguim")

	# Interativos e Gatilhos de Chefe
	var thin_ice: FlagInteractable = secrets.get_node_or_null("Ground/ThinIce") as FlagInteractable
	var stalactite: FlagInteractable = secrets.get_node_or_null("Ground/Stalactite") as FlagInteractable
	var aurora: FlagInteractable = secrets.get_node_or_null("Ground/AuroraTracks") as FlagInteractable

	assert_not_null(thin_ice)
	thin_ice.request_interact()
	assert_true(flags.has_flag(&"gelo_fino_rachado"))

	assert_not_null(stalactite)
	stalactite.request_interact()
	assert_true(flags.has_flag(&"estalactite_quebrada"))

	assert_not_null(aurora)
	aurora.request_interact()
	assert_true(flags.has_flag(&"yeti_acordado"))

	var walrus_trigger: BossTrigger = secrets.get_node_or_null("WalrusElderTrigger") as BossTrigger
	assert_not_null(walrus_trigger)
	assert_eq(walrus_trigger.boss_kind, &"ancient_walrus")
	assert_eq(walrus_trigger.secret_id, "geleira_morsa_ancia")

	var yeti_trigger: BossTrigger = secrets.get_node_or_null("YetiTrigger") as BossTrigger
	assert_not_null(yeti_trigger)
	assert_eq(yeti_trigger.boss_kind, &"cave_yeti")
	assert_eq(yeti_trigger.trigger_flag, &"yeti_acordado")
