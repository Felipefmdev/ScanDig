class_name IslandBoat
extends Interactable

## Barco da viagem para a Ilha do Tesouro (#113), na ponta do cais da Praia. [E] lê o mapa do
## tesouro: com os fragmentos todos (#103a: GameState.has_all_map_fragments), o host encerra a
## expedição e zarpa logo para a ilha; sem eles, diz quantos faltam. Host decide; clientes só
## pedem o [E] (Interactable) e veem as mensagens.

const ISLAND_ID: String = "ilha_tesouro"
const SAIL_DELAY: float = 1.2
const MODELS: Array = [
	["res://assets/models/kenney_pirate/boat-row-small.glb", Vector3(1.4, -0.75, 0.0), 90.0, 1.3],
	["res://assets/models/kenney_pirate/flag-pirate.glb", Vector3(1.4, -0.45, 0.0), 0.0, 0.8],
]


func _ready() -> void:
	if prompt == "[E] Interagir":
		prompt = "[E] Zarpar para a Ilha do Tesouro"
	super._ready()
	for m: Array in MODELS:
		if not ResourceLoader.exists(m[0]):
			continue
		var n: Node3D = (load(m[0]) as PackedScene).instantiate() as Node3D
		n.position = m[1]
		n.rotation.y = deg_to_rad(float(m[2]))
		n.scale = Vector3.ONE * float(m[3])
		add_child(n)
		ToonKit.apply_to_imported(n)


## (encontrados, total) do mapa do tesouro; enquanto o #103a não existir, (0, 8).
static func fragment_progress() -> Vector2i:
	var gs: GameState = GameState.instance
	if gs == null:
		return Vector2i(0, 8)
	var found: Variant = gs.get(&"map_fragments")
	var ids: Variant = gs.get(&"MAP_FRAGMENT_IDS")
	var total: int = (ids as Array).size() if ids is Array else 8
	return Vector2i((found as Array).size() if found is Array else 0, total)


static func map_complete() -> bool:
	var gs: GameState = GameState.instance
	if gs == null:
		return false
	if gs.has_method(&"has_all_map_fragments"):
		return bool(gs.call(&"has_all_map_fragments"))
	var p: Vector2i = fragment_progress()
	return p.y > 0 and p.x >= p.y


func _on_interact(peer_id: int) -> void:
	if not map_complete():
		var p: Vector2i = fragment_progress()
		say_to(peer_id, "O mapa do tesouro ainda tem buracos: %d de %d fragmentos. Sem ele, ninguém encontra a ilha." % [p.x, p.y], 4.0)
		return
	var sm: SessionManager = SessionManager.instance
	if sm == null or not sm.can_start_map(ISLAND_ID):
		say_to(peer_id, "O mapa está completo, mas o barco ainda não está pronto para a viagem.", 4.0)
		return
	say_all("⛵ Mapa completo! A equipe zarpa para a Ilha do Tesouro...", 3.0)
	# A Praia termina (resumo e save) e, já no lobby, o host parte para a ilha. O temporizador
	# fica no SessionManager (este nó desaparece com a cena).
	# Callable no Script (estático), não neste nó: sobrevive à troca de cena.
	sm.get_tree().create_timer(SAIL_DELAY).timeout.connect(Callable(get_script(), &"_sail").bind(sm), CONNECT_ONE_SHOT)


static func _sail(sm: SessionManager) -> void:
	if not is_instance_valid(sm):
		return
	sm.request_end_expedition()
	sm.get_tree().create_timer(SAIL_DELAY).timeout.connect(sm.request_start_expedition.bind(ISLAND_ID), CONNECT_ONE_SHOT)
