class_name BuriedSpot
extends Area3D

signal spot_dug(dirt_left: int, current_integrity: float)
signal item_revealed(item_data: ItemData, final_value: int, final_integrity: float)
## Cliente: chegou a resposta do host a um request_dig (mesmo formato do dig(), com
## "item" já convertido de volta para ItemData).
signal remote_dig_result(result: Dictionary)

@export var item: ItemData = null
## Replicado (NetSync): os clientes refazem o buraco a partir daqui.
@export var dirt_layers: int = 3:
	set(value):
		dirt_layers = value
		_update_mound()
@export_range(0.0, 1.0) var integrity: float = 1.0
## Chance de o item sair como variante rara (vale RARE_VALUE_MULTIPLIER vezes mais).
@export_range(0.0, 1.0, 0.01) var rare_variant_chance: float = 0.05

const RARE_VALUE_MULTIPLIER: float = 3.0
## Bónus para escavações perfeitas (integridade 100%).
const PERFECT_BONUS_MULTIPLIER: float = 1.25
## Host: distância máxima jogador→spot aceite num request_dig (dig_range 1.8 + folga de rede).
const MAX_REMOTE_DIG_DISTANCE: float = 2.8
## Limites do multiplicador de dano que um cliente pode pedir (pá nível 1 = 1.0).
const MIN_DAMAGE_MULTIPLIER: float = 0.3

var is_rare_variant: bool = false
## Criado pelo SpotSpawner através do MultiplayerSpawner (contrato #5 D): só o host cava;
## os clientes pedem com request_dig. Spots fixos na cena (altares) ficam false.
var networked: bool = false
## O host já decidiu a raridade (vem nos dados de spawn): não sortear no _ready.
var rare_decided: bool = false
var _is_revealed: bool = false
var _dirt_mound: Node3D = null
var _dirt_particles: CPUParticles3D = null
const MAX_DIRT_LAYERS: int = 3


func _ready() -> void:
	add_to_group("buried_spots")
	if not rare_decided:
		is_rare_variant = item != null and randf() < rare_variant_chance
	_create_visuals()
	_create_particles()
	_update_mound()
	var sync: MultiplayerSynchronizer = get_node_or_null(^"NetSync") as MultiplayerSynchronizer
	if sync != null:
		NetVisibility.watch(sync)


func _create_visuals() -> void:
	_dirt_mound = Node3D.new()
	_dirt_mound.name = "DirtMound"
	_dirt_mound.visible = false  # Começa totalmente invisível na areia!
	add_child(_dirt_mound)

	# Borda externa da escavação
	var mound_mesh: CSGCylinder3D = CSGCylinder3D.new()
	mound_mesh.radius = 0.45
	mound_mesh.height = 0.05
	mound_mesh.sides = 12
	var mat_dirt: StandardMaterial3D = StandardMaterial3D.new()
	mat_dirt.albedo_color = Color(0.42, 0.28, 0.15)
	mat_dirt.roughness = 0.9
	mound_mesh.material = mat_dirt
	mound_mesh.position.y = 0.02
	_dirt_mound.add_child(mound_mesh)

	# Fundo do buraco (terra mais escura e funda)
	var hole_mesh: CSGCylinder3D = CSGCylinder3D.new()
	hole_mesh.radius = 0.32
	hole_mesh.height = 0.07
	hole_mesh.sides = 12
	var mat_hole: StandardMaterial3D = StandardMaterial3D.new()
	mat_hole.albedo_color = Color(0.25, 0.16, 0.08)
	mat_hole.roughness = 1.0
	hole_mesh.material = mat_hole
	hole_mesh.position.y = 0.015
	_dirt_mound.add_child(hole_mesh)


