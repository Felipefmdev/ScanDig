# Contexto mínimo — mapas e UI

Uma página. Se só puderes ler um ficheiro antes de editar `world/` ou `ui/`, é este.
Cada regra é verificável; nenhuma é estilo.

## Vocabulário

- **Beat** — um momento com uma função: chegar, servir, explorar, descobrir, arriscar, sair.
- **Marco (landmark)** — forma grande e reconhecível que orienta sem HUD.
- **Critical path** — caminho mínimo para cumprir o objetivo do mapa.
- **Espaço vazio** — chão livre de props, necessário para cavar, fugir e ler o relevo.
- **Telegrafar** — avisar antes do perigo, com forma, som ou movimento.
- **Affordance** — o objeto mostra o que se pode fazer com ele.
- **Hierarquia** — o ecrã diz qual é a ação principal antes de tudo o resto.
- **9-slice** — painel que estica sem deformar as bordas (StyleBoxTexture + margens).
- **Foco** — estado visível do controlo selecionado por teclado/comando.

## Mapas — 12 regras

1. **Um beat, uma função.** Não juntes serviço, chefe e segredo no mesmo pátio.
2. **O spawn vê um marco.** Se não vê, o mapa começa perdido.
3. **Marco a cada 20–35 m** no critical path; silhueta legível a 60–80 m.
4. **Corredor jogável ≥ 3 m** (2 jogadores + folga). Arena de chefe ≥ 18 m de diâmetro.
5. **Pelo menos metade** da área jogável fica sem props: é onde se cava e se foge.
6. **Nada de arte na linha de escavação**: spots precisam de 2 m livres em volta.
7. **Verticalidade máxima de 3 níveis**; cada subida tem de ser lida antes de ser feita.
8. **Um herói por beat** (naufrágio, poço, altar) e o resto é kit + scatter.
9. **Perigo telegrafado**: animação ou som antes do dano, sempre com janela de resposta.
10. **Segredo não compete com o objetivo**: fica fora do critical path, mas visível de perto.
11. **Coop**: cada passagem tem alternativa ou espera; ninguém fica preso atrás do outro.
12. **O mapa ensina sem texto**: o primeiro erro custa pouco, o segundo custa mais.

## UI — 12 regras

1. **Uma ação primária por ecrã**, no máximo duas secundárias. O resto é terciário.
2. **Três tamanhos de texto** por ecrã (corpo, título, destaque). Mais que isso é ruído.
3. **Contraste ≥ 4,5:1** para texto e ≥ 3:1 para ícones e bordas de foco.
4. **Cor nunca sozinha**: forma, ícone ou padrão acompanham o estado.
5. **Todos os estados**: normal, hover, pressed, foco, desativado, erro.
6. **Foco sempre visível** e alcançável só com teclado/comando.
7. **Margem segura de 5%** (10% em TV) e 9-slice: a UI não pode colar às bordas.
8. **HUD não tapa o centro**: cantos para estado, centro para mira e feedback de ação.
9. **Texto sobre 3D** leva fundo ou contorno; nunca texto fino sobre cena clara.
10. **Feedback em 150–250 ms**; animação nunca atrasa a ação.
11. **Localização**: +30% de texto, sem texto dentro de imagem, fontes com acentos.
12. **Resolve em 720p**: se só lê a 1080p, o tamanho está errado.

## Números do projeto (detalhe em `docs/MAP_METRICS.md`)

| Grandeza | Valor |
|---|---|
| Velocidade / sprint | 4,5 / 6,75 m/s |
| Altura do salto (ápice) | ≈ 0,90 m |
| Alcance de escavação | 1,8 m (dos pés) |
| Alcance de interação | 2,5 m |
| Deteção nível 1 → 7 | 8 → 23 m |
| Pinpoint | 2,0 m (cavar a 1,5 m) |
| Altura dos olhos | ≈ 1,7 m |

## Antes de abrir o editor

- [ ] A tarefa tem issue e o ficheiro que vou tocar está no meu âmbito (Dev A/Dev B).
- [ ] Sei qual beat estou a mudar e qual é o critério de aceitação.
- [ ] Contei nós e transforms do `map_*.tscn` (`python tools/map_layout_audit.py`).
- [ ] Tenho câmara/condição de captura definida (antes e depois, iguais).
- [ ] Se é UI: ecrã a 1280×720 e 1920×1080, rato **e** comando.

## Quando quebrar uma regra

Só com uma razão escrita na issue: qual regra, porquê, que teste a valida. Regras de
legibilidade e de contraste não se quebram por estética; regras de densidade e de
distância podem ceder num beat deliberado (claustrofobia, arena apertada).
