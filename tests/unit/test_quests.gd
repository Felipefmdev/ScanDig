extends GutTest

## #39: sistemas genéricos de missões/eventos (em solo, sem rede: tudo corre "no host").

const OCTOPUS_SCENE: PackedScene = preload("res://gameplay/enemies/boss/octopus.tscn")
const PRAIA_SECRETS: PackedScene = preload("res://gameplay/quests/praia/praia_secrets.tscn")

var world: Node3D
var flags: WorldFlags


## Evento falso para o NPC: start() e finished(success).
class FakeEvent extends Node:
	signal finished(success: bool)
	var started: int = 0

	func start() -> bool:
		started += 1
		return true


func before_each() -> void:
	QuestRewards.reset_session()
	if GameState.instance != null:
		GameState.instance.completed_quests.clear()
		GameState.instance.found_secrets.clear()
	world = Node3D.new()
	add_child_autofree(world)
	flags = WorldFlags.new()
	world.add_child(flags)


func _interactable(script_obj: GDScript = null) -> Interactable:
	var it: Interactable = (script_obj.new() if script_obj != null else Interactable.new()) as Interactable
	world.add_child(it)
	return it


func test_world_flags_set_and_when_set() -> void:
	var fired: Array[int] = [0]
	flags.when_set(&"porta", func() -> void: fired[0] += 1)
	assert_false(flags.has_flag(&"porta"))
	flags.set_flag(&"porta")
	assert_true(flags.has_flag(&"porta"))
	assert_eq(fired[0], 1)
	flags.set_flag(&"porta", false)
	flags.set_flag(&"porta")
	assert_eq(fired[0], 1, "when_set corre uma vez só")
	assert_eq(WorldFlags.find(get_tree()), flags)


func test_interactable_once() -> void:
	var it: Interactable = _interactable()
	it.once = true
	watch_signals(it)
	it.request_interact()
	assert_signal_emit_count(it, "interacted", 1)
	assert_false(it.active, "once: fica inativo")
	it.request_interact()
	assert_signal_emit_count(it, "interacted", 1)


func test_sequence_puzzle_order_and_reset() -> void:
	var shells: Array[Interactable] = []
	for i: int in 3:
		var s: Interactable = _interactable()
		s.name = "S%d" % i
		shells.append(s)
	var puzzle: SequencePuzzle = SequencePuzzle.new()
	puzzle.inputs = [^"../S0", ^"../S1", ^"../S2"]
	puzzle.solution = PackedInt32Array([2, 0, 1])
	puzzle.success_flag = &"conchas"
	world.add_child(puzzle)
	shells[2].request_interact()
	shells[1].request_interact()  # errado: recomeça
	assert_eq(puzzle.progress, 0)
	shells[2].request_interact()
	shells[0].request_interact()
	assert_false(flags.has_flag(&"conchas"))
	shells[1].request_interact()
	assert_true(puzzle.is_solved)
	assert_true(flags.has_flag(&"conchas"))


func test_flag_interactable_requires_and_sets() -> void:
	var relic: FlagInteractable = FlagInteractable.new()
	relic.requires_flag = &"pedra"
	relic.sets_flag = &"achado"
	relic.secret_id = "praia_reliquia_pedra"
	world.add_child(relic)
	await wait_frames(2)
	assert_false(relic.active, "sem a bandeira fica escondido")
	assert_false(relic.visible)
	relic.request_interact()
	assert_false(flags.has_flag(&"achado"))
	flags.set_flag(&"pedra")
	assert_true(relic.active)
	relic.request_interact()
	assert_true(flags.has_flag(&"achado"))
	assert_eq(relic.state, FlagInteractable.STATE_USED)
	await wait_frames(1)  # o pedido ao core é adiado (call_deferred)
	assert_true(QuestRewards.is_secret_found("praia_reliquia_pedra"), "segredo registado (core #45)")
	assert_false(relic.active, "usado e sem used_prompt: fica inativo")


func test_quest_npc_full_flow() -> void:
	var ev: FakeEvent = FakeEvent.new()
	ev.name = "Ev"
	world.add_child(ev)
	var npc: QuestNpc = QuestNpc.new()
	npc.quest_id = "ze_anzol"
	npc.objective_flag = &"objetivo"
	npc.event_path = ^"../Ev"
	world.add_child(npc)
	await wait_frames(2)
	assert_eq(npc.state, QuestNpc.QuestState.OFFER)
	npc.request_interact()
	assert_eq(npc.state, QuestNpc.QuestState.ACTIVE)
	npc.request_interact()
	assert_eq(npc.state, QuestNpc.QuestState.ACTIVE, "sem objetivo não avança")
	flags.set_flag(&"objetivo")
	assert_eq(npc.state, QuestNpc.QuestState.READY)
	npc.request_interact()
	assert_eq(ev.started, 1)
	assert_eq(npc.state, QuestNpc.QuestState.EVENT)
	ev.finished.emit(false)
	assert_eq(npc.state, QuestNpc.QuestState.READY, "falhou: tenta outra vez")
	npc.request_interact()
	ev.finished.emit(true)
	assert_eq(npc.state, QuestNpc.QuestState.DONE)
	await wait_frames(1)  # o pedido ao core é adiado (call_deferred)
	assert_true(QuestRewards.is_quest_completed("ze_anzol"), "missão registada (core #45)")


