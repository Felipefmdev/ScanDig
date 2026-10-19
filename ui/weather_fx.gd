class_name WeatherFx
extends Node

## Visual do clima (#99), só para o jogador local: partículas presas à câmera ativa (gotas, neve
## ou cinza) e névoa/cor do mapa. O Environment do mapa nunca é alterado: durante o evento o
## WorldEnvironment recebe uma cópia (tween de ~3 s na entrada e na saída) e, no fim, volta a
## ter o MESMO recurso original. Os valores são relativos ao que o mapa já tem (a Geleira já
## tem névoa). Com "Efeitos de clima fortes" desligado ([video] strong_weather_fx), metade das
## partículas e névoa/cor bem mais leves; os modificadores de jogo não mudam.
## Autoload CoreWeatherFx; escuta CoreWeather.weather_changed.

const FADE_SECONDS: float = 3.0
## Partículas no máximo (fortes ligado); com fortes desligado, metade.
const MAX_PARTICLES: Dictionary = {
	WeatherManager.KIND_RAIN: 400, WeatherManager.KIND_BLIZZARD: 400, WeatherManager.KIND_ASHSTORM: 300,
}
const WEAK_PARTICLE_RATIO: float = 0.5
## Fração do efeito de névoa/cor com fortes desligado.
const WEAK_ENV_RATIO: float = 0.35
## Ao auge (fortes ligado), por cima do Environment do mapa: névoa somada, cor da névoa,
## quanto a névoa cobre o céu, saturação e brilho da imagem.
const ENV_TARGETS: Dictionary = {
	WeatherManager.KIND_RAIN: {"fog_add": 0.008, "fog_color": Color(0.56, 0.6, 0.66), "sky_affect": 0.5,
		"saturation": 0.78, "brightness": 0.88},
	WeatherManager.KIND_BLIZZARD: {"fog_add": 0.04, "fog_color": Color(0.86, 0.9, 0.97), "sky_affect": 0.8,
		"saturation": 0.8, "brightness": 1.0},
	WeatherManager.KIND_ASHSTORM: {"fog_add": 0.015, "fog_color": Color(0.5, 0.3, 0.18), "sky_affect": 0.7,
		"saturation": 0.85, "brightness": 0.8},
}
## À noite (#109) as partículas sem sombreamento brilhariam no escuro: a cor é multiplicada por isto.
const NIGHT_PARTICLE_TINT: Color = Color(0.45, 0.5, 0.65, 1.0)
## Altura das partículas acima da câmera e meia-largura da caixa de emissão (m).
const EMIT_HEIGHT: float = 5.0
const EMIT_HALF_SIZE: float = 6.0

static var instance: WeatherFx = null

var particles: CPUParticles3D = null
## Onde as partículas são criadas (Node3D: a câmera é seguida a cada frame).
var particles_root: Node3D = null
var strong: bool = true
## Onde procurar o WorldEnvironment (vazio = a cena atual). Os testes apontam para a cena deles.
var environment_root: Node = null

var _kind: String = ""
var _env_amount: float = 0.0
var _env_tween: Tween = null
var _world_env: WorldEnvironment = null
var _env_original: Environment = null
var _env_copy: Environment = null
var _base: Dictionary = {}


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	particles_root = Node3D.new()
	particles_root.name = "WeatherParticles"
	add_child(particles_root)
	# Só segue a câmera enquanto há partículas (_build_particles liga, finish desliga).
	set_process(false)
	var weather: WeatherManager = WeatherManager.instance
	if weather != null:
		weather.weather_changed.connect(_on_weather_changed)
	var sm: SettingsManager = SettingsManager.instance
	if sm != null:
		strong = bool(sm.get_value(SettingsManager.VIDEO, "strong_weather_fx") != false)
		sm.settings_changed.connect(_on_settings_changed)


func _process(_delta: float) -> void:
	if particles == null:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	particles.visible = cam != null
	if cam != null:
		# Segue a câmera ativa (a orbital do jogador caído também), não o corpo.
		particles_root.global_position = cam.global_position + Vector3(0.0, EMIT_HEIGHT, 0.0)


func _on_weather_changed(kind: String, phase: String) -> void:
	if phase == WeatherManager.PHASE_ACTIVE:
		start(kind)
	elif phase == WeatherManager.PHASE_NONE:
		finish()


