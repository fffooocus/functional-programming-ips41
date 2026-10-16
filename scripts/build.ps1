param([string]$Ghc = 'ghc')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
try {
  if ($Ghc -eq 'ghc') {
    $taskPortable = Get-ChildItem -LiteralPath (Join-Path $taskRoot '.tools') -Filter 'ghc-9.6.7.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($taskPortable) { $Ghc = $taskPortable.FullName }
  }
  $taskGhcOptions = @()
  if (Test-Path -LiteralPath $Ghc) {
    Add-Type -TypeDefinition 'using System; using System.Text; using System.Runtime.InteropServices; public static class FpBuildPaths { [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint GetShortPathName(string path, StringBuilder result, uint size); }'
    $taskBuffer = [System.Text.StringBuilder]::new(2048)
    [void][FpBuildPaths]::GetShortPathName((Resolve-Path -LiteralPath $Ghc).Path,$taskBuffer,2048)
    $Ghc = $taskBuffer.ToString()
    $taskLibrary = Join-Path (Split-Path -Parent (Split-Path -Parent $Ghc)) 'lib'
    $taskGhcOptions = @("-B$taskLibrary")
  }
  foreach ($taskLab in @('lab1','lab2','lab3')) {
    New-Item -ItemType Directory -Path ".build\$taskLab" -Force | Out-Null
    & $Ghc @taskGhcOptions -O2 -Wall -threaded -rtsopts "-i$taskLab/src" "$taskLab/app/Main.hs" -outputdir ".build/$taskLab" -o ".build/$taskLab.exe"
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $taskLab" }
  }
  New-Item -ItemType Directory -Path '.build\tests' -Force | Out-Null
  & $Ghc @taskGhcOptions -O2 -Wall -threaded -rtsopts '-ilab1/src' '-ilab2/src' '-ilab3/src' tests/Main.hs -outputdir .build/tests -o .build/tests.exe
  if ($LASTEXITCODE -ne 0) { throw 'Tests build failed' }
  & .\.build\tests.exe +RTS -N4 -RTS
  if ($LASTEXITCODE -ne 0) { throw 'Tests failed' }
} finally { Pop-Location }
