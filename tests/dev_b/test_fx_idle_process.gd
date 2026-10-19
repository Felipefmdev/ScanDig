extends GutTest

## Otimização (#132): NightFx e WeatherFx só processam quando têm o que fazer (noite / partículas
## de clima) e a NightFx não varre o grupo do jogador local a cada frame.

const PRAIA: MapData = preload("res://items/maps/praia.tres")

var night: NightFx = null
var weather_fx: WeatherFx = null


func before_each() -> void:
	night = NightFx.instance
	weather_fx = WeatherFx.instance
	night.environment_root = Node3D.new()
	add_child_autofree(night.environment_root)


func after_each() -> void:
	weather_fx.finish(true)
	night.restore()
	night.environment_root = null
	SessionManager.instance._current_map = null
	SessionManager.instance._night = false


func test_idle_by_day_and_without_weather() -> void:
	assert_false(night.is_processing(), "de dia a NightFx não processa")
	assert_false(weather_fx.is_processing(), "sem clima a WeatherFx não processa")


func test_weather_processes_only_with_particles() -> void:
	weather_fx.start(WeatherManager.KIND_RAIN)
	assert_true(weather_fx.is_processing(), "com chuva segue a câmera")
	weather_fx.finish(true)
	assert_false(weather_fx.is_processing(), "acabou: para")


func test_night_processes_and_caches_local_player() -> void:
	var player: Player = (load("res://gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	await wait_frames(2)
	SessionManager.instance._current_map = PRAIA
	SessionManager.instance._night = true
	night.start("praia", true)
	assert_true(night.is_processing(), "à noite processa")
	assert_eq(night._local_player(), player)
	assert_eq(night._player, player, "jogador local guardado")
	player.remove_from_group(Player.LOCAL_GROUP)
	assert_null(night._local_player(), "saiu do grupo: procura de novo")
	player.add_to_group(Player.LOCAL_GROUP)
	assert_eq(night._local_player(), player)
	player.free()
	assert_null(night._local_player(), "jogador liberado não é usado")
	night.restore()
	assert_false(night.is_processing(), "de dia de novo: para")
	assert_null(night._player)
