extends GutTest

const LANDMARKS: Script = preload("res://gameplay/environment/night_landmarks.gd")
var _previous_session: SessionManager = null
var _session: SessionManager = null
var _world: Node3D = null


func before_each() -> void:
	_previous_session = SessionManager.instance
	_session = SessionManager.new()
	add_child(_session)
	_session.scene_change_enabled = false
	SessionManager.instance = _session
	_session.set("_current_map", load("res://items/maps/campo.tres"))
	_world = Node3D.new()
	add_child_autofree(_world)
	for anchor_name: String in ["BaseEntrega", "Banca"]:
		var anchor: Node3D = Node3D.new()
		anchor.name = anchor_name
		anchor.position = Vector3(3.5, 0.0, 3.5) if anchor_name == "BaseEntrega" else Vector3(8.5, 0.0, 6.0)
		_world.add_child(anchor)


func after_each() -> void:
	_world.free()
	_session.free()
	SessionManager.instance = _previous_session


func _install(theme_name: String = "campo") -> Node3D:
	var landmarks: Node3D = LANDMARKS.new()
	landmarks.set("theme", theme_name)
	_world.add_child(landmarks)
	return landmarks


func _lights() -> Array[Node]:
	return _world.find_children("*", "OmniLight3D", true, false)


func test_day_stays_unlit_and_scene_loaded_applies_night_once() -> void:
	var landmarks: Node3D = _install()
	assert_eq(_lights().size(), 0, "dia nao ganha luz local")
	_session.set("_night", true)
	_session.scene_loaded.emit("res://world/map_campo.tscn")
	assert_eq(_lights().size(), 2, "noite cria somente os dois marcos")
	_session.scene_loaded.emit("res://world/map_campo.tscn")
	assert_eq(_lights().size(), 2, "sinal repetido nao duplica luz")
	assert_false(landmarks.is_processing(), "sem polling por frame")
	var linked: int = _session.scene_loaded.get_connections().size()
	_world.remove_child(landmarks)
	assert_eq(_session.scene_loaded.get_connections().size(), linked - 1, "desconecta ao sair")
	landmarks.free()


func test_each_supported_map_respects_light_and_shadow_budget() -> void:
	_session.set("_night", true)
	for theme_name: String in ["campo", "ruinas", "geleira"]:
		var landmarks: Node3D = _install(theme_name)
		assert_eq(_lights().size(), 2, theme_name + ": duas luzes novas")
		for node: Node in _lights():
			var light: OmniLight3D = node as OmniLight3D
			assert_false(light.shadow_enabled, "nenhuma sombra nova")
			assert_between(light.light_energy, 0.4999, 0.8001)
			assert_between(light.omni_range, 4.0, 6.0)
			assert_true(light.distance_fade_enabled)
			assert_eq(light.distance_fade_begin, 30.0)
			assert_eq(light.distance_fade_length, 15.0)
		landmarks.free()


func test_praia_reuses_existing_lamps_and_restores_them_on_exit() -> void:
	var dressing: Node3D = Node3D.new()
	dressing.name = "BeachDressing"
	_world.add_child(dressing)
	var original: Array[OmniLight3D] = []
	for p: Vector3 in [Vector3(5.26, 2.25, 5.0), Vector3(25.66, 1.65, 13.8)]:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = p
		light.light_energy = 0.65
		light.omni_range = 5.0
		dressing.add_child(light)
		original.append(light)
	_session.set("_night", true)
	var landmarks: Node3D = _install("praia")
	assert_eq(_lights().size(), 2, "Praia nao duplica lanternas")
	assert_almost_eq(original[0].light_energy, 0.8, 0.001)
	landmarks.free()
	for light: OmniLight3D in original:
		assert_almost_eq(light.light_energy, 0.65, 0.001, "restaura luz emprestada")
		assert_eq(light.omni_range, 5.0)


func test_excluded_maps_do_not_create_lights() -> void:
	_session.set("_night", true)
	for theme_name: String in ["cratera", "lua", "ilha", ""]:
		var landmarks: Node3D = _install(theme_name)
		assert_eq(_lights().size(), 0, theme_name + ": fora do escopo")
		landmarks.free()


func test_maps_wire_landmarks_with_expected_extra_light_counts() -> void:
	_session.set("_night", true)
	for theme_name: String in ["praia", "campo", "ruinas", "geleira"]:
		var packed: PackedScene = load("res://world/map_%s.tscn" % theme_name) as PackedScene
		var map: Node3D = packed.instantiate() as Node3D
		_world.add_child(map)
		await wait_frames(3)
		var landmarks: Node3D = map.get_node_or_null("NightLandmarks") as Node3D
		assert_not_null(landmarks, theme_name + ": componente ligado no mapa")
		if landmarks != null:
			var added: Array[Node] = landmarks.find_children("*", "OmniLight3D", true, false)
			assert_eq(added.size(), 0 if theme_name == "praia" else 2)
			if theme_name == "praia":
				var borrowed: Dictionary = landmarks.get("_borrowed")
				assert_eq(borrowed.size(), 2, "duas lanternas reais reutilizadas")
			var lights: Array[Node] = map.find_children("*", "OmniLight3D", true, false)
			var shadows: int = 0
			for light: OmniLight3D in lights:
				if light.shadow_enabled:
					shadows += 1
			print("#155 %s: omni_total=%d novas=%d sombras_total=%d sombras_novas=0" % [theme_name, lights.size(), added.size(), shadows])
		map.free()
