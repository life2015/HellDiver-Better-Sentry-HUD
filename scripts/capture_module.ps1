$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$p=Get-Process helldivers2
$m=$p.Modules | Where-Object {$_.ModuleName -eq 'game.dll'} | Select-Object -First 1
$root=Join-Path $env:USERPROFILE 'Desktop\SentryHUD-research'
New-Item -ItemType Directory -Path $root -Force | Out-Null
Add-Type @'
using System;using System.IO;using System.Runtime.InteropServices;
public class SentryModuleCapture {
 [DllImport("kernel32.dll")]static extern IntPtr OpenProcess(uint a,bool i,int p);
 [DllImport("kernel32.dll")]static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,UIntPtr n,out UIntPtr g);
 [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr h);
 static byte[] Read(IntPtr h,long a,int n) {byte[] b=new byte[n];UIntPtr g;if(!ReadProcessMemory(h,new IntPtr(a),b,new UIntPtr((uint)n),out g)||g.ToUInt64()!=(ulong)n)throw new Exception("read failed "+a.ToString("X"));return b;}
 public static void Capture(int pid,long address,string output) {
  IntPtr h=OpenProcess(0x10,false,pid);if(h==IntPtr.Zero)throw new Exception("read access unavailable");
  try {
   var dos=Read(h,address,64);var pe=Read(h,address+BitConverter.ToUInt32(dos,60),96);
   if(BitConverter.ToUInt32(pe,8)!=0x6AB3B43F||BitConverter.ToUInt32(pe,80)!=0x4744000||BitConverter.ToUInt32(pe,88)!=0xECDA6F)throw new Exception("unsupported module");
   using(var f=new FileStream(output,FileMode.Create,FileAccess.Write)) {
    f.SetLength(0x263C000);
    for(int off=0;off<0x263C000;off+=65536){int n=Math.Min(65536,0x263C000-off);byte[] b=Read(h,address+off,n);f.Position=off;f.Write(b,0,n);}
   }
  }finally{CloseHandle(h);}
 }
}
'@
[SentryModuleCapture]::Capture($p.Id,$m.BaseAddress.ToInt64(),(Join-Path $root 'game-code.bin'))
Write-Output "Captured module code/data constants only: $root\game-code.bin"
