extends GutTest

## Testes de endurecimento dos pedidos de rede (Issue #48 - Fase 4 coop)
## Cobre: limites de dano por arma/pá, alcances nativos + folga 2m, rate limit 150ms,
## validação de peer_scene_ready e encerramento de public_visibility no synchronizer.

const SNAKE_SCENE: PackedScene = preload("res://gameplay/enemies/snake/snake.tscn")

class TestPlayerNode extends Node3D:
	var held_tool_id: StringName = &""
	var authority_id: int = 1
	var inventory: Node = null

	func _ready() -> void:
		add_to_group("players")
		set_multiplayer_authority(authority_id)


var arena: Node3D = null


func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)


func after_each() -> void:
	var sm: SessionManager = SessionManager.instance
	if sm != null:
		sm.set("_current_map", null)
		sm.set("_ready_peers", [])


func _spawn_player(peer_id: int = 1, tool_id: StringName = &"", pos: Vector3 = Vector3.ZERO) -> TestPlayerNode:
	var p: TestPlayerNode = TestPlayerNode.new()
	p.authority_id = peer_id
	p.held_tool_id = tool_id
	arena.add_child(p)
	p.global_position = pos
	return p


func _spawn_enemy(pos: Vector3 = Vector3.ZERO) -> Snake:
	var s: Snake = SNAKE_SCENE.instantiate() as Snake
	s.max_health = 100.0
	arena.add_child(s)
	s.state = Snake.State.CHASE
	s.health = 100.0
	s.global_position = pos
	return s


func test_spawn_player_uses_world_position_under_translated_parent() -> void:
	arena.position = Vector3(17, 3, -11)
	var expected: Vector3 = Vector3(22, 5, -4)
	var player: TestPlayerNode = _spawn_player(1, &"pa", expected)
	assert_eq(player.global_position, expected, "fixture deve posicionar depois de entrar na árvore")


# ---------------------------------------------------------------------------
# 1. Constantes de configuração e limites
# ---------------------------------------------------------------------------

func test_constants_values() -> void:
	assert_eq(EnemyBase.REQUEST_RANGE_MARGIN, 2.0, "Margem de folga deve ser 2.0m")
	assert_almost_eq(EnemyBase.RANGE_SHOVEL, 4.2, 0.01, "Pá: 2.2 + 2.0 = 4.2m")
	assert_almost_eq(EnemyBase.RANGE_PITCHFORK, 5.2, 0.01, "Forcado: 3.2 + 2.0 = 5.2m")
	assert_almost_eq(EnemyBase.RANGE_LANTERN, 11.0, 0.01, "Lanterna: 9.0 + 2.0 = 11.0m")
	assert_almost_eq(EnemyBase.RANGE_SLINGSHOT, 24.0, 0.01, "Estilingue: 22.0 + 2.0 = 24.0m")
	assert_almost_eq(EnemyBase.RANGE_REPELLENT, 7.5, 0.01, "Repelente: 5.5 + 2.0 = 7.5m")
	assert_almost_eq(EnemyBase.RANGE_NET_TRAP, 4.5, 0.01, "Armadilha rede: 4.5m")
	assert_almost_eq(EnemyBase.REQUEST_MAX_RANGE, 24.0, 0.01, "Teto máximo de alcance: 24.0m")
	assert_almost_eq(EnemyBase.REQUEST_MAX_DAMAGE, 35.0, 0.01, "Teto máximo de dano: 35.0")
	assert_eq(EnemyBase.REQUEST_MIN_INTERVAL_MS, 150, "Intervalo mínimo entre pedidos: 150ms")


# ---------------------------------------------------------------------------
# 2. Alcance por arma equipada (get_peer_max_range e accept_request)
# ---------------------------------------------------------------------------

func test_get_peer_max_range_by_tool() -> void:
	var e: Snake = _spawn_enemy()
	var p: TestPlayerNode = _spawn_player(1, &"pa")

	# Pá
	assert_almost_eq(e.get_peer_max_range(1, &"hit"), 4.2, 0.01)

	# Forcado
	p.held_tool_id = &"forcado"
	assert_almost_eq(e.get_peer_max_range(1, &"hit"), 5.2, 0.01)
	assert_almost_eq(e.get_peer_max_range(1, &"stun"), 5.2, 0.01)

	# Estilingue
	p.held_tool_id = &"estilingue"
	assert_almost_eq(e.get_peer_max_range(1, &"hit"), 24.0, 0.01)

	# Lanterna
	p.held_tool_id = &"lanterna_magnesio"
	assert_almost_eq(e.get_peer_max_range(1, &"stun"), 11.0, 0.01)
	assert_almost_eq(e.get_peer_max_range(1, &"flee"), 11.0, 0.01)

	# Repelente
	p.held_tool_id = &"repelente"
	assert_almost_eq(e.get_peer_max_range(1, &"flee"), 7.5, 0.01)

	# Armadilha de rede
	p.held_tool_id = &"armadilha_rede"
	assert_almost_eq(e.get_peer_max_range(1, &"hit"), 4.5, 0.01)
	assert_almost_eq(e.get_peer_max_range(1, &"stun"), 4.5, 0.01)


