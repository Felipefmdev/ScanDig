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
| `{"t":0,"goto_player":"remote"}` | põe o jogador local 1.5 m ao lado do remoto mais próximo, virado para ele |
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
Upgrades (#27): `praia_300_detector2/detector3/shovel/pinpointer/backpack/all/kit.json` = `praia_300.json` com
`set_state` do upgrade e o raio do bot igual ao alcance do radar (8 / 10,5 / 13 m);
`upgrades_visor.json` (com janela) tira capturas do visor Nv.7 + pinpointer Nv.2 e da hotbar de 8.
Os roteiros do Campo (`tour_campo`, `campo_rate`, `campo_boss`) compram o detector Nv.2 no
`set_state` (o Campo vai exigi-lo, #26); `campo_rate` usa raio 10,5 m.
Coop dos inimigos (#24, `run_coop.sh <godot> <host.json> <client.json>`): `coop_enemies_host/client.json`
(o host acorda um caranguejo e afasta-se; persegue e fere o convidado, que o mata por request_hit)
e `coop_boss_host/client.json` (o convidado cava o altar do Campo; o host cria a Toupeira Gigante;
os dois lutam e `giant_mole` fica vencido nos dois lados).

Ações: `move_forward/backward/left/right`, `jump`, `interact`, `use_tool`, `careful_dig`, `attack`
(botão direito = cavar; `tap` não simula Shift — usa `dig_spot` com `mode`).
Variáveis de `wait_until`/`until`/`if`: `money`, `inventory`, `enemies`, `spots`, `time`, `health`,
`nearest_spot` (m; 9999 sem spots), `free_slots`, `deliverable` (itens vendáveis), `sell_dist` (m),
`pickup_dist` (m até ao item no chão mais próximo);
operadores `>= <= == != > <`.

### Missões, segredos e eventos (#39/#40)

| passo | efeito |
|---|---|
| `{"t":1,"interact":"Ze","walk":true}` | vai até ao `Interactable` com esse nome de nó (a pé com `walk`, senão teleporte), olha para ele e carrega E; avisa se ele não ficou em foco |
| `{"t":1,"call":"Tide","method":"force_low_tide"}` | atalho de debug: chama um método da allowlist (`force_low_tide`, `wake_immediately`, `start`, `trigger`) no primeiro nó com esse nome |

Variáveis: `flag_<nome>` (1/0, bandeira do `WorldFlags`), `quest_<nó do NPC>` (0 OFFER, 1 ACTIVE,
2 READY, 3 EVENT, 4 DONE), `wave_round`, `wave_phase` (0 IDLE, 1 BREAK, 2 FIGHT, 3 WON, 4 LOST),
`wave_left`, `bosses` (chefes vivos). Os dumps trazem `flags`, `quests` e `waves`.
Roteiros: `praia_secrets_tour.json` (visita: Zé, conchas, garrafa, pedra, castelo, pato, maré
baixa), `praia_quest_solo.json` (missão do anzol → Maré Vermelha → conchas → Polvo → relíquias e
easter eggs, solo) e `coop_quest_host/client.json` (porta 7798: o convidado cava e apanha o
anzol, os dois defendem o barco, o convidado toca as conchas e os dois vencem o Polvo).

## Coop (2 instâncias)

```bash
tools/bot/run_coop.sh "<godot console exe>"              # 2 janelas 960x540 lado a lado
tools/bot/run_coop.sh "<godot>" tools/bot/coop_host.json tools/bot/coop_client.json --headless
```

`coop_host.json` hospeda na porta 7791 e entra na Praia; `coop_client.json` liga-se a ela
(Fase 1: cada um vê o outro andar).
`coop_detector_host/client.json` (porta 7797): o convidado apanha um dos 2 detetores do spawn e
o segundo é recusado (cada jogador só leva um detetor).
`coop2_host.json` / `coop2_client.json` (porta 7792, Fase 2): os dois veem os mesmos spots
(`h1_spots` vs `c1_spots`), o convidado cava (o host executa o `dig`), os dois veem o item,
correm para o apanhar (só um o leva) e quem o tem entrega-o na base: o dinheiro e o museu
ficam iguais nos dois dumps finais.
Cada instância escreve o seu run em `.bot_runs/` (logs do Godot em `.bot_runs/<roteiro>.log`).
Os dumps trazem `net` (peer_id, is_server, peers) e `players` (todos os jogadores, com
`local`, posição e ferramenta na mão); a variável `players` conta-os em `wait_until`.
O jogador "local" (grupo `player`) é sempre o desta instância.
