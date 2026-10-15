extends GutTest

## #41: sistemas novos do Campo (contador, chaves largadas, menires, silêncio, chefes).

const CROW_KING_SCENE: PackedScene = preload("res://gameplay/enemies/boss/crow_king.tscn")
const SCARECROW_SCENE: PackedScene = preload("res://gameplay/enemies/boss/scarecrow.tscn")
const CROW_SCENE: PackedScene = preload("res://gameplay/enemies/crow/crow.tscn")
const CAMPO_SECRETS: PackedScene = preload("res://gameplay/quests/campo/campo_secrets.tscn")

var world: Node3D
var flags: WorldFlags


func before_each() -> void:
	QuestRewards.reset_session()
	world = Node3D.new()
	add_child_autofree(world)
	flags = WorldFlags.new()
	world.add_child(flags)


func _keys(count: int) -> Array[FlagInteractable]:
	var out: Array[FlagInteractable] = []
	for i: int in count:
		var k: FlagInteractable = FlagInteractable.new()
		k.name = "Key%d" % i
		k.start_active = false
		k.hide_when_inactive = true
		k.once = true
		world.add_child(k)
		out.append(k)
	return out


func _wave(rounds: Array[String]) -> WaveEvent:
	var wave: WaveEvent = WaveEvent.new()
	wave.name = "Wave"
	wave.rounds = rounds
	wave.break_time = 0.1
	wave.spawn_stagger = 0.0
	world.add_child(wave)
	return wave


func test_quest_counter_sets_flag_once_each() -> void:
	var keys: Array[FlagInteractable] = _keys(3)
	for k: FlagInteractable in keys:
		k.set_active(true)
	var counter: QuestCounter = QuestCounter.new()
	counter.inputs = [^"../Key0", ^"../Key1", ^"../Key2"]
	counter.required = 3
	counter.success_flag = &"chaves"
	world.add_child(counter)
	keys[0].request_interact()
	keys[0].request_interact()
	keys[1].request_interact()
	assert_eq(counter.count, 2)
	assert_false(flags.has_flag(&"chaves"))
	keys[2].request_interact()
	assert_true(flags.has_flag(&"chaves"))


func test_drop_on_death_places_key_where_crow_fell() -> void:
	var keys: Array[FlagInteractable] = _keys(2)
	var wave: WaveEvent = _wave(["crow:1"])
	var drop: DropOnDeath = DropOnDeath.new()
	drop.wave_path = ^"../Wave"
	drop.pool = [^"../Key0", ^"../Key1"]
	world.add_child(drop)
	wave.start()
	wave._physics_process(2.5)
	wave._physics_process(0.05)
	var crow: Crow = null
	for c: Node in wave.get_children():
		if c is Crow:
			crow = c
	assert_not_null(crow)
	assert_true(crow.carries_key, "leva a chave no bico")
	assert_eq(drop.get_assigned(), 1)
	crow.global_position = Vector3(4.0, 0.0, 2.0)
	crow.call(&"_die")
	crow.free()
	assert_true(keys[0].active, "a chave apareceu")
	assert_almost_eq(keys[0].global_position.x, 4.0, 0.01)
	assert_false(keys[1].active)


func test_crow_without_dying_returns_its_key() -> void:
	_keys(1)
	var wave: WaveEvent = _wave(["crow:1"])
	var drop: DropOnDeath = DropOnDeath.new()
	drop.wave_path = ^"../Wave"
	drop.pool = [^"../Key0"]
	world.add_child(drop)
	wave.start()
	wave._physics_process(2.5)
	wave._physics_process(0.05)
	assert_eq(drop.get_assigned(), 1)
	for c: Node in wave.get_children():
		if c is Crow:
			c.free()
	assert_eq(drop.get_assigned(), 0, "sem morrer: a chave volta ao pool")


