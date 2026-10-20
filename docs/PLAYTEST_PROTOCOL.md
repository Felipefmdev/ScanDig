# Protocolo de playtest — primeiro ciclo (#156)

## Objetivo e limites

Observar se uma pessoa consegue descobrir detector, sinal, escavação, coleta,
entrega e compra sem ajuda. Uma sessão dura até 15 minutos; não é uma prova de
habilidade. Não alterar preços, recompensas ou progressão com base apenas em bots.

Este documento é um protocolo e uma ficha vazia: **nenhuma sessão humana foi
realizada ou resultado humano produzido por este documento**.

## Preparação

1. Registrar hash do jogo, mapa (Praia), resolução, idioma, dispositivo de entrada,
   modo solo/coop e experiência prévia do participante. Evitar dados pessoais.
2. Pedir consentimento para observar e, separadamente, para gravar tela/voz.
   Capturas não devem expor nomes de conta ou outras informações pessoais.
3. Usar perfil de teste separado. Não apagar nem sobrescrever saves do jogador.
   Se usar “Rever dicas”, obter consentimento: a opção altera dicas vistas.
4. Um novo slot de save não reinicia as dicas: `scandig_hints.cfg` é global entre
   slots no mesmo diretório de dados do jogador. Registrar também quais dicas
   já foram vistas. Para primeira exposição, usar dados de usuário isolados e
   reiniciar dicas apenas com consentimento; novo slot sozinho não basta.
   Registrar dicas ligadas/desligadas, dia/noite e estado inicial de dinheiro,
   mochila e melhorias. Não misturar perfis experientes com iniciantes.
5. Conferir que não há bot, teleport, compra automática ou console de auxílio.
   Em coop, identificar qual jogador realizou cada ação e observar o cliente.

## Condução

Instrução única: “Explore e tente encontrar um objeto, entregá-lo e comprar algo.
Pode falar o que estiver pensando. Você pode parar a qualquer momento.”

Iniciar o cronômetro quando o jogador puder controlar o personagem. Não apontar
o detector, caminho ou botão correto. Registrar o que aconteceu, não adivinhar
intenções. Se houver bloqueio técnico, interromper e marcar sessão incompleta.
Se o participante pedir ajuda, registrar momento/pergunta e qualquer ajuda dada;
os marcos posteriores passam a ser assistidos. Encerrar em 15 minutos ou a pedido.

## Ficha por sessão

- Código anônimo / data / observador:
- Commit / mapa / resolução / idioma / controle:
- Solo ou coop / papel host ou cliente / experiência prévia:
- Dicas ligadas / dicas já vistas ou reset autorizado / dia ou noite / estado inicial:
- Consentimento para observação / gravação:

| Marco | Tempo desde controle (mm:ss) | Evidência/observação | Assistido? |
|---|---|---|---|
| Detector coletado | | | |
| Detector equipado | | | |
| Primeiro sinal percebido pelo participante | | | |
| Primeira tentativa de escavação | | | |
| Primeiro achado desenterrado | | | |
| Primeiro achado coletado | | | |
| Primeira entrega confirmada | | | |
| Primeira compra confirmada | | | |

Usar “não ocorreu” para marcos não atingidos e “não observável” quando não houver
evidência. O sinal no código não prova que a pessoa percebeu o sinal.

| Tempo | Ação/local | Resultado observado | Dúvida ou fala literal | Ajuda dada |
|---|---|---|---|---|
| | | | | |

Registrar mortes, tentativas de interação sem efeito, caminhos bloqueados,
mensagens ocultas, dicas fora de contexto e tempo parado sem objetivo aparente.
Não classificar toda tentativa sem efeito como bug: registrar mira/distância e
reproduzir depois. Capturas: chegada, primeiro sinal e entrega, com consentimento.

## Encerramento e análise

Perguntar: “O que você tentou fazer?”, “Onde ficou em dúvida?” e “Como percebeu
para onde voltar?”. Separar observação, fala do participante e interpretação.

Apresentar tempos individuais e quantidade de sessões; não tirar médias de
marcos ausentes nem tratar sessão assistida como descoberta independente.
Executar noite como sessão separada, mantendo condições registradas e distinguindo
aprendizagem prévia de melhora de legibilidade.

Classificar propostas em orientação, legibilidade, interação, bug ou economia.
Encaminhar preços/recompensas/progressão ao Dev B com evidência e limitações.
Documentar reprodução de bugs em issues separadas, preservando as reservas.

## Evidência automatizada separada

Bots verificam caminhos, interações e regressões; não medem compreensão humana.
Guardar hash, roteiro, log, resolução, duração e erros, inclusive com exit 0.
Não somar tempo/entregas de bot às fichas humanas. O baseline de pacing anterior
da Praia reportou 902,6 s, 54 escavações, 27 entregas, nenhuma morte/fallback,
mas quatro tentativas de screenshot headless falharam: não é sessão humana nem
evidência visual limpa. Reexecutar baseline comparável antes de propor economia.
