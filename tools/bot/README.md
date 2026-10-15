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
| `{"goto_spot":"nearest","walk":true,"radius":8}` | igual, mas só aceita spots a ≤ `radius` m (alcance do radar nível 1); senão regista aviso |
| `{"explore":10,"bounds":[-23,-23,23,23],"stop_near_spot":8}` | procura como um jogador: caminha 10 m numa direção aleatória dentro dos limites e pára se um spot ficar a ≤ 8 m |
| `{"fight":30,"radius":12}` | luta como o jogador durante 30 s: aproxima-se do inimigo vivo mais próximo, olha e carrega `attack` (pá, F); contorna obstáculos se encravar; acaba antes se ficar 2 s sem inimigos |
| `{"goto_sell":true}` | caminha até ao SellPoint mais próximo |
| `{"t":0,"set_state":{"upgrade_levels":{"backpack":3},"unlocked_maps":["campo"],"team_money":5000}}` | atalho de debug: funde estes campos no snapshot do `CoreGameState` e reaplica-o (`team_money`, `upgrade_levels`, `unlocked_maps`, `defeated_bosses`) |
| `{"t":0,"host":7791}` | coop: hospeda (`CoreNetwork.host_game`; `true` = porta 7777) |
| `{"t":0,"join":"127.0.0.1","port":7791,"timeout":20}` | coop: liga-se ao host e espera pela ligação (o `CoreSession` leva o cliente para o mapa) |
| `{"t":0,"start_expedition":"praia"}` | host: inicia a expedição pelo fluxo normal e espera o mapa carregar |
| `{"sleep":1.5}` | espera N segundos a partir de agora (`t` opcional; útil depois de `wait_until`) |
| `{"t":0,"face_player":"remote"}` | vira o jogador local para o jogador remoto mais próximo |
| `{"sell":true}` | carrega E dentro do raio do SellPoint (mesmo caminho do jogador: `Player._interact` → `SellPoint.deliver`) |

Qualquer passo aceita `"if"`: condição ou lista de condições (todas verdadeiras) — senão é saltado.

Raiz opcional: `"dump_every": 60` e `"screenshot_every": 120` (segundos) → `periodic_<s>.json/png`.

Com passos de alto nível o `summary.json` ganha `metrics`: `time_to_goal`, `money_per_min`,
`money_earned`, `items_sold`, `sold_value`, `sell_trips`, `spots_dug`, `items_picked`,
`first_enemy_time`, `damage_taken`, `deaths`, `teleport_fallbacks`, `explore_steps`,
`max_threat_level`, `threat_level_times`, `step_failures`
(avisos de jogo, ex. "pickup: nenhum item" — não contam como erros), `fight_swings`.
Exemplos: `praia_300.json` (economia da Praia), `campo_rate.json` (economia do Campo),
`campo_boss.json` (cava o altar do círculo de pedras e luta com a Toupeira Gigante).

Ações: `move_forward/backward/left/right`, `jump`, `interact`, `use_tool`, `careful_dig`, `attack`
(botão direito = cavar; `tap` não simula Shift — usa `dig_spot` com `mode`).
Variáveis de `wait_until`/`until`/`if`: `money`, `inventory`, `enemies`, `spots`, `time`, `health`,
`nearest_spot` (m; 9999 sem spots), `free_slots`, `deliverable` (itens vendáveis), `sell_dist` (m),
`pickup_dist` (m até ao item no chão mais próximo);
operadores `>= <= == != > <`.

## Coop (2 instâncias)

```bash
tools/bot/run_coop.sh "<godot console exe>"              # 2 janelas 960x540 lado a lado
tools/bot/run_coop.sh "<godot>" tools/bot/coop_host.json tools/bot/coop_client.json --headless
```

`coop_host.json` hospeda na porta 7791 e entra na Praia; `coop_client.json` liga-se a ela.
Cada instância escreve o seu run em `.bot_runs/` (logs do Godot em `.bot_runs/coop_*.log`).
Os dumps trazem `net` (peer_id, is_server, peers) e `players` (todos os jogadores, com
`local`, posição e ferramenta na mão); a variável `players` conta-os em `wait_until`.
O jogador "local" (grupo `player`) é sempre o desta instância.
