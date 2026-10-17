class_name MetalDetector
extends Node3D

## Detetor de radar: uma linha de varrimento roda e acende blips de BuriedSpots e inimigos.
## O som contínuo foi substituído por um único "ping" discreto por volta, quando a linha passa
## pelo alvo mais próximo. O ecrã do radar é desenhado por DetectorRadar (HUD da própria cena).

signal item_detected(item: ItemData, signal_strength: float)
signal target_lost()
## Emitido sempre que a linha de varrimento acende (ou reacende) um blip.
signal blip_lit(blip: RadarBlip)

## Nível usado quando não existe GameState na cena (só leitura de core/).
@export_range(1, 7) var detector_level: int = 1
## Nível do pinpointer quando não existe GameState (0 = sem pinpointer).
@export_range(0, 2) var pinpointer_level: int = 0
## Alcance no nível 1; cada nível acima soma range_bonus_per_level.
@export var base_detection_distance: float = 8.0
@export var range_bonus_per_level: float = 2.5
## Segundos por volta completa da linha de varrimento.
@export var sweep_period: float = 1.5
@export var scan_interval: float = 0.05
## Mostra também uma cópia do radar no canto inferior esquerdo do ecrã (só para debug).
@export var debug_screen_radar: bool = false

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var coil_tip: Marker3D = $CoilTip
@onready var model: DetectorModel = $Model
@onready var radar_viewport: SubViewport = $RadarViewport

const MAX_LEVEL: int = 7
## Nv.4+: o visor mostra a faixa de valor estimado do alvo.
const VALUE_RANGE_LEVEL: int = 4
## Nv.5+: a variante rara é anunciada a qualquer distância (antes só com sinal forte).
const RARE_ALERT_LEVEL: int = 5
## Nv.6+: inimigos aparecem até ENEMY_RANGE_MULTIPLIER × o alcance (na borda do radar).
const LONG_ENEMY_LEVEL: int = 6
const ENEMY_RANGE_MULTIPLIER: float = 1.5
## Nv.7: identifica o item pelo nome e avisa se ainda falta no museu.
const IDENTIFY_LEVEL: int = 7

# Pinpointer (upgrade "pinpointer"): Nv.1 = bip direcional e zoom nos últimos metros;
# Nv.2 = bússola para a variante rara mais próxima (em todo o mapa).
const PINPOINT_RANGE: float = 2.0
## Abaixo disto o visor diz "CAVE" (dig_range do jogador é 1.8 m, medido dos pés).
const PINPOINT_DIG_DISTANCE: float = 1.5
## Intervalo entre bips a PINPOINT_RANGE e em cima do alvo (s).
const PINPOINT_TICK_FAR: float = 0.45
const PINPOINT_TICK_NEAR: float = 0.08
const PINPOINT_TICK_HZ: float = 2600.0
const PINPOINT_TICK_LENGTH: float = 0.04
const RARE_COMPASS_LEVEL: int = 2
## Escala do radar (m até à borda) enquanto o pinpointer guia.
const PINPOINT_VIEW_DISTANCE: float = 2.5
## Ruído médio que o radar gera enquanto há alvos no alcance; cada ping reporta NOISE_PER_SECOND * sweep_period.
const NOISE_PER_SECOND: float = 1.5
## A partir desta força de sinal, uma variante rara ganha brilho no som e anel no radar.
const RARE_SIGNAL_THRESHOLD: float = 0.7
## Fração da volta que um blip demora a desvanecer.
const BLIP_FADE_FRACTION: float = 0.92
## Chuva (#99, CoreWeather.detector_noise 0..1): blips falsos por segundo com ruído 1 (a chuva
## fica em ~0.35 → um a cada ~6 s), tremor máximo das barras de sinal e do tom do ping.
const WEATHER_FALSE_BLIPS_PER_SEC: float = 0.5
const WEATHER_SIGNAL_JITTER: float = 0.25
const WEATHER_PING_WOBBLE: float = 0.04

