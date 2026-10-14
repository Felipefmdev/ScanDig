class_name MetalDetector
extends Node3D

signal item_detected(item: ItemData, signal_strength: float)
signal target_lost()

## Nível usado quando não existe GameState na cena (só leitura de core/).
@export_range(1, 3) var detector_level: int = 1
## Alcance no nível 1; cada nível acima soma range_bonus_per_level.
@export var base_detection_distance: float = 8.0
@export var range_bonus_per_level: float = 2.5
@export var min_beep_interval: float = 0.08
@export var max_beep_interval: float = 1.20
@export var scan_interval: float = 0.05

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var coil_tip: Marker3D = $CoilTip

const MAX_LEVEL: int = 3
## Barulho reportado ao DisturbanceMeter por cada bip: detetar demais também acorda o subsolo.
const NOISE_BEEP: float = 0.4
## A partir desta força de sinal, uma variante rara ganha o harmónico de brilho.
const RARE_SIGNAL_THRESHOLD: float = 0.7

# Timbres por material
const IRON_BUZZ_HZ: float = 38.0
const UNKNOWN_VIBRATO_HZ: float = 6.5
const UNKNOWN_VIBRATO_DEPTH: float = 0.09
const RARE_SPARKLE_HZ: float = 9.0
const RARE_SHIMMER_RATIO: float = 2.5
const RARE_SHIMMER_GAIN: float = 0.22

var max_detection_distance: float = 8.0

var _audio_generator: AudioStreamGenerator = null
var _playback: AudioStreamGeneratorPlayback = null
var _sample_rate: float = 22050.0

var _scan_timer: float = 0.0
var _time_since_last_beep: float = 0.0
var _current_target: BuriedSpot = null
var _current_distance: float = 999.0
var _is_beeping: bool = false
var _beep_timer: float = 0.0
var _beep_duration: float = 0.045

# Parâmetros do bip atual (fixados no início do bip para o timbre não mudar a meio)
var _beep_material: ItemData.MaterialType = ItemData.MaterialType.FERRO
var _beep_freq: float = 440.0
var _beep_rare: bool = false

# Fases dos osciladores (radianos)
var _phase: float = 0.0
var _lfo_phase: float = 0.0
var _shimmer_phase: float = 0.0
var _sparkle_phase: float = 0.0
var _unknown_drift: float = 0.0

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
	_refresh_level_stats()
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
		_refresh_level_stats()
		_update_target_detection()

	_update_beeping(delta)
	_fill_audio_buffer()


## Nível efetivo: GameState (upgrade comprado) tem prioridade sobre o @export local.
func get_detector_level() -> int:
	var level: int = detector_level
	if GameState.instance != null:
		level = GameState.instance.equipped_detector_level
	return clampi(level, 1, MAX_LEVEL)


func _refresh_level_stats() -> void:
	max_detection_distance = base_detection_distance + range_bonus_per_level * float(get_detector_level() - 1)


func get_signal_strength() -> float:
	if not is_instance_valid(_current_target) or _current_distance > max_detection_distance:
		return 0.0
	var dist_factor: float = clampf((_current_distance - 0.5) / (max_detection_distance - 0.5), 0.0, 1.0)
	return 1.0 - dist_factor


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
		item_detected.emit(_current_target.item, get_signal_strength())
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
			return 190.0
		ItemData.MaterialType.ALUMINIO:
			return 520.0
		ItemData.MaterialType.PRATA:
			return 880.0
		ItemData.MaterialType.OURO:
			return 1320.0
		ItemData.MaterialType.DESCONHECIDO:
			return 1000.0
	return 440.0


## Ferro arrasta-se mais (grave); ouro é um "tic" curto e limpo.
func _get_beep_duration_for_material(mat_type: ItemData.MaterialType) -> float:
	match mat_type:
		ItemData.MaterialType.FERRO:
			return 0.075
		ItemData.MaterialType.ALUMINIO:
			return 0.055
		ItemData.MaterialType.PRATA:
			return 0.045
		ItemData.MaterialType.OURO:
			return 0.038
		ItemData.MaterialType.DESCONHECIDO:
			return 0.065
	return 0.045


func _update_beeping(delta: float) -> void:
	if not is_instance_valid(_current_target) or _current_distance > max_detection_distance:
		_is_beeping = false
		return

	var signal_strength: float = get_signal_strength()
	var interval: float = lerpf(max_beep_interval, min_beep_interval, signal_strength)

	_time_since_last_beep += delta

	if _time_since_last_beep >= interval:
		_time_since_last_beep = 0.0
		_start_beep(signal_strength)

	if _is_beeping:
		_beep_timer -= delta
		if _beep_timer <= 0.0:
			_is_beeping = false


func _start_beep(signal_strength: float) -> void:
	var item: ItemData = _current_target.item
	_beep_material = item.material_type if item != null else ItemData.MaterialType.FERRO
	_beep_freq = _get_frequency_for_item(item)
	_beep_duration = _get_beep_duration_for_material(_beep_material)
	_beep_rare = _current_target.is_rare_variant and signal_strength >= RARE_SIGNAL_THRESHOLD
	_is_beeping = true
	_beep_timer = _beep_duration

	var noise_origin: Vector3 = coil_tip.global_position if coil_tip != null else global_position
	DisturbanceMeter.report(NOISE_BEEP, noise_origin)