func test_menhir_puzzle_lights_and_resets() -> void:
	var stones: Array[RuneStone] = []
	var paths: Array[NodePath] = []
	for i: int in 4:
		var r: RuneStone = RuneStone.new()
		r.name = "R%d" % i
		world.add_child(r)
		stones.append(r)
		paths.append(NodePath("../R%d" % i))
	var puzzle: SequencePuzzle = SequencePuzzle.new()
	puzzle.inputs = paths
	puzzle.solution = PackedInt32Array([0, 1, 2, 3])
	puzzle.light_inputs = true
	puzzle.success_flag = &"menires"
	world.add_child(puzzle)
	stones[0].request_interact()
	stones[1].request_interact()
	assert_true(stones[0].is_lit() and stones[1].is_lit())
	stones[3].request_interact()
	for r: RuneStone in stones:
		assert_false(r.is_lit(), "um erro apaga todas")
	for r: RuneStone in stones:
		r.request_interact()
	assert_true(flags.has_flag(&"menires"))


func test_silence_trigger_needs_still_player() -> void:
	var player: CharacterBody3D = CharacterBody3D.new()
	player.add_to_group(&"players")
	world.add_child(player)
	var spot: SilenceTrigger = SilenceTrigger.new()
	spot.flag = &"ovelha"
	spot.quiet_seconds = 2.0
	world.add_child(spot)
	player.global_position = Vector3(3.0, 0.0, 0.0)
	for i: int in 3:
		spot._physics_process(0.5)
	assert_false(flags.has_flag(&"ovelha"))
	spot._physics_process(0.6)
	assert_true(flags.has_flag(&"ovelha"))
	player.velocity = Vector3(4.0, 0.0, 0.0)
	spot._physics_process(0.1)
	assert_false(flags.has_flag(&"ovelha"))


func test_boss_trigger_as_quest_event() -> void:
	var trig: BossTrigger = BossTrigger.new()
	trig.boss_kind = &"crow_king"
	world.add_child(trig)
	watch_signals(trig)
	assert_true(trig.start())
	assert_false(trig.start(), "só uma vez")
	assert_true(trig.boss is CrowKing)
	trig.boss.call(&"_die")
	assert_signal_emitted_with_parameters(trig, "finished", [true])


func test_crow_king_only_exposed_when_grounded() -> void:
	var king: CrowKing = CROW_KING_SCENE.instantiate() as CrowKing
	world.add_child(king)
	king.take_damage(50.0)
	assert_eq(king.health, 900.0, "imune a chegar")
	king.wake_immediately()
	king.take_damage(10.0)
	assert_eq(king.health, 890.0)
	king.call(&"_enter_state", CrowKing.State.GROUNDED)
	king.take_damage(10.0)
	assert_eq(king.health, 870.0, "pousado: dano a dobrar")


func test_scarecrow_dizzy_doubles_damage() -> void:
	var sc: Scarecrow = SCARECROW_SCENE.instantiate() as Scarecrow
	world.add_child(sc)
	sc.take_damage(50.0)
	assert_eq(sc.health, 1200.0, "imune a sair da terra")
	sc.wake_immediately()
	sc.call(&"_enter_state", Scarecrow.State.DIZZY)
	sc.take_damage(10.0)
	assert_eq(sc.health, 1180.0, "tonto: dano a dobrar")
	for kind: StringName in [&"crow", &"crow_king", &"scarecrow"]:
		assert_true(EnemySpawner.KIND_SCENES.has(kind), String(kind))


func test_crow_key_carrier_never_gives_up() -> void:
	var crow: Crow = CROW_SCENE.instantiate() as Crow
	world.add_child(crow)
	assert_eq(crow.max_dives, 4)
	crow.carries_key = true
	assert_gt(crow.max_dives, 100)


func test_campo_secrets_scene_wiring() -> void:
	var s: Node3D = CAMPO_SECRETS.instantiate() as Node3D
	world.add_child(s)
	await wait_frames(2)
	var lurdes: QuestNpc = s.get_node(^"Ground/Lurdes") as QuestNpc
	assert_eq(lurdes.quest_id, "lurdes_chaves")
	assert_true((s.get_node(^"ScarecrowTrigger") as BossTrigger).night)
	var bell: FlagInteractable = s.get_node(^"Ground/BellUse") as FlagInteractable
	assert_false(bell.active, "o sino só chama corvos depois de aceitar a missão")
	lurdes.request_interact()
	assert_true(WorldFlags.find(get_tree()).has_flag(&"lurdes_missao"))
	assert_true(bell.active)
	for id: String in ["sino_bronze", "anel_do_poco", "moeda_celta", "fibula_romana", "pena_corvo_rei", "lanterna_espantalho"]:
		assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % id), "catálogo: " + id)
