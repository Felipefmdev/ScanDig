extends GutTest

## Testes abrangentes da Issue #44 (Mapa 5: Cratera Final e Pulso Magnético).
## Cobre:
##   1) Arma exclusiva Pulso Magnético (MagneticPulseModel, MagneticPulseWorld, ToolData e mecânicas no Player: empurrar inimigos com dano/knockback/stun, puxar itens metálicos);
##   2) Terreno e estruturas da Cratera (CraterTerrain, CraterStructure, CraterLayout, GroundSnap);
##   3) Cena MapCratera (WorldEnvironment, EnemySpawner, SpotSpawner, BaseEntrega, Banca com 8 ofertas incluindo pulso_magnetico, CraterAltar sem overlay de vitória próprio, #115);
##   4) Missões, relíquias e segredos (CrateraSecrets, Dra. Vega, antenas, wave event, cristais ressonantes, O Eco, gravidade baixa, geodo, pilar, cortina, easter eggs).

const PULSE_MODEL_SCRIPT: Script = preload("res://gameplay/weapons/magnetic_pulse/magnetic_pulse_model.gd")
const MagneticPulseModel = preload("res://gameplay/weapons/magnetic_pulse/magnetic_pulse_model.gd")
const PULSE_WORLD_SCENE: PackedScene = preload("res://gameplay/weapons/magnetic_pulse/magnetic_pulse_world.tscn")
const PULSE_TOOL_DATA: Resource = preload("res://items/tools/pulso_magnetico.tres")

const CraterTerrain = preload("res://gameplay/environment/crater_terrain.gd")
const CraterStructure = preload("res://gameplay/environment/crater_structure.gd")
const CraterLayout = preload("res://gameplay/environment/crater_layout.gd")
const CraterAltar = preload("res://gameplay/environment/crater_altar.gd")
const LowGravityZone = preload("res://gameplay/quests/cratera/low_gravity_zone.gd")

const MAP_CRATERA_SCENE: PackedScene = preload("res://world/map_cratera.tscn")
const CRATERA_SECRETS_SCENE: PackedScene = preload("res://gameplay/quests/cratera/cratera_secrets.tscn")
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _world: Node3D = null


func before_each() -> void:
	QuestRewards.reset_session()
	_world = Node3D.new()
	add_child_autofree(_world)


# ---------------------------------------------------------------------------
# 1) Testes do Pulso Magnético
# ---------------------------------------------------------------------------

func test_magnetic_pulse_model_and_world_scene() -> void:
	var model: MagneticPulseModel = PULSE_MODEL_SCRIPT.new() as MagneticPulseModel
	_world.add_child(model)
	await wait_frames(2)

	assert_not_null(model.get_node_or_null("Body"), "Chassi principal gerado")
	assert_not_null(model.get_node_or_null("Grip"), "Empunhadura gerada")
	assert_not_null(model.get_node_or_null("EnergyCore"), "Câmara de energia gerada")
	assert_not_null(model.get_node_or_null("Coils"), "Bobinas magnéticas de cobre geradas")
	assert_not_null(model.get_node_or_null("MagnetFork"), "Forquilha magnética polar gerada")

	# Testa apoio da mão esquerda
	model.show_left_hand = true
	await wait_frames(1)
	assert_not_null(model.get_node_or_null("LeftHand"), "Mão esquerda de apoio presente")

	# Verifica cena de mundo e recurso ToolData
	var world_inst: Node3D = PULSE_WORLD_SCENE.instantiate() as Node3D
	assert_not_null(world_inst, "MagneticPulseWorld instancia corretamente")
	assert_true(world_inst.has_node("Model"))
	world_inst.free()

	assert_eq(PULSE_TOOL_DATA.get("id"), &"pulso_magnetico")
	assert_gt(int(PULSE_TOOL_DATA.get("price")), 0)
	assert_not_null(PULSE_TOOL_DATA.get("world_scene"), "world_scene ligada no .tres")


