$ErrorActionPreference = 'Stop'
$recordPath = Join-Path $PSScriptRoot 'deployment.json'
$record = Get-Content -LiteralPath $recordPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($record.status -eq 'rolled-back') { Write-Output 'Already rolled back'; exit 0 }
if ($record.status -ne 'deployed') { throw 'No completed deployment to roll back' }
$running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -match '^(helldivers2|hdarsenal|hd2arsenal)$'
})
if ($running.Count) { throw 'Close Helldivers 2 and HD2 Arsenal before rollback' }
foreach ($file in $record.installedFiles) {
    if ($file.name -notmatch '^9ba626afa44a3aa3\.patch_5(\.stream|\.gpu_resources)?$') { throw 'Unexpected rollback file name' }
    $path = Join-Path $record.dataDir $file.name
    if (Test-Path -LiteralPath $path) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) {
            throw ('File was changed after deployment; refusing to remove: ' + $file.name)
        }
    }
}
# Remove the main archive first. Only this deployment's three matching files are removed.
foreach ($file in @($record.installedFiles | Sort-Object {$_.name.Length})) {
    $path = Join-Path $record.dataDir $file.name
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
}
$record.status = 'rolled-back'
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding UTF8
Write-Output 'Sentry HUD test build removed; existing Loader and other mods retained.'
