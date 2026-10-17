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
const _GEN: String = "res://assets/audio/generated/"  # sons de areia: tools/gen_sand_sfx.py (pico -3 dBFS)

# --- Jogador / ferramentas ---------------------------------------------------
const DIG_FAST: Array[String] = [_GEN + "sand_dig_fast_0.wav", _GEN + "sand_dig_fast_1.wav", _GEN + "sand_dig_fast_2.wav"]
const DIG_CAREFUL: Array[String] = [_GEN + "sand_dig_careful_0.wav", _GEN + "sand_dig_careful_1.wav"]
const DIRT_FALL: Array[String] = [_GEN + "sand_throw_0.wav", _GEN + "sand_throw_1.wav"]
const FOOTSTEP_SAND: Array[String] = [_GEN + "sand_step_0.wav", _GEN + "sand_step_1.wav", _GEN + "sand_step_2.wav", _GEN + "sand_step_3.wav", _GEN + "sand_step_4.wav"]
const FOOTSTEP_SNOW: Array[String] = [_IMPACT + "footstep_snow_004.ogg"]
const FOOTSTEP_GRASS: Array[String] = [_IMPACT + "impactSoft_medium_002.ogg"]
const FOOTSTEP_STONE: Array[String] = [_IMPACT + "impactGeneric_light_000.ogg", _IMPACT + "impactGeneric_light_001.ogg"]
const FOOTSTEP_CRYSTAL: Array[String] = [_IMPACT + "impactPlate_light_000.ogg", _IMPACT + "impactPlate_light_001.ogg"]
const FOOTSTEP_WATER: Array[String] = [_GEN + "water_step_0.wav", _GEN + "water_step_1.wav", _GEN + "water_step_2.wav"]
const FOOTSTEP_WOOD: Array[String] = [_IMPACT + "impactSoft_medium_002.ogg", _RPG + "dropLeather.ogg"]

const ITEM_IMPACT_METAL: Array[String] = [_IMPACT + "impactPlate_light_000.ogg", _IMPACT + "impactPlate_light_001.ogg", _RPG + "metalClick.ogg"]
const ITEM_IMPACT_STONE: Array[String] = [_IMPACT + "impactGeneric_light_000.ogg", _IMPACT + "impactGeneric_light_001.ogg"]
const ITEM_IMPACT_WOOD: Array[String] = [_IMPACT + "impactSoft_medium_002.ogg", _RPG + "dropLeather.ogg"]
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


## Devolve a lista de sons de passos para a superfície `surface` (How to Fish SurfaceManager).
static func footstep_sound_for_surface(surface: StringName) -> Array[String]:
	match surface:
		&"snow", &"neve", &"gelo", &"ice":
			return FOOTSTEP_SNOW
		&"grass", &"relva", &"terra", &"dirt":
			return FOOTSTEP_GRASS
		&"stone", &"pedra", &"ruinas", &"laje":
			return FOOTSTEP_STONE
		&"crystal", &"cristal", &"rocha", &"cratera":
			return FOOTSTEP_CRYSTAL
		&"water", &"agua", &"mar":
			return FOOTSTEP_WATER
		&"wood", &"madeira":
			return FOOTSTEP_WOOD
		_:
			return FOOTSTEP_SAND


## Offset de volume em dB para equalizar o nível aparente do passo de cada material.
static func footstep_volume_offset(surface: StringName) -> float:
	match surface:
		&"stone", &"pedra", &"ruinas", &"laje":
			return -4.0
		&"crystal", &"cristal", &"rocha", &"cratera":
			return -5.0
		&"water", &"agua", &"mar":
			return -2.5
		&"grass", &"relva", &"terra", &"dirt":
			return -2.0
		&"wood", &"madeira":
			return -2.0
		_:
			return 0.0


## Devolve o som de impacto para o tipo de material de um item.
static func item_impact_sound(material_type: int) -> Array[String]:
	match material_type:
		0, 1, 2, 3:  # FERRO, ALUMINIO, PRATA, OURO
			return ITEM_IMPACT_METAL
		_:
			return ITEM_IMPACT_STONE


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
