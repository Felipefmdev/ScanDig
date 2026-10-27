# Fontes — o que ler, ver e ouvir (com licença)

Prioridade: **E** = essencial para este projeto; **A** = aprofundar; **C** = consulta.
Não há links para livros pagos: compra, biblioteca ou pré-visualização legal.

## 1. Level design

| P | Fonte | Formato | Onde | Porque |
|---|---|---|---|---|
| E | *The Level Design Book* (Robert Yang e contribuidores) | livro aberto | [book.leveldesignbook.com](https://book.leveldesignbook.com) | blockout, métricas, marcos, critical path; o mais direto ao ponto |
| E | Christopher W. Totten — *An Architectural Approach to Level Design* | livro | CRC Press | composição, espaço, escala, interiores (Ruínas) |
| A | Christopher W. Totten — *Level Design: Processes and Experiences* | livro | CRC Press | processo e casos de estudo |
| A | Dan Taylor — *Ten Principles of Good Level Design* | talk GDC | GDC Vault / resumos | checklist clássico de ritmo e ensino |
| A | Mark Brown — *Boss Keys* | vídeo | [YouTube/GMTK](https://www.youtube.com/@GMTK) | estrutura de mundo e locks & keys |
| C | Talks de *kishōtenketsu* em níveis da Nintendo (ex.: Super Mario 3D Land) | talk | GDC Vault | ritmo introdução→twist→conclusão |
| C | GDC Vault — trilha Level Design | talks | [gdcvault.com](https://www.gdcvault.com) | casos por género; alguns gratuitos |

## 2. Game design e ritmo

| P | Fonte | Formato | Porque |
|---|---|---|---|
| E | Jesse Schell — *The Art of Game Design: A Book of Lenses* | livro | lentes para justificar decisões |
| A | Daniel Cook — *Loops and Arcs* | artigo (Lostgarden) | liga loops de curto prazo a arcos longos |
| A | Tynan Sylvester — *Designing Games* | livro | sistemas, feedback, economia |
| A | Richard Lemarchand — *A Playful Production Process* | livro | prototipar, playtest, cortar |
| C | Tracy Fullerton — *Game Design Workshop* | livro | exercícios de prototipagem |

## 3. UX, interface e perceção

| P | Fonte | Formato | Onde | Porque |
|---|---|---|---|---|
| E | Celia Hodent — *The Gamer's Brain* | livro | CRC Press | atenção, carga cognitiva, onboarding |
| E | Matthew Butterick — *Practical Typography* | livro web | [practicaltypography.com](https://practicaltypography.com) | escala, entrelinha, hierarquia |
| E | Adam Wathan & Steve Schoger — *Refactoring UI* | livro/curso | [refactoringui.com](https://www.refactoringui.com) | regras práticas de espaçamento, cor, profundidade |
| A | Steve Krug — *Don't Make Me Think, Revisited* | livro | — | usabilidade sem cerimónia |
| A | *Game Accessibility Guidelines* | site | [gameaccessibilityguidelines.com](https://gameaccessibilityguidelines.com) | mínimo de acessibilidade |
| A | Microsoft — *Xbox Accessibility Guidelines (XAG)* | doc | Microsoft Learn | requisitos concretos de contraste, texto, input |
| C | [Game UI Database](https://www.gameuidatabase.com) / [Interface In Game](https://interfaceingame.com) | base de imagens | — | referência por ecrã, não por jogo |
| C | [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) | ferramenta | — | medir, não estimar |

## 4. Game feel e feedback

| P | Fonte | Formato | Porque |
|---|---|---|---|
| E | Steve Swink — *Game Feel* | livro | resposta, timing, sensação de controlo |
| A | Martin Jonasson & Petri Purho — *Juice it or lose it* | talk | feedback exagerado com propósito |
| A | Jan Willem Nijman — *The Art of Screenshake* | talk | impacto sem ruído |
| C | *The Door Problem* (Liz England) | artigo | affordances e sistemas explicáveis |

## 5. Godot 4.3 (documentação)

| P | Página | Porque |
|---|---|---|
| E | [GUI skinning](https://docs.godotengine.org/en/4.3/tutorials/ui/gui_skinning.html) | Theme, StyleBox, type variations |
| E | [Multiple resolutions](https://docs.godotengine.org/en/4.3/tutorials/rendering/multiple_resolutions.html) | stretch, anchors, 720p/1080p |
| A | [Custom GUI controls](https://docs.godotengine.org/en/4.3/tutorials/ui/custom_gui_controls.html) | controlos próprios sem quebrar foco |
| A | [Input examples](https://docs.godotengine.org/en/4.3/tutorials/inputs/input_examples.html) | teclado/comando |
| C | [Environment and post-processing](https://docs.godotengine.org/en/4.3/tutorials/3d/environment_and_post_processing.html) | luz e cor por bioma |

## 6. Interno (obrigatório)

- `docs/GAME_DESIGN.md` — o que existe em cada mapa.
- `docs/MAP_METRICS.md` — números reais.
- `docs/MAP_LAYOUT_GUIDE.md` — processo.
- `docs/maps/PRAIA_BEATS.md` — exemplo preenchido.
- `docs/AUDITORIA_DESIGN_158.md` — diagnóstico visual anterior.
- `docs/HOW_TO_FISH_MAP_ANALYSIS.md` — inspiração, não portagem.

## 7. Como estudar (protocolo)

1. **15 min** de leitura → escreve 3 regras com um exemplo do ScanDig.
2. **15 min** de análise → 6 capturas de um jogo de referência, beats marcados.
3. **30 min** de aplicação → muda um beat ou um ecrã e mede.
4. Regista a regra em `AGENT_CONTEXT.md` se for transversal; senão, no documento da área.

Sem o passo 3, é consumo de conteúdo, não estudo.
