extends GutTest

## #94: maré da Praia. A faixa molhada só se cava na maré baixa; na maré cheia as ondas
## empurram as coisas soltas para a areia, deixam destroços e às vezes um achado comum.

const PRAIA: MapData = preload("res://items/maps/praia.tres")

var world: Node3D
var flags: WorldFlags
var tide: TideCycle
var sea: Node3D
var strip: TideStrip


func before_each() -> void:
	world = Node3D.new()
	add_child_autoqfree(world)
	flags = WorldFlags.new()
	world.add_child(flags)
	# Como no mapa: os achados das ondas caem pelo PickupsRoot.
	var pickups: PickupsRoot = PickupsRoot.new()
	pickups.name = "Pickups"
	world.add_child(pickups)
	sea = Node3D.new()
	sea.name = "Sea"
	sea.position.y = -0.15
	world.add_child(sea)
	tide = TideCycle.new()
	tide.name = "Tide"
	tide.sea_path = ^"../Sea"
	tide.period = 300.0
	tide.low_duration = 90.0
	tide.low_drop = 0.55
	tide.transition = 20.0
	tide.start_time = 150.0  # maré cheia
	world.add_child(tide)
	strip = TideStrip.new()
	strip.tide_path = ^"../Tide"
	strip.map_data = PRAIA
	world.add_child(strip)


func _advance(seconds: float) -> void:
	tide._process(seconds)
	strip._process(seconds)


func test_strip_spots_only_at_low_tide() -> void:
	_advance(0.1)
	assert_eq(strip.current_phase(), 0, "Começa na maré cheia")
	assert_eq(strip.get_strip_spots().size(), 0, "Sem spots na faixa com a maré cheia")
	tide.force_low_tide()
	_advance(0.1)
	assert_eq(strip.current_phase(), 1, "Maré baixa")
	assert_true(flags.has_flag(&"mare_baixa"), "A bandeira da relíquia da maré continua a ligar")
	var spots: Array[BuriedSpot] = strip.get_strip_spots()
	assert_eq(spots.size(), strip.spots_per_low_tide, "Spots novos na faixa molhada")
	for s: BuriedSpot in spots:
		assert_between(s.global_position.x, strip.strip_x.x, strip.strip_x.y, "Spot dentro da faixa")
		assert_not_null(s.item, "Spot com item do pool da Praia")
	# o fim da maré baixa avisa e depois tapa os spots
	_advance(tide.low_duration - strip.warn_before_rise + 0.5)
	assert_eq(strip.current_phase(), 2, "Aviso de maré a subir")
	_advance(strip.warn_before_rise)
	assert_eq(strip.current_phase(), 0, "Maré cheia de novo")
	assert_false(flags.has_flag(&"mare_baixa"))
	assert_eq(strip.get_strip_spots().size(), 0, "O mar tapou a faixa")


func test_strip_is_underwater_at_high_tide_and_dry_at_low() -> void:
	# Maré cheia: a faixa fica abaixo do mar; maré baixa: acima (é por isso que só se cava aí).
	var mid_x: float = (strip.strip_x.x + strip.strip_x.y) * 0.5
	var ground: float = BeachTerrain.height_at(mid_x, 0.0)
	_advance(0.1)
	assert_lt(ground, sea.position.y, "Faixa debaixo de água na maré cheia")
	tide.force_low_tide()
	_advance(0.1)
	assert_gt(BeachTerrain.height_at(strip.strip_x.y, 0.0), sea.position.y, "Faixa a seco na maré baixa")


func test_wave_pushes_loose_items_to_the_sand() -> void:
	var item: ItemData = PRAIA.item_pool[0]
	var pickup: ItemPickup = ItemPickup.create(CarriedItem.create(item, item.base_value, 1.0, false))
	world.add_child(pickup)
	pickup.global_position = Vector3(26.0, 0.5, 0.0)
	await wait_frames(3)
	var x0: float = pickup.global_position.x
	strip.find_chance = 0.0
	strip.send_wave()
	await wait_seconds(0.4)
	assert_lt(pickup.global_position.x, x0 - 0.2, "A onda puxou o item para a areia (-X)")


func test_wave_washes_up_the_sand_and_leaves_debris() -> void:
	strip.debris_chance = 1.0
	strip.find_chance = 0.0
	_advance(0.1)
	var sea_y: float = sea.position.y
	strip.send_wave()
	await wait_seconds(strip.wave_duration * 0.4 + 0.1)
	assert_almost_eq(strip.swash_front, strip.wash_x.x, 0.3, "A espuma sobe a areia até à marca da onda")
	assert_eq(sea.position.y, sea_y, "O nível do mar não mexe (não inunda o interior)")
	assert_gt(strip.get_debris_count(), 0, "A onda deixa destroços na areia")
	await wait_seconds(strip.wave_duration)
	assert_true(is_nan(strip.swash_front), "E a espuma volta ao mar")


func test_wave_can_wash_up_a_common_find() -> void:
	strip.find_chance = 1.0
	strip.debris_chance = 0.0
	var before: int = get_tree().get_nodes_in_group(ItemPickup.GROUP).size()
	strip.send_wave()
	await wait_frames(3)
	var pickups: Array[Node] = get_tree().get_nodes_in_group(ItemPickup.GROUP)
	assert_eq(pickups.size(), before + 1, "Um achado veio dar à costa")
	var found: ItemPickup = null
	for n: Node in pickups:
		var p: ItemPickup = n as ItemPickup
		if p != null and p.carried != null and p.carried.item != null:
			found = p
	assert_not_null(found)
	assert_eq(found.carried.item.category, ItemData.Category.COMUM, "Achado comum")
	for n: Node in pickups:
		n.queue_free()


func test_finds_per_tide_are_capped() -> void:
	strip.find_chance = 1.0
	strip.debris_chance = 0.0
	strip.max_finds_per_tide = 2
	var before: int = get_tree().get_nodes_in_group(ItemPickup.GROUP).size()
	for i: int in 4:
		strip.send_wave()
	await wait_frames(3)
	var pickups: Array[Node] = get_tree().get_nodes_in_group(ItemPickup.GROUP)
	assert_eq(pickups.size(), before + 2, "No máximo 2 achados por maré")
	for n: Node in pickups:
		n.queue_free()


func test_praia_scene_wires_the_tide() -> void:
	var scene: PackedScene = load("res://gameplay/quests/praia/praia_secrets.tscn")
	var secrets: Node = scene.instantiate()
	var t: TideCycle = secrets.get_node(^"Tide") as TideCycle
	assert_between(t.period, 240.0, 360.0, "Ciclo de maré de 4-6 min")
	assert_not_null(secrets.get_node_or_null(^"TideStrip") as TideStrip, "TideStrip na Praia")
	secrets.free()
