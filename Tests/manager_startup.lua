-- Actual optional-manager entry point with mocked game services and IO clients.
local repo=assert(os.getenv('BMF_TEST_ROOT'))
local FRAMEWORK=os.getenv('BMF_FRAMEWORK_ROOT')or repo..'/../BladesongModFramework'
local semver=assert(loadfile(FRAMEWORK..'/Framework/shared/BladesongFramework/semver.lua'))()
local function boot(version)
 local calls,scheduled={},{}
 local prefs={BladesongModFramework={auto_check=false,registry_url='https://example.org/index.json'},BladesongModManager={}}
 local F={_version=semver,_json={decode=function()return{}end}}
 function F.Ready(callback)callback()end
 function F.GetFrameworkVersion()return version end
 function F.BindMod(id)assert(id=='BladesongModManager');calls.bound=true end
 function F.GetSettings(id)return prefs[id]end
 function F.SetSetting(id,key,value)prefs[id][key]=value end
 function F.Poll()end
 local M={}
 function M.PrimeCatalogue()calls.primed=true end
 function M.Monitor()calls.monitored=true end
 function M.CheckUpdates()error('Legacy auto_check=false was lost')end
 function M.RefreshCatalogue()M.browse_requested=true end
 local client={Poll=function()end,StartJob=function(op,args,callback)assert(op=='discover');calls.discovered=true;callback({mods={}})end}
 local env=setmetatable({},{__index=_G})
 function env.print(message)calls.message=message end
 function env.ExecuteInGameThreadWithDelay(_,callback)scheduled[#scheduled+1]=callback end
 function env.loadfile(path)
  if path:match('api.lua$')then return function()assert(version,'Missing framework');return F end end
  if path:match('worker_client.lua$')then return function()return client end end
  if path:match('manager.lua$')then return function()return M end end
  error('Unexpected import '..path)
 end
 assert(loadfile(repo..'/Manager/BladesongModManager/Scripts/main.lua','t',env))()
 return calls,prefs
end
local absent=boot(nil);assert(not absent.bound and absent.message:find('bootstrap',1,true))
local old=boot('0.1.7');assert(not old.bound and old.message:find('bootstrap',1,true))
local current,prefs=boot('0.1.8');assert(current.bound and current.primed and current.monitored and current.discovered)
assert(prefs.BladesongModManager.auto_check==false and prefs.BladesongModFramework.auto_check==false)
print('PASS: optional manager refuses missing/old runtime, initializes separately on supported runtime, and preserves legacy preferences (mocked game services)')
