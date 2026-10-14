class_name HUD
extends CanvasLayer

## HUD principal exibindo recursos da equipe, detector e museu.

@onready var money_label: Label = _resolve_label("MoneyLabel", "MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MoneyLabel")
@onready var detector_label: Label = _resolve_label("DetectorLabel", "MarginContainer/PanelContainer/MarginContainer/VBoxContainer/DetectorLabel")
@onready var museum_label: Label = _resolve_label("MuseumLabel", "MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MuseumLabel")

var _game_state: GameState = null


func _resolve_label(unique_id: String, rel_path: String) -> Label:
	if has_node("%" + unique_id):
		return get_node("%" + unique_id) as Label
	if has_node(rel_path):
		return get_node(rel_path) as Label
	var found: Node = find_child(unique_id, true, false)
	return found as Label if found is Label else null


func _ready() -> void:
	_resolve_game_state()


func _resolve_game_state() -> void:
	if GameState.instance != null:
		_game_state = GameState.instance
	elif get_tree().root.has_node("GameState"):
		_game_state = get_tree().root.get_node("GameState") as GameState
	
	if _game_state != null:
		if not _game_state.money_changed.is_connected(_on_money_changed):
			_game_state.money_changed.connect(_on_money_changed)
		if not _game_state.collection_updated.is_connected(_on_collection_updated):
			_game_state.collection_updated.connect(_on_collection_updated)
		if not _game_state.upgrades_changed.is_connected(_on_upgrades_changed):
			_game_state.upgrades_changed.connect(_on_upgrades_changed)
		
		# Atualizar valores iniciais
		update_money(_game_state.team_money)
		update_detector(_game_state.equipped_detector_level)
		update_museum(_game_state.discovered_items.size(), _game_state.get_total_catalog_items())
	else:
		# Valores padrão de fallback
		update_money(100)
		update_detector(1)
		update_museum(0, 10)


func update_money(new_amount: int) -> void:
	if money_label != null:
		money_label.text = "Equipe: R$ %d" % new_amount


func update_detector(level: int) -> void:
	if detector_label != null:
		detector_label.text = "Detector: Nível %d" % level


func update_museum(total_found: int, max_items: int) -> void:
	if museum_label != null:
		museum_label.text = "Museu: %d/%d descobertos" % [total_found, max_items]


func _on_money_changed(new_amount: int) -> void:
	update_money(new_amount)


func _on_upgrades_changed(_levels: Dictionary) -> void:
	if _game_state != null:
		update_detector(_game_state.equipped_detector_level)


func _on_collection_updated(total_found: int, max_items: int) -> void:
	update_museum(total_found, max_items)
