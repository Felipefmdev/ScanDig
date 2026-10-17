# ScanDig: build do Windows (#101)

## Preset
`export_presets.cfg`, preset **"Windows Desktop"**:
- x86_64, PCK embutido no `.exe` (`binary_format/embed_pck=true`), saída `build/windows/ScanDig.exe` (`build/` está no `.gitignore`).
- `exclude_filter`: `tests/*, core/tests/*, ui/tests/*, addons/gut/*, tools/*, docs/*, _ext/*, .bot_runs/*, build/*, *.md, *.py, *.sh, *.bat`. Nada de runtime carrega dessas pastas. O `DebugBridge` (autoload) **fica** no build: só roda em build de debug com `--bot=`, então no release não faz nada.
- Console wrapper (`ScanDig.console.exe`) só no export de **debug**; o release publicado é só o `.exe`.
- `application/modify_resources=false`: sem ícone nem metadados no `.exe` (o runner Linux do CI não tem `rcedit`).

## Local (Windows)
1. Templates da 4.3 (uma vez): baixe `Godot_v4.3-stable_export_templates.tpz` (~1 GB, é um zip) da página de releases da Godot e extraia `templates/*` para `%APPDATA%/Godot/export_templates/4.3.stable/`. Para este preset bastam `version.txt` e os `windows_*_x86_64*.exe`.
2. Exportar:
   ```bash
   G=/c/Godot/Godot_v4.3-stable_win64_console.exe
   $G --headless --path . --import
   mkdir -p build/windows
   $G --headless --path . --export-release "Windows Desktop" build/windows/ScanDig.exe
   ```
   Uma linha `ERROR: Config File "user://gut_temp_directory/gut_editor_config.json" does not exist.` é do plugin GUT do editor, não do jogo.
3. O `.exe` abre na tela inicial. **Ele é o jogo de verdade**: na 1ª vez migra o `scandig_save.json` do `user://` para o slot 1 (#100). Faça backup antes, se for só testar.
4. Para conferir gameplay pelo pacote exportado, use um export de **debug** (`--export-debug "Windows Desktop" build/windows_debug/ScanDig.exe`) e rode `ScanDig.console.exe --headless -- --bot=<roteiro.json>` (ex.: com `{"start_expedition": "praia"}`). No release, `--bot=` é ignorado.

## CI
Job `export-windows` em `.github/workflows/ci.yml`:
- roda depois do `tests`, só em push no `main` ou `workflow_dispatch` (PR não exporta);
- templates em cache (`actions/cache`, chave `godot-export-templates-4.3-stable-windows-x86_64`); no cache miss, baixa o `.tpz` e extrai só os do Windows x86_64;
- falha sem o `.exe`, com `SCRIPT ERROR` ou com `ERROR: ` no log (fora a linha do GUT acima);
- publica o artifact **ScanDig-windows** (`ScanDig-windows.zip`, 14 dias). O GitHub entrega o artifact dentro de outro zip.

## Pendências
- Ícone e metadados do `.exe` (`application/icon`, versão, empresa): precisam de `rcedit` (no CI: wine + rcedit, ou exportar num runner Windows).
- Assinatura de código (`codesign/*`): sem certificado; o Windows SmartScreen avisa na 1ª execução.
