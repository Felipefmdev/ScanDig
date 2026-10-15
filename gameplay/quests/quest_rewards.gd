class_name QuestRewards
extends RefCounted

## Adaptador ÚNICO entre missões/segredos do gameplay e o core (#39, API da #45). Tudo o que
## dá recompensa ou marca progresso passa por aqui:
##   complete_quest(id)  → CoreGameState.request_complete_quest (o host paga QUESTS[id] uma vez,
##                         guarda em completed_quests e emite quest_completed em todos os peers);
##   report_secret(id)   → CoreGameState.request_report_secret (found_secrets, secret_found);
##   drop_item(...)      → itens do catálogo no chão pelo PickupsRoot (recompensas, relíquias,
##                         troféus), que seguem o caminho normal: mochila → entrega → museu.
## Sem GameState (testes, cenas soltas) guarda só numa lista da sessão.
##
## Os pedidos ao core vão ADIADOS (call_deferred): muitas vezes o host chega aqui dentro de um
## RPC de um convidado (o golpe final dele, o [E] dele numa relíquia) e aí
## multiplayer.get_remote_sender_id() ainda é o convidado, e o core recusa (só aceita o host).

const LOG_PREFIX: String = "[QuestRewards]"

## Sem core (testes): o que já foi concluído/encontrado nesta sessão.
static var completed_quests: Array[String] = []
static var found_secrets: Array[String] = []


## Host: missão concluída (o core paga a recompensa uma vez).
static func complete_quest(quest_id: String) -> void:
	if quest_id.is_empty() or is_quest_completed(quest_id):
		return
	var gs: GameState = GameState.instance
	if gs != null:
		gs.request_complete_quest.call_deferred(quest_id)
	else:
		completed_quests.append(quest_id)
		print("%s missao concluida (sem core): %s" % [LOG_PREFIX, quest_id])


## Host: segredo encontrado (relíquia, chefe escondido, easter egg).
static func report_secret(secret_id: String) -> void:
	if secret_id.is_empty() or is_secret_found(secret_id):
		return
	var gs: GameState = GameState.instance
	if gs != null:
		gs.request_report_secret.call_deferred(secret_id)
	else:
		found_secrets.append(secret_id)
		print("%s segredo encontrado (sem core): %s" % [LOG_PREFIX, secret_id])


static func is_quest_completed(quest_id: String) -> bool:
	var gs: GameState = GameState.instance
	if gs != null:
		return gs.is_quest_completed(quest_id)
	return completed_quests.has(quest_id)


static func is_secret_found(secret_id: String) -> bool:
	var gs: GameState = GameState.instance
	if gs != null:
		return gs.is_secret_found(secret_id)
	return found_secrets.has(secret_id)


## Host: larga um item do catálogo no chão (replicado pelo PickupsRoot). Devolve false se o
## item não existir em res://items/catalog/.
static func drop_item(tree: SceneTree, item_id: String, pos: Vector3, impulse: Vector3 = Vector3(0.0, 2.5, 0.0)) -> bool:
	var path: String = "res://items/catalog/%s.tres" % item_id
	if item_id.is_empty() or not ResourceLoader.exists(path):
		push_warning("%s item em falta no catalogo: %s" % [LOG_PREFIX, item_id])
		return false
	var data: ItemData = load(path) as ItemData
	if data == null:
		return false
	var c: CarriedItem = CarriedItem.create(data, data.base_value, 1.0, false)
	var root: PickupsRoot = PickupsRoot.find(tree)
	if root != null:
		root.drop(c, pos, impulse)
		return true
	var scene: Node = tree.current_scene if tree != null else null
	if scene == null:
		return false
	ItemPickup.spawn(scene, c, pos, impulse)
	return true


## Testes: limpa a lista da sessão (sem core).
static func reset_session() -> void:
	completed_quests.clear()
	found_secrets.clear()
