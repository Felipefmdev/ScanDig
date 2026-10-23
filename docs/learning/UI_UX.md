# UI/UX — princípios e prática no Godot 4.3

A UI do ScanDig já tem identidade (papel, tinta, madeira, manuscritas). O que falta é
**hierarquia, estado e legibilidade**. Este capítulo é o critério; o tema vive em
`ui/theme/`.

## 1. O trabalho da UI

1. **Dizer o que importa agora.** Hierarquia antes de decoração.
2. **Não interromper.** A ação do jogador continua a ser a estrela.
3. **Responder sempre.** Todo o input tem feedback em ≤ 250 ms.
4. **Prevenir o erro.** Confirmação só quando há perda; nunca para ações reversíveis.
5. **Ser previsível.** Mesmo sítio, mesmo gesto, mesmo som.

## 2. Hierarquia

- **Uma ação primária** por ecrã: botão preenchido, maior, com acento.
- **Secundárias** com contorno; **terciárias** como texto/ícone.
- **Tamanhos**: corpo, título, destaque. Três passos, rácio 1,25–1,5 entre eles.
  Exemplo a 1080p: 18 / 24 / 32 px; a 720p: 16 / 21 / 28 px.
- **Peso e cor** antes de tamanho: um título em tinta forte lê-se melhor que um título
  gigante em cinza.
- **Agrupamento**: o que pertence ao mesmo assunto fica junto, com espaço entre grupos
  (Lei da Proximidade). Espaço entre grupos ≥ 2× o espaço dentro do grupo.

**Teste dos 5 segundos:** mostra o ecrã 5 s e pergunta “o que podes fazer aqui?”. Se a
resposta não for a ação primária, a hierarquia falhou.

## 3. Grelha, espaço e resolução

- Grelha de **8 px**; espaçamentos em múltiplos (8, 16, 24, 32).
- **Margem segura**: 5% do lado menor; 10% para TV. Nada de texto a menos de 24 px da
  borda a 720p.
- **Alvo de clique ≥ 44×44 px** (a 1080p), com 8 px entre alvos.
- **Anchors e Containers**, não offsets absolutos: o layout tem de sobreviver a 16:9,
  16:10 e ultrawide.
- **Esticar**: `canvas_items` + `expand` (já configurado) mantém a proporção; testa
  1280×720, 1920×1080 e 2560×1080.
- **Texto nítido**: fontes com MSDF ou tamanhos inteiros; evita escala fracionária.

## 4. Tipografia

- **Manuscrita só para títulos curtos, nomes e números grandes.** Nunca para parágrafos,
  listas de preços ou textos de ajuda.
- **Corpo**: 18–20 px a 1080p, entrelinha 1,25–1,4, comprimento de linha 45–75 caracteres.
- **Números tabulares** em preços, quantidades e temporizadores (evita o “salto” dos
  dígitos). No Godot: `Label` + fonte com `tnum`, ou alinhamento à direita fixo.
- **Maiúsculas** só em etiquetas curtas; nunca em nomes de itens.
- **Contraste de peso**: máximo 2 pesos por ecrã.
- **Localização**: +30% de comprimento; evita texto dentro de imagens; confirma acentos
  e cedilhas nas duas fontes (Kalam e Patrick Hand cobrem Latim).

## 5. Cor e contraste

- **Texto ≥ 4,5:1**; texto grande (≥ 24 px bold) ≥ 3:1; ícones e bordas de foco ≥ 3:1.
- **Cor nunca sozinha**: estado = cor + forma + texto/ícone.
- **Paleta funcional**: tinta (texto), papel (fundo), laranja (ação), vermelho (perigo),
  verde (sucesso), metal (desativado), ouro (destaque).
- **Não uses laranja como texto pequeno sobre papel** — é cor de fundo de ação, não de
  leitura. O mesmo para ouro.
- **Daltonismo**: testa protanopia/deuteranopia; vermelho/verde de estado precisam de
  ícone.

## 6. Estados e foco

Todo o controlo interativo tem seis estados:

| Estado | Sinal |
|---|---|
| Normal | superfície base |
| Hover | 1 degrau de valor + cursor |
| Pressed | deslocamento 1–2 px ou sombra menor |
| Focus | borda de 2–3 px, cor de acento, sempre visível |
| Disabled | contraste reduzido + cursor/sem foco |
| Erro | borda vermelha + mensagem, não só cor |

- **Foco por teclado/comando** com ordem lógica (não a ordem do ficheiro). Usa
  `focus_neighbor_*` e `focus_next` explícitos quando a ordem automática falhar.
- **Nunca esconder o foco** atrás de animação ou de um painel.
- **Escape/B volta** sempre um nível; nunca fecha o jogo sem confirmação.
- O projeto já tem `ui/ui_nav_audit.gd`: usa-o como teste, não como substituto do teste
  manual com comando.

## 7. HUD sobre 3D

- **Zonas**: cantos para estado (dinheiro, detetor, vida), centro para mira e feedback
  imediato, base para prompts contextuais.
- **Nunca tapar o centro** nem o chão imediato à frente do jogador.
- **Fundo**: painel semitransparente ou contorno; texto fino sobre areia clara
  desaparece.
- **Escala**: o HUD acompanha a resolução, mas não o FOV. Testa com FOV alto.
- **Densidade**: máximo 4 indicadores permanentes; o resto é transitório.
- **Feedback de dano** nas bordas, não no centro; **feedback de loot** perto do objeto.

## 8. Movimento e som

- **150–250 ms**, ease-out; entrada mais rápida que saída.
- **Nunca bloquear a ação**: animação de menu não impede o clique seguinte.
- **Movimento com propósito**: slide para painéis, fade para modais, nenhum “bounce”
  gratuito.
- **Reduzir movimento**: opção que desliga parallax, shake e transições longas.
- **Som**: um som por tipo de ação, volume consistente; silêncio também comunica.

## 9. Acessibilidade (mínimo viável)

- Remapeamento completo de teclas/comando.
- Legendas para falas e sons importantes, com fundo.
- Escala de texto (100/115/130%) sem quebrar painéis.
- Contraste alto opcional; nada de informação só por cor.
- Sem flashes > 3 Hz; opção para reduzir screenshake.
- Pausa a qualquer momento em solo; em coop, pausa local/não bloqueante.

## 10. Ecrãs do ScanDig — o que cada um deve responder

| Ecrã | Pergunta do jogador | Ação primária |
|---|---|---|
| Título | “o que é isto?” | Continuar / Nova expedição |
| Base | “o que faço agora?” | Escolher mapa / vender |
| Loja | “vale a pena?” | Comprar (com comparação) |
| HUD | “onde estou e o que tenho?” | nenhuma (informativo) |
| Pausa | “como saio ou ajusto?” | Retomar |
| Vitória | “o que consegui?” | Continuar / menu |
| Multijogador | “como entro?” | Entrar/criar sala |

Se um ecrã responde a duas perguntas ao mesmo tempo, separa-o em dois estados.

## 11. Checklist de UI

- [ ] Uma ação primária visível em 5 s.
- [ ] Três tamanhos de texto, no máximo.
- [ ] Contraste medido (não “parece bem”).
- [ ] Seis estados em todos os botões.
- [ ] Foco visível e navegável só com comando.
- [ ] 9-slice sem deformar; margens seguras.
- [ ] 720p legível; 1080p e ultrawide sem sobreposição.
- [ ] Texto localizado +30% sem cortar.
- [ ] HUD não tapa o centro nem o chão.
- [ ] Movimento ≤ 250 ms e opção de reduzir.
