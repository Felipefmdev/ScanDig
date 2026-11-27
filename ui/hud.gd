class_name HUD
extends CanvasLayer

## HUD principal exibindo recursos da equipe, detector e museu, um UiChip para cada (#119).

@onready var money_chip: UiChip = get_node_or_null("%MoneyChip") as UiChip
@onready var detector_chip: UiChip = get_node_or_null("%DetectorChip") as UiChip
@onready var museum_chip: UiChip = get_node_or_null("%MuseumChip") as UiChip
@onready var money_label: Label = _chip_label("MoneyChip")
@onready var detector_label: Label = _chip_label("DetectorChip")
@onready var museum_label: Label = _chip_label("MuseumChip")

var _game_state: GameState = null
var _displayed_money: float = -1.0
var _target_money: int = 0
var _money_tween: Tween = null


func _chip_label(unique_id: String) -> Label:
	var chip: UiChip = get_node_or_null("%" + unique_id) as UiChip
	return chip.label if chip != null else null


func _ready() -> void:
	_resolve_game_state()
	var chips: Array[UiChip] = [money_chip, detector_chip, museum_chip]
	for i: int in chips.size():
		if chips[i] != null:
			UiMotion.pop_in(chips[i], false, 0.95, 0.16, float(i) * 0.045)


## Idioma trocado (#131): os chips são montados por código.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _game_state != null:
		update_money(_game_state.team_money)
		update_detector(_game_state.equipped_detector_level)
		update_museum(_game_state.discovered_items.size(), _game_state.get_total_catalog_items())


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
	_target_money = new_amount
	if _money_tween != null and _money_tween.is_valid():
		_money_tween.kill()
	_money_tween = null
	_displayed_money = float(new_amount)
	if money_label != null:
		money_label.text = tr("Dinheiro  %s") % UiFormat.money(new_amount)


func _apply_interpolated_money(val: float) -> void:
	_displayed_money = val
	if money_label != null:
		money_label.text = tr("Dinheiro  %s") % UiFormat.money(int(roundf(val)))


func update_detector(level: int) -> void:
	if detector_label != null:
		detector_label.text = tr("Detector  nível %d") % level


func update_museum(total_found: int, max_items: int) -> void:
	if museum_label != null:
		museum_label.text = tr("Museu  %d/%d") % [total_found, max_items]


func _pulse_chip(chip: UiChip) -> void:
	if chip == null or not is_inside_tree() or not chip.is_visible_in_tree():
		return
	UiMotion.pulse(chip, 1.048, 0.18, false)
	if chip.icon_rect != null:
		UiMotion.pulse(chip.icon_rect, 1.16, 0.22, false)


func _on_money_changed(new_amount: int) -> void:
	if UiMotion.is_instant() or not is_inside_tree() or money_label == null or _displayed_money < 0.0 or int(roundf(_displayed_money)) == new_amount:
		update_money(new_amount)
		_pulse_chip(money_chip)
		return
	_target_money = new_amount
	if _money_tween != null and _money_tween.is_valid():
		_money_tween.kill()
	var from_val: float = _displayed_money
	_money_tween = create_tween()
	_money_tween.tween_method(_apply_interpolated_money, from_val, float(new_amount), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_money_tween.tween_callback(func() -> void:
		_displayed_money = float(_target_money)
		if money_label != null:
			money_label.text = tr("Dinheiro  %s") % UiFormat.money(_target_money))
	_pulse_chip(money_chip)


func _on_upgrades_changed(_levels: Dictionary) -> void:
	if _game_state != null:
		update_detector(_game_state.equipped_detector_level)
		_pulse_chip(detector_chip)


func _on_collection_updated(total_found: int, max_items: int) -> void:
	update_museum(total_found, max_items)
	_pulse_chip(museum_chip)