# Timbres por material
const IRON_BUZZ_HZ: float = 38.0
const UNKNOWN_VIBRATO_HZ: float = 6.5
const UNKNOWN_VIBRATO_DEPTH: float = 0.09
const RARE_SPARKLE_HZ: float = 9.0
const RARE_SHIMMER_RATIO: float = 2.5
const RARE_SHIMMER_GAIN: float = 0.22

# Envelope do ping: ataque curto e decaimento exponencial suave
const PING_AMPLITUDE: float = 0.2
const PING_ATTACK: float = 0.005
const PING_DECAY: float = 0.07
const PING_LENGTH: float = 0.35


## Um ponto aceso no radar. Guarda a posição no mundo do momento em que a linha passou.
class RadarBlip extends RefCounted:
	var world_pos: Vector3 = Vector3.ZERO
	var age: float = 0.0
	var is_enemy: bool = false
	var material: ItemData.MaterialType = ItemData.MaterialType.FERRO
	var has_item: bool = false
	var depth_cm: int = 0
	var is_rare: bool = false
	var strength: float = 0.0
	## Blip falso da chuva (#99): só desenho, esmaecido; sem ping, alvo nem barulho.
	var is_noise: bool = false


var max_detection_distance: float = 8.0
## Ângulo atual da linha (0 = frente/cima, sentido horário), em radianos.
var sweep_angle: float = 0.0

var _audio_generator: AudioStreamGenerator = null
var _playback: AudioStreamGeneratorPlayback = null
var _sample_rate: float = 22050.0

var _scan_timer: float = 0.0
var _current_target: BuriedSpot = null
var _current_distance: float = 999.0
var _pinged_this_turn: bool = false

## instance_id -> RadarBlip
var _blips: Dictionary = {}

# Parâmetros do ping atual (fixados no início para o timbre não mudar a meio)
var _ping_material: ItemData.MaterialType = ItemData.MaterialType.FERRO
var _ping_freq: float = 440.0
var _ping_rare: bool = false
var _ping_gain: float = 1.0
var _ping_t: float = -1.0

## Ruído do clima (#99): sorteios próprios e chaves negativas para os blips falsos.
var _weather_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _noise_blip_seq: int = 0

var _pin_audio: AudioStreamPlayer3D = null
var _pin_tick_timer: float = 0.0
static var _tick_stream: AudioStreamWAV = null

# Fases dos osciladores (radianos)
var _phase: float = 0.0
var _lfo_phase: float = 0.0
var _shimmer_phase: float = 0.0
var _sparkle_phase: float = 0.0
var _unknown_drift: float = 0.0

# Variáveis de Balanço Procedural (Sway de caminhada)
var _active: bool = true
var _sway_time: float = 0.0
var _initial_pos: Vector3 = Vector3.ZERO
var _initial_rot: Vector3 = Vector3.ZERO


func _ready() -> void:
	_initial_pos = position
	_initial_rot = rotation
	_refresh_level_stats()
	_setup_audio_generator()
	_setup_pinpointer_audio()
	_setup_screen()
	# O detetor é uma ferramenta de inventário: começa guardado até o jogador o equipar.
	set_active(false)


## Liga/desliga o detetor (slot do inventário). Inativo: invisível e sem scan, radar,
## ping nem barulho; o SubViewport do radar deixa de renderizar.
func set_active(active: bool) -> void:
	_active = active
	visible = active
	set_process(active)
	if radar_viewport != null:
		radar_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
		)
	if active:
		if audio_player != null and not audio_player.playing:
			audio_player.play()
			_playback = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
		_refresh_level_stats()
		_update_target_detection()
	else:
		_blips.clear()
		_ping_t = -1.0
		_pin_tick_timer = 0.0
		_pinged_this_turn = false
		if _current_target != null:
			_current_target = null
			_current_distance = 999.0
			target_lost.emit()
		if audio_player != null:
			audio_player.stop()
		_playback = null


