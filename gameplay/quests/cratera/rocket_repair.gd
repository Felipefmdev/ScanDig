extends Node

## #120: staged repair progression only. No scene, model, RPC or core binding.
## The caller must validate host authority, actor/tool, distance and LOS before
## complete_task. This internal method must never be exposed directly as an RPC.
## The progress port owns persistence; this controller never accesses economy.
## Its complete_quest callback is synchronous in this slice (ProgressSpy).
## A future deferred GameState adapter must separately acknowledge persistence
## before allowing travel; READY here is not permission to change scenes.

const REPAIR_QUEST: String = "vega_foguete"
const REQUIRED_QUEST: String = "vega_sinal"
const REQUIRED_BOSS: String = "the_sleeper"
const TASKS: Array[StringName] = [&"clear_base", &"secure_connection", &"align_receiver"]

var _progress: Node = null
var _completed_tasks: Dictionary = {}
var _repair_ready: bool = false


## Configure once per map instance; reconfiguration discards partial progress.
## Completed repair is restored exclusively from the persistent progress port.
func configure(progress: Node) -> void:
	_progress = progress
	_completed_tasks.clear()
	_repair_ready = false
	if not _has_progress_port():
		_progress = null
		return
	_restore_completed_repair()


func get_repair_state() -> StringName:
	_restore_completed_repair()
	if not _has_progress_port():
		return &"LOCKED"
	if _repair_ready:
		return &"READY"
	if not _prerequisites_complete():
		return &"LOCKED"
	return &"REPAIR"


func get_completed_task_count() -> int:
	_restore_completed_repair()
	return TASKS.size() if _repair_ready else _completed_tasks.size()


## Returns true only for a newly accepted, known task during repair.
func complete_task(task_id: StringName) -> bool:
	if get_repair_state() != &"REPAIR":
		return false
	if not TASKS.has(task_id) or _completed_tasks.has(task_id):
		return false
	_completed_tasks[task_id] = true
	if _completed_tasks.size() == TASKS.size():
		# Set before the callback so a reentrant completion cannot submit twice.
		_repair_ready = true
		_progress.call(&"complete_quest", REPAIR_QUEST)
	return true


func _has_progress_port() -> bool:
	return is_instance_valid(_progress) \
		and _progress.has_method(&"is_quest_completed") \
		and _progress.has_method(&"is_boss_defeated") \
		and _progress.has_method(&"complete_quest")


func _restore_completed_repair() -> void:
	if _has_progress_port() and bool(_progress.call(&"is_quest_completed", REPAIR_QUEST)):
		_repair_ready = true


func _prerequisites_complete() -> bool:
	return bool(_progress.call(&"is_quest_completed", REQUIRED_QUEST)) \
		and bool(_progress.call(&"is_boss_defeated", REQUIRED_BOSS))
