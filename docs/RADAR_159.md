# Leitura e ergonomia do detector — #159

Primeira implementação da direção aprovada na auditoria #158. O visor destaca Procurar,
Aproximar e Cavar; a última ação exige o pinpointer comprado e a mesma distância do
`PIN ✔ CAVE` existente. O provedor `MetalDetector` continua controlando alcance, upgrades,
conhecimento do item, clima, sinal, áudio e rede.

Linhas indisponíveis deixam de repetir traços. A reserva de espaço por nível mantém o
círculo estável ao adquirir/perder alvo. Nomes longos reduzem até fonte 9 e recebem reticências
se ainda excederem a largura; o nome completo permanece nos demais contextos do item.
Interferência usa cruz tênue, item usa círculo e inimigo usa losango, preservando as paletas A11y.

A caixa fica mais frontal e elevada, com suporte, e o apoio de braço é menor.
`COIL_CENTER`, `GRIP_TOP`, `GRIP_BOTTOM`, cena e lógica de detecção não foram alterados.
O primeiro ajuste encobria Prof/Val com os dedos; a recaptura refinada corrigiu essa sobreposição.

## Evidências locais

- MCP Godot 4.3: `.bot_runs/159_version_result.json`; aplicação com SHA esperado em
  `radar159_final_{request,result}.json` e `model159_refined_{request,result}.json`.
- Baseline: `audit158_radar_2026-10-21_10-20-22` e lote `radar159_before_*`.
- PT 720p: `radar159_refined_2026-10-21_16-26-49`, quatro capturas, 13 passos e zero erros do bot.
- EN próximo de 1080p: `radar159_english1080_2026-10-21_16-31-51`, cinco capturas a
  1920×1061 (janela limitada pelas bordas do desktop), zero erros do bot. A quinta mostra
  apenas aviso de chuva. Teleporte usado para composição, sem reivindicar caminhada.
- Chuva ativa: `radar159_active_rain_2026-10-21_16-38-37`, 18 passos/zero erros; captura
  adicional `radar159_active_natural_noise.png` observada quando um blip de ruído natural
  apareceu. JSON homônimo confirma `phase=active`, `noise=0.35`, `pinpointer=0`.
  Não foi chamado o método de inserir blip manualmente. Imagem 1280×720, idioma EN.
- EN 1080p exato: `radar159_en1080_exact_2026-10-21_16-48-27`, quatro imagens
  confirmadas a 1920×1080, 13 passos/zero erros. O wrapper ajusta a janela sem bordas
  após o carregamento das configurações; não modifica as configurações persistidas.
- `.bot_runs/a11y159/radar_{off,protanopia,deuteranopia,tritanopia}.png`: fixture de desenho
  com dados sintéticos, nome longo e cruz de ruído; não é encontro real. Log final
  `radar159_a11y_engine.log` sem ERROR/WARNING.
- RED inicial `radar159_red.log`: quatro falhas esperadas; GREEN: quatro testes/24 asserts.
- RED de estabilidade/texto: `radar159_layout_red_valid.log`, duas falhas; GREEN final:
  `radar159_layout_green.log`, seis testes/32 asserts.
- Integração renderizada: `159_160_integrated_rendered.log`, 64 testes/714 asserts passando.
  Há dois erros legados de acessibilidade e aviso de ObjectDB. Os mesmos erros foram
  reproduzidos com os três scripts anteriores em memória em `159_160_a11y_baseline.log`.

GUT completo final: `.bot_runs/159_160_gut_final.log`, 142 scripts, 904 testes,
903 passando, uma pendência conhecida de MultiMesh no renderer dummy, 10190 asserts e exit 0.
Os avisos/erros legados de dummy/A11y/ObjectDB continuam no log; não é uma execução limpa.
Headless final: `.bot_runs/159_160_headless_final.log`, `HEADLESS OK`, exit 0,
incluindo pares de rede de desconexão, múltiplos peers, nomes e saves.
A inspeção estática
e os bots de captura não substituem playtest humano de leitura nem medição de FPS.