func test_accept_request_range_boundaries() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	var p: TestPlayerNode = _spawn_player(1, &"pa", Vector3.ZERO)

	# Pá: 4.0m aceita, 4.5m rejeita
	p.global_position = Vector3(4.0, 0.0, 0.0)
	assert_true(e.accept_request(1, &"hit"), "Pá a 4.0m deve ser aceite (<= 4.2m)")
	e.set("_last_request_ms", {})
	p.global_position = Vector3(4.5, 0.0, 0.0)
	assert_false(e.accept_request(1, &"hit"), "Pá a 4.5m deve ser rejeitada (> 4.2m)")

	# Forcado: 5.0m aceita, 5.5m rejeita
	p.held_tool_id = &"forcado"
	e.set("_last_request_ms", {})
	p.global_position = Vector3(5.0, 0.0, 0.0)
	assert_true(e.accept_request(1, &"hit"), "Forcado a 5.0m deve ser aceite (<= 5.2m)")
	e.set("_last_request_ms", {})
	p.global_position = Vector3(5.5, 0.0, 0.0)
	assert_false(e.accept_request(1, &"hit"), "Forcado a 5.5m deve ser rejeitado (> 5.2m)")

	# Estilingue: 23.0m aceita, 25.0m rejeita
	p.held_tool_id = &"estilingue"
	e.set("_last_request_ms", {})
	p.global_position = Vector3(23.0, 0.0, 0.0)
	assert_true(e.accept_request(1, &"hit"), "Estilingue a 23m deve ser aceite (<= 24.0m)")
	e.set("_last_request_ms", {})
	p.global_position = Vector3(25.0, 0.0, 0.0)
	assert_false(e.accept_request(1, &"hit"), "Estilingue a 25m deve ser rejeitado (> 24.0m)")

	# Lanterna (stun): 10.5m aceita, 11.5m rejeita
	p.held_tool_id = &"lanterna_magnesio"
	e.set("_last_request_ms", {})
	p.global_position = Vector3(10.5, 0.0, 0.0)
	assert_true(e.accept_request(1, &"stun"), "Lanterna stun a 10.5m deve ser aceite (<= 11.0m)")
	e.set("_last_request_ms", {})
	p.global_position = Vector3(11.5, 0.0, 0.0)
	assert_false(e.accept_request(1, &"stun"), "Lanterna stun a 11.5m deve ser rejeitada (> 11.0m)")

	# Repelente (flee): 7.0m aceita, 8.0m rejeita
	p.held_tool_id = &"repelente"
	e.set("_last_request_ms", {})
	p.global_position = Vector3(7.0, 0.0, 0.0)
	assert_true(e.accept_request(1, &"flee"), "Repelente flee a 7.0m deve ser aceite (<= 7.5m)")
	e.set("_last_request_ms", {})
	p.global_position = Vector3(8.0, 0.0, 0.0)
	assert_false(e.accept_request(1, &"flee"), "Repelente flee a 8.0m deve ser rejeitado (> 7.5m)")


# ---------------------------------------------------------------------------
# 3. Limites e clamping de dano em _rpc_request_hit
# ---------------------------------------------------------------------------

func test_damage_clamping_shovel() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	e.health = 100.0
	_spawn_player(1, &"pa", Vector3(2.0, 0.0, 0.0))

	# Dano normal da pá: 25.0
	e._rpc_request_hit(25.0, Vector3.ZERO)
	assert_almost_eq(e.health, 75.0, 0.01, "Dano normal de 25.0 reduz vida para 75.0")

	# Dano excessivo hackeado: 100.0 (deve ser clampado ao teto da pá: 35.0)
	e.set("_last_request_ms", {})
	e._rpc_request_hit(100.0, Vector3.ZERO)
	assert_almost_eq(e.health, 40.0, 0.01, "Dano de 100.0 clampado a 35.0 reduz vida para 40.0")


func test_damage_clamping_slingshot() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	e.health = 100.0
	var p: TestPlayerNode = _spawn_player(1, &"estilingue", Vector3(10.0, 0.0, 0.0))

	# À distância (10m): dano normal do estilingue é 20.0
	e._rpc_request_hit(20.0, Vector3.ZERO)
	assert_almost_eq(e.health, 80.0, 0.01, "Estilingue à distância dá 20.0 de dano")

	# À distância (10m): dano excessivo 90.0 é clampado a 20.0
	e.set("_last_request_ms", {})
	e._rpc_request_hit(90.0, Vector3.ZERO)
	assert_almost_eq(e.health, 60.0, 0.01, "Dano excessivo do estilingue à distância é clampado a 20.0")

	# Em corpo a corpo (2m): jogador com estilingue pode golpear com a pá (até 35.0)
	p.global_position = Vector3(2.0, 0.0, 0.0)
	e.set("_last_request_ms", {})
	e._rpc_request_hit(35.0, Vector3.ZERO)
	assert_almost_eq(e.health, 25.0, 0.01, "Golpe corpo a corpo em alcance de pá aceita até 35.0")


