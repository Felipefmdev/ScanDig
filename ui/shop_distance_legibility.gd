extends Node
## #213: rotulos originais de perto com fade/histerese; LOJA acima da cumeeira.
## RGB pertence ao foco externo; somente alpha/visibilidade sao modulados pelo fade.
const MAP_PATH: String = "res://world/map_praia.tscn"
const OFFER_PATHS: Array[NodePath] = [^"Banca/Offer1", ^"Banca/Offer2", ^"Banca/Offer3", ^"Banca/Offer4"]
const ENTER_METERS: float = 3.4
const EXIT_METERS: float = 4.0
const FADE_SECONDS: float = 0.25
var _map: Node3D
var _stall: Node3D
var _labels: Array[Label3D] = []
var _originals: Array[Dictionary] = []
var _fonts: Array[Font] = []
var _signatures: Array[String] = []
var _camera: Camera3D
var _pending: Node3D
var _pending_frames: int = 0
var _title_wait: int = 0
var _title_units: AABB
var _limited_reason: String = ""
var _target_visible: bool = false
var _weight: float = 0.0
var _distance_m: float = 0.0


func _init() -> void:
	process_priority = 100
	set_process(false)


func _ready() -> void:
	set_process(name == &"CoreShopDistanceLegibility" and get_parent() == get_tree().root)


func _process(delta: float) -> void:
	var current: Node3D = get_tree().current_scene as Node3D
	if is_instance_valid(_map) and current == _map:
		update_for_camera(get_viewport().get_camera_3d(), delta)
		return
	if not _labels.is_empty():
		restore_shop()
	if not _valid_map(current) or not current.has_node(^"ShopTypography"):
		_pending = null
		return
	if _pending != current:
		_pending = current
		_pending_frames = 2
		return
	_pending_frames -= 1
	if _pending_frames <= 0 and bind_shop(current):
		update_for_camera(get_viewport().get_camera_3d(), delta)


func _valid_map(map: Node3D) -> bool:
	return is_instance_valid(map) and map.is_inside_tree() and map.is_node_ready() and not map.is_queued_for_deletion() and map == get_tree().current_scene and map.name == &"MapPraia" and map.scene_file_path == MAP_PATH


func bind_shop(target: Node3D) -> bool:
	if not _valid_map(target):
		return false
	var stall: Node3D = target.get_node_or_null(^"Banca") as Node3D
	if stall == null:
		return false
	var labels: Array[Label3D] = []
	for path: NodePath in OFFER_PATHS:
		var offer: ShopOffer = target.get_node_or_null(path) as ShopOffer
		if offer == null or offer.get_parent() != stall:
			return false
		var direct: Array[Label3D] = []
		for child: Node in offer.get_children():
			if child is Label3D:
				direct.append(child as Label3D)
		if direct.size() != 1 or direct[0].fixed_size:
			return false
		labels.append(direct[0])
	var title: Label3D = target.get_node_or_null(^"Banca/Label") as Label3D
	if title == null:
		return false
	labels.append(title)
	for label: Label3D in labels:
		if not label.is_node_ready() or label.is_queued_for_deletion() or label.text.strip_edges().is_empty() or label.pixel_size <= 0.0 or label.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
			return false
	if _map == target and _labels == labels:
		return true
	var fonts: Array[Font] = []
	var cache: Dictionary = {}
	for index: int in labels.size():
		var font: Font = _private_font(labels[index].font, cache, true)
		if font == null:
			return false
		fonts.append(font)
	# All five targets and private fonts are ready before any target is changed.
	restore_shop()
	_map = target
	_stall = stall
	_labels = labels
	_fonts = fonts
	for index: int in _labels.size():
		var label: Label3D = _labels[index]
		_originals.append({"transform": label.transform, "global_transform": label.global_transform, "offset": label.offset, "font": label.font, "pixel": label.pixel_size, "outline": label.outline_size, "filter": label.texture_filter, "visible": label.visible, "modulate": label.modulate, "outline_modulate": label.outline_modulate, "aabb": label.get_aabb(), "fixed": label.fixed_size, "depth": label.no_depth_test, "billboard": label.billboard})
		label.font = _fonts[index]
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		if index < 4:
			var color: Color = label.modulate
			color.a = 0.0
			label.modulate = color
			var outline_color: Color = label.outline_modulate
			outline_color.a = 0.0
			label.outline_modulate = outline_color
			label.hide()
		_signatures.append(_signature(label))
	_title_wait = 2  # Wait for deferred font shaping before caching title geometry.
	return true


