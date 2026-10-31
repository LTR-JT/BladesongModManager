-- Manager-local folder tab renderer. MIT-derived generic drawing utilities; no Creative UI implementation.
function bmm_tab_rect(state,parent,x,y,w,h,color,angle)
    local rect=bmm_new(state.home,'Border');rect:SetBrushColor(color);rect:SetVisibility(3)
    if state.forge_canvas and parent==state.forge_canvas then
        local list=color.R<.05 and state.forge_faces or state.forge_rules;list[#list+1]=rect
    end
    local slot=parent:AddChildToCanvas(rect);slot:SetPosition({X=x,Y=y});slot:SetSize({X=w,Y=h})
    if angle then rect:SetRenderTransformPivot({X=0,Y=0});rect:SetRenderTransformAngle(angle)end
    return rect,slot
end
function bmm_folder_tab(state,parent,caption,kind,x,definition)
    local width=definition and definition.width or 400
    local canvas=bmm_new(state.home,'CanvasPanel');local slot=parent:AddChildToCanvas(canvas)
    slot:SetPosition({X=x,Y=18});slot:SetSize({X=width,Y=62})
    local bg={R=.008,G=.008,B=.006,A=1};local edge={R=.20,G=.19,B=.13,A=1}
    -- Fill the entire chamfered cap, including the triangles under both slopes.
    for y=0,18,2 do bmm_tab_rect(state,canvas,20-y,y,width-40+2*y,2,bg)end
    local fill,fill_slot=bmm_tab_rect(state,canvas,0,20,width,42,bg)
    bmm_tab_rect(state,canvas,20,0,width-40,2,edge)
    bmm_tab_rect(state,canvas,0,20,29,2,edge,-45)
    bmm_tab_rect(state,canvas,width-20,0,29,2,edge,45)
    local left,left_slot=bmm_tab_rect(state,canvas,0,20,2,42,edge)
    local right,right_slot=bmm_tab_rect(state,canvas,width-2,20,2,42,edge)
    local bottom,bottom_slot=bmm_tab_rect(state,canvas,0,60,width,2,edge)
    local button,visual=bmm_visual_action(state,caption,kind,definition and {tab_id=definition.id}or nil)
    state.action_visuals[button:GetAddress()].folder_tab=true
    local button_slot=canvas:AddChildToCanvas(visual);button_slot:SetPosition({X=0,Y=0});button_slot:SetSize({X=width,Y=62})
    state.folder_tabs[#state.folder_tabs+1]={kind=kind,id=definition and definition.id,width=width,x=x,slot=slot,fill=fill_slot,left=left_slot,right=right_slot,bottom=bottom,bottom_slot=bottom_slot,button=button,button_slot=button_slot}
    return button
end
function bmm_update_folder_tabs(state)
    local active=(not state.open or state.view=='delete')and 'home_close'or 'home_libraries'
    for _,tab in ipairs(state.folder_tabs or {})do
        local selected=tab.id and BMM_TABS.is_active(tab.id,state)or(not tab.id and tab.kind==active)
        local hovered=is_valid(tab.button)and tab.button:IsHovered()
        local height=selected and 80 or(hovered and 64 or 54);local width=tab.width or 400
        if state.tab_opacity_dirty or tab.drawn_height~=height or tab.drawn_selected~=selected then
            tab.drawn_height=height;tab.drawn_selected=selected
            tab.slot:SetPosition({X=tab.x or(tab.kind=='home_close'and 0 or(tab.kind=='home_libraries'and 400 or 800)),Y=80-height})
            tab.slot:SetSize({X=width,Y=height})
            tab.fill:SetSize({X=width,Y=height-18});tab.left:SetSize({X=2,Y=height-20});tab.right:SetSize({X=2,Y=height-20})
            tab.bottom_slot:SetPosition({X=0,Y=height-2});tab.bottom:SetVisibility(selected and 1 or 3)
            tab.button_slot:SetPosition({X=0,Y=0});tab.button_slot:SetSize({X=width,Y=height})
            bmm_action_opacity(state,tab.button,selected and 1 or(hovered and .70 or .40))
        end
    end
    state.tab_opacity_dirty=false
end

function bmm_visual_action(state,caption,kind,extra)
    local button=bmm_button(state,nil,'',kind,extra);button:SetStyle(bmm_transparent_style());bmm_remove_native_chrome(button);button:SetRenderOpacity(.001);button:SetMinDimensions(0,44);button:SetToolTipText(bmm_to_text(''))
    local visual=bmm_new(state.home,'Overlay')
    local hit=visual:AddChildToOverlay(button);hit:SetHorizontalAlignment(0);hit:SetVerticalAlignment(0)
    local label=bmm_label(state.home,caption,24,false);label:SetAutoWrapText(false);label:SetJustification(1);label:SetVisibility(3)
    local text=visual:AddChildToOverlay(label);text:SetHorizontalAlignment(2);text:SetVerticalAlignment(2)
    state.action_visuals=state.action_visuals or {};state.action_visuals[button:GetAddress()]={widget=visual,label=label,button=button,rest_opacity=.55}
    label:SetRenderOpacity(.55)
    return button,visual
end
function bmm_action_opacity(state,button,opacity)
    local visual=state.action_visuals and state.action_visuals[button:GetAddress()]
    if visual then button:SetRenderOpacity(.001);visual.rest_opacity=opacity;visual.hover_opacity=nil;visual.label:SetRenderOpacity(opacity)else button:SetRenderOpacity(opacity)end
end
return {tab=bmm_folder_tab,update=bmm_update_folder_tabs}
