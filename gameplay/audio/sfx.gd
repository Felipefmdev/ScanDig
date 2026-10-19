class_name SFX
extends RefCounted

## Efeitos sonoros partilhados (Dev A). Uso:
##   SFX.play_at(SFX.DIG_FAST, global_position)            # posicional (AudioStreamPlayer3D)
##   SFX.play_ui(SFX.BUY)                                  # sem posição (AudioStreamPlayer)
## Cada chave do banco é uma lista de variantes: escolhe-se uma ao acaso e aplica-se uma
## pequena variação de pitch. Tudo toca no bus "SFX" (volume global em default_bus_layout.tres).
## Os streams ficam em cache depois do primeiro load.
## Arquivos normalizados por tools/gen_audio.py (pico -3 dBFS, RMS ~-18; #123): o nível de cada
## tipo de som e o alcance 3D se acertam em CATEGORY_DB/CATEGORY_RANGE, num lugar só.
## Origem e licença (CC0) de cada arquivo: assets/audio/CREDITS.md.

const BUS: StringName = &"SFX"
const DEFAULT_PITCH_VAR: float = 0.08

const _IMPACT: String = "res://assets/audio/kenney_impact-sounds/"
const _RPG: String = "res://assets/audio/kenney_rpg-audio/"
const _UI: String = "res://assets/audio/kenney_interface-sounds/"
const _GEN: String = "res://assets/audio/generated/"  # tools/gen_sand_sfx.py (.wav) e tools/gen_audio.py (.ogg)

# --- Passos por superfície (3-5 variantes cada) -----------------------------------------
const FOOTSTEP_SAND: Array[String] = [_GEN + "sand_step_0.wav", _GEN + "sand_step_1.wav", _GEN + "sand_step_2.wav", _GEN + "sand_step_3.wav", _GEN + "sand_step_4.wav"]
const FOOTSTEP_SNOW: Array[String] = [_IMPACT + "footstep_snow_000.ogg", _IMPACT + "footstep_snow_001.ogg", _IMPACT + "footstep_snow_002.ogg", _IMPACT + "footstep_snow_003.ogg", _IMPACT + "footstep_snow_004.ogg"]
const FOOTSTEP_GRASS: Array[String] = [_IMPACT + "footstep_grass_000.ogg", _IMPACT + "footstep_grass_001.ogg", _IMPACT + "footstep_grass_002.ogg", _IMPACT + "footstep_grass_003.ogg", _IMPACT + "footstep_grass_004.ogg"]
const FOOTSTEP_STONE: Array[String] = [_IMPACT + "footstep_concrete_000.ogg", _IMPACT + "footstep_concrete_001.ogg", _IMPACT + "footstep_concrete_002.ogg", _IMPACT + "footstep_concrete_003.ogg", _IMPACT + "footstep_concrete_004.ogg"]
const FOOTSTEP_CRYSTAL: Array[String] = [_GEN + "gravel_step_0.ogg", _GEN + "gravel_step_1.ogg", _GEN + "gravel_step_2.ogg", _GEN + "gravel_step_3.ogg", _GEN + "gravel_step_4.ogg"]
const FOOTSTEP_WATER: Array[String] = [_GEN + "water_step_0.wav", _GEN + "water_step_1.wav", _GEN + "water_step_2.wav"]
const FOOTSTEP_WOOD: Array[String] = [_IMPACT + "footstep_wood_000.ogg", _IMPACT + "footstep_wood_001.ogg", _IMPACT + "footstep_wood_002.ogg", _IMPACT + "footstep_wood_003.ogg", _IMPACT + "footstep_wood_004.ogg"]
const JUMP: Array[String] = [_RPG + "cloth1.ogg", _RPG + "cloth2.ogg"]
const LAND: Array[String] = [_IMPACT + "impactSoft_heavy_000.ogg", _IMPACT + "impactSoft_heavy_001.ogg", _IMPACT + "impactSoft_heavy_002.ogg"]