func test_player_magnetic_pulse_mechanics_push_enemy() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.global_position = Vector3.ZERO
	player.rotation = Vector3.ZERO
	await wait_frames(2)

	assert_eq(player.magnetic_pulse_damage, 35.0)
	assert_eq(player.magnetic_pulse_enemy_range, 7.5)
	assert_eq(player.magnetic_pulse_pickup_range, 12.0)
	assert_eq(player.magnetic_pulse_stun, 0.6)

	# Cria um inimigo Crab de teste à frente do jogador a 4 metros (dentro dos 7.5m)
	var crab_scene: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")
	var crab: Crab = crab_scene.instantiate() as Crab
	_world.add_child(crab)
	crab.global_position = Vector3(0.0, 0.0, -4.0)
	crab.call(&"_enter_state", Crab.State.CHASE)
	await wait_frames(2)

	# Jogador equipa o pulso magnético
	player.inventory.slots[0] = CarriedItem.create_from_tool_data(PULSE_TOOL_DATA as ToolData)
	player.inventory.select(0)
	player._update_tool_in_hand()
	await wait_frames(2)

	var initial_z: float = crab.global_position.z
	var initial_hp: float = crab.health

	# Dispara o pulso magnético
	var hits: int = player.fire_magnetic_pulse()
	assert_eq(hits, 1, "Pulso magnético atingiu o inimigo")
	assert_lt(crab.health, initial_hp, "Inimigo recebeu dano da onda de choque")
	assert_almost_eq(crab.health, initial_hp - player.magnetic_pulse_damage, 0.1, "Dano de 35 aplicado")
	assert_true(crab.is_stunned(), "Inimigo ficou atordoado pelo choque magnético")
	# Knockback: empurra para longe do jogador (em direção a -Z)
	assert_lt(crab.global_position.z, initial_z, "Inimigo foi empurrado para longe do jogador (-Z)")

	# Suporte a coop (request_hit / request_stun)
	crab.replicated = true
	assert_true(crab.has_method("request_hit"), "Suporta request_hit para coop")
	assert_true(crab.has_method("request_stun"), "Suporta request_stun para coop")


func test_player_magnetic_pulse_mechanics_pull_metal_pickups() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.global_position = Vector3.ZERO
	await wait_frames(2)

	# Cria um item metálico Pickup a 9 metros de distância (dentro do raio de 12m)
	var item_data: ItemData = load("res://items/catalog/fragmento_meteorito.tres") as ItemData
	var carried: CarriedItem = CarriedItem.create(item_data, 1500, 1.0, false)
	var pickup: ItemPickup = ItemPickup.spawn(_world, carried, Vector3(0.0, 0.2, 9.0))
	assert_not_null(pickup)
	await wait_frames(2)

	var prev_z: float = pickup.global_position.z
	player.fire_magnetic_pulse()
	await wait_frames(5)
	# O item foi puxado em direção a Z=0 (+Z diminui para 0)
	assert_lt(pickup.global_position.z, prev_z, "Item Pickup foi puxado na direção do jogador")


# ---------------------------------------------------------------------------
# 2) Testes do Terreno e Estruturas da Cratera
# ---------------------------------------------------------------------------

func test_crater_terrain_and_ground_snap() -> void:
	var terrain: CraterTerrain = CraterTerrain.new()
	_world.add_child(terrain)
	await wait_frames(2)

	assert_not_null(terrain.get_node_or_null("Mesh"), "Malha de terreno gerada")
	assert_not_null(terrain.get_node_or_null("Collision"), "Colisor do terreno gerado")

	# Alturas determinísticas
	var center_h: float = CraterTerrain.height_at(0.0, 0.0)
	assert_lt(center_h, 0.1, "Centro da cratera é uma depressão")

	var rim_h: float = CraterTerrain.height_at(42.0, 0.0)
	assert_gt(rim_h, 5.0, "Bordas perimétricas da cratera são elevadas")

	# Cores
	var col: Color = CraterTerrain.color_at(0.0, 0.0, 0.0)
	assert_gt(col.r + col.b, 0.2, "Cor de rocha basalto/cósmica válida")

	# GroundSnap com terrain = 4 (Cratera)
	var snap_node: GroundSnap = GroundSnap.new()
	snap_node.terrain = 4
	_world.add_child(snap_node)
	var marker: Marker3D = Marker3D.new()
	marker.position = Vector3(14.0, 10.0, 14.0)
	snap_node.add_child(marker)
	snap_node.snap()
	var expected_h: float = CraterTerrain.height_at(14.0, 14.0)
	assert_almost_eq(marker.global_position.y, expected_h - snap_node.sink, 0.05, "GroundSnap assenta na altura da Cratera")


func test_crater_structures_and_layout() -> void:
	var layout: CraterLayout = CraterLayout.new()
	_world.add_child(layout)
	layout.rebuild()
	await wait_frames(2)
	assert_gt(layout.get_child_count(), 10, "Layout da Cratera gerou mais de 10 peças de cenário")


# ---------------------------------------------------------------------------
# 3) Testes da Cena do Mapa 5 (map_cratera.tscn)
# ---------------------------------------------------------------------------

