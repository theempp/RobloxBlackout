-- Actual KartPhysics integrator over the built route collision. Desktop simulation, not a phone FPS check.
local RS=game:GetService('ReplicatedStorage')
local C=require(RS.BlackoutCrew.Config)
local KP=require(RS.BlackoutCrew.KartPhysics)
local R=require(RS.BlackoutCrew.CityRoute)
local V=Vector3.new
return function(T)
 local points={V(100,0,-200),V(980,0,-200),V(980,0,0)}
 for i=2,#R.Points do table.insert(points,R.Points[i]) end
 local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Include params.FilterDescendantsInstances={workspace.HeistMap}
 local cast=KP.caster(params) local geo=KP.geo(C.Kart)
 local start=CFrame.lookAt(points[1],points[2])
 local b={cf=KP.restCF(start,C.Kart),v=V(0,0,0),w=V(0,0,0),m=geo.mass,com=geo.com}
 local st=KP.newState() local index=2 local elapsed=0 local minY=100 local maxDist=0
 for f=1,75*60 do
  elapsed=f/60
  local at=b.cf.Position local dest=points[index]
  local flat=Vector3.new(dest.X-at.X,0,dest.Z-at.Z)
  if flat.Magnitude<14 and index<#points then index+=1 dest=points[index] flat=Vector3.new(dest.X-at.X,0,dest.Z-at.Z) end
  if index==#points and flat.Magnitude<16 then break end
  local angle=math.atan2(flat:Dot(b.cf.RightVector),flat:Dot(b.cf.LookVector))
  local speed=math.abs(angle)>.18 and 23 or 44
  local input={t=math.clamp((speed-st.speed)/6,-1,1),s=math.clamp(angle*2.5,-1,1),b=false}
  KP.simulate(b,st,input,1/60,C.Kart,cast,{})
  minY=math.min(minY,b.cf.Position.Y)
 end
 T.check('bridge/uphill route driven within 75s',index==#points and (b.cf.Position-points[#points]).Magnitude<25,'index='..index..' time='..elapsed..' pos='..tostring(b.cf.Position))
 T.check('no water fall',minY>-2,'minY='..minY)
 T.check('final elevation reached',b.cf.Position.Y>46)
 print('BC_ROUTE simulatedDashSeconds',elapsed,'minY',minY,'endpoint',b.cf.Position)
end