func is_active() -> bool:
	return _active


## Aplica a textura do SubViewport do radar ao ecrã da caixa de controlo.
func _setup_screen() -> void:
	if model != null and model.screen_mesh != null and radar_viewport != null:
		var tex: ViewportTexture = radar_viewport.get_texture()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = tex
		mat.emission_enabled = true
		mat.emission_texture = tex
		mat.emission_energy_multiplier = 0.35
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		model.screen_mesh.material_override = mat

	# O visor de texto antigo (Label3D na Hand do player.tscn) passou para dentro do ecrã.
	var old_visor: Node = get_node_or_null("../VisorLabel")
	if old_visor is Node3D:
		(old_visor as Node3D).visible = false

	if debug_screen_radar:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.name = "DebugRadarLayer"
		var radar: DetectorRadar = DetectorRadar.new()
		radar.theme = preload("res://ui/theme/scandig_theme.tres")
		radar.detector = self
		radar.anchor_top = 1.0
		radar.anchor_bottom = 1.0
		radar.offset_left = 24.0
		radar.offset_top = -330.0
		radar.offset_right = 244.0
		radar.offset_bottom = -86.0
		layer.add_child(radar)
		add_child(layer)


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

	_update_sweep(delta)
	_age_blips(delta)
	_fill_audio_buffer()
	_update_pinpointer(delta)


## Nível efetivo: GameState (upgrade comprado) tem prioridade sobre o @export local.
func get_detector_level() -> int:
	var level: int = detector_level
	if GameState.instance != null:
		level = GameState.instance.equipped_detector_level
	return clampi(level, 1, MAX_LEVEL)


func _refresh_level_stats() -> void:
	max_detection_distance = base_detection_distance + range_bonus_per_level * float(get_detector_level() - 1)


## Alcance de verdade agora: o do nível × o clima (cinzas, #99). Lido na hora, sem gravar em
## max_detection_distance (um upgrade não acumula nem apaga o efeito).
func get_effective_detection_distance() -> float:
	return max_detection_distance * WeatherManager.now_radar_scale()


## Alcance para inimigos: igual ao dos itens, ou 1.5× a partir do Nv.6.
func get_enemy_detection_distance() -> float:
	if get_detector_level() >= LONG_ENEMY_LEVEL:
		return get_effective_detection_distance() * ENEMY_RANGE_MULTIPLIER
	return get_effective_detection_distance()


## Nível do pinpointer (0 a 2): GameState (upgrade comprado) tem prioridade sobre o @export.
func get_pinpointer_level() -> int:
	var level: int = pinpointer_level
	if GameState.instance != null:
		level = GameState.instance.get_pinpointer_level()
	return clampi(level, 0, 2)


## A variante rara deste spot já aparece no radar/visor? Sinal forte, ou detector Nv.5+.
func is_rare_revealed(spot: BuriedSpot, signal_strength: float) -> bool:
	if spot == null or not spot.is_rare_variant:
		return false
	return signal_strength >= RARE_SIGNAL_THRESHOLD or get_detector_level() >= RARE_ALERT_LEVEL


func get_signal_strength() -> float:
	if not is_instance_valid(_current_target) or _current_distance > get_effective_detection_distance():
		return 0.0
	return _strength_for_distance(_current_distance)


## Sinal mostrado nas barras: o real com um tremor pequeno na chuva (#99). O alvo continua a
## leitura mais forte; o valor real (get_signal_strength) não muda.
func get_display_strength() -> float:
	var strength: float = get_signal_strength()
	var noise: float = WeatherManager.now_detector_noise()
	if noise <= 0.0 or strength <= 0.0:
		return strength
	return clampf(strength + _weather_rng.randf_range(-1.0, 1.0) * noise * WEATHER_SIGNAL_JITTER, 0.0, 1.0)


func _strength_for_distance(dist: float) -> float:
	var dist_factor: float = clampf((dist - 0.5) / (get_effective_detection_distance() - 0.5), 0.0, 1.0)
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