# --- Cavar por superfície (o mesmo detector de superfície dos passos) --------------------
const DIG_FAST: Array[String] = [_GEN + "sand_dig_fast_0.wav", _GEN + "sand_dig_fast_1.wav", _GEN + "sand_dig_fast_2.wav"]
const DIG_CAREFUL: Array[String] = [_GEN + "sand_dig_careful_0.wav", _GEN + "sand_dig_careful_1.wav"]
const DIG_FAST_DIRT: Array[String] = [_GEN + "dirt_dig_fast_0.ogg", _GEN + "dirt_dig_fast_1.ogg", _GEN + "dirt_dig_fast_2.ogg"]
const DIG_CAREFUL_DIRT: Array[String] = [_GEN + "dirt_dig_careful_0.ogg", _GEN + "dirt_dig_careful_1.ogg"]
const DIG_FAST_SNOW: Array[String] = [_GEN + "snow_dig_fast_0.ogg", _GEN + "snow_dig_fast_1.ogg", _GEN + "snow_dig_fast_2.ogg"]
const DIG_CAREFUL_SNOW: Array[String] = [_GEN + "snow_dig_careful_0.ogg", _GEN + "snow_dig_careful_1.ogg"]
const DIG_FAST_STONE: Array[String] = [_GEN + "stone_dig_fast_0.ogg", _GEN + "stone_dig_fast_1.ogg", _GEN + "stone_dig_fast_2.ogg"]
const DIG_CAREFUL_STONE: Array[String] = [_GEN + "stone_dig_careful_0.ogg", _GEN + "stone_dig_careful_1.ogg"]
const DIRT_FALL: Array[String] = [_GEN + "sand_throw_0.wav", _GEN + "sand_throw_1.wav"]

# --- Itens e ferramentas -----------------------------------------------------------------
const ITEM_IMPACT_METAL: Array[String] = [_IMPACT + "impactPlate_light_000.ogg", _IMPACT + "impactPlate_light_001.ogg", _RPG + "metalClick.ogg"]
const ITEM_IMPACT_STONE: Array[String] = [_IMPACT + "impactGeneric_light_002.ogg", _IMPACT + "impactGeneric_light_003.ogg", _IMPACT + "impactGeneric_light_004.ogg"]
const ITEM_IMPACT_WOOD: Array[String] = [_IMPACT + "impactPlank_medium_000.ogg", _IMPACT + "impactPlank_medium_001.ogg", _IMPACT + "impactPlank_medium_002.ogg"]
const PICKUP: Array[String] = [_RPG + "handleSmallLeather.ogg"]
const DROP: Array[String] = [_RPG + "dropLeather.ogg"]
const THROW: Array[String] = [_GEN + "whoosh_0.ogg", _GEN + "whoosh_1.ogg", _GEN + "whoosh_2.ogg"]
const DELIVER_COINS: Array[String] = [_RPG + "handleCoins.ogg", _RPG + "handleCoins2.ogg"]
const SLINGSHOT_STRETCH: Array[String] = [_RPG + "creak1.ogg"]
const SLINGSHOT_FIRE: Array[String] = [_RPG + "beltHandle1.ogg"]
const STONE_IMPACT: Array[String] = [_IMPACT + "impactGeneric_light_000.ogg", _IMPACT + "impactGeneric_light_001.ogg"]
const SPRAY: Array[String] = [_GEN + "spray_hiss.wav"]
const NET_CLOSE: Array[String] = [_RPG + "cloth3.ogg"]

# --- Jogador e respostas do jogo ---------------------------------------------------------
const BUY: Array[String] = [_UI + "confirmation_002.ogg"]
const ERROR: Array[String] = [_UI + "error_006.ogg"]
const MEDKIT: Array[String] = [_UI + "confirmation_004.ogg"]
const RESPAWN: Array[String] = [_UI + "maximize_006.ogg"]
const PLAYER_HURT: Array[String] = [_IMPACT + "impactPunch_medium_000.ogg", _IMPACT + "impactPunch_medium_001.ogg"]
const PLAYER_DEATH: Array[String] = [_IMPACT + "impactPunch_heavy_000.ogg"]

# --- Navegação nos menus (ui/ui_sounds.gd liga todos os botões) --------------------------
const UI_HOVER: Array[String] = [_UI + "tick_001.ogg", _UI + "tick_002.ogg"]
const UI_CLICK: Array[String] = [_UI + "select_001.ogg", _UI + "select_002.ogg"]

