class_name MetalDetector
extends Node3D

@export var max_detection_distance: float = 8.0
@export var min_beep_interval: float = 0.08
@export var max_beep_interval: float = 1.20

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

var _audio_generator: AudioStreamGenerator = null
var _playback: AudioStreamGeneratorPlayback = null
var _sample_rate: float = 22050.0

var _time_since_last_beep: float = 0.0
var _current_target: BuriedSpot = null
var _current_distance: float = 999.0
var _current_freq: float = 440.0
var _is_beeping: bool = false
var _beep_timer: float = 0.0
var _beep_duration: float = 0.045
var _phase: float = 0.0


func _ready() -> void:
	_setup_audio_generator()


func _setup_audio_generator() -> void:
	_audio_generator = AudioStreamGenerator.new()
	_audio_generator.mix_rate = _sample_rate
	_audio_generator.buffer_length = 0.15
	audio_player.stream = _audio_generator
	audio_player.play()
	_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(delta: float) -> void:
	_update_target_detection()
	_update_beeping(delta)
	_fill_audio_buffer()


func _update_target_detection() -> void:
	var spots: Array[Node] = get_tree().get_nodes_in_group("buried_spots")
	var closest_spot: BuriedSpot = null
	var min_dist: float = max_detection_distance + 0.1
	var detector_pos: Vector3 = global_position

	for spot in spots:
		if spot is BuriedSpot and spot.is_inside_tree():
			var dist: float = detector_pos.distance_to(spot.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_spot = spot

	if min_dist <= max_detection_distance and closest_spot != null:
		_current_target = closest_spot
		_current_distance = min_dist
		_current_freq = _get_frequency_for_item(_current_target.item)
	else:
		_current_target = null
		_current_distance = 999.0


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
	if _current_target == null or _current_distance > max_detection_distance:
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

	for i in range(frames_available):
		var sample: float = 0.0
		if _is_beeping:
			sample = sin(_phase) * 0.35
			_phase = fmod(_phase + phase_step, TAU)
		else:
			_phase = 0.0
		_playback.push_frame(Vector2(sample, sample))


func get_readout_text() -> String:
	if _current_target == null or _current_distance > max_detection_distance:
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
