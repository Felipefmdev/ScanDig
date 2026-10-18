extends GutTest

## Polvo e Espantalho: a derrota sai pelo delta recebido no _process, não pelo do frame real
## (como a toupeira gigante, aa06c43). Quem chama _process(1/60) à mão tem de ver boss_defeated.

const BOSSES: Array = [
	["res://gameplay/enemies/boss/octopus.tscn", &"octopus"],
	["res://gameplay/enemies/boss/scarecrow.tscn", &"scarecrow"],
]


func before_each() -> void:
	QuestRewards.reset_session()


func test_manual_process_emits_boss_defeated(params: Array = use_parameters(BOSSES)) -> void:
	var arena: Node3D = Node3D.new()
	add_child_autofree(arena)
	var boss: EnemyBase = (load(params[0]) as PackedScene).instantiate() as EnemyBase
	arena.add_child(boss)
	boss.call(&"wake_immediately")
	watch_signals(boss)
	boss.take_damage(100000.0)
	assert_false(boss.is_alive())
	for i: int in range(90):
		boss._process(1.0 / 60.0)
	assert_signal_emitted_with_parameters(boss, "boss_defeated", [params[1]])
