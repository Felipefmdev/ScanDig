class_name SpotSpawner
extends Node3D

## Gera BuriedSpots aleatórios a partir de um MapData e repõe-nos depois de escavados,
## para que o mapa nunca esgote.
## Coop (contrato #5, bloco D): só o host sorteia. Os spots nascem por um
## MultiplayerSpawner filho (criado aqui) com spawn_function e os dados
## {"n", "item_id", "rare", "pos"}; os clientes recebem-nos já decididos e não sorteiam nada.

signal spot_spawned(spot: BuriedSpot)

const BURIED_SPOT_SCENE: PackedScene = preload("res://items/buried_spot.tscn")
const RAY_HEIGHT: float = 30.0
const MAX_PLACEMENT_ATTEMPTS: int = 30

@export var map_data: MapData = null
## Tamanho (X, Z) da área retangular, centrada neste nó, onde os spots podem nascer.
@export var area_size: Vector2 = Vector2(40.0, 40.0)
## Segundos até um spot escavado ser substituído por um novo.
@export var respawn_delay: float = 20.0
## Distância mínima entre spots.
@export var min_spot_spacing: float = 3.0
## Raio à volta da origem deste nó sem spots (zona de spawn do jogador).
@export var keep_clear_radius: float = 3.0
## Ângulo máximo do terreno (dunas) onde um spot pode nascer.
@export_range(0.0, 60.0) var max_slope_degrees: float = 25.0
## Camadas de física consideradas "chão" no raycast de colocação.
## layer 6: blockers so para o spawner
@export_flags_3d_physics var ground_mask: int = 33

var _active_spots: Array[BuriedSpot] = []
var _net_spawner: MultiplayerSpawner = null
var _spawn_counter: int = 0


func _ready() -> void:
	_net_spawner = MultiplayerSpawner.new()
	_net_spawner.name = "SpotNetSpawner"
	_net_spawner.spawn_path = NodePath("..")
	_net_spawner.spawn_function = _create_spot
	add_child(_net_spawner)
	# Aviso dos fragmentos do Mapa do Tesouro (#112): o spawner existe em todos os mapas e peers.
	add_child(FragmentNotice.new())
	if not multiplayer.is_server():
		return
	if map_data == null:
		push_warning("[SpotSpawner] map_data não definido; nenhum spot será gerado.")
		return
	# Espera a física construir as colisões (CSG) antes de fazer raycasts.
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.physics_frame
	if not is_inside_tree():
		return
	await tree.physics_frame
	if not is_inside_tree() or map_data == null:
		return
	for i: int in map_data.spot_count:
		_spawn_spot()


func get_active_spot_count() -> int:
	return _active_spots.size()


func _spawn_spot() -> void:
	if not is_inside_tree() or map_data == null:
		return
	for i: int in range(_active_spots.size() - 1, -1, -1):
		if not is_instance_valid(_active_spots[i]):
			_active_spots.remove_at(i)
	if _active_spots.size() >= map_data.spot_count:
		return

	var item: ItemData = _pick_item()
	if item == null:
		push_warning("[SpotSpawner] item_pool vazio em '%s'." % map_data.id)
		return

	var found: bool = false
	var spawn_pos: Vector3 = Vector3.ZERO
	for attempt: int in MAX_PLACEMENT_ATTEMPTS:
		var candidate: Vector3 = _random_point_in_area()
		var ground: Dictionary = _find_ground(candidate)
		if ground.is_empty():
			continue
		spawn_pos = ground["position"]
		if _is_position_valid(spawn_pos):
			found = true
			break
	if not found:
		# Tenta novamente mais tarde em vez de bloquear.
		_schedule_respawn()
		return

	_spawn_counter += 1
	var spot: BuriedSpot = _net_spawner.spawn({
		"n": _spawn_counter,
		"item_id": item.id,
		"rare": randf() < map_data.rare_variant_chance,
		"pos": to_local(spawn_pos),
	}) as BuriedSpot
	if spot == null:
		return
	spot.item_revealed.connect(_on_spot_revealed.bind(spot))
	_active_spots.append(spot)
	spot_spawned.emit(spot)


## spawn_function: corre no host e em cada cliente com os mesmos dados.
func _create_spot(data: Variant) -> Node:
	var d: Dictionary = data as Dictionary
	var spot: BuriedSpot = BURIED_SPOT_SCENE.instantiate() as BuriedSpot
	spot.name = "Spot%d" % int(d.get("n", 0))
	spot.networked = true
	spot.item = _load_item(str(d.get("item_id", "")))
	spot.is_rare_variant = bool(d.get("rare", false))
	spot.rare_decided = true
	spot.position = d.get("pos", Vector3.ZERO)
	return spot


func _load_item(item_id: String) -> ItemData:
	if map_data != null:
		for it: ItemData in map_data.item_pool:
			if it != null and it.id == item_id:
				return it
	var path: String = "res://items/catalog/%s.tres" % item_id
	if item_id.is_valid_filename() and ResourceLoader.exists(path):
		return load(path) as ItemData
	return null


func _pick_item() -> ItemData:
	# item_pool é ponderado por repetição: itens repetidos saem mais vezes.
	if map_data.item_pool.is_empty():
		return null
	return map_data.item_pool.pick_random()


func _random_point_in_area() -> Vector3:
	var half: Vector2 = area_size * 0.5
	var local: Vector3 = Vector3(randf_range(-half.x, half.x), 0.0, randf_range(-half.y, half.y))
	return global_transform * local


func _find_ground(point: Vector3) -> Dictionary:
	var world_3d: World3D = get_world_3d() if is_inside_tree() else null
	if world_3d == null:
		return {}
	var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if space == null:
		return {}
	var from: Vector3 = Vector3(point.x, global_position.y + RAY_HEIGHT, point.z)
	var to: Vector3 = Vector3(point.x, global_position.y - RAY_HEIGHT, point.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, ground_mask)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Object = hit.get("collider")
	if collider is Node and (collider as Node).is_in_group("spot_blockers"):
		return {}
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if normal.angle_to(Vector3.UP) > deg_to_rad(max_slope_degrees):
		return {}
	return hit


func _is_position_valid(pos: Vector3) -> bool:
	var origin: Vector3 = global_position
	if Vector2(pos.x - origin.x, pos.z - origin.z).length() < keep_clear_radius:
		return false
	for s: BuriedSpot in _active_spots:
		if is_instance_valid(s) and s.global_position.distance_to(pos) < min_spot_spacing:
			return false
	return true


func _on_spot_revealed(_item: ItemData, _final_value: int, _final_integrity: float, spot: BuriedSpot) -> void:
	_active_spots.erase(spot)
	_schedule_respawn()
	if is_instance_valid(spot) and spot.is_rare_variant:
		_award_dig_fragment()


## Mapa do Tesouro (#112): a escavação profunda rara (achado variante rara) deste mapa traz o
## fragmento com origem "dig:<mapa>", se ainda faltar. O GameState do host valida.
func _award_dig_fragment() -> void:
	if map_data == null or GameState.instance == null:
		return
	for id: String in GameState.MAP_FRAGMENT_IDS:
		if str(GameState.MAP_FRAGMENTS[id]["source"]) == "dig:" + map_data.id 				and not GameState.instance.has_map_fragment(id):
			GameState.instance.request_award_fragment(id)
			return


func _schedule_respawn() -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(respawn_delay).timeout.connect(_spawn_spot)
