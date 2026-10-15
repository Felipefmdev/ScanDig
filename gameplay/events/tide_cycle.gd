class_name TideCycle
extends Node3D

## Maré (#40): o mar (sea_path) desce `low_drop` metros durante `low_duration` s em cada
## ciclo de `period` s e a bandeira `low_flag` (WorldFlags) fica ligada enquanto a maré está
## baixa (relíquia da garrafa, etc.). O relógio é do host: manda o tempo do ciclo a quem
## entra e de 15 em 15 s; os outros peers só animam o mar.

@export var sea_path: NodePath = NodePath("")
## Nós que sobem e descem com o mar (coisas a flutuar).
@export var followers: Array[NodePath] = []
@export var low_flag: StringName = &"mare_baixa"
@export var period: float = 150.0
@export var low_duration: float = 45.0
@export var low_drop: float = 0.35
## Segundos de descida/subida (fora disto o nível está parado).
@export var transition: float = 8.0
## Começa o ciclo neste tempo (para testar: perto da maré baixa).
@export var start_time: float = 0.0

## Tempo dentro do ciclo [0, period).
var cycle_time: float = 0.0
var is_low: bool = false

var _sea: Node3D = null
var _sea_rest_y: float = 0.0
var _followers: Array[Node3D] = []
var _follower_rest_y: Array[float] = []
var _sync_timer: float = 0.0


func _ready() -> void:
	cycle_time = fposmod(start_time, period)
	_sea = get_node_or_null(sea_path) as Node3D
	if _sea != null:
		_sea_rest_y = _sea.position.y
	for path: NodePath in followers:
		var n: Node3D = get_node_or_null(path) as Node3D
		if n != null:
			_followers.append(n)
			_follower_rest_y.append(n.position.y)
	if HostSync.is_host(self):
		HostSync.on_peer_ready(self, func(peer_id: int) -> void:
			HostSync.send_to(self, peer_id, &"_rpc_sync", [cycle_time]))


func _process(delta: float) -> void:
	cycle_time = fposmod(cycle_time + delta, period)
	var drop: float = low_drop * get_low_amount()
	if _sea != null:
		_sea.position.y = _sea_rest_y - drop
	for i: int in _followers.size():
		if is_instance_valid(_followers[i]):
			_followers[i].position.y = _follower_rest_y[i] - drop
	if not HostSync.is_host(self):
		return
	var low_now: bool = cycle_time < low_duration
	if low_now != is_low:
		is_low = low_now
		var flags: WorldFlags = WorldFlags.find(get_tree())
		if flags != null:
			flags.set_flag(low_flag, is_low)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 15.0
		HostSync.broadcast(self, &"_rpc_sync", [cycle_time])


## 0 = maré cheia, 1 = maré baixa (com transições suaves). A maré baixa é [0, low_duration).
func get_low_amount() -> float:
	var t: float = cycle_time
	if t < low_duration:
		return 1.0
	if t < low_duration + transition:
		return 1.0 - smoothstep(0.0, 1.0, (t - low_duration) / transition)
	if t > period - transition:
		return smoothstep(0.0, 1.0, (t - (period - transition)) / transition)
	return 0.0


## Host (testes/bot): salta para o início da maré baixa.
func force_low_tide() -> void:
	if HostSync.is_host(self):
		cycle_time = 0.0
		HostSync.broadcast(self, &"_rpc_sync", [cycle_time])


@rpc("authority", "call_remote", "reliable")
func _rpc_sync(t: float) -> void:
	cycle_time = t
