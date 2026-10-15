class_name SilenceTrigger
extends Node3D

## "Faz silêncio" (#41, a ovelha do Campo): no host, se algum jogador estiver a menos de
## `radius` m deste ponto, quase parado, e o DisturbanceMeter não subir durante
## `quiet_seconds`, liga `flag`. Basta barulho (cavar, lutar) ou correr para a desligar.

@export var radius: float = 9.0
@export var quiet_seconds: float = 8.0
## Velocidade horizontal máxima (m/s) para contar como "parado".
@export var max_speed: float = 1.2
@export var flag: StringName = &""
## Depois de usada (ex.: festas à ovelha) a bandeira fica ligada para sempre.
@export var keep_flag: StringName = &""

var quiet_time: float = 0.0
var _last_noise: float = 0.0


func _physics_process(delta: float) -> void:
	if not HostSync.is_host(self):
		return
	var flags: WorldFlags = WorldFlags.find(get_tree())
	if flags == null or (keep_flag != &"" and flags.has_flag(keep_flag)):
		return
	var quiet: bool = _someone_still_nearby() and not _noise_rising()
	quiet_time = quiet_time + delta if quiet else 0.0
	var on: bool = quiet_time >= quiet_seconds
	if flags.has_flag(flag) != on and (on or quiet_time == 0.0):
		flags.set_flag(flag, on)


func _someone_still_nearby() -> bool:
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var p: Node3D = n as Node3D
		if p == null:
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() > radius:
			continue
		var v: Vector3 = (p as CharacterBody3D).velocity if p is CharacterBody3D else Vector3.ZERO
		if Vector2(v.x, v.z).length() <= max_speed:
			return true
	return false


func _noise_rising() -> bool:
	var dm: DisturbanceMeter = DisturbanceMeter.instance
	if dm == null:
		return false
	var noise: float = dm.current_noise
	var rising: bool = noise > _last_noise + 0.01
	_last_noise = noise
	return rising
