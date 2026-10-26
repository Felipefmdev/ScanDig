extends GutTest

const BASE: PackedScene = preload("res://ui/base_station_ui.tscn")
var _snapshot: Dictionary = {}


func before_each() -> void:
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()


func after_each() -> void:
	GameState.instance.load_snapshot(_snapshot)


func _base() -> BaseStationUI:
	var base: BaseStationUI = BASE.instantiate() as BaseStationUI
	add_child_autofree(base)
	return base


func test_hub_menu_has_no_accessible_equipment_shop() -> void:
	var base: BaseStationUI = _base()
	assert_not_null(base.tab_container)
	for index: int in base.tab_container.get_tab_count():
		var page: Control = base.tab_container.get_tab_control(index)
		if String(page.name).begins_with("Loja"):
			assert_true(base.tab_container.is_tab_hidden(index), "shop must not be a hub tab")
			assert_false(page.is_visible_in_tree(), "hidden shop cannot receive navigation")


func test_closed_routes_only_describe_world_progression_without_price_or_detector_gate() -> void:
	var base: BaseStationUI = _base()
	base.map_list.select(1)
	base.map_list.item_selected.emit(1)
	assert_false(base.unlock_map_btn.visible, "no menu purchase/unlock button")
	for index: int in base.map_list.item_count:
		var text: String = base.map_list.get_item_text(index)
		assert_false(text.contains("R$"), "map list does not advertise an entry fee: " + text)
		assert_false(text.contains("Detector nível"), "equipment is not an entrance gate: " + text)
	GameState.instance.defeated_bosses = ["king_crab"]
	base._refresh_map_list()
	assert_false(GameState.instance.is_map_unlocked("campo"), "boss alone is not first passage use")
	assert_false(base.unlock_map_btn.visible)


func test_legacy_open_route_can_be_revisited_with_baseline_detector() -> void:
	GameState.instance.unlocked_maps = ["campo"]
	var base: BaseStationUI = _base()
	base.map_list.select(1)
	base.map_list.item_selected.emit(1)
	assert_eq(GameState.instance.equipped_detector_level, 1)
	assert_false(base.depart_btn.disabled, "permanent legacy route remains revisitable")
	assert_false(base.unlock_map_btn.visible)