# --- Inimigos (para o Dev_Detector ligar) -----------------------------------
const CRAB_PINCH: Array[String] = [_RPG + "knifeSlice2.ogg", _RPG + "knifeSlice.ogg"]
const SEAGULL_CAW: Array[String] = [_GEN + "gull_caw.wav"]
const SEAGULL_DIVE: Array[String] = [_GEN + "gull_dive.wav"]
const SHELL_KNOCK: Array[String] = [_IMPACT + "impactPlate_medium_000.ogg", _IMPACT + "impactPlate_medium_001.ogg", _IMPACT + "impactPlate_medium_002.ogg"]
const EMERGE_SAND: Array[String] = [_GEN + "emerge_0.ogg", _GEN + "emerge_1.ogg", _GEN + "emerge_2.ogg"]
## Vozes próprias (N2, gravações CC0 cortadas por tools/gen_audio.py clip): o corvo e o morcego
## herdam da gaivota e trocam o grito (Seagull.caw_sfx/dive_sfx); o lobo rosna antes do bote.
const CROW_CAW: Array[String] = [_GEN + "crow_caw_0.ogg", _GEN + "crow_caw_1.ogg", _GEN + "crow_caw_2.ogg"]
const BAT_SCREECH: Array[String] = [_GEN + "bat_screech_0.ogg", _GEN + "bat_screech_1.ogg", _GEN + "bat_screech_2.ogg"]
const WOLF_GROWL: Array[String] = [_GEN + "wolf_growl_0.ogg", _GEN + "wolf_growl_1.ogg", _GEN + "wolf_growl_2.ogg"]
const WOLF_HOWL: Array[String] = [_GEN + "wolf_howl_0.ogg"]

# --- Volume e alcance por categoria (#123) ------------------------------------------------
## dB somados ao volume pedido em play_at/play_ui. Um arquivo listado em mais de uma
## categoria fica com a primeira de _BANK.
const CATEGORY_DB: Dictionary = {
	&"step": 0.0, &"dig": 0.0, &"item": -3.0, &"tool": -2.0, &"player": 0.0,
	&"game_ui": 0.0, &"ui_nav": -15.0, &"creature": 0.0,
}
## Atenuação 3D por categoria: Vector2(unit_size, max_distance) em metros. Passos de outro
## jogador ainda se ouvem a ~15 m; criaturas (e chefes, que tocam as mesmas listas mais alto)
## de mais longe.
const CATEGORY_RANGE: Dictionary = {
	&"step": Vector2(5.0, 20.0), &"dig": Vector2(5.0, 30.0), &"item": Vector2(4.0, 25.0),
	&"tool": Vector2(5.0, 35.0), &"player": Vector2(5.0, 30.0), &"creature": Vector2(7.0, 55.0),
}
const DEFAULT_RANGE: Vector2 = Vector2(6.0, 45.0)
## Tudo o que o jogo toca, por categoria (também é o que os testes conferem).
const _BANK: Dictionary = {
	&"step": [FOOTSTEP_SAND, FOOTSTEP_SNOW, FOOTSTEP_GRASS, FOOTSTEP_STONE, FOOTSTEP_CRYSTAL, FOOTSTEP_WATER, FOOTSTEP_WOOD, JUMP, LAND],
	&"dig": [DIG_FAST, DIG_CAREFUL, DIG_FAST_DIRT, DIG_CAREFUL_DIRT, DIG_FAST_SNOW, DIG_CAREFUL_SNOW, DIG_FAST_STONE, DIG_CAREFUL_STONE, DIRT_FALL],
	&"item": [ITEM_IMPACT_METAL, ITEM_IMPACT_STONE, ITEM_IMPACT_WOOD, PICKUP, DROP, THROW, DELIVER_COINS],
	&"tool": [SLINGSHOT_STRETCH, SLINGSHOT_FIRE, STONE_IMPACT, SPRAY, NET_CLOSE],
	&"game_ui": [BUY, ERROR, MEDKIT, RESPAWN],
	&"player": [PLAYER_HURT, PLAYER_DEATH],
	&"ui_nav": [UI_HOVER, UI_CLICK],
	&"creature": [CRAB_PINCH, SEAGULL_CAW, SEAGULL_DIVE, SHELL_KNOCK, EMERGE_SAND, CROW_CAW, BAT_SCREECH, WOLF_GROWL, WOLF_HOWL],
}

