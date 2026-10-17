class_name EnemySpawner
extends Node3D

## Faz surgir inimigos:
##  - por limiar de ameaça (DisturbanceMeter.threshold_reached), perto da origem do barulho:
##      nível 1: caranguejos; nível 2: caranguejos + ermitão; nível 3: 4 caranguejos + ermitão + gaivota;
##  - ambiente (pressão mesmo sem barulho): um caranguejo a 12-20 m do jogador a cada
##    ambient_interval_min..max s, e uma gaivota a cada seagull_interval_min..max s se o
##    jogador tiver itens escavados na mochila (player.has_loot()).
## Nunca passa de max_alive inimigos de chão vivos criados por este spawner; a gaivota tem
## vaga própria (max_seagulls), para os caranguejos do nível 3 não a deixarem de fora (#31).
##
## Os inimigos são criados por dados {"kind", "pos", "level"[, "rot_y"]} (spawn_from_data).
## Coop (#5 F, #24): só o host cria inimigos (e corre a IA). O spawner monta em código um
## MultiplayerSpawner filho ("EnemyNetSpawner", spawn_path = este nó) com o mesmo nome em
## todos os peers; os mesmos dados recriam o inimigo nos clientes, já com setup_network().
## Chefes (BossAltar) e reforços também passam por aqui (EnemySpawner.find()). Cada mapa
## escolhe os kinds: primary_kind (o "caranguejo" do mapa), secondary_kind (o "ermitão")
## e ambient_kinds. As tabelas por nível do DifficultyProfile continuam a contar
## primário/secundário/gaivota.

signal enemy_spawned(enemy: Node3D)

const DEFAULT_CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")
const DEFAULT_HERMIT_SCENE: PackedScene = preload("res://gameplay/enemies/crab/hermit_crab.tscn")
const DEFAULT_SEAGULL_SCENE: PackedScene = preload("res://gameplay/enemies/seagull/seagull.tscn")
## kind -> cena. Carregadas a pedido (load), para não criar ciclos de preload com os chefes.
const KIND_SCENES: Dictionary = {
	&"crab": "res://gameplay/enemies/crab/crab.tscn",
	&"hermit_crab": "res://gameplay/enemies/crab/hermit_crab.tscn",
	&"seagull": "res://gameplay/enemies/seagull/seagull.tscn",
	&"king_crab": "res://gameplay/enemies/boss/king_crab.tscn",
	&"snake": "res://gameplay/enemies/snake/snake.tscn",
	&"mole": "res://gameplay/enemies/mole/mole.tscn",
	&"giant_mole": "res://gameplay/enemies/boss/giant_mole.tscn",
	&"octopus": "res://gameplay/enemies/boss/octopus.tscn",
	&"crow": "res://gameplay/enemies/crow/crow.tscn",
	&"crow_king": "res://gameplay/enemies/boss/crow_king.tscn",
	&"scarecrow": "res://gameplay/enemies/boss/scarecrow.tscn",
	&"stone_guardian": "res://gameplay/enemies/stone_guardian/stone_guardian.tscn",
	&"bat": "res://gameplay/enemies/bat/bat.tscn",
	&"ancient_guardian": "res://gameplay/enemies/boss/ancient_guardian.tscn",
	&"idol_mummy": "res://gameplay/enemies/boss/idol_mummy.tscn",
	&"gold_colossus": "res://gameplay/enemies/boss/gold_colossus.tscn",
	&"ice_wolf": "res://gameplay/enemies/ice_wolf/ice_wolf.tscn",
	&"penguin": "res://gameplay/enemies/penguin/penguin.tscn",
	&"walrus": "res://gameplay/enemies/walrus/walrus.tscn",
	&"frozen_mammoth": "res://gameplay/enemies/boss/frozen_mammoth.tscn",
	&"ancient_walrus": "res://gameplay/enemies/boss/ancient_walrus.tscn",
	&"cave_yeti": "res://gameplay/enemies/boss/cave_yeti.tscn",
	&"crawler": "res://gameplay/enemies/crawler/crawler.tscn",
	&"floater": "res://gameplay/enemies/floater/floater.tscn",
	&"the_sleeper": "res://gameplay/enemies/boss/the_sleeper.tscn",
	&"the_echo": "res://gameplay/enemies/boss/the_echo.tscn",
}

