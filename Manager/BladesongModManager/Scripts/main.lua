-- Optional management component. The framework never imports this mod.
local scripts=debug.getinfo(1,'S').source:gsub('^@',''):match('^(.*[\\/])')
local root=scripts..'../../shared/BladesongFramework/'
local ok,F=pcall(function()return assert(loadfile(root..'api.lua'))(root)end)
if not ok then print('[BMM] Install BladesongModFramework using the bootstrap package.\n');return end
F.Ready(function()
 if not F._version.matches(F.GetFrameworkVersion(),'>=0.1.8 <1.0.0')then print('[BMM] This manager needs framework 0.1.8 or newer; use the bootstrap package.\n');return end
 F.BindMod('BladesongModManager')
 local preferences=F.GetSettings('BladesongModManager');local legacy=F.GetSettings('BladesongModFramework')
 for _,key in ipairs({'auto_check','registry_url'})do
  local expected=key=='auto_check'and 'boolean'or 'string'
  if preferences[key]==nil and type(legacy[key])==expected then F.SetSetting('BladesongModManager',key,legacy[key])end
 end
 local client=assert(loadfile(scripts..'worker_client.lua'))(scripts,F)
 F.StartJob=client.StartJob
 local M=assert(loadfile(scripts..'manager.lua'))(F,root,scripts)
 M.PrimeCatalogue(M.default_index)
 F.StartJob('discover',{},function(result)
  if result.last_apply and result.last_apply.status=='failed'then M.message='Previous change failed: '..tostring(result.last_apply.error)end
  for _,metadata in ipairs(result.mods or {})do
   if metadata.id and not F._get('mod:'..metadata.id)then
    F._set('mod:'..metadata.id,F._json.encode(metadata));local ids=F._json.decode(F._get('ids')or '[]');ids[#ids+1]=metadata.id;F._set('ids',F._json.encode(ids))
   end
  end
 end)
 local last_check
 local function tick()
  local ok,why=pcall(function()
   F.Poll();client.Poll();M.Monitor()
   local settings=F.GetSettings('BladesongModManager')
   if settings.auto_check~=false and (not last_check or os.time()-last_check>=3600)then last_check=os.time();M.CheckUpdates()end
   if not M.browse_requested then M.RefreshCatalogue(M.default_index,false)end
   if M.tabs and M.tabstate then M.tabs.update(M.tabstate)end
  end)
  if not ok then print('[BMM] '..tostring(why)..'\n')end
  ExecuteInGameThreadWithDelay(500,tick)
 end
 tick()
end)