func test_map_cratera_scene_structure() -> void:
	var map: Node3D = MAP_CRATERA_SCENE.instantiate() as Node3D
	_world.add_child(map)
	await wait_frames(2)

	assert_not_null(map.get_node_or_null("WorldEnvironment"), "WorldEnvironment presente")
	assert_not_null(map.get_node_or_null("Terrain/Ground"), "Terreno da cratera presente")
	assert_not_null(map.get_node_or_null("Terrain/Grass"), "Tufo de relva cósmica presente")
	assert_not_null(map.get_node_or_null("Decor/Layout"), "Layout presente")

	var spawner: SpotSpawner = map.get_node_or_null("SpotSpawner") as SpotSpawner
	assert_not_null(spawner, "SpotSpawner presente")
	assert_eq(spawner.map_data.id, "cratera", "SpotSpawner configurado para cratera")

	var enemy_spawner: EnemySpawner = map.get_node_or_null("EnemySpawner") as EnemySpawner
	assert_not_null(enemy_spawner, "EnemySpawner presente")
	assert_eq(enemy_spawner.primary_kind, &"crawler")
	assert_eq(enemy_spawner.secondary_kind, &"floater")
	assert_true(enemy_spawner.ambient_kinds.has(&"crawler"))
	assert_true(enemy_spawner.ambient_kinds.has(&"floater"))

	assert_not_null(map.get_node_or_null("BaseEntrega"), "Base de Entrega presente")

	# Banca com todas as 8 ofertas completas
	var banca: Node3D = map.get_node_or_null("Banca") as Node3D
	assert_not_null(banca, "Banca presente")
	for i: int in range(1, 9):
		var offer: ShopOffer = banca.get_node_or_null("Offer%d" % i) as ShopOffer
		assert_not_null(offer, "Oferta %d presente na banca" % i)
		assert_not_null(offer.tool_data, "ToolData válido na oferta %d" % i)
	var offer8: ShopOffer = banca.get_node_or_null("Offer8") as ShopOffer
	assert_eq(offer8.tool_data.id, &"pulso_magnetico", "Oferta 8 é o Pulso Magnético")

	# Altar do chefe principal (O Dorminhoco / The Sleeper)
	var altar: CraterAltar = map.get_node_or_null("CraterAltar") as CraterAltar
	assert_not_null(altar, "CraterAltar presente")
	# #115: vitória e créditos ficam na VictoryScreen (final no gold_colossus).
	assert_false(altar.has_method(&"show_victory_and_credits"), "sem overlay de vitória próprio")


# ---------------------------------------------------------------------------
# 4) Testes das Missões, Relíquias e Segredos (CrateraSecrets)
# ---------------------------------------------------------------------------

