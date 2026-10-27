# #186 — Passagens por itens de chefes e lojas no mundo

## Decisões aprovadas

O avanço acontece por uma passagem dentro do mapa atual. Não há compra de acesso a mapas. Usar a chave do chefe na passagem abre a rota permanentemente para toda a equipe; a abertura integra o save do host e o snapshot recebido pelos clientes. Dinheiro continua servindo para ferramentas, consumíveis e melhorias nas lojas físicas.

Este documento concretiza o desenho aprovado em conversa. Os detalhes abaixo precisam de revisão antes da implementação por alterarem progressão, saves e transição cooperativa.

## Rotas terrestres

| Origem | Destino | Chefe | Item associado |
|---|---|---|---|
| Praia | Campo | Caranguejo Rei (`king_crab`) | `coroa_caranguejo_rei` |
| Campo | Ruínas | Toupeira Gigante (`giant_mole`) | `garra_toupeira` |
| Ruínas | Geleira | Guardião Antigo (`ancient_guardian`) | `nucleo_guardiao` |
| Geleira | Cratera | Mamute Congelado (`frozen_mammoth`) | `dente_mamute` |

Praia é acessível desde o início. A Toupeira deve produzir sua recompensa de verdade; a existência do recurso da garra no catálogo não basta. Chefes secundários não abrem atalhos de progressão.

Cada ligação tem uma saída legível no mapa de origem e um ponto de chegada/retorno no destino. A volta por uma rota já aberta é gratuita. A posição exata depende de inspeção atual via MCP, contagem de nós/transforms e capturas antes/depois. Não converter barco de missão, ponte interna ou arco da cripta em portal implicitamente. Corredor útil mínimo de 3 m; serviço, arena e passagem devem ter funções espaciais distintas.

O recibo é fixo por ligação, nos dois sentidos: Praia↔Campo usa `campo`, Campo↔Ruínas usa `ruinas`, Ruínas↔Geleira usa `geleira` e Geleira↔Cratera usa `cratera`. O retorno Campo→Praia consulta `campo`, não o ID do destino. Uma rota ainda fechada só pode ser aberta no endpoint do mapa de origem da tabela.

## Direção das bordas — ajuste solicitado pelo Felipe

Retirar a sensação de recinto fechado causada pelos picos altos nas extremidades. O mapa continua tendo limites jogáveis, mas não deve ser cercado por uma coroa contínua de montanhas, paredões ou vegetação opaca. Abrir vistas para uma paisagem distante que sugira continuação do mundo, com limites próximos variados e legíveis.

Proposta para validação visual: litoral e dunas baixas na Praia; colinas suaves e vegetação em grupos no Campo; desníveis e trechos de estruturas nas Ruínas; margens de gelo e horizonte distante na Geleira; relevo baixo e descontínuo na Cratera. Esses exemplos são direção artística, não posições ou geometrias já aprovadas. Montanhas distantes podem compor a paisagem sem formar uma parede próxima em todos os lados. Névoa ajuda a profundidade, mas não justifica colisão invisível em terreno que aparenta ser caminhável.

Separar relevo visual de contenção física. Reduzir a altura do terreno sem revisar `Bounds` pode deixar uma parede invisível; apagar `Bounds` sem outra solução pode permitir fuga ou queda. Cada trecho deve comunicar por que não é atravessável, com obstáculo natural localizado, margem ou desnível compatível com a linguagem do bioma. Não substituir picos por um anel igualmente fechado de árvores, muros ou abismos. Preservar áreas de escavação, segredos, arenas e a leitura das passagens abertas por chave.

Bússola levanta fontes do relevo; Farol revisa colisão e risco de fuga, ambos offline. A decisão geométrica exige inspeção atual via MCP e capturas na altura do jogador antes/depois; a leitura de código não certifica que a nova borda parece aberta. Fazer primeiro uma amostra em um bioma e validar a linguagem antes de repetir nos demais.

O inventário offline identifica quatro camadas que precisam de revisão conjunta: coroa do terreno, duas faixas de `Deco_border`, costura de `RegionalSurroundings` onde existente e silhuetas de `Backdrop`. Não limitar o ajuste ao backdrop: o terreno e a costura regional também formam um contorno quadrado contínuo. Os valores encontrados nos geradores são parâmetros, não alturas finais medidas ou aceite visual.

