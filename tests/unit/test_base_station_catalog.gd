extends GutTest

## #69: BaseStationUI com catálogo ausente ou vazio avisa no Museu sem quebrar a Loja.

const SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")


func _spawn(dir: String) -> BaseStationUI:
	var ui: BaseStationUI = SCENE.instantiate() as BaseStationUI
	ui.catalog_dir = dir
	add_child_autofree(ui)
	return ui


func test_default_catalog_loads_items() -> void:
	var ui: BaseStationUI = _spawn("res://items/catalog")
	assert_gt(ui.item_select_box.item_count, 0, "catálogo real popula o seletor")
	assert_false(ui.sell_item_btn.disabled, "vender ativo com catálogo")


func test_missing_catalog_shows_message_and_disables_museum_buttons() -> void:
	var ui: BaseStationUI = _spawn("res://items/catalog_que_nao_existe")
	assert_eq(ui.item_select_box.item_count, 0, "seletor vazio")
	assert_string_contains(ui.museum_feedback_label.text, "indisponível")
	assert_true(ui.sell_item_btn.disabled, "vender travado")
	assert_true(ui.register_item_btn.disabled, "registrar travado")
	assert_not_null(ui.buy_detector_btn, "loja segue montada")


func test_empty_catalog_shows_message() -> void:
	# Pasta existente sem nenhum ItemData.
	var ui: BaseStationUI = _spawn("res://tests/unit")
	assert_string_contains(ui.museum_feedback_label.text, "vazio")
	assert_true(ui.sell_item_btn.disabled, "vender travado")
