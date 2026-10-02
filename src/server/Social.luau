-- Walk-up, consent-based invites using the existing lobby crew service. Session mute/block + cooldown.
local Players=game:GetService('Players')
local Social={blocked={},muted={},last={}}
local S
function Social.action(p,action,id)
 local other=type(id)=='number' and Players:GetPlayerByUserId(id)
 if action=='accept' then
  local inv=S.Lobby.crews.invites[p] local from=inv and inv.from
  if not from or p:GetAttribute('BC_Pad') or from:GetAttribute('BC_Pad')
   or (Social.blocked[p] and Social.blocked[p][from]) or (Social.blocked[from] and Social.blocked[from][p]) then return false,'Invite unavailable' end
  return S.Lobby.crews:accept(p,os.clock())
 end
 if action=='decline' then S.Lobby.crews.invites[p]=nil return true end
 if action=='leave' then if p:GetAttribute('BC_Pad') then return false,'Step off queue first' end S.Lobby.crews:leave(p) return true end
 if not other or other==p then return false,'Player unavailable' end
 if action=='block' or action=='mute' then
  local map=action=='block' and Social.blocked or Social.muted map[p]=map[p] or {} map[p][other]=not map[p][other]
  S.Lobby.crews.invites[p]=nil return true
 end
 if action~='invite' then return false,'Unknown action' end
 if (Social.blocked[other] and Social.blocked[other][p]) or (Social.muted[other] and Social.muted[other][p]) or (Social.blocked[p] and Social.blocked[p][other]) then return false,'Invites unavailable' end
 if p:GetAttribute('BC_Pad') or other:GetAttribute('BC_Pad') then return false,'Invite before queueing' end
 local a=p.Character and p.Character:FindFirstChild('HumanoidRootPart') local b=other.Character and other.Character:FindFirstChild('HumanoidRootPart')
 if not a or not b or (a.Position-b.Position).Magnitude>18 then return false,'Walk closer to invite' end
 if os.clock()-(Social.last[p] or -100)<5 then return false,'Invite cooldown' end
 Social.last[p]=os.clock()
 local ok,why=S.Lobby.crews:invite(p,other,os.clock())
 if ok then S.remotes.SocialEvent:FireClient(other,'invite',p.UserId,p.DisplayName) end return ok,why
end
function Social.init(s)
 S=s S.Social=Social
 S.Remotes.bind(S.remotes,'SocialAction',function(p,action,id)
  local ok,msg=Social.action(p,action,id) S.remotes.SocialEvent:FireClient(p,'result',ok,msg or (ok and 'Squad updated' or 'Invite unavailable'))
 end)
 Players.PlayerRemoving:Connect(function(p)
  Social.blocked[p]=nil Social.muted[p]=nil Social.last[p]=nil
  for _,map in ipairs({Social.blocked,Social.muted}) do for _,set in pairs(map) do set[p]=nil end end
 end)
end
return Social
