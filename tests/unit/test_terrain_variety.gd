extends GutTest

## Chão variado das Ruínas e da Cratera (estudo How to Fish): cor variada e relevo com colinas.
## As alturas fixadas abaixo apanham qualquer mudança não intencional do chão (colisão, buracos,
## chefes e limites dependem dele); o templo, a cripta e as zonas planas não podem mudar.

const POINTS: Array = [
	[0.0, 0.0], [0.0, 11.0], [5.5, -20.0], [-22.0, -6.0], [-19.0, -6.0], [0.0, -15.0],
	[12.3, 7.7], [-30.0, 25.0], [35.0, -40.0], [16.0, -14.0], [-14.0, 10.0], [3.3, -4.1],
]
## height_at() com o relevo (ondulação larga + zonas planas da Banca e dos altares).
const RUINS_HEIGHTS: Array[float] = [
	0.0, 0.459023, 0.9, -1.01478, -1.033869, 0.9, 0.0, 0.607893, 0.796266, 0.0,
	1.204629, -0.001277,
]
const CRATER_HEIGHTS: Array[float] = [
	0.0, -0.490452, -0.318556, -0.026848, 0.246876, 0.372145, 0.012704, 0.112253, 0.602437,
	0.0, 0.0, -1.182208,
]


func test_ruins_height_pinned() -> void:
	for i: int in POINTS.size():
		var p: Array = POINTS[i]
		assert_almost_eq(RuinsTerrain.height_at(p[0], p[1]), RUINS_HEIGHTS[i], 0.0001, "Ruínas %s" % [p])


func test_crater_height_pinned() -> void:
	for i: int in POINTS.size():
		var p: Array = POINTS[i]
		assert_almost_eq(CraterTerrain.height_at(p[0], p[1]), CRATER_HEIGHTS[i], 0.0001, "Cratera %s" % [p])


func test_ruins_slabs_vary() -> void:
	# Centros de triângulo no pátio (como no rebuild): muitas cores, não só um xadrez de 2.
	var colors: Dictionary = {}
	var soil_like: int = 0
	var samples: int = 0
	for ix: int in range(-9, 9):
		for iz: int in range(-12, 8):
			var x: float = float(ix) + 0.33
			var z: float = float(iz) + 0.67
			if RuinsTerrain.paved_weight(x, z) <= 0.5:
				continue
			var c: Color = RuinsTerrain.color_at(x, z, RuinsTerrain.height_at(x, z))
			colors[c.to_html(false)] = true
			samples += 1
			if c.r > c.b + 0.12 and c.g < 0.45:
				soil_like += 1
	assert_gt(samples, 100, "Amostras no pátio")
	assert_gt(colors.size(), 40, "Lajes com tons variados (%d cores)" % colors.size())
	assert_gt(soil_like, 0, "Há terra à vista (lajes em falta / juntas abertas)")
	assert_lt(soil_like, samples / 2, "Mas o pátio continua a ser maioritariamente lajes")


func test_ruins_tile_rand_is_stable() -> void:
	assert_eq(RuinsTerrain.tile_rand(3, -7, 0), RuinsTerrain.tile_rand(3, -7, 0))
	var v: float = RuinsTerrain.tile_rand(-12, 40, 2)
	assert_true(v >= 0.0 and v < 1.0)


func test_crater_gradient_and_patches() -> void:
	var center: float = 0.0
	var rim: float = 0.0
	var colors: Dictionary = {}
	var n: int = 0
	for k: int in 24:
		var a: float = TAU * float(k) / 24.0
		var cx: float = cos(a) * 4.0
		var cz: float = sin(a) * 4.0
		var rx: float = cos(a) * 27.0
		var rz: float = sin(a) * 27.0
		var cc: Color = CraterTerrain.color_at(cx, cz, CraterTerrain.height_at(cx, cz))
		var rc: Color = CraterTerrain.color_at(rx, rz, CraterTerrain.height_at(rx, rz))
		center += cc.get_luminance()
		rim += rc.get_luminance()
		colors[cc.to_html(false)] = true
		colors[rc.to_html(false)] = true
		n += 1
	assert_gt(center / n, rim / n, "Mais claro no centro do que nas margens")
	assert_gt(colors.size(), 30, "Chão da Cratera com variação de tom")
