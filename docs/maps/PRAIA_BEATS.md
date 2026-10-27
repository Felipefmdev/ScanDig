# Praia — beat sheet (mapa piloto)

Modelo preenchido para o mapa 1. Serve de exemplo para `docs/maps/<mapa>_beats.md`.
Números medidos com `python tools/map_layout_audit.py world/map_praia.tscn` no commit
`7d1f53b`; conteúdo de `docs/GAME_DESIGN.md` §4.

## 1. Medições atuais

| Âncora | Posição (x, y, z) | Distância do spawn | Tempo a sprint |
|---|---|---|---|
| Spawn | (0; 0,1; 0) | — | — |
| BaseEntrega | (3,5; 0; 3,5) | 5,0 m | 0,7 s |
| Banca | (7; 0; 0,5) | 7,0 m | 1,0 s |
| DetectorSpawn | (3,6; 0,05; 3,6) | 5,1 m | 0,8 s |
| EnemySpawner | (18; 0; 0) | 18,0 m | 2,7 s |
| Cais (Dock1–4) | x 28,75–36,25; z 12 | ≈31 m | 4,6 s |
| Naufrágio (ShipWreck) | (34; −0,9; −13) | 36,4 m | 5,4 s |
| BossAltar | (−22; 0; −22) | 31,1 m | 4,6 s |

Terreno: 69 × 62 m (`beach_terrain.gd:11-12`); paredes a ±30,5 m (62 m). O mapa inteiro
atravessa-se em ~11 s de sprint.

## 2. Leitura

- O **spawn, a base e a banca estão empilhados** num raio de 7 m: o beat de serviço não
  tem espaço próprio e a primeira impressão é um pátio, não uma praia.
- O **chefe está mais perto do spawn (31 m) do que o naufrágio (36 m)**, e ambos à vista
  de qualquer ponto: não há hierarquia de descoberta.
- Com 60–70 min de duração, ~4 300 m² de área jogável obrigam a reutilizar o mesmo espaço
  muitas vezes. A sensação de aperto vem daqui, não do detalhe.
- O segredo (`PraiaSecrets`) é uma cena instanciada na origem; o auditor não vê as
  posições internas. Validar no editor/MCP.

## 3. Beats propostos

| # | Beat | Função | Duração | Marco | Estado atual |
|---|---|---|---|---|---|
| 1 | Chegada | orientar, dar o tom | 2–4 min | cais + barco a remos | existe, a 31 m |
| 2 | Serviço | preparar, dialogar | 5–8 min | Pescador Zé + banca | comprimido no spawn |
| 3 | Baixio | loop de escavação | 15–20 min | marcas na areia, garrafas | disperso |
| 4 | Naufrágio | descoberta | 8–12 min | casco inclinado | a 36 m, fora da parede leste |
| 5 | Maré Vermelha | evento de missão | 5–8 min | barco do Zé cercado | gatilho por missão |
| 6 | Arena do Caranguejo-Rei | risco principal | 8–12 min | arena de costas/dunas | a 31 m, sem arena dedicada |
| 7 | Polvo do Naufrágio | segredo | 8–12 min | 3 conchas | gatilho por sequência |
| 8 | Saída | vender, apontar o próximo | 2–3 min | cais | — |

## 4. Mudanças mínimas propostas (sem refazer o mapa)

1. **Separar serviço de chegada:** mover a banca para o cais (x ≈ 26, z ≈ 10) e deixar o
   spawn na areia, com o naufrágio como marco inicial.
2. **Dar arena ao chefe:** afastar o `BossAltar` para além de 55 m do spawn e limitar a
   área com dunas/rochas; 18–25 m de diâmetro livre.
3. **Abrir o naufrágio:** garantir acesso dentro da parede (x ≤ 30) ou uma abertura
   explícita; hoje o casco está em x = 34, fora do limite jogável.
4. **Espalhar spots:** 10–25 m entre si e ≤ 30 m do eixo do caminho (alcance 8–23 m).
5. **Cortar 30% do scatter** no raio de 6 m à volta de cada spot.

## 5. Critérios de aceitação

- [ ] Um jogador novo encontra a banca em < 60 s e o primeiro spot em < 90 s, sem HUD.
- [ ] O naufrágio é visível do spawn, mas não se chega lá em < 20 s de caminhada.
- [ ] A arena do chefe tem ≥ 18 m de diâmetro e é reconhecível como arena.
- [ ] Todos os spots têm 2 m livres e não há props no caminho de escavação.
- [ ] A captura de spawn mostra um marco dominante e no máximo dois secundários.
- [ ] O auditor não mostra regressão de nós/transforms; o diff é explicado na issue.

## 6. Como validar

```powershell
python tools/map_layout_audit.py world/map_praia.tscn --json > .bot_runs/praia_depois.json
./tools/map_production.ps1 -Tool Game -ToolArgs 'res://world/map_praia.tscn'
```

Capturas: spawn, banca, naufrágio, arena, com a mesma hora/luz. Comparar com o baseline
em `.bot_runs/praia_antes.json`.
