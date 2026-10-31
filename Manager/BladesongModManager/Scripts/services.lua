-- Private manager services. No framework module is imported or required.
local root=assert(...);local J=assert(loadfile(root..'json.lua'))()
local F={VERSION='0.1.1',errors={},_json=J,cache={}}
local function read(path)
 local file=io.open(path,'rb');if not file then return end;local raw=file:read(1048577);file:close();if #raw>1048576 then return end
 local ok,value=pcall(J.decode,raw);if ok and type(value)=='table'then return value end
end
local metadata=read(root..'../mod.json')or{id='BladesongModManager',name='Bladesong Mod Manager',version=F.VERSION,standalone=true,settings={auto_check={type='boolean',default=true},registry_url={type='string',default=''}}}
F.cache['mod:BladesongModManager']=J.encode(metadata);F.cache.ids=J.encode({'BladesongModManager'})
local config=read(root..'../Data/settings.json')or{};local preferences=config.preferences or config.BladesongModManager or{}
function F._valid(o)local ok,v=pcall(function()return o and o:IsValid()end);return ok and v end
function F._get(k)return F.cache[k]end
function F._set(k,v)F.cache[k]=v end
local function shared(key)
 if not ModRef then return end;local ok,value=pcall(function()return ModRef:GetSharedVariable('BMF1:'..key)end);if ok then return value end
end
local function decoded(wire)local ok,value=pcall(J.decode,wire or'');if ok and type(value)=='table'then return value end end
local function bridge()
 local status=decoded(shared('status'));local installed=decoded(F.cache['mod:BladesongModFramework'])
 return status and status.ready and(not installed or installed.enabled~=false)
end
function F.ApplyDiscovery(result)
 F.identity=result.identity or F.identity
 local ids={'BladesongModManager'}
 for _,mod in ipairs(result.mods or{})do
  if mod.id and mod.id:match('^[%w_%-]+$')then F.cache['mod:'..mod.id]=J.encode(mod);if mod.id~='BladesongModManager'then ids[#ids+1]=mod.id end end
 end
 F.cache.ids=J.encode(ids)
end
function F.GetRegisteredMods()
 local result,seen={},{}
 local ids=decoded(F.cache.ids)or{};if bridge()then for _,id in ipairs(decoded(shared('ids'))or{})do ids[#ids+1]=id end end
 for _,id in ipairs(ids)do if not seen[id]then
  seen[id]=true;local installed=decoded(F.cache['mod:'..id]);local runtime=bridge()and decoded(shared('mod:'..id));if installed and installed.standalone then runtime=nil end;local mod=runtime or installed
  if mod then
   if installed then mod.enabled=installed.enabled;mod.install_owner=installed.install_owner end
   result[#result+1]=mod
  end
 end end
 table.sort(result,function(a,b)return a.id<b.id end);return result
end
function F.GetSettings(id)
 if id=='BladesongModManager'then return preferences end
 if bridge()then return(decoded(shared('settings'))or{})[id]or{}end;return{}
end
function F.SetSetting(id,key,value)
 local mod=decoded(F.cache['mod:'..id])or(bridge()and decoded(shared('mod:'..id)))or{}
 local definition=mod.settings and mod.settings[key];assert(definition and type(value)==definition.type,'Unknown setting or incorrect type')
 if id=='BladesongModManager'then
  preferences[key]=value
  if F.StartJob then F.StartJob('settings',{settings={schema_version=1,preferences=preferences}},function(result)if result.status=='failed'then F.errors[#F.errors+1]=result.error end end)end
 else
  assert(bridge(),'This mod needs its runtime running to edit settings');local all=decoded(shared('settings'))or{};all[id]=all[id]or{};all[id][key]=value
  ModRef:SetSharedVariable('BMF1:settings',J.encode(all))
 end
 return true
end
function F.SendPage(id,page)
 if not bridge()then return nil,'Selected mod runtime is not running'end
 F.sequence=(F.sequence or 0)+1;ModRef:SetSharedVariable('BMF1:command:'..id,J.encode({page=page,sequence=F.sequence,time=os.time(),epoch=shared('epoch')}));return true
end
function F.GetFrameworkStatus()
 if bridge()then local m=decoded(shared('mod:BladesongModFramework'))or{};return 'running '..tostring(m.version or'')end
 return 'not running (not required by manager)'
end
function F.GetGameVersion()return F.identity and F.identity.game or'unknown'end
function F.ExportDiagnostics(path)
 local file=assert(io.open(path,'wb'));file:write(J.encode({manager=F.VERSION,mods=F.GetRegisteredMods(),framework=F.GetFrameworkStatus(),errors=F.errors}));file:close();return true
end
return F
