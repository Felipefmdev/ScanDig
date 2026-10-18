extends GutTest

## Abas da Base (Loja, Museu, Expedições, Diário, Mapa): rótulos curtos que cabem na TabBar sem
## setas, também com o ui_scale de vídeo no máximo (1.3); os nós mantêm os nomes completos (caminhos
## do _resolve_node e ui_tab dos bots), que viram a dica da aba; LB/RB continuam a trocar de aba.

const BASE_STATION_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const PAGE_NAMES: Array[String] = ["Loja de Equipamentos", "Museu de Achados", "Expedições", "Diário", "Mapa do Tesouro"]
const SHORT_TITLES: Array[String] = ["Loja", "Museu", "Expedições", "Diário", "Mapa"]

var ui: BaseStationUI = null


func before_each() -> void:
	GameState.instance.reset_state()
	ui = BASE_STATION_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)
	await wait_frames(3)


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	GameState.instance.reset_state()


func _assert_tabs_fit(where: String) -> void:
	var bar: TabBar = ui.tab_container.get_tab_bar()
	var total: float = 0.0
	for i: int in bar.tab_count:
		var r: Rect2 = bar.get_tab_rect(i)
		total += r.size.x
		assert_gt(r.size.x, 0.0, "%s: aba %d com largura" % [where, i])
		assert_true(r.position.x >= 0.0 and r.end.x <= bar.size.x + 0.5, "%s: aba %s dentro da TabBar (%s)" % [where, bar.get_tab_title(i), r])
	assert_lt(total, bar.size.x, "%s: soma das abas (%.0f) cabe na TabBar (%.0f)" % [where, total, bar.size.x])
	assert_false(bar.get_offset_buttons_visible(), "%s: sem setas" % where)
	assert_eq(bar.get_tab_offset(), 0, "%s: nenhuma aba fora da vista" % where)


func test_titles_short_names_kept() -> void:
	var tabs: TabContainer = ui.tab_container
	assert_eq(tabs.get_tab_count(), PAGE_NAMES.size())
	for i: int in tabs.get_tab_count():
		assert_eq(String(tabs.get_tab_control(i).name), PAGE_NAMES[i], "nó com o nome antigo")
		assert_eq(tabs.get_tab_title(i), SHORT_TITLES[i])
		assert_eq(tabs.get_tab_bar().get_tab_tooltip(i), PAGE_NAMES[i], "dica com o nome completo")
	assert_not_null(ui.museum_item_list, "caminhos do _resolve_node continuam a valer")
	assert_not_null(ui.buy_detector_btn)


func test_tabs_fit_on_every_tab() -> void:
	for i: int in ui.tab_container.get_tab_count():
		ui.tab_container.current_tab = i
		await wait_frames(2)
		_assert_tabs_fit("aba %d" % i)


func test_tabs_fit_with_ui_scale_130() -> void:
	get_tree().root.content_scale_factor = 1.3
	ui.tab_container.current_tab = ui.tab_container.get_tab_count() - 1
	await wait_frames(3)
	_assert_tabs_fit("ui_scale 1.3, última aba")


func test_museum_star_keeps_short_title() -> void:
	GameState.instance.game_completed = true
	ui._refresh_museum_display()
	assert_eq(ui.tab_container.get_tab_title(1), "Museu ★")
	await wait_frames(2)
	_assert_tabs_fit("museu concluído")


func test_lb_rb_still_switch_tabs() -> void:
	var tabs: TabContainer = ui.tab_container
	tabs.current_tab = 0
	var rb: InputEventJoypadButton = InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	var lb: InputEventJoypadButton = InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb.pressed = true
	ui._unhandled_input(rb)
	assert_eq(tabs.current_tab, 1, "RB: próxima aba")
	ui._unhandled_input(lb)
	ui._unhandled_input(lb)
	assert_eq(tabs.current_tab, tabs.get_tab_count() - 1, "LB volta e dá a volta para o Mapa")
	await wait_frames(2)
	_assert_tabs_fit("depois do LB")
