extends GutTest

## #42: testes das missões e segredos das Ruínas (RuinasSecrets).
## Cobre NPC Arqueóloga Inês, 3 tábuas com glifos, WaveEvent de 4 ondas,
## pedestal da cripta (Múmia do Ídolo), 3 relíquias e 2 easter eggs.

const RUINAS_SECRETS_SCENE: PackedScene = preload("res://gameplay/quests/ruinas/ruinas_secrets.tscn")
const MAP_RUINAS_SCENE: PackedScene = preload("res://world/map_ruinas.tscn")

var world: Node3D
var secrets: Node3D
var flags: WorldFlags


func before_each() -> void:
	QuestRewards.reset_session()
	world = Node3D.new()
	add_child_autofree(world)
	secrets = RUINAS_SECRETS_SCENE.instantiate() as Node3D
	world.add_child(secrets)
	await wait_frames(2)
	flags = WorldFlags.find(world.get_tree())


func test_scene_nodes_wiring() -> void:
	assert_not_null(flags, "WorldFlags presente na cena")
	var ines: QuestNpc = secrets.get_node_or_null(^"Ground/Ines") as QuestNpc
	assert_not_null(ines, "NPC Inês presente")
	assert_eq(ines.quest_id, "ines_camara")
	assert_eq(ines.objective_flag, &"tabuas_encontradas")
	assert_eq(ines.reward_item_id, "idolo_jade")

	var waves: WaveEvent = secrets.get_node_or_null(^"ThroneWaves") as WaveEvent
	assert_not_null(waves, "ThroneWaves presente")
	assert_eq(waves.rounds.size(), 4, "4 ondas de guardiões de pedra")
	assert_true(waves.rounds[0].begins_with("stone_guardian"))

	var mummy_trigger: BossTrigger = secrets.get_node_or_null(^"MummyTrigger") as BossTrigger
	assert_not_null(mummy_trigger, "MummyTrigger presente")
	assert_eq(mummy_trigger.boss_kind, &"idol_mummy")
	assert_eq(mummy_trigger.trigger_flag, &"pedestal_idolo")
	assert_eq(mummy_trigger.secret_id, "ruinas_mumia")


func test_three_tablets_advance_counter_and_set_flag() -> void:
	var t1: FlagInteractable = secrets.get_node(^"Ground/Tablet1") as FlagInteractable
	var t2: FlagInteractable = secrets.get_node(^"Ground/Tablet2") as FlagInteractable
	var t3: FlagInteractable = secrets.get_node(^"Ground/Tablet3") as FlagInteractable
	var counter: QuestCounter = secrets.get_node(^"TabletsCounter") as QuestCounter

	assert_false(flags.has_flag(&"tabuas_encontradas"))
	assert_eq(counter.count, 0)

	t1.request_interact()
	assert_eq(counter.count, 1)
	assert_false(flags.has_flag(&"tabuas_encontradas"))

	t2.request_interact()
	assert_eq(counter.count, 2)
	assert_false(flags.has_flag(&"tabuas_encontradas"))

	t3.request_interact()
	assert_eq(counter.count, 3)
	assert_true(flags.has_flag(&"tabuas_encontradas"), "as 3 tábuas ativam a bandeira tabuas_encontradas")


func test_ines_quest_flow() -> void:
	var ines: QuestNpc = secrets.get_node(^"Ground/Ines") as QuestNpc
	assert_eq(ines.get_quest_state(), QuestNpc.QuestState.OFFER)

	# Jogador aceita a missão
	ines.request_interact()
	assert_eq(ines.get_quest_state(), QuestNpc.QuestState.ACTIVE)
	assert_true(flags.has_flag(&"ines_missao"))

	# Quando reúne as 3 tábuas, a missão fica pronta para entrega
	flags.set_flag(&"tabuas_encontradas")
	await wait_frames(1)
	assert_eq(ines.get_quest_state(), QuestNpc.QuestState.READY)


func test_false_wall_and_gold_mask_relic() -> void:
	var wall: FlagInteractable = secrets.get_node(^"Ground/FalseWall") as FlagInteractable
	var relic: FlagInteractable = secrets.get_node(^"Ground/RelicMask") as FlagInteractable

	assert_false(relic.active, "relíquia inativa antes da parede partir")
	assert_false(flags.has_flag(&"parede_partida"))

	# Bate na parede com a pá
	wall.request_interact()
	await wait_frames(1)
	assert_true(flags.has_flag(&"parede_partida"))
	assert_true(relic.active, "relíquia fica ativa após parede partir")
	assert_eq(relic.item_id, "mascara_ouro")
	assert_eq(relic.secret_id, "ruinas_reliquia_parede")

	relic.request_interact()
	assert_eq(relic.state, FlagInteractable.STATE_USED)


func test_silver_chalice_relic_in_niche() -> void:
	var chalice: FlagInteractable = secrets.get_node(^"Ground/RelicChalice") as FlagInteractable
	assert_eq(chalice.item_id, "calice_prata")
	assert_eq(chalice.secret_id, "ruinas_reliquia_nicho")

	chalice.request_interact()
	assert_eq(chalice.state, FlagInteractable.STATE_USED)


func test_ceremonial_dagger_relic_on_altar() -> void:
	var dagger: FlagInteractable = secrets.get_node(^"Ground/RelicDagger") as FlagInteractable
	assert_eq(dagger.item_id, "adaga_cerimonial")
	assert_eq(dagger.secret_id, "ruinas_reliquia_altar")

	dagger.request_interact()
	assert_eq(dagger.state, FlagInteractable.STATE_USED)


func test_crypt_pedestal_triggers_mummy_boss() -> void:
	var pedestal: FlagInteractable = secrets.get_node(^"Ground/CryptPedestal") as FlagInteractable
	var trigger: BossTrigger = secrets.get_node(^"MummyTrigger") as BossTrigger

	assert_false(trigger.triggered)
	assert_false(flags.has_flag(&"pedestal_idolo"))

	pedestal.request_interact()
	await wait_frames(1)
	assert_true(flags.has_flag(&"pedestal_idolo"))
	assert_true(trigger.triggered, "pedestal aciona o BossTrigger da Múmia")
	assert_not_null(trigger.boss)
	assert_true(trigger.boss is IdolMummy)


func test_easter_eggs() -> void:
	var mural: FlagInteractable = secrets.get_node(^"Ground/MuralDetector") as FlagInteractable
	assert_eq(mural.secret_id, "ruinas_ovo_pintura")
	mural.request_interact()
	assert_eq(mural.state, FlagInteractable.STATE_UNUSED, "repetível")

	var skeleton: FlagInteractable = secrets.get_node(^"Ground/SkeletonExplorer") as FlagInteractable
	assert_eq(skeleton.secret_id, "ruinas_ovo_esqueleto")
	skeleton.request_interact()
	assert_eq(skeleton.state, FlagInteractable.STATE_UNUSED, "repetível")


func test_map_ruinas_has_secrets_and_items_exist() -> void:
	var map: Node3D = MAP_RUINAS_SCENE.instantiate() as Node3D
	add_child_autofree(map)
	assert_not_null(map.get_node_or_null(^"RuinasSecrets"), "RuinasSecrets instanciada no map_ruinas.tscn")
	assert_not_null(map.get_node_or_null(^"GuardianAltar"), "GuardianAltar presente no map_ruinas.tscn")

	for item_id: String in ["idolo_jade", "ligaduras_mumia", "mascara_ouro", "calice_prata", "adaga_cerimonial", "nucleo_guardiao"]:
		assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % item_id), "item no catálogo: " + item_id)
