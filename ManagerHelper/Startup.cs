// Startup self-update has no UObject, game UI, framework or process-termination dependency.
using System;using System.IO;using System.Linq;using System.Diagnostics;
partial class Worker {
 static bool UserChangesPending(){
  string path=Path.Combine(Data,"pending.json");if(!File.Exists(path))return false;object plan=Read(path);
  return Convert.ToBoolean(G(plan,"approved",false))&&(A(G(plan,"items")).Any()||A(G(plan,"removals")).Any()||A(G(plan,"toggles")).Any());
 }
 static bool StartupUpdatesEnabled(){
  string config=Path.Combine(Data,"settings.json");if(!File.Exists(config))return true;
  object settings=Read(config),prefs=G(settings,"preferences",G(settings,"BladesongModManager",Obj()));
  return !(G(prefs,"auto_update_manager")is bool)||Convert.ToBoolean(G(prefs,"auto_update_manager"));
 }
 static object StartupUpdate(object request,string work,Source fixture=null,bool watch=true){
  const string id="BladesongModManager";
  if(!StartupUpdatesEnabled())return Obj("status","complete","state","disabled");
  if(UserChangesPending())return Obj("status","complete","state","deferred","message","Pending user changes take priority");
  string owner=Ownership(id);if(owner!=OwnerID)return Obj("status","complete","state","manual","message","Automatic updates require an in-game managed installation");
  string currentPath=Child(ModRoot,"bmf-installed.json");Need(File.Exists(currentPath),"Manager file receipt is missing");object current=Read(currentPath);Metadata(current);Need(S(current,"id")==id,"Manager receipt identity mismatch");
  Source source=fixture;
  if(source==null){
   object official=Obj("release_source",Obj("repository","https://github.com/LTR-JT/BladesongModManager","tag_prefix","v"));
   try{source=UpdateSource(official,work);}catch(NoPublishedReleaseException){return Obj("status","complete","state","unpublished");}
  }
  object m=source.Manifest;Manifest(m);Need(S(m,"id")==id&&Standalone(m)&&!A(G(m,"dependencies")).Any(),"Startup updater accepts only the standalone Mod Manager");
  foreach(object file in A(G(m,"files")))Need(!S(file,"path").StartsWith("shared/")&&!S(file,"path").StartsWith("assets/"),"Startup updater cannot install shared or game assets");
  if(Version.Parse(S(m,"version").Split('-')[0])<=Version.Parse(S(current,"version").Split('-')[0]))return Obj("status","complete","state","current");
  Ownable(id);CheckTargets(m);
  if(source.Archive==null){source.Archive=Path.Combine(work,"startup-package.zip");Fetch(S(G(m,"download"),"url"),source.Archive);Need(Hash(source.Archive)==S(G(m,"download"),"sha256").ToLowerInvariant(),"Startup archive hash mismatch");}
  string payload=StageArchive(source.Archive,m,work),manifest=Path.Combine(work,"startup-manifest.json"),path=Path.Combine(work,"startup-plan.json");Write(manifest,m);
  Write(path,Obj("schema_version",1,"approved",true,"startup_auto",true,"relaunch",false,"id","startup_"+Guid.NewGuid().ToString("N").Substring(0,12),"items",new[]{Obj("manifest",manifest,"payload",payload)},"installed_snapshot",TextHash(Json.Serialize(current))));
  if(watch){
   // Run the transaction from a copy so the manager helper itself can be replaced after normal game exit.
   string copy=Path.Combine(Data,"startup-apply-"+Guid.NewGuid().ToString("N")+".exe");File.Copy(Process.GetCurrentProcess().MainModule.FileName,copy,false);
   string job=Path.Combine(work,"startup-apply-job.json");Write(job,Obj("id","startup_apply_"+Guid.NewGuid().ToString("N"),"operation","apply","manager_root",ModRoot,"args",Obj("plan",path)));
   Process.Start(new ProcessStartInfo(copy,"\""+job+"\""){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden});
  }
  return Obj("status","complete","state","ready","version",S(m,"version"),"plan",path,"message","Update downloaded; it will apply after Bladesong closes normally.");
 }
}