func _create_particles() -> void:
	_dirt_particles = CPUParticles3D.new()
	_dirt_particles.name = "DirtParticles"
	_dirt_particles.emitting = false
	_dirt_particles.one_shot = true
	_dirt_particles.explosiveness = 0.9
	_dirt_particles.amount = 24
	_dirt_particles.lifetime = 0.55
	_dirt_particles.direction = Vector3(0, 1, 0)
	_dirt_particles.spread = 45.0
	_dirt_particles.initial_velocity_min = 2.2
	_dirt_particles.initial_velocity_max = 3.8
	_dirt_particles.gravity = Vector3(0, -9.8, 0)

	var particle_box: BoxMesh = BoxMesh.new()
	particle_box.size = Vector3(0.05, 0.05, 0.05)
	var mat_p: StandardMaterial3D = StandardMaterial3D.new()
	mat_p.albedo_color = Color(0.55, 0.38, 0.22)
	mat_p.roughness = 0.9
	particle_box.material = mat_p
	_dirt_particles.mesh = particle_box

	add_child(_dirt_particles)


## Buraco visível a partir da 1.ª pazada; afunda e alarga a cada camada. Derivado de
## dirt_layers, por isso também serve os clientes (dirt_layers chega pelo NetSync).
func _update_mound() -> void:
	if _dirt_mound != null:
		var layer_progress: float = float(MAX_DIRT_LAYERS - clampi(dirt_layers, 0, MAX_DIRT_LAYERS)) / float(MAX_DIRT_LAYERS)
		_dirt_mound.visible = layer_progress > 0.0
		_dirt_mound.position.y = -0.04 * layer_progress
		_dirt_mound.scale = Vector3(1.0 + layer_progress * 0.15, 1.0, 1.0 + layer_progress * 0.15)
	# Cliente: revelado no host → sai do radar e deixa de poder ser cavado.
	if networked and dirt_layers <= 0 and not _is_revealed and is_inside_tree() and not multiplayer.is_server():
		_is_revealed = true
		remove_from_group("buried_spots")


## Partículas de terra a voar (em todos os peers quando o spot é em rede).
@rpc("authority", "call_local", "unreliable")
func _play_dig_fx() -> void:
	if _dirt_particles != null:
		_dirt_particles.restart()


# --- Rede (contrato #5, bloco D) -----------------------------------------------

## Cliente → host: cavar este spot. O host confere a distância do jogador de quem pede,
## limita o multiplicador de dano e responde só a esse peer com _dig_result.
@rpc("any_peer", "call_remote", "reliable")
func request_dig(is_careful: bool, damage_multiplier: float) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var digger: Node3D = _player_of(sender)
	if digger == null or digger.global_position.distance_to(global_position) > MAX_REMOTE_DIG_DISTANCE:
		_dig_result.rpc_id(sender, {})
		return
	# Fase 3 (#5 G): o barulho de um cliente é reportado por ele (report_noise=false aqui).
	var res: Dictionary = dig(is_careful, clampf(damage_multiplier, MIN_DAMAGE_MULTIPLIER, 1.0), false)
	res["is_careful"] = is_careful
	_dig_result.rpc_id(sender, result_to_net(res))


@rpc("authority", "call_remote", "reliable")
func _dig_result(res: Dictionary) -> void:
	remote_dig_result.emit(result_from_net(res))


## O resultado do dig() leva um ItemData; pela rede vai só o id.
static func result_to_net(res: Dictionary) -> Dictionary:
	var out: Dictionary = res.duplicate()
	var data: ItemData = res.get("item") as ItemData
	out["item"] = data.id if data != null else ""
	return out


static func result_from_net(res: Dictionary) -> Dictionary:
	var out: Dictionary = res.duplicate()
	var item_id: Variant = res.get("item", "")
	out["item"] = null
	if item_id is String and not (item_id as String).is_empty() and (item_id as String).is_valid_filename():
		var path: String = "res://items/catalog/%s.tres" % item_id
		if ResourceLoader.exists(path):
			out["item"] = load(path) as ItemData
	return out


func _player_of(peer_id: int) -> Node3D:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	for n: Node in tree.get_nodes_in_group(&"players"):
		if String(n.name) == str(peer_id):
			return n as Node3D
	return null


