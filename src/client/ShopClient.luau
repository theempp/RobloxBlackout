-- Garage economy: real owned inventory, forty earned tiers and token odds before any spin.
local Shop={open=false}
local ctx,H,C,panel,list,header,tab='','','',nil,nil,nil,'guns'
local E
local function send(action,id) ctx.remotes.EconomyAction:FireServer(action,id) end
local function button(text,fn)
 local b=H.button(list,'ShopItem',text,48,{Size=UDim2.new(1,-12,0,48),ZIndex=52,TextSize=14})
 b.Activated:Connect(fn) return b
end
function Shop.refresh()
 if not list then return end
 for _,v in ipairs(list:GetChildren()) do if v:IsA('GuiObject') then v:Destroy() end end
 local p=ctx.profile if not p or not p.progress then return end
 header.Text=string.format('%d Credits • %d Glitch Coins • Tier %d/40',p.credits,p.glitchCoins or 0,E.tier(p))
 if tab=='guns' or tab=='attachments' then
  local gun=tab=='guns' local catalog=gun and C.Guns or C.Attachments
  for _,item in ipairs(catalog) do
   local owned=(gun and p.guns.owned or p.attachments.owned)[item.id]
   button(item.name..(owned and ' • OWNED' or (' • '..(item.price or C.Economy.AttachmentPrice)..' Credits')),function() if not owned then send(gun and 'buyGun' or 'buyAttachment',item.id) end end)
  end
 elseif tab=='pass' then
  button('40-tier season • Premium purchasing unavailable in private test',function() end)
  for i=1,40 do
   local claimed=p.progress.claimed['f'..i]
   button('Tier '..i..' • '..(i%5==0 and 'Attachment' or C.Economy.TierCredits..' Credits')..(claimed and ' • CLAIMED' or (i>E.tier(p) and ' • LOCKED' or ' • CLAIM')),function() send('claimFree',tostring(i)) end)
   button('Premium tier '..i..(p.progress.premium and ' • COSMETIC' or ' • LOCKED'),function() send('claimPremium',tostring(i)) end)
  end
 elseif tab=='spin' then
  button('FREE SEASON SPIN '..math.min(5,p.wheel.freeSpins+1)..'/5 • Vortex guaranteed on spin 5',function() send('freeSpin') end)
  button('EARNED TOKEN SPIN • '..p.progress.tokens..' tokens • Epic+ pity '..p.wheel.pity..'/6',function() send('tokenSpin') end)
  button('DETAILS • Live odds below • Paid wheel/crate disabled',function() end)
  for _,x in ipairs(E.odds(p)) do button(string.format('%s • %.2f%%',C.CosmeticsById[x.id].name,x.odds),function() end) end
 else
  button('Bundles 199 / 499 / 999 Robux • unavailable in private test',function() end)
  button('Cosmetic crate • unavailable in private test',function() end)
 end
end
function Shop.set(on)
 if on then ctx.Menus.open('shop',function() Shop.set(false) end) end
 Shop.open=on panel.Visible=on
 if on then Shop.refresh() ctx.Menus.focus(panel:FindFirstChild('ShopClose',true)) else ctx.Menus.closed('shop') end
end
function Shop.init(c)
 ctx=c H=c.Hud C=c.Config E=require(c.shared.Economy)
 local launch=H.button(H.root,'ShopButton','SHOP',60,{Position=UDim2.fromOffset(105,40),TextSize=14})
 launch.Activated:Connect(function() Shop.set(not Shop.open) end)
 panel=H.make('Frame',H.root,{Name='Shop',AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(520,300),BackgroundColor3=C.UI.Paper,Visible=false,ZIndex=50}) H.surface(panel)
 header=H.label(panel,'',14,{Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-80,0,35),ZIndex=51})
 local close=H.button(panel,'ShopClose','BACK',60,{Position=UDim2.new(1,-68,0,0),ZIndex=52}) close.Activated:Connect(function() Shop.set(false) end)
 for i,name in ipairs({'guns','attachments','pass','spin','bundles'}) do
  local b=H.button(panel,'ShopTab_'..name,name:upper(),90,{Position=UDim2.fromOffset(8+(i-1)*100,42),Size=UDim2.fromOffset(96,44),ZIndex=52,TextSize=12})
  b.Activated:Connect(function() tab=name Shop.refresh() end)
 end
 list=H.make('ScrollingFrame',panel,{Position=UDim2.fromOffset(8,92),Size=UDim2.new(1,-16,1,-100),BackgroundTransparency=1,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=5,ZIndex=51})
 H.make('UIListLayout',list,{Padding=UDim.new(0,5)})
 local function layout()
  local w=math.min(520,H.W-16) local h=math.min(300,H.H-16)
  panel.Size=UDim2.fromOffset(w,h)
  for i,name in ipairs({'guns','attachments','pass','spin','bundles'}) do
   local b=panel:FindFirstChild('ShopTab_'..name) b.Size=UDim2.fromOffset((w-16)/5-4,44) b.Position=UDim2.fromOffset(8+(i-1)*(w-16)/5,42)
  end
 end
 ctx.on('rescale',layout) layout()
 ctx.on('profile',Shop.refresh)
 ctx.probe.shop=function(command) if command=='open' then Shop.set(true) elseif command=='close' then Shop.set(false) end return {open=Shop.open,tab=tab,rows=#list:GetChildren(),credits=ctx.profile and ctx.profile.credits} end
 ctx.remotes.EconomyEvent.OnClientEvent:Connect(function(ok,message) H.toast(message,3) Shop.refresh() end)
end
return Shop