## Inimigo base do mapa (níveis de ameaça e ambiente) e o "resistente" a partir do nível 2.
@export var primary_kind: StringName = &"crab"
@export var secondary_kind: StringName = &"hermit_crab"
## Kinds sorteados nos spawns ambiente; vazio = só primary_kind.
@export var ambient_kinds: Array[StringName] = []
## Sobrepõem a cena de primary/secondary/gaivota (compatibilidade e testes).
@export var crab_scene: PackedScene = null
@export var hermit_scene: PackedScene = null
@export var seagull_scene: PackedScene = null
@export var max_alive: int = 6
## Gaivotas vivas ao mesmo tempo (vaga à parte de max_alive).
@export var max_seagulls: int = 1
## Usa DifficultyProfile (nº de jogadores) para max_alive, tabelas por nível, graça, intervalos
## e dano. Desligado: usa os @export deste nó tal como estão.
@export var use_player_scaling: bool = true

@export_group("Por limiar de ameaça")
## Quantos de cada surgem por nível de ameaça (índice 0 = nível 1).
@export var spawns_per_level: Array[int] = [1, 2, 4]
@export var hermits_per_level: Array[int] = [0, 1, 1]
@export var seagulls_per_level: Array[int] = [0, 0, 1]
@export var min_spawn_radius: float = 4.0
@export var max_spawn_radius: float = 8.0

@export_group("Ambiente")
@export var ambient_enabled: bool = true
@export var ambient_interval_min: float = 45.0
@export var ambient_interval_max: float = 90.0
@export var ambient_radius_min: float = 12.0
@export var ambient_radius_max: float = 20.0
@export var seagull_interval_min: float = 60.0
@export var seagull_interval_max: float = 120.0
## Distância horizontal ao jogador a que a gaivota aparece, e altura.
@export var seagull_spawn_distance: float = 25.0
@export var seagull_spawn_height: float = 9.0

@export_group("Chão")
## Máscara de colisão usada para encontrar o chão.
@export_flags_3d_physics var ground_mask: int = 1

const RAY_HEIGHT: float = 10.0
const RAY_DEPTH: float = 20.0
const SPAWN_ATTEMPTS: int = 8
## Pontos cujo chão difere mais do que isto da referência (paredes, rochas altas) são rejeitados.
const MAX_GROUND_STEP: float = 1.5
## Se não há loot quando a gaivota calha, volta a verificar passado este tempo.
const SEAGULL_RETRY: float = 10.0
const GROUP: StringName = &"enemy_spawners"
const NET_SPAWNER_NAME: StringName = &"EnemyNetSpawner"

var _alive: Array[Node3D] = []
var _gulls: Array[Node3D] = []
var _connected: bool = false
var _ambient_timer: float = 0.0
var _seagull_timer: float = 0.0
var _elapsed: float = 0.0
var _net_spawner: MultiplayerSpawner = null


func _ready() -> void:
	add_to_group(GROUP)
	_net_spawner = MultiplayerSpawner.new()
	_net_spawner.name = NET_SPAWNER_NAME
	_net_spawner.spawn_function = _create_from_data
	add_child(_net_spawner)
	_net_spawner.spawn_path = _net_spawner.get_path_to(self)
	if crab_scene == null:
		crab_scene = scene_for_kind(primary_kind)
		if crab_scene == null and primary_kind != &"":
			push_warning("[EnemySpawner] primary_kind sem cena valida: '%s'" % primary_kind)
	if hermit_scene == null:
		hermit_scene = scene_for_kind(secondary_kind)
		if hermit_scene == null and secondary_kind != &"":
			push_warning("[EnemySpawner] secondary_kind sem cena valida: '%s'" % secondary_kind)
	if seagull_scene == null:
		seagull_scene = DEFAULT_SEAGULL_SCENE
	for ak: StringName in ambient_kinds:
		if not has_scene_for_kind(ak):
			push_warning("[EnemySpawner] ambient_kind sem cena valida: '%s'" % ak)
	# O primeiro caranguejo ambiente chega mais cedo (pressão logo no 1.º minuto)
	_ambient_timer = randf_range(ambient_interval_min, ambient_interval_max) * _interval_multiplier() * 0.5
	_seagull_timer = randf_range(seagull_interval_min, seagull_interval_max) * _interval_multiplier()
	_try_connect()


