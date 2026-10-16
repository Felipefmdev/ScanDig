extends GutTest

## Morte dos chefes com frames reais (sem mexer em _state_time à mão): boss_defeated tem de
## sair sozinho depois de take_damage letal. Apanha relógios de morte parados (a física é
## desligada em _on_died e o _process tem de avançar _state_time).

const BOSSES: Array = [
	["res://gameplay/enemies/boss/ancient_walrus.tscn"],
	["res://gameplay/enemies/boss/frozen_mammoth.tscn"],
	["res://gameplay/enemies/boss/cave_yeti.tscn"],
	["res://gameplay/enemies/boss/the_sleeper.tscn"],
	["res://gameplay/enemies/boss/the_echo.tscn"],
	["res://gameplay/enemies/boss/idol_mummy.tscn"],
	["res://gameplay/enemies/boss/ancient_guardian.tscn"],
]
## Tempo máximo de animação de morte (s) até boss_defeated.
const MAX_DEATH_TIME: float = 4.0


func before_each() -> void:
	QuestRewards.reset_session()


func test_boss_emits_defeated_with_real_frames(params: Array = use_parameters(BOSSES)) -> void:
	var path: String = params[0]
	var boss: EnemyBase = (load(path) as PackedScene).instantiate() as EnemyBase
	add_child_autoqfree(boss)
	if boss.has_method(&"wake_immediately"):
		boss.call(&"wake_immediately")
	await wait_frames(4)
	watch_signals(boss)
	boss.take_damage(100000.0)
	await wait_for_signal(Signal(boss, &"boss_defeated"), MAX_DEATH_TIME)
	assert_signal_emitted(boss, "boss_defeated", "%s emite boss_defeated sozinho" % path.get_file())
