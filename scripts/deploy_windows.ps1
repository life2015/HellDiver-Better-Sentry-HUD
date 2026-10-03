param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [Parameter(Mandatory=$true)][string]$ExpectedZipSha256,
    [Parameter(Mandatory=$true)][string]$ExpectedPatchSha256,
    [string]$GameRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2',
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Assert-Closed {
    $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match '^(helldivers2|hdarsenal|hd2arsenal)$'
    })
    if ($running.Count) { throw ('Close these processes first: ' + ($running.ProcessName -join ', ')) }
}
function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-ResourceKeys([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 72 -or [BitConverter]::ToUInt32($bytes, 0) -ne [uint32]4026531857) {
        throw ('Unexpected archive header: ' + $Path)
    }
    $types = [BitConverter]::ToUInt32($bytes, 4)
    $count = [BitConverter]::ToUInt32($bytes, 8)
    $start = [long]72 + [long]32 * $types
    if ($start + [long]80 * $count -gt $bytes.Length) { throw ('Invalid resource table: ' + $Path) }
    for ($i = 0; $i -lt $count; $i++) {
        $offset = [int]($start + 80 * $i)
        '{0:x16}.{1:x16}' -f [BitConverter]::ToUInt64($bytes, $offset), [BitConverter]::ToUInt64($bytes, $offset + 8)
    }
}

if (!$ValidateOnly) { Assert-Closed }
$ArchivePath = (Resolve-Path -LiteralPath $ArchivePath).Path
$work = Split-Path -Parent $ArchivePath
$dataDir = Join-Path $GameRoot 'data'
$steamapps = Split-Path -Parent (Split-Path -Parent $GameRoot)
$appmanifest = Get-Content -LiteralPath (Join-Path $steamapps 'appmanifest_553850.acf') -Raw
if ($appmanifest -notmatch '"buildid"\s+"25480438"') { throw 'Unsupported installed Steam build' }
if ((Get-Sha $ArchivePath) -ne $ExpectedZipSha256.ToLowerInvariant()) { throw 'ZIP checksum mismatch' }

# This deployment targets the previously inspected BSL v15 environment exactly.
$expectedExisting = @{
    '9ba626afa44a3aa3.patch_0' = '86b31f8ef0f3a4065a3a737d1e0aee0fef309f7a1a6e0211c6fee07271f6cc96'
    '9ba626afa44a3aa3.patch_1' = '676ad3d32b43f75379af7162b39614ea22f5201c1b8340f1c07f3f654b3eb5ed'
    '9ba626afa44a3aa3.patch_2' = '8312b06178ad1e63f0f07444920f5e1f61a69adf1e62770786da09af70337e18'
    '9ba626afa44a3aa3.patch_3' = 'bbf19d5caa43516926243df5dd30e241c0306b23f06bddf4d4e8733bd63ecb71'
    '9ba626afa44a3aa3.patch_4' = 'e8dfa3e2efc4cc28bc4962bdd3949a25c57ee1abbaea1b6f7c8bfc034c09bdad'
}
$existing = @(Get-ChildItem -LiteralPath $dataDir -File | Where-Object { $_.Name -match '^9ba626afa44a3aa3\.patch_\d+$' })
if ($existing.Count -ne $expectedExisting.Count) { throw 'Installed patch inventory changed; inspect before deploying' }
$originalFiles = @()
foreach ($item in $existing) {
    if (!$expectedExisting.ContainsKey($item.Name) -or (Get-Sha $item.FullName) -ne $expectedExisting[$item.Name]) {
        throw ('Installed patch changed: ' + $item.Name)
    }
    foreach ($suffix in @('', '.stream', '.gpu_resources')) {
        $file = Get-Item -LiteralPath ($item.FullName + $suffix)
        $originalFiles += [pscustomobject]@{name=$file.Name; sha256=(Get-Sha $file.FullName); length=$file.Length}
    }
    if (@(Get-ResourceKeys $item.FullName) -contains 'c70581f9009795d1.a14e8dfa2cd117e2') {
        throw 'A Sentry HUD resource is already installed'
    }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
try {
    $entries = @($zip.Entries | ForEach-Object { $_.FullName })
    $allowed = @('Addon/9ba626afa44a3aa3.patch_0', 'Addon/9ba626afa44a3aa3.patch_0.stream',
        'Addon/9ba626afa44a3aa3.patch_0.gpu_resources', 'README.txt', 'THIRD_PARTY.txt',
        'dependencies.json', 'sentry_hud.cfg.example', 'manifest.json')
    if ($entries.Count -ne $allowed.Count -or @(Compare-Object $allowed $entries).Count) {
        throw 'Unexpected ZIP contents'
    }
} finally { $zip.Dispose() }

$patchName = '9ba626afa44a3aa3.patch_5'
foreach ($suffix in @('', '.stream', '.gpu_resources')) {
    if (Test-Path -LiteralPath (Join-Path $dataDir ($patchName + $suffix))) { throw 'Deployment slot already occupied' }
}
if ($ValidateOnly) {
    [pscustomobject]@{status='validated; install requires game and Arsenal closed'; gameBuild='25480438'; loader='existing BSL v15'; target=$patchName;
        existingFiles=$originalFiles.Count; zipSha256=(Get-Sha $ArchivePath)} | ConvertTo-Json
    exit 0
}

$backup = Join-Path $work 'backup'
$unpacked = Join-Path $work 'unpacked'
if ((Test-Path $backup) -or (Test-Path $unpacked) -or (Test-Path (Join-Path $work 'deployment.json'))) {
    throw 'Deployment work directory has already been used'
}
New-Item -ItemType Directory -Path $backup | Out-Null
foreach ($record in $originalFiles) {
    [IO.File]::Copy((Join-Path $dataDir $record.name), (Join-Path $backup $record.name), $false)
    if ((Get-Sha (Join-Path $backup $record.name)) -ne $record.sha256) { throw 'Backup checksum mismatch' }
}
$arsenal = Join-Path $env:LOCALAPPDATA 'hd2arsenal'
foreach ($name in @('hd2a_data.json', 'deployment_snapshot.json')) {
    $path = Join-Path $arsenal $name
    if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $backup $name) }
}
[IO.Compression.ZipFile]::ExtractToDirectory($ArchivePath, $unpacked)
$source = Join-Path $unpacked 'Addon\9ba626afa44a3aa3.patch_0'
if ((Get-Sha $source) -ne $ExpectedPatchSha256.ToLowerInvariant()) { throw 'Patch checksum mismatch' }
if (@(Get-ResourceKeys $source).Count -ne 1 -or (Get-ResourceKeys $source) -ne 'c70581f9009795d1.a14e8dfa2cd117e2') {
    throw 'Unexpected addon resource'
}

