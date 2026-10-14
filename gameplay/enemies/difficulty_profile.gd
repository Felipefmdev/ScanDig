class_name DifficultyProfile
extends Resource

## Afinação da pressão de inimigos por nº de jogadores (issue #11). Em solo a Praia era
## dura demais no início; em coop estava bem. EnemySpawner e EnemyBase leem o perfil atual
## com DifficultyProfile.current(). Valores fáceis de afinar em for_player_count().

## Segundos do início da sessão sem spawns ambientes (período de graça).
@export var ambient_grace_seconds: float = 0.0
## Multiplica os intervalos ambiente (caranguejo e gaivota). >1 = menos frequente.
@export var ambient_interval_multiplier: float = 1.0
@export var max_alive: int = 6
## Inimigos por nível de ameaça (índice 0 = nível 1).
@export var crabs_per_level: Array[int] = [1, 2, 4]
@export var hermits_per_level: Array[int] = [0, 1, 1]
@export var seagulls_per_level: Array[int] = [0, 0, 1]
## Multiplica o dano que os inimigos fazem ao jogador.
@export var enemy_damage_multiplier: float = 1.0

## Perfil fixo para testes/debug (null = calcula pelo nº de jogadores).
static var override: DifficultyProfile = null


static func for_player_count(players: int) -> DifficultyProfile:
	var p: DifficultyProfile = DifficultyProfile.new()
	if players <= 1:
		# Solo: graça de 3 min, menos inimigos e menos dano
		p.ambient_grace_seconds = 180.0
		p.ambient_interval_multiplier = 1.8
		p.max_alive = 3
		p.crabs_per_level = [1, 1, 2]
		p.hermits_per_level = [0, 1, 1]
		p.seagulls_per_level = [0, 0, 1]
		p.enemy_damage_multiplier = 0.6
	elif players == 2:
		# Coop a dois: os valores que já funcionavam
		pass
	else:
		# 3-4 jogadores: um pouco acima
		p.ambient_interval_multiplier = 0.85
		p.max_alive = 8
		p.crabs_per_level = [2, 3, 5]
		p.hermits_per_level = [0, 1, 2]
		p.seagulls_per_level = [0, 1, 1]
		p.enemy_damage_multiplier = 1.1
	return p


## Nº de jogadores ligados (só leitura de core/). Sem rede = 1.
static func get_player_count(tree: SceneTree = null) -> int:
	if NetworkManager.instance != null and NetworkManager.instance.connected_players.size() > 0:
		return NetworkManager.instance.connected_players.size()
	if tree != null and tree.get_multiplayer() != null and tree.get_multiplayer().has_multiplayer_peer():
		return tree.get_multiplayer().get_peers().size() + 1
	return 1


static func current(tree: SceneTree = null) -> DifficultyProfile:
	if override != null:
		return override
	return for_player_count(get_player_count(tree))
