local TEST_ROOT=os.getenv('BMF_TEST_ROOT')or 'BladesongModdingPlatform'
local nextid=0
local function object(t)t=t or {};nextid=nextid+1;t.id=nextid;function t:IsValid()return true end;function t:GetAddress()return self.id end;return t end
local wrapClass=object()
local function slot()
 local s=object({Padding={Left=4,Top=5,Right=6,Bottom=7},HorizontalAlignment=0,VerticalAlignment=2,bFillEmptySpace=true,bForceNewLine=true,FillSpanWhenLessThan=500})
 function s:SetPadding(v)self.Padding=v end
 function s:SetHorizontalAlignment(v)self.HorizontalAlignment=v end
 function s:SetVerticalAlignment(v)self.VerticalAlignment=v end
 function s:SetFillEmptySpace(v)self.bFillEmptySpace=v end
 function s:SetNewLine(v)self.bForceNewLine=v end
 function s:SetFillSpanWhenLessThan(v)self.FillSpanWhenLessThan=v end
 return s
end
local parent=object({children={}})
function parent:IsA(c)return c==wrapClass end
function parent:GetChildrenCount()return #self.children end
function parent:GetChildAt(i)return self.children[i+1]end
function parent:GetChildIndex(w)for i,c in ipairs(self.children)do if c==w then return i-1 end end;return -1 end
function parent:AddChildToWrapBox(w)self.children[#self.children+1]=w;w.parent=self;w.Slot=slot();return w.Slot end
local template=object();local style=object();function style:GetClass()return style end
local function btn(name)
 local b=object({name=name,Caption=name,MinWidth=800,MinHeight=120})
 function b:GetParent()return self.parent end
 function b:RemoveFromParent()local i=self.parent:GetChildIndex(self);table.remove(self.parent.children,i+1);self.parent=nil end
 function b:GetClass()return template end
 function b:GetStyle()return style end
 function b:IsA(c)return c==template end
 function b:SetVisibility(value)self.visibility=value end
 function b:SetStyle()end;function b:SetCaption(c)self.name=c end
 function b:SetMinDimensions(w,h)self.MinWidth=w;self.MinHeight=h end
 function b:SetToolTipText()end
 return b
end
local original={}
for _,name in ipairs({'Continue','New','Load','Creative','Options','Credits','Quit'})do local b=btn(name);parent:AddChildToWrapBox(b);original[#original+1]=b end
local main=object({QuitButton=original[7],OptionsButton=original[5],visible=true})
function main:IsVisible()return self.visible end;function main:GetOwningPlayer()end
local library=object();local created=0
function library:Create(context,class)assert(class==template);created=created+1;return btn('')end
function StaticFindObject(path)
 if path=='/Script/UMG.WrapBox'then return wrapClass end
 if path=='/Script/UMG.Default__WidgetBlueprintLibrary'then return library end
 if path=='/Script/Engine.Default__KismetTextLibrary'then local o=object();function o:Conv_StringToText(t)return t end;return o end
end
function RegisterHook()end
function FindAllOf(name)assert(name=='WBP_MainMenu_C');return {main}end
local F={_valid=function(o)return type(o)=='table'and o.IsValid end,errors={}}
local M=assert(loadfile(TEST_ROOT..'/Manager/BladesongModManager/Scripts/manager.lua'))(F,TEST_ROOT..'/Manager/BladesongModManager/Scripts/',TEST_ROOT..'/Manager/BladesongModManager/Scripts/')
M.Monitor()
assert(#parent.children==8 and parent.children[5]==M.entry and parent.children[6]==original[5])
assert(M.entry.MinWidth==800 and M.entry.MinHeight==120)
assert(M.entry.Slot.Padding.Top==5 and M.entry.Slot.bForceNewLine and M.entry.Slot.bFillEmptySpace)
for i=1,4 do assert(parent.children[i]==original[i])end
for i=5,7 do assert(parent.children[i+1]==original[i] and original[i].Slot.Padding.Bottom==7)end
M.Monitor();main.visible=false;M.Monitor();main.visible=true;M.Monitor();assert(created==1 and #parent.children==8)
print('PASS: Mods inserted immediately before Options; native size/slot styling and original widget identity preserved; no duplicate on reopen')

local switcher=object({active=original[1]})
function switcher:GetActiveWidget()return self.active end
function switcher:IsCurrentlySwitching()return false end
function switcher:IsTransitionPlaying()return false end
function switcher:SetActiveWidget(w)self.active=w end
local panel=object();function panel:RemoveFromParent()self.removed=true end
M.panel=panel;M.switcher=switcher;M.previous_page=original[1];switcher.active=panel
M.Close();assert(switcher.active==original[1]and panel.removed and M.content==nil and M.tabs==nil)
local panel2=object();function panel2:RemoveFromParent()self.removed=true end
M.panel=panel2;M.switcher=switcher;M.previous_page=original[1];switcher.active=original[2]
M.Monitor();assert(switcher.active==original[2]and panel2.removed and M.panel==nil)
assert(M.actions[M.entry:GetAddress()])
print('PASS: Close restores native page; native Back/navigation cleans up without overriding destination; entry remains clickable')

F.LegacyCombinedMenu=function()return true end
local active_entry=M.entry
local legacy=btn('Mods');parent:AddChildToWrapBox(legacy);M.Monitor()
assert(legacy.visibility==1 and legacy:GetParent()==parent,'Legacy combined-manager button was not safely collapsed')
assert(M.entry==active_entry and M.entry~=legacy)
print('PASS: standalone manager supersedes the legacy combined Mods button without destroying its widget')