func _on_settings_changed(section: String, values: Dictionary) -> void:
	if section != SettingsManager.VIDEO:
		return
	var now: bool = values.get("strong_weather_fx", true) != false
	if now == strong:
		return
	set_strong(now)


## Fortes ligado/desligado ao vivo: refaz a quantidade de partículas e a névoa no ponto atual.
func set_strong(on: bool) -> void:
	strong = on
	if particles != null:
		particles.amount = particle_amount(_kind, strong)
	_apply_env_amount(_env_amount)


static func particle_amount(kind: String, strong_fx: bool) -> int:
	var full: int = int(MAX_PARTICLES.get(kind, 0))
	return full if strong_fx else maxi(int(round(full * WEAK_PARTICLE_RATIO)), 1)


# --- Início / fim ---------------------------------------------------------------------

func start(kind: String) -> void:
	if not ENV_TARGETS.has(kind):
		return
	_kind = kind
	_build_particles(kind)
	_grab_environment()
	_fade_env_to(1.0)


## `instant` (testes): sem o fade de saída, restaura na hora.
func finish(instant: bool = false) -> void:
	if particles != null:
		particles.emitting = false
		var old: CPUParticles3D = particles
		particles = null
		set_process(false)
		# Deixa as últimas gotas caírem e some.
		get_tree().create_timer(old.lifetime + 0.2, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(old):
				old.queue_free())
	if _env_copy == null:
		_kind = ""
		return
	if instant:
		set_env_amount_now(0.0)
		restore_environment()
		return
	_fade_env_to(0.0)


## Sem tween (testes e capturas): névoa/cor já no ponto `amount`.
func set_env_amount_now(amount: float) -> void:
	if _env_tween != null and _env_tween.is_valid():
		_env_tween.kill()
	_apply_env_amount(amount)


func is_running() -> bool:
	return particles != null and particles.emitting


# --- Partículas ----------------------------------------------------------------------

func _build_particles(kind: String) -> void:
	if particles != null:
		particles.queue_free()
	particles = CPUParticles3D.new()
	particles.name = "Weather_%s" % kind
	particles.local_coords = false
	particles.amount = particle_amount(kind, strong)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(EMIT_HALF_SIZE, 0.5, EMIT_HALF_SIZE)
	particles.direction = Vector3.DOWN
	particles.spread = 8.0
	var quad: QuadMesh = QuadMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	if kind != WeatherManager.KIND_RAIN:
		mat.albedo_texture = _soft_dot()
	match kind:
		WeatherManager.KIND_RAIN:
			quad.size = Vector2(0.045, 0.7)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			# Some ao chegar ao chão (câmera ~1.7 m acima dele): a chuva fica toda à vista.
			particles.lifetime = 0.55
			particles.gravity = Vector3(0.0, -30.0, 0.0)
			particles.initial_velocity_min = 7.0
			particles.initial_velocity_max = 9.0
			particles.color = Color(0.6, 0.68, 0.8, 0.7)
		WeatherManager.KIND_BLIZZARD:
			quad.size = Vector2(0.22, 0.22)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			particles.lifetime = 1.8
			particles.gravity = Vector3(5.0, -3.0, 1.5)
			particles.spread = 35.0
			particles.initial_velocity_min = 1.0
			particles.initial_velocity_max = 2.5
			# Branco levemente azulado: aparece também sobre a neve do chão.
			particles.color = Color(0.93, 0.96, 1.0, 0.95)
		WeatherManager.KIND_ASHSTORM:
			quad.size = Vector2(0.2, 0.2)
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			particles.lifetime = 3.2
			particles.gravity = Vector3(1.2, -0.8, 0.6)
			particles.spread = 60.0
			particles.initial_velocity_min = 0.3
			particles.initial_velocity_max = 1.2
			particles.color = Color(0.55, 0.5, 0.46, 0.9)
			particles.color_ramp = _ash_ramp()
	if SessionManager.is_night():
		particles.color *= NIGHT_PARTICLE_TINT
		if particles.color_ramp != null:
			particles.color_ramp = particles.color_ramp.duplicate() as Gradient
			for i: int in particles.color_ramp.get_point_count():
				particles.color_ramp.set_color(i, particles.color_ramp.get_color(i) * NIGHT_PARTICLE_TINT)
	quad.material = mat
	particles.mesh = quad
	particles.preprocess = particles.lifetime
	particles.emitting = true
	particles_root.add_child(particles)
	set_process(true)


