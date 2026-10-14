class_name MetalDetector
extends Node3D

signal item_detected(item: ItemData, signal_strength: float)
signal target_lost()

@export var max_detection_distance: float = 8.0
@export var min_beep_interval: float = 0.08
@export var max_beep_interval: float = 1.20
@export var scan_interval: float = 0.05

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var coil_tip: Marker3D = $CoilTip

var _audio_generator: AudioStreamGenerator = null
var _playback: AudioStreamGeneratorPlayback = null
var _sample_rate: float = 22050.0

var _scan_timer: float = 0.0
var _time_since_last_beep: float = 0.0
var _current_target: BuriedSpot = null
var _current_distance: float = 999.0
var _current_freq: float = 440.0
var _is_beeping: bool = false
var _beep_timer: float = 0.0
var _beep_duration: float = 0.045
var _phase: float = 0.0

# Envelope suave para síntese de áudio (elimina estalos e descontinuidades)
var _current_amplitude: float = 0.0
const MAX_AMPLITUDE: float = 0.35
const ATTACK_TIME: float = 0.004
const RELEASE_TIME: float = 0.006

# Variáveis de Balanço Procedural (Sway de caminhada)
var _sway_time: float = 0.0
var _initial_pos: Vector3 = Vector3.ZERO
var _initial_rot: Vector3 = Vector3.ZERO


func _ready() -> void:
	_initial_pos = position
	_initial_rot = rotation
	_setup_audio_generator()
	_update_target_detection()


func _setup_audio_generator() -> void:
	_audio_generator = AudioStreamGenerator.new()
	_audio_generator.mix_rate = _sample_rate
	_audio_generator.buffer_length = 0.15
	audio_player.stream = _audio_generator
	audio_player.play()
	_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= scan_interval:
		_scan_timer = 0.0
		_update_target_detection()

	_update_beeping(delta)
	_fill_audio_buffer()


## Aplica balanço suave (sway) na haste e visor quando o jogador anda
func apply_walk_sway(is_moving: bool, delta: float) -> void:
	if is_moving:
		_sway_time += delta * 6.5
		# Movimento de arco de varredura lateral característico
		var sway_angle_z: float = sin(_sway_time) * deg_to_rad(3.5)
		var sway_angle_x: float = cos(_sway_time * 2.0) * deg_to_rad(1.8)
		var sway_offset_x: float = sin(_sway_time) * 0.022
		var sway_offset_y: float = absf(cos(_sway_time)) * 0.012

		rotation.z = lerpf(rotation.z, _initial_rot.z + sway_angle_z, 8.0 * delta)
		rotation.x = lerpf(rotation.x, _initial_rot.x + sway_angle_x, 8.0 * delta)
		position.x = lerpf(position.x, _initial_pos.x + sway_offset_x, 8.0 * delta)
		position.y = lerpf(position.y, _initial_pos.y + sway_offset_y, 8.0 * delta)
	else:
		# Retorna à posição e repouso originais
		rotation.z = lerpf(rotation.z, _initial_rot.z, 6.0 * delta)
		rotation.x = lerpf(rotation.x, _initial_rot.x, 6.0 * delta)
		position.x = lerpf(position.x, _initial_pos.x, 6.0 * delta)
		position.y = lerpf(position.y, _initial_pos.y, 6.0 * delta)


