# Aprender mapas e UI — pacote de contexto do ScanDig

Material de estudo e de trabalho para humanos e agentes. Não é uma bibliografia: é o
**contexto que os modelos têm de carregar antes de tocar em `world/` ou `ui/`**, mais as
ferramentas livres que o suportam.

## Como usar (agentes)

1. Lê `AGENT_CONTEXT.md` (1 página). É o mínimo obrigatório e substitui a leitura dos
   restantes ficheiros em tarefas pequenas.
2. Lê o capítulo da área que vais mexer:
   - mapas: `LEVEL_DESIGN.md` + `MAP_ART.md`;
   - UI: `UI_UX.md`;
   - decisão de ferramenta: `TOOLS.md`.
3. Consulta `docs/MAP_METRICS.md` antes de propor distâncias, alturas ou larguras.
4. Antes de fechar a tarefa, passa `CHECKLISTS.md`.
5. Quando precisares de uma fonte, `SOURCES.md` diz o que é livre, o que é pago e o que
   não deve ser descarregado.

Regra: **não inventes números**. Se um valor não está em `MAP_METRICS.md`, mede-o no
código ou no mapa e acrescenta-o lá com a fonte.

## Como usar (humanos)

A ordem de leitura é a mesma. Para estudar a fundo, o caminho mais curto é:

1. `LEVEL_DESIGN.md` §§2–6 (blockout, beats, marcos, espaço vazio) — 40 min.
2. `UI_UX.md` §§2–5 (hierarquia, tipografia, cor, estados) — 40 min.
3. Um capítulo do [Level Design Book](https://book.leveldesignbook.com) por sessão.
4. 10 ecrãs no [Game UI Database](https://www.gameuidatabase.com) por sessão, sempre a
   escrever o que se retira.

## Ficheiros

| Ficheiro | Para quê |
|---|---|
| `AGENT_CONTEXT.md` | Regras destiladas e vocabulário; injetar no contexto do modelo |
| `LEVEL_DESIGN.md` | Teoria de level design aplicada aos 6 mapas |
| `MAP_ART.md` | Composição, kits modulares, scatter, luz, performance |
| `UI_UX.md` | Hierarquia, tipografia, cor, estados, acessibilidade, HUD em 3D |
| `TOOLS.md` | Ferramentas: para quê, licença, estado, como instalar |
| `SOURCES.md` | Livros, talks, artigos e docs — com licença e prioridade |
| `CHECKLISTS.md` | Revisão de mapa e de UI, com critérios de aceitação |
| `references.json` | Manifesto das referências descarregáveis (URL, licença, hash) |
| `_refs/` | Cópias locais para estudo (ignorado pelo Git) |

## Limites

- Cópias em `_refs/` servem para estudo offline; não entram no repositório nem no build.
- Nada aqui autoriza migrar Godot, trocar o tema ou reescrever `world/map_*.tscn`.
  As regras da casa continuam em `AGENTS.md` e `CONTEXT.md`.
- Números de mapa e de UI mudam com o jogo: o documento vivo é `docs/MAP_METRICS.md`;
  este pacote explica o *porquê*.

## Manutenção

- Novo número de gameplay → `docs/MAP_METRICS.md` e, se mudar uma regra, o capítulo
  respetivo.
- Nova ferramenta → `TOOLS.md` + `references.json`.
- Referência nova → `SOURCES.md`, com licença.
- O pacote é revisto quando um mapa piloto fecha ou quando a UI muda de estrutura.
