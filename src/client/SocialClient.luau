local Players=game:GetService('Players')
local Social={}
function Social.init(ctx)
 local H=ctx.Hud local panel=H.make('ScrollingFrame',H.root,{Name='Social',Size=UDim2.fromOffset(440,280),AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Visible=false,BackgroundColor3=ctx.Config.UI.Paper,ZIndex=55,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new()}) H.surface(panel)
 H.make('UIListLayout',panel,{Padding=UDim.new(0,6)})
 local function close() panel.Visible=false ctx.Menus.closed('social') end
 local function row(text,fn) local b=H.button(panel,'SocialAction',text,60,{Size=UDim2.new(1,-12,0,48),ZIndex=56,TextSize=14}) b.Activated:Connect(fn) end
 local function send(action,id) ctx.remotes.SocialAction:FireServer(action,id) end
 local function reset() for _,v in ipairs(panel:GetChildren()) do if v:IsA('GuiObject') then v:Destroy() end end row('BACK',close) end
 -- Opened by the lobby HUD FRIENDS button and the squad "+" slots (LobbyHud).
 function Social.open()
  ctx.Menus.open('social',close) panel.Visible=true reset() row('Leave squad',function() send('leave') end)
  for _,p in ipairs(Players:GetPlayers()) do if p~=ctx.player then
   row('Invite '..p.DisplayName..' (walk within 18 studs)',function() send('invite',p.UserId) end)
   row('Mute invites / unmute • '..p.DisplayName,function() send('mute',p.UserId) end)
   row('Block invites / unblock • '..p.DisplayName,function() send('block',p.UserId) end)
  end end
 end
 ctx.remotes.SocialEvent.OnClientEvent:Connect(function(kind,a,b)
  if kind=='invite' then
   if ctx.player:GetAttribute('BC_Tutorial')~='done' or ctx.player:GetAttribute('BC_Pad') then send('decline') return end
   ctx.Menus.open('social',close) panel.Visible=true reset()
   row(b..' invited you',function() end) row('ACCEPT',function() send('accept') close() end) row('DECLINE',function() send('decline') close() end)
  else H.toast(b or 'Squad updated',3) end
 end)
end
return Social