func _update_target_detection() -> void:
	var spots: Array[Node] = get_tree().get_nodes_in_group("buried_spots")
	var closest_spot: BuriedSpot = null
	var min_dist: float = max_detection_distance + 0.1
	var detector_pos: Vector3 = coil_tip.global_position if coil_tip != null else global_position

	for spot: Node in spots:
		if spot is BuriedSpot and spot.is_inside_tree():
			var dist: float = detector_pos.distance_to(spot.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_spot = spot

	var had_target: bool = (_current_target != null)

	if min_dist <= max_detection_distance and closest_spot != null:
		_current_target = closest_spot
		_current_distance = min_dist
		_current_freq = _get_frequency_for_item(_current_target.item)

		var dist_factor: float = clampf((_current_distance - 0.5) / (max_detection_distance - 0.5), 0.0, 1.0)
		var signal_strength: float = 1.0 - dist_factor
		item_detected.emit(_current_target.item, signal_strength)
	else:
		_current_target = null
		_current_distance = 999.0
		if had_target:
			target_lost.emit()


func _get_frequency_for_item(item: ItemData) -> float:
	if item == null:
		return 440.0
	match item.material_type:
		ItemData.MaterialType.FERRO:
			return 330.0
		ItemData.MaterialType.ALUMINIO:
			return 520.0
		ItemData.MaterialType.PRATA:
			return 820.0
		ItemData.MaterialType.OURO:
			return 1150.0
		ItemData.MaterialType.DESCONHECIDO:
			return 1450.0
	return 440.0


func _update_beeping(delta: float) -> void:
	if not is_instance_valid(_current_target) or _current_distance > max_detection_distance:
		_is_beeping = false
		return

	var dist_factor: float = clampf((_current_distance - 0.5) / (max_detection_distance - 0.5), 0.0, 1.0)
	var interval: float = lerpf(min_beep_interval, max_beep_interval, dist_factor)

	_time_since_last_beep += delta

	if _time_since_last_beep >= interval:
		_time_since_last_beep = 0.0
		_is_beeping = true
		_beep_timer = _beep_duration

	if _is_beeping:
		_beep_timer -= delta
		if _beep_timer <= 0.0:
			_is_beeping = false


func _fill_audio_buffer() -> void:
	if _playback == null:
		return

	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var phase_step: float = (TAU * _current_freq) / _sample_rate
	var target_amp: float = MAX_AMPLITUDE if _is_beeping else 0.0
	var attack_step: float = MAX_AMPLITUDE / (_sample_rate * ATTACK_TIME)
	var release_step: float = MAX_AMPLITUDE / (_sample_rate * RELEASE_TIME)

	for i in range(frames_available):
		if _current_amplitude < target_amp:
			_current_amplitude = minf(_current_amplitude + attack_step, target_amp)
		elif _current_amplitude > target_amp:
			_current_amplitude = maxf(_current_amplitude - release_step, target_amp)

		var sample: float = 0.0
		if _current_amplitude > 0.0001:
			sample = sin(_phase) * _current_amplitude
			_phase = fmod(_phase + phase_step, TAU)
		else:
			_current_amplitude = 0.0
			_phase = 0.0

		_playback.push_frame(Vector2(sample, sample))


func get_readout_text() -> String:
	if not is_instance_valid(_current_target) or _current_distance > max_detection_distance:
		return "DETETOR PRONTO\nSinal: ---\nProf: ---\nMat: ---\nTam: ---"

	var dist_factor: float = clampf((_current_distance - 0.5) / (max_detection_distance - 0.5), 0.0, 1.0)
	var signal_strength: float = 1.0 - dist_factor

	var bars_count: int = int(round(signal_strength * 6.0))
	var bars_text: String = ""
	for i in range(6):
		if i < bars_count:
			bars_text += "█"
		else:
			bars_text += "░"

	var sound_cue: String = "BIP! BIP!" if signal_strength > 0.75 else ("BIP... BIP" if signal_strength > 0.35 else "BIP.......")

	var item: ItemData = _current_target.item
	var prof_text: String = "20-40 cm"
	var mat_text: String = "Desconhecido"
	var size_text: String = "Médio"

	if item != null:
		var approx_min: int = maxi(5, item.depth_cm - 8)
		var approx_max: int = item.depth_cm + 8
		prof_text = "%d-%d cm" % [approx_min, approx_max]

		match item.material_type:
			ItemData.MaterialType.FERRO:
				mat_text = "Ferro (Grave)"
			ItemData.MaterialType.ALUMINIO:
				mat_text = "Alumínio"
			ItemData.MaterialType.PRATA:
				mat_text = "Prata"
			ItemData.MaterialType.OURO:
				mat_text = "Ouro (Agudo)"
			ItemData.MaterialType.DESCONHECIDO:
				mat_text = "Desconhecido (?)"

		match item.size_category:
			ItemData.SizeCategory.PEQUENO:
				size_text = "Pequeno"
			ItemData.SizeCategory.MEDIO:
				size_text = "Médio"
			ItemData.SizeCategory.GRANDE:
				size_text = "Grande"
			ItemData.SizeCategory.COLOSSAL:
				size_text = "Colossal"

	return "%s [%s]\nProf: %s\nMat: %s\nTam: %s" % [sound_cue, bars_text, prof_text, mat_text, size_text]
