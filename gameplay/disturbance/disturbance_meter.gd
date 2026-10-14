class_name DisturbanceMeter
extends Node

## Diferencial do ScanDig: "o subsolo acorda".
## Cada pazada e cada bip do detector geram barulho. Ao passar limiares, o mapa reage
## (criaturas, eventos). Escavar com cuidado é silencioso; escavar rápido é barulhento.

signal noise_changed(current: float, max_noise: float)
signal threshold_reached(level: int, origin: Vector3)
signal threshold_cleared(level: int)

const NOISE_FAST_DIG: float = 8.0
const NOISE_CAREFUL_DIG: float = 2.0
const NOISE_REVEAL: float = 5.0

static var instance: DisturbanceMeter = null

@export var max_noise: float = 100.0
## Limiares em percentagem de max_noise. Índice + 1 = nível de ameaça.
@export var thresholds: Array[float] = [0.35, 0.65, 0.9]
@export var map_data: MapData = null

var current_noise: float = 0.0
var current_level: int = 0
var _last_origin: Vector3 = Vector3.ZERO


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(delta: float) -> void:
	if current_noise <= 0.0:
		return
	var decay: float = map_data.noise_decay_per_second if map_data != null else 2.0
	_set_noise(current_noise - decay * delta)


func add_noise(amount: float, origin: Vector3) -> void:
	var multiplier: float = map_data.noise_multiplier if map_data != null else 1.0
	_last_origin = origin
	_set_noise(current_noise + amount * multiplier)


## Atalho seguro: não faz nada em cenas sem DisturbanceMeter.
static func report(amount: float, origin: Vector3) -> void:
	if instance != null:
		instance.add_noise(amount, origin)


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
