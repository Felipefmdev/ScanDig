class_name BossTrigger
extends Node3D

## Gatilho de chefe adicional/escondido (#39): acorda um chefe quando uma bandeira do mapa
## (WorldFlags) fica verdadeira — sequência resolvida (conchas), item colocado, fim de missão —
## ou quando alguém chama trigger(). Mesmo caminho de criação do BossAltar (spawn_boss):
## só o host, pelo EnemySpawner do mapa (replicado), uma vez.

signal boss_spawned(boss: Node3D)
signal boss_defeated()

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

var triggered: bool = false
var boss: Node3D = null


func _ready() -> void:
	if trigger_flag != &"" and HostSync.is_host(self):
		_watch_flag.call_deferred()


func _watch_flag() -> void:
	var flags: WorldFlags = WorldFlags.find(get_tree())
	if flags != null:
		flags.when_set(trigger_flag, trigger)


## Host: acorda o chefe (uma vez).
func trigger() -> void:
	if triggered or not HostSync.is_host(self):
		return
	triggered = true
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
	boss_defeated.emit()


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
