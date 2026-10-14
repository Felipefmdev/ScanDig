class_name SFX
extends RefCounted

## Efeitos sonoros partilhados (Dev A). Uso:
##   SFX.play_at(SFX.DIG_FAST, global_position)            # posicional (AudioStreamPlayer3D)
##   SFX.play_ui(SFX.BUY)                                  # sem posição (AudioStreamPlayer)
## Cada chave do banco é uma lista de variantes: escolhe-se uma ao acaso e aplica-se uma
## pequena variação de pitch. Tudo toca no bus "SFX" (volume global em default_bus_layout.tres).
## Os streams ficam em cache depois do primeiro load.

const BUS: StringName = &"SFX"
const DEFAULT_PITCH_VAR: float = 0.08

const _IMPACT: String = "res://assets/audio/kenney_impact-sounds/"
const _RPG: String = "res://assets/audio/kenney_rpg-audio/"
const _UI: String = "res://assets/audio/kenney_interface-sounds/"
const _GEN: String = "res://assets/audio/generated/"

# --- Jogador / ferramentas ---------------------------------------------------
const DIG_FAST: Array[String] = [_IMPACT + "impactSoft_heavy_000.ogg", _IMPACT + "impactSoft_heavy_001.ogg", _IMPACT + "impactSoft_heavy_002.ogg"]
const DIG_CAREFUL: Array[String] = [_IMPACT + "impactSoft_medium_000.ogg", _IMPACT + "impactSoft_medium_001.ogg"]
const DIRT_FALL: Array[String] = [_IMPACT + "footstep_snow_001.ogg", _IMPACT + "footstep_snow_003.ogg"]
const FOOTSTEP_SAND: Array[String] = [_IMPACT + "footstep_snow_000.ogg", _IMPACT + "footstep_snow_001.ogg", _IMPACT + "footstep_snow_002.ogg", _IMPACT + "footstep_snow_003.ogg", _IMPACT + "footstep_snow_004.ogg"]
const PICKUP: Array[String] = [_RPG + "handleSmallLeather.ogg"]
const DROP: Array[String] = [_RPG + "dropLeather.ogg"]
const DELIVER_COINS: Array[String] = [_RPG + "handleCoins.ogg", _RPG + "handleCoins2.ogg"]
const BUY: Array[String] = [_UI + "confirmation_002.ogg"]
const ERROR: Array[String] = [_UI + "error_006.ogg"]
const SLINGSHOT_STRETCH: Array[String] = [_RPG + "creak1.ogg"]
const SLINGSHOT_FIRE: Array[String] = [_RPG + "beltHandle1.ogg"]
const STONE_IMPACT: Array[String] = [_IMPACT + "impactGeneric_light_000.ogg", _IMPACT + "impactGeneric_light_001.ogg"]
const SPRAY: Array[String] = [_GEN + "spray_hiss.wav"]
const NET_CLOSE: Array[String] = [_RPG + "cloth3.ogg"]
const MEDKIT: Array[String] = [_UI + "confirmation_004.ogg"]
const PLAYER_HURT: Array[String] = [_IMPACT + "impactPunch_medium_000.ogg", _IMPACT + "impactPunch_medium_001.ogg"]
const PLAYER_DEATH: Array[String] = [_IMPACT + "impactPunch_heavy_000.ogg"]
const RESPAWN: Array[String] = [_UI + "maximize_006.ogg"]

# --- Inimigos (para o Dev_Detector ligar) -----------------------------------
const CRAB_PINCH: Array[String] = [_RPG + "knifeSlice2.ogg", _RPG + "metalClick.ogg"]
const SEAGULL_CAW: Array[String] = [_GEN + "gull_caw.wav"]
const SEAGULL_DIVE: Array[String] = [_GEN + "gull_dive.wav"]
const SHELL_KNOCK: Array[String] = [_IMPACT + "impactPlate_light_000.ogg", _IMPACT + "impactPlate_light_001.ogg"]
const EMERGE_SAND: Array[String] = [_IMPACT + "impactSoft_medium_002.ogg", _IMPACT + "footstep_snow_004.ogg"]

static var _cache: Dictionary = {}


## Toca um som posicional em `pos`. `sound` pode ser uma lista de caminhos (do banco
## acima), um caminho String ou um AudioStream. Devolve o player (ou null).
static func play_at(sound: Variant, pos: Vector3, volume_db: float = 0.0, pitch_var: float = DEFAULT_PITCH_VAR) -> AudioStreamPlayer3D:
	var stream: AudioStream = _resolve(sound)
	var parent: Node = _parent()
	if stream == null or parent == null:
		return null
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = BUS
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.unit_size = 6.0
	p.max_distance = 45.0
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Toca um som sem posição (UI, respostas ao próprio jogador).
static func play_ui(sound: Variant, volume_db: float = 0.0, pitch_var: float = 0.03) -> AudioStreamPlayer:
	var stream: AudioStream = _resolve(sound)
	var parent: Node = _parent()
	if stream == null or parent == null:
		return null
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = BUS
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


static func _resolve(sound: Variant) -> AudioStream:
	if sound is AudioStream:
		return sound
	var path: String = ""
	if sound is Array:
		var arr: Array = sound
		if arr.is_empty():
			return null
		path = str(arr.pick_random())
	else:
		path = str(sound)
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func _parent() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root
