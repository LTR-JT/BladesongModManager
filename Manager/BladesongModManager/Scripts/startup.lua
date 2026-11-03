-- Starts before services/UI. Only file IO, pure Lua JSON and the OS worker launcher are used.
local root=assert(...)
local J=assert(loadfile(root..'json.lua'))()
local context={_json=J,errors={}}
local client=assert(loadfile(root..'worker_client.lua'))(root,context)
client.StartJob('startup-update',{},function(result)
 if result.status=='failed'then print('[BMM Startup] '..tostring(result.error)..'\n')end
end)
return client
