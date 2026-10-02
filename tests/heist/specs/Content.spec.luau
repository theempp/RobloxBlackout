local RS=game:GetService('ReplicatedStorage')
local S=require(game.ServerScriptService.BlackoutCrew.ServerState)
local C=require(RS.BlackoutCrew.Config)
local M=require(RS.BlackoutCrew.HeistMap)
local Twists=require(RS.BlackoutCrew.Twists)
return function(T)
 T.eq('six twists',#C.Twists.Enabled,6)
 for _,id in ipairs(C.Twists.Enabled) do T.check('twist definition '..id,C.Twists[id]~=nil) end
 local storm=Twists.apply({laserMult=1},C.Twists.laserStorm) T.near('storm raises speed',storm.laserMult,1.6)
 T.eq('short fuse 2x',Twists.apply({alarmMult=1},C.Twists.shortFuse).alarmMult,2)
 T.eq('loud floor gunfire 2x',Twists.apply({},C.Twists.loudFloor).bumpMult.gunfire,2)
 T.eq('glitch reroutes',Twists.apply({},C.Twists.glitchSurge).reroute,true)
 for _,id in ipairs({'A','B','C'}) do
  T.eq('six safe sentry routes '..id,#M.GuardSets[id].sentries,6)
  for _,route in ipairs(M.GuardSets[id].sentries) do for _,p in ipairs(route) do T.check('route inside tower '..id,M.inTower(p)) end end
 end
 local run=S.Heist.run
 T.check('selected wing',table.find({'data','bullion','prototype'},run.wing)~=nil)
 T.check('selected guard set',M.GuardSets[run.guardSet]~=nil)
 local kit=workspace.HeistMap:FindFirstChild('ActiveVaultWing')
 T.check('only active wing kit',kit~=nil and kit.ModelStreamingMode==Enum.ModelStreamingMode.Atomic)
 local k=S.karts.byOwner[T.player]
 local credits=S.profiles.loaded[T.player].credits
 T.eq('skip cannot repair healthy kart',S.karts.skipRepair(T.player,k.model),false)
 T.eq('invalid skip never charges',S.profiles.loaded[T.player].credits,credits)
end
