# ScanDig — Design do jogo completo (5 mapas, 7 a 9 horas)

Documento mestre do Dev A (aprovado pelo Felipe em 2026-10-15). O `docs/PACING.md` continua a ser
a fonte dos números de economia; este documento define **o que existe em cada mapa**.
Tudo o que está aqui é o alvo: afinem com o bot e com testes humanos e atualizem.

## 1. Regras gerais

- **5 mapas**, cada um único: inimigos próprios, itens próprios, chefe com uma mecânica diferente,
  cenário com que se interage.
- **Duração total 7–9 h** (história principal ~7,5 h + missões e segredos ~1 h). Ninguém precisa de
  fazer 100 % para acabar.
- **Armas:** cada mapa tem uma banca. A banca vende **todas as armas dos mapas anteriores + 1 arma
  exclusiva nova** desse mapa. Do Campo em diante há sempre pelo menos 2 armas à venda.
- **Missões de NPC: poucas.** 1 NPC por mapa, 1–2 missões cada (máx. ~8 no jogo). Cada missão dispara
  um **evento no mapa**: ou **rounds de inimigos** (ondas crescentes) ou um **chefe adicional**.
  Dão dinheiro e um item único de museu: ajudam, mas não são obrigatórias.
- **Segredos por mapa:** 1 **chefe secundário escondido**, 3 **relíquias escondidas** (não saem no
  detector: exigem interagir com o cenário), 2–3 **easter eggs**.
