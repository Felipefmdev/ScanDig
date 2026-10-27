extends GutTest

## #120: prepared RED, NOT RUN. No controller implementation is included.
## Proposed staged controller API (Node; no class_name required):
## configure(progress: Node) -> void
## get_repair_state() -> StringName: LOCKED / REPAIR / READY
## get_completed_task_count() -> int
## complete_task(task_id: StringName) -> bool: true only for a new accepted task.
## complete_task is an internal host-validated entry, NOT an exposed client RPC.
## Progress port: is_quest_completed(String), is_boss_defeated(String),
## complete_quest(String). Completion must go through this port exactly once.
## READY hydration must not submit completion/reward again.
## These tests cover repair progression only, not RPC/security/physical interaction,
## save-file IO, unlock integration or boarding. The port below is only a spy.
## Run explicitly with empty GUT dirs after root grants engine lease.

const CONTROLLER_PATH: String = "res://gameplay/quests/cratera/rocket_repair.gd"
const REPAIR_QUEST: String = "vega_foguete"
const TASKS: Array[StringName] = [&"clear_base", &"secure_connection", &"align_receiver"]

class ProgressSpy extends Node:

	var completed_quests: Array[String] = []
	var defeated_bosses: Array[String] = []
	var team_money: int = 137
	var inventory: Dictionary = {"nucleo_adormecido": 1, "cristal_eco": 1, "engrenagem_alienigena": 2}
	var completion_calls: Array[String] = []

	func is_quest_completed(quest_id: String) -> bool:
		return completed_quests.has(quest_id)

	func is_boss_defeated(boss_id: String) -> bool:
		return defeated_bosses.has(boss_id)

	func complete_quest(quest_id: String) -> void:
		completion_calls.append(quest_id)
		if not completed_quests.has(quest_id):
			completed_quests.append(quest_id)


func _progress(vega: bool = true, sleeper: bool = true, ready: bool = false) -> ProgressSpy:
	var progress: ProgressSpy = ProgressSpy.new()
	if vega:
		progress.completed_quests.append("vega_sinal")
	if sleeper:
		progress.defeated_bosses.append("the_sleeper")
	if ready:
		progress.completed_quests.append(REPAIR_QUEST)
	add_child_autofree(progress)
	return progress


func _controller(progress: ProgressSpy) -> Node:
	# Explicit absence failure: no fallback implementation, pending or mock SUT.
	assert_true(ResourceLoader.exists(CONTROLLER_PATH), "RED: staged rocket controller is absent")
	if not ResourceLoader.exists(CONTROLLER_PATH):
		return null
	var source: Script = load(CONTROLLER_PATH) as Script
	assert_not_null(source, "Controller must load")
	if source == null:
		return null
	var instance: Node = source.new() as Node
	assert_not_null(instance, "Controller contract extends Node")
	if instance == null:
		return null
	add_child_autofree(instance)
	for method: StringName in [&"configure", &"get_repair_state", &"get_completed_task_count", &"complete_task"]:
		assert_true(instance.has_method(method), "Missing behavioral API: " + String(method))
		if not instance.has_method(method):
			return null
	instance.call(&"configure", progress)
	return instance


func _assert_economy(progress: ProgressSpy, money: int, items: Dictionary) -> void:
	assert_eq(progress.team_money, money, "Repair must neither charge nor pay money")
	assert_eq(progress.inventory, items, "Repair must not consume, grant or replace inventory items")


func test_locked_until_both_vega_and_sleeper_complete() -> void:
	for prerequisites: Vector2i in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)]:
		var progress: ProgressSpy = _progress(prerequisites.x == 1, prerequisites.y == 1)
		var items: Dictionary = progress.inventory.duplicate(true)
		var controller: Node = _controller(progress)
		if controller == null: return
		assert_eq(StringName(controller.call(&"get_repair_state")), &"LOCKED")
		for task: StringName in TASKS:
			assert_false(bool(controller.call(&"complete_task", task)), "Cannot repair while prerequisites are missing")
		assert_eq(int(controller.call(&"get_completed_task_count")), 0)
		assert_false(progress.is_quest_completed(REPAIR_QUEST))
		assert_eq(progress.completion_calls.size(), 0)
		_assert_economy(progress, 137, items)


