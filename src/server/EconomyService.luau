-- Serial purchase transaction per player. Save before acknowledgement; failed save restores snapshot.
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Policy=game:GetService('PolicyService')
local E=require(RS.BlackoutCrew.Economy)
local Rules=require(RS.BlackoutCrew.Rules)
local Service={busy={},policy={}}
function Service.transact(S,p,action,id)
 if Service.busy[p] then return false,'Please wait' end
 local d=S.profiles.loaded[p]
 if not d or S.role~='lobby' or p:GetAttribute('BC_Driving') or p:GetAttribute('BC_Pad') then return false,'Use the shop in the garage before queueing' end
 Service.busy[p]=true
 local before=Rules.clean(d)
 local ok,message=E.act(d,action,id,Random.new():NextNumber())
 if ok and not S.profiles:save(p,false) then S.profiles.loaded[p]=before ok=false message='Save failed; purchase reversed' end
 Service.busy[p]=nil
 local current=S.profiles.loaded[p]
 local kart=S.GarageKarts and S.GarageKarts.byOwner[p]
 if ok and current and current.karts.owned.vortex and kart then kart.model:SetAttribute('KartTier','vortex') end
 S.pushProfile(p)
 return ok,message
end
function Service.init(S)
 S.Economy=Service
 S.Remotes.bind(S.remotes,'EconomyAction',function(p,action,id)
  local ok,message=Service.transact(S,p,action,id) S.remotes.EconomyEvent:FireClient(p,ok,message)
 end)
 table.insert(S.onJoin,function(p)
  -- Missing policy is restricted. No paid random request is exposed while the kill switch/IDs are off.
  local ok,policy=pcall(Policy.GetPolicyInfoForPlayerAsync,Policy,p)
  Service.policy[p]=ok and type(policy)=='table' and policy.ArePaidRandomItemsRestricted==false or false
 end)
 Players.PlayerRemoving:Connect(function(p) Service.busy[p]=nil Service.policy[p]=nil end)
end
return Service
