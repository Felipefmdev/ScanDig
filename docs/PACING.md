# ScanDig — Ritmo e Progressão (alvo: 7 a 9 horas)

Documento partilhado entre Dev A e Dev B. Os números são o **alvo de design**; afinem
com testes reais e atualizem a tabela.

## 1. Estrutura das ~8 horas

| Mapa | Tempo alvo | Inimigos | Chefe | Desbloqueia com |
| :--- | :--- | :--- | :--- | :--- |
| 1. Praia | 60–80 min | Caranguejo | Caranguejo-Rei | Início |
| 2. Campo Antigo | 80–100 min | Cobra, Toupeira | Toupeira Gigante | R$ 1.200 + detector Nv.2 + vencer o chefe da Praia |
| 3. Ruínas | 90–110 min | Guardião de pedra, Morcegos | Guardião Ancestral | R$ 8.000 + chefe do Campo |
| 4. Geleira Eterna | 90–110 min | A definir (Dev A) | Mamute Congelado (`frozen_mammoth`) | R$ 20.000 + detector Nv.5 + chefe das Ruínas (`ancient_guardian`) |
| 5. Cratera | 90–120 min | Criaturas "estranhas" | O Que Dorme Lá Em Baixo | R$ 55.000 + detector Nv.6 + chefe da Geleira (`frozen_mammoth`) |
| Final / museu 100% | +30–60 min | — | — | Opcional (completistas) |

