# Read-only DSAR/DSAA extraction, based on HD2Runtime scripts/hd2_game_data.py.
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
Add-Type @'
using System;using System.IO;using System.Collections.Generic;using System.Text;
public class SentryIconsExtract : IDisposable {
 class Chunk {public ulong off,pos;public int raw,size;public byte comp;}
 class Bundle {public FileStream f;public Chunk[] chunks;public Dictionary<ulong,int> offsets=new Dictionary<ulong,int>();}
 class Entry {public uint a,b;public byte bundle;}
 class Item {public ulong size;public Entry[] entries;}
 Bundle[] bundles;Dictionary<string,Item> items=new Dictionary<string,Item>();
 Dictionary<string,byte[]> cache=new Dictionary<string,byte[]>();Queue<string> order=new Queue<string>();
 static uint U(byte[] b,int i){return BitConverter.ToUInt32(b,i);}static ulong Q(byte[] b,int i){return BitConverter.ToUInt64(b,i);}
 static byte[] R(FileStream f,long p,int n){if(p<0||n<0||p+n>f.Length)throw new Exception("file bounds");f.Position=p;byte[] b=new byte[n];int at=0;while(at<n){int got=f.Read(b,at,n-at);if(got==0)throw new Exception("short read");at+=got;}return b;}
 static Bundle Open(string path){
  Bundle b=new Bundle();b.f=new FileStream(path,FileMode.Open,FileAccess.Read,FileShare.ReadWrite);
  byte[] h=R(b.f,0,32);if(Encoding.ASCII.GetString(h,0,4)!="DSAR")throw new Exception("not DSAR");
  uint n=U(h,8);if(n>1000000)throw new Exception("chunk count");byte[] rows=R(b.f,32,checked((int)n*32));b.chunks=new Chunk[n];
  for(int i=0;i<n;i++){int a=i*32;Chunk c=new Chunk{off=Q(rows,a),pos=Q(rows,a+8),raw=checked((int)U(rows,a+16)),size=checked((int)U(rows,a+20)),comp=rows[a+24]};if(c.raw<0||c.size<0||c.pos+(ulong)c.size>(ulong)b.f.Length)throw new Exception("chunk bounds");b.chunks[i]=c;b.offsets.Add(c.off,i);}return b;
 }
 static byte[] Decode(Bundle b,int i){Chunk c=b.chunks[i];if(c.raw>256*1024*1024)throw new Exception("needed chunk too large: "+c.raw);byte[] src=R(b.f,checked((long)c.pos),c.size);if(c.comp==0){if(src.Length!=c.raw)throw new Exception("raw size");return src;}if(c.comp!=3)throw new Exception("compression");
  byte[] dst=new byte[c.raw];int s=0,d=0;while(s<src.Length){int token=src[s++],lit=token>>4;if(lit==15){int x;do{x=src[s++];lit+=x;}while(x==255);}Buffer.BlockCopy(src,s,dst,d,lit);s+=lit;d+=lit;if(s==src.Length)break;int off=src[s]|src[s+1]<<8;s+=2;int match=(token&15)+4;if((token&15)==15){int x;do{x=src[s++];match+=x;}while(x==255);}if(off<=0||off>d||d+match>dst.Length)throw new Exception("LZ4 bounds");for(int j=0;j<match;j++){dst[d]=dst[d-off];d++;}}if(d!=dst.Length)throw new Exception("LZ4 size");return dst;
 }
 byte[] Get(int b,int i){string key=b+":"+i;byte[] data;if(cache.TryGetValue(key,out data))return data;data=Decode(bundles[b],i);cache.Add(key,data);order.Enqueue(key);if(order.Count>256)cache.Remove(order.Dequeue());return data;}
 static string S(byte[] b,uint off){int end=Array.IndexOf(b,(byte)0,checked((int)off));if(end<0)throw new Exception("string");return Encoding.UTF8.GetString(b,(int)off,end-(int)off);}
 public SentryIconsExtract(string dir){
  byte[] idx;Bundle index=Open(Path.Combine(dir,"bundles.nxa"));try{using(var o=new MemoryStream()){for(int i=0;i<index.chunks.Length;i++){byte[] b=Decode(index,i);o.Write(b,0,b.Length);}idx=o.ToArray();}}finally{index.f.Dispose();}
  if(Encoding.ASCII.GetString(idx,0,4)!="DSAA")throw new Exception("not DSAA");uint n=U(idx,12),count=U(idx,16);bundles=new Bundle[n];
  for(int i=0;i<n;i++)bundles[i]=Open(Path.Combine(dir,S(idx,U(idx,checked(24+(int)count*24+i*4)))));
  for(int i=0;i<count;i++){int at=24+i*24;uint no=U(idx,at+8),en=U(idx,at+12);ulong ep=Q(idx,at+16);Item item=new Item{size=Q(idx,at),entries=new Entry[en]};for(int j=0;j<en;j++){int e=checked((int)ep+j*16);item.entries[j]=new Entry{a=U(idx,e),b=U(idx,e+8),bundle=idx[e+15]};}items.Add(S(idx,no),item);}
 }
 byte[] Read(string name,ulong start,int length){Item item=items[name];if(start+(ulong)length>item.size)throw new Exception("item bounds");byte[] result=new byte[length];int wrote=0;
  for(int i=0;i<item.entries.Length;i++){Entry e=item.entries[i];ulong end=i+1<item.entries.Length?item.entries[i+1].a:item.size;if(end<=start||e.a>=start+(ulong)length)continue;int ci=bundles[e.bundle].offsets[e.b];ulong pos=e.a;
   while(pos<end&&pos<start+(ulong)length){byte[] b=Get(e.bundle,ci++);ulong lo=Math.Max(pos,start),hi=Math.Min(Math.Min(pos+(ulong)b.Length,end),start+(ulong)length);if(lo<hi){int size=checked((int)(hi-lo));Buffer.BlockCopy(b,checked((int)(lo-pos)),result,checked((int)(lo-start)),size);wrote+=size;}pos+=(ulong)b.Length;}}
  if(wrote!=length)throw new Exception("item short read");return result;
 }
 public object Extract(string output){int scanned=0;var names=new List<string>(items.Keys);names.Sort();
  foreach(string name in names){if(name.Length!=16||name.Contains("."))continue;scanned++;byte[] h=Read(name,0,72);if(U(h,0)!=0xF0000011)continue;uint tc=U(h,4),ec=U(h,8);if(tc>4096||ec>1000000)throw new Exception("table bounds");byte[] rows=Read(name,72+tc*32,checked((int)ec*80));
   for(int i=0;i<ec;i++){int a=i*80;if(Q(rows,a)!=0x7c6e2910b1a074a6UL||Q(rows,a+8)!=0x46bc82aae9ae0565UL)continue;int size=checked((int)U(rows,a+56));if(size>16000000)throw new Exception("resource size");byte[] blob=Read(name,Q(rows,a+16),size);File.WriteAllBytes(output,blob);return new{scanned=scanned,archive=name,bytes=size,output=output};}
  }throw new Exception("icon library not found after "+scanned);
 }
 public void Dispose(){if(bundles!=null)foreach(var b in bundles)if(b!=null)b.f.Dispose();}
}
'@
$root=Join-Path $env:USERPROFILE 'Desktop\SentryHUD-research'
$reader=[SentryIconsExtract]::new('C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\data')
try{$reader.Extract((Join-Path $root 'stratagem_icons.bin'))|ConvertTo-Json}finally{$reader.Dispose()}
