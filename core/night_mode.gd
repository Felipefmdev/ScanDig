class_name NightMode
extends RefCounted

## Expedição noturna (#109). A config de cada mapa fica toda aqui (NIGHT_BY_MAP): tempo da
## transição, visual, multiplicador de raro e criaturas. O host escolhe "Noite" na mesa (aba
## Expedições); o SessionManager guarda o modo (SessionManager.is_night()) e o leva no RPC de
## entrada e no _rpc_sync_scene, como o mapa. Visual (céu, luz, névoa, lanterna, brilho do
## detector, chip "Noite" do HUD): ui/night_fx.gd (autoload CoreNightFx).
## A Ilha do Tesouro não tem noite: chega-se a ela de barco a partir da Praia (IslandBoat), é a
## luta final (o Colosso de Ouro precisa ser lido com clareza) e já tem a maior chance de raro.

## Por mapa:
## fade_s: transição dia -> noite ao chegar · rare_mult: × MapData.rare_variant_chance ·
## sun_energy: × energia da DirectionalLight do mapa · fog_add: névoa somada à do mapa ·
## brightness: brilho da imagem · extra_kinds: somados aos ambient_kinds do EnemySpawner ·
## ambient_interval_mult: × intervalo dos spawns ambiente (< 1 = criaturas mais ativas).
const NIGHT_BY_MAP: Dictionary = {
	"praia": {"fade_s": 2.5, "rare_mult": 1.6, "sun_energy": 0.22, "fog_add": 0.010, "brightness": 0.82,
		"extra_kinds": [&"bat", &"bat"], "ambient_interval_mult": 0.7},
	"campo": {"fade_s": 2.5, "rare_mult": 1.6, "sun_energy": 0.22, "fog_add": 0.010, "brightness": 0.82,
		"extra_kinds": [&"bat", &"mole"], "ambient_interval_mult": 0.7},
	"ruinas": {"fade_s": 2.5, "rare_mult": 1.5, "sun_energy": 0.2, "fog_add": 0.012, "brightness": 0.8,
		"extra_kinds": [&"bat", &"bat"], "ambient_interval_mult": 0.6},
	"geleira": {"fade_s": 2.5, "rare_mult": 1.5, "sun_energy": 0.24, "fog_add": 0.008, "brightness": 0.84,
		"extra_kinds": [&"ice_wolf"], "ambient_interval_mult": 0.75},
	"cratera": {"fade_s": 2.5, "rare_mult": 1.4, "sun_energy": 0.25, "fog_add": 0.008, "brightness": 0.84,
		"extra_kinds": [&"floater"], "ambient_interval_mult": 0.75},
}
## Céu e luz noturnos, iguais em todos os mapas (uniforms do sky_stylized e Environment).
const NIGHT_LOOK: Dictionary = {
	"top_color": Color(0.03, 0.05, 0.13), "horizon_color": Color(0.12, 0.16, 0.3),
	"ground_color": Color(0.05, 0.06, 0.1), "cloud_color": Color(0.2, 0.23, 0.33),
	"cloud_shade_color": Color(0.1, 0.12, 0.2), "sun_color": Color(0.82, 0.88, 1.0),
	"sun_size_deg": 1.6, "sun_glow": 0.15,
	"ambient_color": Color(0.22, 0.28, 0.48), "ambient_energy": 0.55,
	"fog_color": Color(0.08, 0.1, 0.2), "sun_light_color": Color(0.62, 0.72, 1.0),
}
## Teto da névoa somada (noite + clima + a do mapa): a Geleira com nevasca à noite não vira
## parede branca. WeatherFx usa o mesmo teto.
const MAX_FOG_DENSITY: float = 0.05


static func is_available(map_id: String) -> bool:
	return NIGHT_BY_MAP.has(map_id)


static func config(map_id: String) -> Dictionary:
	return NIGHT_BY_MAP.get(map_id, {}) as Dictionary


## Config do mapa atual se a expedição é noturna; {} de dia ou no lobby.
static func active_config() -> Dictionary:
	var sm: SessionManager = SessionManager.instance
	if sm == null or not SessionManager.is_night() or sm.get_current_map() == null:
		return {}
	return config(sm.get_current_map().id)


## Chance de raro com a noite: base × rare_mult do mapa (de dia, a base). Chance 0 fica 0.
static func rare_chance(base: float) -> float:
	return clampf(base * float(active_config().get("rare_mult", 1.0)), 0.0, 1.0)


## Host: criaturas noturnas no EnemySpawner do mapa (mesmos inimigos, mais ativos).
static func apply_to_spawner(spawner: EnemySpawner, map_id: String) -> void:
	var cfg: Dictionary = config(map_id)
	if spawner == null or cfg.is_empty():
		return
	var kinds: Array[StringName] = spawner.ambient_kinds.duplicate()
	if kinds.is_empty():
		kinds.append(spawner.primary_kind)
	for kind: StringName in cfg.get("extra_kinds", []):
		if spawner.has_scene_for_kind(kind):
			kinds.append(kind)
	spawner.ambient_kinds = kinds
	var mult: float = float(cfg.get("ambient_interval_mult", 1.0))
	spawner.ambient_interval_min *= mult
	spawner.ambient_interval_max *= mult
