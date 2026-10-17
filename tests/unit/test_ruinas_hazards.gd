extends GutTest

## #97: colunas instáveis (cavar perto faz cair, telegrafado, linha de queda, entulho) e placas de
## pressão (jogador ou inimigo dispara dardos/pedra; rearma).

const COLUMN: Script = preload("res://gameplay/quests/ruinas/unstable_column.gd")
const PLATE: Script = preload("res://gameplay/quests/ruinas/pressure_plate.gd")


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout


func test_fall_line_geometry() -> void:
	var a: Vector3 = Vector3.ZERO
	var b: Vector3 = Vector3(0, 0, 3.4)
	assert_true(COLUMN.in_fall_line(Vector3(0.3, 0.5, 2.0), a, b), "debaixo da coluna")
	assert_false(COLUMN.in_fall_line(Vector3(2.0, 0.5, 2.0), a, b), "ao lado")
	assert_false(COLUMN.in_fall_line(Vector3(0, 0.5, -1.5), a, b), "atras da base")
	assert_false(COLUMN.in_fall_line(Vector3(0, 6.0, 2.0), a, b), "muito acima")


func test_column_needs_two_digs_then_topples_toward_digging() -> void:
	var c: Node3D = COLUMN.new()
	c.set("niche_chance", 0.0)
	add_child_autofree(c)
	await get_tree().process_frame
	assert_not_null(c.get_node_or_null(^"Pivot/Cracks"), "rachas visiveis")
	assert_false(c.call("add_stress", Vector3(0, 0, 2)), "primeiro golpe so estala")
	assert_true(c.call("add_stress", Vector3(0, 0, 2)), "segundo golpe faz cair")
	assert_true(c.get("wobbling"), "abana antes de cair (telegrafado)")
	assert_false(c.get("fallen"))
	await _wait(COLUMN.WOBBLE_TIME + COLUMN.FALL_TIME + 0.3)
	assert_true(c.get("fallen"), "caiu")
	assert_not_null(c.get_node_or_null(^"Rubble"), "deixa entulho")
	var top: Vector3 = (c.get_node(^"Pivot") as Node3D).basis * Vector3.UP
	assert_gt(top.z, 0.9, "tombou para o lado onde se cavou")
	assert_false(c.call("add_stress", Vector3(0, 0, 2)), "caida nao cai outra vez")


func test_plate_detects_bodies_and_rearms() -> void:
	var p: Node3D = PLATE.new()
	p.set("cooldown", 0.4)
	p.set("delay", 0.05)
	add_child_autofree(p)
	assert_true(p.call("is_on_plate", Vector3(0.3, 0.5, -0.2)), "em cima")
	assert_false(p.call("is_on_plate", Vector3(1.5, 0.5, 0)), "fora")
	var enemy: Node3D = Node3D.new()
	enemy.add_to_group(&"enemies")
	add_child_autofree(enemy)
	enemy.global_position = Vector3(0.2, 0.1, 0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(int(p.get("triggered_count")), 1, "um inimigo em cima tambem dispara")
	assert_false(p.get("armed"), "desarmada depois de disparar")
	enemy.global_position = Vector3(10, 0, 0)
	await _wait(0.6)
	assert_true(p.get("armed"), "rearma depois do cooldown")


func test_dart_line_crosses_plate_and_rock_area() -> void:
	var p: Node3D = PLATE.new()
	p.set("emitter_offset", Vector3(6, 1, 0))
	add_child_autofree(p)
	assert_true(p.call("is_hit", Vector3(0, 0.5, 0.2)), "dardos passam pela placa")
	assert_true(p.call("is_hit", Vector3(3, 0.5, 0)), "e pelo caminho desde o bocal")
	assert_false(p.call("is_hit", Vector3(0, 0.5, 2.0)), "fora da linha")
	var r: Node3D = PLATE.new()
	r.set("trap", 1)
	add_child_autofree(r)
	assert_true(r.call("is_hit", Vector3(1.0, 0.3, 0.5)), "pedra acerta perto")
	assert_false(r.call("is_hit", Vector3(3.0, 0.3, 0)), "pedra nao acerta longe")


func test_ruinas_secrets_has_hazards() -> void:
	var scene: Node = (load("res://gameplay/quests/ruinas/ruinas_secrets.tscn") as PackedScene).instantiate()
	autofree(scene)
	var cols: int = 0
	var plates: int = 0
	for c: Node in scene.get_node(^"Ground").get_children():
		if c.get_script() == COLUMN:
			cols += 1
		elif c.get_script() == PLATE:
			plates += 1
	assert_eq(cols, 3, "tres colunas instaveis")
	assert_eq(plates, 3, "tres placas de pressao")
