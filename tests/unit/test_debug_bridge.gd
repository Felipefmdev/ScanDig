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
