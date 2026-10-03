param([Parameter(Mandatory=$true)][string]$ZipName,[Parameter(Mandatory=$true)][string]$ZipSha,[Parameter(Mandatory=$true)][string]$PatchSha,[Parameter(Mandatory=$true)][string]$GpuSha)
# Integration test of the real installer, exclusively against copied files.
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$real='C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2'
$test=Join-Path $PSScriptRoot 'installer-check'
if(Test-Path -LiteralPath $test){throw 'Test directory already used'}
New-Item -ItemType Directory -Path $test|Out-Null
$before=@(Get-ChildItem -LiteralPath (Join-Path $real 'data') -File|Where-Object {$_.Name -match '^9ba626afa44a3aa3\.patch_\d+(\.stream|\.gpu_resources)?$'}|ForEach-Object {
 [pscustomobject]@{name=$_.Name;sha=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
foreach($scenario in @('normal','locked-main')){
 $homeTest=Join-Path $test $scenario
 $fakeGame=Join-Path $homeTest 'steamapps\common\Helldivers 2';$data=Join-Path $fakeGame 'data'
 $run=Join-Path $homeTest 'run';New-Item -ItemType Directory -Path $data,$run -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path (Split-Path -Parent (Split-Path -Parent $real)) 'appmanifest_553850.acf') -Destination (Join-Path $homeTest 'steamapps\appmanifest_553850.acf')
 foreach($f in $before){Copy-Item -LiteralPath (Join-Path $real ('data\'+$f.name)) -Destination (Join-Path $data $f.name)}
 foreach($name in @($ZipName,'upgrade_windows.ps1','rollback_upgrade.ps1')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $run $name)}
 $params=@{ArchivePath=(Join-Path $run $ZipName);ExpectedZipSha256=$ZipSha;ExpectedPatchSha256=$PatchSha;ExpectedGpuSha256=$GpuSha;GameRoot=$fakeGame}
 if($scenario -eq 'normal'){
  & (Join-Path $run 'upgrade_windows.ps1') @params|Out-Null
  $r=Get-Content -LiteralPath (Join-Path $run 'deployment.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if($r.status -ne 'deployed' -or $r.dataDir -ne $data){throw 'Test deployment failed'}
  & (Join-Path $run 'rollback_upgrade.ps1')|Out-Null
 }else{
  $lock=[IO.File]::Open((Join-Path $data '9ba626afa44a3aa3.patch_5'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
  $failed=$false
  try{try{& (Join-Path $run 'upgrade_windows.ps1') @params|Out-Null}catch{$failed=$true}}finally{$lock.Dispose()}
  if(!$failed){throw 'Expected locked main replacement failure'}
  $r=Get-Content -LiteralPath (Join-Path $run 'deployment.json') -Raw -Encoding UTF8|ConvertFrom-Json
  if($r.status -ne 'restored-after-failure'){throw ('Expected GPU automatic restore: '+$r.status)}
 }
 foreach($f in $before){if((Get-FileHash -LiteralPath (Join-Path $data $f.name) -Algorithm SHA256).Hash -ne $f.sha){throw ('Copied inventory did not restore: '+$f.name)}}
 Write-Output ('PASS: '+$scenario+' copied-file upgrade/restoration')
}
foreach($f in $before){if((Get-FileHash -LiteralPath (Join-Path $real ('data\'+$f.name)) -Algorithm SHA256).Hash -ne $f.sha){throw 'Real game files changed during test'}}
Write-Output 'PASS: real game files unchanged'