func _private_font(font: Font, cache: Dictionary, raster: bool) -> Font:
	if font == null:
		return null
	# The same source may serve products and LOJA; never share their render cache.
	var key: String = "%d|%s" % [font.get_instance_id(), str(raster)]
	if cache.has(key):
		return cache[key] as Font
	if font is FontVariation:
		var source: FontVariation = font as FontVariation
		var base: Font = _private_font(source.base_font, cache, raster)
		if base == null:
			return null
		var variation: FontVariation = source.duplicate(false) as FontVariation
		variation.base_font = base
		cache[key] = variation
		return variation
	if font is FontFile:
		var source: FontFile = font as FontFile
		if source.data.is_empty():
			return null
		var file: FontFile = FontFile.new()
		file.data = source.data
		file.antialiasing = source.antialiasing
		file.hinting = source.hinting
		file.subpixel_positioning = source.subpixel_positioning
		file.allow_system_fallback = source.allow_system_fallback
		file.fallbacks = source.fallbacks
		file.multichannel_signed_distance_field = not raster
		if raster:
			file.oversampling = 2.0
		file.msdf_size = 48
		file.msdf_pixel_range = 16
		cache[key] = file
		return file
	return null


func _signature(label: Label3D) -> String:
	return "%s|%d|%s|%d" % [label.text, label.font_size, label.width, label.autowrap_mode]


func _bound_valid() -> bool:
	if not _valid_map(_map) or not is_instance_valid(_stall) or _labels.size() != 5:
		return false
	for index: int in 5:
		var label: Label3D = _labels[index]
		if not is_instance_valid(label) or label.is_queued_for_deletion() or not _map.is_ancestor_of(label) or label.font != _fonts[index] or _signature(label) != _signatures[index]:
			return false
	return true


func _baseline(label: Label3D, camera: Camera3D) -> float:
	return 0.0032 * minf(1.0, camera.global_position.distance_to(label.global_position) / 2.8)


func update_for_camera(camera: Camera3D, delta: float) -> void:
	if _labels.is_empty():
		return
	if not _bound_valid():
		restore_shop()
		return
	if not is_instance_valid(camera) or not camera.is_inside_tree() or camera.get_viewport() != _map.get_viewport() or camera.projection != Camera3D.PROJECTION_PERSPECTIVE:
		return
	_camera = camera
	_limited_reason = ""
	_distance_m = Vector2(camera.global_position.x - _stall.global_position.x, camera.global_position.z - _stall.global_position.z).length()
	if _target_visible:
		if _distance_m >= EXIT_METERS:
			_target_visible = false
	elif _distance_m <= ENTER_METERS:
		_target_visible = true
	_weight = move_toward(_weight, 1.0 if _target_visible else 0.0, maxf(delta, 0.0) / FADE_SECONDS)
	for index: int in 4:
		var label: Label3D = _labels[index]
		label.pixel_size = _baseline(label, camera)
		var color: Color = label.modulate
		var original_color: Color = _originals[index]["modulate"]
		# ShopOffer may write yellow/white alpha1. Keep its RGB, not its alpha reset.
		color.a = original_color.a * _weight
		label.modulate = color
		var outline_color: Color = label.outline_modulate
		var original_outline_color: Color = _originals[index]["outline_modulate"]
		outline_color.a = original_outline_color.a * _weight
		label.outline_modulate = outline_color
		label.visible = bool(_originals[index]["visible"]) and _weight > 0.0
	var title: Label3D = _labels[4]
	var pixel: float = _originals[4]["pixel"]
	if _title_wait > 0:
		_title_wait -= 1
		if _title_wait > 0:
			return
		var box: AABB = title.get_aabb()
		_title_units = AABB(box.position / pixel, box.size / pixel)
	var transform: Transform3D = _render_transform(title, camera, title.global_transform, title.fixed_size)
	var pad: Vector3 = Vector3(float(title.outline_size), float(title.outline_size), 0.0)
	var ink: AABB = AABB((_title_units.position - pad) * pixel, (_title_units.size + pad * 2.0) * pixel)
	var bottom: float = _world_box(transform, ink).position.y
	var vertical: float = transform.basis.y.y * pixel
	var offset: Vector2 = _originals[4]["offset"]
	if bottom < _stall.global_position.y + 3.20:
		if absf(vertical) < 0.000001:
			_limited_reason = "title_vertical_projection"
		else:
			offset.y += (_stall.global_position.y + 3.2001 - bottom) / vertical
	title.offset = offset