func _fill_audio_buffer() -> void:
	if _playback == null:
		return

	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var target_amp: float = MAX_AMPLITUDE if _is_beeping else 0.0
	var attack_step: float = MAX_AMPLITUDE / (_sample_rate * ATTACK_TIME)
	var release_step: float = MAX_AMPLITUDE / (_sample_rate * RELEASE_TIME)

	for i: int in range(frames_available):
		if _current_amplitude < target_amp:
			_current_amplitude = minf(_current_amplitude + attack_step, target_amp)
		elif _current_amplitude > target_amp:
			_current_amplitude = maxf(_current_amplitude - release_step, target_amp)

		var sample: float = 0.0
		if _current_amplitude > 0.0001:
			sample = _synth_sample() * _current_amplitude
		else:
			_current_amplitude = 0.0
			_reset_oscillators()

		_playback.push_frame(Vector2(sample, sample))


func _reset_oscillators() -> void:
	_phase = 0.0
	_lfo_phase = 0.0
	_shimmer_phase = 0.0
	_sparkle_phase = 0.0
	_unknown_drift = 0.0


## Gera uma amostra normalizada (-1..1) com o timbre do material do bip atual.
func _synth_sample() -> float:
	var inv_sr: float = 1.0 / _sample_rate
	var freq: float = _beep_freq
	var s: float = 0.0

	match _beep_material:
		ItemData.MaterialType.FERRO:
			# Grave e áspero: seno saturado (quase quadrado) com zumbido AM
			_lfo_phase = fmod(_lfo_phase + TAU * IRON_BUZZ_HZ * inv_sr, TAU)
			var harsh: float = tanh(sin(_phase) * 3.5)
			var buzz: float = 0.6 + 0.4 * sin(_lfo_phase)
			s = (harsh * 0.7 + sin(_phase * 3.0) * 0.15) * buzz
		ItemData.MaterialType.ALUMINIO:
			# Médio e neutro: seno com um pouco de 2º harmónico
			s = sin(_phase) * 0.8 + sin(_phase * 2.0) * 0.18
		ItemData.MaterialType.PRATA:
			# Claro: harmónicos suaves dão brilho
			s = sin(_phase) * 0.7 + sin(_phase * 2.0) * 0.16 + sin(_phase * 4.0) * 0.1
		ItemData.MaterialType.OURO:
			# Agudo e limpo: seno puro
			s = sin(_phase) * 0.9
		ItemData.MaterialType.DESCONHECIDO:
			# Instável: vibrato + deriva aleatória da afinação + tremolo
			_lfo_phase = fmod(_lfo_phase + TAU * UNKNOWN_VIBRATO_HZ * inv_sr, TAU)
			_unknown_drift = clampf(_unknown_drift + randf_range(-1.0, 1.0) * 0.0015, -0.12, 0.12)
			freq *= 1.0 + UNKNOWN_VIBRATO_DEPTH * sin(_lfo_phase) + _unknown_drift
			var tremolo: float = 0.7 + 0.3 * sin(_lfo_phase * 1.7)
			s = (sin(_phase) * 0.75 + sin(_phase * 2.0) * 0.12) * tremolo

	if _beep_rare:
		# Brilho extra: harmónico não inteiro cintilante sobre o timbre base
		_shimmer_phase = fmod(_shimmer_phase + TAU * freq * RARE_SHIMMER_RATIO * inv_sr, TAU)
		_sparkle_phase = fmod(_sparkle_phase + TAU * RARE_SPARKLE_HZ * inv_sr, TAU)
		var sparkle: float = 0.5 + 0.5 * sin(_sparkle_phase)
		s = s * 0.85 + sin(_shimmer_phase) * RARE_SHIMMER_GAIN * sparkle + sin(_phase * 2.0) * 0.08

	_phase = fmod(_phase + TAU * freq * inv_sr, TAU)
	return clampf(s, -1.0, 1.0)


## Visor: nível 1 só barras; nível 2 + material; nível 3 + profundidade e tamanho.
func get_readout_text() -> String:
	var level: int = get_detector_level()
	if not is_instance_valid(_current_target) or _current_distance > max_detection_distance:
		return "DETETOR PRONTO  Nv.%d\nSinal: ---\nProf: ---\nMat: ---\nTam: ---" % level

	var signal_strength: float = get_signal_strength()

	var bars_count: int = int(round(signal_strength * 6.0))
	var bars_text: String = ""
	for i: int in range(6):
		if i < bars_count:
			bars_text += "█"
		else:
			bars_text += "░"

	var sound_cue: String = "BIP! BIP!" if signal_strength > 0.75 else ("BIP... BIP" if signal_strength > 0.35 else "BIP.......")

	var item: ItemData = _current_target.item
	var prof_text: String = "---"
	var mat_text: String = "---"
	var size_text: String = "---"

	if item != null and level >= 2:
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

	if item != null and level >= 3:
		var approx_min: int = maxi(5, item.depth_cm - 8)
		var approx_max: int = item.depth_cm + 8
		prof_text = "%d-%d cm" % [approx_min, approx_max]

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