func _process(delta: float) -> void:
	if not can_spawn():
		return
	# O DisturbanceMeter pode entrar na árvore depois deste nó; tentamos até ligar.
	if not _connected:
		_try_connect()
	if ambient_enabled:
		_process_ambient(delta)


func _try_connect() -> void:
	if DisturbanceMeter.instance == null:
		return
	DisturbanceMeter.instance.threshold_reached.connect(_on_threshold_reached)
	_connected = true


# ---------------------------------------------------------------------------
# Spawns por limiar
# ---------------------------------------------------------------------------

func _on_threshold_reached(level: int, origin: Vector3) -> void:
	if level <= 0:
		return
	for i: int in range(_count_for_level(_crab_table(), level)):
		_spawn_ground(primary_kind, origin, min_spawn_radius, max_spawn_radius, level)
	for i: int in range(_count_for_level(_hermit_table(), level)):
		_spawn_ground(secondary_kind, origin, min_spawn_radius, max_spawn_radius, level)
	for i: int in range(_count_for_level(_seagull_table(), level)):
		var player: Node3D = _find_player()
		_spawn_seagull(player.global_position if player != null else origin)


func _count_for_level(table: Array[int], level: int) -> int:
	if table.is_empty():
		return 0
	return table[mini(level, table.size()) - 1]


# ---------------------------------------------------------------------------
# Spawns ambiente
# ---------------------------------------------------------------------------

func _process_ambient(delta: float) -> void:
	_elapsed += delta
	# Período de graça (solo): nada de spawns ambiente nos primeiros minutos
	if _elapsed < _profile().ambient_grace_seconds:
		return
	_ambient_timer -= delta
	if _ambient_timer <= 0.0:
		_ambient_timer = randf_range(ambient_interval_min, ambient_interval_max) * _interval_multiplier()
		var player: Node3D = _random_player()
		if player != null:
			# spawn_level 0: não volta para a areia quando a ameaça baixa
			var kind: StringName = primary_kind if ambient_kinds.is_empty() else ambient_kinds.pick_random()
			_spawn_ground(kind, player.global_position, ambient_radius_min, ambient_radius_max, 0)

	_seagull_timer -= delta
	if _seagull_timer <= 0.0:
		var player: Node3D = _player_with_loot()
		if player != null:
			_spawn_seagull(player.global_position)
			_seagull_timer = randf_range(seagull_interval_min, seagull_interval_max) * _interval_multiplier()
		else:
			_seagull_timer = SEAGULL_RETRY


## Coop: o ambiente pressiona um jogador qualquer (local ou remoto).
func _random_player() -> Node3D:
	var all: Array[Node3D] = []
	for group: StringName in EnemyBase.PLAYERS_GROUPS:
		for n: Node in get_tree().get_nodes_in_group(group):
			if n is Node3D and n.is_inside_tree() and not all.has(n):
				all.append(n as Node3D)
	return all.pick_random() if not all.is_empty() else null


## Coop: um jogador (local ou remoto) com itens escavados na mochila, ou null.
func _player_with_loot() -> Node3D:
	var with_loot: Array[Node3D] = []
	for group: StringName in EnemyBase.PLAYERS_GROUPS:
		for n: Node in get_tree().get_nodes_in_group(group):
			if n is Node3D and n.has_method("has_loot") and bool(n.call("has_loot")) and not with_loot.has(n):
				with_loot.append(n as Node3D)
	return with_loot.pick_random() if not with_loot.is_empty() else null