func _render_transform(label: Label3D, camera: Camera3D, initial: Transform3D, fixed: bool) -> Transform3D:
	var result: Transform3D = initial
	var basis: Basis = camera.global_basis.orthonormalized()
	var scale: Vector3 = initial.basis.get_scale()
	if label.billboard == BaseMaterial3D.BILLBOARD_ENABLED:
		result.basis = Basis(basis.x * scale.x, basis.y * scale.y, basis.z * scale.z)
	if fixed:
		var depth: float = -(camera.global_transform.affine_inverse() * initial.origin).z
		result.basis = result.basis.scaled(Vector3.ONE * depth)
	return result


func _world_box(transform: Transform3D, box: AABB) -> AABB:
	var result: AABB = AABB(transform * box.get_endpoint(0), Vector3.ZERO)
	for corner: int in range(1, 8):
		result = result.expand(transform * box.get_endpoint(corner))
	return result


func _project_box(camera: Camera3D, transform: Transform3D, box: AABB) -> Array[float]:
	var rect: Rect2 = Rect2()
	for corner: int in 8:
		var point: Vector2 = camera.unproject_position(transform * box.get_endpoint(corner))
		rect = Rect2(point, Vector2.ZERO) if corner == 0 else rect.expand(point)
	var scale: Vector2 = Vector2(camera.get_window().size) / camera.get_viewport().get_visible_rect().size
	return [rect.position.x * scale.x, rect.position.y * scale.y, rect.size.x * scale.x, rect.size.y * scale.y]


func restore_shop() -> void:
	for index: int in _labels.size():
		var label: Label3D = _labels[index]
		if not is_instance_valid(label) or label.is_queued_for_deletion():
			continue
		var original: Dictionary = _originals[index]
		label.transform = original["transform"]
		label.offset = original["offset"]
		label.font = original["font"]
		label.pixel_size = original["pixel"]
		label.outline_size = original["outline"]
		label.texture_filter = original["filter"]
		label.visible = original["visible"]
		var color: Color = label.modulate
		var original_color: Color = original["modulate"]
		color.a = original_color.a
		label.modulate = color
		var outline_color: Color = label.outline_modulate
		var original_outline_color: Color = original["outline_modulate"]
		outline_color.a = original_outline_color.a
		label.outline_modulate = outline_color
	_map = null
	_stall = null
	_camera = null
	_pending = null
	_labels.clear()
	_originals.clear()
	_fonts.clear()
	_signatures.clear()
	_title_wait = 0
	_limited_reason = ""
	_target_visible = false
	_weight = 0.0
	_distance_m = 0.0


