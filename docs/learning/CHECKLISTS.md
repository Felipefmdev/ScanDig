# Checklists de revisão

Usa antes de pedir revisão e antes de fechar a issue. Cada item tem de ser respondido
com **sim/não + evidência** (captura, medição ou ficheiro:linha), não com “acho que sim”.

## A. Portão de blockout (mapa)

- [ ] Existe planta/beat sheet com os beats e as ligações.
- [ ] Cada beat tem uma função única e uma duração alvo.
- [ ] Larguras ≥ 3 m no caminho; arena de chefe ≥ 18 m.
- [ ] Spawn vê pelo menos um marco; marco a cada 20–35 m.
- [ ] ≥ 50% da área jogável sem props; ≥ 2 m livres por spot.
- [ ] Verticalidade ≤ 3 níveis, com subidas legíveis.
- [ ] Critical path contínuo; atalhos não o substituem.
- [ ] Nenhuma parede invisível em zona de escavação.
- [ ] Coop: passagens alternativas ou espera; nada fecha sem aviso.

**Teste:** percurso de 3 min sem HUD, narrando em voz alta. Regista onde hesitaste.

## B. Legibilidade (mapa)

- [ ] Chão, percurso e horizonte leem-se em separado.
- [ ] Em cinza, os beats continuam distintos.
- [ ] Interativos, spots e inimigos têm silhueta/som próprios.
- [ ] Perigo telegrafado com janela de resposta.
- [ ] Segredos com pista local (forma + som + texto).
- [ ] Nenhum prop tapa um interativo, spot ou saída.
- [ ] Capturas de 3 câmaras fixas (spawn, meio, chefe) antes/depois.

## C. Arte e performance

- [ ] Um ponto focal por vista; um hero prop por beat.
- [ ] Kit encaixa sem folgas, z-fighting ou peças flutuantes.
- [ ] Paleta com acento quente/frio; contorno consistente.
- [ ] Scatter com exclusões (caminho, spots, arenas).
- [ ] Pior ponto (chefe + efeitos + 2 jogadores) dentro do orçamento de FPS.
- [ ] Sombras/colisão só onde importa.

## D. UI — hierarquia e legibilidade

- [ ] Uma ação primária por ecrã, visível em 5 s.
- [ ] Três tamanhos de texto, no máximo.
- [ ] Contraste de texto ≥ 4,5:1; ícones/foco ≥ 3:1 (medido).
- [ ] Cor não é o único sinal de estado.
- [ ] HUD não tapa o centro nem o chão imediato.
- [ ] Texto sobre 3D tem fundo/contorno.
- [ ] 720p legível; 1080p e ultrawide sem sobreposição.
- [ ] Localização +30% sem cortar; acentos corretos.

## E. UI — interação

- [ ] Seis estados em todos os controlos.
- [ ] Foco visível, ordem lógica, alcançável só com comando.
- [ ] Escape/B volta um nível; nada fecha sem confirmação.
- [ ] Alvos ≥ 44×44 px, 8 px de separação.
- [ ] Feedback em ≤ 250 ms; animação não bloqueia.
- [ ] Erros previnem-se; confirmação só com perda.
- [ ] Som consistente por tipo de ação.
- [ ] Opções: remapeamento, escala de texto, reduzir movimento.

## F. Registo de revisão (copiar para a issue)

```
Mapa/ecrã:
Commit:
Câmaras/resoluções:
Itens falhados:
Evidência (ficheiro:linha, captura):
Decisão: aprovado / aprovado com ressalvas / rejeitado
Ressalvas e dono:
```

## G. Critérios de bloqueio (não negociáveis)

- Texto ilegível a 720p ou contraste abaixo de 4,5:1 em texto essencial.
- Ação principal não identificável em 5 s.
- Jogador preso sem saída ou sem feedback.
- Perda de progresso sem confirmação.
- Chefe sem telegrafia ou sem arena jogável.
- Regressão de nós/transforms no `map_*.tscn` sem explicação.
