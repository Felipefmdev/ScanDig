class_name MapData
extends Resource

## Definição de um mapa de escavação: o que se encontra, quanto custa liberar e quão
## rápido o subsolo "acorda" (ver DisturbanceMeter).

@export var id: String = ""
@export var display_name: String = ""
@export var unlock_cost: int = 0
@export var required_detector_level: int = 1
@export var item_pool: Array[ItemData] = []
@export_range(0.0, 1.0, 0.01) var rare_variant_chance: float = 0.05
## Multiplicador do barulho gerado neste mapa (mapas difíceis acordam mais rápido).
@export_range(0.1, 5.0, 0.1) var noise_multiplier: float = 1.0
## Barulho perdido por segundo quando ninguém está a cavar.
@export var noise_decay_per_second: float = 2.0
@export var spot_count: int = 8
## Multiplica o dano dos inimigos neste mapa (#82: mortes demais nos mapas 3-5 no bot).
## Soma-se ao ajuste por nº de jogadores do DifficultyProfile.
@export_range(0.1, 2.0, 0.05) var enemy_damage_multiplier: float = 1.0
## #103/#113: só se desbloqueia com o mapa do tesouro completo (GameState.has_all_map_fragments),
## nunca por dinheiro. Ilha do Tesouro.
@export var requires_map_fragments: bool = false
