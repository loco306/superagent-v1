# SUPERAGENT workspace hygiene -- archive transient run artifacts so the root stays clean.
# Usage:  powershell -File cleanup.ps1          (archive to _archive\<date>-cleanup\)
#         powershell -File cleanup.ps1 -WhatIf  (preview only, move nothing)
[CmdletBinding(SupportsShouldProcess)]
param()

$ws = $PSScriptRoot
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$arch = Join-Path $ws "_archive\$stamp"

# Transient artifact patterns (load-bearing grok_design_out.txt / grok_review_out.txt are EXCLUDED below).
$patterns = @('.tmp-*','.grok-*tmp*.txt','.grok-prompt-*.txt','_grok_*','bridge_*.log','_shot_*.png','_verify.txt','_eject.txt')
$keep     = @('grok_design_out.txt','grok_review_out.txt')   # never archive these
$dirs     = @('terminals','agent-tools','live')              # per-run scratch dirs

$targets = foreach ($p in $patterns) {
  Get-ChildItem -Path $ws -Filter $p -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $keep -notcontains $_.Name }
}
$targets = $targets | Sort-Object FullName -Unique

if (-not $targets -and -not ($dirs | Where-Object { Test-Path (Join-Path $ws $_) })) {
  Write-Host "Root already clean -- nothing to archive."; return
}

if ($PSCmdlet.ShouldProcess($arch, "create archive dir")) { New-Item -ItemType Directory -Path $arch -Force | Out-Null }

$n = 0
foreach ($t in $targets) {
  if ($PSCmdlet.ShouldProcess($t.Name, "archive")) { Move-Item -LiteralPath $t.FullName -Destination $arch -Force; $n++ }
  else { Write-Host "would archive: $($t.Name)" }
}
foreach ($d in $dirs) {
  $dp = Join-Path $ws $d
  if (Test-Path $dp) {
    if ($PSCmdlet.ShouldProcess($d, "archive dir")) { Move-Item -LiteralPath $dp -Destination $arch -Force; Write-Host "archived dir: $d" }
    else { Write-Host "would archive dir: $d" }
  }
}
if ($n -or ($dirs | Where-Object { Test-Path (Join-Path $arch $_) })) { Write-Host "Archived to $arch" }
