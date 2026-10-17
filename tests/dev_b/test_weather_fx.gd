extends GutTest

## Visual do clima (#99): partículas seguem a câmera, névoa/cor numa cópia do Environment e o
## MESMO recurso original de volta no fim; com "fortes" desligado, metade das partículas e névoa
## mais leve. Sem tween real (set_env_amount_now / finish(true)).

var _scene: Node3D = null
var _world_env: WorldEnvironment = null
var _env: Environment = null
var _fx: WeatherFx = null


func before_each() -> void:
	_scene = Node3D.new()
	add_child_autofree(_scene)
	_env = Environment.new()
	_env.fog_enabled = true
	_env.fog_density = 0.007
	_env.fog_light_color = Color(0.7, 0.85, 0.95)
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.05
	_world_env = WorldEnvironment.new()
	_world_env.environment = _env
	_scene.add_child(_world_env)
	_fx = WeatherFx.new()
	_fx.environment_root = _scene
	add_child_autofree(_fx)
	_fx.set_strong(true)


func after_each() -> void:
	if WeatherManager.instance != null:
		WeatherManager.instance.stop()


func test_blizzard_fog_on_copy_and_original_restored() -> void:
	_fx.start(WeatherManager.KIND_BLIZZARD)
	assert_ne(_world_env.environment, _env, "durante o evento o WorldEnvironment usa uma cópia")
	assert_eq(_world_env.environment, _fx.current_environment_copy())
	_fx.set_env_amount_now(1.0)
	var copy: Environment = _world_env.environment
	assert_almost_eq(copy.fog_density, 0.007 + 0.04, 0.0001, "nevasca: névoa somada à do mapa")
	assert_almost_eq(_env.fog_density, 0.007, 0.000001, "o original não muda")
	assert_true(_fx.is_running(), "partículas ligadas")
	assert_eq(_fx.particles.amount, WeatherFx.MAX_PARTICLES[WeatherManager.KIND_BLIZZARD])
	assert_lte(_fx.particles.amount, 400, "orçamento de partículas")
	_fx.finish(true)
	assert_eq(_world_env.environment, _env, "fim: o MESMO recurso original volta")
	assert_almost_eq(_env.fog_density, 0.007, 0.000001)
	assert_eq(_env.fog_light_color, Color(0.7, 0.85, 0.95))
	assert_false(_fx.is_running())


func test_fade_starts_from_map_values() -> void:
	_fx.start(WeatherManager.KIND_RAIN)
	_fx.set_env_amount_now(0.0)
	var copy: Environment = _world_env.environment
	assert_almost_eq(copy.fog_density, 0.007, 0.0001, "começo do fade = mapa")
	assert_almost_eq(copy.adjustment_saturation, 1.05, 0.0001)
	_fx.set_env_amount_now(0.5)
	assert_almost_eq(copy.fog_density, 0.007 + 0.008 * 0.5, 0.0001, "meio do fade")
	_fx.finish(true)


func test_strong_off_halves_particles_and_lightens_fog() -> void:
	_fx.start(WeatherManager.KIND_ASHSTORM)
	_fx.set_env_amount_now(1.0)
	var full: int = _fx.particles.amount
	_fx.set_strong(false)
	assert_eq(_fx.particles.amount, int(round(full * WeatherFx.WEAK_PARTICLE_RATIO)), "fortes desligado: metade")
	assert_almost_eq(_world_env.environment.fog_density, 0.007 + 0.015 * WeatherFx.WEAK_ENV_RATIO, 0.0001, "névoa mais leve")
	_fx.set_strong(true)
	assert_eq(_fx.particles.amount, full)
	_fx.finish(true)
	assert_eq(_world_env.environment, _env)


func test_particles_follow_active_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	_scene.add_child(cam)
	cam.global_position = Vector3(5, 2, -4)
	cam.make_current()
	_fx.start(WeatherManager.KIND_RAIN)
	await get_tree().process_frame
	assert_almost_eq(_fx.particles_root.global_position, Vector3(5, 2 + WeatherFx.EMIT_HEIGHT, -4), Vector3.ONE * 0.01)
	cam.global_position = Vector3(-3, 1, 8)
	await get_tree().process_frame
	assert_almost_eq(_fx.particles_root.global_position, Vector3(-3, 1 + WeatherFx.EMIT_HEIGHT, 8), Vector3.ONE * 0.01, "segue a câmera")
	_fx.finish(true)


func test_weather_signal_drives_fx() -> void:
	var core: WeatherManager = WeatherManager.instance
	assert_not_null(core)
	core.force_event(WeatherManager.KIND_RAIN, 30.0)
	assert_true(_fx.is_running(), "active liga o visual")
	assert_ne(_world_env.environment, _env)
	core.stop()
	assert_false(_fx.is_running(), "none desliga")
	_fx.finish(true)
	assert_eq(_world_env.environment, _env)