A amostra inicial será no Campo: ondulações externas baixas, grupos espaçados e setores de horizonte livre, preservando lavoura, cercas, marcos e apoio de árvores. Isso permite testar a linguagem sem alterar de início a Cratera/foguete ou a arena lunar. Na Praia, conservar o lado do mar já aberto e a continuidade costeira baixa. Ruínas, Geleira e Cratera precisam tratar a costura intermediária junto com o terreno e o cenário distante. Recalcular apoios de props sempre que a altura mudar.

Lua usa outro gerador, sem essas quatro camadas comuns. Sua revisão fica em um recorte visual próprio da #186, sem alterar PR185: primeiro redefinir o teste que atualmente exige o fechamento do horizonte e depois verificar chegada, arena e rota. Não afrouxar esse teste incidentalmente para fazer uma mudança terrestre passar, nem tomar a geometria assimétrica atual como prova de horizonte aberto.

## Chave de equipe e troféu físico

A autorização é uma credencial de missão da equipe, associada ao item do chefe. O troféu comercial continua existindo e pode integrar o museu. Não exigir que o único exemplar comercial desapareça permanentemente para permitir o avanço e concluir a coleção.

O host registra a recompensa de progressão ao resolver a derrota autêntica do chefe; a passagem continua fechada até uma interação explícita com ela. A chave de missão não ocupa mochila, não é vendida, doada ou largada na morte. O feedback da recompensa identifica o item obtido e sua função na passagem. Assim, mochila cheia ou desconexão durante entrega do troféu não perde a autorização de missão.

“Chave disponível” não significa “progresso salvo”: chefes terrestres atualmente não têm autosave imediato de derrota. A gravação confirmada ao abrir a passagem deve incluir derrota e recibo juntos. Antes disso, recuperação após encerrar o processo depende do último save real; não anunciar durabilidade inexistente.

Esse registro não aceita `item_id`, valor, inventário ou declaração de chefe derrotado enviados arbitrariamente por clientes. Usa o caminho de derrota validado pelo host e o mapeamento fixo chefe/rota. O estado de chefe derrotado permite reconstruir a credencial ainda não usada, sem gerar outro troféu comercial. Um cliente com o mesmo item do catálogo não pode abrir rota sem essa credencial.

Usar a passagem converte a credencial em abertura permanente, representada por `unlocked_maps`. O chefe continua em `defeated_bosses`; repetir a interação não cobra dinheiro nem entrega recompensas. O desenho não precisa de uma lista persistente de chaves redundante enquanto cada credencial puder ser derivada do chefe e cada abertura de `unlocked_maps`.

## Interação e autoridade

Qualquer jogador vivo e pronto pode solicitar a abertura da rota da equipe. O host valida o jogador real pelo remetente, mapa atual, objeto de passagem canônico, distância máxima de 2,5 m ao foco de interação, linha de visão, chave correspondente e ausência de outra transição em andamento. Esse alcance segue a métrica de interação do projeto e é distinto dos 5 m de reunião. A validação genérica atual de `Interactable` não substitui essas verificações.

Desativar a autorização de abrir mapas terrestres fechados pelo endpoint legado `request_unlock_map`/`_host_unlock_map`. Uma chamada direta de cliente não pode comprar nem abrir uma rota, mesmo com dinheiro e chefe derrotado. Só a operação host de interação com passagem validada pode criar o recibo novo; remover a UI sem bloquear esse caminho não atende ao contrato.

Abertura e viagem são operações distintas, com duas interações deliberadas. O primeiro E em uma passagem fechada apenas usa a chave, registra e salva a rota; não exige que a equipe esteja reunida. Depois de confirmação do save, o prompt muda para viajar. Um novo E inicia o pedido de viagem, que exige todos os jogadores vivos e prontos no ponto de reunião, sem ameaça próxima. O host usa raio de reunião de 5 m e de ameaça de 8 m, com mensagem identificando quem falta. Não transportar alguém à força enquanto explora ou combate. As passagens nunca viajam automaticamente por contato, inclusive no ponto de chegada.

