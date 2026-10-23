# Métricas de mapa e UI — valores reais do ScanDig

Fonte de verdade para distâncias, alturas e tempos. Extraído do código a 23/10/2026
(commit `7d1f53b`), não de estimativas. Quando um valor mudar no código, atualiza aqui.

## 1. Jogador (`gameplay/player/player.gd`, `player.tscn`)

| Grandeza | Valor | Fonte |
|---|---|---|
| Velocidade base | 4,5 m/s | `player.gd:15` |
| Sprint | ×1,5 → 6,75 m/s | `player.gd:25` |
| Velocidade com carga | ×0,85 → 3,83 m/s | `player.gd:13` |
| Impulso de salto | 4,2 m/s | `player.gd:16` |
| Gravidade | 9,8 m/s² (projeto) | `get_gravity()` |
| Queda | ×1,6 (15,68 m/s²) | `player.gd:36` |
| Altura do salto (ápice) | **0,90 m** | 4,2² / (2 × 9,8) |
| Tempo no ar | **0,77 s** | subida 0,43 s + descida 0,34 s |
| Distância horizontal do salto | **3,5 m** a andar; **5,2 m** a sprint | v × tempo no ar |
| Altura dos olhos | ≈1,7 m (Head 0,9 + câmara) | `player.tscn` |
| FOV | 75° (predefinição) | `Camera3D` sem `fov` |
| Alcance de escavação | **1,8 m** (dos pés) | `player.gd:18` |
| Alcance de interação | **2,5 m** | `player.gd:82` |
| Alcance do golpe de pá | **2,2 m**, cone `dot ≥ 0,5` (~60°) | `player.gd:75,78` |
| Raio do repelente | 8 m por 8 s | `player.gd:96,97` |

## 2. Detetor (`gameplay/detector/metal_detector.gd`)

| Grandeza | Valor |
|---|---|
| Alcance no nível 1 | **8 m** (`:18`) |
| Ganho por nível | +2,5 m (`:19`) |
| Alcance no nível 7 | **23 m** (8 + 2,5 × 6) |
| Pinpoint | 2,0 m; “CAVE” a 1,5 m (`:44,46`) |
| Inimigos no radar | a partir do nível 6, até 1,5× o alcance (`:37,38`) |
| Intervalo de varredura | 0,05 s; volta 1,5 s (`:21,22`) |

**Consequência para o layout:** com alcance 8 m, dois spots a menos de ~10 m aparecem
no mesmo blip e o jogador não sabe qual cavar. Com alcance 23 m, um spot a 30 m do
caminho fica “mudo” e obriga a caminhada sem feedback. Faixa útil: **10–25 m** entre
spots e **≤ 30 m** do eixo do caminho.

## 3. Inimigos (`gameplay/enemies/enemy_base.gd`)

| Grandeza | Valor |
|---|---|
| Vida base | 50 (`:52`) |
| Raio de agressão por objetivo | 3,0 m (`:161`) |
| Velocidades e alcances | por inimigo (medir no `.tscn`/script de cada um) |

Não inventes velocidade de inimigo: mede no script respetivo e acrescenta aqui.

## 4. UI (`ui/theme/build_theme.gd`)

| Grandeza | Valor |
|---|---|
| Corpo | 18 px |
| Título | 21 px (1,17× corpo) |
| Dica/aviso | 15 px |
| Código | 30 px |
| Carregamento | 30 px |
| Toast | 20 px |
| Margem do 9-patch | 14 px |

**Observação:** título a 1,17× do corpo não cria hierarquia suficiente; a regra do
`UI_UX.md` pede 1,25–1,5×. O contraste medido está em `docs/UI_REVIEW.md`.

## 5. Regras derivadas (usa estas no layout)

| Regra | Valor | Razão |
|---|---|---|
| Largura mínima de passagem | **3,0 m** | 2 jogadores + folga; 2,5 m só em atalhos |
| Largura confortável | 4–6 m | leitura e combate |
| Arena de chefe | **18–25 m** de diâmetro | investidas/irrupções precisam de recuo |
| Degrau sem salto | ≤ 0,45 m | step height do `CharacterBody3D` |
| Plataforma que exige salto | 0,5–0,85 m | abaixo do ápice de 0,90 m |
| Parede que exige salto | 0,9–1,2 m | margem de erro pequena; usa rampa |
| Vão transponível | ≤ 3,0 m a andar; ≤ 4,5 m a sprint | 3,5/5,2 m teóricos menos margem |
| Marco dominante | a cada **20–35 m** | 3–5 s de sprint |
| Silhueta de marco | legível a **60–80 m** | horizonte |
| Espaço livre por spot | raio de **2 m** | corpo + pá + animação |
| Área jogável sem props | **≥ 50%** | escavar, fugir, ler |
| Spots entre si | **10–25 m** | alcance 8–23 m |
| Spots ao eixo do caminho | ≤ 30 m | não perder feedback |
| Verticalidade | ≤ 3 níveis | orientação |
| Beats por mapa | 6–9 (60–100 min) | 4–12 min por beat |

## 6. Como medir

```powershell
# contagem de nós/transforms e distâncias entre âncoras
python tools/map_layout_audit.py world/map_praia.tscn
python tools/map_layout_audit.py --all --json

# contraste dos pares da paleta
python tools/ui_contrast_audit.py

# capturas com a mesma câmara (Godot com janela/MCP)
./tools/map_production.ps1 -Tool Game -ToolArgs 'res://world/map_praia.tscn'
```

Para posições globais exatas de nós instanciados, confirma no editor/MCP: o auditor lê
apenas os nós declarados no `.tscn` e resolve a cadeia de pais.

## 7. Dívida conhecida

- FOV não está fixado no `.tscn`; se mudar, as distâncias de leitura mudam.
- Velocidades de inimigos não estão centralizadas; medir por tipo antes de dimensionar
  arenas.
- O tempo de travessia real (com terreno e obstáculos) é maior que `distância /
  velocidade`; usa o cálculo como limite inferior.
