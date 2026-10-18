extends GutTest

## Testes unitários para os marcadores no coop (#107).
## Cobre: inicialização de bandeiras (sinal, perigo, ajuda), tempo de vida de 20s,
## limite de 1 marcador por jogador, menu radial com ângulos e atalho no SettingsManager.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const COOP_MARKER_FLAG_SCRIPT: Script = preload("res://gameplay/player/coop_marker_flag.gd")
const COOP_MARKER_WHEEL_SCRIPT: Script = preload("res://gameplay/player/coop_marker_wheel.gd")
const COOP_MARKER_HUD_SCRIPT: Script = preload("res://gameplay/player/coop_marker_hud.gd")

var _player: Player = null


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(_player)


func after_each() -> void:
	var markers: Array[Node] = get_tree().get_nodes_in_group(&"coop_markers")
	for m: Node in markers:
		if is_instance_valid(m):
			m.queue_free()


func test_settings_has_marker_action() -> void:
	assert_true("marker" in SettingsManager.CONTROL_ACTIONS, "Ação marker deve estar em CONTROL_ACTIONS")
	assert_true(SettingsManager.ACTION_LABELS.has("marker"), "Deve ter rótulo amigável no menu")
	assert_eq(SettingsManager.DEFAULT_BINDINGS["marker"]["code"], KEY_T, "Atalho padrão no teclado deve ser T")
	assert_eq(SettingsManager.DEFAULT_PAD_BINDINGS["marker"]["code"], JOY_BUTTON_DPAD_UP, "Atalho no comando deve ser D-Pad Cima")


func test_flag_types_and_display() -> void:
	var flag_signal: Node3D = COOP_MARKER_FLAG_SCRIPT.new(0, 1, "Mineiro1")
	add_child_autofree(flag_signal)
	assert_eq(flag_signal.get("marker_type"), 0)
	assert_eq(flag_signal.call("get_type_config")["icon"], "🚩")
	assert_true("Sinal aqui" in flag_signal.call("get_display_label"))
	assert_true("Mineiro1" in flag_signal.call("get_display_label"))

	var flag_danger: Node3D = COOP_MARKER_FLAG_SCRIPT.new(1, 2, "Explorador")
	add_child_autofree(flag_danger)
	assert_eq(flag_danger.get("marker_type"), 1)
	assert_eq(flag_danger.call("get_type_config")["icon"], "⚠️")
	assert_true("Perigo" in flag_danger.call("get_display_label"))

	var flag_help: Node3D = COOP_MARKER_FLAG_SCRIPT.new(2, 3, "Socorro")
	add_child_autofree(flag_help)
	assert_eq(flag_help.get("marker_type"), 2)
	assert_eq(flag_help.call("get_type_config")["icon"], "🆘")
	assert_true("Ajuda" in flag_help.call("get_display_label"))


func test_flag_group_and_lifetime() -> void:
	var flag: Node3D = COOP_MARKER_FLAG_SCRIPT.new(0, 1, "Player1")
	add_child_autofree(flag)
	assert_true(flag.is_in_group(&"coop_markers"), "Bandeira deve estar no grupo coop_markers")
	assert_almost_eq(float(flag.get("time_left")), 20.0, 0.1, "Tempo de vida padrão é de 20s")

	# Avança tempo
	flag._process(5.0)
	assert_almost_eq(float(flag.get("time_left")), 15.0, 0.1, "Contagem regressiva do tempo")


func test_radial_wheel_angle_selection() -> void:
	var wheel: Control = COOP_MARKER_WHEEL_SCRIPT.new()
	add_child_autofree(wheel)
	wheel.call("open")
	assert_true(wheel.call("is_wheel_open"))

	# Cima (y negativo) -> Sinal aqui (0)
	wheel.call("update_selection_from_input", Vector2(0.0, -1.0))
	assert_eq(wheel.call("get_selected_type"), 0)

	# Direita (x positivo) -> Perigo (1)
	wheel.call("update_selection_from_input", Vector2(1.0, 0.0))
	assert_eq(wheel.call("get_selected_type"), 1)

	# Esquerda (x negativo) -> Ajuda (2)
	wheel.call("update_selection_from_input", Vector2(-1.0, 0.0))
	assert_eq(wheel.call("get_selected_type"), 2)

	wheel.call("close")
	assert_false(wheel.call("is_wheel_open"))


func test_limit_one_marker_per_player() -> void:
	# Spawna primeiro marcador para peer 1
	var flag1: Node3D = _player._spawn_marker_in_world(Vector3(10, 0, 10), 0, 1, "Player1")
	assert_not_null(flag1)

	# Spawna marcador para peer 2
	var flag2: Node3D = _player._spawn_marker_in_world(Vector3(20, 0, 20), 1, 2, "Player2")
	assert_not_null(flag2)

	# Novo marcador para peer 1 deve remover o flag1
	_player._rpc_spawn_marker(Vector3(15, 0, 15), 2, 1, "Player1")

	# flag1 foi acionado para fade/queue_free
	assert_true(bool(flag1.get("_is_fading")) or not flag1.is_inside_tree(), "Marcador anterior do jogador deve ser removido")
	assert_false(bool(flag2.get("_is_fading")), "Marcador do outro jogador não deve ser afetado")


func test_player_plant_marker() -> void:
	_player.global_position = Vector3(0, 1, 0)
	_player.plant_marker_at_aim(1)

	var markers: Array[Node] = get_tree().get_nodes_in_group(&"coop_markers")
	assert_eq(markers.size(), 1, "Deve ter gerado 1 marcador no mundo")
	var m: Node = markers[0]
	assert_eq(m.get("marker_type"), 1)