## O spawner do mapa (o primeiro do grupo), para chefes e reforços.
static func find(tree: SceneTree) -> EnemySpawner:
	return tree.get_first_node_in_group(GROUP) as EnemySpawner if tree != null else null


func _find_player() -> Node3D:
	for n: Node in get_tree().get_nodes_in_group("player"):
		if n is Node3D and n.is_inside_tree():
			return n as Node3D
	return null


# ---------------------------------------------------------------------------
# Instanciação
# ---------------------------------------------------------------------------

## Inimigos de chão vivos (os que contam para max_alive).
func get_alive_count() -> int:
	return _prune(_alive)


func get_seagull_count() -> int:
	return _prune(_gulls)


## Inimigos mortos ficam como referências libertadas; um lambda tipado (n: Node3D)
## rebenta ao receber um objeto libertado, por isso limpamos com um ciclo.
static func _prune(list: Array[Node3D]) -> int:
	for i: int in range(list.size() - 1, -1, -1):
		if not is_instance_valid(list[i]):
			list.remove_at(i)
	return list.size()


## Inimigo de chão do `kind` num ponto válido a r_min..r_max de center.
func _spawn_ground(kind: StringName, center: Vector3, r_min: float, r_max: float, level: int) -> Node3D:
	if not can_spawn() or get_alive_count() >= get_max_alive():
		return null
	var pos: Vector3 = _pick_ground_position(center, r_min, r_max)
	if not pos.is_finite():
		return null
	return spawn_from_data(make_spawn_data(kind, pos, level))


func _spawn_seagull(player_pos: Vector3) -> Node3D:
	if not can_spawn() or get_seagull_count() >= max_seagulls:
		return null
	var angle: float = randf() * TAU
	var pos: Vector3 = player_pos + Vector3(cos(angle), 0.0, sin(angle)) * seagull_spawn_distance
	pos.y = player_pos.y + seagull_spawn_height
	return spawn_from_data(make_spawn_data(&"seagull", pos, 0))


## Dados de criação de um inimigo (formato do MultiplayerSpawner da fase 3).
static func make_spawn_data(kind: StringName, pos: Vector3, level: int) -> Dictionary:
	return {"kind": String(kind), "pos": pos, "level": level}


## Verifica se o kind existe na tabela e se o ficheiro de cena existe no disco.
static func has_kind_scene(kind: StringName) -> bool:
	if kind == &"" or not KIND_SCENES.has(kind):
		return false
	return ResourceLoader.exists(KIND_SCENES[kind])


static func scene_for_kind(kind: StringName) -> PackedScene:
	if not has_kind_scene(kind):
		return null
	return load(KIND_SCENES[kind]) as PackedScene


## Verifica se esta instância tem cena (por override ou tabela) para o kind dado.
func has_scene_for_kind(kind: StringName) -> bool:
	if kind == &"":
		return false
	return _scene_override(kind) != null or has_kind_scene(kind)


