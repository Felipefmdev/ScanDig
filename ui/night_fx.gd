class_name NightFx
extends Node

## Visual da expedição noturna (#109), só para o jogador local. Ao carregar um mapa à noite
## (SessionManager.scene_loaded + is_night()), o WorldEnvironment recebe uma cópia do Environment
## (com céu e material do céu próprios) e, em NightMode fade_s, vai do dia à noite: céu escuro,
## luz ambiente azulada, névoa somada (com teto) e a DirectionalLight do mapa fraca e azulada.
## Na troca de cena o WorldEnvironment volta a ter o MESMO recurso original e a luz, os valores
## de antes; nada é gravado em .tres. O clima (WeatherFx) duplica a cópia noturna, então os dois
## somam.
## À noite a Lanterna de Magnésio na mão acende uma luz em cone e o visor do detector ilumina a
## mão e o chão em volta (luzes presas ao jogador local; somem de dia). No HUD, um chip "Noite"
## discreto entra na fila de chips do topo (HUD/TopChips).
## Autoload CoreNightFx; config em NightMode.NIGHT_BY_MAP / NIGHT_LOOK.

const LANTERN_TOOL: StringName = &"lanterna_magnesio"
const LANTERN_COLOR: Color = Color(1.0, 0.97, 0.9)
const LANTERN_ENERGY: float = 3.0
const LANTERN_RANGE: float = 18.0
const LANTERN_ANGLE: float = 34.0
const DETECTOR_GLOW_COLOR: Color = Color(0.55, 1.0, 0.75)
const DETECTOR_GLOW_ENERGY: float = 0.9
const DETECTOR_GLOW_RANGE: float = 3.0
## Uniforms do sky_stylized que a noite troca (o resto do céu fica como no mapa).
const SKY_KEYS: Array[String] = ["top_color", "horizon_color", "ground_color", "cloud_color",
	"cloud_shade_color", "sun_color", "sun_size_deg", "sun_glow"]

static var instance: NightFx = null

## Onde procurar o WorldEnvironment e a DirectionalLight3D (vazio = a cena atual). Testes.
var environment_root: Node = null
var lantern_light: SpotLight3D = null
var detector_glow: OmniLight3D = null
var night_chip: UiChip = null

var _map_id: String = ""
var _cfg: Dictionary = {}
var _amount: float = 0.0
var _tween: Tween = null
var _world_env: WorldEnvironment = null
var _env_original: Environment = null
var _env_copy: Environment = null
var _sky_material: ShaderMaterial = null
var _sun: DirectionalLight3D = null
var _base: Dictionary = {}


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	var sm: SessionManager = SessionManager.instance
	if sm != null:
		sm.scene_loaded.connect(_on_scene_loaded)
		sm.scene_changing.connect(func(_target: String) -> void: restore())


func _on_scene_loaded(_scene_path: String) -> void:
	var sm: SessionManager = SessionManager.instance
	if sm != null and SessionManager.is_night() and sm.get_current_map() != null:
		start(sm.get_current_map().id)


func is_active() -> bool:
	return not _cfg.is_empty()


func get_amount() -> float:
	return _amount


func current_environment_copy() -> Environment:
	return _env_copy


## Noite no mapa `map_id` (sem config: nada). `instant` (testes e capturas): sem transição.
func start(map_id: String, instant: bool = false) -> void:
	var cfg: Dictionary = NightMode.config(map_id)
	if cfg.is_empty():
		return
	_map_id = map_id
	_cfg = cfg
	_grab_scene()
	_update_local_player()
	if instant:
		set_amount_now(1.0)
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_apply, _amount, 1.0, float(cfg.get("fade_s", 2.5)))


