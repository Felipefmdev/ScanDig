class_name DisturbanceMeter
extends Node

## Diferencial do ScanDig: "o subsolo acorda".
## Cada pazada e cada bip do detector geram barulho. Ao passar limiares, o mapa reage
## (criaturas, eventos). Escavar com cuidado faz metade do barulho de escavar rápido.
##
## Coop (#5 bloco G, #24): só o DisturbanceMeter do host acumula e decai. Num cliente,
## add_noise()/report() vira rpc_id(1); o host manda current_noise e o nível aos peers com
## o mapa carregado a ~SYNC_HZ, só para o HUD. threshold_reached/cleared só disparam no host
## (é lá que correm o EnemySpawner e os inimigos).

signal noise_changed(current: float, max_noise: float)
signal threshold_reached(level: int, origin: Vector3)
signal threshold_cleared(level: int)

const NOISE_FAST_DIG: float = 8.0
## Cuidadoso = metade do rápido (issue #19: com 2.0 a ameaça nunca subia na Praia).
const NOISE_CAREFUL_DIG: float = 4.0
const NOISE_REVEAL: float = 5.0
## Frequência do envio do barulho aos clientes (HUD).
const SYNC_HZ: float = 5.0
## Limite por pedido de um cliente (o repelente manda valores negativos).
const MAX_CLIENT_NOISE: float = 40.0

static var instance: DisturbanceMeter = null

@export var max_noise: float = 100.0
## Limiares em percentagem de max_noise. Índice + 1 = nível de ameaça.
@export var thresholds: Array[float] = [0.35, 0.65, 0.9]
@export var map_data: MapData = null

var current_noise: float = 0.0
var current_level: int = 0
var _last_origin: Vector3 = Vector3.ZERO
var _sync_timer: float = 0.0


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if is_remote_client():
		return
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 1.0 / SYNC_HZ
		_broadcast()
	if current_noise <= 0.0:
		return
	var decay: float = map_data.noise_decay_per_second if map_data != null else 2.0
	_set_noise(current_noise - decay * delta)


## Cliente ligado a um host (o barulho não é dele).
func is_remote_client() -> bool:
	return is_inside_tree() and NetVisibility.is_online(multiplayer) and not multiplayer.is_server()


func add_noise(amount: float, origin: Vector3) -> void:
	if is_remote_client():
		_rpc_add_noise.rpc_id(1, amount, origin)
		return
	var multiplier: float = map_data.noise_multiplier if map_data != null else 1.0
	_last_origin = origin
	_set_noise(current_noise + amount * multiplier)


## Atalho seguro: não faz nada em cenas sem DisturbanceMeter.
static func report(amount: float, origin: Vector3) -> void:
	if instance != null:
		instance.add_noise(amount, origin)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_add_noise(amount: float, origin: Vector3) -> void:
	if multiplayer.is_server():
		add_noise(clampf(amount, -MAX_CLIENT_NOISE, MAX_CLIENT_NOISE), origin)


## Host: barulho atual para os peers com o mapa carregado.
func _broadcast() -> void:
	if not NetVisibility.is_online(multiplayer):
		return
	for peer_id: int in multiplayer.get_peers():
		if NetVisibility.is_peer_ready(multiplayer, peer_id):
			_rpc_sync.rpc_id(peer_id, current_noise, current_level)


@rpc("authority", "call_remote", "unreliable_ordered")
func _rpc_sync(noise: float, level: int) -> void:
	current_noise = noise
	current_level = level
	noise_changed.emit(current_noise, max_noise)


func get_ratio() -> float:
	return current_noise / max_noise if max_noise > 0.0 else 0.0


func _set_noise(value: float) -> void:
	current_noise = clampf(value, 0.0, max_noise)
	noise_changed.emit(current_noise, max_noise)

	var ratio: float = get_ratio()
	var new_level: int = 0
	for i: int in thresholds.size():
		if ratio >= thresholds[i]:
			new_level = i + 1

	while current_level < new_level:
		current_level += 1
		threshold_reached.emit(current_level, _last_origin)
	while current_level > new_level:
		threshold_cleared.emit(current_level)
		current_level -= 1
