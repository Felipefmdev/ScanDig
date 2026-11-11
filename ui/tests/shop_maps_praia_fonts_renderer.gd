extends SceneTree
## Renderer real obrigatorio antes do merge; headless nao constitui aceite.
## Godot --path . --windowed --resolution 2560x1440 --script res://ui/tests/shop_maps_praia_fonts_renderer.gd
## Gate: exit0, sem SCRIPT/Parse Error ou FAIL; CHECKS count=63 e RESULT fails=0.
## #216: fontes da Praia por papel nas cinco lojas, com Prompt real e dinamico.
const DRIVER: Script = preload("res://ui/shop_distance_legibility.gd")
const HELPER: Script = preload("res://ui/world_shop_typography.gd")
const COUNTER: PackedScene = preload("res://gameplay/environment/upgrade_counter.tscn")
const SHOP_THEME: Theme = preload("res://ui/theme/scandig_theme.tres")
const IDS: Array[String] = ["praia", "campo", "ruinas", "geleira", "cratera"]
const NAMES: Array[String] = ["MapPraia", "MapCampo", "MapRuinas", "MapGeleira", "MapCratera"]
const COUNTS: Array[int] = [4, 5, 7, 8, 9]
var _checks: int = 0
var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	_fails += 0 if ok else 1
	print(("PASS " if ok else "FAIL ") + message)


func _base(font: Font) -> FontFile:
	var result: Font = font
	while result is FontVariation:
		result = (result as FontVariation).base_font
	return result as FontFile


func _style_ok(label: Label3D, source: Font) -> bool:
	var file: FontFile = _base(label.font)
	var original: FontFile = _base(source)
	if not label.font is FontVariation or not source is FontVariation or file == null or original == null:
		return false
	return label.font != source and file != original and file.data == original.data and is_equal_approx((label.font as FontVariation).variation_embolden, (source as FontVariation).variation_embolden) and not file.multichannel_signed_distance_field and is_equal_approx(file.oversampling, 2.0) and label.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR


