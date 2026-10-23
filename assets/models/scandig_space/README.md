# Modelos espaciais derivados — #175 / #120

Fonte: Kenney Space Kit **2.0**, CC0. `License.txt` acompanha as cópias. Download oficial: https://kenney.nl/assets/space-kit.

Os originais foram importados no Blender 4.5.15 LTS e exportados em GLB, preservando materiais. O deslocamento interno dos modelos foi compensado antes da montagem. Os arquivos não dependem de um Blender instalado para rodar o jogo.

- `lunar_rocket.glb`: rocket_baseA, rocket_fuelA, rocket_finsA e rocket_topA; encaixes verticais em 0, 0.6, 1.1 e 1.8 m. Dimensões locais 1.8 × 2.6 × 1.8 m, antes da escala 2 da cena.
- `lunar_generator.glb`: machine_generator, incluindo cabo.
- `lunar_supplies.glb`: barrels, incluindo os quatro recipientes.

`source-manifest.json` registra peças, limites, triângulos e hashes dos originais, do ZIP oficial, das fontes e dos GLBs entregues. `mesh_count` conta objetos/instâncias; suprimentos usam cinco objetos e duas malhas únicas no GLB.

As fontes editáveis estão em `source/`, excluída da importação Godot por `.gdignore`. Exportar GLB explicitamente com Y-up/metros, sem animações/câmeras/luzes; o jogo usa apenas os GLBs e não depende de Blender.

QA de 23/10/2026: fontes e GLBs reimportados passaram no perfil game. Foguete607triângulos, gerador403, suprimentos268. Faces degeneradas foram removidas em coordenadas de montagem; UVs colapsadas sem textura foram reparadas. O fuelA é uma camisa3mm afastada radialmente do casco, eliminando superfícies coincidentes sem mudar o AABB total. UVs empilhadas/seams e faces internas opostas permanecem warnings aceitos para este uso de cores sólidas, sem bake. Ver `docs/MAP_PRODUCTION.md` e issue175 para evidências/limites.

A escala2 citada acima e a composição/apoio no terreno são contexto da integração local #120 em `gameplay/environment/lunar_arrival.gd`, não dependências destes assets nem parte do commit175.
