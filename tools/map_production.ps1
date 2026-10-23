param(
    [ValidateSet('Validate', 'Blender', 'Workshop', 'Game')]
    [string]$Tool = 'Validate',
    [switch]$Background,
    [string[]]$ToolArgs = @()
)

$ErrorActionPreference = 'Stop'
$toolchainFile = Join-Path $env:USERPROFILE '.codex/tools/map-production/toolchain.json'
if (-not (Test-Path -LiteralPath $toolchainFile)) {
    throw 'Oficina ausente. Consulte docs/MAP_PRODUCTION.md para instalar/configurar.'
}
$toolchain = Get-Content -Raw -Encoding UTF8 -LiteralPath $toolchainFile | ConvertFrom-Json
foreach ($program in @($toolchain.blender, $toolchain.godot)) {
    if (-not (Test-Path -LiteralPath $program)) { throw "Executavel ausente: $program" }
}

function Assert-NativeSuccess([string]$Program, [int]$ExitCode) {
    if ($ExitCode -ne 0) { throw "$Program encerrou com codigo $ExitCode" }
}

# Start-Process joins ArgumentList before launching. Quote for Windows argv parsing,
# including embedded quotes and trailing backslashes, instead of losing boundaries.
function ConvertTo-ProcessArgument([string]$Value) {
    $quoted = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $quoted = [regex]::Replace($quoted, '(\\+)$', '$1$1')
    return '"' + $quoted + '"'
}

function Start-InteractiveTool([string]$Program, [string[]]$Arguments) {
    $joined = ($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' '
    if ($Arguments.Count -gt 0) {
        Start-Process -FilePath $Program -ArgumentList $joined -WindowStyle Normal
    } else {
        Start-Process -FilePath $Program -WindowStyle Normal
    }
}

switch ($Tool) {
    'Validate' {
        $blenderVersion = & $toolchain.blender --background --factory-startup --version
        Assert-NativeSuccess 'Blender' $LASTEXITCODE
        $blenderVersion | Select-Object -First 1
        & $toolchain.godot --version
        Assert-NativeSuccess 'Godot' $LASTEXITCODE
        Write-Output "Oficina: $($toolchain.workshop)"
        Write-Output "Space Kit: $($toolchain.space_kit)"
        Write-Output "ProtonScatter $($toolchain.versions.proton_scatter) / Terrain3D 1.0.0 Godot4.3 / renderer Forward+"
    }
    'Blender' {
        if ($Background) {
            & $toolchain.blender --background --factory-startup @ToolArgs
            Assert-NativeSuccess 'Blender' $LASTEXITCODE
        } else {
            Start-InteractiveTool $toolchain.blender $ToolArgs
        }
    }
    'Workshop' {
        $arguments = @('--path', $toolchain.workshop, '--rendering-method', 'forward_plus', '--editor') + $ToolArgs
        if ($Background) {
            & $toolchain.godot --headless @arguments
            Assert-NativeSuccess 'Godot Workshop' $LASTEXITCODE
        } else {
            Start-InteractiveTool ($toolchain.godot.Replace('_console.exe','.exe')) $arguments
        }
    }
    'Game' {
        $projectPath = Split-Path -Parent $PSScriptRoot
        $arguments = @('--path', $projectPath, '--editor') + $ToolArgs
        if ($Background) {
            & $toolchain.godot --headless @arguments
            Assert-NativeSuccess 'Godot Game' $LASTEXITCODE
        } else {
            Start-InteractiveTool ($toolchain.godot.Replace('_console.exe','.exe')) $arguments
        }
    }
}