func set_amount_now(amount: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_apply(amount)


## Volta ao dia: o WorldEnvironment recebe o recurso original e a luz, os valores de antes.
func restore() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(_world_env) and _env_original != null:
		_world_env.environment = _env_original
	if is_instance_valid(_sun) and _base.has("sun_energy"):
		_sun.light_energy = float(_base["sun_energy"])
		_sun.light_color = _base["sun_color"] as Color
	_free_lights()
	_world_env = null
	_env_original = null
	_env_copy = null
	_sky_material = null
	_sun = null
	_base = {}
	_cfg = {}
	_map_id = ""
	_amount = 0.0


func _grab_scene() -> void:
	if _env_copy != null and is_instance_valid(_world_env):
		return
	var scene: Node = environment_root
	if scene == null and is_inside_tree():
		scene = get_tree().current_scene
	if scene == null:
		return
	_base = {}
	var envs: Array[Node] = scene.find_children("*", "WorldEnvironment", true, false)
	var we: WorldEnvironment = envs[0] as WorldEnvironment if not envs.is_empty() else null
	if we != null and we.environment != null:
		_world_env = we
		_env_original = we.environment
		_env_copy = _env_original.duplicate() as Environment
		if _env_original.sky != null:
			_env_copy.sky = _env_original.sky.duplicate() as Sky
			_sky_material = (_env_original.sky.sky_material as ShaderMaterial)
			if _sky_material != null:
				_sky_material = _sky_material.duplicate() as ShaderMaterial
				_env_copy.sky.sky_material = _sky_material
		_base["fog_density"] = _env_original.fog_density if _env_original.fog_enabled else 0.0
		_base["fog_color"] = _env_original.fog_light_color
		_base["ambient_color"] = _env_original.ambient_light_color
		_base["ambient_energy"] = _env_original.ambient_light_energy
		_base["brightness"] = _env_original.adjustment_brightness if _env_original.adjustment_enabled else 1.0
		if _sky_material != null:
			for key: String in SKY_KEYS:
				_base["sky_" + key] = _sky_material.get_shader_parameter(key)
		_env_copy.fog_enabled = true
		_env_copy.adjustment_enabled = true
		we.environment = _env_copy
	var suns: Array[Node] = scene.find_children("*", "DirectionalLight3D", true, false)
	if not suns.is_empty():
		_sun = suns[0] as DirectionalLight3D
		_base["sun_energy"] = _sun.light_energy
		_base["sun_color"] = _sun.light_color


## 0 = o mapa de dia, 1 = noite cheia.
func _apply(amount: float) -> void:
	_amount = amount
	if _cfg.is_empty():
		return
	var look: Dictionary = NightMode.NIGHT_LOOK
	if _env_copy != null:
		_env_copy.ambient_light_color = (_base["ambient_color"] as Color).lerp(look["ambient_color"] as Color, amount)
		_env_copy.ambient_light_energy = lerpf(float(_base["ambient_energy"]), float(look["ambient_energy"]), amount)
		_env_copy.fog_light_color = (_base["fog_color"] as Color).lerp(look["fog_color"] as Color, amount)
		_env_copy.fog_density = minf(float(_base["fog_density"]) + float(_cfg.get("fog_add", 0.0)) * amount, NightMode.MAX_FOG_DENSITY)
		_env_copy.adjustment_brightness = lerpf(float(_base["brightness"]), float(_cfg.get("brightness", 1.0)), amount)
	if _sky_material != null:
		for key: String in SKY_KEYS:
			var day: Variant = _base.get("sky_" + key)
			var night: Variant = look.get(key)
			if day is Color and night is Color:
				_sky_material.set_shader_parameter(key, (day as Color).lerp(night as Color, amount))
			elif (day is float or day is int) and (night is float or night is int):
				_sky_material.set_shader_parameter(key, lerpf(float(day), float(night), amount))
	if is_instance_valid(_sun) and _base.has("sun_energy"):
		_sun.light_energy = lerpf(float(_base["sun_energy"]), float(_base["sun_energy"]) * float(_cfg.get("sun_energy", 1.0)), amount)
		_sun.light_color = (_base["sun_color"] as Color).lerp(look["sun_light_color"] as Color, amount)


# --- Luzes do jogador local ---------------------------------------------------------------

func _process(_delta: float) -> void:
	_update_local_player()


func _update_local_player() -> void:
	if _cfg.is_empty():
		return
	var player: Player = _local_player()
	if player == null:
		return
	_update_lantern(player)
	_update_detector_glow(player)
	_update_chip(player)


func _local_player() -> Player:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Player.LOCAL_GROUP):
		if node is Player and node.is_inside_tree():
			return node as Player
	return null


func _update_lantern(player: Player) -> void:
	if player.camera == null:
		return
	if lantern_light == null or not is_instance_valid(lantern_light):
		lantern_light = SpotLight3D.new()
		lantern_light.name = "NightLantern"
		lantern_light.light_color = LANTERN_COLOR
		lantern_light.light_energy = LANTERN_ENERGY
		lantern_light.spot_range = LANTERN_RANGE
		lantern_light.spot_angle = LANTERN_ANGLE
		lantern_light.spot_attenuation = 0.8
		lantern_light.shadow_enabled = false
		# Da mão (onde está a lanterna) para a frente da mira.
		lantern_light.position = Vector3(0.3, -0.25, -0.4)
		player.camera.add_child(lantern_light)
	lantern_light.visible = player.held_tool_id == LANTERN_TOOL and player.is_alive()


func _update_detector_glow(player: Player) -> void:
	var detector: Node3D = player.detector
	if detector == null:
		return
	if detector_glow == null or not is_instance_valid(detector_glow):
		detector_glow = OmniLight3D.new()
		detector_glow.name = "NightDetectorGlow"
		detector_glow.light_color = DETECTOR_GLOW_COLOR
		detector_glow.light_energy = DETECTOR_GLOW_ENERGY
		detector_glow.omni_range = DETECTOR_GLOW_RANGE
		detector_glow.shadow_enabled = false
		detector_glow.position = Vector3(0.0, 0.12, 0.0)
		detector.add_child(detector_glow)
	detector_glow.visible = detector.is_visible_in_tree()


func _update_chip(player: Player) -> void:
	if night_chip != null and is_instance_valid(night_chip):
		return
	var chips: Node = player.get_node_or_null(^"HUD/TopChips")
	if chips == null:
		return
	night_chip = UiChip.new()
	night_chip.name = "NightChip"
	night_chip.icon_name = "moon"
	night_chip.label.text = "Noite"
	night_chip.tooltip_text = "Expedição noturna"
	chips.add_child(night_chip)


func _free_lights() -> void:
	for node: Node in [lantern_light, detector_glow, night_chip]:
		if node != null and is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.queue_free()
	lantern_light = null
	detector_glow = null
	night_chip = null
