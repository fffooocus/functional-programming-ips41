$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
try {
  New-Item -ItemType Directory -Path '.tools' -Force | Out-Null
  $taskDownloads = @(
    @{Url='https://downloads.haskell.org/ghc/9.6.7/ghc-9.6.7-x86_64-unknown-mingw32.tar.xz'; File='.tools\ghc.tar.xz'},
    @{Url='https://downloads.haskell.org/ghc/9.6.7/SHA256SUMS'; File='.tools\ghc-sha256.txt'},
    @{Url='https://cdn.mysql.com/archives/mysql-8.4/mysql-8.4.6-winx64.zip'; File='.tools\mysql.zip'}
  )
  foreach ($taskDownload in $taskDownloads) {
    if (-not (Test-Path -LiteralPath $taskDownload.File)) {
      & curl.exe --fail --location --retry 3 --output $taskDownload.File $taskDownload.Url
      if ($LASTEXITCODE -ne 0) { throw "Download failed: $($taskDownload.Url)" }
    }
  }
  $taskHash = (Get-FileHash -LiteralPath '.tools\ghc.tar.xz' -Algorithm SHA256).Hash.ToLowerInvariant()
  $taskExpected = ((Get-Content -LiteralPath '.tools\ghc-sha256.txt' | Where-Object { $_ -match '\./ghc-9\.6\.7-x86_64-unknown-mingw32\.tar\.xz$' }) -split '\s+')[0]
  if ($taskHash -ne $taskExpected) { throw 'GHC SHA256 mismatch' }
  if (-not (Test-Path -LiteralPath '.tools\ghc-9.6.7-x86_64-unknown-mingw32\mingw\bin\clang.exe')) {
    if (Test-Path -LiteralPath 'C:\msys64\usr\bin\tar.exe') {
      & 'C:\msys64\usr\bin\tar.exe' --use-compress-program='C:/msys64/usr/bin/xz.exe' -xf '.tools/ghc.tar.xz' -C '.tools'
    } else { & tar.exe -xf '.tools\ghc.tar.xz' -C '.tools' }
    if ($LASTEXITCODE -ne 0) { throw 'GHC extraction failed' }
  }
  if (-not (Test-Path -LiteralPath '.tools\mysql-8.4.6-winx64\bin\mysqld.exe')) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $taskRoot '.tools\mysql.zip'),(Join-Path $taskRoot '.tools'))
  }
  Add-Type -TypeDefinition 'using System; using System.Text; using System.Runtime.InteropServices; public static class FpSetupPaths { [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern uint GetShortPathName(string path, StringBuilder result, uint size); }'
  $taskBuffer = [System.Text.StringBuilder]::new(2048)
  [void][FpSetupPaths]::GetShortPathName($taskRoot,$taskBuffer,2048)
  [System.IO.File]::WriteAllText((Join-Path $taskRoot '.tools\short-path.txt'),$taskBuffer.ToString(),[System.Text.UTF8Encoding]::new($false))
  & "$PSScriptRoot\build.ps1"
  node scripts/local.mjs verify
  if ($LASTEXITCODE -ne 0) { throw 'Integration checks failed' }
} finally { Pop-Location }
