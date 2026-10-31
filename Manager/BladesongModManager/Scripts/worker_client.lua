-- Per-Lua-state job client. No shell or console host is involved.
local root,F=...
local J=F._json
local C={jobs={},sequence=0}
function C.StartJob(operation,args,callback,progress)
 C.sequence=C.sequence+1
 local id='job_'..os.time()..'_'..math.floor(os.clock()*1000000)..'_'..C.sequence
 local base=root..'../'
 local path=base..id..'.json'
 local capabilities={};for name in pairs(F._map.capabilities)do if F.HasCapability(name)then capabilities[#capabilities+1]=name end end
 local file=assert(io.open(path,'wb'));assert(file:write(J.encode({id=id,operation=operation,args=args or {},capabilities=capabilities})));assert(file:close())
 C.launch=C.launch or assert(package.loadlib(base..'Scripts/bmm-launch.dll','bmf_launch'))
 local bytes=base..'Scripts/bmm-worker.exe'..'\0'..path
 local arguments={#bytes};for i=1,#bytes do arguments[#arguments+1]=bytes:byte(i)end
 assert(C.launch(table.unpack(arguments))>0,'Could not launch the background worker')
 C.jobs[id]={path=path,callback=callback,progress=progress,started=os.time()}
 if not C.polling and type(ExecuteInGameThreadWithDelay)=='function'then
  C.polling=true
  local function poll()
   C.Poll()
   if next(C.jobs)then ExecuteInGameThreadWithDelay(50,poll)else C.polling=false end
  end
  ExecuteInGameThreadWithDelay(50,poll)
 end
 return id
end
function C.Poll()
 for id,job in pairs(C.jobs)do
  local file=io.open(job.path..'.result.json','rb')
  local response
  if file then local wire=file:read('*a');file:close();local ok,value=pcall(J.decode,wire);response=ok and value or {status='failed',error='Invalid worker result'}
  elseif os.time()-job.started>180 then response={status='failed',error='Worker timed out. Staged files have not been applied.'}end
  if not response and job.progress then
   local progress=io.open(job.path..'.progress.json','rb')
   if progress then
    local wire=progress:read('*a');progress:close()
    if wire~=job.progress_seen then
     job.progress_seen=wire;local decoded,value=pcall(J.decode,wire)
     if decoded then local ok,why=pcall(job.progress,value);if not ok then F.errors[#F.errors+1]=tostring(why);print('[BMF] Job progress callback failed: '..tostring(why)..'\n')end end
    end
   end
  end
  if response then
   C.jobs[id]=nil
   if job.callback then local ok,why=pcall(job.callback,response);if not ok then F.errors[#F.errors+1]=tostring(why);print('[BMF] Job callback failed: '..tostring(why)..'\n')end end
  end
 end
end
return C
