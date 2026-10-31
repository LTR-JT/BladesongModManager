-- Actual standalone entry point and private services, with mocked UE4SS UI/launchers.
local repo=assert(os.getenv('BMF_TEST_ROOT'));local root=repo..'/Manager/BladesongModManager/Scripts/'
local J=assert(loadfile(root..'json.lua'))();local native_load=loadfile
local function boot(with_framework)
 local calls={};local services;local shared={}
 if with_framework then
  shared['BMF1:status']=J.encode({ready=true});shared['BMF1:ids']=J.encode({'BladesongModFramework'});shared['BMF1:mod:BladesongModFramework']=J.encode({id='BladesongModFramework',version='0.1.7'});
 end
 local env=setmetatable({},{__index=_G});env.ModRef={GetSharedVariable=function(_,k)return shared[k]end}
 local manager={default_index='https://example.org/index.json'}
 function manager.PrimeCatalogue()calls.primed=true end
 function manager.Monitor()calls.monitored=true end
 function manager.CheckUpdates()calls.checked=true end
 function manager.RefreshCatalogue()manager.browse_requested=true end
 function env.ExecuteInGameThreadWithDelay()end
 function env.loadfile(path,...)
  assert(not path:find('shared/BladesongFramework',1,true),'Standalone manager imported the framework')
  if path:match('services.lua$')then return function()services=assert(native_load(path,'t',env))(root);return services end end
  if path:match('manager.lua$')then return function()return manager end end
  if path:match('worker_client.lua$')then return function()return{Poll=function()end,StartJob=function(op,args,callback)
   if op=='discover'then calls.discovered=true;callback({mods={}})else error('Unexpected operation '..op)end
  end}end end
  return native_load(path,...)
 end
 assert(native_load(root..'main.lua','t',env))()
 assert(calls.primed and calls.monitored and calls.discovered)
 assert(services.GetFrameworkStatus():find(with_framework and 'running'or'not running',1,true))
 local own=J.decode(services._get('mod:BladesongModManager'));assert(own.standalone and not own.dependencies.BladesongModFramework)
end
boot(false);boot(true)
print('PASS: manager entry point/services run without a framework, and optional legacy framework presence does not gate initialization')