func test_damage_clamping_forcado_and_net_trap() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	e.health = 100.0
	var p: TestPlayerNode = _spawn_player(1, &"forcado", Vector3(3.0, 0.0, 0.0))

	# Forcado: pedido de 80.0 clampado a 35.0
	e._rpc_request_hit(80.0, Vector3.ZERO)
	assert_almost_eq(e.health, 65.0, 0.01, "Forcado clampa pedido excessivo para 35.0")

	# Armadilha de rede: pedido de 45.0 clampado a 15.0
	p.held_tool_id = &"armadilha_rede"
	e.set("_last_request_ms", {})
	e._rpc_request_hit(45.0, Vector3.ZERO)
	assert_almost_eq(e.health, 50.0, 0.01, "Armadilha de rede clampa pedido para 15.0")


func test_invalid_tool_and_zero_damage_rejected() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	e.health = 100.0
	var p: TestPlayerNode = _spawn_player(1, &"arma_hackeada_999", Vector3(2.0, 0.0, 0.0))

	# Ferramenta inválida / desconhecida
	e._rpc_request_hit(50.0, Vector3.ZERO)
	assert_almost_eq(e.health, 100.0, 0.01, "Ferramenta inválida é rejeitada e causa 0 dano")

	# Dano zero ou negativo
	p.held_tool_id = &"pa"
	e.set("_last_request_ms", {})
	e._rpc_request_hit(0.0, Vector3.ZERO)
	assert_almost_eq(e.health, 100.0, 0.01, "Dano 0 é ignorado")
	e.set("_last_request_ms", {})
	e._rpc_request_hit(-15.0, Vector3.ZERO)
	assert_almost_eq(e.health, 100.0, 0.01, "Dano negativo é ignorado")


# ---------------------------------------------------------------------------
# 4. Rate Limiting (150ms)
# ---------------------------------------------------------------------------

func test_rate_limiting_150ms() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	_spawn_player(1, &"pa", Vector3(2.0, 0.0, 0.0))

	# Primeiro pedido: aceite
	assert_true(e.accept_request(1), "Primeiro pedido aceite")

	# Segundo pedido imediato: rejeitado por cadência
	assert_false(e.accept_request(1), "Pedido consecutivo imediato deve ser rejeitado")

	# Simular passagem de 160ms
	var now: int = Time.get_ticks_msec()
	e.get("_last_request_ms")[1] = now - 160
	assert_true(e.accept_request(1), "Pedido após 160ms deve ser aceite")


# ---------------------------------------------------------------------------
# 5. Peer Scene Ready Check (SessionManager / CoreSession)
# ---------------------------------------------------------------------------

func test_peer_scene_ready_validation() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	_spawn_player(2, &"pa", Vector3(2.0, 0.0, 0.0))

	var sm: SessionManager = SessionManager.instance
	if sm == null:
		# Fallback em ambiente isolado sem SessionManager
		assert_true(e.is_peer_scene_ready(2), "Fallback sem session manager deve retornar true")
		return

	# Sem expedição ativa: handshake não é obrigatório (testes/bot/direto)
	sm.set("_current_map", null)
	assert_true(e.is_peer_scene_ready(2), "Fora de expedição conta como pronto")
	assert_true(e.accept_request(2), "Pedido aceite fora de expedição")

	# Com expedição ativa:
	var maps: Array[MapData] = sm.get_available_maps()
	if not maps.is_empty():
		sm.set("_current_map", maps[0])
		sm.set("_ready_peers", [1]) # Só host pronto; peer 2 ainda a carregar o mapa

		# Peer 2 ainda carregando
		e.set("_last_request_ms", {})
		assert_false(e.is_peer_scene_ready(2), "Peer 2 ainda a carregar não está pronto")
		assert_false(e.accept_request(2), "Pedido de peer não pronto é rejeitado")

		# Simular chegada de _rpc_request_hit do peer 2
		e.health = 100.0
		e.set("_last_request_ms", {})
		# Simulando chamada de outro peer: se sender_id for 2
		e._last_request_ms.clear()

		# Agora peer 2 termina de carregar
		sm.get("_ready_peers").append(2)
		assert_true(e.is_peer_scene_ready(2), "Peer 2 marcado como pronto")
		assert_true(e.accept_request(2), "Pedido do peer 2 agora é aceite")


# ---------------------------------------------------------------------------
# 6. Desligar public_visibility do MultiplayerSynchronizer
# ---------------------------------------------------------------------------

func test_synchronizer_public_visibility_shutdown() -> void:
	var e: Snake = _spawn_enemy(Vector3.ZERO)
	e.setup_network()

	var sync: MultiplayerSynchronizer = e.get_net_sync()
	assert_not_null(sync, "NetSync deve existir após setup_network")
	assert_true(sync.public_visibility, "public_visibility deve iniciar true")

	# Ao emitir expedition_ending, public_visibility deve passar a false
	e._on_expedition_ending("mapa_teste")
	assert_false(sync.public_visibility, "public_visibility deve ser false após expedition_ending")

	# Ao sair da cena (_exit_tree), também garante public_visibility = false
	sync.public_visibility = true
	e._exit_tree()
	assert_false(sync.public_visibility, "public_visibility deve ser false após _exit_tree")