# ---------------------------------------------------------------------------
# Referencial do radar (centro = jogador, frente da câmara = cima)
# ---------------------------------------------------------------------------

func _get_radar_basis_node() -> Node3D:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam if cam != null else self


func get_radar_center() -> Vector3:
	return _get_radar_basis_node().global_position


## Converte uma posição do mundo para o plano do radar em metros: x = direita, y = frente.
func world_to_radar(world_pos: Vector3) -> Vector2:
	var ref: Node3D = _get_radar_basis_node()
	var basis: Basis = ref.global_transform.basis
	var forward: Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3(-basis.y.x, 0.0, -basis.y.z)
	forward = forward.normalized()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var rel: Vector3 = world_pos - ref.global_position
	rel.y = 0.0
	return Vector2(rel.dot(right), rel.dot(forward))


func _radar_angle(radar_pos: Vector2) -> float:
	return fposmod(atan2(radar_pos.x, radar_pos.y), TAU)


# ---------------------------------------------------------------------------
# Alvo mais próximo (leitura do visor e timbre do ping)
# ---------------------------------------------------------------------------

func _update_target_detection() -> void:
	var spots: Array[Node] = get_tree().get_nodes_in_group("buried_spots")
	var closest_spot: BuriedSpot = null
	var range_m: float = get_effective_detection_distance()
	var min_dist: float = range_m + 0.1

	for spot: Node in spots:
		if spot is BuriedSpot and spot.is_inside_tree():
			var dist: float = world_to_radar((spot as BuriedSpot).global_position).length()
			if dist < min_dist:
				min_dist = dist
				closest_spot = spot

	var had_target: bool = (_current_target != null)

	if min_dist <= range_m and closest_spot != null:
		_current_target = closest_spot
		_current_distance = min_dist
		item_detected.emit(_current_target.item, get_signal_strength())
	else:
		_current_target = null
		_current_distance = 999.0
		if had_target:
			target_lost.emit()


# ---------------------------------------------------------------------------
# Varrimento e blips
# ---------------------------------------------------------------------------

func _update_sweep(delta: float) -> void:
	var step: float = TAU * delta / maxf(sweep_period, 0.1)
	var prev: float = sweep_angle
	sweep_angle = fposmod(prev + step, TAU)
	if sweep_angle < prev:
		_pinged_this_turn = false

	for spot: Node in get_tree().get_nodes_in_group("buried_spots"):
		if spot is BuriedSpot and spot.is_inside_tree():
			_sweep_check(spot as Node3D, false, prev, step)

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D and enemy.is_inside_tree():
			_sweep_check(enemy as Node3D, true, prev, step)

	var noise: float = WeatherManager.now_detector_noise()
	if noise > 0.0 and _weather_rng.randf() < noise * WEATHER_FALSE_BLIPS_PER_SEC * delta:
		add_weather_noise_blip()


