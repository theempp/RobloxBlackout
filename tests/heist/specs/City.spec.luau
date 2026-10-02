local RS=game:GetService('ReplicatedStorage')
local C=require(RS.BlackoutCrew.Config)
local R=require(RS.BlackoutCrew.CityRoute)
local Time=require(RS.BlackoutCrew.TimeOfDay)
return function(T)
 local day,on=Time.resolve(12,0,C.City,nil)
 T.eq('day clock',day.ClockTime,12) T.eq('day lamps off',on,false)
 local night,lights=Time.resolve(21,0,C.City,nil)
 T.eq('night lamps',lights,true)
 local wrap=Time.resolve(21,C.City.CycleSeconds,C.City,nil)
 T.near('cycle wraps',wrap.ClockTime,21)
 local dark,darkLights=Time.resolve(12,400,C.City,C.Twists.blackout.lighting)
 T.eq('blackout wins',dark.Brightness,C.Twists.blackout.lighting.Brightness)
 T.eq('blackout lamps off',darkLights,false)
 local restored=Time.resolve(12,400,C.City,nil)
 T.check('blackout removal current cycle',restored.Brightness>dark.Brightness)
 local road=workspace.HeistMap.Oceanside.EscapeRoadCollision
 T.eq('route collision persistent',road.ModelStreamingMode,Enum.ModelStreamingMode.Persistent)
 local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Include ray.FilterDescendantsInstances={road}
 for i=2,#R.Points do
  local p=(R.Points[i]+R.Points[i-1])/2
  T.check('route deck '..i,workspace:Raycast(p+Vector3.new(0,5,0),Vector3.new(0,-10,0),ray)~=nil)
 end
 T.check('route within timer at realistic 35 studs/s',(R.length()+1100)/35<C.Escape.DashTime)
 local nearest,dist=R.nearest(R.Points[5]+Vector3.new(0,2,0))
 T.check('nearest route recovery',dist<=2.01)
 local count=0 for _,v in ipairs(workspace.HeistMap:GetDescendants()) do if v:IsA('Light') and v.Enabled then count+=1 end end
 T.check('active practical light cap',count<=C.City.MaxLights)
 local escape=require(game.ServerScriptService.BlackoutCrew.heist.Escape)
 local gate=require(RS.BlackoutCrew.HeistMap).Gate.pos
 T.eq('cannot escape below elevated gate',escape.inGate(gate-Vector3.new(0,40,0)),false)
 T.eq('safe gate accepts road elevation',escape.inGate(gate+Vector3.new(0,2,0)),true)
 T.eq('preserved parking pool',#require(RS.BlackoutCrew.HeistMap).Spots,15)
 print('BC_ROUTE length',R.length(),'plus-city-1100 at-35',(R.length()+1100)/35)
end
