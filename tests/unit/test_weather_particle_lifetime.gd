extends GutTest

## Regressão: partículas/cena podem sair antes do timer real de retirada.
## WeatherFx real, sem substituição de singleton, relógio ou timer.
var _scene: Node3D = null
var _fx: WeatherFx = null
var _fx_ref: WeakRef = null
var _singleton_before: WeatherFx = null
var _case: String = "setup"
var _wait_seconds: float = 0.0


func before_each() -> void:
	_singleton_before = WeatherFx.instance
	_scene = Node3D.new()
	_scene.name = "WeatherLifetime186Scene"
	add_child(_scene)
	_fx = WeatherFx.new()
	# Isolated environment search, no mutation of the current production scene.
	# No WorldEnvironment: particle retirement is independent of fog tweens.
	_fx.environment_root = _scene
	_scene.add_child(_fx)
	_fx_ref = weakref(_fx)
	_wait_seconds = 0.0
	assert_true(_fx.is_inside_tree())
	assert_not_null(_fx.particles_root, "real ready must build particle root")
	await get_tree().process_frame


func after_each() -> void:
	print("WEATHER186 ", _case, " cleanup_begin")
	# Also drain the production timeout on an early-return assertion failure.
	if _wait_seconds > 0.0:
		await get_tree().create_timer(_wait_seconds, true, false, true).timeout
	if is_instance_valid(_scene):
		_scene.free()
	_scene = null
	_fx = null
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(_fx_ref.get_ref(), "local FX gone after fixture cleanup")
	assert_true(WeatherFx.instance == _singleton_before, "production autoload instance preserved")
	print("WEATHER186 ", _case, " cleanup_end")


func _start_and_finish_rain() -> CPUParticles3D:
	print("WEATHER186 ", _case, " start_rain")
	_fx.start(WeatherManager.KIND_RAIN)
	var old: CPUParticles3D = _fx.particles
	assert_not_null(old, "real rain creates particles")
	if old == null:
		return null
	assert_true(old.is_inside_tree())
	assert_true(old.emitting)
	assert_eq(old.get_parent(), _fx.particles_root)
	assert_gt(old.lifetime, 0.0)
	assert_lt(old.lifetime, 10.0, "bounded rain baseline; fail rather than mutate lifetime")
	if old.lifetime <= 0.0 or old.lifetime >= 10.0:
		return null
	# Read production lifetime; never assign it or Engine.time_scale.
	_wait_seconds = old.lifetime + 0.2 + 0.3
	_fx.finish(true)
	assert_null(_fx.particles, "finish detaches active reference immediately")
	assert_false(old.emitting)
	assert_false(_fx.is_processing())
	assert_true(is_instance_valid(old), "finish keeps old alive until retirement timer")
	print("WEATHER186 ", _case, " finish_true timer_wait=", _wait_seconds)
	return old


func _observe_after_timeout() -> void:
	assert_gt(_wait_seconds, 0.0)
	print("WEATHER186 ", _case, " wait_begin")
	await get_tree().create_timer(_wait_seconds, true, false, true).timeout
	_wait_seconds = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	print("WEATHER186 ", _case, " wait_end")


func test_old_particles_freed_before_timeout_while_fx_survives() -> void:
	_case = "old_freed_fx_alive"
	var old: CPUParticles3D = _start_and_finish_rain()
	if old == null:
		return
	var old_ref: WeakRef = weakref(old)
	old.free()
	old = null
	assert_null(old_ref.get_ref(), "old particles freed before queued timeout")
	assert_not_null(_fx_ref.get_ref(), "watcher: FX is alive before timeout")
	print("WEATHER186 ", _case, " old_freed_before_timer")
	await _observe_after_timeout()
	assert_null(old_ref.get_ref(), "no resurrection of old particles")
	assert_not_null(_fx_ref.get_ref(), "watcher: FX survived timer")
	assert_true(_fx.is_inside_tree())
	assert_null(_fx.particles)
	assert_eq(_fx.particles_root.get_child_count(), 0)


func test_fx_and_scene_freed_before_timeout_watcher_survives() -> void:
	_case = "scene_and_fx_freed"
	var old: CPUParticles3D = _start_and_finish_rain()
	if old == null:
		return
	var old_ref: WeakRef = weakref(old)
	var scene_ref: WeakRef = weakref(_scene)
	old = null
	_scene.free()
	_scene = null
	_fx = null
	assert_null(scene_ref.get_ref())
	assert_null(_fx_ref.get_ref(), "FX gone before timer")
	assert_null(old_ref.get_ref(), "scene teardown removes its particles")
	print("WEATHER186 ", _case, " scene_freed_before_timer")
	# GutTest watcher remains in the real tree while the production timer expires.
	assert_true(is_inside_tree())
	await _observe_after_timeout()
	assert_true(is_inside_tree(), "watcher survived original scene and timeout")
	assert_null(scene_ref.get_ref())
	assert_null(_fx_ref.get_ref())
	assert_null(old_ref.get_ref())


func test_control_live_fx_timer_retires_old_particles() -> void:
	_case = "control_fx_alive"
	var old: CPUParticles3D = _start_and_finish_rain()
	if old == null:
		return
	var old_ref: WeakRef = weakref(old)
	old = null
	assert_not_null(old_ref.get_ref(), "old survives until real timer")
	assert_not_null(_fx_ref.get_ref())
	await _observe_after_timeout()
	assert_null(old_ref.get_ref(), "production timeout retires old particles")
	assert_not_null(_fx_ref.get_ref(), "watcher: FX remains alive after retirement")
	assert_true(_fx.is_inside_tree())
	assert_null(_fx.particles)
	assert_eq(_fx.particles_root.get_child_count(), 0)
