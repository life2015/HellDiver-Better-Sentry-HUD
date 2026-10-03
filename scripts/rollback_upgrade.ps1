$ErrorActionPreference='Stop'
function Assert-Closed {
 if(@(Get-Process|Where-Object {$_.ProcessName -match '^(helldivers2|hdarsenal|hd2arsenal)$'}).Count){throw 'Close game and Arsenal first'}
}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
$p=Join-Path $PSScriptRoot 'deployment.json'
$r=Get-Content -LiteralPath $p -Raw -Encoding UTF8|ConvertFrom-Json
if($r.status -ne 'deployed' -or $r.target -ne '9ba626afa44a3aa3.patch_5' -or !$r.installedFiles){throw 'No matching deployed multi-part upgrade'}
Assert-Closed
foreach($f in $r.installedFiles){if((Get-Sha (Join-Path $r.dataDir $f.name)) -ne $f.sha256){throw 'Installed part changed'}}
$restore=@($r.originalFiles|Where-Object {$_.name -like ($r.target+'*')})
if($restore.Count -ne 3){throw 'Incomplete backup inventory'}
foreach($f in $restore){if((Get-Sha (Join-Path $r.backup $f.name)) -ne $f.sha256){throw 'Backup changed'}}
# Restore main first, then its sidecars, with the game closed throughout.
foreach($f in ($restore|Sort-Object name)){
 Assert-Closed
 $dest=Join-Path $r.dataDir $f.name;$source=Join-Path $r.backup $f.name;$tmp=$dest+'.sentry-rollback-tmp'
 [IO.File]::Copy($source,$tmp,$false)
 [IO.File]::Replace($tmp,$dest,(Join-Path $r.backup ('rolled-back-'+$f.name)))
 if((Get-Sha $dest) -ne $f.sha256){throw 'Restore verification failed'}
}
$r.status='rolled-back';$r|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $p -Encoding UTF8
Write-Output 'Restored the previous Sentry HUD version and all sidecars. Config retained.'
