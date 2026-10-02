-- Single server Lighting writer for the cycle and twist precedence.
local Lighting=game:GetService('Lighting')
local Players=game:GetService('Players')
local shared=game:GetService('ReplicatedStorage'):WaitForChild('BlackoutCrew')
local Config=require(shared.Config)
local Time=require(shared.TimeOfDay)
local Twists=require(shared.Twists)
local City=require(script.Parent.City)
local Twist={}
local S,run,startHour,elapsed,acc=nil,nil,12,0,0
function Twist.init(s) S=s end
function Twist.update()
 local def=run and run.twist and Config.Twists[run.twist]
 local values,night=Time.resolve(startHour,elapsed,Config.City,def and def.lighting)
 for k,v in pairs(values) do Lighting[k]=v end
 -- At most the nearest six lamps across all players. No per-frame lighting scan.
 local candidates={}
 for _,l in ipairs(City.lights) do
  l.Enabled=false
  if night then
   local distance=math.huge
   for _,p in ipairs(Players:GetPlayers()) do
    local root=p.Character and p.Character:FindFirstChild('HumanoidRootPart')
    if root then distance=math.min(distance,(root.Position-l.Parent.Position).Magnitude) end
   end
   if distance<Config.City.LightRange then table.insert(candidates,{light=l,d=distance}) end
  end
 end
 table.sort(candidates,function(a,b) return a.d<b.d end)
 for i=1,math.min(#candidates,Config.City.MaxLights) do candidates[i].light.Enabled=true end
 if workspace:FindFirstChild('HeistState') then workspace.HeistState:SetAttribute('CityHour',values.ClockTime) end
end
function Twist.start(_,r)
 run=r elapsed=0 acc=0
 startHour=Config.City.StartHours[Random.new(Twists.seed(r.info.runId..'day')):NextInteger(1,#Config.City.StartHours)]
 local def=r.twist and Config.Twists[r.twist]
 workspace.HeistState:SetAttribute('Twist',def and def.name or '')
 Twist.update()
 for _,p in ipairs(r.players) do if def then S.notify(p,'TWIST: '..def.name) end end
end
function Twist.tick(_,_,dt)
 elapsed+=dt acc+=dt if acc>=Config.City.UpdateSeconds then acc=0 Twist.update() end
end
function Twist.reset() run=nil Twist.update() end
return Twist
