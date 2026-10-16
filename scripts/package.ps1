param([string]$Output = 'submission.zip')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location $taskRoot
try {
  git archive --format=zip HEAD --output $Output
  if ($LASTEXITCODE -ne 0) { throw 'Source archive failed' }
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $taskArchivePath = [System.IO.Path]::GetFullPath((Join-Path $taskRoot $Output))
  $taskArchive = [System.IO.Compression.ZipFile]::Open($taskArchivePath,[System.IO.Compression.ZipArchiveMode]::Update)
  try {
    foreach ($taskProgram in @('lab1','lab2','lab3','tests')) {
      $taskFile = Join-Path $taskRoot ".build\$taskProgram.exe"
      if (-not (Test-Path -LiteralPath $taskFile)) { throw "Build missing: $taskProgram" }
      [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($taskArchive,$taskFile,".build/$taskProgram.exe",[System.IO.Compression.CompressionLevel]::Optimal)
    }
  } finally { $taskArchive.Dispose() }
  Get-FileHash -LiteralPath $taskArchivePath -Algorithm SHA256 | Format-List
  Get-Item -LiteralPath $taskArchivePath | Select-Object Name,Length | Format-List
} finally { Pop-Location }