## Valida a estrutura mínima necessária de spawn data antes de tocar em campos ou replicar.
static func is_valid_spawn_data(data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var d: Dictionary = data as Dictionary
	if not d.has("pos") or not (d["pos"] is Vector3):
		return false
	if not d.has("kind"):
		return false
	var k: Variant = d["kind"]
	if not (k is String or k is StringName):
		return false
	if String(k).is_empty():
		return false
	return true


## Host: cria o inimigo descrito por {"kind", "pos", "level"[, "rot_y"]} como filho deste
## spawner e replica-o (MultiplayerSpawner). Não verifica max_alive (quem chama decide).
## Devolve null num cliente ou se os dados forem inválidos.
func spawn_from_data(data: Variant) -> Node3D:
	if not can_spawn():
		return null
	if not is_valid_spawn_data(data):
		push_warning("[EnemySpawner] dados de spawn invalidos: %s" % str(data))
		return null
	var d: Dictionary = data as Dictionary
	var scene: PackedScene = _scene_for_data(d)
	if scene == null:
		push_warning("[EnemySpawner] kind sem cena valida para spawn: %s" % str(d.get("kind", "")))
		return null
	var enemy: Node3D = null
	if _net_spawner != null and _net_spawner.is_inside_tree():
		enemy = _net_spawner.spawn(d) as Node3D
	else:
		enemy = _create_from_data(d) as Node3D
		if enemy != null:
			add_child(enemy)
	if enemy == null:
		return null
	(_gulls if enemy is Seagull else _alive).append(enemy)
	enemy_spawned.emit(enemy)
	return enemy


## spawn_function: corre no host e em cada cliente com os mesmos dados.
func _create_from_data(data: Variant) -> Node:
	if not is_valid_spawn_data(data):
		return null
	var d: Dictionary = data as Dictionary
	var scene: PackedScene = _scene_for_data(d)
	if scene == null:
		return null
	var enemy: Node3D = scene.instantiate() as Node3D
	if enemy == null:
		return null
	var pos: Vector3 = d["pos"] as Vector3
	enemy.position = global_transform.affine_inverse() * pos if is_inside_tree() else pos
	enemy.rotation.y = float(d.get("rot_y", 0.0))
	if "spawn_level" in enemy:
		enemy.set("spawn_level", int(d.get("level", 0)))
	if enemy is EnemyBase:
		(enemy as EnemyBase).setup_network()
	return enemy


## Cena para os dados, ou null se o kind ou a posição forem inválidos.
func _scene_for_data(data: Variant) -> PackedScene:
	if not is_valid_spawn_data(data):
		return null
	var d: Dictionary = data as Dictionary
	var kind: StringName = StringName(str(d["kind"]))
	var scene: PackedScene = _scene_override(kind)
	return scene if scene != null else scene_for_kind(kind)


## As cenas exportadas sobrepõem o kind primário/secundário/gaivota.
func _scene_override(kind: StringName) -> PackedScene:
	if kind == primary_kind and crab_scene != null:
		return crab_scene
	if kind == secondary_kind and hermit_scene != null:
		return hermit_scene
	if kind == &"seagull" and seagull_scene != null:
		return seagull_scene
	return null


## Só o host cria inimigos (em solo o jogador é o host).
func can_spawn() -> bool:
	if not is_inside_tree():
		return true
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


## Ponto no chão a r_min..r_max de center. Rejeita pontos fora do mapa (o raio não acerta no
## chão) e em cima de paredes/rochas altas. Devolve Vector3.INF se nenhuma tentativa servir.
func _pick_ground_position(center: Vector3, r_min: float, r_max: float) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for attempt: int in range(SPAWN_ATTEMPTS):
		var angle: float = randf() * TAU
		var radius: float = randf_range(r_min, r_max)
		var flat: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			flat + Vector3.UP * RAY_HEIGHT,
			flat + Vector3.DOWN * RAY_DEPTH,
			ground_mask
		)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		var p: Vector3 = hit["position"] as Vector3
		if absf(p.y - center.y) > MAX_GROUND_STEP:
			continue
		return p
	return Vector3.INF


# ---------------------------------------------------------------------------
# Dificuldade por nº de jogadores (issue #11)
# ---------------------------------------------------------------------------

func _profile() -> DifficultyProfile:
	if use_player_scaling:
		return DifficultyProfile.current(get_tree() if is_inside_tree() else null)
	var p: DifficultyProfile = DifficultyProfile.new()
	p.max_alive = max_alive
	p.crabs_per_level = spawns_per_level
	p.hermits_per_level = hermits_per_level
	p.seagulls_per_level = seagulls_per_level
	return p


func get_max_alive() -> int:
	return _profile().max_alive


func _interval_multiplier() -> float:
	return _profile().ambient_interval_multiplier


func _crab_table() -> Array[int]:
	return _profile().crabs_per_level


func _hermit_table() -> Array[int]:
	return _profile().hermits_per_level


func _seagull_table() -> Array[int]:
	return _profile().seagulls_per_level
