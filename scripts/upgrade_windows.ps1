param(
    [Parameter(Mandatory=$true)][string]$ArchivePath,
    [Parameter(Mandatory=$true)][string]$ExpectedZipSha256,
    [Parameter(Mandatory=$true)][string]$ExpectedPatchSha256,
    [Parameter(Mandatory=$true)][string]$ExpectedGpuSha256,
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
$expectedExisting = @{
    '9ba626afa44a3aa3.patch_0' = '86b31f8ef0f3a4065a3a737d1e0aee0fef309f7a1a6e0211c6fee07271f6cc96'
    '9ba626afa44a3aa3.patch_1' = '676ad3d32b43f75379af7162b39614ea22f5201c1b8340f1c07f3f654b3eb5ed'
    '9ba626afa44a3aa3.patch_2' = '8312b06178ad1e63f0f07444920f5e1f61a69adf1e62770786da09af70337e18'
    '9ba626afa44a3aa3.patch_3' = 'bbf19d5caa43516926243df5dd30e241c0306b23f06bddf4d4e8733bd63ecb71'
    '9ba626afa44a3aa3.patch_4' = 'e8dfa3e2efc4cc28bc4962bdd3949a25c57ee1abbaea1b6f7c8bfc034c09bdad'
    '9ba626afa44a3aa3.patch_5' = '4dcf42688afbb26acdb7c2d000f3f74f11379fcaa5fd14af982ef9150cf797bf'
}

if (!$ValidateOnly) { Assert-Closed }
$ArchivePath=(Resolve-Path -LiteralPath $ArchivePath).Path
$work=Split-Path -Parent $ArchivePath
$dataDir=Join-Path $GameRoot 'data'
$steamapps=Split-Path -Parent (Split-Path -Parent $GameRoot)
if ((Get-Content -LiteralPath (Join-Path $steamapps 'appmanifest_553850.acf') -Raw) -notmatch '"buildid"\s+"25480438"') { throw 'Unsupported Steam build' }
if ((Get-Sha $ArchivePath) -ne $ExpectedZipSha256.ToLowerInvariant()) { throw 'ZIP hash mismatch' }
$patchName='9ba626afa44a3aa3.patch_5'
$dest=Join-Path $dataDir $patchName
$existing=@(Get-ChildItem -LiteralPath $dataDir -File | Where-Object {$_.Name -match '^9ba626afa44a3aa3\.patch_\d+$'})
if ($existing.Count -ne $expectedExisting.Count) { throw 'Installed inventory changed' }
$originalFiles=@()
foreach($item in $existing) {
 if (!$expectedExisting.ContainsKey($item.Name) -or (Get-Sha $item.FullName) -ne $expectedExisting[$item.Name]) { throw ('Existing patch changed: '+$item.Name) }
 foreach($suffix in @('','.stream','.gpu_resources')) {
  $f=Get-Item -LiteralPath ($item.FullName+$suffix)
  if ($suffix -ne '' -and $f.Length -ne 0) { throw 'Unexpected sidecar data' }
  $originalFiles += [pscustomobject]@{name=$f.Name;sha256=(Get-Sha $f.FullName);length=$f.Length}
 }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=[IO.Compression.ZipFile]::OpenRead($ArchivePath)
try {
 $allowed=@('Addon/9ba626afa44a3aa3.patch_0','Addon/9ba626afa44a3aa3.patch_0.stream','Addon/9ba626afa44a3aa3.patch_0.gpu_resources','README.txt','THIRD_PARTY.txt','dependencies.json','sentry_hud.cfg.example','manifest.json')
 $names=@($zip.Entries|ForEach-Object {$_.FullName})
 if ($names.Count -ne $allowed.Count -or @(Compare-Object $allowed $names).Count) { throw 'Unexpected ZIP contents' }
 $payloads=@{}
 foreach($suffix in @('','.stream','.gpu_resources')) {
  $entry=$zip.GetEntry('Addon/9ba626afa44a3aa3.patch_0'+$suffix)
  if($entry.Length -gt 4194304){throw 'Oversized addon part'}
  $stream=$entry.Open();$buffer=[IO.MemoryStream]::new()
  try {$stream.CopyTo($buffer);$payloads[$suffix]=$buffer.ToArray()}finally{$stream.Dispose();$buffer.Dispose()}
 }
}finally{$zip.Dispose()}
function Bytes-Sha([byte[]]$Bytes) {
 $sha=[Security.Cryptography.SHA256]::Create()
 try {return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
$patch=$payloads[''];$patchHash=Bytes-Sha $patch;$gpuHash=Bytes-Sha $payloads['.gpu_resources']
if($patchHash -ne $ExpectedPatchSha256.ToLowerInvariant() -or $gpuHash -ne $ExpectedGpuSha256.ToLowerInvariant()){throw 'Addon part hash mismatch'}
if($payloads['.stream'].Length -ne 0){throw 'Unexpected stream data'}
if($patch.Length -lt 416 -or [BitConverter]::ToUInt32($patch,0) -ne [uint32]4026531857 -or [BitConverter]::ToUInt32($patch,4) -ne 3 -or [BitConverter]::ToUInt32($patch,8) -ne 3){throw 'Unexpected addon header'}
$wanted=@{'c70581f9009795d1'='a14e8dfa2cd117e2';'17449bc4467b3462'='cd4238c6a0c69e32';'7662b9e469b07989'='eac0b497876adedf'}
$seen=@{}
for($i=0;$i -lt 3;$i++) {
 $at=168+$i*80;$name=[BitConverter]::ToUInt64($patch,$at).ToString('x16');$kind=[BitConverter]::ToUInt64($patch,$at+8).ToString('x16')
 if(!$wanted.ContainsKey($name) -or $wanted[$name] -ne $kind -or $seen.ContainsKey($name)){throw 'Unexpected or duplicate resource'}
 $seen[$name]=$true;$off=[BitConverter]::ToUInt64($patch,$at+16);$size=[BitConverter]::ToUInt32($patch,$at+56)
 $goff=[BitConverter]::ToUInt64($patch,$at+32);$gsize=[BitConverter]::ToUInt32($patch,$at+64)
 if($off -lt 416 -or $off+$size -gt $patch.Length -or $goff+$gsize -gt $payloads['.gpu_resources'].Length -or $goff%64 -ne 0){throw 'Resource part bounds'}
 if($kind -eq 'cd4238c6a0c69e32'){
  if($size -ne 340 -or $gsize -ne 349552 -or [Text.Encoding]::ASCII.GetString($patch,([int]$off+192),4) -ne 'DDS ' -or [BitConverter]::ToUInt32($patch,([int]$off+204)) -ne 512 -or [BitConverter]::ToUInt32($patch,([int]$off+208)) -ne 512){throw 'Invalid icon texture'}
 }elseif($gsize -ne 0){throw 'Unexpected GPU data'}
}
$config=Join-Path $env:LOCALAPPDATA 'sentry_hud.cfg'
$configHash=if(Test-Path -LiteralPath $config){Get-Sha $config}else{$null}
if ($ValidateOnly) {
 [pscustomobject]@{status='validated';target=$patchName;version='sentry-hud-0.1.0-ui4';patchSha256=$patchHash;gpuSha256=$gpuHash;configPreserved=$true;running=@(Get-Process|Where-Object {$_.ProcessName -match 'helldivers2|arsenal'}|Select-Object -ExpandProperty ProcessName)}|ConvertTo-Json
 exit 0
}
$backup=Join-Path $work 'backup'
$recordPath=Join-Path $work 'deployment.json'
$changedSuffixes=@('.gpu_resources','')
if((Test-Path -LiteralPath $backup) -or (Test-Path -LiteralPath $recordPath)){throw 'Upgrade directory already used'}
foreach($suffix in $changedSuffixes){if(Test-Path -LiteralPath ($dest+$suffix+'.sentry-upgrade-tmp')){throw 'Temporary file already exists'}}
New-Item -ItemType Directory -Path $backup|Out-Null
foreach($f in $originalFiles) {
 if($f.name -like ($patchName+'*')) {
  $saved=Join-Path $backup $f.name;[IO.File]::Copy((Join-Path $dataDir $f.name),$saved,$false)
  if((Get-Sha $saved) -ne $f.sha256){throw 'Backup hash mismatch'}
 }
}
$installedFiles=@()
foreach($suffix in @('','.stream','.gpu_resources')){
 $installedFiles += [pscustomobject]@{name=$patchName+$suffix;sha256=(Bytes-Sha $payloads[$suffix]);length=$payloads[$suffix].Length}
}
$record=[ordered]@{status='prepared';version='sentry-hud-0.1.0-ui4';dataDir=$dataDir;target=$patchName;timeUtc=[DateTime]::UtcNow.ToString('o');zipSha256=(Get-Sha $ArchivePath);previousSha256=$expectedExisting[$patchName];patchSha256=$patchHash;gpuSha256=$gpuHash;originalFiles=$originalFiles;installedFiles=$installedFiles;backup=$backup;config=$config;configSha256=$configHash;managerRegistered=$false}
$record|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $recordPath -Encoding UTF8
$replaced=@()
try {
 foreach($suffix in $changedSuffixes){
  $tmp=$dest+$suffix+'.sentry-upgrade-tmp';[IO.File]::WriteAllBytes($tmp,$payloads[$suffix])
  if((Get-Sha $tmp) -ne (Bytes-Sha $payloads[$suffix])){throw 'Staged part mismatch'}
 }
 Assert-Closed
 foreach($f in $originalFiles){if((Get-Sha (Join-Path $dataDir $f.name)) -ne $f.sha256){throw 'Existing file changed during preparation'}}
 foreach($suffix in $changedSuffixes){
  Assert-Closed
  [IO.File]::Replace(($dest+$suffix+'.sentry-upgrade-tmp'),($dest+$suffix),(Join-Path $backup ('atomic-previous'+$suffix+'.patch')))
  $replaced+=$suffix
 }
 foreach($f in $installedFiles){if((Get-Sha (Join-Path $dataDir $f.name)) -ne $f.sha256){throw 'Installed part mismatch'}}
 foreach($f in $originalFiles){if($f.name -notlike ($patchName+'*') -and (Get-Sha (Join-Path $dataDir $f.name)) -ne $f.sha256){throw 'Unrelated file changed'}}
 if($configHash -and (Get-Sha $config) -ne $configHash){throw 'Position config changed'}
 $record.status='deployed'
 $record|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $recordPath -Encoding UTF8
}catch{
 $record.status='failed'
 foreach($suffix in $changedSuffixes){$tmp=$dest+$suffix+'.sentry-upgrade-tmp';if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp}}
 foreach($suffix in $replaced){
  Assert-Closed
  if((Get-Sha ($dest+$suffix)) -ne (Bytes-Sha $payloads[$suffix])){throw 'Changed installed file; automatic restore stopped'}
  $tmp=$dest+$suffix+'.sentry-upgrade-tmp';[IO.File]::Copy((Join-Path $backup ($patchName+$suffix)),$tmp,$false)
  [IO.File]::Replace($tmp,($dest+$suffix),(Join-Path $backup ('atomic-failed'+$suffix+'.patch')))
 }
 if($replaced.Count){$record.status='restored-after-failure'}
 $record|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $recordPath -Encoding UTF8
 throw
}
[pscustomobject]@{status=$record.status;version=$record.version;patchSha256=(Get-Sha $dest);gpuSha256=(Get-Sha ($dest+'.gpu_resources'));otherFilesUnchanged=15;configPreserved=$true;record=$recordPath}|ConvertTo-Json
