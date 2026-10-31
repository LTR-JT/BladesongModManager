// Manager-only dependency solver. Runtime APIs and packages never import it.
using System;using System.IO;using System.Linq;using System.Collections.Generic;using System.Text.RegularExpressions;
partial class Worker {
 const string OwnerID="bladesong-in-game";
 static string Ownership(string id){string p=Child(ModsRoot,id+"/deployment.json");return File.Exists(p)?S(Read(p),"owner"):"manual";}
 static void Ownable(string id){string root=Child(ModsRoot,id);if(Directory.Exists(root)&&Directory.EnumerateFileSystemEntries(root).Any())Need(Ownership(id)==OwnerID,"Installation owned by "+Ownership(id)+"; explicit adoption or controlled redeployment is required: "+id);}
 static object Adoption(object args,bool apply){
  string id=S(args,"id");Need(Regex.IsMatch(id,@"^[A-Za-z0-9_-]{1,64}$"),"Invalid mod ID");string folder=Child(ModsRoot,id);
  Need(Ownership(id)=="manual","External deployment must be removed through its original manager before redeployment");
  string record=Child(folder,"bmf-installed.json");Need(File.Exists(record),"Adoption needs a portable file receipt; redeploy unmanaged mods manually");object m=Read(record);Manifest(m);Need(S(m,"id")==id,"Receipt identity mismatch");
  var files=new List<object>();foreach(var file in A(G(m,"files"))){string target=Target(m,S(file,"path"));Need(File.Exists(target)&&Hash(target)==S(file,"sha256").ToLowerInvariant(),"Local changes prevent adoption");files.Add(Obj("path",S(file,"path"),"sha256",Hash(target)));}
  string fingerprint=TextHash(Json.Serialize(files));if(apply){Need(S(args,"fingerprint")==fingerprint,"Installation changed since review");Write(Child(folder,"deployment.json"),Obj("schema_version",1,"owner",OwnerID,"adopted",true,"files_fingerprint",fingerprint));}
  return Obj("status","complete","id",id,"fingerprint",fingerprint,"message",apply?"Installation adopted; files and configuration unchanged":"Verified manual installation. Confirm adoption to allow this manager to maintain it.");
 }
 class Choice {public object Manifest;public Source Source;public bool Installed;}
 static Dictionary<string,string> SourcesFor(IEnumerable<Choice> chosen){
  var sources=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase){{"BladesongModFramework","https://github.com/LTR-JT/BladesongModFramework"}};
  foreach(var c in chosen)if(G(c.Manifest,"dependency_sources")!=null)foreach(var source in D(G(c.Manifest,"dependency_sources"))){string url=Convert.ToString(source.Value);Https(url);if(sources.ContainsKey(source.Key)&&sources[source.Key]!=url&&source.Key!="BladesongModFramework")throw new Exception("Conflicting dependency sources: "+source.Key);sources[source.Key]=url;}
  return sources;
 }
 static IEnumerable<Choice> Candidates(string id,List<string> ranges,Dictionary<string,string> sources,Dictionary<string,object> installed,string work,Dictionary<string,List<object>> fixtures){
  object current;
  if(installed.TryGetValue(id,out current)&&ranges.All(x=>VersionOK(S(current,"version"),x)))yield return new Choice{Manifest=current,Installed=true};
  if(fixtures!=null){List<object> list;if(fixtures.TryGetValue(id,out list))foreach(object m in list)if(ranges.All(x=>VersionOK(S(m,"version"),x)))yield return new Choice{Manifest=m,Source=new Source{Manifest=m,Url="fixture",Digest=TextHash(Json.Serialize(m))}};yield break;}
  string source;if(!sources.TryGetValue(id,out source)){if(current!=null)source=S(current,"repository");Need(!String.IsNullOrEmpty(source),"No release source for dependency "+id+"; declare dependency_sources");}
  // Bounded GitHub release search supports older compatible releases, not only latest.
  var urls=new List<string>();var uri=Https(source);
  if(uri.Host=="github.com"&&Regex.IsMatch(uri.AbsolutePath,@"^/[\w.-]+/[\w.-]+/?$")){
   string listing=Path.Combine(work,"releases-"+id+".json");Fetch("https://api.github.com/repos"+uri.AbsolutePath.TrimEnd('/')+"/releases?per_page=20",listing,1048576);
   foreach(object release in A(Read(listing)).Where(x=>!Convert.ToBoolean(G(x,"draft",false))&&!Convert.ToBoolean(G(x,"prerelease",false)))){
    var asset=A(G(release,"assets")).FirstOrDefault(x=>S(x,"name")=="mod.json");if(asset!=null)urls.Add(S(asset,"browser_download_url"));
   }
  }else urls.Add(source);
  int n=0;foreach(string url in urls.Take(20)){
   string directory=Child(work,"candidate_"+id+"_"+(n++));Directory.CreateDirectory(directory);Source candidate=Resolve(url,directory);
   if(S(candidate.Manifest,"id")==id&&ranges.All(x=>VersionOK(S(candidate.Manifest,"version"),x)))yield return new Choice{Manifest=candidate.Manifest,Source=candidate};
  }
 }
 static Dictionary<string,Choice> Solve(Dictionary<string,Choice> selected,Dictionary<string,object> installed,HashSet<string> roots,string work,Dictionary<string,List<object>> fixtures,int depth){
  Need(depth<=64,"Dependency graph limit");var constraints=new Dictionary<string,List<string>>(StringComparer.OrdinalIgnoreCase);
  var all=installed.Where(x=>!selected.ContainsKey(x.Key)).Select(x=>x.Value).Concat(selected.Values.Select(x=>x.Manifest));
  foreach(object m in all)if(G(m,"dependencies")!=null)foreach(var dep in D(G(m,"dependencies"))){if(!constraints.ContainsKey(dep.Key))constraints[dep.Key]=new List<string>();constraints[dep.Key].Add(Convert.ToString(dep.Value));}
  foreach(var pair in selected){List<string> ranges;if(constraints.TryGetValue(pair.Key,out ranges)&&!ranges.All(x=>VersionOK(S(pair.Value.Manifest,"version"),x)))throw new Exception("Dependency version conflict: "+pair.Key+" "+String.Join(" & ",ranges));}
  string missing=constraints.Keys.FirstOrDefault(id=>!selected.ContainsKey(id));if(missing==null){ValidateGraph(selected);return selected;}
  var sources=SourcesFor(selected.Values.Concat(installed.Where(x=>!selected.ContainsKey(x.Key)).Select(x=>new Choice{Manifest=x.Value})));string last="No compatible release";
  foreach(Choice candidate in Candidates(missing,constraints[missing],sources,installed,work,fixtures)){
   var next=new Dictionary<string,Choice>(selected,StringComparer.OrdinalIgnoreCase);next[missing]=candidate;
   try{return Solve(next,installed,roots,work,fixtures,depth+1);}catch(Exception e){last=e.Message;}
  }
  throw new Exception("Cannot resolve "+missing+" ("+String.Join(" & ",constraints[missing])+"): "+last);
 }
 static List<string> ValidateGraph(Dictionary<string,Choice> selected){
  var order=new List<string>();var states=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);Action<string> visit=null;visit=id=>{int state;if(states.TryGetValue(id,out state)){Need(state!=1,"Circular dependency: "+id);return;}states[id]=1;
   object m=selected[id].Manifest;Need(Standalone(m)||VersionOK("1.0.0",S(m,"api")),"Unsupported historical framework API: "+id);
   if(G(m,"dependencies")!=null)foreach(var dep in D(G(m,"dependencies"))){Need(selected.ContainsKey(dep.Key),"Missing dependency "+dep.Key);visit(dep.Key);}
   states[id]=2;order.Add(id);
  };foreach(string id in selected.Keys)visit(id);return order;
 }
 static object Plan(Source root,object request,string work,Dictionary<string,List<object>> fixtures=null){
  string expected=S(G(request,"args",Obj()),"expected_id");Need(expected==""||S(root.Manifest,"id")==expected,"Release identity differs from selected mod");
  var installed=new Dictionary<string,object>(StringComparer.OrdinalIgnoreCase);foreach(string record in Records()){object m=Read(record);installed[S(m,"id")]=m;}
  var start=new Dictionary<string,Choice>(StringComparer.OrdinalIgnoreCase){{S(root.Manifest,"id"),new Choice{Manifest=root.Manifest,Source=root}}};
  var selected=Solve(start,installed,new HashSet<string>(start.Keys),work,fixtures,0);var items=new List<object>();
  foreach(string id in ValidateGraph(selected)){
   object declared=G(selected[id].Manifest,"runtime_components");if(declared!=null)foreach(var component in D(declared)){
    Need(component.Key=="UE4SS","Unknown runtime component: "+component.Key);string dll=Path.Combine(Directory.GetParent(ModsRoot).FullName,"UE4SS.dll");Need(File.Exists(dll),"UE4SS bootstrap missing; use the documented one-time installer");
    if(Convert.ToString(component.Value)!="*"){string version=System.Diagnostics.FileVersionInfo.GetVersionInfo(dll).FileVersion;Need(version!=null&&VersionOK(version,Convert.ToString(component.Value)),"UE4SS version is unknown or incompatible; repair bootstrap outside the game");}
   }
   Choice c=selected[id];bool exists=installed.ContainsKey(id);string action=c.Installed?(Enabled(id)?"keep":"enable"):(exists?"update":"install");
   if(action!="keep")Ownable(id);
   if(!c.Installed){Need(InstallCompatible(c.Manifest,request),"Required runtime capability unavailable: "+id);Manifest(c.Manifest);CheckTargets(c.Manifest);}
   string path=Path.Combine(work,"plan-"+id+".json");Write(path,c.Manifest);
   items.Add(Obj("id",id,"name",S(c.Manifest,"name"),"version",S(c.Manifest,"version"),"action",action,"source",c.Source==null?"":c.Source.Url,"manifest",path,"manifest_hash",Hash(path),"owner",exists?Ownership(id):OwnerID,"installed_snapshot",exists?TextHash(Json.Serialize(installed[id])):""));
  }
  string token=Guid.NewGuid().ToString("N").Substring(0,12);Write(Child(Path.Combine(Data,"plans"),token+".json"),Obj("schema_version",1,"items",items));
  return Obj("status","complete","plan",Obj("token",token,"items",items.Select(x=>Obj("id",S(x,"id"),"name",S(x,"name"),"version",S(x,"version"),"action",S(x,"action"))).ToArray()),"message","Review the dependencies before installing. Required runtime capabilities are checked after launch; UE4SS bootstrap is separate.");
 }
 static object ExecutePlan(object args,object request,string work){
  string token=S(args,"token");Need(Regex.IsMatch(token,@"^[a-f0-9]{12}$"),"Invalid plan token");object review=Read(Child(Path.Combine(Data,"plans"),token+".json"));var staged=new List<object>();var toggles=new List<object>();
  // Do not alter pending.json until every dependency archive has passed validation.
  var current=Records().Select(Read).ToDictionary(x=>S(x,"id"));
  foreach(object item in A(G(review,"items"))){
   string key=S(item,"id");Need((current.ContainsKey(key)?TextHash(Json.Serialize(current[key])):"")==S(item,"installed_snapshot"),"Installed dependencies changed after review");
  }
  foreach(object item in A(G(review,"items"))){
   string id=S(item,"id"),action=S(item,"action");Need(Hash(S(item,"manifest"))==S(item,"manifest_hash"),"Reviewed plan changed");object m=Read(S(item,"manifest"));Metadata(m);
   if(action=="keep"){Need(Enabled(id),"Kept dependency became disabled");continue;}Ownable(id);
   if(action!="enable"){
    Need(InstallCompatible(m,request),"Runtime capability changed");CheckTargets(m);string directory=Child(work,id);Directory.CreateDirectory(directory);
    Source source=Resolve(S(item,"source"),directory);Need(TextHash(Json.Serialize(source.Manifest))==TextHash(Json.Serialize(m)),"Release changed after plan review");
    if(source.Archive==null){source.Archive=Path.Combine(directory,"archive.zip");Fetch(S(G(m,"download"),"url"),source.Archive);Need(Hash(source.Archive)==S(G(m,"download"),"sha256"),"Archive hash mismatch");}
    string payload=StageArchive(source.Archive,m,directory);staged.Add(Obj("manifest",S(item,"manifest"),"payload",payload));
   }
   string mods=Path.Combine(ModsRoot,"mods.txt");toggles.Add(Obj("id",id,"enabled",true,"mods_hash",File.Exists(mods)?Hash(mods):"","marker",File.Exists(Child(ModsRoot,id+"/enabled.txt"))));
  }
  var pending=PendingPlan(work);Need(!A(G(pending,"items")).Any()&&!A(G(pending,"removals")).Any()&&!A(G(pending,"toggles")).Any(),"Apply or clear existing pending changes before installing a new plan");pending["items"]=staged;pending["toggles"]=toggles;Write(Path.Combine(Data,"pending.json"),pending);return Restart();
 }
}
