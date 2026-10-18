extends GutTest

## "Ver museu" no lobby: a câmera começa na tenda; o botão da aba Museu leva a câmera (Tween) até a
## vitrine, esconde os painéis da Base e deixa só o "Voltar"; Voltar ou Esc/B (ui_cancel) trazem a
## câmera de volta, os painéis voltam e o foco volta ao botão.

const LOBBY_SCENE: PackedScene = preload("res://world/lobby_base.tscn")
## Câmera da tenda (a de antes da #111).
const TENT_TRANSFORM: Transform3D = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.965926, -0.258819), Vector3(0, 0.258819, 0.965926)), Vector3(0, 3.5, 9))
const EPS: float = 0.01

var lobby: Node3D = null
var view: MuseumView = null
var base: BaseStationUI = null
var camera: Camera3D = null
var ui_layer: CanvasLayer = null


func before_each() -> void:
	GameState.instance.reset_state()
	lobby = LOBBY_SCENE.instantiate() as Node3D
	add_child_autofree(lobby)
	view = lobby.get_node("MuseumView") as MuseumView
	base = lobby.get_node("UILayer/BaseStationUI") as BaseStationUI
	camera = lobby.get_node("Camera3D") as Camera3D
	ui_layer = lobby.get_node("UILayer") as CanvasLayer
	await wait_frames(4)


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	GameState.instance.reset_state()


func _close_to(a: Transform3D, b: Transform3D) -> bool:
	return a.origin.distance_to(b.origin) < EPS and a.basis.z.distance_to(b.basis.z) < EPS and a.basis.y.distance_to(b.basis.y) < EPS


func _cancel() -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	get_viewport().push_input(ev)


func test_camera_starts_at_tent() -> void:
	assert_true(_close_to(camera.transform, TENT_TRANSFORM), "câmera na tenda: %s" % camera.transform)
	assert_false(view.is_open())
	assert_false(view.back_button.visible, "Voltar só aparece na vista do museu")
	assert_true(base.view_museum_btn.visible, "com MuseumView na cena, o botão aparece")


func test_round_trip_with_back_button() -> void:
	base.tab_container.current_tab = 1
	await wait_frames(2)
	base.view_museum_btn.pressed.emit()
	assert_true(view.is_open())
	assert_false(ui_layer.visible, "painéis da Base escondidos")
	assert_true(view.back_button.visible, "só o Voltar")
	await wait_seconds(MuseumView.TWEEN_TIME + 0.2)
	assert_true(_close_to(camera.global_transform, view.get_view_transform()), "câmera na frente da vitrine")
	assert_true(view.back_button.has_focus(), "foco no Voltar (teclado e controle)")
	var museum: Node3D = lobby.get_node("MuseumDisplay") as Node3D
	var to_museum: Vector3 = (museum.global_position + Vector3(0, 1, 0) - camera.global_position).normalized()
	assert_gt(-camera.global_basis.z.dot(to_museum), 0.9, "olhando para a estante")

	view.back_button.pressed.emit()
	assert_false(view.is_open())
	assert_true(ui_layer.visible, "painéis de volta")
	assert_false(view.back_button.visible)
	assert_true(base.view_museum_btn.has_focus(), "foco de volta no Ver museu")
	await wait_seconds(MuseumView.TWEEN_TIME + 0.2)
	assert_true(_close_to(camera.transform, TENT_TRANSFORM), "câmera de volta à tenda")


func test_ui_cancel_returns_without_pause_menu() -> void:
	view.open()
	await wait_seconds(0.2)
	_cancel()
	await wait_frames(2)
	assert_false(view.is_open(), "Esc/B voltam")
	assert_true(ui_layer.visible)
	assert_false(PauseMenu.is_open(), "Esc na vista do museu não abre a pausa")
	await wait_seconds(MuseumView.TWEEN_TIME + 0.2)
	assert_true(_close_to(camera.transform, TENT_TRANSFORM))


func test_cancel_when_closed_is_ignored() -> void:
	view.close()
	assert_false(view.is_open())
	assert_true(ui_layer.visible)
	assert_true(_close_to(camera.transform, TENT_TRANSFORM))