Uma abertura só anuncia persistência confirmada depois de `SaveManager` retornar `OK`. Se salvar falhar, manter a chave recuperável, reverter a abertura ainda não publicada e exibir erro com possibilidade de tentar novamente. Não iniciar viagem depois de falha de save. Repetições simultâneas devem produzir uma abertura, sem débito ou recompensa duplicada.

## Transição entre biomas

A troca é uma continuação da expedição, sem avançar dia nem criar uma venda/resumo de fim de expedição. Preserva vida, fome, inventário, seleção e estado do jogador, incluindo dano, cura, morte ou revive legítimos durante a preparação. Estado temporário de pickups abandonados no mapa não ganha persistência entre cenas.

Extrair a infraestrutura comum de transição da #120 para um componente com origem, destino e ponto de chegada explícitos, mantendo a autorização específica do foguete separada. Preservar captura única por token, observação até a saída do ator, preparação/ACK, roster fixado, quiescência da geração antiga e remoção só de spawns com proveniência válida. A barreira de preparação não substitui a prontidão de cena da #173.

Antes de COMMITTING, timeout de 10 s, saída de participante ou cancelamento restaura o controle e permite nova tentativa. Após COMMITTING, não cancelar unilateralmente nem alegar rollback de cena. Erro de carregamento ou falta de ready do roster após 30 s é falha explícita de transição. Interromper novas viagens, mostrar diagnóstico e encaminhar os participantes conectados ao lobby por uma operação de recuperação própria; não usar o retorno atual que descarta o cache. Manter o payload de cada dono em memória até restaurá-lo uma única vez no próximo spawn normal de recuperação. Não permitir nova captura por cima desse payload pendente. A rota salva permanece aberta. Essa recuperação precisa de teste de falha injetada; não promete recuperar inventário de processo encerrado ou cliente desconectado.

Novos participantes durante PREPARING invalidam a preparação; durante COMMITTING aguardam a sessão estabilizar antes de entrar na cena de destino. Só publicar entidades para destinatários prontos segundo o contrato existente. A chegada usa o spawn normal com âncora, orientação e offsets separados por jogador, sem escrever posições arbitrárias depois do spawn. Validar essas âncoras por MCP antes de fixar coordenadas.

A retenção de late join durante COMMITTING e a recuperação de falha pós-commit são comportamentos novos da #186, cada um com gate próprio. Não atribuir sua comprovação aos testes anteriores de foguete/payload da #120.

A preferência dia/noite da expedição permanece a mesma; cada destino aplica noite apenas se suportada pelo mapa. Clima é reinicializado pelas regras locais do destino, sem transportar chuva/nevasca/cinzas incompatíveis. Manter um único início/fim de expedição e os acumuladores de dinheiro/itens; registrar os mapas visitados em ordem e atualizar a identificação do mapa atual no resumo, sem reiniciar métricas nem emitir outro `expedition_started` a cada passagem.

O menu inicia a campanha na Praia e permite continuar por rotas já abertas; não oferece compra nem desbloqueio de mapa e não permite saltar para destino fechado. Revisitar um mapa aberto pode continuar disponível no lobby como conveniência, sem substituir a primeira passagem física. O botão de encerrar a expedição mantém dia/save/resumo atuais.

## Lojas físicas

Reutilizar as bancas e `ShopOffer` existentes nos cinco mapas terrestres. Acrescentar um ponto de interação de melhorias na banca, que abre somente o painel comercial contextual. Não instanciar `BaseStationUI` inteira dentro do mapa. Separar suas linhas de melhorias e feedback de compra das páginas Museu, Conquistas e Expedições.

Retirar a página Loja do menu da base. Ferramentas, consumíveis e melhorias passam a ser comprados nas bancas. Todas as cinco bancas oferecem os quatro tipos de melhoria: detector, pinpointer, pá e mochila, mantendo os requisitos globais atuais de `required_maps`, agora consultando a abertura permanente. As ofertas físicas de ferramentas/consumíveis mantêm o sortimento local existente; não criar uma tabela nova de preços ou sortimentos nesta fatia.

