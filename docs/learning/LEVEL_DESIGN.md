# Level design — teoria aplicada ao ScanDig

Este capítulo explica *porque* as regras de `AGENT_CONTEXT.md` existem. Os números
concretos vivem em `docs/MAP_METRICS.md`; aqui estão os critérios.

## 1. As cinco perguntas de um mapa

Um jogador em qualquer ponto tem de responder, sem consultar o menu:

1. **Onde estou?** — bioma, luz, som, paleta e um marco reconhecível.
2. **Para onde vou?** — uma direção dominante, não cinco iguais.
3. **O que posso fazer aqui?** — cavar, vender, falar, subir, atacar.
4. **O que ganhei?** — recompensa visível em ≤ 60 s da primeira ação.
5. **O que arrisco?** — perigo legível e com resposta possível.

Se uma destas falha, o problema é de layout, não de arte. Antes de acrescentar detalhe,
resolve a pergunta.

## 2. Blockout: primeiro a planta, depois a fachada

O blockout (greybox) existe para responder às perguntas acima com caixas e colisão, sem
material, sem som, sem decoração. Se o mapa não funciona a cinzento, não funciona.

**Ordem obrigatória**

1. Planta em papel/2D: beats, caminhos, portas, arenas, zonas de escavação.
2. Métricas: larguras, alturas, distâncias (ver `MAP_METRICS.md`).
3. Greybox jogável: só formas, um material, sem props.
4. Passeio de leitura: entrar sem HUD e narrar em voz alta o que se vê.
5. Só então arte, som e efeitos.

**Sinais de que o blockout está errado**

- Andas às voltas para achar a saída ou a banca.
- Não sabes onde é seguro cavar.
- O chefe vê-te antes de o veres.
- Tens de subir a um sítio para perceber o mapa.
- O caminho principal e o atalho parecem iguais.

## 3. Beats: a unidade de composição

Um mapa de 60–100 min não é um espaço contínuo: é uma sequência de beats de 4–10 min.
O modelo japonês *kishōtenketsu* (introdução, desenvolvimento, twist, conclusão) ajuda a
variar sem mudar de sistema: apresenta o elemento, repete-o com variação, surpreende,
fecha.

| Beat | Função | Duração | Exemplo na Praia |
|---|---|---|---|
| Chegada | orientar, dar o tom | 2–4 min | cais, barco, primeira vista do naufrágio |
| Serviço | preparar, vender, dialogar | 3–6 min | Pescador Zé, banca de armas |
| Exploração | loop principal, ensinar | 10–20 min | baixio, garrafas, conchas |
| Descoberta | recompensa fora do loop | 5–10 min | casco do navio, relíquia |
| Risco | testar o que se aprendeu | 5–12 min | arena do Caranguejo-Rei |
| Segredo | recompensar atenção | 5–15 min | 3 conchas → Polvo do Naufrágio |
| Saída | fechar, apontar o próximo | 1–3 min | venda, barco, mapa seguinte |

Regras:

- **Um beat não rouba o foco do outro.** Serviço e chefe no mesmo pátio confundem.
- **Alterna tensão e descanso.** Depois de uma arena, dá 30–60 s de espaço calmo antes
  do próximo perigo.
- **O beat de descoberta não é obrigatório**: se for obrigatório, é critical path.
- **O segredo vive à margem**: visível de perto, invisível de longe.

## 4. Marcos e orientação sem HUD

Um marco é uma forma grande, distinta em silhueta, que se lê a 60–80 m. Precisa de:

- **contraste de forma** (vertical contra horizontal, orgânico contra construído);
- **contraste de valor** (claro contra escuro), não só de cor;
- **posição** no eixo de visão do caminho principal;
- **som** próprio quando perto (sinos, gaivotas, água).

Máximo de **um marco dominante por beat**; dois competem, três não se leem. Usa a
paisagem de fundo para “prometer” o próximo beat (a montanha que se vê antes da subida).

**Teste dos 3 níveis de leitura:** em cada ponto, o jogador deve conseguir ler
(a) o chão imediato (2–4 m), (b) o percurso (10–30 m), (c) o horizonte (80 m+). Se um
nível estiver tapado por props, há ruído.

## 5. Critical path, atalhos e segredos

- **Critical path** claro e contínuo; nunca obrigues a voltar sem recompensa.
- **Locks & keys**: um obstáculo (porta, ponte, chefe) e a chave visível antes de a
  poder usar. O jogador deve saber *o que* falta, não *onde* está tudo.
