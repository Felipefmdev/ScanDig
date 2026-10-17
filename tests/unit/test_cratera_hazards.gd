extends GutTest

## #96: chuva de meteoritos (aviso, impacto com empurrão, cratera quente, spot fresco) e
## gêiseres de vapor (ciclo previsível, lançam jogadores e itens).

const METEOR: Script = preload("res://gameplay/quests/cratera/meteor_shower.gd")
const GEYSER: Script = preload("res://gameplay/quests/cratera/steam_geyser.gd")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func test_meteor_points_avoid_base_and_stay_in_area() -> void:
	var m: Node3D = METEOR.new()
	add_child_autofree(m)
	m.set("enabled", false)
	assert_false(m.call("is_point_allowed", Vector3(3.5, 0, 3.5)), "base de entrega protegida")
	assert_false(m.call("is_point_allowed", Vector3(40, 0, 0)), "fora da zona")
	for i: int in 30:
		var p: Vector3 = m.call("pick_point")
		assert_true(m.call("is_point_allowed", p), "ponto valido %s" % p)


func test_meteor_warns_then_impacts_and_leaves_hot_crater() -> void:
	var m: Node3D = METEOR.new()
	add_child_autofree(m)
	m.set("enabled", false)
	var p: Vector3 = m.call("trigger", Vector3(-12, 0, -4))
	assert_ne(p, Vector3.INF, "host lanca")
	await get_tree().process_frame
	assert_not_null(m.find_child("MeteorShadow*", false, false), "sombra de aviso no chao")
	assert_not_null(m.find_child("Meteor1", false, false), "meteorito a cair")
	assert_eq(m.call("hot_count"), 0, "ainda nao caiu")
	await _wait(METEOR.WARN_TIME + 0.3)
	assert_eq(m.call("hot_count"), 1, "cratera quente apos o impacto")
	assert_not_null(m.find_child("MeteorCrater*", false, false), "cratera fumegante")
	assert_null(m.find_child("Meteor1", false, false), "meteorito some no impacto")


func test_geyser_cycle_is_predictable() -> void:
	var g: Node3D = GEYSER.new()
	g.set("idle_time", 0.3)
	g.set("warn_time", 0.3)
	g.set("burst_time", 0.3)
	add_child_autofree(g)
	assert_eq(int(g.get("phase")), 0, "comeca em repouso")
	await _wait(0.45)
	assert_eq(int(g.get("phase")), 1, "aviso antes do jato")
	await _wait(0.3)
	assert_eq(int(g.get("phase")), 2, "jato")
	await _wait(0.3)
	assert_eq(int(g.get("phase")), 0, "volta ao repouso")


func test_geyser_area_and_trigger() -> void:
	var g: Node3D = GEYSER.new()
	add_child_autofree(g)
	g.global_position = Vector3(5, 0, 5)
	assert_true(g.call("is_over", Vector3(5.5, 0.2, 5)), "em cima da fenda")
	assert_false(g.call("is_over", Vector3(8, 0.2, 5)), "fora do raio")
	assert_false(g.call("is_over", Vector3(5, 4.0, 5)), "muito alto")
	g.call("trigger")
	assert_eq(int(g.get("phase")), 2, "trigger dispara o jato")


func test_cratera_secrets_has_hazards() -> void:
	var scene: Node = (load("res://gameplay/quests/cratera/cratera_secrets.tscn") as PackedScene).instantiate()
	autofree(scene)
	assert_not_null(scene.get_node_or_null(^"MeteorShower"), "MeteorShower na cena")
	var geysers: int = 0
	for c: Node in scene.get_node(^"Ground").get_children():
		if c.get_script() == GEYSER:
			geysers += 1
	assert_eq(geysers, 3, "tres geiseres nas fendas")
