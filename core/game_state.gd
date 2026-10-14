class_name GameState
extends Node

## Estado global da equipe, economia e museu do ScanDig.

signal money_changed(new_amount: int)
signal collection_updated(total_found: int, max_items: int)
signal item_sold(item_name: String, value: int)

static var instance: GameState = null

@export var team_money: int = 100
@export var current_day: int = 1
@export var discovered_items: Array[String] = []
@export var equipped_detector_level: int = 1
@export var max_museum_items: int = 0


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()


func _count_catalog_items() -> int:
	var dir: DirAccess = DirAccess.open("res://items/catalog")
	if dir == null:
		return 0
	
	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var clean_name: String = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				count += 1
		file_name = dir.get_next()
	return count


func get_total_catalog_items() -> int:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()
	return max_museum_items


func get_item_display_name(item_id: String) -> String:
	var catalog_path: String = "res://items/catalog/%s.tres" % item_id
	if ResourceLoader.exists(catalog_path):
		var res: Resource = ResourceLoader.load(catalog_path)
		if res is ItemData:
			var item_data: ItemData = res as ItemData
			if not item_data.display_name.is_empty():
				return item_data.display_name
	return item_id


@rpc("any_peer", "call_local", "reliable")
func sell_found_item(item_id: String, final_value: int) -> void:
	team_money += final_value
	var display_name: String = get_item_display_name(item_id)
	money_changed.emit(team_money)
	item_sold.emit(display_name, final_value)


@rpc("any_peer", "call_local", "reliable")
func register_museum_item(item_id: String) -> void:
	if not discovered_items.has(item_id):
		discovered_items.append(item_id)
		var total_catalog: int = get_total_catalog_items()
		collection_updated.emit(discovered_items.size(), total_catalog)


@rpc("any_peer", "call_local", "reliable")
func buy_upgrade(upgrade_id: String, cost: int) -> bool:
	if cost < 0:
		return false
	
	if team_money >= cost:
		team_money -= cost
		if upgrade_id == "detector" or upgrade_id.begins_with("detector"):
			equipped_detector_level += 1
		money_changed.emit(team_money)
		return true
	
	return false


func reset_state() -> void:
	team_money = 100
	current_day = 1
	discovered_items.clear()
	equipped_detector_level = 1
	money_changed.emit(team_money)
	collection_updated.emit(discovered_items.size(), get_total_catalog_items())
