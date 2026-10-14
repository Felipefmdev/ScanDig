# ScanDig — Diretrizes do Projeto e Contexto de Arquitetura

## 1. Engine e Linguagem
- **Engine:** Godot 4.3 Standard (Forward+).
- **Linguagem:** GDScript 2.0 com **tipagem estática obrigatória** em todas as variáveis, parâmetros de função e retornos.
  - Exemplo: `var speed: float = 5.0`, `func dig(target_depth: float) -> bool:`.
- **Proibido usar sintaxe legada do Godot 3:**
  - NÃO usar `Spatial`, `KinematicBody`, `yield()`, conexões antigas de sinais em string `connect("signal", self, "method")` ou `export var` sem `@`.
- **Obrigatório usar padrões do Godot 4.3:**
  - Usar `Node3D`, `CharacterBody3D`.
  - Usar anotações modernas: `@export`, `@export_range`, `@onready`, `@rpc("any_peer", "call_local")`.
  - Conexão de sinais tipada via Callable: `signal_name.connect(_on_signal_name)`.

---

## 2. Divisão de Responsabilidades e Permissões de Equipa

| Equipa / Dev | Âmbito de Edição Permitido | Áreas Proibidas |
| :--- | :--- | :--- |
| **Dev A** (`Lead_Gameplay`, `Dev_Detector`, `Dev_Player`) | `res://gameplay/` (todos os subdiretórios)<br>`res://world/test_sandbox.tscn`<br>`res://items/` (ver regra abaixo)<br>`res://assets/` (pasta partilhada)<br>`res://world/map_*.tscn` | **PROIBIDO** editar `res://core/` e `res://ui/` |
| **Dev B** (`Arquiteto`, `Dev_Netcode`, `Dev_UI_Economy`) | `res://core/`<br>`res://ui/`<br>`res://world/lobby_base.tscn`<br>`res://items/catalog/` e `res://items/maps/`<br>`res://assets/` (pasta partilhada) | `res://gameplay/`, `res://world/map_*.tscn`, `res://world/test_sandbox.tscn` |

**Regra de `res://items/`:** o Dev B edita `items/catalog/` e `items/maps/`. Os ficheiros de ponte/gameplay em `items/` (`discovery_bridge.gd`, `sell_point.gd`, `buried_spot.gd`) só mudam **mediante acordo entre Dev A e Dev B**.

**Autoloads oficiais** (`project.godot`, prefixo `Core*` para não colidir com o `class_name`): `CoreGameState`, `CoreNetwork`, `CoreSave`, `CoreSession`, `CoreSessionUI`. Detalhes em `docs/CORE_AND_NETWORK.md`.

---

## 3. Mapeamento de Entradas (Input Map Configurado)
As seguintes ações de input já estão pré-configuradas no `project.godot`:
- `move_forward`: Movimento para a frente
- `move_backward`: Movimento para trás
- `move_left`: Movimento para a esquerda
- `move_right`: Movimento para a direita
- `jump`: Salto
- `interact`: Interação com objetos/mundo
- `use_tool`: Ação principal da ferramenta ativa (detetar / escavar)
- `careful_dig`: Modo de escavação cuidadosa / minuciosa

---

## 4. Estrutura de Diretórios
```
res://
├── core/                  # Dev B: Sistemas centrais, managers globais e autoloads
├── gameplay/              # Dev A: Gameplay loop
│   ├── detector/          # Dev_Detector: Detetor de metais, física 3D, áudio procedural
│   ├── digging/           # Dev_Player / Dev A: Sistema de escavação do terreno
│   └── player/            # Dev_Player: CharacterBody3D, câmara 1ª pessoa, inventário rápido
├── assets/                # Partilhada: modelos 3D, texturas e áudio de terceiros (ver License.txt de cada pacote; preferir CC0 e glTF/.glb)
├── items/                 # Partilhada: Definições de itens e catálogo
│   ├── catalog/           # Recursos .tres de instâncias de itens
│   └── item_data.gd       # Script base Resource para ItemData
├── ui/                    # Dev B: Interfaces HUD, menus, feedback visual
└── world/                 # Cenários e sandbox de testes (ex: test_sandbox.tscn)
```

---

## 5. Convenções de Código
1. Scripts sempre com extensão `.gd`. Cenas com extensão `.tscn` formatadas estritamente em texto puro.
2. Nomes de ficheiros em `snake_case`. Nomes de classes em `PascalCase`.
3. Sinais definidos no topo dos scripts usando tipos nos argumentos: `signal item_detected(item: ItemData, signal_strength: float)`.
