-- Pure authoritative operations. No client-selected prices/rewards/rolls. Paid products stay disabled.
local C=require(script.Parent.Config)
local E={}
function E.clean(raw)
 raw=type(raw)=='table' and raw or {}
 local function n(x,cap) return type(x)=='number' and x==x and math.clamp(math.floor(x),0,cap) or 0 end
 local out={xp=n(raw.xp,400000),premium=raw.premium==true,tokens=n(raw.tokens,1000),claimed={},paidOwned={},heli=raw.heli==true}
 for k,v in pairs(type(raw.claimed)=='table' and raw.claimed or {}) do if type(k)=='string' and k:match('^[fp]%d+$') and tonumber(k:sub(2))>=1 and tonumber(k:sub(2))<=40 and v==true then out.claimed[k]=true end end
 for k,v in pairs(type(raw.paidOwned)=='table' and raw.paidOwned or {}) do if type(k)=='string' and C.CosmeticsById[k] and v==true then out.paidOwned[k]=true end end
 return out
end
function E.tier(d) return math.min(40,math.floor(d.progress.xp/C.Economy.XpPerTier)) end
function E.reward(d,tier,premium)
 if premium then
  local list=C.Economy.SpinItems local id=list[(tier-1)%#list+1].id
  d.cosmetics.owned[id]=true return 'Cosmetic: '..C.CosmeticsById[id].name
 end
 if tier%5==0 then
  local a=C.Attachments[((tier/5-1)%#C.Attachments)+1]
  d.attachments.owned[a.id]=true return 'Attachment: '..a.name
 end
 d.credits=math.min(C.Profile.MaxCurrency,d.credits+C.Economy.TierCredits) return tostring(C.Economy.TierCredits)..' Credits'
end
function E.odds(d)
 local candidates,total={},0
 local pity=d.wheel.pity>=5
 for _,x in ipairs(C.Economy.SpinItems) do
  if not d.progress.paidOwned[x.id] and (not pity or x.rank>=3) then total+=x.weight table.insert(candidates,x) end
 end
 -- When all Epic+ items are owned, pity cannot manufacture a duplicate; remaining items renormalize.
 if #candidates==0 and pity then
  for _,x in ipairs(C.Economy.SpinItems) do if not d.progress.paidOwned[x.id] then total+=x.weight table.insert(candidates,x) end end
 end
 local out={} for _,x in ipairs(candidates) do table.insert(out,{id=x.id,odds=x.weight/total*100,rank=x.rank}) end return out
end
function E.act(d,action,id,roll)
 if action=='buyGun' or action=='buyAttachment' then
  local gun=action=='buyGun' local item=gun and C.GunsById[id] or C.AttachmentsById[id]
  if not item then return false,'Unknown item' end
  local owned=gun and d.guns.owned or d.attachments.owned
  if owned[id] then return false,'Already owned' end
  local price=item.price or C.Economy.AttachmentPrice
  if d.credits<price then return false,'Need '..price..' Credits' end
  d.credits-=price owned[id]=true return true,'Unlocked '..item.name
 elseif action=='claimFree' or action=='claimPremium' then
  local tier=tonumber(id) local premium=action=='claimPremium'
  if not tier or tier%1~=0 or tier<1 or tier>E.tier(d) or (premium and not d.progress.premium) then return false,'Tier locked' end
  local key=(premium and 'p' or 'f')..tier
  if d.progress.claimed[key] then return false,'Already claimed' end
  d.progress.claimed[key]=true return true,E.reward(d,tier,premium)
 elseif action=='freeSpin' then
  if d.wheel.freeSpins>=5 then return false,'Season spins used' end
  d.wheel.freeSpins+=1
  if d.wheel.freeSpins==5 then d.karts.owned.vortex=true d.progress.heli=true return true,'Vortex unlocked + future heli entitlement' end
  local a=C.Attachments[(d.wheel.freeSpins-1)%#C.Attachments+1] d.attachments.owned[a.id]=true return true,'Unlocked '..a.name
 elseif action=='tokenSpin' then
  if d.progress.tokens<1 then return false,'Earn a token by completing a heist' end
  local odds=E.odds(d) if #odds==0 then return false,'Collection complete' end
  local value=math.clamp(roll or 0,0,.999999)*100 local sum=0 local chosen=odds[#odds]
  for _,x in ipairs(odds) do sum+=x.odds if value<sum then chosen=x break end end
  d.progress.tokens-=1 d.wheel.pity=chosen.rank>=3 and 0 or d.wheel.pity+1
  d.progress.paidOwned[chosen.id]=true d.cosmetics.owned[chosen.id]=true return true,'Unlocked '..C.CosmeticsById[chosen.id].name
 end
 return false,'Unavailable in private test'
end
-- Config-selected receipt grants; premium never grants Credits, guns or repair power.
function E.receiptGrant(d,product)
 if product.kind=='premium' then d.progress.premium=true return true
 elseif product.kind=='glitchCoins' and type(product.amount)=='number' and product.amount>0 then
  d.glitchCoins=math.min(C.Profile.MaxCurrency,d.glitchCoins+product.amount) return true
 elseif product.kind=='cosmetics' then
  for _,id in ipairs(product.items or {}) do if not C.CosmeticsById[id] then return false end end
  for _,id in ipairs(product.items or {}) do d.cosmetics.owned[id]=true end return true
 end
 return false
end
function E.paidAllowed(policy)
 return C.Economy.PaidRandomEnabled and type(policy)=='table' and policy.ArePaidRandomItemsRestricted==false
end
function E.runReward(d,success)
 d.progress.xp=math.min(400000,d.progress.xp+(success and C.Economy.RunXp or C.Economy.FailXp))
 if success then d.progress.tokens=math.min(1000,d.progress.tokens+1) end
end
return E
