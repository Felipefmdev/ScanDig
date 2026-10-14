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

Ações: `move_forward/backward/left/right`, `jump`, `interact`, `use_tool`, `careful_dig`
(botão direito = cavar; Shift não é simulado, logo cava sempre em modo rápido).
Variáveis de `wait_until`: `money`, `inventory`, `enemies`, `spots`, `time`, `health`;
operadores `>= <= == != > <`.
