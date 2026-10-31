local TEST_ROOT=os.getenv('BMF_TEST_ROOT')or 'BladesongModdingPlatform'
-- Exercise the complete Open path with the actual asset's slotless SizeBox root.
local serial=0
local function obj(kind,name)
 serial=serial+1
 local w={kind=kind,name=name or kind,id=serial,children={},visibility=0,enabled=true,Font={Size=24},WidgetStyle={Padding={},TextStyle={Font={}},BackgroundImageNormal={},BackgroundImageHovered={},BackgroundImageFocused={},BackgroundImageReadOnly={}}}
 function w:IsValid()return true end
 function w:GetAddress()return self.id end
 function w:GetFName()return {ToString=function()return self.name end}end
 function w:GetClass()return self end
 function w:IsA(c)return self.kind==c.kind end
 function w:GetParent()return self.parent end
 function w:GetStyle()return self end
 function w:GetOwningPlayer()end
 function w:GetChildrenCount()return #self.children end
 function w:GetChildAt(i)return self.children[i+1]end
 function w:RemoveFromParent()self.removed=true;self.parent=nil end
 function w:AddChild(child)
  self.children[#self.children+1]=child;child.parent=self
  local slot={}
  function slot:SetHorizontalAlignment(v)self.horizontal=v end
  function slot:SetVerticalAlignment(v)self.vertical=v end
  function slot:SetPadding(v)self.padding=v end
  function slot:SetSize(v)self.size=v end
  child.Slot=slot;return slot
 end
 w.AddChildToVerticalBox=w.AddChild;w.AddChildToHorizontalBox=w.AddChild
 function w:SetContent(child)self.children={};self:AddChild(child)end
 function w:ClearChildren()self.children={}end
 function w:SetText(v)self.text=v end
 function w:GetText()return self.text end
 function w:SetHintText(v)self.hint=v end
 function w:SetCaption(v)self.caption=v end
 function w:SetVisibility(v)self.visibility=v end
 function w:SetIsEnabled(v)self.enabled=v end
 function w:GetVisibility()return self.visibility end
 function w:GetIsEnabled()return self.enabled end
 for _,method in ipairs({'SetForegroundColor','SetStyle','SetMinDimensions','SetToolTipText','SetFont','SetAutoWrapText','SetColorAndOpacity','SetWidthOverride','SetMaxDesiredWidth','SetHeightOverride','SetBrushColor','SetPadding'})do w[method]=function()end end
 function w:AddToViewport()error('Must use native menu switcher, not a viewport overlay')end
 return w
end
local panel
local library=obj('Library')
function library:Create(context,class)
 if class.kind=='AssetClass'then
  panel=obj('UserWidget');panel.visibility=3;panel.enabled=false;panel.WidgetTree={RootWidget=obj('SizeBox','StockFrameRoot')}
  assert(panel.WidgetTree.RootWidget.Slot==nil)
  return panel
 end
 return obj('Button')
end
local text=obj('Text');function text:Conv_StringToText(v)return v end
function StaticFindObject(path)
 if path:find('Default__WidgetBlueprintLibrary',1,true)then return library end
 if path:find('Default__KismetTextLibrary',1,true)then return text end
 assert(not path:find('/Game/PCL/',1,true),'Manager requested a framework/PCL asset')
 if path:find('/Game/',1,true)then return obj('AssetClass')end
 return obj(path:match('%.([^%.]+)$'))
end
function StaticConstructObject(class)return obj(class.kind)end
local click_hook
function RegisterHook(path,callback)if path:find('HandleButtonClicked',1,true)then click_hook=callback end end
local original_loadfile=loadfile
function loadfile(path,...)
 if path:match('ui/tabs.lua$')then return function()local labels={};return {_labels=labels,tab=function(_,_,caption)labels[#labels+1]=caption end,update=function()end}end end
 return original_loadfile(path,...)
end
local native=obj('NativeMainPage');local switcher=obj('WidgetSwitcher');switcher.active=native
function switcher:GetActiveWidget()return self.active end
function switcher:IsCurrentlySwitching()return self.switching or false end
function switcher:IsTransitionPlaying()return self.animating or false end
function switcher:SetActiveWidget(w)self.active=w end
local F={_json=assert(original_loadfile(TEST_ROOT..'/Manager/BladesongModManager/Scripts/json.lua'))(),_valid=function(w)return type(w)=='table'and type(w.IsValid)=='function'and w:IsValid()end,errors={}}
function F.GetRegisteredMods()return {{id='Example',name='Example mod',version='1.0.0',description='Example description',status='registered',enabled=true},{id='ConsoleCommandsMod',name='Console commands',version='0.0.0',discovered=true}}end
local M=assert(loadfile(TEST_ROOT..'/Manager/BladesongModManager/Scripts/manager.lua'))(F,TEST_ROOT..'/Manager/BladesongModManager/Scripts/',TEST_ROOT..'/Manager/BladesongModManager/Scripts/')
M.main=obj('Main');M.main.QuitButton=obj('Button');M.main.VersionText=obj('TextBlock');M.main.WidgetSwitcher=switcher;M.main.WBP_OptionsMenu=obj('Options');M.main.WBP_OptionsMenu.ScreenModeApplyFrame=obj('AssetClass');M.main.WBP_OptionsMenu.ScreenResolutionText=obj('TextBlock')
M.Open()
assert(switcher.active==panel and panel.parent==switcher)
assert(panel.visibility==4 and panel.enabled,'Decorative stock widget blocked the entire manager input tree')
assert(panel.Slot.horizontal==2 and panel.Slot.vertical==2)
assert(M.content:GetChildrenCount()>0 and M.rendering_content==false)
-- The native switcher can report the outgoing page for several monitor ticks.
switcher.active=native;switcher.switching=true
M.Monitor();assert(M.panel==panel and not panel.removed)
switcher.switching=false;switcher.animating=true
M.Monitor();assert(M.panel==panel and not panel.removed)
switcher.animating=false
M.Monitor();assert(M.panel==panel and M.awaiting_page)
switcher.active=panel
M.Monitor();assert(M.panel==panel and not M.awaiting_page and not panel.removed)
M.Close();assert(switcher.active==native and panel.removed)
M.Open();assert(switcher.active==panel and M.content:GetChildrenCount()>0)
M.Close();assert(switcher.active==native)
M.main.IsVisible=function()return true end;M.entry=obj('Button');M.entry.parent=M.main
M.Open();local before=M.panel
local close
for _,entry in pairs(M.actions)do if entry.widget.caption=='Close'then close=entry.widget end end
assert(close)
click_hook({get=function()return close end})
assert(M.panel==before and not before.removed,'Click callback destroyed its live native widget')
M.Monitor();assert(M.panel==nil and before.removed,'Deferred click did not close the page')
print('PASS: native callback only queues; next game-thread monitor performs widget replacement')
print('PASS: outgoing page survives delayed native transition and activation settles without premature cleanup')
print('PASS: complete manager Open/render/Close/reopen with slotless asset root and centered native switcher page; viewport overlays forbidden')
return M,F,text,obj
