# Ambientação externa dos mapas — #157

Passe de 21/10/2026, acompanhado na [issue #157](https://github.com/Felipefmdev/ScanDig/issues/157).
Codex coordenou a aplicação pelo MCP Godot; Bússola preparou Campo/Praia e Farol preparou
as formações regionais e revisou as capturas. Antigravity #2 verificou a ferramenta e
suspendeu a rotina antiga de transferência de liderança ao Claude.

## Alterações

- **Praia:** nove palmeiras em três grupos no lado terrestre, apoiadas nos triângulos da
  extensão costeira existente. O mar aberto em +X e o cais continuam visíveis.
- **Campo:** pedras de borda mais baixas, dois conjuntos assimétricos de árvores, moitas
  e dois talhões externos. Oitenta touceiras compartilham um `MultiMesh`; rotas,
  clareiras e vista da torre para o círculo foram preservadas.
- **Ruínas:** transição de terreno e lajes facetadas de arenito até as mesas distantes.
- **Geleira:** cristas irregulares conectadas, afloramentos de gelo e neve localizada.
- **Cratera:** estratos e afloramentos basálticos conectam o relevo ao horizonte.

As faixas regionais usam uma superfície por mapa, costurada ao relevo em ±46 m e à
base do horizonte em ±75 m. Não criam colisores, objetivos, RPCs nem nós serializados.
Nenhuma cena `.tscn` foi salva por este passe; diferenças anteriores nas cenas foram preservadas.

## Capturas atuais

Os diretórios abaixo ficam em `.bot_runs/`, ignorado pelo Git. Não usar capturas históricas
como substitutas destes pares. Resolução 1280×720, janela, câmera de jogador e mesmos
enquadramentos nos pares; semente determinística dos geradores. As capturas extras de
costura ficam fora da área jogável e servem somente para inspecionar a malha.

| Mapa | Antes | Depois validado |
| :--- | :--- | :--- |
| Praia | `praia_157_before_2026-10-21_09-46-17` | `praia_157_after_2026-10-21_09-53-26` |
| Campo | `campo_157_before_2026-10-21_09-37-46` | `campo_157_after_2026-10-21_09-42-12` |
| Ruínas | `ruinas_157_before_2026-10-21_09-43-57` | `ruinas_157_refined_2026-10-21_09-55-31` |
| Geleira | `geleira_157_before_2026-10-21_09-44-49` | `geleira_157_refined_2026-10-21_09-54-36` |
| Cratera | `cratera_157_before_2026-10-21_09-45-20` | `cratera_157_refined_2026-10-21_09-55-07` |

Os três lotes regionais finais têm 33 passos, dez PNGs, `errors=[]` e saída 0 cada.
O Campo diurno tem 36 passos, onze PNGs e zero erros; a Praia tem cinco PNGs.
A rodada de Ruínas `09-54-04` excedeu o tempo do MCP e foi substituída pela rodada curta `09-55-31`.

Campo com noite e chuva: `campo_157_night_rain_2026-10-21_09-46-11`, 52 passos, dez PNGs,
zero erros. A caminhada real spawn → entrega está nos dumps da rodada separada
`campo_157_night_rain_v2_2026-10-21_09-46-40`; essa rodada parcial não comprova o percurso inteiro.

## Verificação e limites

- GUT completo final: **892 testes, 891 aprovados e um pendente**, saída 0;
  `.bot_runs/ambient157_gut_final.log`.
- GUT de ambiente com janela: **17 testes e 545 asserts aprovados**, saída 0 e log sem
  erros/avisos; `.bot_runs/ambient157_rendered_final.log`. Inclui o teste de `MultiMesh`
  explicitamente pendente no renderer dummy headless da Godot 4.3.
- Suíte headless final: **HEADLESS OK**, saída 0, incluindo os pares de rede;
  `.bot_runs/ambient157_headless_final.log`. A rodada anterior também passou
  (`.bot_runs/ambient157_headless.log`).
- MCP `check_script` do gerador regional: sem erros ou avisos,
  `.bot_runs/ambient157_mcp_check_regional.json`.
- MCP `run_project_diagnostics` do Campo: saída 0, mas `ok=false` por mensagens de
  shadowing/divisão inteira e `mesh_get_surface_count` do renderer dummy; não é uma
  execução de log limpo (`.bot_runs/ambient157_mcp_diagnostics.json`). A validação visual
  e o contrato de `MultiMesh` foram executados com renderizador real.

Os testes verificam apoio na malha costeira real, apoio analítico das raízes, limites,
ausência de colisores novos, costuras regionais, determinismo de vértices/cores,
triângulos não degenerados e reconstrução sem duplicação. Revisão independente das
capturas finais foi favorável. Imagens estáticas não comprovam ausência de cintilação,
todos os pontos do perímetro, uma campanha cooperativa completa ou desempenho mínimo.
