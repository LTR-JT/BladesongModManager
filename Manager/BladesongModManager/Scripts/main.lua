-- Standalone UE4SS entry point. Framework is only a dependency of selected SDK mods.
local scripts=assert(debug.getinfo(1,'S').source:gsub('^@',''):match('^(.*[\\/])'))
-- Keep the startup updater alive even if a game update breaks the menu module.
local startup_ok,startup_error=pcall(function()return assert(loadfile(scripts..'startup.lua'))(scripts)end)
if not startup_ok then print('[BMM Startup] '..tostring(startup_error)..'\n')end
local ui_ok,ui_error=pcall(function()
local services=assert(loadfile(scripts..'services.lua'))(scripts)
local client=assert(loadfile(scripts..'worker_client.lua'))(scripts,services)
services.StartJob=client.StartJob
local manager=assert(loadfile(scripts..'manager.lua'))(services,scripts,scripts)
manager.PrimeCatalogue(manager.default_index)
services.StartJob('discover',{},function(result)
 services.ApplyDiscovery(result)
 if result.last_apply and result.last_apply.status=='failed'then manager.message='Previous change failed: '..tostring(result.last_apply.error)end
end)
local last_check
local function tick()
 local ok,why=pcall(function()
  client.Poll();manager.Monitor()
  local settings=services.GetSettings('BladesongModManager')
  if settings.auto_check~=false and(not last_check or os.time()-last_check>=3600)then last_check=os.time();manager.CheckUpdates()end
  if not manager.browse_requested then manager.RefreshCatalogue(manager.default_index,false)end
  if manager.tabs and manager.tabstate then manager.tabs.update(manager.tabstate)end
 end)
 if not ok then services.errors[#services.errors+1]=tostring(why);print('[BMM] '..tostring(why)..'\n')end
 ExecuteInGameThreadWithDelay(500,tick)
end
tick()

end)
if not ui_ok then print('[BMM] Menu failed to initialize; startup updater remains independent: '..tostring(ui_error)..'\n')end
