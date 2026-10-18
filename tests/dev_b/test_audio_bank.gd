extends GutTest

## Banco do SFX (#123): todo caminho existe e carrega, cada superfície tem 3+ passos e uma
## pazada própria, e cada categoria tem volume e (se 3D) alcance definidos num lugar só.

const SURFACES: Array[StringName] = [&"sand", &"snow", &"grass", &"stone", &"crystal", &"water", &"wood"]


func test_every_bank_path_exists_and_loads() -> void:
	var paths: Array[String] = SFX.all_paths()
	assert_gt(paths.size(), 40, "o banco lista os sons do jogo")
	for path: String in paths:
		assert_true(ResourceLoader.exists(path), "existe: %s" % path)
		assert_not_null(load(path) as AudioStream, "carrega como AudioStream: %s" % path)


func test_each_surface_has_three_or_more_footsteps() -> void:
	for s: StringName in SURFACES:
		var steps: Array[String] = SFX.footstep_sound_for_surface(s)
		assert_gte(steps.size(), 3, "%s: 3+ variantes de passo" % s)
		for path: String in steps:
			assert_eq(SFX.category_of(path), &"step", "%s: passo na categoria step (%s)" % [s, path])


func test_dig_sound_follows_surface() -> void:
	assert_eq(SFX.dig_sound_for_surface(&"sand", false), SFX.DIG_FAST)
	assert_eq(SFX.dig_sound_for_surface(&"water", true), SFX.DIG_CAREFUL)
	assert_eq(SFX.dig_sound_for_surface(&"grass", false), SFX.DIG_FAST_DIRT)
	assert_eq(SFX.dig_sound_for_surface(&"wood", true), SFX.DIG_CAREFUL_DIRT)
	assert_eq(SFX.dig_sound_for_surface(&"snow", false), SFX.DIG_FAST_SNOW)
	assert_eq(SFX.dig_sound_for_surface(&"stone", true), SFX.DIG_CAREFUL_STONE)
	assert_eq(SFX.dig_sound_for_surface(&"crystal", false), SFX.DIG_FAST_STONE)
	for s: StringName in SURFACES:
		for careful: bool in [false, true]:
			assert_gte(SFX.dig_sound_for_surface(s, careful).size(), 2, "%s: 2+ pazadas" % s)


func test_categories_have_volume_and_range() -> void:
	for cat: StringName in SFX._BANK:
		assert_true(SFX.CATEGORY_DB.has(cat), "volume da categoria %s" % cat)
	for cat: StringName in SFX.CATEGORY_RANGE:
		var r: Vector2 = SFX.CATEGORY_RANGE[cat]
		assert_gt(r.y, r.x, "%s: max_distance > unit_size" % cat)
	# passos de outro jogador a ~15 m ainda chegam
	assert_gte((SFX.CATEGORY_RANGE[&"step"] as Vector2).y, 15.0)


func test_play_at_applies_category_volume_and_range() -> void:
	var p: AudioStreamPlayer3D = SFX.play_at(SFX.FOOTSTEP_GRASS, Vector3.ZERO, -10.0, 0.0)
	assert_not_null(p)
	var r: Vector2 = SFX.CATEGORY_RANGE[&"step"]
	assert_almost_eq(p.volume_db, -10.0 + float(SFX.CATEGORY_DB[&"step"]), 0.001)
	assert_eq(p.unit_size, r.x)
	assert_eq(p.max_distance, r.y)
	p.queue_free()
	var u: AudioStreamPlayer = SFX.play_ui(SFX.UI_CLICK, 0.0, 0.0)
	assert_not_null(u)
	assert_almost_eq(u.volume_db, float(SFX.CATEGORY_DB[&"ui_nav"]), 0.001, "UI com volume baixo")
	assert_lt(u.volume_db, -10.0)
	u.queue_free()
