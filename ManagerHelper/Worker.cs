// UI-free .NET Framework worker. No PowerShell, policy changes, scripts from mods,
// administrator privileges, game memory access, or process termination.
using System;
using System.IO;
using System.IO.Compression;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

partial class Worker {
 static JavaScriptSerializer Json=new JavaScriptSerializer{MaxJsonLength=1048576,RecursionLimit=32};
 static string ModRoot,ModsRoot,Data,JobPath;
 static readonly object NetworkSync=new object();
 static Dictionary<string,object> D(object x){var d=x as Dictionary<string,object>;if(d==null)throw new Exception("JSON object required");return d;}
 static object G(object x,string k,object fallback=null){object v;return D(x).TryGetValue(k,out v)?v:fallback;}
 static string S(object x,string k,string fallback=""){return Convert.ToString(G(x,k,fallback),System.Globalization.CultureInfo.InvariantCulture);}
 static IEnumerable<object> A(object x){return x==null?new object[0]:((IEnumerable)x).Cast<object>();}
 static Dictionary<string,object> Obj(params object[] pairs){var d=new Dictionary<string,object>();for(int i=0;i<pairs.Length;i+=2)d.Add((string)pairs[i],pairs[i+1]);return d;}
 static void Need(bool ok,string why){if(!ok)throw new Exception(why);}
 static object Read(string p){Need(new FileInfo(p).Length<=1048576,"JSON size limit");lock(Json)return Json.DeserializeObject(File.ReadAllText(p));}
 static void Write(string p,object value){Directory.CreateDirectory(Path.GetDirectoryName(p));string t=p+".tmp";string encoded;lock(Json)encoded=Json.Serialize(value);File.WriteAllText(t,encoded,new UTF8Encoding(false));if(File.Exists(p))File.Replace(t,p,null);else File.Move(t,p);}
 static string Hash(string p){using(var s=File.OpenRead(p))using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(s)).Replace("-","").ToLowerInvariant();}
 static bool Inside(string root,string p){return Path.GetFullPath(p).StartsWith(Path.GetFullPath(root).TrimEnd('\\')+"\\",StringComparison.OrdinalIgnoreCase);}
 static string Child(string root,string rel){
  Need(!String.IsNullOrEmpty(rel)&&!rel.Contains('\\')&&!rel.Contains(':')&&!rel.StartsWith("/")&&!rel.Any(c=>c<32),"Invalid relative path");
  foreach(string part in rel.Split('/'))Need(part!=""&&part!="."&&part!=".."&&!part.EndsWith(".")&&!part.EndsWith(" ")&&!Regex.IsMatch(part,@"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)",RegexOptions.IgnoreCase),"Unsafe path segment");
  string p=Path.GetFullPath(Path.Combine(root,rel));Need(Inside(root,p),"Path escape");
  for(string q=p;q!=null&&q.Length>=Path.GetFullPath(root).Length;q=Path.GetDirectoryName(q))if(File.Exists(q)||Directory.Exists(q))Need((File.GetAttributes(q)&FileAttributes.ReparsePoint)==0,"Symlink/junction target rejected");return p;
 }
 static bool VersionOK(string value,string range){
  Version v;try{v=Version.Parse(value.Split('-')[0]);}catch{return false;}
  if(String.IsNullOrWhiteSpace(range))return false;
  foreach(string token in range.Split(new[]{' '},StringSplitOptions.RemoveEmptyEntries)){
   if(token=="*")continue;var m=Regex.Match(token,@"^(>=|<=|>|<|=|\^)?(\d+\.\d+\.\d+)$");if(!m.Success)return false;Version t=Version.Parse(m.Groups[2].Value);int c=v.CompareTo(t);
   switch(m.Groups[1].Value){case ">=":if(c<0)return false;break;case "<=":if(c>0)return false;break;case ">":if(c<=0)return false;break;case "<":if(c>=0)return false;break;case "^":Version top=t.Major>0?new Version(t.Major+1,0,0):t.Minor>0?new Version(0,t.Minor+1,0):new Version(0,0,t.Build+1);if(c<0||v>=top)return false;break;default:if(c!=0)return false;break;}
  }return true;
 }
 static string ReleaseURL(object m){object source=G(m,"release_source");return source==null?S(m,"repository"):S(source,"repository")+(S(source,"tag")==""?"":"/releases/tag/"+S(source,"tag"));}
 static Source UpdateSource(object metadata,string work){
  object source=G(metadata,"release_source");string prefix=source==null?"":S(source,"tag_prefix");
  if(prefix=="")return Resolve(ReleaseURL(metadata),work,S(metadata,"channel")=="prerelease",ManifestAsset(metadata));
  var uri=Https(S(source,"repository"));Need(uri.Host=="github.com"&&Regex.IsMatch(uri.AbsolutePath,@"^/[\w.-]+/[\w.-]+/?$"),"Invalid component release repository");
  string listing=Path.Combine(work,"component-releases.json");Fetch("https://api.github.com/repos"+uri.AbsolutePath.TrimEnd('/')+"/releases?per_page=20",listing,1048576);
  return Resolve(SelectComponentRelease(metadata,Read(listing)),work);
 }
 static string SelectComponentRelease(object metadata,object releases){
  object source=G(metadata,"release_source");string prefix=S(source,"tag_prefix");
  foreach(object release in A(releases)){
   if(Convert.ToBoolean(G(release,"draft",false))||!S(release,"tag_name").StartsWith(prefix,StringComparison.Ordinal)||Convert.ToBoolean(G(release,"prerelease",false))&&S(metadata,"channel")!="prerelease")continue;
   var asset=A(G(release,"assets")).FirstOrDefault(x=>S(x,"name")==ManifestAsset(metadata));if(asset!=null)return S(asset,"browser_download_url");
  }
  throw new Exception("No compatible component release in the newest 20 releases");
 }
 static string ManifestAsset(object m){object source=G(m,"release_source");return source==null?"mod.json":S(source,"manifest_asset","mod.json");}
 static bool Standalone(object m){return G(m,"standalone")is bool&&(bool)G(m,"standalone");}
 static void Metadata(object m){
  Need(Convert.ToInt32(G(m,"schema_version"))==1&&Regex.IsMatch(S(m,"id"),@"^[A-Za-z0-9_-]{1,64}$")&&S(m,"name").Length>0&&S(m,"name").Length<=160&&Regex.IsMatch(S(m,"version"),@"^\d+\.\d+\.\d+(-[\w.-]+)?$"),"Invalid mod.json identity/schema");
  Need(G(m,"standalone")==null||G(m,"standalone")is bool,"Invalid standalone flag");Need(Standalone(m)||(S(m,"api").Length>0&&S(m,"api").Length<=120),"API requirement missing");
  if(G(m,"package")!=null)Need(S(G(m,"package"),"format")=="bladesong-mod-1"&&S(G(m,"package"),"target")=="ue4ss-mods","Unsupported portable package target");
  if(G(m,"dependency_sources")!=null)foreach(var source in D(G(m,"dependency_sources"))){Need(Regex.IsMatch(source.Key,@"^[A-Za-z0-9_-]{1,64}$"),"Invalid dependency source ID");Https(Convert.ToString(source.Value));}
  object caps=G(m,"capabilities");if(caps!=null){Need(GIsArray(caps),"Capabilities must be an array");Need(A(caps).Count()<=64,"Capability count limit");foreach(object c in A(caps))Need(c is string&&Regex.IsMatch((string)c,@"^[A-Za-z0-9_.-]{1,120}$"),"Invalid capability");}
  foreach(string field in new[]{"dependencies","optional_dependencies"})if(G(m,field)!=null)foreach(var dep in D(G(m,field)))Need(Regex.IsMatch(dep.Key,@"^[A-Za-z0-9_-]{1,64}$")&&dep.Value is string&&((string)dep.Value).Length<=120,"Invalid dependency");
  if(G(m,"raw_integration")!=null){object raw=G(m,"raw_integration");Need(S(raw,"reason").Length>0&&GIsArray(G(raw,"game_builds")),"Explicit raw integration needs a reason and hashes");var hashes=A(G(raw,"game_builds")).ToList();Need(hashes.Count>0&&hashes.Count<=64&&hashes.All(h=>h is string&&Regex.IsMatch((string)h,@"^[a-fA-F0-9]{64}$")),"Invalid raw integration fingerprint");}
 }
 static void Manifest(object m){
  Metadata(m);
  Need(Convert.ToInt32(G(m,"schema_version"))==1&&Regex.IsMatch(S(m,"id"),@"^[A-Za-z0-9_-]{1,64}$")&&S(m,"name").Length>0&&Regex.IsMatch(S(m,"version"),@"^\d+\.\d+\.\d+(-[\w.-]+)?$"),"Invalid manifest identity/schema");
  Need(Standalone(m)||VersionOK("1.0.0",S(m,"api")),"Unsupported API range");Need(G(m,"signature")==null,"Unsupported signature type; cannot validate it");
  var files=A(G(m,"files")).ToList();Need(files.Count>0&&files.Count<=4096,"File count limit");var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);long total=0;
  foreach(var f in files){string p=S(f,"path");Need(p!="deployment.json"&&p!="bmf-installed.json"&&p!="mod.json"&&p!="bmf-manifest.json","Reserved installation record");Child(Data,p);Need(seen.Add(p),"Duplicate file path");Need(!Regex.IsMatch(p,@"(^|/)(SaveGames|preconstructions|blades|Data)(/|$)|\.(sav|dmp|log)$",RegexOptions.IgnoreCase),"Personal data path rejected");Need(Regex.IsMatch(S(f,"sha256"),@"^[a-fA-F0-9]{64}$"),"Invalid SHA256");long size=Convert.ToInt64(G(f,"size"));Need(size>=0&&size<=67108864,"File size limit");total+=size;}
  Need(total<=268435456,"Extraction limit");
 }
 static Uri Https(string value){Uri u;Need(Uri.TryCreate(value,UriKind.Absolute,out u)&&u.Scheme=="https"&&u.UserInfo==""&&u.Fragment==""&&u.Port==443,"HTTPS URL required (no credentials, fragment or custom port)");return u;}
 static void Fetch(string url,string path,long limit=67108864,int timeout=30000){
  Uri u=Https(url);ServicePointManager.SecurityProtocol=SecurityProtocolType.Tls12;
  for(int hop=0;hop<6;hop++){
   var r=(HttpWebRequest)WebRequest.Create(u);r.AllowAutoRedirect=false;r.UserAgent="BladesongModManager/0.1.2";r.Timeout=timeout;r.ReadWriteTimeout=timeout;
   string rate=Path.Combine(Data,"rate-"+TextHash(u.Host)+".json");lock(NetworkSync){if(File.Exists(rate)){DateTime until;if(DateTime.TryParse(S(Read(rate),"until"),out until)&&until.ToUniversalTime()>DateTime.UtcNow)throw new Exception("Provider rate limit cooldown; using cached metadata where available");}}
   HttpWebResponse received;try{received=(HttpWebResponse)r.GetResponse();}catch(WebException e){var failed=e.Response as HttpWebResponse;if(failed!=null){using(failed){if((int)failed.StatusCode==429||((int)failed.StatusCode==403&&(failed.Headers["X-RateLimit-Remaining"]=="0"||failed.Headers["Retry-After"]!=null))){int seconds;long reset;DateTime until=DateTime.UtcNow.AddMinutes(15);if(Int32.TryParse(failed.Headers["Retry-After"],out seconds))until=DateTime.UtcNow.AddSeconds(Math.Min(86400,Math.Max(1,seconds)));else if(Int64.TryParse(failed.Headers["X-RateLimit-Reset"],out reset))until=new DateTime(1970,1,1,0,0,0,DateTimeKind.Utc).AddSeconds(reset);lock(NetworkSync)Write(rate,Obj("until",until.ToString("o")));throw new Exception("Provider rate limit reached; cached metadata remains available");}}}throw;}
   using(var response=received){
    int status=(int)response.StatusCode;if(status>=300&&status<400){u=Https(new Uri(u,response.Headers["Location"]).AbsoluteUri);continue;}
    Need(response.ContentLength<=limit,"Download limit");using(var input=response.GetResponseStream())using(var output=File.Create(path)){byte[] buf=new byte[65536];long n=0;int count;while((count=input.Read(buf,0,buf.Length))>0){n+=count;Need(n<=limit,"Download limit");output.Write(buf,0,count);}}return;
   }
  }throw new Exception("Too many redirects");
 }
 class Source {public object Manifest;public string Url,Archive,Digest;}
 static Source Resolve(string url,string work,bool prerelease=false,string assetName="mod.json"){
  var u=Https(url);Need(!u.Host.EndsWith("nexusmods.com",StringComparison.OrdinalIgnoreCase),"Nexus webpage provider is not implemented");string source=url;
  if(u.Host=="github.com"){
   var p=u.AbsolutePath.Trim('/').Split('/');Need(p.Length>=2&&Regex.IsMatch(p[0],@"^[\w.-]+$")&&Regex.IsMatch(p[1],@"^[\w.-]+$"),"Invalid GitHub repository");
   if(p.Length==2||(p.Length>=3&&p[2]=="releases"&&!(p.Length>=4&&p[3]=="download"))){
    string api="https://api.github.com/repos/"+p[0]+"/"+p[1]+"/releases";
    if(p.Length==5&&p[3]=="tag")api+="/tags/"+Uri.EscapeDataString(p[4]);else api+=prerelease?"":"/latest";
    string release=Path.Combine(work,"release.json");Fetch(api,release,1048576);object metadata=Read(release);
    if(prerelease&&GIsArray(metadata))metadata=A(metadata).First(x=>!Convert.ToBoolean(G(x,"draft",false)));
    var assets=A(G(metadata,"assets")).Where(x=>S(x,"name")==assetName).ToList();if(assets.Count==0)assets=A(G(metadata,"assets")).Where(x=>S(x,"name")=="bmf-release.json").ToList();if(assets.Count==0&&!(p.Length==5&&p[3]=="tag")){
     string list=Path.Combine(work,"fallback-releases.json");Fetch("https://api.github.com/repos/"+p[0]+"/"+p[1]+"/releases?per_page=20",list,1048576);
     foreach(object other in A(Read(list))){if(Convert.ToBoolean(G(other,"draft",false))||Convert.ToBoolean(G(other,"prerelease",false))&&!prerelease)continue;assets=A(G(other,"assets")).Where(x=>S(x,"name")==assetName).ToList();if(assets.Count>0)break;}
    }
    Need(assets.Count==1,"Release requires one mod.json asset (legacy bmf-release.json accepted)");source=S(assets[0],"browser_download_url");
   }
  }
  string path=Path.Combine(work,"source");Fetch(source,path);object m;string archive=null;
  if(Https(source).AbsolutePath.EndsWith(".zip",StringComparison.OrdinalIgnoreCase)){
   using(var z=ZipFile.OpenRead(path)){var entries=z.Entries.Where(x=>x.FullName=="mod.json").ToList();if(entries.Count==0)entries=z.Entries.Where(x=>x.FullName=="bmf-manifest.json").ToList();Need(entries.Count==1&&entries[0].Length<=1048576,"Archive needs bounded root manifest");using(var reader=new StreamReader(entries[0].Open()))m=Json.DeserializeObject(reader.ReadToEnd());}archive=path;
  }else m=Read(path);
  Manifest(m);if(archive==null){var download=G(m,"download");Need(download!=null&&Regex.IsMatch(S(download,"sha256"),@"^[a-fA-F0-9]{64}$"),"Manifest needs archive hash");Https(S(download,"url"));}
  return new Source{Manifest=m,Url=source,Archive=archive,Digest=Hash(path)};
 }
 static string TextHash(string value){using(var h=SHA256.Create())return BitConverter.ToString(h.ComputeHash(Encoding.UTF8.GetBytes(value))).Replace("-","").ToLowerInvariant();}
 static void Index(object index){
  Need(D(index).Count==1&&G(index,"mods")!=null,"Registry index must contain only mods");var mods=A(G(index,"mods")).ToList();Need(mods.Count<=64,"Registry entry limit");var seen=new HashSet<string>();
  foreach(var entry in mods){Need(D(entry).Count==2&&S(entry,"name").Length>0&&S(entry,"name").Length<=160,"Index entries contain only name and url");var u=Https(S(entry,"url"));Need(u.Host=="github.com"&&Regex.IsMatch(u.AbsolutePath,@"^/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/?$")&&u.Query=="","Index requires a GitHub repository URL");Need(seen.Add(u.AbsoluteUri.TrimEnd('/').ToLowerInvariant()),"Duplicate repository");}
 }
 static object RepoMetadata(string repository,string work){
  var u=Https(repository);Need(u.Host=="github.com"&&Regex.IsMatch(u.AbsolutePath,@"^/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/?$"),"GitHub repository required");
  string file=Path.Combine(work,"contents.json");Fetch("https://api.github.com/repos"+u.AbsolutePath.TrimEnd('/')+"/contents/mod.json",file,1048576,8000);
  object content=Read(file);Need(S(content,"encoding")=="base64","Repository mod.json content unavailable");byte[] bytes=Convert.FromBase64String(S(content,"content"));Need(bytes.Length<=65536,"Repository manifest size limit");
  object m;lock(Json)m=Json.DeserializeObject(Encoding.UTF8.GetString(bytes));
  Metadata(m);
  return m;
 }
 static object Browse(object args,string work){
  bool offline=Convert.ToBoolean(G(args,"offline",false)),force=Convert.ToBoolean(G(args,"force",false));
  string url=S(args,"index_url");Https(url);string cache=Path.Combine(Data,"catalogue");Directory.CreateDirectory(cache);string cachedIndex=Path.Combine(cache,TextHash(url)+".index.json");object index;bool stale=false,cachedIndexUsed=false;
  try{if(offline)throw new Exception("Offline mode");if(!force&&File.Exists(cachedIndex)&&DateTime.UtcNow-File.GetLastWriteTimeUtc(cachedIndex)<TimeSpan.FromMinutes(10)){index=Read(cachedIndex);Index(index);cachedIndexUsed=true;}else{string file=Path.Combine(work,"index.json");Fetch(url,file,262144,8000);index=Read(file);Index(index);Write(cachedIndex,index);}}catch{if(!File.Exists(cachedIndex))throw;index=Read(cachedIndex);Index(index);stale=true;cachedIndexUsed=true;}
  var entries=new List<object>();var sync=new object();using(var cancel=new CancellationTokenSource()){
   cancel.CancelAfter(45000);try{Parallel.ForEach(A(G(index,"mods")),new ParallelOptions{MaxDegreeOfParallelism=4,CancellationToken=cancel.Token},entry=>{
    string repository=S(entry,"url"),cached=Path.Combine(cache,TextHash(repository)+".mod.json");object metadata=null;string error="";bool cachedResult=false;
    try{if(offline&&!File.Exists(cached))throw new Exception("Repository metadata unavailable offline");if(File.Exists(cached)&&(offline||(!force&&DateTime.UtcNow-File.GetLastWriteTimeUtc(cached)<TimeSpan.FromHours(1)))){metadata=Read(cached);cachedResult=true;}else{string dir=Child(work,TextHash(repository));Directory.CreateDirectory(dir);metadata=RepoMetadata(repository,dir);Write(cached,metadata);}}
    catch(Exception e){error=e.Message;if(File.Exists(cached)){try{metadata=Read(cached);cachedResult=true;}catch{}}}
    lock(sync)entries.Add(Obj("name",S(entry,"name"),"repository",repository,"manifest",metadata,"cached",cachedResult,"error",error,"status",metadata==null?"unavailable":"available"));
   });}catch(OperationCanceledException){}}
  return Obj("status","complete","entries",entries.OrderBy(e=>S(e,"name")).ToArray(),"cached_index",cachedIndexUsed,"message",stale?"Using cached index; unavailable repositories do not block other mods.":"Repository metadata loaded. The selected release manifest is authoritative when reviewing an install.");
 }
 static bool GIsArray(object x){return x is object[]||x is ArrayList;}
 static string Compatibility(object m,object request){
  if(!Standalone(m)&&!VersionOK("1.0.0",S(m,"api")))return "requires-framework-work";
  object raw=G(m,"raw_integration");
  if(raw!=null){
   Need(S(raw,"reason").Length>0,"Raw integration exception requires a reason");
   string exe=GameExe();if(!File.Exists(exe))return "raw-build-unknown";
   if(!A(G(raw,"game_builds")).Select(Convert.ToString).Contains(Hash(exe)))return "raw-build-mismatch";
  }
  // Installation metadata is checked here. Live game capabilities and exact
  // native adapter gating remain the selected mod runtime's responsibility.
  return Standalone(m)?"standalone-ready":"framework-ready";
 }

 static bool InstallCompatible(object m,object request){string status=Compatibility(m,request);return status=="framework-ready"||status=="standalone-ready";}
 static string StageArchive(string archive,object m,string work){
  Manifest(m);string root=Path.Combine(work,"payload");Directory.CreateDirectory(root);var expected=A(G(m,"files")).ToDictionary(f=>S(f,"path"),StringComparer.OrdinalIgnoreCase);var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);long total=0;
  using(var z=ZipFile.OpenRead(archive)){
   Need(z.Entries.Count<=4097,"Archive entry limit");foreach(var e in z.Entries){
    if(e.FullName=="bmf-manifest.json"||e.FullName=="mod.json")continue;string dest=Child(root,e.FullName);Need(seen.Add(e.FullName),"Duplicate archive path");int type=(e.ExternalAttributes>>16)&61440;Need(type!=40960&&(e.ExternalAttributes&1024)==0,"Link entry rejected");
    Need(expected.ContainsKey(e.FullName),"Unlisted archive file");var f=expected[e.FullName];long size=Convert.ToInt64(G(f,"size"));Need(e.Length==size,"File size mismatch");total+=size;Need(total<=268435456,"Extraction limit");Directory.CreateDirectory(Path.GetDirectoryName(dest));
    using(var input=e.Open())using(var output=File.Create(dest)){byte[] buf=new byte[65536];int count;long n=0;while((count=input.Read(buf,0,buf.Length))>0){n+=count;Need(n<=size,"Expanded size exceeded");output.Write(buf,0,count);}}
    Need(Hash(dest)==S(f,"sha256").ToLowerInvariant(),"Hash mismatch");
   }
  }Need(seen.Count==expected.Count,"Missing archive file");return root;
 }
 static string GameExe(){return Path.Combine(Directory.GetParent(Directory.GetParent(ModsRoot).FullName).FullName,"Bladesong-Win64-Shipping.exe");}
 static IEnumerable<string> Records(){
  foreach(string directory in Directory.GetDirectories(ModsRoot)){
   string id=Path.GetFileName(directory);if(!Regex.IsMatch(id,@"^[A-Za-z0-9_-]{1,64}$")||id=="shared")continue;
   string record=new[]{"mod.json","bmf-manifest.json","bmf-installed.json"}.Select(n=>Child(directory,n)).FirstOrDefault(File.Exists);
   if(record==null)continue;try{object metadata=Read(record);Metadata(metadata);if(S(metadata,"id")!=id)continue;}catch{continue;}yield return record;
  }
 }
 static void Dependencies(object manifest){
  if(G(manifest,"dependencies")==null)return;
  foreach(var dependency in D(G(manifest,"dependencies"))){
   Need(Regex.IsMatch(dependency.Key,@"^[A-Za-z0-9_-]{1,64}$"),"Invalid dependency ID");
   string directory=Child(ModsRoot,dependency.Key),path=null;
   foreach(string name in new[]{"mod.json","bmf-manifest.json","bmf-installed.json"}){string candidate=Child(directory,name);if(File.Exists(candidate)){path=candidate;break;}}
   Need(path!=null,"Missing dependency "+dependency.Key);object installed=Read(path);Metadata(installed);
   Need(S(installed,"id")==dependency.Key&&VersionOK(S(installed,"version"),Convert.ToString(dependency.Value)),"Incompatible dependency "+dependency.Key);
   Need(Enabled(dependency.Key),"Disabled dependency "+dependency.Key);
  }
 }
 static void CheckTargets(object manifest){
  Ownable(S(manifest,"id"));
  string record=Child(ModsRoot,S(manifest,"id")+"/bmf-installed.json");object previous=File.Exists(record)?Read(record):null;
  foreach(var file in A(G(manifest,"files"))){
   string destination=Target(manifest,S(file,"path"));if(!File.Exists(destination))continue;
   Need(previous!=null,"Unmanaged installation exists; manual migration required");
   var owned=A(G(previous,"files")).FirstOrDefault(x=>S(x,"path")==S(file,"path"));
   Need(owned!=null&&Hash(destination)==S(owned,"sha256").ToLowerInvariant(),"Local edits preserved; refusing overwrite");
  }
 }
 static Dictionary<string,object> PendingPlan(string work){
  string path=Path.Combine(Data,"pending.json");Dictionary<string,object> plan=null;
  if(File.Exists(path)){object previous=Read(path);if(Convert.ToBoolean(G(previous,"approved",false)))plan=D(previous);}
  if(plan==null)plan=Obj("schema_version",1,"approved",true,"items",new object[0]);
  if(S(plan,"id")=="")plan["id"]=Guid.NewGuid().ToString("N").Substring(0,12);
  Need(Regex.IsMatch(S(plan,"id"),@"^[A-Za-z0-9_-]{1,80}$"),"Invalid pending transaction ID");
  if(G(plan,"relaunch")==null)plan["relaunch"]=true;
  return plan;
 }
 static bool GameRunning(string exe){
  return Process.GetProcessesByName("Bladesong-Win64-Shipping").Any(p=>{try{return String.Equals(p.MainModule.FileName,exe,StringComparison.OrdinalIgnoreCase);}catch{return true;}finally{p.Dispose();}});
 }
 static string RemovalTarget(string id){
  Need(Regex.IsMatch(id,@"^[A-Za-z0-9_-]{1,64}$"),"Invalid mod ID");
  string root=Child(ModsRoot,id);Need(Directory.Exists(root),"Mod directory is unavailable");Ownable(id);
  foreach(string path in Records()){object mod=Read(path);if(S(mod,"id")!=id&&Enabled(S(mod,"id"))&&G(mod,"dependencies")!=null&&D(G(mod,"dependencies")).Keys.Any(k=>String.Equals(k,id,StringComparison.OrdinalIgnoreCase)))throw new Exception("Enabled mod depends on this mod: "+S(mod,"id"));}
  var pending=new Stack<string>();pending.Push(root);int count=0;
  while(pending.Count>0){string directory=pending.Pop();foreach(string entry in Directory.EnumerateFileSystemEntries(directory)){
   Need(++count<=50000,"Mod archive entry limit");FileAttributes flags=File.GetAttributes(entry);Need((flags&FileAttributes.ReparsePoint)==0,"Mod link/junction cannot be archived");if((flags&FileAttributes.Directory)!=0)pending.Push(entry);
  }}return root;
 }
 static string UninstallArchive(object removal){
  string token=S(removal,"archive");Need(Regex.IsMatch(token,@"^[a-f0-9]{12}$"),"Invalid uninstall archive token");
  string root=Path.Combine(Path.GetDirectoryName(GameExe()),"BMF_Uninstalled");Directory.CreateDirectory(root);
  Need((File.GetAttributes(root)&FileAttributes.ReparsePoint)==0,"Uninstall backup link rejected");return Child(root,token);
 }
 static void PrepareUninstall(object args,string work){
  string id=S(args,"id");RemovalTarget(id);var plan=PendingPlan(work);string mods=Path.Combine(ModsRoot,"mods.txt");
  var items=A(G(plan,"items")).Where(x=>S(Read(S(x,"manifest")),"id")!=id).ToList();
  foreach(var item in items){object mod=Read(S(item,"manifest"));Need(G(mod,"dependencies")==null||!D(G(mod,"dependencies")).Keys.Any(k=>String.Equals(k,id,StringComparison.OrdinalIgnoreCase)),"A pending install depends on this mod");}
  plan["items"]=items;plan["toggles"]=A(G(plan,"toggles")).Where(x=>S(x,"id")!=id).ToArray();
  var removals=A(G(plan,"removals")).Where(x=>S(x,"id")!=id).ToList();var removal=Obj("id",id,"archive",Guid.NewGuid().ToString("N").Substring(0,12),"mods_hash",File.Exists(mods)?Hash(mods):"");UninstallArchive(removal);removals.Add(removal);plan["removals"]=removals;
  Write(Path.Combine(Data,"pending.json"),plan);
 }
 static object Restart(){
  string pending=Path.Combine(Data,"pending.json");Need(File.Exists(pending)&&Convert.ToBoolean(G(Read(pending),"approved",false)),"No approved pending changes");
  object plan=PendingPlan(Data);Write(pending,plan);
  foreach(var item in A(G(plan,"items"))){object manifest=Read(S(item,"manifest"));Manifest(manifest);CheckTargets(manifest);
   foreach(var file in A(G(manifest,"files")))Need(Hash(Child(S(item,"payload"),S(file,"path")))==S(file,"sha256").ToLowerInvariant(),"Staged file changed");
  }
  foreach(var removal in A(G(plan,"removals"))){RemovalTarget(S(removal,"id"));string mods=Path.Combine(ModsRoot,"mods.txt");Need((File.Exists(mods)?Hash(mods):"")==S(removal,"mods_hash"),"Load order changed since uninstall request");}
  foreach(var toggle in A(G(plan,"toggles"))){string mods=Path.Combine(ModsRoot,"mods.txt");Need((File.Exists(mods)?Hash(mods):"")==S(toggle,"mods_hash"),"Load order changed since approval");}
  string copy=Path.Combine(Data,"apply-"+Guid.NewGuid().ToString("N")+".exe");File.Copy(Process.GetCurrentProcess().MainModule.FileName,copy,false);
  string job=Path.Combine(Data,"apply-job-"+Guid.NewGuid().ToString("N")+".json");Write(job,Obj("id","apply_"+Guid.NewGuid().ToString("N"),"operation","apply","args",Obj("plan",pending),"manager_root",ModRoot));
  Process.Start(new ProcessStartInfo(copy,"\""+job+"\""){UseShellExecute=false,CreateNoWindow=true});return Obj("status","waiting_for_exit","message","Installation checked. Restarting Bladesong...");
 }
 static void Stage(Source s,object args,object request,string work){
  object m=s.Manifest;Need(S(m,"id")==S(args,"expected_id")&&S(m,"version")==S(args,"expected_version"),"Source changed since review");
  if(S(args,"expected_manifest_sha256")!="")Need(S(args,"expected_manifest_sha256")==s.Digest,"Manifest changed since review");string compatible=Compatibility(m,request);Need(compatible=="framework-ready"||compatible=="standalone-ready","Required API/capability or explicit raw integration support is unavailable: "+compatible);
  Dependencies(m);CheckTargets(m);
  if(s.Archive==null){s.Archive=Path.Combine(work,"archive.zip");Fetch(S(G(m,"download"),"url"),s.Archive);Need(Hash(s.Archive)==S(G(m,"download"),"sha256").ToLowerInvariant(),"Archive hash mismatch");}
  string payload=StageArchive(s.Archive,m,work),manifest=Path.Combine(work,"manifest.json");Write(manifest,m);string pending=Path.Combine(Data,"pending.json");
  var plan=PendingPlan(work);
  var items=A(G(plan,"items")).Where(x=>S(Read(S(x,"manifest")),"id")!=S(m,"id")).ToList();items.Add(Obj("manifest",manifest,"payload",payload));plan["items"]=items;plan["approved"]=true;Write(pending,plan);
 }
 static string Target(object m,string rel){
  string id=S(m,"id");if(id=="BladesongModFramework"&&rel.StartsWith("shared/"))return Child(Path.Combine(ModsRoot,"shared/BladesongFramework"),rel.Substring(7));
  if(rel.StartsWith("assets/logicmods/")){
   string name=rel.Substring(17);Need(Regex.IsMatch(name,@"^[A-Za-z0-9_.-]+\.(pak|ucas|utoc)$"),"Unsupported LogicMods asset");
   string inner=Directory.GetParent(Directory.GetParent(Path.GetDirectoryName(GameExe())).FullName).FullName;
   return Child(Path.Combine(inner,"Content/Paks/LogicMods"),name);
  }
  return Child(Child(ModsRoot,id),rel);
 }
 static bool Enabled(string id){
  string txt=Path.Combine(ModsRoot,"mods.txt");if(File.Exists(txt)){var m=Regex.Match(File.ReadAllText(txt),@"(?m)^\s*"+Regex.Escape(id)+@"\s*:\s*([01])\s*$");if(m.Success)return m.Groups[1].Value=="1";}
  return File.Exists(Child(ModsRoot,id+"/enabled.txt"));
 }
 static void Toggle(object args,string work){
  string id=S(args,"id");Need(Regex.IsMatch(id,@"^[A-Za-z0-9_-]{1,64}$")&&Directory.Exists(Child(ModsRoot,id)),"Unknown mod directory");
  bool enabled=Convert.ToBoolean(G(args,"enabled",!Enabled(id)));Ownable(id);
  if(!enabled)foreach(string record in Records()){var m=Read(record);if(Enabled(S(m,"id"))&&G(m,"dependencies")!=null&&D(G(m,"dependencies")).Keys.Any(k=>String.Equals(k,id,StringComparison.OrdinalIgnoreCase)))throw new Exception("Enabled dependency requires this mod: "+S(m,"id"));}
  string pending=Path.Combine(Data,"pending.json"),mods=Path.Combine(ModsRoot,"mods.txt");var plan=PendingPlan(work);
  var toggles=A(G(plan,"toggles")).Where(x=>S(x,"id")!=id).ToList();toggles.Add(Obj("id",id,"enabled",enabled,"mods_hash",File.Exists(mods)?Hash(mods):"","marker",File.Exists(Child(ModsRoot,id+"/enabled.txt"))));plan["toggles"]=toggles;plan["approved"]=true;Write(pending,plan);
 }
 static void Apply(string path){
  var plan=Read(path);Need(Convert.ToInt32(G(plan,"schema_version"))==1&&Convert.ToBoolean(G(plan,"approved",false)),"Unapproved plan");string exe=GameExe();
  while(GameRunning(exe))Thread.Sleep(1000);
  string transaction=Child(Path.Combine(Data,"rollback"),S(plan,"id"));Directory.CreateDirectory(transaction);var changes=new List<object>();
  using(var mutex=new Mutex(false,"Local\\BMFInstall_"+Hash(path).Substring(0,16))){Need(mutex.WaitOne(0),"Another transaction is active");try{
   // Prepare every backup before the first write, including installation records.
   foreach(var item in A(G(plan,"items"))){object m=Read(S(item,"manifest"));Manifest(m);Ownable(S(m,"id"));string install=Child(ModsRoot,S(m,"id"));string record=Path.Combine(install,"bmf-installed.json");object old=File.Exists(record)?Read(record):null;
    foreach(var f in A(G(m,"files"))){string source=Child(S(item,"payload"),S(f,"path")),dest=Target(m,S(f,"path"));Need(Hash(source)==S(f,"sha256").ToLowerInvariant(),"Staged file changed");string backup=null;
     if(File.Exists(dest)){Need(old!=null,"Unmanaged installation exists; manual migration required");var owned=A(G(old,"files")).FirstOrDefault(x=>S(x,"path")==S(f,"path"));Need(owned!=null&&Hash(dest)==S(owned,"sha256").ToLowerInvariant(),"Local edits preserved; refusing overwrite");backup=Child(transaction,"file_"+changes.Count+".bak");Directory.CreateDirectory(Path.GetDirectoryName(backup));File.Copy(dest,backup,false);Need(Hash(dest)==Hash(backup),"Backup mismatch");}
     changes.Add(Obj("destination",dest,"backup",backup,"source",source,"sha256",S(f,"sha256").ToLowerInvariant()));
    }
    string recordSource=Path.Combine(transaction,"record_"+changes.Count+".json");Write(recordSource,m);string recordBackup=null;if(File.Exists(record)){recordBackup=recordSource+".bak";File.Copy(record,recordBackup,false);}changes.Add(Obj("destination",record,"backup",recordBackup,"source",recordSource,"sha256",Hash(recordSource)));
    string deployment=Child(install,"deployment.json"),deploymentNew=Path.Combine(transaction,"owner_"+changes.Count+".json"),deploymentBackup=null;
    Write(deploymentNew,Obj("schema_version",1,"owner",OwnerID,"mod_id",S(m,"id")));
    if(File.Exists(deployment)){deploymentBackup=deploymentNew+".bak";File.Copy(deployment,deploymentBackup,false);}
    changes.Add(Obj("destination",deployment,"backup",deploymentBackup,"source",deploymentNew,"sha256",Hash(deploymentNew)));

   }
   var removals=A(G(plan,"removals")).ToList();
   foreach(var removal in removals){string id=S(removal,"id"),source=RemovalTarget(id),archive=UninstallArchive(removal);Need(!Directory.Exists(archive),"Uninstall archive already exists");changes.Add(Obj("destination",archive,"move_directory",source));}
   var toggles=A(G(plan,"toggles")).ToList();
   if(toggles.Count>0||removals.Count>0){
    string mods=Path.Combine(ModsRoot,"mods.txt"),originalText=File.Exists(mods)?File.ReadAllText(mods):"";string edited=originalText;
    foreach(var removal in removals){
     Need((File.Exists(mods)?Hash(mods):"")==S(removal,"mods_hash"),"Load order changed since uninstall request");
     edited=Regex.Replace(edited,@"(?m)^\s*"+Regex.Escape(S(removal,"id"))+@"\s*:\s*[01]\s*$","");
    }
    foreach(var toggle in toggles){
     string id=S(toggle,"id");Need(Regex.IsMatch(id,@"^[A-Za-z0-9_-]{1,64}$"),"Invalid toggle target");Need((File.Exists(mods)?Hash(mods):"")==S(toggle,"mods_hash"),"Load order changed since approval");
     string line=id+" : "+(Convert.ToBoolean(G(toggle,"enabled"))?"1":"0");string pattern=@"(?m)^\s*"+Regex.Escape(id)+@"\s*:\s*[01]\s*$";
     edited=Regex.IsMatch(edited,pattern)?Regex.Replace(edited,pattern,line):edited+"\r\n"+line+"\r\n";
     string marker=Child(ModsRoot,id+"/enabled.txt");Need(File.Exists(marker)==Convert.ToBoolean(G(toggle,"marker")),"Enable marker changed");
     if(File.Exists(marker)&&!Convert.ToBoolean(G(toggle,"enabled"))){string backup=Path.Combine(transaction,id+".enabled.bak");File.Copy(marker,backup,false);changes.Add(Obj("destination",marker,"backup",backup,"delete",true));}
    }
    string source=Path.Combine(transaction,"mods.new.txt");File.WriteAllText(source,edited,new UTF8Encoding(false));string old=null;if(File.Exists(mods)){old=Path.Combine(transaction,"mods.bak.txt");File.Copy(mods,old,false);}changes.Add(Obj("destination",mods,"backup",old,"source",source,"sha256",Hash(source)));
   }
   Write(Path.Combine(transaction,"journal.json"),Obj("status","prepared","changes",changes));var done=new List<object>();
   try{foreach(var c in changes){Directory.CreateDirectory(Path.GetDirectoryName(S(c,"destination")));done.Add(c);Write(Path.Combine(transaction,"journal.json"),Obj("status","applying","changes",done));if(G(c,"move_directory")!=null)Directory.Move(S(c,"move_directory"),S(c,"destination"));else if(Convert.ToBoolean(G(c,"delete",false)))File.Delete(S(c,"destination"));else{File.Copy(S(c,"source"),S(c,"destination"),true);Need(Hash(S(c,"destination"))==S(c,"sha256"),"Installed hash mismatch");}}}
   catch{for(int i=done.Count-1;i>=0;i--){var c=done[i];if(G(c,"move_directory")!=null){if(Directory.Exists(S(c,"destination")))Directory.Move(S(c,"destination"),S(c,"move_directory"));}else if(G(c,"backup")!=null)File.Copy(S(c,"backup"),S(c,"destination"),true);else if(File.Exists(S(c,"destination")))File.Delete(S(c,"destination"));}Write(Path.Combine(transaction,"journal.json"),Obj("status","rolled_back","changes",done));throw;}
   Write(Path.Combine(transaction,"journal.json"),Obj("status","committed","changes",changes));Write(Path.Combine(Data,"pending.json"),Obj("schema_version",1,"approved",false,"items",new object[0]));
  }finally{mutex.ReleaseMutex();}}

 }
 static object Updates(object request,string work){
  var updates=new List<object>();var checks=Obj();var records=Records().ToArray();var sync=new object();
  foreach(string path in records){object metadata=Read(path);checks[S(metadata,"id")]=Obj("state","checking");}
  Action publish=()=>{try{Write(JobPath+".progress.json",Obj("checks",checks,"updates",updates.ToArray()));}catch(IOException){}catch(UnauthorizedAccessException){}};publish();
  Parallel.ForEach(records,new ParallelOptions{MaxDegreeOfParallelism=4},path=>{
   object old=Read(path);string id=S(old,"id");object check;
   try{
    if(S(old,"repository")=="")check=Obj("state","unavailable","message","No update source");
    else if(S(old,"pinned_version")!="")check=Obj("state","pinned","message","Version pinned");
    else{
     string directory=Child(work,id);Directory.CreateDirectory(directory);Source source=UpdateSource(old,directory);
     Need(S(source.Manifest,"id")==id,"Update release identity mismatch");
     if(Version.Parse(S(source.Manifest,"version").Split('-')[0])>Version.Parse(S(old,"version").Split('-')[0])){
      var metadata=D(source.Manifest);metadata["source"]=source.Url;metadata["manifest_sha256"]=source.Digest;metadata["compatibility"]=Compatibility(metadata,request);
      lock(sync)updates.Add(metadata);check=Obj("state","update","version",S(metadata,"version"));
     }else check=Obj("state","current");
    }
   }catch(Exception error){check=Obj("state","failed","message",error.Message);}
   lock(sync){checks[id]=check;publish();}
  });
  return Obj("status","complete","checks",checks,"updates",updates.ToArray(),"message","Update check complete.");
 }
 static object Run(object request,string work){
  object args=G(request,"args",Obj());switch(S(request,"operation")){
   case "browse":return Browse(args,work);
   case "select-component-release-local":return Obj("status","complete","url",SelectComponentRelease(Read(S(args,"manifest")),Read(S(args,"releases"))));
   case "validate-dependencies-local":Dependencies(Read(S(args,"path")));return Obj("status","complete");
   case "validate-index-local":Index(Read(S(args,"path")));return Obj("status","complete");
   case "compatibility-local":return Obj("status","complete","compatibility",Compatibility(Read(S(args,"path")),request));
   case "discover":{
    var mods=new List<object>();foreach(string directory in Directory.GetDirectories(ModsRoot)){
     string id=Path.GetFileName(directory);if(!Regex.IsMatch(id,@"^[A-Za-z0-9_-]{1,64}$")||id=="shared")continue;
     string record=Path.Combine(directory,"bmf-installed.json"),manifest=Path.Combine(directory,"mod.json");if(!File.Exists(manifest))manifest=Path.Combine(directory,"bmf-manifest.json");object m=null;try{m=File.Exists(record)?Read(record):File.Exists(manifest)?Read(manifest):null;if(m!=null){Metadata(m);Need(S(m,"id")==id,"Installed mod ID mismatch");D(m)["integration"]="manifest";}}catch(Exception e){m=Obj("id",id,"name",id,"version","0.0.0","api","^1.0.0","integration","invalid-manifest","description","Invalid manifest: "+e.Message);}
     if(m==null&&File.Exists(Path.Combine(directory,"Scripts/main.lua")))m=Obj("id",id,"name",id,"version","0.0.0","api","^1.0.0","description","Unmanaged UE4SS mod; version and compatibility unknown");
     if(m!=null){if(G(m,"integration")==null)D(m)["integration"]="ordinary";D(m)["install_owner"]=Ownership(id);D(m)["enabled"]=Enabled(id);D(m)["discovered"]=true;mods.Add(m);}
    }return Obj("status","complete","mods",mods,"identity",File.Exists(GameExe())?Obj("game",FileVersionInfo.GetVersionInfo(GameExe()).FileVersion):null,"last_apply",File.Exists(Path.Combine(Data,"last-apply.json"))?Read(Path.Combine(Data,"last-apply.json")):null);
   }
   case "inspect":{Source s=Resolve(S(args,"url"),work);var m=D(s.Manifest);m["source"]=s.Url;m["manifest_sha256"]=s.Digest;m["compatibility"]=Compatibility(m,request);return Obj("status","complete","mod",m);}
   case "uninstall":PrepareUninstall(args,work);return Restart();
   case "plan-install":return Plan(Resolve(S(args,"url"),work),request,work);
   case "install":return ExecutePlan(args,request,work);
   case "inspect-adoption":return Adoption(args,false);
   case "adopt":return Adoption(args,true);
   case "plan-local":{
    object root=Read(S(args,"path"));Manifest(root);var fixtures=new Dictionary<string,System.Collections.Generic.List<object>>();
    foreach(var entry in D(G(args,"sources",Obj())))fixtures[entry.Key]=A(entry.Value).Select(x=>Read(Convert.ToString(x))).ToList();
    return Plan(new Source{Manifest=root,Url="fixture",Digest=Hash(S(args,"path"))},request,work,fixtures);
   }
   case "stage":{Source s=Resolve(S(args,"source"),work);Stage(s,args,request,work);return Obj("status","complete","message","Validated and staged. Restart & Apply to install.");}
   case "updates":return Updates(request,work);
   case "settings":Write(Path.Combine(Data,"settings.json"),G(args,"settings",Obj()));return Obj("status","complete","message","Settings saved");
   case "toggle":Toggle(args,work);return Obj("status","complete","message","Enable/disable queued for next launch; loaded code remains active until exit.");
   case "restart":return Restart();
   case "apply":{
    string path=S(args,"plan");object plan=Read(path);Need(Convert.ToBoolean(G(plan,"approved",false)),"Unapproved plan");
    object result;
    try{Apply(path);result=Obj("status","complete","message","Approved changes applied");}
    catch(Exception error){result=Obj("status","failed","error",error.Message);}
    Write(Path.Combine(Data,"last-apply.json"),result);
    if(Convert.ToBoolean(G(plan,"relaunch",false))){string exe=GameExe();if(File.Exists(exe)&&!GameRunning(exe))Process.Start(new ProcessStartInfo(exe){WorkingDirectory=Path.GetDirectoryName(exe)});}
    return result;
   }
   case "validate-local":return Obj("status","complete","payload",StageArchive(S(args,"archive"),Read(S(args,"manifest")),work));
   default:throw new Exception("Unsupported operation");
  }
 }
 [STAThread]static int Main(string[] args){
  if(args.Length!=1)return 2;JobPath=Path.GetFullPath(args[0]);object request;
  try{
   request=Read(JobPath);string root=S(request,"manager_root");ModRoot=root!=""?Path.GetFullPath(root):Directory.GetParent(Path.GetDirectoryName(Process.GetCurrentProcess().MainModule.FileName)).FullName;
   Need(Path.GetFileName(ModRoot)=="BladesongModManager","Invalid manager root");ModsRoot=Directory.GetParent(ModRoot).FullName;Data=Path.Combine(ModRoot,"Data");Directory.CreateDirectory(Data);
   string id=S(request,"id");Need(Regex.IsMatch(id,@"^[A-Za-z0-9_-]{1,80}$"),"Invalid job id");string work=Child(Path.Combine(Data,"jobs"),id);Directory.CreateDirectory(work);
   Write(JobPath+".result.json",Run(request,work));return 0;
  }catch(Exception e){try{Write(JobPath+".result.json",Obj("status","failed","error",e.Message));}catch{}return 1;}
 }
}
