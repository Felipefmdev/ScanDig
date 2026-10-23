# Guia de produção de mapas — do blockout à revisão

Processo obrigatório para mapas novos ou reformulados. Cada passo tem um **portão**: não
avança sem o critério cumprido e registado na issue. Números em `docs/MAP_METRICS.md`.

## 0. Preparação (30 min)

- Issue com âmbito, beat a mudar e critério de aceitação.
- Confirma o âmbito Dev A/Dev B (`CONTEXT.md` §2). `world/map_*.tscn` é Dev A.
- Fotografa o estado atual: 3 câmaras (spawn, meio, chefe), mesma hora/luz.
- Corre o auditor e guarda o baseline:

```powershell
python tools/map_layout_audit.py world/map_praia.tscn --json > .bot_runs/praia_antes.json
```

**Portão:** baseline de nós/transforms e capturas arquivados.

## 1. Beat sheet (1 h)

Preenche `docs/maps/PRAIA_BEATS.md` (modelo) para o mapa em causa:

- lista de beats, função, duração alvo;
- marco de cada beat;
- ligações (critical path, atalhos, segredos);
- zonas de escavação e de combate;
- recompensas e o que muda de estado.

**Portão:** um leitor que não conhece o mapa consegue desenhar a planta a partir do
documento.

## 2. Greybox (2–4 h)

Só formas, um material, colisão. Ferramenta: Cyclops Level Builder na oficina
(`docs/learning/TOOLS.md`) ou CSG temporário.

Regras:

- escala 1 m; nada de detalhe;
- marcos como volumes grandes e distintos;
- 50% de área livre; zonas de exclusão à volta dos spots;
- nenhuma parede invisível;
- marcadores nomeados (`MapMarker/Spawn`, `MapMarker/Boss`, `MapMarker/Shop`,
  `MapMarker/Secret`), porque o auditor e os spawners dependem de nomes estáveis.

**Portão:** percurso completo em ≤ 3 min, sem cair do mapa, sem bloqueios.

## 3. Passeio de leitura (30 min)

Joga sem HUD e narra:

1. Onde estou? O que vejo ao longe?
2. Para onde vou? Porquê?
3. Onde posso cavar? Onde é perigoso?
4. O que ganhei? O que arrisco?

Anota hesitações com timestamp. Cada hesitação é um defeito de layout, não de arte.

**Portão:** um jogador novo encontra a banca e o primeiro spot em < 60 s; chega ao chefe
sem ser conduzido por setas.

## 4. Arte (4–8 h)

Ordem: hero props → kit → scatter → luz/som.

- um hero por beat;
- kit modular nas partes construídas;
- scatter com exclusões (caminho, spots, arenas);
- paleta do bioma; cor script;
- som por marco e por interativo.

**Portão:** capturas de 3 câmaras; em cinza os beats continuam distintos; nenhum prop
tapa interativo/spot.

## 5. Sistemas e coop (2–3 h)

- spots, inimigos, chefe, segredos e NPC ligados ao host;
- estados replicados (porta aberta, chefe acordado, relíquia apanhada);
- passagens alternativas; ninguém fica preso;
- atalhos testados com 2 jogadores.

**Portão:** sessão coop de 10 min sem bloqueio; segredo aberto por um jogador é óbvio
para o outro.

## 6. Performance (1 h)

- pior ponto: chefe + efeitos + 2 jogadores;
- sombras e oclusão revistas;
- colisões simples;
- medir FPS, não estimar.

**Portão:** dentro do orçamento definido na issue; sem spikes ao entrar na arena.

## 7. Revisão e fecho (30 min)

- `docs/learning/CHECKLISTS.md` A–C, com evidência;
- auditor depois, diff de nós/transforms explicado;
- capturas antes/depois na issue;
- commit com `Closes #N` apenas dos teus ficheiros.

**Portão:** checklist preenchida, capturas anexadas, testes verdes.

## Ferramentas por passo

| Passo | Ferramenta |
|---|---|
| 0, 7 | `tools/map_layout_audit.py`, `tools/qa_visual_review.py`, MCP |
| 1 | este guia + `docs/maps/PRAIA_BEATS.md` |
| 2 | Cyclops (oficina) / CSG temporário / GridMap |
| 3 | build jogável, sem HUD (`hud.tscn` desativado em cena de teste) |
| 4 | Blender + kit + ProtonScatter + Kenney |
| 5 | Godot + testes GUT + sessão coop |
| 6 | Godot profiler, Movie Maker |

## Não faças

- Regravar `world/map_*.tscn` de raiz: perdes spawners, transforms e segredos.
- Mover âncoras sem atualizar `spot_spawner`, NPCs e gatilhos.
- Colocar props no caminho de escavação “porque fica bonito”.
- Resolver ilegibilidade com setas ou HUD extra: resolve no layout.
- Misturar passe de arte com mudança de layout no mesmo commit.
- Fechar sem capturas atuais (um roteiro antigo não valida nada).

## Modelo de beat sheet

Ver `docs/maps/PRAIA_BEATS.md`. Copia para `docs/maps/<mapa>_beats.md` e preenche.
