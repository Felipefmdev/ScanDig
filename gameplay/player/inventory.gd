class_name Inventory
extends Node

## Mochila do jogador: slots fixos (null = vazio) e um slot selecionado.

signal inventory_changed
signal selected_slot_changed(index: int)

## Número de slots. Pode ser melhorado em runtime (os itens a mais não se perdem: são devolvidos).
@export var capacity: int = 3:
	set(value):
		capacity = maxi(value, 1)
		_resize()

var slots: Array[CarriedItem] = []
var selected_slot: int = 0


func _ready() -> void:
	_resize()


func is_full() -> bool:
	return get_count() >= capacity


func is_empty() -> bool:
	return get_count() == 0


func get_count() -> int:
	var n: int = 0
	for c: CarriedItem in slots:
		if c != null:
			n += 1
	return n


func get_total_value() -> int:
	var total: int = 0
	for c: CarriedItem in slots:
		if c != null:
			total += c.final_value
	return total


func get_item(index: int) -> CarriedItem:
	if index < 0 or index >= slots.size():
		return null
	return slots[index]


func get_selected() -> CarriedItem:
	return get_item(selected_slot)


## Põe o item no primeiro slot livre. Devolve false se a mochila estiver cheia.
func add_item(c: CarriedItem) -> bool:
	if c == null:
		return false
	for i: int in slots.size():
		if slots[i] == null:
			slots[i] = c
			inventory_changed.emit()
			return true
	return false


func remove_at(index: int) -> CarriedItem:
	var c: CarriedItem = get_item(index)
	if c != null:
		slots[index] = null
		inventory_changed.emit()
	return c


func take_selected() -> CarriedItem:
	return remove_at(selected_slot)


## Esvazia a mochila e devolve todos os itens (para entregar ou largar ao morrer).
func take_all() -> Array[CarriedItem]:
	var out: Array[CarriedItem] = []
	for i: int in slots.size():
		if slots[i] != null:
			out.append(slots[i])
			slots[i] = null
	if not out.is_empty():
		inventory_changed.emit()
	return out


## Tira e devolve só os itens que cumprem `predicate` (ex.: SellPoint.can_deliver).
## Os restantes (ferramentas) ficam no mesmo slot.
func take_where(predicate: Callable) -> Array[CarriedItem]:
	var out: Array[CarriedItem] = []
	for i: int in slots.size():
		if slots[i] != null and predicate.call(slots[i]):
			out.append(slots[i])
			slots[i] = null
	if not out.is_empty():
		inventory_changed.emit()
	return out


func select(index: int) -> void:
	if slots.is_empty():
		return
	var clamped: int = clampi(index, 0, slots.size() - 1)
	if clamped == selected_slot:
		return
	selected_slot = clamped
	selected_slot_changed.emit(selected_slot)


## Avança/recua o slot selecionado com wrap-around (roda do rato).
func cycle(direction: int) -> void:
	if slots.is_empty():
		return
	select(posmod(selected_slot + direction, slots.size()))


func _resize() -> void:
	var overflow: Array[CarriedItem] = []
	while slots.size() > capacity:
		var c: CarriedItem = slots.pop_back()
		if c != null:
			overflow.append(c)
	while slots.size() < capacity:
		slots.append(null)
	# Itens que já não cabem: reencaixa nos slots livres que restem.
	for c: CarriedItem in overflow:
		add_item(c)
	if selected_slot >= capacity:
		selected_slot = capacity - 1
		selected_slot_changed.emit(selected_slot)
	inventory_changed.emit()
