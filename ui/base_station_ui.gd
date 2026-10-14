class_name BaseStationUI
extends Control

## Painel da Base/Tenda contendo Loja de Equipamentos e Museu de Achados.

@onready var tab_container: TabContainer = _resolve_node("TabContainer", "PanelContainer/MarginContainer/VBoxContainer/TabContainer") as TabContainer

# Loja
@onready var buy_detector_btn: Button = _resolve_node("BuyDetectorButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyDetectorButton") as Button
@onready var buy_pinpointer_btn: Button = _resolve_node("BuyPinpointerButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyPinpointerButton") as Button
@onready var buy_shovel_btn: Button = _resolve_node("BuyShovelButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/BuyShovelButton") as Button
@onready var shop_feedback_label: Label = _resolve_node("ShopFeedbackLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Loja de Equipamentos/ShopFeedbackLabel") as Label

# Museu
@onready var museum_item_list: ItemList = _resolve_node("MuseumItemList", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/MuseumItemList") as ItemList
@onready var item_select_box: OptionButton = _resolve_node("ItemSelectBox", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/ItemSelectBox") as OptionButton
@onready var sell_item_btn: Button = _resolve_node("SellItemButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/SellItemButton") as Button
@onready var register_item_btn: Button = _resolve_node("RegisterItemButton", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/HBoxContainer/RegisterItemButton") as Button
@onready var museum_feedback_label: Label = _resolve_node("MuseumFeedbackLabel", "PanelContainer/MarginContainer/VBoxContainer/TabContainer/Museu de Achados/MuseumFeedbackLabel") as Label

var _game_state: GameState = null
var _catalog_items: Array[ItemData] = []
var _pending_purchase: bool = false

const SHOP_BUTTONS: Array[String] = ["detector", "pinpointer", "shovel"]


func _resolve_node(unique_id: String, rel_path: String) -> Node:
	if has_node("%" + unique_id):
		return get_node("%" + unique_id)
	if has_node(rel_path):
		return get_node(rel_path)
	return find_child(unique_id, true, false)


func _ready() -> void:
	_load_catalog()
	_setup_shop_buttons()
	_setup_museum_controls()
	_resolve_game_state()


func _resolve_game_state() -> void:
	if GameState.instance != null:
		_game_state = GameState.instance
	elif get_tree().root.has_node("GameState"):
		_game_state = get_tree().root.get_node("GameState") as GameState
	
	if _game_state != null:
		if not _game_state.money_changed.is_connected(_on_state_updated):
			_game_state.money_changed.connect(_on_state_updated)
		if not _game_state.collection_updated.is_connected(_on_collection_updated):
			_game_state.collection_updated.connect(_on_collection_updated)
		if not _game_state.item_sold.is_connected(_on_item_sold):
			_game_state.item_sold.connect(_on_item_sold)
		if not _game_state.item_donated.is_connected(_on_item_donated):
			_game_state.item_donated.connect(_on_item_donated)
		if not _game_state.upgrades_changed.is_connected(_on_upgrades_changed):
			_game_state.upgrades_changed.connect(_on_upgrades_changed)
		if not _game_state.purchase_result.is_connected(_on_purchase_result):
			_game_state.purchase_result.connect(_on_purchase_result)
	
	_refresh_museum_display()
	_refresh_shop_buttons()


func _load_catalog() -> void:
	_catalog_items.clear()
	var dir: DirAccess = DirAccess.open("res://items/catalog")
	if dir == null:
		push_error("BaseStationUI: Não foi possível abrir res://items/catalog")
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var clean_name: String = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				var full_path: String = "res://items/catalog/%s" % clean_name
				var res: Resource = ResourceLoader.load(full_path)
				if res is ItemData:
					_catalog_items.append(res as ItemData)
		file_name = dir.get_next()
	
	# Ordena pelo nome para exibição consistente
	_catalog_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return a.display_name < b.display_name
	)


func _setup_shop_buttons() -> void:
	for upgrade_id: String in SHOP_BUTTONS:
		var btn: Button = _get_shop_button(upgrade_id)
		if btn != null:
			btn.pressed.connect(_purchase_upgrade.bind(upgrade_id))


func _get_shop_button(upgrade_id: String) -> Button:
	match upgrade_id:
		"detector":
			return buy_detector_btn
		"pinpointer":
			return buy_pinpointer_btn
		"shovel":
			return buy_shovel_btn
	return null


func _refresh_shop_buttons() -> void:
	if _game_state == null:
		return
	for upgrade_id: String in SHOP_BUTTONS:
		var btn: Button = _get_shop_button(upgrade_id)
		if btn == null:
			continue
		var display_name: String = GameState.UPGRADES[upgrade_id]["name"]
		var level: int = _game_state.get_upgrade_level(upgrade_id)
		var max_level: int = _game_state.get_upgrade_max_level(upgrade_id)
		var cost: int = _game_state.get_next_upgrade_cost(upgrade_id)
		if cost < 0:
			btn.text = "%s — MÁXIMO (%d/%d)" % [display_name, level, max_level]
			btn.disabled = true
		else:
			btn.text = "Comprar %s (%d/%d) — R$ %d" % [display_name, level, max_level, cost]
			btn.disabled = _pending_purchase


func _setup_museum_controls() -> void:
	if item_select_box != null:
		item_select_box.clear()
		for i in range(_catalog_items.size()):
			var item: ItemData = _catalog_items[i]
			item_select_box.add_item("%s (R$ %d)" % [item.display_name, item.base_value], i)
	
	if sell_item_btn != null:
		sell_item_btn.pressed.connect(_on_sell_test_pressed)
	if register_item_btn != null:
		register_item_btn.pressed.connect(_on_register_test_pressed)


func _purchase_upgrade(upgrade_id: String) -> void:
	if _game_state == null:
		_set_shop_feedback("Erro: GameState não disponível.")
		return
	if _pending_purchase:
		return
	
	# A confirmação (ou recusa) chega pelo sinal purchase_result vindo do host.
	_pending_purchase = true
	_refresh_shop_buttons()
	_set_shop_feedback("Processando compra...")
	_game_state.request_buy_upgrade(upgrade_id)


func _on_purchase_result(_upgrade_id: String, _success: bool, message: String) -> void:
	_pending_purchase = false
	_set_shop_feedback(message)
	_refresh_shop_buttons()


func _on_upgrades_changed(_levels: Dictionary) -> void:
	_refresh_shop_buttons()


func _on_sell_test_pressed() -> void:
	var selected_item: ItemData = _get_selected_catalog_item()
	if selected_item == null or _game_state == null:
		return
	_game_state.request_sell_item(selected_item.id, selected_item.base_value)


func _on_register_test_pressed() -> void:
	var selected_item: ItemData = _get_selected_catalog_item()
	if selected_item == null or _game_state == null:
		return
	if _game_state.discovered_items.has(selected_item.id):
		_set_museum_feedback("%s já estava cadastrado no Museu!" % selected_item.display_name)
		return
	_game_state.request_donate_item(selected_item.id)


func _get_selected_catalog_item() -> ItemData:
	if item_select_box == null or _catalog_items.is_empty():
		return null
	var selected_idx: int = item_select_box.selected
	if selected_idx >= 0 and selected_idx < _catalog_items.size():
		return _catalog_items[selected_idx]
	return null


func _refresh_museum_display() -> void:
	if museum_item_list == null:
		return
	
	museum_item_list.clear()
	var discovered: Array[String] = []
	if _game_state != null:
		discovered = _game_state.discovered_items
	
	for item in _catalog_items:
		var is_found: bool = discovered.has(item.id)
		var status_str: String = "[DESCOBERTO]" if is_found else "[NÃO DESCOBERTO]"
		var text: String = "%s %s (Valor: R$ %d | Profundidade: %d cm)" % [
			status_str,
			item.display_name,
			item.base_value,
			item.depth_cm
		]
		museum_item_list.add_item(text)


func _on_state_updated(_amount: int) -> void:
	pass


func _on_collection_updated(_total_found: int, _max_items: int) -> void:
	_refresh_museum_display()


func _on_item_sold(item_name: String, value: int) -> void:
	_set_museum_feedback("Venda concluída: %s (+R$ %d)" % [item_name, value])


func _on_item_donated(item_name: String, reward: int) -> void:
	_set_museum_feedback("%s doado ao Museu! (+R$ %d de recompensa)" % [item_name, reward])


func _set_shop_feedback(msg: String) -> void:
	if shop_feedback_label != null:
		shop_feedback_label.text = msg


func _set_museum_feedback(msg: String) -> void:
	if museum_feedback_label != null:
		museum_feedback_label.text = msg
