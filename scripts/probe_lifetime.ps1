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
 public int Find(long m,int map,uint id){byte[] b=R(m+map,20);uint cap=BitConverter.ToUInt32(b,8),empty=BitConverter.ToUInt32(b,12),mul=BitConverter.ToUInt32(b,16);long p=(long)BitConverter.ToUInt64(b,0);if(cap==0)return -1;if(cap>131072||(cap&(cap-1))!=0)throw new Exception("hash cap");for(uint i=0;i<Math.Min(cap,128);i++){byte[] row=R(p+8*((unchecked(id*mul)+i)&(cap-1)),8);uint k=BitConverter.ToUInt32(row,0);if(k==empty)return -1;if(k==id)return (int)BitConverter.ToUInt32(row,4);}throw new Exception("hash probes");}
 public object Component(long rva,int map,int back,uint id,long d,int off,int stride){long m=P(game+rva);if(m==0)return null;int i=Find(m,map,id);if(i<0)return null;if(i>16384)throw new Exception("index");long same=P(P(m+back)+i*8);byte[] a=R(P(m+off)+i*stride,stride);return new {manager=m,index=i,descriptor_match=same==d,bytes=Convert.ToBase64String(a)};}
 public object MagazineInstance(uint id,long descriptor){long m=P(game+53634632);int i=Find(m,96,id);byte[] b;
  if(i>=0){if(i>16384)throw new Exception("magazine instance");b=R(P(m+160)+i*160,160);}
  else {ulong type=BitConverter.ToUInt64(R(descriptor,8),0);long table=P(P(game+0x346BF98)+0xF124A0);uint start=(uint)(type%540);b=null;
   for(uint n=0;n<540;n++){byte[] slot=R(table+((start+n)%540)*16,16);ulong key=BitConverter.ToUInt64(slot,0);if(key==0)break;if(key==type){uint row=BitConverter.ToUInt32(slot,8);if(row>=540)throw new Exception("magazine settings index");b=R(table+8640+row*160,160);break;}}
  }
  if(b==null)return null;return new {maximum=BitConverter.ToUInt32(b,136),chambered=b[156],bytes=Convert.ToBase64String(b)};
 }
 public object NetworkOwner(uint goid){
  long obj=P(P(exe+0x1A10278)+0xA8);byte[] h=R(obj+0x648,32);long data=(long)BitConverter.ToUInt64(h,0);uint count=BitConverter.ToUInt32(h,16),cap=BitConverter.ToUInt32(h,20);
  if(count==0)return null;if(cap==0||cap>65536||count>cap)throw new Exception("network capacity");
  uint hash=unchecked(goid*0x5BD1E995);hash^=hash>>24;hash=unchecked(hash*0x5BD1E995);uint slot=hash%cap;
  for(int n=0;n<128;n++){if(slot>=U(obj+0x640))return null;byte[] row=R(data+slot*0x248,0x248);uint next=BitConverter.ToUInt32(row,0x240);if(next==0xFFFFFFFE)return null;if(BitConverter.ToUInt32(row,0)==goid)return new {slot=slot,owner=BitConverter.ToUInt64(row,16).ToString("X16"),raw=Convert.ToBase64String(row)};if(next==0x7FFFFFFF)return null;slot=next;}throw new Exception("network chain");
 }
 public object Lifetime(uint id,long descriptor){
  long m=P(game+0x3326560);int i=Find(m,0x28,id);if(i<0)return null;
  if(i>=U(m+0x14)||i>16384)throw new Exception("payload bounds");
  long back=P(m+0x40);if(P(back+i*8)!=descriptor)throw new Exception("payload identity");
  long data=P(m+0x50);byte[] value=R(data+i*8,8);float remaining=BitConverter.ToSingle(value,4);
  float retract=BitConverter.ToSingle(R(P(m+0x48)+i*4,4),0);
  if(float.IsNaN(remaining)||float.IsInfinity(remaining)||remaining>86400)throw new Exception("timer value");
  if(P(back+i*8)!=descriptor||P(m+0x50)!=data)throw new Exception("payload changed");
  return new {remaining=remaining,retract=retract,network0=BitConverter.ToUInt32(value,0),descriptor_match=true};
 }
 public object Sample(){memory.Clear();
  if(BitConverter.ToString(R(game+0x93233a,32)).Replace("-", "").ToLowerInvariant()!="498b4650f30f1044c8040f2fc60f86d0020000f30f5cc70f2ff0f30f1144c804")throw new Exception("lifetime code changed");
  byte[] dos=R(game,64),pe=R(game+BitConverter.ToUInt32(dos,60),96);if(BitConverter.ToUInt32(pe,8)!=0x6AB3B43F||BitConverter.ToUInt32(pe,80)!=0x4744000||BitConverter.ToUInt32(pe,88)!=0xECDA6F)throw new Exception("unsupported build");
  long user=P(game+0x347CEF0);string peer=H(user+0xB398);long hm=P(game+0x3326688);byte[] head=R(hm+0x1010,88);int count=(int)BitConverter.ToUInt32(head,16);if(count<0||count>4096)throw new Exception("count");
  var sentries=new List<object>();var types=new HashSet<string>{"EF85D6CF58E31D70","37CDE43876BA26BB","54D86057F5DACFB9","37079568DC86E9C6","51A0812E3BCE2D74","B2053A1838092F8B","299C0D3DFD2F0994","820CC3BAFE962858","56070F36CFFFA8A8","74599E56F72F9D7E"};
  long descriptors=P(hm+0x1048),records=P(hm+0x1058),ext=P(hm+0x1060);if(count>0)R(descriptors,count*8);
  for(int i=0;i<count;i++){long d=P(descriptors+i*8);byte[] desc=R(d,24);string type=BitConverter.ToUInt64(desc,0).ToString("X16");if(!types.Contains(type))continue;uint id=BitConverter.ToUInt32(desc,8);byte[] health=R(records+i*440,440);byte[] extra=R(ext+i*28,28);
   sentries.Add(new {type=type,entity=id,descriptor=d,owner_info=NetworkOwner(BitConverter.ToUInt32(desc,16)),hp=BitConverter.ToInt32(health,20),max_hp=BitConverter.ToUInt32(extra,20),life=BitConverter.ToUInt32(health,412),
    lifetime=Lifetime(id,d),magazine_instance=MagazineInstance(id,d),magazine=Component(53634632,32,56,id,d,80,12),magazine_runtime=Component(53634632,32,56,id,d,72,16),rounds=Component(53636336,40,64,id,d,88,20)});
  }
  long network=P(game+0x3326308),functions=P(network+0x40),getter=P(functions+0x160),context=P(P(network+0x38)+8);R(getter,1024);R(context,256);long networkObject=P(P(exe+0x1A10278)+0xA8);long vt=P(networkObject);R(networkObject,2048);R(vt,1024);R(P(vt+0x178),1536);R(P(vt+0xF8),256);
  return new {utc=DateTime.UtcNow.ToString("o"),game=game,exe=exe,peer=peer,count=count,sentries=sentries,network_getter=getter,network_context=context,network_object=networkObject,network_vtable=vt,memory=memory};
 }
 public void Dispose(){CloseHandle(h);}
}
'@
$reader=[SentryRead]::new($p.Id,$m.BaseAddress.ToInt64(),$p.MainModule.BaseAddress.ToInt64())
try{
 for($i=0;$i -lt $Samples;$i++){
  $s=$reader.Sample()
  $file=Join-Path $root ('lifetime-sample-'+$i+'.json')
  $s | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $file -Encoding UTF8
  [pscustomobject]@{sample=$i;health_count=$s.count;sentry_count=$s.sentries.Count;sentries=@($s.sentries|Select-Object type,entity,hp,max_hp,lifetime);getter=$s.network_getter;context=$s.network_context}|ConvertTo-Json -Depth 6 -Compress
  if($i+1 -lt $Samples){Start-Sleep -Milliseconds $DelayMs}
 }
}finally{$reader.Dispose()}
