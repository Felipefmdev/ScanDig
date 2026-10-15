extends GutTest

## Coop fase 3 (#24): o que dá para testar sem rede (offline este processo é o host).

const SNAKE_SCENE: PackedScene = preload("res://gameplay/enemies/snake/snake.tscn")

var arena: Node3D


func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)


func _spawner() -> EnemySpawner:
	var spawner: EnemySpawner = EnemySpawner.new()
	spawner.primary_kind = &"snake"
	spawner.secondary_kind = &"mole"
	arena.add_child(spawner)
	return spawner


func test_spawn_goes_through_multiplayer_spawner_with_sync() -> void:
	var spawner: EnemySpawner = _spawner()
	var net: MultiplayerSpawner = spawner.get_node_or_null(NodePath(String(EnemySpawner.NET_SPAWNER_NAME))) as MultiplayerSpawner
	assert_not_null(net, "MultiplayerSpawner criado em código")
	assert_eq(net.get_node(net.spawn_path), spawner, "spawn_path aponta para o EnemySpawner")
	var data: Dictionary = EnemySpawner.make_spawn_data(&"snake", Vector3(2, 0, 3), 1)
	data["rot_y"] = 1.0
	var e: EnemyBase = spawner.spawn_from_data(data) as EnemyBase
	assert_not_null(e)
	assert_true(e.replicated)
	assert_not_null(e.get_net_sync(), "cada inimigo tem MultiplayerSynchronizer")
	var props: Array = e.get_net_sync().replication_config.get_properties()
	for p: String in [".:position", ".:rotation", ".:net_state", ".:health", ".:stunned", ".:fleeing"]:
		assert_has(props, NodePath(p))
	assert_almost_eq(e.global_position.x, 2.0, 0.001)
	assert_almost_eq(e.rotation.y, 1.0, 0.001)
	assert_true(e.has_simulation_authority(), "offline = host simula")
	assert_eq(EnemySpawner.find(get_tree()), spawner)


func test_net_state_mirrors_state() -> void:
	var s: Snake = SNAKE_SCENE.instantiate() as Snake
	arena.add_child(s)
	assert_eq(s.net_state, Snake.State.EMERGE)
	s.net_state = Snake.State.CHASE
	assert_eq(s.state, Snake.State.CHASE)


func test_host_validates_requests_by_distance_and_rate() -> void:
	var s: Snake = SNAKE_SCENE.instantiate() as Snake
	arena.add_child(s)
	var near: DamageDummy = DamageDummy.new()
	arena.add_child(near)
	near.global_position = Vector3(3, 0, 0)
	assert_true(s.accept_request(1), "jogador do peer 1 a 3 m")
	assert_false(s.accept_request(1), "segundo pedido logo a seguir: cadência")
	assert_false(s.accept_request(7), "peer sem jogador na cena")
	near.global_position = Vector3(EnemyBase.REQUEST_MAX_RANGE + 5.0, 0, 0)
	s.set("_last_request_ms", {})
	assert_false(s.accept_request(1), "longe demais")


func test_requests_apply_directly_on_host() -> void:
	var s: Snake = SNAKE_SCENE.instantiate() as Snake
	arena.add_child(s)
	for i: int in 40:
		s._physics_process(1.0 / 60.0)
	s.request_hit(10.0, Vector3.ZERO)
	assert_eq(s.health, 20.0)
	s.request_stun(1.0)
	assert_true(s.stunned)
	s.request_flee(Vector3.ZERO, 2.0)
	assert_true(s.fleeing)


func test_enemies_target_all_players_group() -> void:
	var s: Snake = SNAKE_SCENE.instantiate() as Snake
	arena.add_child(s)
	var remote: Node3D = Node3D.new()
	remote.add_to_group(&"players")
	arena.add_child(remote)
	remote.global_position = Vector3(2, 0, 0)
	var local: DamageDummy = DamageDummy.new()
	arena.add_child(local)
	local.global_position = Vector3(9, 0, 0)
	assert_eq(s._update_target(1.0), remote, "o mais próximo, mesmo que seja de outro peer")


func test_meter_is_host_offline() -> void:
	var meter: DisturbanceMeter = DisturbanceMeter.new()
	arena.add_child(meter)
	assert_false(meter.is_remote_client())
	meter.add_noise(10.0, Vector3.ZERO)
	assert_eq(meter.current_noise, 10.0)
	meter._rpc_sync(42.0, 1)
	assert_eq(meter.current_noise, 42.0, "o HUD do cliente usa o valor do host")


## Jogador falso com a API do Player (Dev_Player): _steal_from responde diretamente (host).
class FakeOwner:
	extends Node3D
	var loot: CarriedItem = null
	var damage_taken: float = 0.0

	func _ready() -> void:
		add_to_group(&"players")

	func _steal_from(gull_path: NodePath) -> void:
		var gull: Node = get_node_or_null(gull_path)
		var data: Dictionary = loot.to_dict() if loot != null else {}
		loot = null
		gull.call("request_seagull_loot", data)

	func take_damage(amount: float) -> void:
		damage_taken += amount


func _gull_and_owner(with_loot: bool) -> Array:
	var gull: Seagull = (load("res://gameplay/enemies/seagull/seagull.tscn") as PackedScene).instantiate() as Seagull
	var owner_node: FakeOwner = FakeOwner.new()
	if with_loot:
		var item: ItemData = load("res://items/catalog/lata_enferrujada.tres") as ItemData
		owner_node.loot = CarriedItem.create(item, 6, 1.0, false)
	arena.add_child(owner_node)
	arena.add_child(gull)
	gull._update_target(1.0)
	return [gull, owner_node]


func test_seagull_steals_through_owner() -> void:
	var pair: Array = _gull_and_owner(true)
	var gull: Seagull = pair[0]
	var owner_node: FakeOwner = pair[1]
	gull._grab(owner_node)
	assert_eq(gull.state, Seagull.State.ESCAPE, "o dono respondeu com o item: foge")
	assert_true(gull.has_stolen)
	assert_eq(gull.stolen.item.id, "lata_enferrujada")
	assert_null(owner_node.loot, "o item saiu da mochila do dono")


func test_seagull_pecks_when_owner_has_nothing() -> void:
	var pair: Array = _gull_and_owner(false)
	var gull: Seagull = pair[0]
	var owner_node: FakeOwner = pair[1]
	gull._grab(owner_node)
	assert_false(gull.has_stolen)
	assert_gt(owner_node.damage_taken, 0.0, "sem nada para roubar: bica")