## damage_multiplier: escala o dano à integridade (ex.: pás melhores < 1.0). Opcional.
## report_noise: false quando quem cava é um cliente (ele reporta o barulho do lado dele).
func dig(is_careful: bool, damage_multiplier: float = 1.0, report_noise: bool = true) -> Dictionary:
	if _is_revealed or dirt_layers <= 0:
		return {
			"revealed": true,
			"revealed_now": false,
			"dirt_layers": 0,
			"max_layers": MAX_DIRT_LAYERS,
			"integrity": integrity,
			"damaged": false,
			"item": item,
			"final_value": 0,
			"is_rare_variant": is_rare_variant,
			"is_perfect": false,
			"dug": false,
		}

	# Partículas de areia e terra a voar (todos os peers veem-nas se o spot é em rede).
	if networked and NetVisibility.is_online(multiplayer):
		_play_dig_fx.rpc()
	else:
		_play_dig_fx()

	# O setter refaz o buraco (fica visível na 1.ª pazada, afunda e alarga a cada camada).
	dirt_layers -= 1
	if report_noise:
		DisturbanceMeter.report(
			DisturbanceMeter.NOISE_CAREFUL_DIG if is_careful else DisturbanceMeter.NOISE_FAST_DIG,
			global_position
		)

	var damaged_this_hit: bool = false
	var damage_amount: float = 0.0

	if not is_careful:
		# Se dirt_layers <= 1, aplica dano à integridade baseado na fragilidade do item
		if dirt_layers <= 1 and item != null:
			damage_amount = clampf(item.fragility * 0.45, 0.08, 0.90) * maxf(damage_multiplier, 0.0)
			integrity = clampf(integrity - damage_amount, 0.05, 1.0)
			damaged_this_hit = true
			print("[BuriedSpot] CRACK! Pazada agressiva causou dano! Integridade: %d%%" % int(integrity * 100.0))
		else:
			print("[BuriedSpot] Pazada rápida removeu camada de terra. Restam %d" % dirt_layers)
	else:
		print("[BuriedSpot] Escavação cuidadosa! Camadas restantes: %d (Integridade 100%% preservada)" % dirt_layers)

	var revealed: bool = (dirt_layers <= 0)
	var final_val: int = 0
	var is_perfect: bool = false

	if revealed:
		_is_revealed = true
		remove_from_group("buried_spots")

		if item != null:
			final_val = item.calculate_value(integrity)
			if is_rare_variant:
				final_val = int(round(float(final_val) * RARE_VALUE_MULTIPLIER))
			is_perfect = integrity >= 1.0
			if is_perfect:
				final_val = int(round(float(final_val) * PERFECT_BONUS_MULTIPLIER))
			if report_noise:
				DisturbanceMeter.report(DisturbanceMeter.NOISE_REVEAL, global_position)
			print("========================================")
			print("★ ITEM ENCONTRADO: %s" % item.display_name)
			print("  Integridade: %d%%" % int(integrity * 100.0))
			print("  Valor de Venda: R$ %d" % final_val)
			print("  Profundidade Real: %d cm" % item.depth_cm)
			print("========================================")
			_spawn_pickup(final_val)
		else:
			print("[BuriedSpot] Ponto escavado sem ItemData configurado.")

		item_revealed.emit(item, final_val, integrity)
		# A venda já não é automática: o item salta como ItemPickup, vai para a
		# mochila (E) e só é entregue ao GameState num SellPoint.
		if is_inside_tree() and get_tree() != null:
			get_tree().create_timer(4.0).timeout.connect(queue_free)
		else:
			queue_free()

	spot_dug.emit(dirt_layers, integrity)

	return {
		"revealed": revealed,
		"revealed_now": revealed,
		"dirt_layers": dirt_layers,
		"max_layers": MAX_DIRT_LAYERS,
		"integrity": integrity,
		"damaged": damaged_this_hit,
		"damage_amount": damage_amount,
		"item": item,
		"final_value": final_val,
		"is_rare_variant": is_rare_variant,
		"is_perfect": is_perfect,
		"dug": true,
	}


func _spawn_pickup(final_val: int) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var c: CarriedItem = CarriedItem.create(item, final_val, integrity, is_rare_variant)
	# Salta para fora do buraco numa direção aleatória.
	var dir: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	ItemPickup.spawn(parent, c, global_position + Vector3.UP * 0.35, Vector3.UP * 2.2 + dir * 0.6)
