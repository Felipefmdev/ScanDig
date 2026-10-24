# Lua — produção do mapa final (#120)

Autorização: Felipe pediu o início da produção em 22/10/2026. A #120 define missão da Dra. Vega, foguete na Cratera, Lua e chefe final. Ilha e fragmentos permanecem removidos.

## Primeira etapa: espaço jogável

Chegada em X/Z (0,18), disco plano de raio 5 m. Percurso com largura 4,8 m por (0,18), (-4,10), (3,3), (-4,-5), (0,-15). Arena de raio 9 m em (0,-15), altura -0,8 m, transição até 12 m. Caminho deve funcionar com Player atual, sem saltos obrigatórios. Terreno contínuo até ±70 m, limites jogáveis ±30 m e elevações externas assimétricas. Rególito cinza facetado e céu escuro, sem vegetação terrestre nem anel de pedras repetidas.

Terreno procedural determinístico: uma superfície, colisão da mesma malha e consulta de altura interpolada nos mesmos triângulos. Não usar GroundSnap com enum de outro mapa. Cena independente permite inspeção e caminhada; não mudar FINAL_BOSS_ID nem oferecer Lua na Base antes de missão/transição/chefe estarem integrados.

## Etapas seguintes

Missão de reparo e foguete reutilizam interação, inventário e autoridade existentes, com decisões de requisitos registradas antes de implementação. A transição usa SessionManager. Chefe lunar reutiliza ferramentas disponíveis e tem ataques antecipados visualmente, pausas e arena legível. A conclusão passa por GameState e VictoryScreen; carregar save não dispara vitória ao vivo.

## Validação

RED/GREEN de geometria, determinismo, apoio e cena. Capturas atuais pelo MCP com janela em chegada, percurso, arena e bordas. Caminhada com colisão real sem teleporte no percurso; física versus consulta de altura. Rede e latejoin em etapa própria, explicitando #173. GUT e headless completos antes de commit. Preservar alterações locais anteriores e registrar evidências na #120.
