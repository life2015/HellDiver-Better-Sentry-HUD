param([int]$Samples=1,[int]$DelayMs=250)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$p=Get-Process helldivers2
$m=$p.Modules | Where-Object {$_.ModuleName -eq 'game.dll'} | Select-Object -First 1
$root=Join-Path $env:USERPROFILE 'Desktop\SentryHUD-research'
New-Item -ItemType Directory -Path $root -Force | Out-Null
Add-Type @'
using System;using System.Collections.Generic;using System.Runtime.InteropServices;
public class SentryRead : IDisposable {
 [DllImport("kernel32.dll")]static extern IntPtr OpenProcess(uint a,bool i,int p);
 [DllImport("kernel32.dll")]static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,UIntPtr n,out UIntPtr g);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 IntPtr h;public long game,exe;public Dictionary<string,string> memory=new Dictionary<string,string>();
 public SentryRead(int pid,long g,long e){h=OpenProcess(0x10,false,pid);if(h==IntPtr.Zero)throw new Exception("read access");game=g;exe=e;}
 public byte[] R(long a,int n){if(a<65536||a>=0x800000000000||n<1||n>1048576)throw new Exception("range");byte[] b=new byte[n];UIntPtr g;if(!ReadProcessMemory(h,new IntPtr(a),b,new UIntPtr((uint)n),out g)||g.ToUInt64()!=(ulong)n)throw new Exception("read "+a.ToString("X"));string key=a.ToString();if(!memory.ContainsKey(key)||Convert.FromBase64String(memory[key]).Length<=n)memory[key]=Convert.ToBase64String(b);return b;}
 public long P(long a){return (long)BitConverter.ToUInt64(R(a,8),0);}
 public uint U(long a){return BitConverter.ToUInt32(R(a,4),0);}
 public string H(long a){return BitConverter.ToUInt64(R(a,8),0).ToString("X16");}
 public object Box(byte[] bytes,int at){
  return new {offset=at,x=BitConverter.ToSingle(bytes,at+148),y=BitConverter.ToSingle(bytes,at+156),width=BitConverter.ToSingle(bytes,at+36),height=BitConverter.ToSingle(bytes,at+40),scale=BitConverter.ToSingle(bytes,at+100),shown=BitConverter.ToSingle(bytes,at+84)};
 }
 public object Sample(){memory.Clear();
  byte[] dos=R(game,64),pe=R(game+BitConverter.ToUInt32(dos,60),96);if(BitConverter.ToUInt32(pe,8)!=0x6AB3B43F||BitConverter.ToUInt32(pe,80)!=0x4744000||BitConverter.ToUInt32(pe,88)!=0xECDA6F)throw new Exception("unsupported build");
  long hud=P(game+0x346d538);long panel=hud+0x24e340+0x60;byte[] raw=R(panel,22300);
  if(P(game+0x346d538)!=hud)throw new Exception("HUD changed");
  var boxes=new List<object>();boxes.Add(Box(raw,1968));boxes.Add(Box(raw,2864));
  return new {utc=DateTime.UtcNow.ToString("o"),game=game,exe=exe,hud=hud,panel=panel,boxes=boxes,memory=memory};
 }
 public void Dispose(){CloseHandle(h);}
}
'@
$reader=[SentryRead]::new($p.Id,$m.BaseAddress.ToInt64(),$p.MainModule.BaseAddress.ToInt64())
try{
 for($i=0;$i -lt $Samples;$i++){
  $s=$reader.Sample()
  $file=Join-Path $root ('hud-sample-'+$i+'.json')
  $s | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $file -Encoding UTF8
  $s | Select-Object utc,game,hud,panel,boxes | ConvertTo-Json -Depth 6 -Compress
  if($i+1 -lt $Samples){Start-Sleep -Milliseconds $DelayMs}
 }
}finally{$reader.Dispose()}