$installedFiles = @()
foreach ($suffix in @('.stream', '.gpu_resources', '')) {
    $installedFiles += [pscustomobject]@{name=($patchName + $suffix); sha256=(Get-Sha ($source + $suffix)); source=($source + $suffix)}
}
$recordPath = Join-Path $work 'deployment.json'
$record = [ordered]@{status='prepared'; timeUtc=[DateTime]::UtcNow.ToString('o'); version='sentry-hud-0.1.0-ui1-bsl15';
    gameRoot=$GameRoot; dataDir=$dataDir; gameBuild='25480438'; loader='BSL v15 (unchanged)';
    managerRegistered=$false; zipSha256=(Get-Sha $ArchivePath); originalFiles=$originalFiles; installedFiles=$installedFiles}
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding UTF8
$created = @()
try {
    Assert-Closed
    foreach ($original in $originalFiles) {
        if ((Get-Sha (Join-Path $dataDir $original.name)) -ne $original.sha256) { throw 'Existing files changed during preparation' }
    }
    foreach ($file in $installedFiles) {
        $dest = Join-Path $dataDir $file.name
        [IO.File]::Copy($file.source, $dest, $false)
        $created += $file
        if ((Get-Sha $dest) -ne $file.sha256) { throw ('Installed file checksum mismatch: ' + $file.name) }
    }
    foreach ($original in $originalFiles) {
        if ((Get-Sha (Join-Path $dataDir $original.name)) -ne $original.sha256) { throw 'Existing files changed during deployment' }
    }
    $record.status = 'deployed'
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding UTF8
} catch {
    foreach ($file in $created) {
        $dest = Join-Path $dataDir $file.name
        if ((Test-Path -LiteralPath $dest) -and (Get-Sha $dest) -eq $file.sha256) { Remove-Item -LiteralPath $dest }
    }
    $record.status = 'failed'
    $record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $recordPath -Encoding UTF8
    throw
}
[pscustomobject]@{status=$record.status; version=$record.version; installedFiles=$installedFiles;
    originalFilesUnchanged=$originalFiles.Count; backup=$backup; record=$recordPath} | ConvertTo-Json -Depth 5
