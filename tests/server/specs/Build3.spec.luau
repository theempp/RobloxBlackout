local RS=game:GetService('ReplicatedStorage')
local SSS=game:GetService('ServerScriptService')
local E=require(RS.BlackoutCrew.Economy)
local Rules=require(RS.BlackoutCrew.Rules)
local C=require(RS.BlackoutCrew.Config)
local Service=require(SSS.BlackoutCrew.EconomyService)
local Crews=require(RS.BlackoutCrew.Crews)
local Queue=require(RS.BlackoutCrew.Queue)
return function(T)
 local player=T.player
 local okShop,shop=T.cmd('eval','shop','open')
 T.check('shop client opens',okShop and shop.open==true)
 local okAudio,audio=T.cmd('eval','worldAudio')
 T.check('audio voices bounded',okAudio and audio.voices==6)
 T.cmd('eval','shop','close')
 local _,closed=T.cmd('eval','shop') T.check('shop closes cleanly',closed.open==false)
 local oldPad,oldDriving=player:GetAttribute('BC_Pad'),player:GetAttribute('BC_Driving')
 player:SetAttribute('BC_Pad',nil) player:SetAttribute('BC_Driving',false)
 local d=Rules.defaultProfile() d.credits=1000
 local fake={role='lobby',profiles={loaded={[player]=d}},pushProfile=function() end}
 function fake.profiles:save() return false end
 local ok=Service.transact(fake,player,'buyGun','A2')
 T.eq('failed save denies transaction',ok,false)
 T.check('failed purchase restores ownership and credits',not fake.profiles.loaded[player].guns.owned.A2 and fake.profiles.loaded[player].credits==1000)
 function fake.profiles:save() return true end
 T.eq('retry succeeds',Service.transact(fake,player,'buyGun','A2'),true)
 T.eq('duplicate request never debits twice',Service.transact(fake,player,'buyGun','A2'),false)
 player:SetAttribute('BC_Pad','A') T.eq('no shop while queueing',Service.transact(fake,player,'freeSpin'),false)
 player:SetAttribute('BC_Pad',oldPad) player:SetAttribute('BC_Driving',oldDriving)
 local crews=Crews.new(4,20) local a,b={},{}
 T.eq('walk up invitation',crews:invite(a,b,0),true) T.eq('consent acceptance',crews:accept(b,1),true)
 local pad=Queue.new('A',C.Lobby,crews)
 T.eq('invited leader can queue',pad:join(a,2),true)
 T.eq('invited mate can queue',pad:join(b,2),true)
 T.eq('crew remains together',crews:size(a),2)
 local KP=require(RS.BlackoutCrew.KartPhysics)
 local model=Instance.new('Model') model:SetAttribute('KartTier','vortex') local top=KP.forModel(model,C.Kart)
 T.check('top kart fixed spread within 15 percent',top.MaxSpeed>C.Kart.MaxSpeed and top.MaxSpeed<=C.Kart.MaxSpeed*1.15 and top.Accel<=C.Kart.Accel*1.15)
 model:Destroy()
 local old=Rules.defaultProfile() old.schemaVersion=4 old.credits=42 old.receipts.saved=true
 local migrated=Rules.clean(old)
 T.check('schema 4 retained',migrated.credits==42 and migrated.receipts.saved and migrated.progress.xp==0)
 for i=1,40 do
  migrated.progress.xp=10000
  T.eq('free track tier '..i,E.act(migrated,'claimFree',tostring(i),0),true)
 end
 local clean=Rules.clean(migrated) T.eq('all tier claims survive migration',clean.progress.claimed.f40,true)
 local social=require(SSS.BlackoutCrew.Social)
 T.eq('self invite rejected',social.action(player,'invite',player.UserId),false)
 T.eq('unavailable target rejected',social.action(player,'invite',-987654),false)
 T.eq('no production paid ids',#C.Products,0)
 T.eq('policy absent fails closed',E.paidAllowed(nil),false)
 T.eq('restricted policy fails closed',E.paidAllowed({ArePaidRandomItemsRestricted=true}),false)
 T.eq('kill switch overrides permissive policy',E.paidAllowed({ArePaidRandomItemsRestricted=false}),false)
 local receipts=require(SSS.BlackoutCrew.Receipts)
 local data=Rules.defaultProfile() local saveOK=false
 local profiles={loaded={[player]=data}} function profiles:save() return saveOK end
 local handle=receipts.handler({products={{id=7123,kind='premium'}},profiles=profiles,getPlayer=function() return player end,grant=E.receiptGrant})
 local info={PlayerId=player.UserId,ProductId=7123,PurchaseId='test-pass'}
 T.eq('premium failed save waits',handle(info),Enum.ProductPurchaseDecision.NotProcessedYet)
 T.eq('premium rollback',data.progress.premium,false)
 saveOK=true T.eq('premium receipt',handle(info),Enum.ProductPurchaseDecision.PurchaseGranted)
 T.eq('premium no credit power',data.credits,0)
 T.eq('premium retry idempotent',handle(info),Enum.ProductPurchaseDecision.PurchaseGranted)
 T.eq('receipt entitlement persisted',data.progress.premium,true)
end