Ordem (#49): Praia → Campo → Ruínas → **Geleira** → Cratera. Soma: 6 h 50 min a 8 h 40 min
sem o final; 7 h 20 min a 9 h 40 min com ele. **Provisório** até a medição pelo bot (#46).

Regra geral: **cada mapa novo paga ~3x mais por item**, mas os upgrades e o mapa seguinte
custam ~4x mais. Assim o tempo por mapa cresce devagar e o jogador sente-se mais rico.

## 2. Economia por mapa (Dev A: `items/maps/*.tres`; Dev B: `core/game_state.gd`)

Um "ciclo" = detetar + cavar 3 itens + voltar à base ≈ **3 min** na Praia.

| Mapa | Valor médio/item | R$ por minuto | Detector mínimo | Gasto total no mapa (upgrades + desbloqueio do seguinte) |
| :--- | :--- | :--- | :--- | :--- |
| Praia | ~50 | ~50 | Nv.1 | upgrades opcionais + 1.200 (alvo: 70–80 min até o Campo) |
| Campo | ~150 | ~130 | Nv.2 | mochila 1.600 + Ruínas 8.000 = 9.600 |
| Ruínas | ~468 | ~350 | Nv.4 | detector 2.000 + mochila 1.800 + pá 1.200 + Geleira 20.000 = 25.000 |
| Geleira | ~783 | ~570 | Nv.5 | detector 12.000 + mochila 6.000 + Cratera 55.000 = 73.000 |
| Cratera | ~1.248 | ~900 | Nv.6 | detector 25.000 + pá 12.000 + pinpointer 18.000 = 55.000 |

R$/min = 0,73 × valor médio (como nas outras linhas). **Números provisórios** da Geleira e da
Cratera até a medição pelo bot (#46). Upgrades por mapa (#49, `UPGRADES` em
`core/game_state.gd`): detector 300 / 600 / 700 / 2.000 (Ruínas) / **12.000 (Geleira)** /
25.000 (Cratera); mochila 400 / 800 / 1.600 (Campo) / 1.800 (Ruínas) / **6.000 (Geleira)**;
pá 800 / 1.200 (Ruínas) / 12.000 (Cratera); pinpointer 500 / 18.000 (Cratera).

Os upgrades seguem a tabela aprovada na #25, com o ajuste da #46. Cada nível exige o mapa
da linha onde aparece (ex.: mochila de 6 slots só com o Campo desbloqueado). Exceção da #46:
o detector Nv.4 (upgrade nível 3, R$ 700) já se compra na Praia.

Estado atual (Praia, `items/maps/praia.tres`): lata x5, chave x4, moeda x2, aliança x1
(média ≈ 53 R$). **O Relógio de Ouro (2.500) saiu da Praia** — passa para as Ruínas.
Variante rara (x3, 5%) e escavação perfeita (+25%) são bónus por habilidade.

- **Ruínas** (`items/maps/ruinas.tres`, #26): fivela de prata x8, relógio de bolso x5,
  ídolo de ouro x4, cálice de prata x2, relógio de ouro x1 (média ≈ 468 R$). Variante rara 6%.
- **Geleira Eterna** (`items/maps/geleira.tres`, #49): crampon enferrujado x7, lanterna da
  expedição perdida x6, cronômetro do explorador x4, medalha da expedição polar x2, bússola
  congelada x1 (média ≈ 783 R$). Variante rara 6%. Tema gelo / expedição perdida.
- **Cratera** (`items/maps/cratera.tres`, #26): fragmento de meteorito x7, caixa de música
  x6, liga desconhecida x5, engrenagem alienígena x2 (média ≈ 1.248 R$). Variante rara 7%.
  O Orbe Vibrante (10.000) fica fora do pool: é o prémio do chefe final.
- **Detector mínimo** (`required_detector_level`): Ruínas Nv.4 (comprado no Campo),
  Geleira Nv.5 (comprado nas Ruínas) e Cratera Nv.6 (comprado na Geleira). Campo Nv.2 (`campo.tres`, #46; os testes e roteiros do Campo
  compram o detector Nv.2 desde a #27).
- **Ritmo da Praia:** a #19 mediu 20–24 R$/min, abaixo dos ~50 da tabela. Pela decisão B
  da #25/#27, os preços não caem: a renda da Praia sobe com os upgrades (detector, pá e
  pinpointer com efeito no gameplay).

**Custos atuais (#25, ajustados na #46):** Campo por R$ 1.200 com detector Nv.2 (upgrade
nível 1, R$ 300); detector 300 / 600 / **700** (o nível 3 saiu da trava do Campo); pinpointer
500, pá 800 e mochila 400 / 800 continuam opcionais na Praia. **Alvo: 70–80 min da Praia até
o Campo**, a medir de novo pelo Dev A com `tools/bot/praia_300_*.json`.

## 3. Ritmo dentro de uma sessão

- **Ameaça do subsolo:** escavar rápido acorda caranguejos ao fim de ~3–4 escavações
  seguidas; escavar com cuidado permite ~10. O radar sozinho nunca acorda o subsolo.
- **Caranguejo:** velocidade 1.9 m/s (jogador: 4.5), pinçada de 10 a cada 1.6 s. Deve ser
  um incómodo, não uma ameaça mortal na Praia.
- **Chefe:** só aparece quando o jogador **escolhe** invocá-lo (ex.: escavar um ponto
  especial marcado no mapa), nunca por acaso. Combate de 2–4 min. Fases lentas e
  telegrafadas; o chefe da Praia deve ser vencível com a pá de nível 1.
- **Morte:** perde a mochila no local (pode voltar a apanhar) — punição moderada.

## 4. Como medir

1. Joguem a Praia do zero com cronómetro; anotem quando compram cada upgrade.
2. Se o primeiro upgrade (300) demorar menos de 8 min ou mais de 15 min, ajustem os pesos
   do `item_pool` ou os valores do catálogo.
3. Registem aqui os resultados de cada teste (data, mapa, tempo, notas).

## Teste por bot 2026-10-14

> **É um bot, não um humano.** Não sente pressão nem se distrai, não explora, não compra
> nada e conhece sempre o spot mais próximo (não usa o detetor). Usa os mesmos inputs do
> jogador (andar, botão direito para cavar, E para apanhar/entregar), com Shift só nas 2
> últimas camadas (`mode: smart`), o que dá sempre integridade 100 %. Os tempos são um
> **limite inferior** do que um jogador real faz.

Roteiro `tools/bot/praia_300.json` (DebugBridge): ciclo spot mais próximo → cavar → apanhar →
entregar na base quando a mochila (3) enche → repetir, até `money>=300` (dinheiro inicial
100, logo +200 de lucro). Saída em `.bot_runs/`.

| corrida | tempo até 300 | R$/min | itens vendidos | 1.º inimigo | dano | mortes | teleports |
|---|---|---|---|---|---|---|---|
| `praia_300_2026-10-14_15-51-14` (janela) | 1 min 10 s | 222 | 9 | nenhum | 0 | 0 | 0 |
| `praia_300_2026-10-14_19-01-59` (headless) | 48 s | 319 | 6 | nenhum | 0 | 0 | 0 |
| `praia_300_2026-10-14_19-02-00` (headless) | 3 min 29 s | 65 | 23 | nenhum | 0 | 0 | 0 |

Observações:
- **Muito abaixo da meta de 8–15 min**, mesmo descontando a eficiência do bot. Um ciclo
  (3 spots + entrega) leva ~25 s.
- O tempo depende quase só de sair uma **Moeda Antiga** (R$ 188 perfeita): numa entrega
  ela vale mais do que 10 latas (R$ 6, ou 19 com bónus). Sem moeda, ~R$ 65/min.
- O museu absorve parte do valor (vendido 385–457 vs. lucro 226–258) — previsto.
- **Nenhum inimigo apareceu** em 3,5 min: com Shift nas últimas camadas a Ameaça do
  Subsolo nunca chega ao limiar. Cavar "inteligente" anula a pressão dos caranguejos.
- Sugestões: baixar o peso/valor da Moeda Antiga ou o bónus de perfeição na Praia, e/ou
  dar ruído também à escavação cuidadosa; repetir o teste com humanos.

## Rebalanceamento da Praia por bot 2026-10-14 (issue #19)

> Também é **um bot**: não luta nem foge dos caranguejos (por isso morre mais do que um
> humano), mas agora joga mais perto de um humano: **apanha o detetor** no início (ocupa 1
> dos 3 slots e o radar faz ruído) e só "vê" spots a ≤ 8 m (alcance do radar nível 1);
> fora disso **explora** (10 m numa direção aleatória). Roteiro: `tools/bot/praia_300.json`.

Mudanças:

| o quê | antes | depois | ficheiro |
|---|---|---|---|
| ruído da pazada cuidadosa | 2 | 4 (metade da rápida, 8) | `gameplay/disturbance/disturbance_meter.gd` |
| decaimento do ruído na Praia | 2.5/s | 2.2/s | `items/maps/praia.tres` |
| spots ativos na Praia | 8 | 5 | `items/maps/praia.tres` |
| `item_pool` (lata/chave/moeda em 20) | 12 / 6 / 2 | 17 / 2 / 1 | `items/maps/praia.tres` |
| Moeda Antiga `base_value` | 150 | 60 (perfeita = 75) | `items/catalog/moeda_antiga.tres` |

Resultados (3 corridas por configuração, início 100 R$, meta `money>=300`):

| configuração | corrida | até 300 | R$/min | itens | 1.º inimigo | ameaça máx. | dano | mortes |
|---|---|---|---|---|---|---|---|---|
| antiga + bot com radar | `20-32-47` | 3 min 48 s | 57.7 | 14 | 224 s (ambiente) | 0 | 0 | 0 |
| iteração 1 (decay 1.5, 6 spots, 16/3/1) | `20-37-38` | 3 min 46 s | 57.8 | 15 | 28 s | 3 | 145 | 1 |
| | `20-37-40` | 7 min 53 s | 26.7 | 18 | 13 s | 3 | 421 | 4 |
| | `20-37-42` | 6 min 26 s | 35.7 | 17 | 83 s | 2 | 286 | 2 |
| **final** (decay 2.2, 5 spots, 17/2/1) | `20-46-17` (janela) | 11 min 20 s | 19.6 | 25 | 127 s | 1 | 504 | 5 |
| | `20-46-19` | 8 min 36 s | 24.1 | 30 | 134 s | 1 | 195 | 1 |
| | `20-46-21` | 9 min 21 s | 22.5 | 23 | 61 s | 1 | 252 | 2 |

(Pastas `.bot_runs/praia_300_2026-10-14_<hora>`.)

Leitura:
- **Final: 20–24 R$/min, 300 em 8,5–11,5 min**: dentro da meta de 8–15 min. A moeda (R$ 75)
  ainda dá um pico agradável, mas já não decide a corrida sozinha.
- **Inimigos voltam a aparecer**: a ameaça chega ao nível 1 entre 1 e 2,5 min. Na iteração 1
  (decay 1.5) chegava ao nível 3 em ~1,5 min e era demais.
- As mortes do bot (1–5) vêm de não se defender; um humano mata/foge dos caranguejos, por
  isso deve morrer menos, mas perde tempo a lutar. Falta o **teste com humanos**.

## Campo Antigo por bot 2026-10-14 (issue #20)

> Bot (`tools/bot/campo_rate.json`), igual ao da Praia (detetor, radar a 8 m, explora,
> cava `smart`), mas agora **defende-se** (`fight` quando um inimigo está a ≤ 5 m), porque
> as cobras e toupeiras do Campo matavam-no 5-6 vezes por corrida. Início 100 R$, meta
> `money>=1000` (+900).

**Revisão do alvo:** o pedido inicial era 35-45 R$/min (1,5-2x a Praia), mas isso contradiz
a tabela da secção 2 e o custo das Ruínas (R$ 8.000 = ~3h20 a 40/min). Alvo revisto pelo
Lead: **~90-110 R$/min** (a tabela diz ~130; fica um pouco abaixo porque a Praia também
ficou abaixo do previsto depois da #19). Ameaça: nível 1 por volta de 1 min; nível 3 só
abusando da escavação rápida. Só `items/maps/campo.tres` mudou (catálogo intacto).

| configuração | spots | pool ferr/colher/lança/medalha/anel | raro | ruído ×/decay | R$/min (3 corridas) | 1.º nível de ameaça | ameaça máx. | mortes |
|---|---|---|---|---|---|---|---|---|
| original (#18) | 10 | 8/6/4/2/1 | 6% | 1.3 / 2.2 | **~500** (1 corrida, +400 em 53 s) | 11 s | 3 | 0 |
| iteração 1 (bot sem se defender) | 3 | 18/4/2/1/1 | 4% | 1.2 / 2.0 | 33 / 63 / 120 | 4-6 min | 1 | 5-6 |
| iteração 2 (bot defende-se) | 6 | 30/6/2/1/1 | 4% | 1.4 / 2.0 | 168 / 199 / 236 | 51-90 s | 2-3 | 0-1 |
| **final** | **4** | **30/6/2/1/1** | **4%** | **1.3 / 2.0** | **91 / 116 / 127** | **14-93 s** | **1** | **0** |

Final: +900 R$ em 7 min 14 s a 11 min 2 s (`.bot_runs/campo_rate_2026-10-14_22-12-25`
(janela), `-27`, `-29`); 13-16 itens; 38-67 de dano por corrida.

Leitura:
- Com 6+ spots o bot faz ~2,7 itens/min e só a ferradura perfeita (~R$ 41) já dá ~110
  R$/min; por isso o Campo tem **menos spots do que a Praia** (4 vs 5), mas cada spot vale
  ~5x mais. `tests/unit/test_map_campo.gd` passou a aceitar isso (3 ≤ spots ≤ Praia).
- O **anel (R$ 400 perfeito)** e a medalha ainda dão picos (uma entrega de R$ 438), mas
  com peso 1/40 já não decidem a corrida.

### Inimigos e chefe do Campo

- **Cobra** (`snake`): 30 de vida, 3 m/s (jogador 4,5), enrola-se ~0,45 s (aviso) e dá
  um bote de 2,4 m (8 de dano). Atordoada → foge 4 s e some na erva.
- **Toupeira** (`mole`): viaja debaixo de terra (imune; só se vê o monte), pára debaixo do
  jogador, marca vermelha 0,8 s e irrompe (14 de dano). Fica 2,5 s exposta (45 de vida).
- Spawner do Campo: primário cobra, secundário toupeira (nível 2+), ambiente
  cobra/cobra/toupeira, sem gaivotas.
- **Toupeira Gigante** (`giant_mole`, 800 de vida): garras (círculo 2,6 m, 18) quando
  perto; túnel até debaixo do jogador → marca 1,1 s → irrompe (círculo 3 m, 25) → **tonta
  2,4 s com dano x2**. Reforços de 2 toupeiras a 66%/33%. Fase 2 (<50%): túnel mais rápido e
  irrompe 2x seguidas. Trela de 13 m à volta do círculo de pedras.
- Bot (`campo_boss.json`, golpe sempre que pode, sem se desviar) vs. o mesmo bot contra o
  Caranguejo-Rei: **Toupeira Gigante 36 s, 164 de dano, 1 morte**; Caranguejo-Rei 21-22 s,
  72-84 de dano, 0 mortes, ou seja ~1,7x mais difícil. Um humano demora mais (desvia-se,
  falha golpes). Falta o teste com humanos.

## Upgrades na Praia por bot 2026-10-15 (issue #27)

> Mesmo bot da #19 (`praia_300.json`: apanha o detetor, só "vê" spots dentro do alcance do
> radar, explora, cava `smart`, **não luta**). Cada variante (`tools/bot/praia_300_<x>.json`)
> faz `set_state` do upgrade no início e usa como raio do bot o alcance do radar (8 / 10,5 /
> 13 m). Início 100 R$, meta `money>=300` (+200). Headless, 3 corridas por configuração
> (6 na base), todas em paralelo (FPS ~125). Pastas `.bot_runs/praia_300*_2026-10-15_00-{26..41}-*`
(mochila e kit: `_05-03-*`). Itens/min = spots cavados por minuto.

### O que cada upgrade faz agora

| upgrade | efeito |
|---|---|
| Detector Nv.1–7 (`MAX_LEVEL` 3 → 7) | alcance 8 + 2,5 × (Nv − 1) (23 m no Nv.7). Nv.2 material, Nv.3 profundidade e tamanho, **Nv.4 faixa de valor** (`Val: R$22-50`: pior caso com pazadas rápidas até perfeita), **Nv.5 variante rara anunciada a qualquer distância** (`★x3`; antes só com sinal ≥ 0,7), **Nv.6 inimigos a 1,5 × o alcance** (na borda do radar), **Nv.7 nome do item** e `Novo:` se ainda falta no museu |
| Pá (`shovel_level = get_shovel_level()`) | Nv.2 a 4: cooldown ÷ 1,25 / 1,5 / 1,75, dano à integridade × 0,85 / 0,7 / 0,55, golpe +20 % por nível. Lido no `_ready` e em cada `upgrades_changed` |
| Pinpointer Nv.1 | nos últimos 2 m o radar faz zoom (borda = 2,5 m), mira no ponto exato e anel do alcance da pá (dourado quando dá para cavar), e o visor mostra `PIN ↗ 1.3m` / `PIN ✔ CAVE`. Bip 3D que vem do ponto exato, cada vez mais rápido (0,45 → 0,08 s) e mais agudo ao alcance da pá |
| Pinpointer Nv.2 (Cratera) | bússola para a variante rara mais próxima em todo o mapa: triângulo dourado na borda do radar + `★24m` no cabeçalho |
| Mochila até 8 | teclas 4–8 ligadas (só existiam 1–3); a hotbar encolhe os slots (92 → 76 px com 8) para não tapar a vida |

### Resultados

| configuração (custo) | corridas: tempo até 300 | mediana | R$/min (mediana) | itens/min | mortes/10 min | explorações/corrida |
|---|---|---|---|---|---|---|
| **base** (0) | 7:48 / 10:53 / 12:36 / 13:43 / 15:38 / >20:00 | **12:36** | **15,9** | 2,47 | 4,8 | 260 |
| detector Nv.2 (300) | 5:09 / 7:53 / 9:53 | 7:53 | 25,3 (**+59 %**) | 3,62 (+47 %) | 2,2 | 109 |
| detector Nv.3 (900) | 4:47 / 5:16 / 8:22 | 5:16 | 37,9 (**+138 %**) | 3,92 (+59 %) | 1,1 | 73 |
| pá Nv.2 (800) | 6:57 / 7:57 / 10:09 | 7:57 | 25,1 (+58 %, ver nota) | 3,31 | 1,2 | 136 |
| pinpointer Nv.1 (500) | 9:06 / 12:59 / 16:14 | 12:59 | 15,4 (≈ 0) | 2,45 | 3,4 | 247 |
| mochila +1 (400) | 10:19 / 12:22 / 15:59 | 12:22 | 16,2 (≈ 0) | 2,85 (+15 %) | 4,7 | 249 |
| detector Nv.3 + pá Nv.2 + pinpointer (2.200) | 5:08 / 5:46 / 8:54 | 5:46 | 34,6 (+118 %) | 3,89 | 1,0 | 84 |
| **kit da Praia**: detector Nv.3 + pá + pinpointer + mochila +2 (3.400) | 4:02 / 5:53 / 7:15 | 5:53 | 33,9 (+113 %) | 4,69 (+90 %) | 1,7 | 77 |

Leitura:
- **Base: as corridas rápidas anteriores (4:22 e 6:24) foram variância.** Não há bug da Fase 2
  no ritmo: `spots_dug` = `items_picked` − 1 (o detetor), por isso não há pickups duplicados;
  o sorteio do `SpotSpawner` não tem viés; os itens/min (2,2–3,7) são os mesmos da #19
  (2,2–3,5). O tempo depende de duas coisas aleatórias: quantas **Moedas Antigas** (R$ 75)
  saem (nas corridas de 4–6 min saíram 2–4, nas da #19 nenhuma ou uma) e as **mortes**, que se
  alimentam a si mesmas (quanto mais longa a corrida, mais ameaça e caranguejos ambiente, e
  quanto mais mortes, mais longa). Com 6 corridas a mediana é 12:36, um pouco acima das
  8,5–11,5 da #19. As mortes por 10 min subiram de ~2,6 (#19) para 4,8; vale o Dev_Detector
  conferir se a #24 (inimigos no host) mudou o dano em solo.
- **O detector é o upgrade que mais rende**: com mais alcance o bot explora 2,5 a 3,5 vezes
  menos (260 → 73–109 passos de exploração), chega a mais spots por minuto e, por passar
  menos tempo a vaguear, morre menos. O Nv.3 (900 R$ no total) mais do que duplica a renda.
- **Pá: o efeito mecânico é pequeno para o bot**: −11 % de tempo por spot (2,58 → 2,30 s; a
  cadência de cliques do bot limita), ou seja, ~+3–5 % de renda. O +58 % da tabela vem quase
  todo de ter morrido menos nessas 3 corridas (1,2 contra 4,8 mortes/10 min), ou seja, é
  ruído. Para um humano a pá vale mais: menos dano à integridade com pazadas rápidas e +20 %
  de dano no golpe (menos tempo a lutar).
- **Pinpointer: o bot não o consegue medir.** O bot já caminha até 1 m do ponto exato (sabe
  onde está o spot), por isso o resultado é igual à base. Para um humano ele poupa a fase de
  "procurar o ponto": no radar normal, a 8 m de escala, os últimos 2 m ocupam ~25 px. Estimativa:
  2–5 s por spot em ~15–20 s por item, ou seja, **+10–25 %** para um humano. Medir isto exige um
  passo novo no DebugBridge (chegar com erro de ±1,5 m e procurar). Fica como sugestão.
- **Mochila: +15 % de itens/min, renda igual dentro do ruído.** Com o detetor a ocupar 1
  slot, a mochila de 3 só leva 2 itens por viagem; a +1 corta 1/3 das viagens, mas as 3
  corridas tiveram 3–8 mortes (perde-se a mochila). Com o detector Nv.3 já no kit, a mochila
  +2 sobe os itens/min de 3,9 para 4,7.
- **Kit completo (3.400) ≈ detector Nv.3 sozinho em R$/min** (34–38): mais itens/min, mas
  com o pool da Praia (média ~12 R$) a sorte da moeda pesa mais do que a diferença.
- **A Praia continua lenta para a meta de 60–80 min.** O bot junta os 5.400 R$ da Praia
  (3.400 de upgrades + 2.000 do Campo) em ~2h30: ~13 min até ao detector Nv.2, ~24 min até ao
  Nv.3 e ~1h55 para os ~4.500 restantes a ~38 R$/min. Um humano é mais lento. Para chegar aos
  60–80 min a renda depois do detector Nv.3 teria de ser ~90 R$/min. Opções (Dev B / Lead):
  baratear a pá, o pinpointer e a mochila na Praia, ou baixar o desbloqueio do Campo; subir o
  valor do pool da Praia (contradiz a decisão B); ou aceitar uma Praia mais longa e deixar
  parte dos upgrades para o Campo.

## Jogo completo (#62, 2026-10-16)

> Bot = **limite inferior** (sabe onde estão os spots, não se distrai, compra tudo de uma vez).
> Corrido em headless com `--fixed-fps 60`: o DebugBridge mede agora o **tempo de jogo** (soma
> dos delta), por isso 15 min de jogo correm em ~45 s reais. O bot usa um save isolado por
> processo (`user://test_saves/bot_<pid>/`) e já não toca no save do jogador.

### Ritmo dos 5 mapas (`tools/bot/pacing_<mapa>.json`)
Cada roteiro põe o jogador no mapa com os upgrades que teria comprado no anterior e faz o ciclo
detetar → cavar → vender durante 15 min. O tempo do mapa é o gasto previsto nele (upgrades +
desbloqueio do seguinte) a dividir pela renda medida (2–3 amostras por mapa).

| Mapa | upgrades à chegada | R$/min | itens/min | R$/item vendido | mortes/15 min | gasto no mapa | tempo (bot) | alvo |
|---|---|---|---|---|---|---|---|---|
| Praia | — | 22 | 2,5 | ~9 | 0 | 2.700 | **124 min** | 60–80 |
| Campo | det 1, moch 1, pá 1 | 127 | 2,3 | ~55 | 1 | 11.700 | 92 min | 80–100 |
| Ruínas | det 3, moch 3, pá 1 | 1.336 | 2,3 | ~573 | 7,5 | 25.000 | **19 min** | 90–110 |
| Geleira | det 4, moch 4, pá 2 | 2.849 | 2,8 | ~1.124 | 7 | 73.000 | **26 min** | 90–110 |
| Cratera | det 5, moch 5, pá 2, pin 1 | 2.552 | 1,4 | ~1.986 | 14 | 55.000 | **22 min** | 90–120 |

**Total de bot: ~4 h 43 min** de escavação, mais ~2–4 min por chefe (o bot vence o do Campo em
40 s) e as missões. A soma até bate com o limite inferior de 7–9 h para um humano, mas a
**distribuição está errada**: os mapas 1–2 levam 216 min e os 3–5 só 67 min, contra ~140 e
~290 previstos. A causa é a curva de valores, não o ritmo de escavação (o bot faz 2,3–2,8
itens/min em todos os mapas):
- Praia e Campo pagam 3–5x **menos** por item do que a tabela da secção 2 (~50 / ~150): as
  primeiras descobertas vão para o museu e o pool da Praia é quase só latas.
- Das Ruínas em diante, o valor por item salta ~10x mas os gastos só sobem 2–3x.
- Proposta na **#64** (Dev B): ~3,5x nos desbloqueios e upgrades dos mapas 3–5 (ou ÷3 nos
  valores dos itens desses mapas) e Praia ~2x mais rica ou Campo mais barato.
- As mortes nos mapas 3–5 são quase todas da mordida sem aviso do Crawler e do Lobo de Gelo
  (**#63**). Num humano isso alonga esses mapas, mas pela frustração e não pelo desenho.

### Varredura de bugs
- **Solo (25 roteiros, headless):** 0 `SCRIPT ERROR`, 0 erros de script. Dois roteiros
  estavam frágeis perante os empurrões da #57: `campo_quest_solo` (o jogador era atirado da torre
  de fardos antes de olhar para o círculo; agora repete teleporte + olhar num loop) e
  `praia_quest_solo` (a defesa do barco perde-se ~1 em 3 em solo, equilíbrio apertado e não
  bug). Os passos falhados dos `praia_300_*` (1–3) são spots fora do alcance, como antes.
- **Coop (12 pares nos 5 mapas):** o cliente dava `SCRIPT ERROR` ("hide_warning in base Nil") porque o setter de `net_attack_point` corria antes do `_ready`. Corrigido no Corvo-Rei, no Polvo e no Espantalho (Dev_Player) e na Múmia (Dev_Detector). Os pares dos mapas 3–5 (`coop_ruinas_*`, `coop_geleira_*`, `coop_cratera_*`) foram concluídos e validados pelo Dev_Detector com `tools/run_coop.sh`: sincronização no lobby, partida em expedição, combate aos chefes e recolha de troféus com 0 erros e 0 `SCRIPT ERROR`.
- **Telegrafia e cadência de mordidas (#63, Dev_Detector):** Crawler e Lobo de Gelo ganharam estado `BITE_WINDUP` (0,35 s com aviso circular e animação dedicada), cooldown de mordida (1,6 s) e solavanco de repulsão real que quebra o ciclo de dano contínuo. O Guardião de Pedra recebeu aviso circular no chão durante o `WINDUP` do esmagamento (0,8 s com pulso) e o Morcego teve a cadência e altura de voo afinadas. Validado com `test_enemy_bite_telegraph.gd` (3/3) e na simulação da Cratera (48 spots cavados e R$ 23.559 em 15 min).
- **Chefes sem `boss_defeated` (Dev_Detector):** a Morsa Anciã, o Mamute, o Yeti, O Que Dorme e
  O Eco nunca emitiam o sinal no host com frames reais (sem troféu nem progresso). Corrigido, com
  o teste `test_boss_death_real_frames.gd`.
- Janela: o Vulkan dá milhares de `swap_chain_resize ... ERR_CANT_CREATE` quando a janela do bot
  está em segundo plano nesta máquina. É do ambiente, não do jogo.

### Fluxo pela UI (`tools/bot/ui_flow.json`)
Passos novos no DebugBridge: `ui_tab`, `ui_select` e `ui_press` emitem os mesmos sinais que um
clique, e há a condição `in_expedition`. O roteiro faz lobby → aba Expedições → escolher o mapa →
**Partir** → (na Praia cava, apanha e entrega uma lata) → **Voltar à base** → resumo do dia
(**Fechar**), nos 5 mapas, e acaba no Museu e na Loja. Tudo passa: os resumos mostram o dia, o
ganho e a lata doada ao museu (+R$ 3), e o progresso comprado pela UI (desbloquear o Campo)
mantém-se depois de ir e voltar. Capturas em `.bot_runs/ui_flow_*`.
