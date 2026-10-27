# Arte de mapa — composição, kits e legibilidade

O objetivo não é “mais detalhe”: é **ler melhor**. Um mapa low-poly facetado com
silhuetas fortes vence um mapa denso que não se percebe. A direção de arte do jogo está em
`docs/GAME_DESIGN.md` §2; este capítulo é o método.

## 1. Três camadas de leitura

Em cada vista, separa:

| Camada | Distância | O que comunica | Como |
|---|---|---|---|
| Chão | 0–4 m | onde pisar, onde cavar | contraste de material, relevo, bordas |
| Percurso | 5–30 m | para onde ir, o que evitar | massa de props, corredores, sombras |
| Horizonte | 80 m+ | identidade e promessa | marcos, montanhas, skyline |

Cada camada tem um orçamento de contraste. Se o chão e o horizonte têm a mesma
complexidade, o olho não sabe onde pousar.

## 2. Composição

- **Um ponto focal por vista.** Constrói em torno dele; o resto é suporte.
- **Assimetria com peso.** Evita o “campo de batatas” uniforme: grupos de 1–3 objetos
  grandes + 3–5 pequenos, com espaços entre grupos.
- **Linhas de guia.** Caminhos, cristas de duna, valas, filas de rochas conduzem o olho.
- **Enquadramento.** Usa “portais” naturais (arcos, árvores, rochas) para revelar o
  próximo beat.
- **Escala humana.** Um barril, uma porta, um banco: sem referência, o jogador não lê o
  tamanho. Repete um objeto conhecido em cada beat.

## 3. Kits modulares (quando usar)

Kits valem quando há repetição: Ruínas, base, estação, interiores.

**Regras de kit**

1. Grade fixa (1 m ou 2 m) e módulos que encaixam sem folga.
2. **Uma peça, uma função**: parede, canto, porta, telhado, chão, escada.
3. **Variações por desgaste**, não por forma nova (3 estados: novo, gasto, arruinado).
4. **Trim sheet** ou atlas por kit: poucas texturas, muitas peças.
5. Pivô na base, eixo +Y para cima, escala 1.0 na exportação GLB.
6. Testa o kit montando **um canto de 3×3 m** antes de produzir 40 peças.

**Quando não usar:** mapas orgânicos (Praia, Geleira, Cratera). Aí manda a forma grande:
dunas, cristas, crateras, geleiras.

## 4. Kit-bashing com hero props

- **Hero prop**: o objeto único do beat (naufrágio, poço, altar, mamute). Modela à mão,
  com silhueta própria, e dá-lhe luz/som.
- **Props de suporte**: kit + Kenney, com o material toon por override.
- **Regra 1:3:9** — 1 hero, 3 médios, 9 pequenos por beat. É um orçamento, não uma
  obrigação.

## 5. Scatter (ProtonScatter / decoração procedural)

O scatter é para **textura de superfície**, não para contar histórias.

- **3 densidades**: base (relva/areia), médio (arbustos/pedras), detalhe (conchas,
  flores, lixo) — cada uma com a sua regra de exclusão.
- **Exclusões**: caminho principal, spots, arenas, interativos, bordas de água.
- **Variação**: rotação e escala aleatórias dentro de limites; nunca escala uniforme.
- **Repetição visível** é o maior defeito: limita o mesmo prop a ~15% da área.
- **Custo**: MultiMesh para o detalhe, cenas instanciadas para o médio, hero à mão.

## 6. Cor e luz

- **Paleta por bioma** com um acento quente e um frio; o resto é neutro.
- **Cor script**: a luz conta a progressão (manhã → tarde → noite; ou claro → tempestade).
- **Valor antes da cor**: converte a captura para cinza. Se os beats não se distinguem a
  preto e branco, falta contraste de valor.
- **Cor não é o único sinal**: interativos, perigo e raridade precisam de forma/som.
- **Contraste local**: o objeto interativo tem sempre uma borda ou luz que o separa do
  fundo.

## 7. Legibilidade dos sistemas

| Elemento | Precisa de |
|---|---|
| Spot de escavação | monte distinto + 2 m livres + som ao aproximar |
| Interativo | contorno/silhueta + prompt + som |
| Inimigo | silhueta única por tipo + telegrafia antes do ataque |
| Chefe | escala 2–3× + arena + fase legível |
| Segredo | pista local (rachadura, som, padrão) + recompensa clara |
| Saída/transição | marco + luz + som, nunca só uma seta |

## 8. Performance (orçamento prático)

- **Draw calls**: agrupa por material; evita centenas de MeshInstance únicos no detalhe.
- **Sombras**: só o que o jogador vê; desliga sombras de scatter pequeno.
- **Oclusão**: usa oclusores nas paredes de Ruínas; não confies em culling automático.
- **Colisão**: formas simples (box/capsule/convex) para props; trimesh só no terreno e
  no que é escalável.
- **Mede antes de otimizar**: FPS no pior ponto (chefe + efeitos + 2 jogadores).

## 9. Consistência entre os 6 mapas

- **Gramática comum**: mesma escala de props, mesma espessura de contorno, mesma
  intensidade de desgaste.
- **Identidade por bioma**: paleta, material dominante, silhueta de marco.
- **Transições**: a passagem de mapa deve reutilizar um elemento do anterior (madeira do
  cais → madeira da cabana; pedra das Ruínas → pedra da Cratera).
- **UI diegética**: papel, madeira e metal da UI vêm do mesmo mundo; não inventes uma
  terceira linguagem.

## 10. Checklist rápido de arte

- [ ] A vista tem um ponto focal claro e um marco.
- [ ] Chão, percurso e horizonte leem-se em separado.
- [ ] Há espaços vazios suficientes para cavar e fugir.
- [ ] Nenhum prop tapa um interativo ou um spot.
- [ ] O kit encaixa sem folgas e sem z-fighting.
- [ ] A paleta tem acento quente/frio e neutros suficientes.
- [ ] Em cinza, os beats continuam distintos.
- [ ] O pior ponto mantém o orçamento de performance.
