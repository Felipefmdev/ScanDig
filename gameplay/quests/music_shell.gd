class_name MusicShell
extends Interactable

## Concha que toca uma nota ao usar [E] (#40). A nota é sintetizada em código (parciais
## inarmónicos tipo marimba/vidro + sopro no ataque + decaimento exponencial), sem ficheiros
## de áudio. O host decide e toca em todos os peers; emite `interacted` (SequencePuzzle).

const SAMPLE_RATE: int = 22050
const NOTE_SECONDS: float = 1.6
## Pentatónica de Dó (Hz): dó, ré, mi, sol, lá (oitava 5).
const NOTES: PackedFloat32Array = [523.25, 587.33, 659.25, 783.99, 880.0]
const NAMES: PackedStringArray = ["dó", "ré", "mi", "sol", "lá"]

## Índice em NOTES.
@export_range(0, 4) var note: int = 0

static var _cache: Dictionary = {}

var _base_scale: Vector3 = Vector3.ZERO


func _on_interact(peer_id: int) -> void:
	play_note()
	HostSync.broadcast(self, &"_rpc_play")
	super._on_interact(peer_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_play() -> void:
	play_note()


## Local: toca a nota e abana a concha.
func play_note() -> void:
	SFX.play_at(make_note(NOTES[clampi(note, 0, NOTES.size() - 1)]), get_focus_point(), 2.0, 0.0)
	var model: Node3D = get_node_or_null(^"Model") as Node3D
	if model != null:
		if _base_scale == Vector3.ZERO:
			_base_scale = model.scale
		var tw: Tween = create_tween()
		tw.tween_property(model, "scale", _base_scale * 1.18, 0.07)
		tw.tween_property(model, "scale", _base_scale, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func get_note_name() -> String:
	return NAMES[clampi(note, 0, NAMES.size() - 1)]


## Nota sintetizada (cache por frequência).
static func make_note(freq: float) -> AudioStreamWAV:
	var key: int = int(freq * 100.0)
	if _cache.has(key):
		return _cache[key]
	var n: int = int(NOTE_SECONDS * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	# Parciais de uma barra/concha (razões inarmónicas) com decaimentos diferentes.
	var ratios: PackedFloat32Array = [1.0, 2.76, 5.4, 8.93]
	var amps: PackedFloat32Array = [1.0, 0.42, 0.18, 0.08]
	var decays: PackedFloat32Array = [2.6, 5.5, 9.0, 14.0]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = key
	var noise_lp: float = 0.0
	for i: int in n:
		var t: float = float(i) / SAMPLE_RATE
		var s: float = 0.0
		for k: int in ratios.size():
			s += sin(TAU * freq * ratios[k] * t) * amps[k] * exp(-decays[k] * t)
		# Sopro no ataque (ruído filtrado) e entrada suave para não estalar.
		noise_lp = lerpf(noise_lp, rng.randf_range(-1.0, 1.0), 0.25)
		s += noise_lp * 0.25 * exp(-40.0 * t)
		s *= minf(t / 0.004, 1.0) * 0.55
		var v: int = clampi(int(s * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, v)
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	_cache[key] = wav
	return wav