## Chuva (#99): um blip falso fraco na linha do varrimento. Não vira alvo, não toca ping e não
## faz barulho (o DisturbanceMeter só ouve o ping do alvo real).
func add_weather_noise_blip() -> RadarBlip:
	var ref: Node3D = _get_radar_basis_node()
	var dist: float = get_effective_detection_distance() * _weather_rng.randf_range(0.3, 0.95)
	var angle: float = sweep_angle + _weather_rng.randf_range(-0.05, 0.05)
	var basis: Basis = ref.global_transform.basis
	var forward: Vector3 = Vector3(-basis.z.x, 0.0, -basis.z.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3(-basis.y.x, 0.0, -basis.y.z)
	forward = forward.normalized()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	var blip: RadarBlip = RadarBlip.new()
	blip.world_pos = ref.global_position + (right * sin(angle) + forward * cos(angle)) * dist
	blip.is_noise = true
	blip.strength = _weather_rng.randf_range(0.1, 0.3)
	_noise_blip_seq += 1
	_blips[-_noise_blip_seq] = blip
	return blip


func _sweep_check(node: Node3D, is_enemy: bool, prev_angle: float, step: float) -> void:
	var radar_pos: Vector2 = world_to_radar(node.global_position)
	var dist: float = radar_pos.length()
	if dist > (get_enemy_detection_distance() if is_enemy else get_effective_detection_distance()):
		return
	if fposmod(_radar_angle(radar_pos) - prev_angle, TAU) > step:
		return

	var id: int = node.get_instance_id()
	var blip: RadarBlip = _blips.get(id) as RadarBlip
	if blip == null:
		blip = RadarBlip.new()
		_blips[id] = blip
	blip.world_pos = node.global_position
	blip.age = 0.0
	blip.is_enemy = is_enemy
	blip.strength = _strength_for_distance(dist)

	if not is_enemy:
		var spot: BuriedSpot = node as BuriedSpot
		blip.has_item = spot.item != null
		blip.material = spot.item.material_type if spot.item != null else ItemData.MaterialType.FERRO
		blip.depth_cm = spot.item.depth_cm if spot.item != null else 0
		blip.is_rare = is_rare_revealed(spot, blip.strength)
		if spot == _current_target and not _pinged_this_turn:
			_pinged_this_turn = true
			_start_ping(spot, blip.strength)

	blip_lit.emit(blip)


func _age_blips(delta: float) -> void:
	var lifetime: float = sweep_period * BLIP_FADE_FRACTION
	for id: int in _blips.keys():
		var blip: RadarBlip = _blips[id] as RadarBlip
		blip.age += delta
		if blip.age >= lifetime:
			_blips.erase(id)


## Blips visíveis com alpha de desvanecimento (1 = acabou de acender).
func get_blips() -> Array[RadarBlip]:
	var out: Array[RadarBlip] = []
	for blip: Variant in _blips.values():
		out.append(blip as RadarBlip)
	return out


func get_blip_alpha(blip: RadarBlip) -> float:
	var lifetime: float = sweep_period * BLIP_FADE_FRACTION
	var t: float = clampf(blip.age / lifetime, 0.0, 1.0)
	return 1.0 - t * t


func get_current_target() -> BuriedSpot:
	return _current_target if is_instance_valid(_current_target) else null


func get_target_count() -> int:
	var count: int = 0
	for blip: Variant in _blips.values():
		if not (blip as RadarBlip).is_enemy and not (blip as RadarBlip).is_noise:
			count += 1
	return count


func get_enemy_count() -> int:
	var count: int = 0
	for blip: Variant in _blips.values():
		if (blip as RadarBlip).is_enemy:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Ping sonoro (um por volta, timbre por material)
# ---------------------------------------------------------------------------

func _start_ping(spot: BuriedSpot, signal_strength: float) -> void:
	var item: ItemData = spot.item
	_ping_material = item.material_type if item != null else ItemData.MaterialType.FERRO
	_ping_freq = _get_frequency_for_item(item)
	_ping_rare = is_rare_revealed(spot, signal_strength)
	_ping_gain = lerpf(0.45, 1.0, signal_strength)
	# Chuva (#99): o tom oscila um pouco (o material continua reconhecível).
	_ping_freq *= 1.0 + _weather_rng.randf_range(-1.0, 1.0) * WeatherManager.now_detector_noise() * WEATHER_PING_WOBBLE
	_ping_t = 0.0
	_reset_oscillators()

	var noise_origin: Vector3 = coil_tip.global_position if coil_tip != null else global_position
	DisturbanceMeter.report(NOISE_PER_SECOND * sweep_period, noise_origin)


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


func _fill_audio_buffer() -> void:
	if _playback == null:
		return

	var frames_available: int = _playback.get_frames_available()
	if frames_available <= 0:
		return

	var inv_sr: float = 1.0 / _sample_rate
	for i: int in range(frames_available):
		var sample: float = 0.0
		if _ping_t >= 0.0:
			var env: float = minf(_ping_t / PING_ATTACK, 1.0) * exp(-_ping_t / PING_DECAY)
			sample = _synth_sample() * env * PING_AMPLITUDE * _ping_gain
			_ping_t += inv_sr
			if _ping_t >= PING_LENGTH:
				_ping_t = -1.0
		_playback.push_frame(Vector2(sample, sample))


func _reset_oscillators() -> void:
	_phase = 0.0
	_lfo_phase = 0.0
	_shimmer_phase = 0.0
	_sparkle_phase = 0.0
	_unknown_drift = 0.0


## Gera uma amostra normalizada (-1..1) com o timbre do material do ping atual.
func _synth_sample() -> float:
	var inv_sr: float = 1.0 / _sample_rate
	var freq: float = _ping_freq
	var s: float = 0.0

	match _ping_material:
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

	if _ping_rare:
		# Brilho extra: harmónico não inteiro cintilante sobre o timbre base
		_shimmer_phase = fmod(_shimmer_phase + TAU * freq * RARE_SHIMMER_RATIO * inv_sr, TAU)
		_sparkle_phase = fmod(_sparkle_phase + TAU * RARE_SPARKLE_HZ * inv_sr, TAU)
		var sparkle: float = 0.5 + 0.5 * sin(_sparkle_phase)
		s = s * 0.85 + sin(_shimmer_phase) * RARE_SHIMMER_GAIN * sparkle + sin(_phase * 2.0) * 0.08

	_phase = fmod(_phase + TAU * freq * inv_sr, TAU)
	return clampf(s, -1.0, 1.0)


# ---------------------------------------------------------------------------
# Pinpointer: Nv.1 bip direcional (som 3D no ponto) + zoom do radar nos últimos
# PINPOINT_RANGE m; Nv.2 bússola para a variante rara mais próxima.
# ---------------------------------------------------------------------------

func _setup_pinpointer_audio() -> void:
	_pin_audio = AudioStreamPlayer3D.new()
	_pin_audio.name = "PinpointerAudio"
	# Fica no mundo, em cima do alvo: o bip vem da direção do ponto exato.
	_pin_audio.top_level = true
	_pin_audio.stream = get_tick_stream()
	_pin_audio.bus = SFX.BUS
	_pin_audio.volume_db = -8.0
	_pin_audio.unit_size = 3.0
	_pin_audio.max_distance = 10.0
	add_child(_pin_audio)


## Bip curto e agudo gerado uma vez (seno com decaimento rápido).
static func get_tick_stream() -> AudioStreamWAV:
	if _tick_stream != null:
		return _tick_stream
	var rate: int = 22050
	var frames: int = int(float(rate) * PINPOINT_TICK_LENGTH)
	var data: PackedByteArray = PackedByteArray()
	data.resize(frames * 2)
	for i: int in frames:
		var t: float = float(i) / float(rate)
		var s: float = sin(TAU * PINPOINT_TICK_HZ * t) * minf(t / 0.002, 1.0) * exp(-t / 0.012) * 0.7
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	_tick_stream = AudioStreamWAV.new()
	_tick_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_tick_stream.mix_rate = rate
	_tick_stream.stereo = false
	_tick_stream.data = data
	return _tick_stream


## Distância (m, no plano do radar) ao alvo atual; INF sem alvo.
func get_target_distance() -> float:
	return _current_distance if get_current_target() != null else INF


## O pinpointer está a guiar? Nv.1+ e o alvo a ≤ PINPOINT_RANGE m.
func is_pinpointing() -> bool:
	return get_pinpointer_level() >= 1 and get_target_distance() <= PINPOINT_RANGE


## Metros do centro à borda do radar: zoom de PINPOINT_VIEW_DISTANCE enquanto o pinpointer guia.
func get_radar_view_distance() -> float:
	return PINPOINT_VIEW_DISTANCE if is_pinpointing() else get_effective_detection_distance()


## Segundos entre bips: PINPOINT_TICK_FAR a PINPOINT_RANGE m, PINPOINT_TICK_NEAR em cima do alvo.
static func get_pinpoint_tick_interval(distance: float) -> float:
	return lerpf(PINPOINT_TICK_NEAR, PINPOINT_TICK_FAR, clampf(distance / PINPOINT_RANGE, 0.0, 1.0))


## Seta (8 rumos) para um vetor no plano do radar (x = direita, y = frente).
static func get_direction_arrow(radar_pos: Vector2) -> String:
	if radar_pos.length_squared() < 0.0001:
		return "•"
	var arrows: Array[String] = ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
	var sector: int = int(round(fposmod(atan2(radar_pos.x, radar_pos.y), TAU) / (TAU / 8.0))) % 8
	return arrows[sector]


## Linha do pinpointer no visor ("" quando não está a guiar).
func get_pinpoint_text() -> String:
	if not is_pinpointing():
		return ""
	if _current_distance <= PINPOINT_DIG_DISTANCE:
		return "PIN ✔ CAVE"
	var dir: Vector2 = world_to_radar(get_current_target().global_position)
	return "PIN %s %.1fm" % [get_direction_arrow(dir), _current_distance]


## Pinpointer Nv.2: vetor (plano do radar) até à variante rara mais próxima, a qualquer
## distância; Vector2.ZERO se não houver nenhuma ou sem o Nv.2.
func get_rare_compass() -> Vector2:
	if get_pinpointer_level() < RARE_COMPASS_LEVEL or not is_inside_tree():
		return Vector2.ZERO
	var best: Vector2 = Vector2.ZERO
	var best_len: float = INF
	for node: Node in get_tree().get_nodes_in_group("buried_spots"):
		var spot: BuriedSpot = node as BuriedSpot
		if spot == null or not spot.is_inside_tree() or not spot.is_rare_variant or spot.item == null:
			continue
		var v: Vector2 = world_to_radar(spot.global_position)
		if v.length() < best_len:
			best_len = v.length()
			best = v
	return best


func _update_pinpointer(delta: float) -> void:
	if not is_pinpointing():
		_pin_tick_timer = 0.0
		return
	_pin_tick_timer -= delta
	if _pin_tick_timer > 0.0:
		return
	_pin_tick_timer = get_pinpoint_tick_interval(_current_distance)
	if _pin_audio != null and _pin_audio.is_inside_tree():
		_pin_audio.global_position = get_current_target().global_position
		_pin_audio.pitch_scale = 1.35 if _current_distance <= PINPOINT_DIG_DISTANCE else 1.0
		_pin_audio.play()


# ---------------------------------------------------------------------------
# Visor (Label3D no aparelho) — resumo coerente com o radar
# ---------------------------------------------------------------------------

static func get_material_name(material: ItemData.MaterialType) -> String:
	match material:
		ItemData.MaterialType.FERRO:
			return "Ferro"
		ItemData.MaterialType.ALUMINIO:
			return "Alumínio"
		ItemData.MaterialType.PRATA:
			return "Prata"
		ItemData.MaterialType.OURO:
			return "Ouro"
		ItemData.MaterialType.DESCONHECIDO:
			return "Desconhecido (?)"
	return "---"


## Faixa aproximada de profundidade do alvo (±8 cm), ou "" sem item.
static func get_depth_range_text(item: ItemData) -> String:
	if item == null:
		return ""
	return "%d-%d cm" % [maxi(5, item.depth_cm - 8), item.depth_cm + 8]


## Faixa de valor (R$) do Nv.4 em diante: do pior caso (pazadas rápidas nas 2 últimas
## camadas, mesma conta do BuriedSpot.dig) à escavação perfeita; × 3 se for variante rara.
static func get_value_range(item: ItemData, rare: bool) -> Vector2i:
	if item == null:
		return Vector2i.ZERO
	var mult: float = BuriedSpot.RARE_VALUE_MULTIPLIER if rare else 1.0
	var crack: float = clampf(item.fragility * 0.45, 0.08, 0.90)
	var worst: float = clampf(1.0 - 2.0 * crack, 0.05, 1.0)
	var lo: int = int(round(float(item.calculate_value(worst)) * mult))
	var hi: int = int(round(float(item.base_value) * mult * BuriedSpot.PERFECT_BONUS_MULTIPLIER))
	return Vector2i(lo, hi)


## Nv.7: nome do item; "Novo: " se a equipa ainda não o descobriu (falta no museu).
static func get_identify_text(item: ItemData) -> String:
	if item == null:
		return "---"
	var item_name: String = item.display_name if not item.display_name.is_empty() else item.id
	if GameState.instance != null and not GameState.instance.discovered_items.has(item.id):
		return "Novo: " + item_name
	return item_name


static func get_size_name(size: ItemData.SizeCategory) -> String:
	match size:
		ItemData.SizeCategory.PEQUENO:
			return "Pequeno"
		ItemData.SizeCategory.MEDIO:
			return "Médio"
		ItemData.SizeCategory.GRANDE:
			return "Grande"
		ItemData.SizeCategory.COLOSSAL:
			return "Colossal"
	return "---"


func _signal_bars() -> String:
	var bars_count: int = int(round(get_display_strength() * 6.0))
	var bars_text: String = ""
	for i: int in range(6):
		bars_text += "█" if i < bars_count else "░"
	return bars_text


## Linhas por baixo do radar (DetectorRadar) por nível:
## Nv.1 sinal · Nv.2 + material · Nv.3 + profundidade · Nv.4 + faixa de valor ·
## Nv.5 raro a qualquer distância (★x3) · Nv.6 inimigos a 1.5× · Nv.7 nome do item.
## Pinpointer: "PIN ↗ 1.3m" no lugar do sinal (Nv.1) e "★12m" até ao raro mais próximo (Nv.2).
func get_footer_lines() -> PackedStringArray:
	var level: int = get_detector_level()
	var lines: PackedStringArray = PackedStringArray()
	var head: String = "Nv.%d  %dm" % [level, int(round(get_effective_detection_distance()))]
	var enemies: int = get_enemy_count()
	if enemies > 0:
		head += "  ⚠%d" % enemies
	var compass: Vector2 = get_rare_compass()
	if compass != Vector2.ZERO:
		head += "  ★%dm" % int(round(compass.length()))
	lines.append(head)

	var pin: String = get_pinpoint_text()
	lines.append(pin if not pin.is_empty() else "Sinal " + _signal_bars())

	var target: BuriedSpot = get_current_target()
	var item: ItemData = target.item if target != null else null
	if level >= IDENTIFY_LEVEL and item != null:
		lines.append(get_identify_text(item))
	else:
		lines.append("Mat: " + (get_material_name(item.material_type) if item != null and level >= 2 else "---"))
	lines.append("Prof: " + (get_depth_range_text(item) if item != null and level >= 3 else "---"))
	if level >= VALUE_RANGE_LEVEL:
		var val_text: String = "---"
		if item != null:
			var rare: bool = is_rare_revealed(target, get_signal_strength())
			var r: Vector2i = get_value_range(item, rare)
			val_text = "%s–%s%s" % [MoneyFormat.money(r.x), MoneyFormat.thousands(r.y), " ★x3" if rare else ""]
		lines.append("Val: " + val_text)
	return lines


## Visor de texto (debug/legado): o mesmo que o rodapé do radar, mais o tamanho (Nv.3+).
func get_readout_text() -> String:
	var lines: PackedStringArray = get_footer_lines()
	var target: BuriedSpot = get_current_target()
	if target != null and target.item != null and get_detector_level() >= 3:
		lines.append("Tam: " + get_size_name(target.item.size_category))
	return "\n".join(lines)
