extends GutTest

## Hotbar de 8 slots (mochila no máximo) não encosta na mão do viewmodel: o retângulo da hotbar
## fica a pelo menos MIN_GAP da projeção na tela da mão (HandModel visível sob a câmara), com
## ui_scale 1.0 e 1.3. 960x540 e 1920x1080 têm o mesmo tamanho base (16:9, stretch expand).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
## Margem mínima (px do HUD) entre a hotbar e a mão.
const MIN_GAP: float = 8.0

## [janela, ui_scale, slot na mão (6 = detector, 7 = estilingue)]
const CASES: Array = [
	[Vector2i(960, 540), 1.0, 6], [Vector2i(960, 540), 1.0, 7],
	[Vector2i(960, 540), 1.3, 6], [Vector2i(960, 540), 1.3, 7],
	[Vector2i(1920, 1080), 1.0, 6], [Vector2i(1920, 1080), 1.0, 7],
	[Vector2i(1920, 1080), 1.3, 6], [Vector2i(1920, 1080), 1.3, 7],
]

var _player: Node3D = null
var _old_size: Vector2i = Vector2i.ZERO


## Retângulo (coordenadas do HUD) que cobre as malhas das mãos visíveis sob a câmara.
static func viewmodel_rect(cam: Camera3D) -> Rect2:
	var out: Rect2 = Rect2()
	var first: bool = true
	for hand: Node in cam.find_children("*", "Node3D", true, false):
		if not hand is HandModel:
			continue
		for mi: Node in hand.find_children("*", "VisualInstance3D", true, false):
			var vi: VisualInstance3D = mi as VisualInstance3D
			if vi == null or not vi.is_visible_in_tree():
				continue
			var box: AABB = vi.global_transform * vi.get_aabb()
			for i: int in 8:
				var p: Vector3 = box.get_endpoint(i)
				if cam.is_position_behind(p):
					continue
				var q: Vector2 = cam.unproject_position(p)
				if first:
					out = Rect2(q, Vector2.ZERO)
					first = false
				else:
					out = out.expand(q)
	return out


## Distância entre dois retângulos (negativa se se sobrepõem).
static func gap(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(a.position.x - b.end.x, b.position.x - a.end.x)
	var dy: float = maxf(a.position.y - b.end.y, b.position.y - a.end.y)
	return maxf(dx, dy)


func before_each() -> void:
	_old_size = get_tree().root.size
	_player = PLAYER_SCENE.instantiate() as Node3D
	add_child_autofree(_player)
	await wait_frames(2)
	var inv: Inventory = _player.get("inventory") as Inventory
	inv.capacity = 8
	for i: int in 6:
		inv.add_item(CarriedItem.create(load("res://items/catalog/moeda_antiga.tres") as ItemData, 10, 1.0, false))
	inv.add_item(CarriedItem.create_tool(&"detector", "Detector"))
	inv.add_item(CarriedItem.create_from_tool_data(load("res://items/tools/estilingue.tres") as ToolData))


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	get_tree().root.size = _old_size


## `slot` na mão (6 = detector, 7 = estilingue), na janela `res` com ui_scale `scale`.
func _check(res: Vector2i, scale: float, slot: int) -> void:
	get_tree().root.size = res
	get_tree().root.content_scale_factor = scale
	(_player.get("inventory") as Inventory).select(slot)
	await wait_frames(3)
	var bar: Control = _player.get_node(^"HUD/Hotbar") as Control
	assert_eq(bar.get_child_count(), 8, "8 slots")
	var cam: Camera3D = _player.get_node(^"Head/Camera3D") as Camera3D
	var hand: Rect2 = viewmodel_rect(cam)
	assert_true(hand.has_area(), "a mão aparece na tela")
	var view: Rect2 = get_tree().root.get_visible_rect()
	var r: Rect2 = bar.get_global_rect()
	var what: String = "%s ui %.1f slot %d" % [res, scale, slot]
	assert_true(view.encloses(r), "%s: hotbar %s dentro da tela %s" % [what, r, view])
	var g: float = gap(r, hand)
	assert_gte(g, MIN_GAP, "%s: hotbar %s, mão %s (folga %.1f)" % [what, r, hand, g])


func test_hotbar_clears_hand(params: Array = use_parameters(CASES)) -> void:
	await _check(params[0], params[1], params[2])
