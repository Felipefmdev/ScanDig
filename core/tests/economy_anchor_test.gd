# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/economy_anchor_test.gd
## Âncora da economia (#64): o ÚNICO teste que fixa os valores de balanceamento. Os outros testes
## leem GameState.UPGRADES e items/maps/*.tres e conferem regras. Se este falhar de propósito:
## mudou a economia? Atualize docs/PACING.md e as tabelas abaixo no mesmo commit.
extends SceneTree

const HINT: String = " — mudou a economia? atualize docs/PACING.md e core/tests/economy_anchor_test.gd"

const UPGRADE_COSTS: Dictionary = {
	"detector": [300, 600, 700, 2000, 40000, 90000],
	"pinpointer": [500, 60000],
	"shovel": [800, 1200, 40000],
	"backpack": [400, 800, 1600, 1800, 6000],
}
const UPGRADE_MAPS: Dictionary = {
	"detector": ["", "", "", "ruinas", "geleira", "cratera"],
	"pinpointer": ["", "cratera"],
	"shovel": ["", "ruinas", "cratera"],
	"backpack": ["", "", "campo", "ruinas", "geleira"],
}
## map_id -> [unlock_cost, required_detector_level, média mínima do pool, média máxima do pool]
const MAPS: Dictionary = {
	"praia": [0, 1, 1.0, 100.0],
	"campo": [800, 2, 30.0, 200.0],
	"ruinas": [8000, 4, 400.0, 520.0],
	"geleira": [100000, 5, 650.0, 950.0],
	"cratera": [280000, 6, 1100.0, 1400.0],
}
const QUEST_REWARDS: Dictionary = {"ze_anzol": 600, "lurdes_chaves": 1800}

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg + ("" if cond else HINT))
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _pool_average(map_data: MapData) -> float:
	if map_data.item_pool.is_empty():
		return 0.0
	var total: int = 0
	for item: ItemData in map_data.item_pool:
		total += item.base_value if item != null else 0
	return float(total) / map_data.item_pool.size()


func _run() -> void:
	_check(GameState.UPGRADES.keys().size() == UPGRADE_COSTS.size(), "upgrades: %s" % str(GameState.UPGRADES.keys()))
	for upgrade_id: String in UPGRADE_COSTS.keys():
		var entry: Dictionary = GameState.UPGRADES.get(upgrade_id, {})
		_check(entry.get("costs", []) == UPGRADE_COSTS[upgrade_id], "%s custos %s" % [upgrade_id, str(entry.get("costs", []))])
		_check(entry.get("required_maps", []) == UPGRADE_MAPS[upgrade_id], "%s travas %s" % [upgrade_id, str(entry.get("required_maps", []))])
	for map_id: String in MAPS.keys():
		var map_data: MapData = load("res://items/maps/%s.tres" % map_id) as MapData
		var expected: Array = MAPS[map_id]
		_check(map_data != null and map_data.unlock_cost == int(expected[0]), "%s desbloqueio %d" % [map_id, map_data.unlock_cost if map_data != null else -1])
		_check(map_data != null and map_data.required_detector_level == int(expected[1]), "%s detector Nv.%d" % [map_id, map_data.required_detector_level if map_data != null else -1])
		var avg: float = _pool_average(map_data) if map_data != null else 0.0
		_check(avg >= float(expected[2]) and avg <= float(expected[3]), "%s média do pool %.1f (%.0f–%.0f)" % [map_id, avg, float(expected[2]), float(expected[3])])
	for quest_id: String in QUEST_REWARDS.keys():
		var reward: int = int((GameState.QUESTS.get(quest_id, {}) as Dictionary).get("reward", -1))
		_check(reward == int(QUEST_REWARDS[quest_id]), "missão %s paga %d" % [quest_id, reward])
	print("RESULT fails=%d" % _fails)
	quit(_fails)
