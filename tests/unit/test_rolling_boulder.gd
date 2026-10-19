extends GutTest

## Testes unitários para a Issue #110:
## Cratera: pedras que rolam e rochas instáveis.
## Cobre:
##   1) Estado estável/travado e componente de interação [E];
##   2) Desestabilização por empurrão, dano (pá/estilingue/arpão) e dinamite;
##   3) Rolamento físico morro abaixo;
##   4) Esmagamento de inimigos (dano alto, stun, repulsão);
##   5) Impacto em jogadores e tombamento de carrinhos de mão;
##   6) Quebra em alta velocidade contra paredões com drop de fragmento de meteorito.

const BOULDER_SCRIPT: Script = preload("res://gameplay/environment/rolling_boulder.gd")
const RollingBoulder = preload("res://gameplay/environment/rolling_boulder.gd")
const DYNAMITE_SCRIPT: Script = preload("res://gameplay/weapons/dynamite/dynamite.gd")
const WHEELBARROW_SCRIPT: Script = preload("res://gameplay/objects/wheelbarrow/wheelbarrow.gd")
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")

var _world: Node3D = null


func before_each() -> void:
	_world = Node3D.new()
	add_child_autofree(_world)


func test_boulder_initial_state_stable_and_interactable() -> void:
	var boulder: RollingBoulder = BOULDER_SCRIPT.new() as RollingBoulder
	_world.add_child(boulder)

	assert_eq(boulder.state, RollingBoulder.STATE_STABLE, "Rocha começa estável")
	assert_true(boulder.freeze, "Física congelada enquanto estável")
	assert_true(boulder.is_in_group(RollingBoulder.GROUP), "Está no grupo de rochas")
	assert_true(boulder.is_in_group(&"damageable"), "É damageable")

	var inter: Node = boulder.get_node_or_null("Interactable")
	assert_not_null(inter, "Possui componente Interactable para empurrão")
	assert_eq(inter.get("prompt"), "[E] Empurrar rocha instável", "Prompt de interação [E]")


func test_boulder_dislodge_and_launch_roll() -> void:
	var boulder: RollingBoulder = BOULDER_SCRIPT.new() as RollingBoulder
	_world.add_child(boulder)

	watch_signals(boulder)

	# 1. Desestabiliza com direção definida
	var dir: Vector3 = Vector3(1.0, 0.0, 0.0)
	boulder.dislodge(dir)

	assert_eq(boulder.state, RollingBoulder.STATE_TEETERING, "Entra em oscilação pré-rolamento")
	assert_almost_eq(boulder.roll_direction.x, 1.0, 0.01)

	# 2. Simula teetering até soltar
	boulder._physics_process(0.50)

	assert_eq(boulder.state, RollingBoulder.STATE_ROLLING, "Transiciona para rolando")
	assert_false(boulder.freeze, "Física liberada para rolar")
	assert_gt(boulder.linear_velocity.length(), 0.0, "Ganhou impulso para descer")
	assert_signal_emitted(boulder, "dislodged", "Sinal dislodged emitido")


func test_boulder_dislodged_by_damage_and_blast() -> void:
	var b1: RollingBoulder = BOULDER_SCRIPT.new() as RollingBoulder
	_world.add_child(b1)
	b1.global_position = Vector3(5.0, 0.0, 0.0)

	# Golpe de ferramenta (from_pos a oeste empurra para leste)
	b1.take_damage(20.0, Vector3(0.0, 0.0, 0.0))
	assert_eq(b1.state, RollingBoulder.STATE_TEETERING, "Golpe desestabilizou a rocha")
	assert_gt(b1.roll_direction.x, 0.0, "Direção para longe do ponto do golpe")

	# Explosão de dinamite
	var b2: RollingBoulder = BOULDER_SCRIPT.new() as RollingBoulder
	_world.add_child(b2)
	b2.global_position = Vector3(0.0, 0.0, 3.0)

	var blast_res: Dictionary = DYNAMITE_SCRIPT.apply_blast(get_tree(), Vector3.ZERO, null)
	assert_true(blast_res.has("boulders"), "Resultado da explosão registra rochas")
	assert_gt(blast_res["boulders"], 0, "Atingiu rochas no raio da explosão")
	assert_eq(b2.state, RollingBoulder.STATE_TEETERING, "Dinamite desestabilizou a rocha próxima")


func test_rolling_boulder_crushes_enemy() -> void:
	var boulder: RollingBoulder = BOULDER_SCRIPT.new() as RollingBoulder
	_world.add_child(boulder)
	boulder.dislodge(Vector3(1.0, 0.0, 0.0))
	boulder._launch_roll()
	boulder.linear_velocity = Vector3(6.0, 0.0, 0.0)

	var crab: Crab = CRAB_SCENE.instantiate() as Crab
	_world.add_child(crab)
	crab.global_position = Vector3(2.0, 0.0, 0.0)
	crab._enter_state(Crab.State.CHASE)
	crab.max_health = 150.0
	crab.health = 150.0
	var hp_before: float = crab.health

	watch_signals(boulder)

	boulder._handle_hit_target(crab)

	assert_lt(crab.health, hp_before, "Inimigo recebeu dano de esmagamento")
	assert_almost_eq(crab.health, hp_before - RollingBoulder.CRUSH_DAMAGE_ENEMY, 0.1)
	assert_true(crab.is_stunned(), "Inimigo atordoado pelo impacto")
	assert_signal_emitted(boulder, "crushed_target", "Sinal crushed_target emitido")


func test_rolling_boulder_hits_player_and_wheelbarrow() -> void:
	var boulder: RollingBoulder = BOULDER_SCRIPT.new() as RollingBoulder
	_world.add_child(boulder)
	boulder.dislodge(Vector3(1.0, 0.0, 0.0))
	boulder._launch_roll()
	boulder.linear_velocity = Vector3(5.0, 0.0, 0.0)

	# 1. Jogador
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.set_physics_process(false)
	var hp_before: float = player.health

	boulder._handle_hit_target(player)
	assert_lt(player.health, hp_before, "Jogador atropelado sofre dano")
	assert_almost_eq(player.health, hp_before - RollingBoulder.CRUSH_DAMAGE_PLAYER, 0.1)

	# 2. Carrinho de mão
	var wb: CharacterBody3D = WHEELBARROW_SCRIPT.new() as CharacterBody3D
	_world.add_child(wb)
	wb.set_physics_process(false)
	assert_false(wb.get("is_tipped"), "Carrinho de pé")

	boulder._handle_hit_target(wb)
	assert_true(wb.get("is_tipped"), "Carrinho tombou com o atropelamento da rocha")


func test_boulder_shatters_on_high_speed_impact() -> void:
	var boulder: RollingBoulder = BOULDER_SCRIPT.new() as RollingBoulder
	_world.add_child(boulder)
	boulder.drops_loot_on_shatter = false # sem precisar de PickupsRoot no teste isolado
	boulder.dislodge(Vector3(1.0, 0.0, 0.0))
	boulder._launch_roll()
	boulder.linear_velocity = Vector3(14.0, 0.0, 0.0) # alta velocidade

	watch_signals(boulder)

	var wall: StaticBody3D = StaticBody3D.new()
	_world.add_child(wall)

	boulder._on_contact(wall)

	assert_eq(boulder.state, RollingBoulder.STATE_SHATTERED, "Pedra se despedaça no choque")
	assert_signal_emitted(boulder, "shattered", "Sinal shattered emitido")