- **Atalhos** (cordas, rampas, túneis) recompensam exploração; não podem partir o ritmo
  de quem não os encontra.
- **Backtracking** só com mudança de estado: nova luz, novo som, novo inimigo, novo NPC.
- **Segredos** fora do critical path, com pista local. “Parede falsa sem pista” é
  adivinhação; “parede rachada + som oco” é descoberta.

## 6. Espaço vazio é conteúdo

O ScanDig vive de **cavar**: o jogador precisa de chão livre, linha de visão e espaço
para recuar. Regras práticas:

- **≥ 50%** da área jogável sem props decorativos.
- **≥ 2 m livres** em volta de cada spot de escavação.
- **≥ 3 m** entre grupos de props no caminho principal.
- Nada de colisão invisível a bloquear o chão onde o detetor apita.

O vazio não é “mapa inacabado”: é onde a mecânica acontece. Preenche com relevo e som,
não com caixas.

## 7. Ensinar sem tutorial

- **Signifiers**: o objeto mostra a ação (pá na mão, contorno no interativo).
- **Repetição segura**: o primeiro uso de uma mecânica acontece sem perigo.
- **Erro barato**: o primeiro falhanço custa tempo, não a vida.
- **Escalada**: a mesma mecânica com uma variável nova (mais fundo, mais escuro, mais
  inimigos), não com cinco sistemas novos.
- **Feedback imediato**: se o jogador não vê a consequência em 250 ms, não aprendeu.

## 8. Ritmo de dificuldade

Curva de tensão em dente de serra, não em rampa. Cada mapa deve ter:

1. um pico de tensão no meio (chefe/evento) e outro no fim (chefe principal);
2. um vale de descanso antes de cada pico;
3. uma recompensa depois de cada pico (dinheiro, item, passagem).

Densidade de inimigos não é dificuldade: é frequência de interrupção. Prefere **poucos
encontros legíveis** a muitos encontros triviais.

## 9. Coop

- **Passagens** com ≥ 3 m ou alternativas; ninguém fica preso atrás do outro.
- **Papéis** claros: quem cava, quem cobre, quem carrega. O mapa deve permitir os dois.
- **Comunicação pelo mundo**: marcos e sons partilhados, não setas privadas.
- **Estados replicados**: um segredo aberto por um jogador tem de ser óbvio para o outro.
- **Não separar a equipa** com portas que fecham sem aviso.

## 10. Erros comuns (e o antídoto)

| Erro | Antídoto |
|---|---|
| Mapa “bonito” mas ilegível | passeio de leitura sem HUD |
| Props no caminho de escavação | zonas de exclusão à volta dos spots |
| Tudo à mesma altura | 3 níveis, com rampas legíveis |
| Chefe numa sala pequena | arena ≥ 18 m, obstáculos na periferia |
| Segredo sem pista | som + forma + pista de NPC |
| Voltar atrás sem novidade | mudar estado (luz, inimigo, porta) |
| Excesso de scatter | orçamento de props por beat |

## 11. Aplicação ao ScanDig

- **O detetor é o guia.** O alcance (8→23 m) define o ritmo de descoberta: spots a menos
  de 10 m sobrepõem blips; a mais de 30 m obrigam a caminhada sem feedback.
- **Cavar exige chão.** Cada spot precisa de uma “clareira” de 4–6 m, mesmo em Ruínas e
  Cratera.
- **Chefes precisam de arena e de leitura.** O Caranguejo-Rei, a Toupeira e o Mamute
  usam investidas/irrupções: 18–25 m de diâmetro, com cobertura na periferia e nada no
  centro.
- **Relíquias fora do detetor** (interagir com cenário) são beats de descoberta: dá-lhes
  um marco próprio e uma pista local.
- **O mapa final (Ilha)** é curto (30–45 min): 3–4 beats, um deles o Colosso. Não o
  trates como um mapa de 90 min comprimido.

## 12. Exercícios (para modelos e humanos)

1. Desenha a planta da Praia em 10 caixas e 5 marcadores. Compara com
   `docs/maps/PRAIA_BEATS.md` e lista as diferenças de percurso.
2. Escolhe um mapa comercial do mesmo género e marca os beats em 6 fotogramas. Identifica
   o marco de cada beat e o que te fez olhar para lá.
3. Pega num beat atual do ScanDig e remove 30% dos props. O loop de escavação melhora ou
   piora? Justifica com tempo-até-à-primeira-descoberta.
4. Escreve o teste de aceitação de um beat em uma frase: “um jogador novo encontra X em
   menos de Y segundos sem HUD”.
