local root=os.getenv('BMF_TEST_ROOT')or 'BladesongModdingPlatform'
local M,F,text,obj=assert(loadfile(root..'/Tests/manager_open.lua'))()
local jobs,settings={},{}
function F.GetSettings()return {registry_url=''}end
function F.SetSetting(_,key,value)assert(type(value)=='string');settings[key]=value end
function F.StartJob(operation,args,callback,progress)jobs[#jobs+1]={operation=operation,args=args,callback=callback,progress=progress}end
function text:Conv_TextToString(value)return {ToString=function()return value end}end
M.Open();assert(table.concat(M.tabs._labels,',')=='Installed,Browse,Settings,Developer')
M.PrimeCatalogue();assert(#M.browser>0 and #jobs==0,'Catalogue waited for network')
M.page='browse';M.Render();assert(#jobs==1 and jobs[1].operation=='browse'and not M.busy)
assert(jobs[1].args.index_url==M.default_index)
jobs[1].callback({status='complete',entries={{name='Preconstruction Library',repository='https://github.com/LTR-JT/PreconstructionLibrary',manifest={id='PreconstructionLibraryProbe',name='PCL',version='15.18.2'}}}})
local function action(caption)
 for _,entry in pairs(M.actions)do if entry.widget.caption==caption then return entry end end
 error('Missing action '..caption)
end
local before=M.panel;action('Install').callback()
assert(#jobs==2 and jobs[2].operation=='plan-install'and jobs[2].args.expected_id=='PreconstructionLibraryProbe')
assert(not M.quit_after_job and M.busy)
jobs[2].callback({status='failed',error='Offline'});assert(M.panel==before and not M.quit_after_job and not M.busy)
assert(M.registry==nil,'Fixed catalogue URL is editable')
-- Review stays inside the chosen mod card, below its title, rather than above Browse.
action('Install').callback();jobs[#jobs].callback({status='complete',plan={token='012345abcdef',items={{id='PreconstructionLibraryProbe',name='PCL',version='15.18.3',action='install'}}}})
local visited={};local function walk(w,ancestors)
 visited[#visited+1]=w.text or w.caption or ''
 if w.text=='INSTALLATION PLAN'then assert(ancestors[#ancestors].kind=='VerticalBox'and ancestors[#ancestors]~=M.content,'Review is outside mod card')end
 ancestors[#ancestors+1]=w;for _,child in ipairs(w.children or {})do walk(child,ancestors)end;ancestors[#ancestors]=nil
end
walk(M.content,{})
local order=table.concat(visited,'|');assert(order:find('COMMUNITY MODS',1,true)<order:find('INSTALLATION PLAN',1,true));assert(order:find('|PCL|',1,true)<order:find('INSTALLATION PLAN',1,true))
assert(action('Confirm & restart').widget.min_width==640,'Confirmation hit area is narrower than its caption')
action('Cancel installation').callback();assert(not M.install_plan)

action('Refresh catalogue').callback();assert(jobs[#jobs].args.force==true)
jobs[#jobs].callback({status='failed',error='Offline'})
M.url:SetText('https://github.com/LTR-JT/PreconstructionLibrary');action('Install from URL').callback()
assert(jobs[#jobs].operation=='plan-install'and type(jobs[#jobs].args.url)=='string')
jobs[#jobs].callback({status='failed',error='Offline'})
M.page='installed';M.Render();action('Check for updates').callback();local count=#jobs;M.CheckUpdates();assert(#jobs==count)
assert(M.UpdateStatus({id='Example'})=='Checking...')
M.update_checks.Unreleased={state='unpublished'};assert(M.UpdateStatus({id='Unreleased'})=='No published releases yet')
jobs[#jobs].progress({checks={Example={state='current'}},updates={}})
assert(M.update_checking and M.UpdateStatus({id='Example'})=='✓ Up to date')
jobs[#jobs].callback({status='complete',updates={{id='Example',name='Example mod',version='1.1.0',source='https://example.org/update.json'}},checks={Example={state='update',version='1.1.0'}}})
action('Update to 1.1.0').callback();assert(M.page=='installed'and jobs[#jobs].operation=='plan-install')
jobs[#jobs].callback({status='complete',plan={token='012345abcdef',items={{id='Example',name='Example mod',version='1.1.0',action='update'}}}})
assert(not M.quit_after_job and not M.busy)
action('Confirm & restart').callback();assert(jobs[#jobs].operation=='install'and jobs[#jobs].args.token=='012345abcdef')
local quit=0;local find=StaticFindObject
StaticFindObject=function(path)
 if path:find('KismetSystemLibrary',1,true)then local library=obj('Library');library.QuitGame=function()quit=quit+1 end;return library end
 return find(path)
end
jobs[#jobs].callback({status='waiting_for_exit'});assert(quit==1,'Successful install did not request normal game exit')
StaticFindObject=find
local registered=F.GetRegisteredMods
F.GetRegisteredMods=function()return {{id='PreconstructionLibraryProbe',name='PCL',repository='https://github.com/LTR-JT/PreconstructionLibrary',enabled=false}}end
M.busy=false;M.page='browse';M.Render()
for _,entry in pairs(M.actions)do assert(entry.widget.caption~='Install'and entry.widget.caption~='Confirm install','Extra/installed install button remains')end
assert(M.url.WidgetStyle.BackgroundImageNormal.DrawAs==0)
F.GetRegisteredMods=registered;M.Close()
print('PASS: cached catalogue appears before network; merged tabs; installed badge; reviewed dependency install/URL/update; failure stays open; only successful preparation requests exit')
