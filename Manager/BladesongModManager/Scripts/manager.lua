local F,root,manager_root=...
manager_root=manager_root or root

local J=F._json
local catalogue=assert(loadfile(manager_root..'catalogue.lua'))()

local M={actions={},entries={},page='installed',generation=0,pending_actions={}}
M.default_index='https://raw.githubusercontent.com/LTR-JT/BladesongModFramework/main/mod-index.json'

local function valid(o)return F._valid(o)end

local function obj(path)local o=StaticFindObject(path);assert(valid(o),'Missing '..path);return o end

local function text(s)return obj('/Script/Engine.Default__KismetTextLibrary'):Conv_StringToText(tostring(s or ''))end

local function plain(value)
 if type(value)=='string'then return value end
 local converted=obj('/Script/Engine.Default__KismetTextLibrary'):Conv_TextToString(value)
 if type(converted)=='string'then return converted end
 local ok,result=pcall(function()return converted:ToString()end)
 assert(ok and type(result)=='string','Could not read text field')
 return result
end

function M.PrimeCatalogue(url)
 url=url or M.default_index
 if M.browser_url==url then return end
 M.browser_url=url;M.browser={}
 local file=io.open(manager_root..'../Data/catalogue-view.json','rb')
 if file then local wire=file:read('*a');file:close();local ok,snapshot=pcall(J.decode,wire)
  if ok and snapshot.url==url and type(snapshot.entries)=='table'then M.browser=snapshot.entries;return end
 end
 if url==M.default_index then
  local seed=io.open(manager_root..'community-index.json','rb')
  if seed then local wire=seed:read('*a');seed:close();local ok,index=pcall(J.decode,wire)
   if ok then for _,entry in ipairs(index.mods or {})do M.browser[#M.browser+1]={name=entry.name,repository=entry.url,status='discoverable'}end end
  end
 end
end
function M.RefreshCatalogue(url,force)
 if type(url)~='string'or url:match('^%s*$')then url=M.default_index end
 M.PrimeCatalogue(url)
 if M.catalogue_loading then return end
 M.browse_requested=true;M.catalogue_loading=true
 F.SetSetting('BladesongModManager','registry_url',url)
 F.StartJob('browse',{index_url=url,force=force==true},function(result)
  M.catalogue_loading=false
  if M.browser_url~=url then M.browse_requested=false;return end
  if result.entries then
   M.browser=result.entries
   local file=io.open(manager_root..'../Data/catalogue-view.json','wb')
   if file then file:write(J.encode({url=url,entries=result.entries}));file:close()end
  end
  M.catalogue_message=result.error or result.message
  if M.page=='browse'and not M.busy then M.Render()end
 end)
end
function M.CheckUpdates()
 if M.update_checking then return end;M.update_checking=true;M.update_checks={};M.updates={}
 for _,mod in ipairs(F.GetRegisteredMods())do M.update_checks[mod.id]={state='checking'}end
 if M.page=='installed'then M.Render()end
 local function progress(result)
  for id,check in pairs(result.checks or {})do M.update_checks[id]=check end
  if result.updates then M.updates=result.updates end
  if M.page=='installed'and not M.busy then M.Render()end
 end
 F.StartJob('updates',{},function(result)
  M.update_checking=false;M.updates=result.updates or {}
  M.update_message=result.error or result.message or 'Update check complete.'
  for id,check in pairs(M.update_checks)do
   M.update_checks[id]=(result.checks or {})[id]or{state=result.status=='failed'and 'failed'or 'unavailable',message=result.error or 'No update source'}
  end
  for _,mod in ipairs(F.GetRegisteredMods())do if not M.update_checks[mod.id]then M.update_checks[mod.id]={state='unavailable',message='No update source'}end end
  progress(result)
 end,progress)
end
function M.UpdateStatus(mod)
 local check=M.update_checks and M.update_checks[mod.id]
 if not check then return 'Updates not checked yet'end
 if check.state=='checking'then return 'Checking...'end
 if check.state=='current'then return '✓ Up to date'end
 if check.state=='unpublished'then return 'No published releases yet'end
 if check.state=='update'then return 'Update available: '..tostring(check.version or '')end
 if check.state=='pinned'then return 'Version pinned'end
 if check.state=='failed'then return 'Check failed: '..tostring(check.message or 'Try again')end
 return 'Update checks unavailable: '..tostring(check.message or 'No update source')
end

local function new(panel,kind)local o=StaticConstructObject(obj('/Script/UMG.'..kind),panel.WidgetTree);assert(valid(o),kind..' unavailable');return o end

local function widget(context,class)return obj('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(context,class,context:GetOwningPlayer())end

local function loadasset(path)

 local o=StaticFindObject(path);if valid(o)then return o end

 local p,a=path:match('^(.*)%.([^%.]+)$');local h=require('UEHelpers')

 return obj('/Script/AssetRegistry.Default__AssetRegistryHelpers'):GetAsset({PackageName=h.FindOrAddFName(p),AssetName=h.FindOrAddFName(a)})

end

local function find(w,name)

 if not valid(w)then return end;if w:GetFName():ToString()==name then return w end

 if w:IsA(obj('/Script/UMG.PanelWidget'))then for i=0,w:GetChildrenCount()-1 do local f=find(w:GetChildAt(i),name);if f then return f end end end

end

local function label(panel,s,size)

 local w=new(panel,'TextBlock');w:SetText(text(s));local font=w.Font;local reference=M.main.VersionText.Font;if valid(M.main.WBP_OptionsMenu)and valid(M.main.WBP_OptionsMenu.ScreenResolutionText)then reference=M.main.WBP_OptionsMenu.ScreenResolutionText.Font end;font.FontObject=reference.FontObject;font.TypefaceFontName=reference.TypefaceFontName;font.Size=size or 24;w:SetFont(font);w:SetAutoWrapText(true);w:SetVisibility(3)

 w:SetColorAndOpacity({SpecifiedColor={R=.56,G=.51,B=.35,A=1},ColorUseRule=0});return w

end

local function add(parent,w)local slot=parent:AddChildToVerticalBox(w);slot:SetHorizontalAlignment(0);slot:SetPadding({Left=12,Right=12,Top=8,Bottom=8});return slot end

local function url_field(panel)
 local input=new(panel,'EditableTextBox');input:SetHintText(text('https://github.com/owner/repository'));input:SetText(text(M.manual_url or ''))
 local style=input.WidgetStyle
 for _,name in ipairs({'BackgroundImageNormal','BackgroundImageHovered','BackgroundImageFocused','BackgroundImageReadOnly'})do style[name].DrawAs=0 end
 local font=style.TextStyle.Font;local reference=M.main.VersionText.Font
 font.FontObject=reference.FontObject;font.TypefaceFontName=reference.TypefaceFontName;font.Size=26
 local gold={R=.56,G=.51,B=.35,A=1};input:SetForegroundColor(gold)
 style.ForegroundColor={SpecifiedColor=gold,ColorUseRule=0};style.FocusedForegroundColor={SpecifiedColor=gold,ColorUseRule=0};style.ReadOnlyForegroundColor={SpecifiedColor=gold,ColorUseRule=0}
 style.TextStyle.ColorAndOpacity={SpecifiedColor=gold,ColorUseRule=0};style.Padding.Left=8;style.Padding.Right=8;style.Padding.Top=8;style.Padding.Bottom=8
 local frame=new(panel,'Border');frame:SetBrushColor({R=.20,G=.19,B=.13,A=1});frame:SetPadding({Left=2,Top=2,Right=2,Bottom=2})
 local background=new(panel,'Border');background:SetBrushColor({R=.008,G=.008,B=.006,A=1});background:SetPadding({Left=4,Top=4,Right=4,Bottom=4});background:SetContent(input);frame:SetContent(background)
 local height=new(panel,'SizeBox');height:SetHeightOverride(70);height:SetContent(frame)
 return input,height
end

local function button(panel,caption,callback)

 local ref=M.main.QuitButton;if panel~=M.main and valid(M.main.WBP_OptionsMenu)and valid(M.main.WBP_OptionsMenu.WBP_BladesongButton)then ref=M.main.WBP_OptionsMenu.WBP_BladesongButton end;local w=widget(panel,ref:GetClass());assert(valid(w));w:SetStyle(ref:GetStyle():GetClass());w:SetCaption(text(caption));w:SetMinDimensions(0,64);w:SetToolTipText(text(''))

 M.actions[w:GetAddress()]={widget=w,callback=callback};if M.rendering_content then M.content_action_ids=M.content_action_ids or {};M.content_action_ids[#M.content_action_ids+1]=w:GetAddress()end;return w

end

function M.Close()

 if valid(M.panel)then
  if valid(M.switcher)then local active=M.switcher:GetActiveWidget();if valid(active)and active:GetAddress()==M.panel:GetAddress()and valid(M.previous_page)then M.switcher:SetActiveWidget(M.previous_page)end end
  M.panel:RemoveFromParent()
 end
 M.switcher=nil;M.previous_page=nil;M.awaiting_page=nil;M.page_requested_at=nil;M.content=nil;M.tabs=nil;M.tabstate=nil;M.rendering_content=false

 M.panel=nil;M.actions={};if valid(M.entry)then M.actions[M.entry:GetAddress()]={widget=M.entry,callback=M.Open}end

end

function M.Render()

 if not valid(M.content)then return end
 if valid(M.url)then M.manual_url=plain(M.url:GetText())end

 for _,id in ipairs(M.content_action_ids or {})do M.actions[id]=nil end;M.content_action_ids={};M.content:ClearChildren();M.rendering_content=true

 local function line(s,target,size)add(target or M.content,label(M.panel,s,size or 26))end

 local function action(c,f,target)
  local holder=new(M.panel,'SizeBox');holder:SetWidthOverride(640);local control=button(M.panel,c,f);control:SetMinDimensions(640,64);holder:SetContent(control);local slot=add(target or M.content,holder);slot:SetHorizontalAlignment(1);return holder
 end

 local plan_rendered=false
 local function card()
  local frame=new(M.panel,'Border');frame:SetBrushColor({R=.20,G=.19,B=.13,A=1});frame:SetPadding({Left=2,Top=2,Right=2,Bottom=2});add(M.content,frame)
  local inside=new(M.panel,'Border');inside:SetBrushColor({R=.008,G=.008,B=.006,A=.97});inside:SetPadding({Left=22,Top=18,Right=22,Bottom=18});frame:SetContent(inside)
  local body=new(M.panel,'VerticalBox');inside:SetContent(body);return body
 end
 local function plan(target)
  if not M.install_plan or plan_rendered then return end;plan_rendered=true
  line('INSTALLATION PLAN',target,28)
  for _,item in ipairs(M.install_plan.items or {})do line(item.action..' — '..item.name..' '..item.version,target,23)end
  action('Confirm & restart',function()local token=M.install_plan.token;M.install_plan=nil;M.quit_after_job=true;M.Job('install',{token=token})end,target)
  action('Cancel installation',function()M.install_plan=nil;M.Render()end,target)
 end
 if M.adoption then
  line(M.adoption.message,nil,23)
  action('Confirm adoption',function()M.Job('adopt',{id=M.adoption.id,fingerprint=M.adoption.fingerprint})end)
  action('Cancel adoption',function()M.adoption=nil;M.Render()end)
 end
 if M.page=='installed'then

  local community,utilities=catalogue.partition(F.GetRegisteredMods())
  line('INSTALLED MODS',nil,28)
  line('Manage your mods here. Enable and disable changes take effect after restarting the game.',nil,24)
  line(M.update_checking and 'Checking for updates in the background...'or(M.update_message or 'Updates are checked automatically at startup.'),nil,23)
  action('Check for updates',M.CheckUpdates)
  local function render_mod(mod)
   local frame=new(M.panel,'Border');frame:SetBrushColor({R=.20,G=.19,B=.13,A=1});frame:SetPadding({Left=2,Top=2,Right=2,Bottom=2});add(M.content,frame)
   local inside=new(M.panel,'Border');inside:SetBrushColor({R=.008,G=.008,B=.006,A=.97});inside:SetPadding({Left=22,Top=18,Right=22,Bottom=18});frame:SetContent(inside)
   local body=new(M.panel,'VerticalBox');inside:SetContent(body)
   local name=mod.name or mod.id
   if mod.id=='PreconstructionLibraryProbe'and name==mod.id then name='Preconstruction Library'end
   local heading=new(M.panel,'HorizontalBox');add(body,heading)
   local title=label(M.panel,name,32);local title_slot=heading:AddChildToHorizontalBox(title);title_slot:SetSize({Value=1,SizeRule=1});title_slot:SetVerticalAlignment(2)
   if mod.version and mod.version~='0.0.0'then local vs=heading:AddChildToHorizontalBox(label(M.panel,'v'..mod.version,24));vs:SetVerticalAlignment(2)end
   if mod.author and mod.author~=''then line('By '..mod.author,body,23)end
   if mod.description and mod.description~=''and not mod.discovered then line(mod.description,body)end
   line((mod.enabled==false and 'Disabled'or 'Enabled')..'  |  '..(mod.standalone and 'Standalone UE4SS mod'or(mod.integration=='ordinary'and 'Ordinary UE4SS mod'or(mod.integration=='manifest'and 'Manifest integration'or 'SDK integration'))),body,24)
   if mod.integration=='ordinary'then line('Uses its own game interfaces; behavior has not been verified by the framework.',body,23)elseif mod.compatibility then line('Compatibility: '..mod.compatibility.state..' (behavior not automatically verified)',body,23)end
   for _,failure in ipairs(mod.failures or {})do line(failure,body,24)end
   for page,definition in pairs(mod.pages or {})do action(definition.title or page,function()M.Close();F.SendPage(mod.id,page)end,body)end
   line('Maintained by: '..tostring(mod.install_owner or 'manual'),body,22)
   if mod.install_owner=='manual'then action('Review adoption',function()M.Job('inspect-adoption',{id=mod.id})end,body)end
   line(M.UpdateStatus(mod),body,24)
   for _,update in ipairs(M.updates or {})do if update.id==mod.id then
    action('Update to '..update.version,function()M.Install(update.source or mod.repository,mod.id)end,body)
   end end
   if M.plan_origin and M.plan_origin.id==mod.id then plan(body)end
   if mod.id~='BladesongModFramework'then
    action((mod.enabled==false and 'Enable'or 'Disable')..' on next launch',function()M.Job('toggle',{id=mod.id,enabled=mod.enabled==false})end,body)
    action('Uninstall',function()M.quit_after_job=true;M.Job('uninstall',{id=mod.id})end,body)
    line('Uninstall restarts Bladesong. Your library is preserved and restored when you reinstall.',body,21)
   end
  end
  for _,mod in ipairs(community)do render_mod(mod)end
  if #utilities>0 then
   action((M.show_utilities and 'Hide 'or 'Show ')..'UE4SS utilities ('..#utilities..')',function()M.show_utilities=not M.show_utilities;M.Render()end)
   if M.show_utilities then for _,mod in ipairs(utilities)do render_mod(mod)end end
  end

 elseif M.page=='browse'then
  line('COMMUNITY MODS',nil,28)
  line('Install validates and downloads the mod, then restarts Bladesong automatically.',nil,24)
  local installed_mods=F.GetRegisteredMods()
  local url=M.default_index;M.PrimeCatalogue(url)
  line('Install from URL',nil,26)
  local field;M.url,field=url_field(M.panel);add(M.content,field)
  action('Install from URL',function()M.Install(plain(M.url:GetText()))end)
  if M.plan_origin and not M.plan_origin.id then plan(M.content)end
  action('Refresh catalogue',function()M.RefreshCatalogue(M.default_index,true)end)
  if M.catalogue_loading then line('Refreshing in the background...',nil,23)elseif M.catalogue_message then line(M.catalogue_message,nil,23)end
  for _,entry in ipairs(M.browser or {})do
   local body=card()
   line(entry.manifest and entry.manifest.name or entry.name,body,30)
   if entry.manifest then line(entry.manifest.description or '',body,24);line('Repository version '..entry.manifest.version..(entry.cached and ' (cached)'or ''),body,23)end
   if catalogue.installed(entry,installed_mods)then line('✓ Installed',body,26)
   elseif entry.manifest or entry.status=='discoverable'then
    if M.install_plan and M.plan_origin and M.plan_origin.url==entry.repository then plan(body)
    else action('Install',function()M.Install(entry.repository,entry.manifest and entry.manifest.id)end,body)end
   else line('Repository unavailable: '..(entry.error or ''),body,23)end
  end
 elseif M.page=='settings'then

  line('SETTINGS',nil,28)
  for _,mod in ipairs(F.GetRegisteredMods())do
   local keys={};for key,definition in pairs(mod.settings or {})do if definition.type=='boolean'then keys[#keys+1]=key end end;table.sort(keys)
   if #keys>0 then
    local body=card();line(mod.name or mod.id,body,30)
    local settings=F.GetSettings(mod.id)
    for _,key in ipairs(keys)do
     local definition=mod.settings[key];local value=settings[key];if value==nil then value=definition.default end
     local names={auto_check='Automatically check for updates',auto_update_manager='Automatically update Mod Manager',developer_mode='Developer mode'}
     local caption=definition.label or names[key]or key:gsub('_',' '):gsub('^%l',string.upper)
     local row=new(M.panel,'HorizontalBox');add(body,row)
     local name_slot=row:AddChildToHorizontalBox(label(M.panel,caption,26));name_slot:SetSize({Value=1,SizeRule=1});name_slot:SetVerticalAlignment(2)
     local toggle=button(M.panel,value and 'On'or 'Off',function()F.SetSetting(mod.id,key,not value);M.Render()end);toggle:SetMinDimensions(220,64)
     local holder=new(M.panel,'SizeBox');holder:SetWidthOverride(220);holder:SetContent(toggle)
     local slot=row:AddChildToHorizontalBox(holder);slot:SetVerticalAlignment(2);slot:SetPadding({Left=20,Top=0,Right=0,Bottom=0})
    end
   end
  end

 else

  line('Mod Manager '..F.VERSION..' | Standalone UE4SS mod');line('Game: '..F.GetGameVersion()..' | Optional framework: '..F.GetFrameworkStatus())


  action('Export diagnostic report',function()F.ExportDiagnostics(manager_root..'../Data/diagnostics.json');line('Diagnostic report exported without usernames, hardware IDs, or save contents.')end)

  for _,err in ipairs(F.errors)do line(err)end

 end

 if M.install_plan and not plan_rendered then plan(card())end
 if M.message then line(M.message)end
 if M.staged then
  action('Restart & Apply',function()M.restart_review=not M.restart_review;M.Render()end)
 end
 if M.restart_review then
  line('Save any unsaved gameplay first. This closes Bladesong normally and installs the staged files after it exits.')
  action('Confirm saved - restart and apply',function()M.quit_after_job=true;M.Job('restart',{})end)
 end
 M.rendering_content=false
 if M.page=='browse'and not M.browse_requested and not M.busy then M.RefreshCatalogue(M.default_index)end

end

function M.Install(url,id)
 if M.busy then return end
 M.plan_origin={url=url,id=id,page=M.page};M.install_plan=nil;M.Job('plan-install',{url=url,expected_id=id or ''})
end
function M.Job(operation,args)

 if M.busy then return end

 local ok,err=pcall(function()F.StartJob(operation,args,function(result)

  M.busy=false;M.message=result.error or result.message or result.status
  if(operation=='stage'or operation=='toggle')and result.status=='complete'then M.staged=true end
  if result.status=='failed'then M.quit_after_job=false end

  if result.plan then M.install_plan=result.plan end
  if result.fingerprint then M.adoption=result end
  if operation=='adopt'and result.status=='complete'then
   M.adoption=nil;local wire=F._get and F._get('mod:'..result.id)
   if wire then local metadata=J.decode(wire);metadata.install_owner='bladesong-in-game';F._set('mod:'..result.id,J.encode(metadata))end
  end
  if result.entries then M.browser=result.entries end;if result.mod then M.preview=result.mod end;if result.updates then M.updates=result.updates end

  if M.quit_after_job and result.status=='waiting_for_exit'then

   obj('/Script/Engine.Default__KismetSystemLibrary'):QuitGame(M.main,M.main:GetOwningPlayer(),0,false);return

  end

  M.Render()

 end);M.busy=true;M.message=operation=='install'and 'Validating and downloading; Bladesong will restart when ready...'or 'Working...';M.Render()end)

 if not ok then M.busy=false;M.quit_after_job=false;M.message=tostring(err);M.Render()end

end

function M.Open()

 M.Close()

 local options=M.main.WBP_OptionsMenu;assert(valid(options),'Native Options menu unavailable')
 local template=options.ScreenModeApplyFrame;assert(valid(template),'Native menu frame unavailable')
 local class=template:GetClass()

 local panel=widget(M.main,class);M.panel=panel
 local inherited_visibility=panel:GetVisibility();local inherited_enabled=panel:GetIsEnabled()
 -- The stock tutorial frame is decorative. Its input flags must not disable
 -- the manager's complete descendant tree. SelfHitTestInvisible keeps children interactive.
 panel:SetVisibility(4);panel:SetIsEnabled(true)
 print('[BMM] Manager input root enabled; inherited_visibility='..tostring(inherited_visibility)..' inherited_enabled='..tostring(inherited_enabled)..'\n')

 local rootbox=new(panel,'SizeBox');rootbox:SetVisibility(4);rootbox:SetIsEnabled(true);panel.WidgetTree.RootWidget=rootbox

 rootbox:SetWidthOverride(1600);rootbox:SetMaxDesiredWidth(1600);rootbox:SetHeightOverride(1740)


 local frame=new(panel,'Border');frame:SetBrushColor({R=.20,G=.19,B=.13,A=1});frame:SetPadding({Left=2,Top=2,Right=2,Bottom=2});rootbox:SetContent(frame)
 local border=new(panel,'Border');border:SetBrushColor({R=.008,G=.008,B=.006,A=.97});border:SetPadding({Left=28,Top=24,Right=28,Bottom=24});frame:SetContent(border)

 local body=new(panel,'VerticalBox');border:SetContent(body);add(body,label(panel,'BLADESONG MODS',40))

 local nav=new(panel,'CanvasPanel');local navbox=new(panel,'SizeBox');navbox:SetHeightOverride(80);navbox:SetContent(nav);add(body,navbox)

 local env=setmetatable({}, {__index=_G});env.bmm_new=new;env.bmm_label=function(p,c,size)return label(p,c,size)end;env.bmm_to_text=text;env.is_valid=valid

 env.bmm_transparent_style=function()return loadasset('/Game/UI/Style/ButtonStyle_Transparent.ButtonStyle_Transparent_C')end

 env.bmm_remove_native_chrome=function()end

 env.bmm_button=function(_,_,c,_,extra)return button(panel,c,function()M.page=extra.tab_id;M.tabstate.active_tab_id=M.page;M.Render();M.tabs.update(M.tabstate)end)end

 local tabs=assert(loadfile(manager_root..'ui/tabs.lua','t',env))();M.tabs=tabs

 env.BMM_TABS={is_active=function(id,state)return id==state.active_tab_id end}

 local ts={home=panel,folder_tabs={},active_tab_id=M.page};M.tabstate=ts

 for i,definition in ipairs({{'installed','Installed'},{'browse','Browse'},{'settings','Settings'},{'developer','Developer'}})do tabs.tab(ts,nav,definition[2],'manager_tab',(i-1)*240,{id=definition[1],width=240})end;tabs.update(ts)

 local scroll=new(panel,'ScrollBox');local slot=add(body,scroll);slot:SetSize({Value=1,SizeRule=1});M.content=new(panel,'VerticalBox');scroll:AddChild(M.content)

 M.rendering_content=false
 local footer=new(panel,'SizeBox');footer:SetWidthOverride(360);footer:SetContent(button(panel,'Close',M.Close));local footslot=add(body,footer);footslot:SetHorizontalAlignment(1);footslot:SetPadding({Left=12,Right=12,Top=22,Bottom=4})
 M.Render();M.rendering_content=false
 M.switcher=M.main.WidgetSwitcher;assert(valid(M.switcher),'Native main-menu switcher unavailable')
 M.previous_page=M.switcher:GetActiveWidget();local pageslot=M.switcher:AddChild(panel);pageslot:SetHorizontalAlignment(2);pageslot:SetVerticalAlignment(2)
 M.awaiting_page=true;M.page_requested_at=os.time()
 M.switcher:SetActiveWidget(panel)
 print('[BMM] Mods page requested through native menu switcher\n')


end

function M.DrainActions()
 M.action_tick_pending=false
 local pending=M.pending_actions;M.pending_actions={}
 for _,entry in ipairs(pending)do
  if valid(entry.widget)and M.actions[entry.widget:GetAddress()]==entry then
   local ok,why=pcall(entry.callback);if not ok then F.errors[#F.errors+1]=tostring(why);print('[BMM] '..tostring(why)..'\n')end
  end
 end
end
function M.Monitor()
 M.TryBindClickHook()
 M.DrainActions()
 if valid(M.panel)and valid(M.switcher)then
  -- CommonAnimatedSwitcher keeps reporting the outgoing page during its animation.
  -- That is not a Back/navigation action and must never remove the incoming page.
  if M.switcher:IsCurrentlySwitching()or M.switcher:IsTransitionPlaying()then return end
  local active=M.switcher:GetActiveWidget()
  if valid(active)and active:GetAddress()==M.panel:GetAddress()then
   if M.awaiting_page then print('[BMM] Mods page active; native transition settled\n')end
   M.awaiting_page=false
   return
  elseif M.awaiting_page then
   if os.time()-(M.page_requested_at or os.time())<5 then return end
   print('[BMM] Mods page activation timed out; returning to previous native page\n')
   if valid(M.previous_page)then M.switcher:SetActiveWidget(M.previous_page)end
   M.Close()
  else M.Close()end
 end

 if not valid(M.main)or not M.main:IsVisible()then

  M.Close();M.main=nil;M.entry=nil

  for _,w in pairs(FindAllOf('WBP_MainMenu_C')or {})do if valid(w)and w:IsVisible()and valid(w.QuitButton)and valid(w.QuitButton:GetParent())then M.main=w;break end end

 end

 if valid(M.main)and F.LegacyCombinedMenu and F.LegacyCombinedMenu()then
  local options=M.main.OptionsButton;local parent=valid(options)and options:GetParent()
  if valid(parent)then for i=0,parent:GetChildrenCount()-1 do
   local child=parent:GetChildAt(i);local known,is_button=pcall(function()return child:IsA(options:GetClass())end)
   local own=valid(child)and valid(M.entry)and child:GetAddress()==M.entry:GetAddress()
   if own then child:SetVisibility(0)
   elseif known and is_button then
    local ok,caption=pcall(function()return plain(child.Caption)end)
    if ok and type(caption)=='string'and caption:lower()=='mods'then child:SetVisibility(1)end
   end
  end end
 end
 if valid(M.main)and (not valid(M.entry)or not valid(M.entry:GetParent()))then

  local old=M.entries[M.main:GetAddress()];if old and valid(old)and valid(old:GetParent())then M.entry=old;M.actions[old:GetAddress()]={widget=old,callback=M.Open};return end

  local options=M.main.OptionsButton
  local parent=options:GetParent()
  assert(valid(parent)and parent:IsA(obj('/Script/UMG.WrapBox')),'Native main-menu WrapBox unavailable')
  local function copy_slot(slot)
   return {padding={Left=slot.Padding.Left,Top=slot.Padding.Top,Right=slot.Padding.Right,Bottom=slot.Padding.Bottom},
    horizontal=slot.HorizontalAlignment,vertical=slot.VerticalAlignment,fill=slot.bFillEmptySpace,
    newline=slot.bForceNewLine,span=slot.FillSpanWhenLessThan}
  end
  local function apply_slot(slot,style)
   slot:SetPadding(style.padding);slot:SetHorizontalAlignment(style.horizontal);slot:SetVerticalAlignment(style.vertical)
   slot:SetFillEmptySpace(style.fill);slot:SetNewLine(style.newline);slot:SetFillSpanWhenLessThan(style.span)
  end
  local insertion=parent:GetChildIndex(options);assert(insertion>=0,'Options not in native menu')
  local style=copy_slot(options.Slot)
  local tail={}
  for i=insertion,parent:GetChildrenCount()-1 do local child=parent:GetChildAt(i);tail[#tail+1]={widget=child,style=copy_slot(child.Slot)}end
  local entry=button(M.main,'MODS',M.Open)
  entry:SetMinDimensions(options.MinWidth,options.MinHeight)
  -- Preserve the actual native widgets, callbacks and each slot's layout settings.
  -- Reappend only the tail because UPanelWidget has no reflected insert-at method.
  for _,item in ipairs(tail)do item.widget:RemoveFromParent()end
  apply_slot(parent:AddChildToWrapBox(entry),style)
  for _,item in ipairs(tail)do apply_slot(parent:AddChildToWrapBox(item.widget),item.style)end
  M.entry=entry
  M.entries[M.main:GetAddress()]=M.entry;print('[BMM] Native main-menu Mods button attached\n')

 end

end

function M.TryBindClickHook()
 if M.click_hook_installed then return true end
 local path='/Script/CommonUI.CommonButtonBase:HandleButtonClicked'
 local found,fn=pcall(StaticFindObject,path);if not found or not valid(fn)then return false end
 local ok,why=pcall(RegisterHook,path,function(context)

 local b=context:get();if not valid(b)then return end;local a=M.actions[b:GetAddress()]

 -- Rebuild on the next game-thread tick, after Slate's click callback unwinds.
 if a and valid(a.widget)then
  M.pending_actions[#M.pending_actions+1]=a
  if not M.action_tick_pending and type(ExecuteInGameThreadWithDelay)=='function'then
   M.action_tick_pending=true;ExecuteInGameThreadWithDelay(1,M.DrainActions)
  end
 end

end)
 if ok then M.click_hook_installed=true;return true end
 if M.hook_error~=tostring(why)then M.hook_error=tostring(why);F.errors[#F.errors+1]=M.hook_error end
 return false
end
M.TryBindClickHook()

return M

