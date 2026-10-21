extends GutTest

## #151: bordas devem seguir o terreno, nunca o topo de Bounds ou o fallback y=0.
const TERRAINS: Dictionary = {
	"praia": preload("res://gameplay/environment/beach_terrain.gd"),
	"campo": preload("res://gameplay/environment/field_terrain.gd"),
	"ruinas": preload("res://gameplay/environment/ruins_terrain.gd"),
	"geleira": preload("res://gameplay/environment/glacier_terrain.gd"),
	"cratera": preload("res://gameplay/environment/crater_terrain.gd"),
}


class BorderScatter extends "res://gameplay/environment/decoration_scatter.gd":
	# Isola a construcao das bordas do ciclo de vida de fauna/backdrop.
	func _ready() -> void:
		pass


func test_both_border_rows_follow_terrain_beneath_bounds_and_beyond_collision() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 6.0, 62.0)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(30.5, 2.5, 0.0)
	add_child_autofree(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for theme_name: String in TERRAINS:
		var scatter: Node3D = BorderScatter.new()
		scatter.set("theme", theme_name)
		scatter.set("count", 0)
		add_child_autofree(scatter)
		var kinds: Dictionary = scatter.get("_kinds")
		kinds.clear()
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 151
		scatter.call("_border", Vector2(29.0, 29.0), rng)
		var worst_error: float = 0.0
		var inner_count: int = 0
		var outer_count: int = 0
		for kind: String in kinds:
			var entry: Dictionary = kinds[kind]
			var transforms: Array = entry["xforms"]
			for transform: Transform3D in transforms:
				var p: Vector3 = transform.origin
				var expected_y: float = TERRAINS[theme_name].height_at(p.x, p.z) - 0.3
				worst_error = maxf(worst_error, absf(p.y - expected_y))
				if maxf(absf(p.x), absf(p.z)) > 31.0:
					outer_count += 1
				else:
					inner_count += 1
		assert_gt(inner_count, 0, theme_name + ": cobre a fila junto a Bounds")
		assert_gt(outer_count, 0, theme_name + ": cobre a fila fora da colisao")
		assert_lt(worst_error, 0.001, theme_name + ": apoio no terreno, com enterro de 0.3 m")


func test_campo_border_rocks_leave_the_landscape_visible() -> void:
	var scatter: Node3D = BorderScatter.new()
	scatter.set("theme", "campo")
	autofree(scatter)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 157
	scatter.call("_border", Vector2(29.0, 29.0), rng)
	var kinds: Dictionary = scatter.get("_kinds")
	var maximum_height: float = 0.0
	for kind: String in kinds:
		for pose: Transform3D in kinds[kind]["xforms"]:
			# O modelo termina em y=0.75; limitar a silhueta acima do apoio.
			maximum_height = maxf(maximum_height, pose.basis.y.length() * 0.75)
	assert_lt(maximum_height, 1.5, "Borda rural baixa deixa ver bosques e lavoura externa")