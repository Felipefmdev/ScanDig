extends GutTest

const Bridge: GDScript = preload("res://gameplay/debug/debug_bridge.gd")


func test_valid_script() -> void:
	var r: Dictionary = Bridge.parse_script({
		"scene": "res://world/map_praia.tscn",
		"steps": [
			{"t": 0.5, "press": "move_forward", "for": 2.0},
			{"t": 3, "tap": "use_tool"},
			{"t": 3, "look": [10, -5]},
			{"t": 4, "screenshot": "a"},
			{"t": 4, "dump": "b"},
			{"t": 5, "teleport": [1, 2, 3]},
			{"t": 5, "look_at": [0, 1, 0]},
			{"t": 5, "goto_spot": "nearest"},
			{"wait_until": "money>=300", "timeout": 900},
			{"t": 60, "quit": true},
		],
	})
	assert_true(r["ok"], str(r["errors"]))
	var steps: Array = r["steps"]
	assert_eq(steps.size(), 10)
	assert_eq(steps[0]["for"], 2.0)
	assert_eq(steps[1]["for"], Bridge.TAP_SECONDS)
	assert_eq(steps[2]["delta"], Vector2(10, -5))
	assert_eq(steps[5]["position"], Vector3(1, 2, 3))
	assert_eq(steps[8]["condition"], {"var": "money", "op": ">=", "value": 300.0})
	assert_eq(steps[8]["timeout"], 900.0)


func test_root_errors() -> void:
	assert_false(Bridge.parse_script([])["ok"])
	assert_false(Bridge.parse_script({"steps": "x"})["ok"])
	assert_false(Bridge.parse_script({"scene": "map.tscn", "steps": []})["ok"])
	assert_true(Bridge.parse_script({"steps": []})["ok"])


func test_invalid_steps() -> void:
	var bad: Array = [
		"nao e objeto",
		{"press": "move_forward", "for": 1.0},
		{"t": -1, "tap": "jump"},
		{"t": 1, "tap": "voar"},
		{"t": 1, "press": "jump"},
		{"t": 1, "press": "jump", "for": 0},
		{"t": 1, "look": [1]},
		{"t": 1, "teleport": [1, "a", 3]},
		{"t": 1, "screenshot": ""},
		{"t": 1, "dump": "a/b"},
		{"t": 1, "tap": "jump", "dump": "x"},
		{"t": 1},
		{"wait_until": "ouro>=3"},
		{"wait_until": "money>=x"},
		{"wait_until": "money>=1", "timeout": 0},
		{"t": 1, "goto_spot": "far"},
		{"t": 1, "look_at": [1, 2]},
		{"t": 1, "quit": false},
	]
	for raw: Variant in bad:
		assert_true(Bridge.parse_step(raw) is String, "deveria falhar: %s" % str(raw))
	var r: Dictionary = Bridge.parse_script({"steps": bad})
	assert_false(r["ok"])
	assert_eq((r["errors"] as PackedStringArray).size(), bad.size())


func test_conditions() -> void:
	assert_eq(Bridge.parse_condition("spots < 2"), {"var": "spots", "op": "<", "value": 2.0})
	assert_eq(Bridge.parse_condition("health!=0"), {"var": "health", "op": "!=", "value": 0.0})
	assert_null(Bridge.parse_condition(">=3"))
	assert_true(Bridge.compare(300, ">=", 300))
	assert_false(Bridge.compare(299, ">=", 300))
	assert_true(Bridge.compare(1, "<", 2))


func test_loop_and_high_level_steps() -> void:
	var r: Dictionary = Bridge.parse_script({
		"dump_every": 60,
		"screenshot_every": 120,
		"steps": [
			{"loop": [
				{"goto_sell": true, "if": ["deliverable>=1", "free_slots<=0"]},
				{"sell": true, "timeout": 5},
				{"goto_spot": "nearest", "walk": true},
				{"dig_spot": true, "mode": "smart"},
				{"pickup": true, "radius": 4},
				{"wait_until": "nearest_spot<9000"},
			], "until": "money>=300", "timeout": 1200},
		],
	})
	assert_true(r["ok"], str(r["errors"]))
	assert_eq(r["periodic"], {"dump_every": 60.0, "screenshot_every": 120.0})
	var loop: Dictionary = (r["steps"] as Array)[0]
	assert_eq(loop["until"], {"var": "money", "op": ">=", "value": 300.0})
	assert_eq(loop["timeout"], 1200.0)
	var body: Array = loop["body"]
	assert_eq(body.size(), 6)
	assert_eq((body[0]["if"] as Array).size(), 2)
	assert_eq(body[1]["timeout"], 5.0)
	assert_true(body[2]["walk"])
	assert_eq(body[3]["mode"], "smart")
	assert_eq(body[4]["radius"], 4.0)


