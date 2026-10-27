# #177 — Aviso de conquista na vitória

O aviso de conquista agora ocupa a faixa superior quando a vitória está aberta. O cartão da vitória reserva a altura medida do aviso mais a folga existente; a reserva permanece nos créditos e após o aviso expirar. Ao fechar, o aviso ainda ativo volta à posição normal. Fila, token, prazo de três segundos, recompensa e progressão são preservados.

## Reprodução e verificação

Codex executou os testes; Farol revisou os dois scripts e a regressão sem editar ou iniciar engine. Checkout isolado `365a`, branch `codex/victory-toast-177`, sobre `6bc934f` (#186).

- RED: oito cenários PT/EN ×1152×648/1280×720 ×escala 1/1,3 falharam na interseção do aviso com subtítulo e créditos. `177_toast_RED26.log` e `177_before26.log`; 16 capturas em `177_before26/`.
- GREEN com renderer: oito testes / 656 asserts em `177_unobstructed26.log`. As 16 capturas de resumo/créditos em `177_after_unobstructed26/` ocultam somente o painel do GUT, mantendo o aviso real visível.
- Regressão de vitória, créditos e aviso de save: 34 testes / 845 asserts em `177_renderer_regression26.log`; warning de ObjectDB conservado nessa execução combinada.
- Repetição na fonte final, sem capturas: `177_final_ui_native26.json`, saída real zero, 34 testes / 813 asserts, zero falhas/erros nativos e um warning de ObjectDB. stdout/stderr separados, watchdog de 90 segundos. A diferença de asserts é a captura opcional de PNG desligada.
- O teste usa autoloads reais e `request_report_boss_defeated(lunar_warden)`, sem emitir eventos de conquista/vitória artificialmente. Confere uma conquista/vitória, saldo e dia inalterados, foco/scroll dos créditos, Continuação antes de expirar, restauração de mouse/foco/posição e expiração no prazo original; repetir o boss não reabre a tela.

O primeiro gate completo identificou setup visual executado antes do pending headless. A fixture foi corrigida para não iniciar esse setup/cleanup em modo headless; todos os asserts de renderer continuam intactos. O log RED de integração foi preservado, e o gate completo foi repetido.

Gate completo repetido: `177_final_r2gates26.json`, todos os códigos zero. GUT: 199 scripts, 1182 testes, 1172 passaram, dez pending (oito deste teste e dois de iluminação), 26411 asserts, sem falhas. Os dois scripts de iluminação no renderer passaram 7/7, 315 asserts. Headless: `HEADLESS OK`, incluindo pares de rede. LSP core/UI: zero diagnósticos em 99 arquivos. O log completo conserva os diagnósticos nativos legados documentados na #186; não é apresentado como log global limpo.

## Limites

O evento do core é real, mas este ensaio não comprova combate ou ENet. A matriz configura tamanho/escala antes da vitória; não cobre resize ativo, segunda conquista ou transform customizado de canvas. A leitura de geometria complementa as capturas, sem substituir avaliação humana de toda a interface. Capturas e arquivos de teste ficam em `.bot_runs/`; saves são isolados, e configurações do usuário são restauradas.
