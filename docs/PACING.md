# ScanDig — Ritmo e Progressão (alvo: 5 a 7 horas)

Documento partilhado entre Dev A e Dev B. Os números são o **alvo de design**; afinem
com testes reais e atualizem a tabela.

## 1. Estrutura das ~6 horas

| Mapa | Tempo alvo | Inimigos | Chefe | Desbloqueia com |
| :--- | :--- | :--- | :--- | :--- |
| 1. Praia | 60–80 min | Caranguejo | Caranguejo-Rei | Início |
| 2. Campo Antigo | 80–100 min | Cobra, Toupeira | Toupeira Gigante | R$ 2.000 + vencer o chefe da Praia |
| 3. Ruínas | 90–110 min | Guardião de pedra, Morcegos | Guardião Ancestral | R$ 8.000 + chefe do Campo |
| 4. Cratera | 90–120 min | Criaturas "estranhas" | O Que Dorme Lá Em Baixo | R$ 25.000 + chefe das Ruínas |
| Final / museu 100% | +30–60 min | — | — | Opcional (completistas) |

Regra geral: **cada mapa novo paga ~3x mais por item**, mas os upgrades e o mapa seguinte
custam ~4x mais. Assim o tempo por mapa cresce devagar e o jogador sente-se mais rico.

## 2. Economia por mapa (Dev A: `items/maps/*.tres`; Dev B: `core/game_state.gd`)

Um "ciclo" = detetar + cavar 3 itens + voltar à base ≈ **3 min** na Praia.

| Mapa | Valor médio/item | R$ por minuto | Detector mínimo | Gasto total no mapa (upgrades + desbloqueio do seguinte) |
| :--- | :--- | :--- | :--- | :--- |
| Praia | ~50 | ~50 | Nv.1 | 3.400 + 2.000 = 5.400 (≈ 70 min + tempo a explorar) |
| Campo | ~150 | ~130 | Nv.1 (Nv.2 pendente da #27) | 2.800 + 8.000 = 10.800 |
| Ruínas | ~468 | ~350 | Nv.4 | 5.000 + 25.000 = 30.000 |
| Cratera | ~1.248 | ~900 | Nv.5 | 80.000 |

Os upgrades seguem a tabela aprovada na #25. Cada nível exige o mapa da linha onde aparece
(ex.: detector Nv.4 e mochila de 6 slots só com o Campo desbloqueado).

Estado atual (Praia, `items/maps/praia.tres`): lata x5, chave x4, moeda x2, aliança x1
(média ≈ 53 R$). **O Relógio de Ouro (2.500) saiu da Praia** — passa para as Ruínas.
Variante rara (x3, 5%) e escavação perfeita (+25%) são bónus por habilidade.

- **Ruínas** (`items/maps/ruinas.tres`, #26): fivela de prata x8, relógio de bolso x5,
  ídolo de ouro x4, cálice de prata x2, relógio de ouro x1 (média ≈ 468 R$). Variante rara 6%.
- **Cratera** (`items/maps/cratera.tres`, #26): fragmento de meteorito x7, caixa de música
  x6, liga desconhecida x5, engrenagem alienígena x2 (média ≈ 1.248 R$). Variante rara 7%.
  O Orbe Vibrante (10.000) fica fora do pool: é o prémio do chefe final.
- **Detector mínimo** (`required_detector_level`): Ruínas Nv.4 (comprado no Campo) e
  Cratera Nv.5 (comprado nas Ruínas). O Campo passa a Nv.2 só depois da #27: primeiro o
  Dev A ajusta o `test_map_campo`, depois o Dev B muda o `campo.tres`.
- **Ritmo da Praia:** a #19 mediu 20–24 R$/min, abaixo dos ~50 da tabela. Pela decisão B
  da #25/#27, os preços não caem: a renda da Praia sobe com os upgrades (detector, pá e
  pinpointer com efeito no gameplay).

**Pedido ao Dev B:** com estes valores, os custos atuais da loja
(detector 300/600/1200, pinpointer 500, pá 800 = 3.400) encaixam na Praia. Os níveis
seguintes (mapa 2+) devem seguir a tabela acima. A capacidade da mochila (3) deve ser um
upgrade da loja (4 → 5 → 6 slots).

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