func test_cratera_secrets_and_vega_quest() -> void:
	var secrets: Node3D = CRATERA_SECRETS_SCENE.instantiate() as Node3D
	_world.add_child(secrets)
	await wait_frames(2)

	var flags: WorldFlags = WorldFlags.find(_world.get_tree())
	assert_not_null(flags, "WorldFlags presente")

	# NPC Dra. Vega
	var vega: QuestNpc = secrets.get_node_or_null("Ground/Vega") as QuestNpc
	assert_not_null(vega, "NPC Dra. Vega presente")
	assert_eq(vega.quest_id, "vega_sinal")
	assert_eq(vega.objective_flag, &"antenas_calibradas")
	assert_eq(vega.reward_item_id, "cristal_eco")
	assert_eq(vega.get_quest_state(), QuestNpc.QuestState.OFFER)

	# 3 Antenas e contador de calibração
	var ant_a: FlagInteractable = secrets.get_node_or_null("Ground/AntennaAlfa") as FlagInteractable
	var ant_b: FlagInteractable = secrets.get_node_or_null("Ground/AntennaBeta") as FlagInteractable
	var ant_c: FlagInteractable = secrets.get_node_or_null("Ground/AntennaGama") as FlagInteractable
	var counter: QuestCounter = secrets.get_node_or_null("AntennaCounter") as QuestCounter
	assert_not_null(ant_a)
	assert_not_null(ant_b)
	assert_not_null(ant_c)
	assert_not_null(counter)

	# Interage com as 3 antenas
	assert_false(flags.has_flag(&"antenas_calibradas"))
	ant_a.request_interact()
	assert_eq(counter.count, 1)
	assert_false(flags.has_flag(&"antenas_calibradas"))
	ant_b.request_interact()
	assert_eq(counter.count, 2)
	assert_false(flags.has_flag(&"antenas_calibradas"))
	ant_c.request_interact()
	assert_eq(counter.count, 3)
	assert_true(flags.has_flag(&"antenas_calibradas"), "3 antenas calibradas ativam bandeira antenas_calibradas")

	# Dra. Vega aceita missão e fica pronta para o evento de transmissão
	vega.request_interact()
	assert_true(flags.has_flag(&"vega_missao"))
	await wait_frames(1)
	assert_eq(vega.get_quest_state(), QuestNpc.QuestState.READY, "Vega pronta para acionar transmissão")

	# Evento de ondas da transmissão
	var wave_ev: WaveEvent = secrets.get_node_or_null("AntennaWaveEvent") as WaveEvent
	assert_not_null(wave_ev, "AntennaWaveEvent presente")
	assert_eq(wave_ev.rounds.size(), 4, "Transmissão tem 4 rondas de criaturas")

	# Puzzle de cristais ressonantes para acordar O Eco
	var cry_v: FlagInteractable = secrets.get_node_or_null("Ground/CrystalViolet") as FlagInteractable
	var cry_c: FlagInteractable = secrets.get_node_or_null("Ground/CrystalCyan") as FlagInteractable
	var cry_a: FlagInteractable = secrets.get_node_or_null("Ground/CrystalAmber") as FlagInteractable
	var seq: SequencePuzzle = secrets.get_node_or_null("CrystalSequence") as SequencePuzzle
	var echo_trigger: BossTrigger = secrets.get_node_or_null("EchoTrigger") as BossTrigger

	assert_not_null(cry_v)
	assert_not_null(cry_c)
	assert_not_null(cry_a)
	assert_not_null(seq)
	assert_not_null(echo_trigger)
	assert_eq(echo_trigger.boss_kind, &"the_echo")
	assert_eq(echo_trigger.trigger_flag, &"eco_acordado")

	# Toca a sequência correta de cristais (Violeta -> Ciano -> Âmbar)
	assert_false(flags.has_flag(&"eco_acordado"))
	cry_v.request_interact()
	assert_eq(seq.progress, 1)
	cry_c.request_interact()
	assert_eq(seq.progress, 2)
	cry_a.request_interact()
	assert_true(flags.has_flag(&"eco_acordado"), "Sequência correta acorda o chefe escondido O Eco")

	# Zona de baixa gravidade
	var grav_zone: LowGravityZone = secrets.get_node_or_null("LowGravityZone") as LowGravityZone
	assert_not_null(grav_zone, "LowGravityZone presente")

	var p: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(p)
	grav_zone._on_body_entered(p)
	assert_almost_eq(p.jump_velocity, grav_zone.boosted_jump, 0.01, "Salto amplificado na zona")
	grav_zone._on_body_exited(p)
	assert_almost_eq(p.jump_velocity, 4.2, 0.01, "Salto restaurado ao sair da zona")
	p.free()

	# 3 Relíquias escondidas
	var relic_geode: FlagInteractable = secrets.get_node_or_null("Ground/GeodeRelic") as FlagInteractable
	var relic_orb: FlagInteractable = secrets.get_node_or_null("Ground/OrbRelic") as FlagInteractable
	var curtain: FlagInteractable = secrets.get_node_or_null("Ground/CrystalCurtain") as FlagInteractable
	var relic_gear: FlagInteractable = secrets.get_node_or_null("Ground/RelicGear") as FlagInteractable

	assert_not_null(relic_geode)
	assert_eq(relic_geode.item_id, "geodo_estrelar")
	assert_eq(relic_geode.secret_id, "cratera_reliquia_geodo")

	assert_not_null(relic_orb)
	assert_eq(relic_orb.item_id, "orbe_vibrante")
	assert_eq(relic_orb.secret_id, "cratera_reliquia_orbe")

	assert_not_null(curtain)
	curtain.request_interact()
	assert_true(flags.has_flag(&"cortina_quebrada"), "Cortina de cristal parte-se")

	assert_not_null(relic_gear)
	assert_eq(relic_gear.item_id, "engrenagem_alienigena")
	assert_eq(relic_gear.secret_id, "cratera_reliquia_engrenagem")
	assert_eq(relic_gear.requires_flag, &"cortina_quebrada")

	# 2 Easter Eggs
	var egg_probe: FlagInteractable = secrets.get_node_or_null("Ground/SpaceProbe") as FlagInteractable
	var egg_vinyl: FlagInteractable = secrets.get_node_or_null("Ground/VinylRecord") as FlagInteractable

	assert_not_null(egg_probe)
	assert_eq(egg_probe.secret_id, "cratera_ovo_sonda")

	assert_not_null(egg_vinyl)
	assert_eq(egg_vinyl.secret_id, "cratera_ovo_disco")

	# Rocha de meteorito quebrável
	var meteor_rock: FlagInteractable = secrets.get_node_or_null("Ground/MeteoriteRock") as FlagInteractable
	assert_not_null(meteor_rock)
	assert_eq(meteor_rock.item_id, "fragmento_meteorito")
	meteor_rock.request_interact()
	assert_true(flags.has_flag(&"rocha_meteorito_partida"))
