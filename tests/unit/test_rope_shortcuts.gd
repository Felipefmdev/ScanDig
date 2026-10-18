extends GutTest

## Testes unitários para Tirolesa e Ponte de Corda com o Arpão (#105).

const ROPE_ANCHOR_SCRIPT: Script = preload("res://gameplay/objects/shortcuts/rope_anchor.gd")
const ROPE_SHORTCUT_SCRIPT: Script = preload("res://gameplay/objects/shortcuts/rope_shortcut.gd")
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var arena: Node3D = null


func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)
	if GameState.instance != null:
		GameState.instance.reset_state()


func test_rope_anchor_creation_and_groups() -> void:
	var anchor: RopeAnchor = ROPE_ANCHOR_SCRIPT.new() as RopeAnchor
	anchor.anchor_id = "test_a"
	anchor.pair_anchor_id = "test_b"
	anchor.shortcut_id = "test_sc"
	arena.add_child(anchor)
	anchor.position = Vector3(10.0, 5.0, -12.0)

	assert_true(anchor.is_in_group(RopeAnchor.GROUP), "Deve estar no grupo rope_anchors")
	assert_true(anchor.is_in_group(&"interactive"), "Deve estar no grupo interactive")

	var hook_pt: Vector3 = anchor.get_hook_point()
	assert_almost_eq(hook_pt.y, 6.35, 0.05, "Ponto de gancho deve ser no topo do poste")

	anchor.set_hooked(true)
	assert_true(anchor.is_hooked, "Poste deve marcar como fisgado")


func test_create_shortcut_helper_and_linking() -> void:
	var pos1: Vector3 = Vector3(0.0, 10.0, 0.0)
	var pos2: Vector3 = Vector3(0.0, 2.0, 20.0)
	var sc: RopeShortcut = ROPE_SHORTCUT_SCRIPT.call("create_shortcut", arena, "sc_zipline_test", "Tirolesa de Teste", "zipline", pos1, pos2) as RopeShortcut

	assert_not_null(sc, "Atalho deve ser criado")
	assert_true(sc.is_in_group(RopeShortcut.GROUP), "Deve estar no grupo rope_shortcuts")
	assert_not_null(sc.anchor_a, "Âncora A deve estar vinculada")
	assert_not_null(sc.anchor_b, "Âncora B deve estar vinculada")
	assert_false(sc.is_built, "Atalho novo não deve iniciar construído")

	sc.build()
	assert_true(sc.is_built, "Atalho deve ficar construído")
	assert_true(sc.anchor_a.is_hooked, "Âncora A deve estar marcada como hooked")
	assert_true(sc.anchor_b.is_hooked, "Âncora B deve estar marcada como hooked")
	assert_almost_eq(sc.get_zipline_start().y, sc.anchor_a.get_hook_point().y, 0.1, "Início da tirolesa deve ser no ponto mais alto")


func test_rope_bridge_physical_collider() -> void:
	var pos1: Vector3 = Vector3(-10.0, 1.0, 0.0)
	var pos2: Vector3 = Vector3(10.0, 1.0, 0.0)
	var bridge_sc: RopeShortcut = ROPE_SHORTCUT_SCRIPT.call("create_shortcut", arena, "sc_bridge_test", "Ponte de Teste", "rope_bridge", pos1, pos2) as RopeShortcut

	bridge_sc.build()
	assert_true(bridge_sc.is_built, "Ponte de corda deve ser construída")

	# Verifica presença do corpo físico sólido para colisão de jogadores e carrinhos
	var collider_found: bool = false
	for child: Node in bridge_sc.find_children("*", "StaticBody3D", true, false):
		var sb: StaticBody3D = child as StaticBody3D
		if sb != null and (sb.collision_layer & 1) != 0:
			collider_found = true
			break
	assert_true(collider_found, "Ponte de corda deve conter StaticBody3D com layer 1 para colisão física sólida")


func test_game_state_and_save_persistence() -> void:
	assert_not_null(GameState.instance, "GameState deve estar instanciado")
	assert_false(GameState.instance.is_shortcut_built("sc_test_save"), "Atalho não deve estar construído de início")

	GameState.instance.build_shortcut("sc_test_save")
	assert_true(GameState.instance.is_shortcut_built("sc_test_save"), "build_shortcut deve registrar o atalho")

	var snap: Dictionary = GameState.instance.get_snapshot()
	assert_true(snap.has("built_shortcuts"), "Snapshot deve conter built_shortcuts")
	var sc_list: Array = snap["built_shortcuts"] as Array
	assert_true(sc_list.has("sc_test_save"), "Snapshot deve conter o id do atalho")

	# Reset e restauração de snapshot
	GameState.instance.reset_state()
	assert_false(GameState.instance.is_shortcut_built("sc_test_save"), "reset_state deve limpar atalhos")

	GameState.instance.apply_snapshot(snap)
	assert_true(GameState.instance.is_shortcut_built("sc_test_save"), "apply_snapshot deve restaurar atalhos salvos")


func test_player_zipline_travel_and_completion() -> void:
	var p: Player = PLAYER_SCENE.instantiate() as Player
	arena.add_child(p)

	var pos_high: Vector3 = Vector3(0.0, 15.0, 0.0)
	var pos_low: Vector3 = Vector3(0.0, 0.0, 30.0)
	var sc: RopeShortcut = ROPE_SHORTCUT_SCRIPT.call("create_shortcut", arena, "sc_player_zip", "Tirolesa do Jogador", "zipline", pos_high, pos_low) as RopeShortcut
	sc.build()

	p.global_position = pos_high + Vector3(0.0, 1.0, 0.0)
	assert_true(sc.can_player_zipline(p), "Jogador perto do ponto de partida deve poder usar tirolesa")

	p.start_ziplining(sc)
	assert_true(p.is_ziplining, "Jogador deve entrar no estado is_ziplining")
	assert_almost_eq(p.global_position.y, sc.get_zipline_start().y - 1.2, 0.2, "Jogador deve estar posicionado no cabo")

	# Simula o avanço do slide na tirolesa
	p._process_zipline(1.5)
	assert_true(p.is_ziplining, "Ainda deve estar deslizando após 1.5s")

	# Simula tempo suficiente para completar a descida
	p._process_zipline(5.0)
	assert_false(p.is_ziplining, "Deve sair do estado is_ziplining ao atingir o destino")