## Brasa laranja que vira cinza clara e apaga (vale sobre o chão escuro da Cratera).
func _ash_ramp() -> Gradient:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1.0, 0.55, 0.2, 1.0))
	g.set_color(1, Color(0.6, 0.56, 0.52, 0.0))
	g.add_point(0.3, Color(0.72, 0.66, 0.6, 0.9))
	return g


## Ponto redondo e macio (neve e cinza não ficam quadradas).
static func _soft_dot() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 0.85))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex


# --- Névoa e cor (Environment duplicado) ---------------------------------------------------

## Acha o WorldEnvironment do mapa e troca o recurso por uma cópia (o original fica guardado).
func _grab_environment() -> void:
	if _env_copy != null and is_instance_valid(_world_env) and _world_env.environment == _env_copy:
		return
	_world_env = null
	_env_original = null
	_env_copy = null
	var scene: Node = environment_root
	if scene == null and is_inside_tree():
		scene = get_tree().current_scene
	if scene == null:
		return
	var found: Array[Node] = scene.find_children("*", "WorldEnvironment", true, false)
	if found.is_empty():
		return
	var we: WorldEnvironment = found[0] as WorldEnvironment
	if we == null or we.environment == null:
		return
	_world_env = we
	_env_original = we.environment
	_env_copy = _env_original.duplicate() as Environment
	_base = {
		"fog_density": _env_original.fog_density if _env_original.fog_enabled else 0.0,
		"fog_color": _env_original.fog_light_color,
		"sky_affect": _env_original.fog_sky_affect if _env_original.fog_enabled else 0.0,
		"saturation": _env_original.adjustment_saturation if _env_original.adjustment_enabled else 1.0,
		"brightness": _env_original.adjustment_brightness if _env_original.adjustment_enabled else 1.0,
	}
	_env_copy.fog_enabled = true
	_env_copy.adjustment_enabled = true
	we.environment = _env_copy
	_apply_env_amount(_env_amount)


func _fade_env_to(target: float) -> void:
	if _env_tween != null and _env_tween.is_valid():
		_env_tween.kill()
	if _env_copy == null:
		_env_amount = target
		return
	_env_tween = create_tween()
	_env_tween.tween_method(_apply_env_amount, _env_amount, target, FADE_SECONDS * absf(target - _env_amount))
	if target <= 0.0:
		_env_tween.tween_callback(restore_environment)


## 0 = Environment do mapa, 1 = auge do evento (reduzido com fortes desligado).
func _apply_env_amount(amount: float) -> void:
	_env_amount = amount
	if _env_copy == null or not ENV_TARGETS.has(_kind):
		return
	var t: Dictionary = ENV_TARGETS[_kind]
	var a: float = amount * (1.0 if strong else WEAK_ENV_RATIO)
	# Teto da névoa somada (a do mapa + a da noite #109 + a do clima).
	_env_copy.fog_density = minf(float(_base["fog_density"]) + float(t["fog_add"]) * a, NightMode.MAX_FOG_DENSITY)
	_env_copy.fog_light_color = (_base["fog_color"] as Color).lerp(t["fog_color"] as Color, a)
	_env_copy.fog_sky_affect = lerpf(float(_base["sky_affect"]), maxf(float(t["sky_affect"]), float(_base["sky_affect"])), a)
	_env_copy.adjustment_saturation = lerpf(float(_base["saturation"]), float(t["saturation"]), a)
	# À noite (#109) o brilho do clima é relativo ao da noite (a nevasca não clareia o escuro).
	var brightness: float = float(t["brightness"]) * (float(_base["brightness"]) if SessionManager.is_night() else 1.0)
	_env_copy.adjustment_brightness = lerpf(float(_base["brightness"]), brightness, a)


## Fim do evento (ou troca de cena): o WorldEnvironment volta a ter o recurso original.
func restore_environment() -> void:
	if is_instance_valid(_world_env) and _env_original != null and _world_env.environment == _env_copy:
		_world_env.environment = _env_original
	_world_env = null
	_env_original = null
	_env_copy = null
	_env_amount = 0.0
	_kind = ""


func current_environment_copy() -> Environment:
	return _env_copy
