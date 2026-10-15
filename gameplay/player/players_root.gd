class_name PlayersRoot
extends Node3D

## Nó `Players` dos mapas (contrato #5, bloco B): o host cria um Player por peer com o mapa
## carregado (`CoreSession.peer_scene_ready`), com `name = str(peer_id)` (o Player tira daí
## a autoridade), e tira-o quando o peer sai (`CoreNetwork.player_disconnected`). O filho
## MultiplayerSpawner (spawn_path = "..") replica-os com `spawn_function` e os dados
## `{"peer_id", "pos"}`: assim o nó nasce já com nome e posição em todos os peers (o
## estado de spawn do NetSync não serve, porque o dono do NetSync é o cliente e não o
## host). Os clientes não criam nada. Em solo é igual: o jogador é o peer 1.
## Fora de uma expedição (cena aberta direto no editor, bot, testes) o host cria logo o
## jogador local, porque o SessionManager não emite peer_scene_ready nesse caso.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

## Distância entre jogadores à volta do ponto de nascimento (o host fica no centro).
@export var spawn_spacing: float = 1.6


var _spawner: MultiplayerSpawner = null


func _ready() -> void:
	child_entered_tree.connect(_on_child_entered)
	for child: Node in get_children():
		if child is MultiplayerSpawner:
			_spawner = child as MultiplayerSpawner
			_spawner.spawn_function = _create_player
	if not multiplayer.is_server():
		return
	var sm: SessionManager = SessionManager.instance
	if sm != null:
		sm.peer_scene_ready.connect(_on_peer_scene_ready)
	if NetworkManager.instance != null:
		NetworkManager.instance.player_disconnected.connect(_on_peer_left)
	if sm == null or not sm.is_in_expedition():
		spawn_player(multiplayer.get_unique_id())
		return
	# Peers que já ficaram prontos antes de esta cena montar o Players.
	for peer_id: int in sm.get_ready_peers():
		spawn_player(peer_id)


## Host: cria (uma vez) o jogador do peer. Devolve o nó, ou null se não for o host.
func spawn_player(peer_id: int) -> Player:
	if not multiplayer.is_server():
		return null
	var existing: Node = get_node_or_null(str(peer_id))
	if existing != null:
		return existing as Player
	var data: Dictionary = {"peer_id": peer_id, "pos": _spawn_offset(_player_count())}
	if _spawner != null:
		return _spawner.spawn(data) as Player
	# Sem spawner (testes): cria só localmente.
	var player: Player = _create_player(data)
	add_child(player)
	return player


## spawn_function: corre no host e em cada cliente com os mesmos dados.
func _create_player(data: Variant) -> Node:
	var d: Dictionary = data as Dictionary
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.name = str(int(d.get("peer_id", 1)))
	player.position = d.get("pos", Vector3.ZERO)
	return player


func get_player(peer_id: int) -> Player:
	return get_node_or_null(str(peer_id)) as Player


func _on_peer_scene_ready(peer_id: int, _map_id: String) -> void:
	spawn_player(peer_id)
	_refresh_visibility()


func _on_peer_left(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player != null:
		player.queue_free()


## Um jogador novo pode tornar outros visíveis (e vice-versa): os filtros do NetSync
## dependem de quem está pronto e de quem já tem jogador na cena.
func _on_child_entered(node: Node) -> void:
	if node is Player:
		_refresh_visibility.call_deferred()


func _refresh_visibility() -> void:
	for child: Node in get_children():
		var player: Player = child as Player
		if player != null and player.is_node_ready():
			player.net_sync.update_visibility()


func _player_count() -> int:
	var n: int = 0
	for child: Node in get_children():
		if child is Player:
			n += 1
	return n


## 0 = centro; os seguintes num círculo à volta, para não nascerem uns dentro dos outros.
func _spawn_offset(index: int) -> Vector3:
	if index <= 0:
		return Vector3.ZERO
	var angle: float = TAU * float(index - 1) / 6.0
	return Vector3(cos(angle), 0.0, sin(angle)) * spawn_spacing