Preservar preços, níveis, tradução, feedback de saldo, pedido pendente, timeout e foco de teclado/comando. O alvo de melhorias é distinto das ofertas físicas para não interceptar sua interação. O painel só permanece utilizável enquanto o jogador estiver vivo, pronto e próximo da banca; fechar ao afastar, ficar downed, morrer, desconectar ou iniciar transição. Enquanto aberto, bloquear inputs locais de movimento, salto, escavação, ataque e seleção de ferramenta, sem pausar física, rede ou dano; ao fechar, restaurar foco e mouse conforme o estado anterior.

O host valida banca real no mapa atual, ator, alcance e linha de visão em cada compra, além de catálogo, saldo, nível e limite da melhoria. Não basta validar a abertura do painel ou esconder a antiga página. Uma resposta tardia não deve cobrar duas vezes nem perder o item se a mochila encher.

Remover o nível mínimo de detector como impedimento de entrada/travessia dos biomas terrestres. Detector e pá mantêm seus efeitos de qualidade e eficiência. As condições de melhoria por mapa passam a depender da abertura permanente da rota; cada mapa oferece suas melhorias na banca, sem exigir a melhoria para chegar à própria banca. Não alterar preços para compensar o dinheiro retirado da antiga taxa sem medição própria.

## Saves e migração

Preservar todas as entradas válidas de `unlocked_maps` de saves existentes; uma rota já comprada continua aberta. Não reembolsar custos históricos automaticamente. Chefe já derrotado com rota fechada dá acesso à credencial recuperável na passagem, sem item comercial extra. `unlock_cost == 0` deixa de significar mapa automaticamente aberto: somente Praia tem acesso inicial por regra explícita.

O save pertence ao host; clientes e late join recebem seu snapshot e não importam progresso pessoal para abrir rotas da sessão. Carregar save não dispara derrotas, recompensas, vitória ou viagens. Não afirmar que inventário pessoal passa a ser persistido em disco: este recorte preserva o payload durante viagem ao vivo e a abertura das rotas no save.

## Lua e fronteiras de escopo

Preservar o foguete Cratera→Lua da #120, seus reparos, quests, pré-requisitos, reunião da equipe e save antes de preparar. Lua não recebe uma porta terrestre nem uma banca nesta mudança. A derrota do Guardião do Sinal continua sendo o final; não reintroduzir Ilha do Tesouro/Ídolo de Ouro como destino final.

Base de trabalho: candidato publicado `codex/lua120-final`, separado dos commits locais de UI #180 e dos arquivos sujos compartilhados. Não editar, reescrever ou incorporar alterações alheias no checkout principal. Entrega #186 em branch própria; não alterar PR185.

## Verificação exigida

- Regressões determinísticas: rota inicial; quatro gates; recibo fixo ida/volta; derrota sem uso não abre; uso permanente sem dinheiro; item cliente forjado; chamada direta ao unlock legado; ator ausente/morto/unready, origem errada, alcance e LOS; repetição; save falho; morte/mochila cheia/doação do troféu; migração com mapas comprados e com chefe vencido; snapshot de cliente; novo jogo limpa rotas.
- Compras: interação válida e fora do alcance/LOS, morte, mapa errado, nível máximo, saldo insuficiente, concorrência e resposta tardia; foco e tradução do painel contextual.
- Transição: ida/volta, inventário não vazio, desgaste/cargas, dano antes/depois de ACK e commit, cancelamento/retry, participante ausente, desconexão, late join e ready separados.
- Execução solo: chefe real→chave→passagem→mapa seguinte, compra na banca e retorno sem taxa. Execução ENet: abertura compartilhada, posse de payload por dono e viagem coordenada sem erros nativos. Não chamar laboratório de protocolo de campanha completa.
- MCP e capturas atuais antes/depois em cada mapa alterado; legibilidade em 720p/1080p e teclado/comando. Contar nós/transforms antes/depois e explicar qualquer remoção.
- GUT completo e `tools/run_headless_tests.sh` devem passar antes do commit. Registrar warnings e limites sem declarar log limpo quando houver avisos.

## Divisão de execução

Codex reserva core, save, UI e integração da transição. Farol revisa autenticidade, recuperação e regressões de progressão. Bússola prepara gameplay de passagens/bancas após contratos definidos, sem sobrepor core/UI. A revisão básica de migração fica com Codex enquanto Antigravity #2 estiver indisponível. Só Codex inicia engine para importação, testes e QA coordenados.