func test_invalid_high_level_steps() -> void:
	var bad: Array = [
		{"loop": [], "until": "money>=1", "timeout": 10},
		{"loop": [{"sell": true}], "timeout": 10},
		{"loop": [{"sell": true}], "until": "money>=1"},
		{"loop": [{"quit": true}], "until": "money>=1", "timeout": 10},
		{"loop": [{"tap": "voar"}], "until": "money>=1", "timeout": 10},
		{"t": 1, "dig_spot": true, "mode": "lento"},
		{"t": 1, "pickup": true, "radius": 0},
		{"t": 1, "sell": true, "if": "ouro>1"},
		{"t": 1, "sell": true, "if": []},
		{"sell": true},
	]
	for raw: Variant in bad:
		assert_true(Bridge.parse_step(raw) is String, "deveria falhar: %s" % str(raw))
	assert_false(Bridge.parse_script({"steps": [], "dump_every": 0})["ok"])


func test_set_state() -> void:
	var ok: Variant = Bridge.parse_step({"t": 0, "set_state": {"upgrade_levels": {"backpack": 3}, "unlocked_maps": ["campo"], "team_money": 5000}})
	assert_true(ok is Dictionary, str(ok))
	assert_eq((ok as Dictionary)["state"]["upgrade_levels"], {"backpack": 3})
	for bad: Variant in [{}, {"current_day": 2}, {"team_money": "x"}, {"upgrade_levels": 3}, {"unlocked_maps": "campo"}]:
		assert_true(Bridge.parse_step({"t": 0, "set_state": bad}) is String, "deveria falhar: %s" % str(bad))


func test_explore_and_radar_radius() -> void:
	var ok: Variant = Bridge.parse_step({"explore": 10, "bounds": [-23, -23, 23, 23], "stop_near_spot": 8}, true)
	assert_true(ok is Dictionary, str(ok))
	assert_eq(ok["distance"], 10.0)
	assert_eq(ok["bounds"], Rect2(-23, -23, 46, 46))
	assert_eq(ok["stop_near_spot"], 8.0)
	var spot: Variant = Bridge.parse_step({"goto_spot": "nearest", "walk": true, "radius": 8}, true)
	assert_eq(spot["radius"], 8.0)
	assert_eq(Bridge.parse_condition("pickup_dist<=6"), {"var": "pickup_dist", "op": "<=", "value": 6.0})
	var bad: Array = [
		{"explore": 0},
		{"explore": 5, "bounds": [1, 1, 0, 0]},
		{"explore": 5, "stop_near_spot": -1},
		{"goto_spot": "nearest", "radius": -2},
	]
	for raw: Variant in bad:
		assert_true(Bridge.parse_step(raw, true) is String, "deveria falhar: %s" % str(raw))


func test_fight_step() -> void:
	var ok: Variant = Bridge.parse_step({"t": 1, "fight": 30, "radius": 10})
	assert_true(ok is Dictionary, str(ok))
	assert_eq(ok["for"], 30.0)
	assert_eq(ok["radius"], 10.0)
	assert_true(Bridge.parse_step({"fight": 0}, true) is String)
	assert_true(Bridge.parse_step({"fight": 5, "radius": 0}, true) is String)
	assert_true(Bridge.parse_step({"t": 1, "tap": "attack"}) is Dictionary)
	assert_eq(Bridge.parse_condition("enemy_dist<4"), {"var": "enemy_dist", "op": "<", "value": 4.0})


func test_coop_steps() -> void:
	var host: Variant = Bridge.parse_step({"t": 0, "host": 7791})
	assert_eq((host as Dictionary)["port"], 7791)
	assert_eq((Bridge.parse_step({"t": 0, "host": true}) as Dictionary)["port"], Bridge.DEFAULT_NET_PORT)
	var join: Variant = Bridge.parse_step({"t": 0, "join": "127.0.0.1", "port": 7791, "timeout": 20})
	assert_eq((join as Dictionary)["ip"], "127.0.0.1")
	assert_eq((join as Dictionary)["port"], 7791)
	assert_eq((Bridge.parse_step({"t": 0, "start_expedition": "praia"}) as Dictionary)["map_id"], "praia")
	assert_eq((Bridge.parse_step({"sleep": 1.5}) as Dictionary)["seconds"], 1.5, "sleep dispensa 't'")
	assert_true(Bridge.parse_step({"t": 0, "face_player": "remote"}) is Dictionary)
	assert_true(Bridge.parse_step({"t": 0, "goto_player": "remote"}) is Dictionary)
	assert_eq(Bridge.parse_condition("players>=2"), {"var": "players", "op": ">=", "value": 2.0})
	for bad: Dictionary in [
		{"t": 0, "host": 80}, {"t": 0, "host": "x"}, {"t": 0, "join": ""}, {"t": 0, "join": "1.2.3.4", "port": 99999},
		{"t": 0, "start_expedition": "../x"}, {"sleep": -1}, {"t": 0, "face_player": "1"}, {"t": 0, "goto_player": 2},
	]:
		assert_true(Bridge.parse_step(bad) is String, "deveria falhar: %s" % str(bad))
