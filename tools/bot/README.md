# DebugBridge — roteiros de bot

Autoload `DebugBridge` (`res://gameplay/debug/debug_bridge.gd`). Só liga em builds
de debug **e** com o user arg `--bot=<roteiro.json>`; sem isso não faz nada.

```bash
tools/run_bot.sh "/c/.../Godot_v4.3-stable_win64_console.exe" tools/bot/smoke_praia.json
tools/run_bot.sh "<godot>" tools/bot/smoke_praia.json --headless
```

Com janela corre a 1280x720. Em `--headless` o renderer é dummy: **não há
capturas** (o passo regista um erro e segue), mas dumps, input e `wait_until` funcionam.

Saída: `.bot_runs/<roteiro>_<timestamp>/` com `*.png`, `*.json` (dumps), `log.txt`
e `summary.json` (passos, capturas, esperas, erros). O exit code é 0 sem erros.

## Formato

```json
{"scene": "res://world/map_praia.tscn", "steps": [ ... ]}
```

Os passos correm por ordem; `t` = segundos desde o início (espera até lá). Cada passo
tem exatamente uma ação:

| passo | efeito |
|---|---|
| `{"t":0.5,"press":"move_forward","for":2.0}` | mantém a ação premida (não bloqueia os passos seguintes) |
| `{"t":3,"tap":"careful_dig"}` | prime 0.1 s |
| `{"t":3,"look":[dx,dy]}` | movimento de rato (px) — roda a câmara |
| `{"t":4,"screenshot":"nome"}` | grava `nome.png` |
| `{"t":4,"dump":"nome"}` | grava `nome.json`: jogador, GameState (só leitura), mochila, inimigos, spots, FPS, tempo |
| `{"t":5,"teleport":[x,y,z]}` | põe o jogador na posição |
| `{"t":5,"look_at":[x,y,z]}` | vira o jogador/câmara para o ponto |
| `{"t":5,"goto_spot":"nearest"}` | põe o jogador a 1 m do spot mais próximo, virado para ele |
| `{"wait_until":"money>=300","timeout":900}` | espera pela condição (`t` opcional); regista o tempo |
| `{"t":60,"quit":true}` | termina (também termina após o último passo) |
| `{"loop":[...],"until":"money>=300","timeout":1200}` | repete o corpo até à condição ou timeout (passos internos sem `t`; regista em `loops`) |
| `{"goto_spot":"nearest","walk":true,"timeout":40}` | **caminha** (move_forward + rumo) até 1 m do spot; salta se encravar e, se avançar < 1 m em 5 s, teleport de recurso (contado em `teleport_fallbacks`) |
| `{"dig_spot":true,"mode":"smart","timeout":30}` | cava (botão direito real) o spot ao alcance até revelar. `fast` = sem Shift, `careful` = Shift, `smart` = Shift só nas 2 últimas camadas |
| `{"pickup":true,"radius":6,"timeout":10}` | aproxima-se do item no chão mais próximo, olha e carrega E |
| `{"goto_sell":true}` | caminha até ao SellPoint mais próximo |
| `{"sell":true}` | carrega E dentro do raio do SellPoint (mesmo caminho do jogador: `Player._interact` → `SellPoint.deliver`) |

Qualquer passo aceita `"if"`: condição ou lista de condições (todas verdadeiras) — senão é saltado.

Raiz opcional: `"dump_every": 60` e `"screenshot_every": 120` (segundos) → `periodic_<s>.json/png`.

Com passos de alto nível o `summary.json` ganha `metrics`: `time_to_goal`, `money_per_min`,
`money_earned`, `items_sold`, `sold_value`, `sell_trips`, `spots_dug`, `items_picked`,
`first_enemy_time`, `damage_taken`, `deaths`, `teleport_fallbacks`, `step_failures`
(avisos de jogo, ex. "pickup: nenhum item" — não contam como erros). Exemplo: `praia_300.json`.

Ações: `move_forward/backward/left/right`, `jump`, `interact`, `use_tool`, `careful_dig`
(botão direito = cavar; `tap` não simula Shift — usa `dig_spot` com `mode`).
Variáveis de `wait_until`/`until`/`if`: `money`, `inventory`, `enemies`, `spots`, `time`, `health`,
`nearest_spot` (m; 9999 sem spots), `free_slots`, `deliverable` (itens vendáveis), `sell_dist` (m);
operadores `>= <= == != > <`.
