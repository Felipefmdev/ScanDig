class_name BossTrigger
extends Node3D

## Gatilho de chefe adicional/escondido (#39): acorda um chefe quando uma bandeira do mapa
## (WorldFlags) fica verdadeira — sequência resolvida (conchas), item colocado, fim de missão —
## ou quando alguém chama trigger(). Mesmo caminho de criação do BossAltar (spawn_boss):
## só o host, pelo EnemySpawner do mapa (replicado), uma vez.
## Também serve de evento de missão (QuestNpc.event_path): start() acorda o chefe e
## finished(true) sai quando ele morre. Com night = true o mapa fica de noite durante a luta
## (sol, ambiente e céu escurecem em todos os peers).

signal boss_spawned(boss: Node3D)
signal boss_defeated()
## Para o QuestNpc (evento de missão): true quando o chefe morre.
signal finished(success: bool)

const NIGHT_TIME: float = 2.5
## Fatores da noite (sol, ambiente, céu).
const NIGHT_SUN: float = 0.18
const NIGHT_AMBIENT: float = 0.35
const NIGHT_SKY: float = 0.3

## Kind do EnemySpawner (ex. &"octopus").
@export var boss_kind: StringName = &""
## Bandeira que acorda o chefe (vazio = só por trigger()).
@export var trigger_flag: StringName = &""
## Bandeira posta quando o chefe morre (ex.: abre a relíquia do navio).
@export var defeated_flag: StringName = &""
## Segredo reportado ao vencer (QuestRewards.report_secret).
@export var secret_id: String = ""
## Ponto (local) onde o chefe nasce.
@export var spawn_offset: Vector3 = Vector3.ZERO
## Noite durante a luta.
@export var night: bool = false

var triggered: bool = false
var boss: Node3D = null
var is_night: bool = false

var _sun: DirectionalLight3D = null
var _sun_energy: float = 1.0
var _env: Environment = null
var _ambient_energy: float = 1.0
var _sky_energy: float = 1.0
var _exposure: float = 1.0
var _sky_contribution: float = 1.0
var _ambient_color: Color = Color.WHITE


func _ready() -> void:
	if trigger_flag != &"" and HostSync.is_host(self):
		_watch_flag.call_deferred()
	if HostSync.is_host(self):
		HostSync.on_peer_ready(self, func(peer_id: int) -> void:
			if is_night:
				HostSync.send_to(self, peer_id, &"_rpc_night", [true]))


func _watch_flag() -> void:
	var flags: WorldFlags = WorldFlags.find(get_tree())
	if flags != null:
		flags.when_set(trigger_flag, trigger)


## Evento de missão: acorda o chefe; falso se já foi acordado.
func start() -> bool:
	if triggered or not HostSync.is_host(self):
		return false
	trigger()
	return triggered


## Host: acorda o chefe (uma vez).
func trigger() -> void:
	if triggered or not HostSync.is_host(self):
		return
	triggered = true
	if night:
		_set_night(true)
		HostSync.broadcast(self, &"_rpc_night", [true])
	boss = spawn_boss(self, boss_kind, global_transform * spawn_offset, global_rotation.y)
	if boss == null:
		return
	if boss.has_signal(&"died"):
		boss.connect(&"died", _on_boss_died)
	boss_spawned.emit(boss)


func _on_boss_died() -> void:
	if defeated_flag != &"":
		var flags: WorldFlags = WorldFlags.find(get_tree())
		if flags != null:
			flags.set_flag(defeated_flag)
	if not secret_id.is_empty():
		QuestRewards.report_secret(secret_id)
	if night:
		_set_night(false)
		HostSync.broadcast(self, &"_rpc_night", [false])
	boss_defeated.emit()
	finished.emit(true)


@rpc("authority", "call_remote", "reliable")
func _rpc_night(on: bool) -> void:
	_set_night(on)


## Todos os peers: escurece/clareia o sol (DirectionalLight3D) e o ambiente do mapa.
func _set_night(on: bool) -> void:
	if on == is_night or not is_inside_tree():
		return
	if _sun == null:
		_sun = _find_sun(get_tree().current_scene)
		if _sun != null:
			_sun_energy = _sun.light_energy
		var we: WorldEnvironment = _find_world_env(get_tree().current_scene)
		if we != null and we.environment != null:
			# Cópia: não mexer no .tres partilhado do mapa.
			we.environment = we.environment.duplicate() as Environment
			_env = we.environment
			_ambient_energy = _env.ambient_light_energy
			_sky_energy = _env.background_energy_multiplier
			_exposure = _env.tonemap_exposure
			_sky_contribution = _env.ambient_light_sky_contribution
			_ambient_color = _env.ambient_light_color
	is_night = on
	var k: float = 1.0 if not on else 0.0
	var tw: Tween = create_tween().set_parallel(true)
	if _sun != null:
		tw.tween_property(_sun, "light_energy", _sun_energy * lerpf(NIGHT_SUN, 1.0, k), NIGHT_TIME)
	if _env != null:
		tw.tween_property(_env, "ambient_light_energy", _ambient_energy * lerpf(NIGHT_AMBIENT, 1.0, k), NIGHT_TIME)
		tw.tween_property(_env, "background_energy_multiplier", _sky_energy * lerpf(NIGHT_SKY, 1.0, k), NIGHT_TIME)
		tw.tween_property(_env, "tonemap_exposure", _exposure * lerpf(0.55, 1.0, k), NIGHT_TIME)
		tw.tween_property(_env, "ambient_light_sky_contribution", lerpf(0.0, _sky_contribution, k), NIGHT_TIME)
		tw.tween_property(_env, "ambient_light_color", _ambient_color.lerp(Color(0.25, 0.3, 0.55), 1.0 - k), NIGHT_TIME)


static func _find_sun(root: Node) -> DirectionalLight3D:
	if root == null:
		return null
	for n: Node in root.get_children():
		if n is DirectionalLight3D:
			return n as DirectionalLight3D
	return null


static func _find_world_env(root: Node) -> WorldEnvironment:
	if root == null:
		return null
	for n: Node in root.get_children():
		if n is WorldEnvironment:
			return n as WorldEnvironment
	return null


## Host: cria o chefe `kind` em `world_pos` pelo EnemySpawner do mapa (replicado); sem
## spawner (testes, cenas antigas) instancia-o localmente ao lado de `owner_node`.
## Partilhado com o BossAltar.
static func spawn_boss(owner_node: Node3D, kind: StringName, world_pos: Vector3, rot_y: float,
		fallback_scene: PackedScene = null) -> Node3D:
	var tree: SceneTree = owner_node.get_tree() if owner_node.is_inside_tree() else null
	var spawner: EnemySpawner = EnemySpawner.find(tree) if tree != null else null
	if spawner != null and kind != &"":
		var b: Node3D = spawner.spawn_from_data({"kind": String(kind), "pos": world_pos, "level": 0, "rot_y": rot_y})
		if b != null:
			return b
	var scene: PackedScene = fallback_scene if fallback_scene != null else EnemySpawner.scene_for_kind(kind)
	if scene == null:
		push_warning("[BossTrigger] chefe sem cena: %s" % kind)
		return null
	var b2: Node3D = scene.instantiate() as Node3D
	var parent: Node = owner_node.get_parent() if owner_node.get_parent() != null else owner_node
	# Posiciona antes de entrar na árvore: o _ready do chefe guarda a posição de partida.
	b2.position = (parent as Node3D).global_transform.affine_inverse() * world_pos if parent is Node3D and parent.is_inside_tree() else world_pos
	b2.rotation.y = rot_y
	parent.add_child(b2)
	b2.global_position = world_pos
	return b2
