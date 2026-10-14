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

| Mapa | Valor médio/item | R$ por minuto | Gasto total no mapa (upgrades + desbloqueio) |
| :--- | :--- | :--- | :--- |
| Praia | ~50 | ~50 | ~3.400 upgrades + 2.000 = ~5.400 (≈ 70 min + tempo a explorar) |
| Campo | ~150 | ~130 | ~11.000 |
| Ruínas | ~450 | ~350 | ~30.000 |
| Cratera | ~1.300 | ~900 | ~80.000 |

Estado atual (Praia, `items/maps/praia.tres`): lata x5, chave x4, moeda x2, aliança x1
(média ≈ 53 R$). **O Relógio de Ouro (2.500) saiu da Praia** — passa para as Ruínas.
Variante rara (x3, 5%) e escavação perfeita (+25%) são bónus por habilidade.

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