func test_three_distinct_tasks_are_idempotent_in_any_order() -> void:
	for order: Array in [[0,1,2], [2,0,1], [1,2,0]]:
		var progress: ProgressSpy = _progress()
		var controller: Node = _controller(progress)
		if controller == null: return
		assert_eq(StringName(controller.call(&"get_repair_state")), &"REPAIR")
		assert_eq(int(controller.call(&"get_completed_task_count")), 0)
		var count: int = 0
		for index: int in order:
			assert_true(bool(controller.call(&"complete_task", TASKS[index])))
			count += 1
			assert_false(bool(controller.call(&"complete_task", TASKS[index])), "Duplicate task must not advance progression")
			assert_eq(int(controller.call(&"get_completed_task_count")), count)
			assert_eq(StringName(controller.call(&"get_repair_state")), &"READY" if count == 3 else &"REPAIR")
			assert_eq(progress.is_quest_completed(REPAIR_QUEST), count == 3, "Two tasks never unlock travel")
		assert_eq(progress.completion_calls, [REPAIR_QUEST], "One persistent completion after exactly three distinct tasks")


func test_unknown_task_never_counts_or_completes() -> void:
	var progress: ProgressSpy = _progress()
	var controller: Node = _controller(progress)
	if controller == null: return
	for invalid: StringName in [&"", &"buy_fuel", &"map_fragment", &"clear_base_typo"]:
		assert_false(bool(controller.call(&"complete_task", invalid)))
	assert_eq(int(controller.call(&"get_completed_task_count")), 0)
	assert_eq(StringName(controller.call(&"get_repair_state")), &"REPAIR")
	assert_eq(progress.completion_calls.size(), 0)


func test_repair_preserves_money_and_items_after_every_action() -> void:
	var progress: ProgressSpy = _progress()
	# Completion must not introduce a hidden economy prerequisite either.
	progress.team_money = 0
	progress.inventory.clear()
	var items: Dictionary = progress.inventory.duplicate(true)
	var controller: Node = _controller(progress)
	if controller == null: return
	for task: StringName in TASKS:
		assert_true(bool(controller.call(&"complete_task", task)), "No money, gear delivery or consumable is required")
		_assert_economy(progress, 0, items)
	assert_eq(StringName(controller.call(&"get_repair_state")), &"READY")
	assert_eq(progress.completion_calls, [REPAIR_QUEST])
	# A second fixture with valuable trophies must preserve them too.
	var stocked: ProgressSpy = _progress()
	var original_items: Dictionary = stocked.inventory.duplicate(true)
	var second: Node = _controller(stocked)
	if second == null: return
	for task: StringName in TASKS:
		assert_true(bool(second.call(&"complete_task", task)))
		_assert_economy(stocked, 137, original_items)


func test_ready_restores_from_persistent_completion_without_repair_or_reward() -> void:
	var progress: ProgressSpy = _progress(true, true, true)
	var items: Dictionary = progress.inventory.duplicate(true)
	var controller: Node = _controller(progress)
	if controller == null: return
	assert_eq(StringName(controller.call(&"get_repair_state")), &"READY")
	assert_eq(int(controller.call(&"get_completed_task_count")), 3)
	for task: StringName in TASKS:
		assert_false(bool(controller.call(&"complete_task", task)))
	controller.call(&"configure", progress)
	assert_eq(StringName(controller.call(&"get_repair_state")), &"READY")
	assert_eq(progress.completion_calls.size(), 0, "Loading completed repair must not replay completion/reward")
	_assert_economy(progress, 137, items)


func test_partial_repair_is_not_persistent_but_completed_repair_is() -> void:
	var progress: ProgressSpy = _progress()
	var first: Node = _controller(progress)
	if first == null: return
	assert_true(bool(first.call(&"complete_task", TASKS[0])))
	assert_true(bool(first.call(&"complete_task", TASKS[1])))
	assert_false(progress.is_quest_completed(REPAIR_QUEST))
	# Fresh controller represents a new map; persistent progress port survives.
	var fresh: Node = _controller(progress)
	if fresh == null: return
	assert_eq(int(fresh.call(&"get_completed_task_count")), 0)
	assert_eq(StringName(fresh.call(&"get_repair_state")), &"REPAIR")
	for task: StringName in TASKS:
		assert_true(bool(fresh.call(&"complete_task", task)))
	var restored: Node = _controller(progress)
	if restored == null: return
	assert_eq(StringName(restored.call(&"get_repair_state")), &"READY")
	assert_eq(int(restored.call(&"get_completed_task_count")), 3)
	assert_eq(progress.completion_calls, [REPAIR_QUEST])