static var _cache: Dictionary = {}
static var _category_of: Dictionary = {}


## Toca um som posicional em `pos`. `sound` pode ser uma lista de caminhos (do banco
## acima), um caminho String ou um AudioStream. Devolve o player (ou null).
static func play_at(sound: Variant, pos: Vector3, volume_db: float = 0.0, pitch_var: float = DEFAULT_PITCH_VAR) -> AudioStreamPlayer3D:
	var path: String = _pick(sound)
	var stream: AudioStream = sound as AudioStream if sound is AudioStream else _load(path)
	var parent: Node = _parent()
	if stream == null or parent == null:
		return null
	var cat: StringName = category_of(path)
	var range_m: Vector2 = CATEGORY_RANGE.get(cat, DEFAULT_RANGE)
	var p: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = BUS
	p.volume_db = volume_db + float(CATEGORY_DB.get(cat, 0.0))
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.unit_size = range_m.x
	p.max_distance = range_m.y
	parent.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
	return p


## Toca um som sem posição (UI, respostas ao próprio jogador).
static func play_ui(sound: Variant, volume_db: float = 0.0, pitch_var: float = 0.03) -> AudioStreamPlayer:
	var path: String = _pick(sound)
	var stream: AudioStream = sound as AudioStream if sound is AudioStream else _load(path)
	var parent: Node = _parent()
	if stream == null or parent == null:
		return null
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = BUS
	p.volume_db = volume_db + float(CATEGORY_DB.get(category_of(path), 0.0))
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


## Offset de volume em dB para equalizar o nível aparente do passo de cada material
## (medido depois da normalização: grama e concreto ficam ~3 dB abaixo em RMS).
static func footstep_volume_offset(surface: StringName) -> float:
	match surface:
		&"stone", &"pedra", &"ruinas", &"laje":
			return -1.0
		&"crystal", &"cristal", &"rocha", &"cratera":
			return -2.0
		&"water", &"agua", &"mar":
			return -1.5
		&"grass", &"relva", &"terra", &"dirt":
			return -0.5
		&"wood", &"madeira":
			return -1.5
		&"snow", &"neve", &"gelo", &"ice":
			return -3.0
		_:
			return 0.0


## Som da pazada para a superfície (a mesma de footstep_sound_for_surface): areia/água,
## terra/grama/madeira, neve, pedra/cristal (cascalho e cinza).
static func dig_sound_for_surface(surface: StringName, careful: bool) -> Array[String]:
	match footstep_sound_for_surface(surface):
		FOOTSTEP_GRASS, FOOTSTEP_WOOD:
			return DIG_CAREFUL_DIRT if careful else DIG_FAST_DIRT
		FOOTSTEP_SNOW:
			return DIG_CAREFUL_SNOW if careful else DIG_FAST_SNOW
		FOOTSTEP_STONE, FOOTSTEP_CRYSTAL:
			return DIG_CAREFUL_STONE if careful else DIG_FAST_STONE
		_:
			return DIG_CAREFUL if careful else DIG_FAST


## Devolve o som de impacto para o tipo de material de um item.
static func item_impact_sound(material_type: int) -> Array[String]:
	match material_type:
		0, 1, 2, 3:  # FERRO, ALUMINIO, PRATA, OURO
			return ITEM_IMPACT_METAL
		_:
			return ITEM_IMPACT_STONE


## Categoria (chave de CATEGORY_DB) do arquivo `path`; &"" fora do banco.
static func category_of(path: String) -> StringName:
	if _category_of.is_empty():
		for cat: StringName in _BANK:
			for list: Array in _BANK[cat]:
				for p: String in list:
					if not _category_of.has(p):
						_category_of[p] = cat
	return _category_of.get(path, &"")


## Todos os caminhos do banco, sem repetir.
static func all_paths() -> Array[String]:
	category_of("")
	var out: Array[String] = []
	out.assign(_category_of.keys())
	return out


static func _pick(sound: Variant) -> String:
	if sound is AudioStream:
		return ""
	if sound is Array:
		var arr: Array = sound
		return "" if arr.is_empty() else str(arr.pick_random())
	return str(sound)


static func _load(path: String) -> AudioStream:
	if path == "":
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func _parent() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root