func test_wave_event_rounds_and_win() -> void:
	var wave: WaveEvent = WaveEvent.new()
	wave.rounds = ["crab:1", "crab:2"]
	wave.break_time = 0.1
	wave.spawn_stagger = 0.0
	world.add_child(wave)
	watch_signals(wave)
	assert_true(wave.start())
	assert_false(wave.start(), "não começa duas vezes")
	for round_index: int in 2:
		wave._physics_process(2.5)  # acaba a pausa
		for i: int in 3:
			wave._physics_process(0.05)  # nascem os inimigos
		assert_eq(wave.phase, WaveEvent.Phase.FIGHT)
		assert_eq(wave.round_number, round_index + 1)
		for c: Node in wave.get_children():
			if c is EnemyBase:
				c.call(&"_die")
		await wait_frames(1)
		wave._physics_process(0.05)
	assert_eq(wave.phase, WaveEvent.Phase.WON)
	assert_signal_emitted_with_parameters(wave, "finished", [true])


func test_wave_event_fails_when_defended_target_dies() -> void:
	var boat: Node3D = Node3D.new()
	boat.name = "Boat"
	world.add_child(boat)
	var wave: WaveEvent = WaveEvent.new()
	wave.rounds = ["crab:1"]
	wave.break_time = 0.1
	wave.spawn_stagger = 0.0
	wave.spawn_radius_min = 0.5
	wave.spawn_radius_max = 0.6
	wave.defend_path = ^"../Boat"
	wave.defend_radius = 3.0
	wave.defend_max_hp = 10.0
	wave.defend_damage_per_enemy = 10.0
	world.add_child(wave)
	watch_signals(wave)
	wave.start()
	wave._physics_process(2.5)
	wave._physics_process(0.05)
	for i: int in 5:
		wave._physics_process(0.5)
	assert_eq(wave.phase, WaveEvent.Phase.LOST)
	assert_signal_emitted_with_parameters(wave, "finished", [false])


func test_octopus_weak_point_and_reinforcements() -> void:
	var oct: Octopus = OCTOPUS_SCENE.instantiate() as Octopus
	world.add_child(oct)
	assert_true(oct.is_in_group("bosses"))
	oct.take_damage(50.0)
	assert_eq(oct.health, 450.0, "imune a sair da água")
	oct.wake_immediately()
	oct.take_damage(10.0)
	assert_eq(oct.health, 440.0)
	oct.call("_enter_state", Octopus.State.STUCK)
	oct.take_damage(10.0)
	assert_eq(oct.health, 420.0, "tentáculo preso: cabeça exposta, dano a dobrar")
	oct.call("_enter_state", Octopus.State.IDLE)
	oct.take_damage(140.0)  # passa os 66 %
	var crabs: int = 0
	for c: Node in world.get_children():
		if c is Crab:
			crabs += 1
	assert_eq(crabs, 2, "chama 2 caranguejos aos 66 %")
	assert_true(EnemySpawner.KIND_SCENES.has(&"octopus"))


func test_tide_sets_low_flag() -> void:
	var tide: TideCycle = TideCycle.new()
	tide.start_time = 140.0
	world.add_child(tide)
	tide._process(0.1)
	assert_false(flags.has_flag(&"mare_baixa"))
	tide._process(10.0)  # passa o fim do ciclo (150 s) → maré baixa
	assert_true(flags.has_flag(&"mare_baixa"))
	assert_almost_eq(tide.get_low_amount(), 1.0, 0.001)


func test_praia_secrets_scene_wiring() -> void:
	var s: Node3D = PRAIA_SECRETS.instantiate() as Node3D
	world.add_child(s)
	await wait_frames(2)
	var ze: QuestNpc = s.get_node(^"Ze") as QuestNpc
	assert_not_null(ze)
	assert_eq(ze.quest_id, "ze_anzol")
	assert_true(s.get_node(^"RedTide") is WaveEvent)
	assert_true(s.get_node(^"Ground/ShellPink") is MusicShell)
	var hook: FlagInteractable = s.get_node(^"Ground/Hook") as FlagInteractable
	assert_false(hook.active, "o anzol só aparece depois de cavado")
	for id: String in ["concha_dourada", "bussola_naufragio", "medalhao_sereia", "mapa_na_garrafa", "olho_do_polvo", "moeda_chocolate"]:
		assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % id), "catálogo: " + id)
	# Puzzle das conchas → Polvo (sem spawner: nasce localmente)
	# Neste teste há 2 WorldFlags (o do before_each e o da cena): todos usam o primeiro (find()).
	var flags2: WorldFlags = WorldFlags.find(get_tree())
	for shell: String in ["ShellPink", "ShellBlue", "ShellGold"]:
		(s.get_node(NodePath("Ground/" + shell)) as Interactable).request_interact()
	assert_true(flags2.has_flag(&"conchas_tocadas"))
	var trigger: BossTrigger = s.get_node(^"OctopusTrigger") as BossTrigger
	assert_true(trigger.triggered)
	assert_true(trigger.boss is Octopus)