- **Coop:** tudo o que é evento, segredo ou chefe corre no host (contrato da #5) e funciona em solo.

## 2. Direção de arte (seguir `docs/art/reference/`)

Referências: `caranguejo.jpg`, `pa.jpg`, `kit_medico.jpg`, `repelente.jpg`, `estilingue.jpg`.

- **Low-poly facetado:** faces planas bem visíveis, poucas arestas, silhuetas simples e legíveis.
- **Contorno preto desenhado** em todos os objetos (2–3 px, mais grosso na silhueta).
- **Sombreado cel** em 2–3 tons por cor (luz, meio-tom, sombra), sem gradientes suaves.
- **Desgaste:** ferrugem nas arestas, tinta lascada, pintas/salpicos, fita e ligaduras, autocolantes
  rasgados ("CRAB OFF!"). Nada parece novo.
- **Personagens cartoon:** olhos grandes e esbugalhados nos bichos, proporções exageradas
  (pinça gigante do caranguejo).
- **Paleta quente e de saturação média:** laranjas, vermelhos queimados, verdes-garrafa, madeira
  castanha, metal cinzento-azulado. Ícones e fundos de UI em bege papel.
- **Implementação:** um shader toon partilhado (`world/shaders/toon.gdshader`) com luz em degraus,
  ruído de manchas/ferrugem por parâmetro, e um material de contorno (casco invertido, `next_pass`)
  aplicado aos modelos próprios. Os modelos Kenney recebem o mesmo material por override quando der.

## 3. Os 5 mapas

| # | Mapa | Tempo | Inimigos | Chefe principal | Chefe escondido | Arma exclusiva | Desbloqueio |
| :- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Praia | 60–70 min | Caranguejo, Ermitão, Gaivota | Caranguejo-Rei (investidas, enxame) | Polvo do Naufrágio | **Estilingue** (+ Armadilha de Rede) | Início |
| 2 | Campo Antigo | 80–90 min | Cobra, Toupeira, Corvo | Toupeira Gigante (túneis, irrompe) | Espantalho Desperto | **Forcado** (corpo a corpo de alcance, empurra) | R$ 800 + Caranguejo-Rei |
| 3 | Ruínas | 90–100 min | Guardião de pedra, Morcego | Guardião Ancestral (pontos fracos que acendem, placas) | Múmia do Ídolo | **Lanterna de Magnésio** (flash em cone que atordoa; morcegos fogem) | R$ 8.000 + Toupeira Gigante |
| 4 | **Geleira Eterna** (novo) | 90–100 min | Lobo do gelo, Pinguim-ladrão, Morsa | Mamute Congelado (gelo que racha, avalanche) | Yeti da Gruta | **Arpão de Corda** (puxa inimigos e itens) | R$ 70.000 + Guardião Ancestral |
| 5 | Cratera | 100–120 min | Criaturas estranhas (rastejantes, flutuantes) | O Que Dorme Lá Em Baixo (fases no fundo da cratera) | O Eco | **Pulso Magnético** (empurra criaturas, puxa metal) | R$ 190.000 + Mamute Congelado |

Total da história ≈ 7–8 h; com missões e segredos ≈ 8–9 h.

## 4. Conteúdo por mapa

### 1. Praia
- **NPC:** Pescador Zé (no barco a remos). Missão "O anzol de ouro": encontrar o anzol enterrado no
  baixio → evento **Maré Vermelha**: 3 rounds de caranguejos a atacar o barco dele. Recompensa: dinheiro
  + Concha Dourada (museu).
- **Interativos:** garrafas com mensagem (ler), conchas que tocam notas, o casco do navio naufragado.
- **Relíquias escondidas:** dentro do navio naufragado; debaixo de uma pedra que se empurra; numa
  garrafa que só aparece na maré baixa.
- **Chefe escondido:** Polvo do Naufrágio: tocar as 3 conchas pela ordem certa (pista nas mensagens das
  garrafas) abre o casco.
- **Easter eggs:** um pato de borracha no mar; um castelo de areia que, cavado, dá uma moeda de chocolate.

### 2. Campo Antigo
- **Banca:** Estilingue, Armadilha de Rede, **Forcado**, Kit Médico, Repelente.
- **NPC:** Dona Lurdes (na base). Missão "Os corvos levaram as chaves": apanhar as chaves que os corvos
  largam → evento **chefe adicional**: Corvo-Rei sobre a lavoura. Recompensa: dinheiro + Sino de Bronze.
- **Interativos:** o poço (deitar uma moeda dá uma pista), o sino da quinta (chama corvos), os menires
  que acendem quando se lhes toca pela ordem do sol.
- **Relíquias escondidas:** no fundo do poço; atrás de um fardo de palha que se rola; dentro do muro em
  ruína.
- **Chefe escondido:** Espantalho Desperto: acender os 8 menires abre a lavoura à noite.
- **Easter eggs:** um círculo nas searas visto do alto; uma ovelha que só aparece se fizeres silêncio.

### 3. Ruínas
- **Banca:** armas anteriores + **Lanterna de Magnésio**.
- **NPC:** Arqueóloga Inês. Missão "A câmara selada": encontrar 3 tábuas com glifos → evento **rounds**:
  guardiões de pedra acordam em 4 ondas na sala do trono. Recompensa: dinheiro + Ídolo de Jade.
- **Interativos:** placas de pressão, alavancas, tochas que se acendem, paredes que se partem com a pá.
- **Relíquias escondidas:** atrás de uma parede falsa; num nicho alto (escalar blocos); no altar das
  tochas.
- **Chefe escondido:** Múmia do Ídolo: colocar o Ídolo de Jade no pedestal da cripta.
- **Easter eggs:** uma pintura rupestre de um detetor de metais; um chapéu de explorador num esqueleto.

### 4. Geleira Eterna (mapa novo)
- **Banca:** armas anteriores + **Arpão de Corda**.
- **NPC:** Velho Bjorn (cabana com lareira). Missão "A expedição perdida": encontrar o diário e o
  trenó → evento **chefe adicional**: Morsa Anciã no lago gelado. Recompensa: dinheiro + Bússola Antiga.
- **Interativos:** gelo fino que racha (cair = perder vida), estalactites que se derrubam em inimigos,
  a lareira (aquecer recupera vida devagar), aurora que revela pegadas.
- **Relíquias escondidas:** num mamute bebé de gelo (partir com a pá), no fundo do lago (arpão), num
  iglu.
- **Chefe escondido:** Yeti da Gruta: seguir as pegadas que só aparecem com a aurora.
- **Easter eggs:** um boneco de neve com cenoura de ouro; um pinguim com chapéu de festa.

### 5. Cratera (final)
- **Banca:** armas anteriores + **Pulso Magnético**.
- **NPC:** Dra. Vega (estação de pesquisa). Missão "Sinal no fundo": calibrar 3 antenas → evento
  **rounds** finais: ondas de criaturas enquanto a antena transmite. Recompensa: dinheiro + Cristal Eco.
- **Interativos:** cristais que ressoam (tocar acorda criaturas ou abre caminho), gravidade baixa em
  zonas, rochas de meteorito que se partem.
- **Relíquias escondidas:** dentro de um geodo, no topo de um pilar (gravidade baixa), atrás de uma
  cortina de cristal.
- **Chefe escondido:** O Eco: tocar os cristais com a sequência do Cristal Eco.
- **Final:** vencer O Que Dorme Lá Em Baixo mostra os créditos e abre o "modo museu completo".
- **Easter eggs:** uma sonda espacial com bandeira; um disco de vinil "Greatest Hits of Earth".

## 5. Sistemas a construir (Dev A)

1. **Direção de arte:** shader toon + contorno e remodelação dos 5 assets de referência.
2. **Interativos:** componente `Interactable` (olhar + `[E]`, estado replicado pelo host).
3. **Missões e NPC:** NPC com balão de fala, objetivos simples (encontrar X, apanhar N, acender Y),
   recompensa pedida ao core (o host valida).
4. **Eventos de rounds:** `WaveEvent` com N rondas, lista de spawns por ronda, contagem, recompensa;
   reutiliza o `EnemySpawner.spawn_from_data` (corre no host).
5. **Chefes adicionais e escondidos:** variantes do `BossAltar` acionadas por gatilhos (sequência,
   item colocado, evento de missão).
6. **Relíquias escondidas:** itens fixos fora do `item_pool`, ligados a interativos.

## 6. Pedidos ao Dev B (core/ui)

- `MapData` do 5.º mapa (`geleira`) e custos de desbloqueio na ordem acima (Geleira R$ 70.000,
  Cratera R$ 190.000; valores do #64, fonte: docs/PACING.md); `required_detector_level` por mapa.
- `ToolData` das armas novas (forcado, lanterna_magnesio, arpao_corda, pulso_magnetico) e a banca por
  mapa (#25): cada mapa vende as armas anteriores + a sua.
- API de missões: `request_complete_quest(quest_id)` validada no host (recompensa uma só vez) e flags
  de segredos/missões no save (`completed_quests`, `found_secrets`).
- Itens de museu novos (recompensas de missão, relíquias, troféus de chefe) no catálogo.

## 7. Tom da gameplay: caótica (estilo How to Fish)

Todos os chefes e vários inimigos têm movimentos únicos e exagerados (o Polvo sai a rodar com os tentáculos, o Caranguejo-Rei vira pião, a Toupeira faz surf debaixo da terra). Física exagerada, knockback cómico do jogador, câmara a tremer, mas cada ataque telegrafado e com janela de exposição. Detalhe e lista: issue "Gameplay caótica".
