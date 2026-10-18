class_name HoardWake
extends Interactable

## O tesouro certo da Ilha do Tesouro (#114): a maior pilha de ouro, no planalto do Monte do
## Tesouro, é o Colosso do Tesouro disfarçado. Acorda quando alguém mexe nela ([E]) ou quando a
## equipa desenterra `finds_to_wake` achados na ilha (avisa antes: o monte estremece). O chefe
## nasce pelo BossTrigger (EnemySpawner, replicado) e esconde a pilha em todos os peers; se fugir
## aos 300 s a pilha volta e pode-se tentar de novo; vencido, o tesouro principal fica livre.

const BOSS_KIND: StringName = &"gold_colossus"

@export var finds_to_wake: int = 8
@export var warn_before: int = 2

var finds: int = 0
var boss_trigger: BossTrigger = null
var defeated: bool = false
var _watched: Dictionary = {}


func _ready() -> void:
	if prompt == "[E] Interagir":
		prompt = "[E] Mexer no tesouro"
	focus_offset = Vector3(0, 0.9, 0)
	interact_range = 3.2
	# Assenta no planalto (a cena só guarda x/z): o colosso nasce aqui, onde está a pilha.
	position.y = IslandTerrain.height_at(position.x, position.z)
	super._ready()
	boss_trigger = BossTrigger.new()
	boss_trigger.name = "BossTrigger"
	boss_trigger.boss_kind = BOSS_KIND
	add_child(boss_trigger)
	boss_trigger.boss_defeated.connect(_on_boss_defeated)
	if HostSync.is_host(self):
		_watch_spots.call_deferred()


func _on_interact(peer_id: int) -> void:
	super._on_interact(peer_id)
	if defeated:
		return
	say_all("As moedas tremem e começam a levantar voo... o tesouro está VIVO!", 3.0)
	wake()


## Host: acorda o colosso (se ainda não está acordado). Devolve true se nasceu agora.
func wake() -> bool:
	if defeated or boss_trigger == null or boss_trigger.triggered or not HostSync.is_host(self):
		return false
	boss_trigger.trigger()
	if boss_trigger.triggered:
		set_active(false)
		if boss_trigger.boss != null and not boss_trigger.boss.is_connected(&"left_fight", _on_boss_left):
			boss_trigger.boss.connect(&"left_fight", _on_boss_left)
	return boss_trigger.triggered


## Atalho de debug/bot (passo "call" com method "trigger").
func trigger() -> void:
	wake()


func _on_boss_left() -> void:
	# Cansou e fugiu: a pilha volta ao sítio e o tesouro pode ser mexido outra vez.
	finds = 0
	set_active(true)


func _on_boss_defeated() -> void:
	defeated = true
	set_active(false)
	say_all("💰 O Colosso se desfez! O tesouro principal da ilha é de vocês!", 4.0)


## Host: conta os achados desenterrados na ilha (spots do SpotSpawner e pontos frescos).
func _watch_spots() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for n: Node in tree.get_nodes_in_group(&"buried_spots"):
		_watch(n)
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BuriedSpot:
		_watch.call_deferred(n)


func _watch(n: Node) -> void:
	if not is_instance_valid(n) or not n.has_signal(&"item_revealed") or _watched.has(n.get_instance_id()):
		return
	if n is BossAltar:
		return
	_watched[n.get_instance_id()] = true
	n.connect(&"item_revealed", _on_find)


func _on_find(_item: ItemData, _value: int, _integrity: float) -> void:
	if defeated or boss_trigger == null or boss_trigger.triggered:
		return
	finds += 1
	if finds == finds_to_wake - warn_before:
		say_all("O monte de ouro no alto da ilha estremece... alguém está cavando demais.", 3.5)
	elif finds >= finds_to_wake:
		say_all("O ouro do monte acordou com o barulho!", 3.0)
		wake()


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