func get_individual_snapshot() -> Dictionary:
	var labels: Array[Dictionary] = []
	for index: int in _labels.size():
		var label: Label3D = _labels[index]
		if not is_instance_valid(label):
			continue
		var original: Dictionary = _originals[index]
		var box: AABB = label.get_aabb()
		var state: Dictionary = {"role": "Offer%d" % (index + 1) if index < 4 else "LOJA", "path": String(label.get_path()), "text": label.text, "font": _font_snapshot(label.font), "font_size": label.font_size, "pixel_size": label.pixel_size, "filter": label.texture_filter, "outline_size": label.outline_size, "scale": _v3(label.scale), "global_scale": _v3(label.global_basis.get_scale()), "offset": [label.offset.x, label.offset.y], "position": _v3(label.position), "global_position": _v3(label.global_position), "transform": _transform_snapshot(label.transform), "visible": label.visible, "is_visible_in_tree": label.is_visible_in_tree(), "billboard": label.billboard, "fixed_size": label.fixed_size, "no_depth_test": label.no_depth_test, "local_aabb": _box_snapshot(box)}
		state["modulate"] = [label.modulate.r, label.modulate.g, label.modulate.b, label.modulate.a]
		state["alpha"] = label.modulate.a
		var before: Transform3D = original["transform"]
		var before_offset: Vector2 = original["offset"]
		state["original"] = {"font": _font_snapshot(original["font"]), "pixel_size": original["pixel"], "filter": original["filter"], "outline_size": original["outline"], "scale": _v3(before.basis.get_scale()), "offset": [before_offset.x, before_offset.y], "transform": _transform_snapshot(before), "local_aabb": _box_snapshot(original["aabb"])}
		var original_color: Color = original["modulate"]
		state["original"]["modulate"] = [original_color.r, original_color.g, original_color.b, original_color.a]
		if is_instance_valid(_camera):
			var rendered: Transform3D = _render_transform(label, _camera, label.global_transform, label.fixed_size)
			var pad: Vector3 = Vector3(float(label.outline_size), float(label.outline_size), 0.0) * label.pixel_size
			state["bounds_physical"] = _project_box(_camera, rendered, box)
			state["world_ink_aabb"] = _box_snapshot(_world_box(rendered, AABB(box.position - pad, box.size + pad * 2.0)))
			state["baseline_pixel_size"] = _baseline(label, _camera) if index < 4 else original["pixel"]
			state["original"]["bounds_physical"] = _project_box(_camera, _render_transform(label, _camera, original["global_transform"], original["fixed"]), original["aabb"])
		labels.append(state)
	var pose: Dictionary = {}
	if is_instance_valid(_camera):
		pose = {"position": _v3(_camera.global_position), "rotation": _v3(_camera.global_rotation), "basis": _transform_snapshot(_camera.global_transform)["basis"], "fov": _camera.fov, "window_size": [_camera.get_window().size.x, _camera.get_window().size.y], "viewport_size": [_camera.get_viewport().get_visible_rect().size.x, _camera.get_viewport().get_visible_rect().size.y]}
	return {"bound": is_instance_valid(_map), "bound_to_current_scene": is_instance_valid(_map) and _map == get_tree().current_scene, "labels": labels, "pose": pose, "target_visible": _target_visible, "weight": _weight, "distance_m": _distance_m, "enter_m": ENTER_METERS, "exit_m": EXIT_METERS, "fade_seconds": FADE_SECONDS, "shaping_pending": _title_wait > 0, "limited_reason": _limited_reason, "bounds_method": "cached glyph AABB plus conservative outline; QA images decide reading"}


func get_proximity_snapshot() -> Dictionary:
	return get_individual_snapshot()


func _font_snapshot(font: Font) -> Dictionary:
	var base: Font = font
	while base is FontVariation:
		base = (base as FontVariation).base_font
	var file: FontFile = base as FontFile
	return {"class": font.get_class() if font != null else "", "resource": font.resource_path if font != null else "", "base_class": base.get_class() if base != null else "", "msdf": file.multichannel_signed_distance_field if file != null else false, "msdf_size": file.msdf_size if file != null else 0, "msdf_pixel_range": file.msdf_pixel_range if file != null else 0, "antialiasing": file.antialiasing if file != null else -1, "hinting": file.hinting if file != null else -1}


func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _transform_snapshot(value: Transform3D) -> Dictionary:
	return {"origin": _v3(value.origin), "basis": [_v3(value.basis.x), _v3(value.basis.y), _v3(value.basis.z)]}


func _box_snapshot(value: AABB) -> Dictionary:
	return {"position": _v3(value.position), "size": _v3(value.size)}


func _exit_tree() -> void:
	restore_shop()