func _cache(labels: Array[Label3D]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for label: Label3D in labels:
		result.append({"font": label.font, "size": label.font_size, "outline": label.outline_size, "filter": label.texture_filter, "pixel": label.pixel_size, "transform": label.transform, "offset": label.offset, "text": label.text, "color": label.modulate, "ink": label.outline_modulate})
	return result


func _restored(labels: Array[Label3D], cache: Array[Dictionary]) -> bool:
	for index: int in labels.size():
		var label: Label3D = labels[index]
		var before: Dictionary = cache[index]
		if label.font != before["font"] or label.font_size != before["size"] or label.outline_size != before["outline"] or label.texture_filter != before["filter"] or not is_equal_approx(label.pixel_size, before["pixel"]) or not label.transform.is_equal_approx(before["transform"]) or not label.modulate.is_equal_approx(before["color"]) or not label.outline_modulate.is_equal_approx(before["ink"]):
			return false
	return true


func _step(driver: Node, fixture: Dictionary, delta: float) -> void:
	var helper: Node = fixture["helper"]
	if helper != null:
		helper.call("_process", delta)
	driver.call("update_for_camera", fixture["camera"], delta)
	await process_frame


func _fixture(index: int) -> Dictionary:
	var map: Node3D = Node3D.new()
	map.name = NAMES[index]
	map.scene_file_path = "res://world/map_%s.tscn" % IDS[index]
	var bank: Node3D = Node3D.new()
	bank.name = "Banca"
	map.add_child(bank)
	var offers: Array[ShopOffer] = []
	for number: int in COUNTS[index]:
		var offer: ShopOffer = ShopOffer.new()
		offer.name = "Offer%d" % (number + 1)
		offer.position = Vector3(0, 0.54 if index < 2 else 0.9, (number - (COUNTS[index] - 1) * 0.5) * 0.8)
		var data: ToolData = ToolData.new()
		data.display_name = "Produto %d" % number
		data.price = 50 + number
		offer.tool_data = data
		bank.add_child(offer)
		offers.append(offer)
	var shop: Label3D = Label3D.new()
	shop.name = "Label"
	shop.text = "LOJA"
	shop.font_size = 64
	shop.pixel_size = 0.008
	shop.outline_size = 14
	shop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shop.position.y = 2.35 if index == 0 else (2.1 if index == 1 else 2.3)
	shop.modulate = Color(0.55, 0.9, 1, 0.9)
	bank.add_child(shop)
	var delivery: Node3D = Node3D.new()
	delivery.name = "BaseEntrega"
	map.add_child(delivery)
	var delivery_label: Label3D = Label3D.new()
	delivery_label.name = "Label"
	delivery_label.text = "ENTREGA [E]"
	delivery_label.font_size = 56
	delivery_label.pixel_size = 0.008
	delivery_label.outline_size = 14
	delivery_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	delivery_label.position = Vector3(0.75, 2.5, 0.75)
	delivery_label.modulate = Color(1, 0.88, 0.35, 1)
	delivery.add_child(delivery_label)
	var counter: Node3D = COUNTER.instantiate() as Node3D
	counter.name = "Upgrades"
	counter.set("map_id", IDS[index])
	bank.add_child(counter)
	var helper: Node = null
	if index == 0:
		helper = HELPER.new() as Node
		helper.name = "ShopTypography"
		helper.set("map_root", NodePath(".."))
		var titles: Array[NodePath] = [^"BaseEntrega/Label", ^"Banca/Label", ^"Banca/Upgrades/Label"]
		var body: Array[NodePath] = [^"Banca/Upgrades/Prompt"]
		var paths: Array[NodePath] = [^"Banca/Offer1", ^"Banca/Offer2", ^"Banca/Offer3", ^"Banca/Offer4"]
		helper.set("title_labels", titles)
		helper.set("body_labels", body)
		helper.set("offers", paths)
		map.add_child(helper)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(2.5, 1.62, 0)
	camera.fov = 100
	map.add_child(camera)
	root.add_child(map)
	current_scene = map
	camera.make_current()
	camera.look_at(Vector3(0, 1.3, 0))
	await process_frame
	await process_frame
	counter.set_process(false) # Exercise real _set_focused without a Player scanning the fixture.
	if helper != null:
		helper.set_process(false)
		helper.call("_process", 0.0)
	var labels: Array[Label3D] = []
	for offer: ShopOffer in offers:
		var label: Label3D = offer.get("_label") as Label3D
		label.modulate.a = 0.7
		label.outline_modulate.a = 0.4
		labels.append(label)
	labels.append_array([shop, delivery_label, counter.get_node(^"Label") as Label3D, counter.get_node(^"Prompt") as Label3D])
	return {"map": map, "camera": camera, "helper": helper, "counter": counter, "offers": offers, "labels": labels}


func _run() -> void:
	var installed: Node = root.get_node_or_null(^"CoreShopDistanceLegibility")
	if installed != null:
		installed.set_process(false)
		installed.call("restore_shop")
	var driver: Node = DRIVER.new() as Node
	root.add_child(driver)
	var previous: Dictionary = {}
	_check(DisplayServer.get_name() != "headless", "renderer real para familia/estilo das fontes")
	for index: int in IDS.size():
		var fixture: Dictionary = await _fixture(index)
		var labels: Array[Label3D] = fixture["labels"]
		var count: int = COUNTS[index]
		var prompt: Label3D = labels[count + 3]
		var before: Array[Dictionary] = _cache(labels)
		fixture["before"] = before
		_check(prompt.text.is_empty() and not prompt.visible, IDS[index] + ": Prompt real inicia vazio/oculto")
		for frame: int in 4:
			driver.call("_process", 0.0)
			await process_frame
		_check(driver.get("_map") == fixture["map"], IDS[index] + ": bind admite Prompt vazio")
		var snapshot: Dictionary = driver.call("get_proximity_snapshot")
		_check((snapshot.get("labels", []) as Array).size() == count + 4, IDS[index] + ": inclui produtos tres titulos e Prompt")
		if index == 0:
			var helper: Node = fixture["helper"]
			_check((helper.get("offers") as Array).size() == 4 and (helper.get("title_labels") as Array).size() == 3 and (helper.get("body_labels") as Array).size() == 1, "helper Praia real conserva contrato4ofertas/3titulos/1prompt")
		if not previous.is_empty():
			_check(_restored(previous["labels"], previous["before"]), "rebind restaura fontes/outline/pixel/cores da cena anterior")
			(previous["map"] as Node).free()
		await _step(driver, fixture, 0.25)
		var roles_ok: bool = true
		var geometry_ok: bool = true
		for number: int in labels.size():
			var source: Font = SHOP_THEME.default_font if number < count or number == count + 3 else SHOP_THEME.get_font(&"font", &"TitleLabel")
			roles_ok = roles_ok and _style_ok(labels[number], source) and labels[number].outline_size == 8
			var expected_pixel: float = 0.0032 * minf(1.0, (fixture["camera"] as Camera3D).global_position.distance_to(labels[number].global_position) / 2.8) if index == 0 and number < count else float(before[number]["pixel"])
			geometry_ok = geometry_ok and labels[number].font_size == before[number]["size"] and is_equal_approx(labels[number].pixel_size, expected_pixel) and labels[number].transform.is_equal_approx(before[number]["transform"]) and labels[number].text == before[number]["text"]
			if not (index == 0 and number == count):
				geometry_ok = geometry_ok and labels[number].offset.is_equal_approx(before[number]["offset"])
		_check(roles_ok, IDS[index] + ": todos papeis usam fontesPraia privadas raster2/Linear/outline8")
		_check(geometry_ok, IDS[index] + ": tamanhos pixels ancoras e Prompt vazio preservados")
		(fixture["counter"] as Node).call("_set_focused", true)
		var prompt_text: String = prompt.text
		await _step(driver, fixture, 0.0)
		_check(not prompt_text.is_empty() and prompt.visible and prompt.text == prompt_text and driver.get("_map") == fixture["map"] and _style_ok(prompt, SHOP_THEME.default_font), IDS[index] + ": foco real altera Prompt sem invalidar fonte/bind/visibilidade")
		(fixture["counter"] as Node).call("_set_focused", false)
		await _step(driver, fixture, 0.0)
		_check(not prompt.visible and prompt.text == prompt_text, IDS[index] + ": Interactable continua dono da visibilidade/texto Prompt")
		var offer: ShopOffer = (fixture["offers"] as Array).back() as ShopOffer
		offer.set_highlighted(true)
		await _step(driver, fixture, 0.0)
		var focused: Color = labels[count - 1].modulate
		_check(is_equal_approx(focused.r, 1.0) and is_equal_approx(focused.g, 0.9) and is_equal_approx(focused.b, 0.3) and is_equal_approx(focused.a, 0.7), IDS[index] + ": ShopOffer real preserva RGB foco e alphaoriginal")
		offer.set_highlighted(false)
		await _step(driver, fixture, 0.0)
		(fixture["camera"] as Camera3D).position.x = 3.7
		await _step(driver, fixture, 0.0)
		_check(bool((driver.call("get_proximity_snapshot") as Dictionary).get("target_visible", false)), IDS[index] + ": histerese3.7 preservada")
		(fixture["camera"] as Camera3D).position.x = 5.0
		await _step(driver, fixture, 0.125)
		_check(is_equal_approx(labels[0].modulate.a, 0.35) and is_equal_approx(labels[0].outline_modulate.a, 0.2), IDS[index] + ": fade0.25 texto/outline com alphaoriginal")
		await _step(driver, fixture, 0.125)
		var far_ok: bool = true
		for number: int in count:
			far_ok = far_ok and not labels[number].visible and is_zero_approx(labels[number].modulate.a) and is_zero_approx(labels[number].outline_modulate.a)
		for number: int in range(count, count + 3):
			far_ok = far_ok and labels[number].visible and labels[number].modulate.is_equal_approx(before[number]["color"])
		_check(far_ok, IDS[index] + ": longe oculta so produtos e preserva placas/cores")
		previous = fixture
	var final_prompt: Label3D = (previous["labels"] as Array).back() as Label3D
	(previous["counter"] as Node).call("_set_focused", true)
	var final_prompt_text: String = final_prompt.text
	driver.call("restore_shop")
	_check(_restored(previous["labels"], previous["before"]), "restore final de todos os papeis e propriedades originais")
	_check(final_prompt.visible and final_prompt.text == final_prompt_text, "restore nao rouba texto ou visibilidade do Prompt ainda focado")
	(previous["map"] as Node).free()
	driver.free()
	current_scene = null
	print("CHECKS count=%d" % _checks)
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
