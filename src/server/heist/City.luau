-- Oceanside silhouette/detail outside the preserved tower and parking gameplay core.
local RS=game:GetService('ReplicatedStorage')
local R=require(RS.BlackoutCrew.CityRoute)
local C=require(RS.BlackoutCrew.Config)
local City={lights={}}
local V=Vector3.new
function City.build(parent,box)
 local f=Instance.new('Folder') f.Name='Oceanside' f.Parent=parent
 local road=Instance.new('Model') road.Name='EscapeRoadCollision' road.ModelStreamingMode=Enum.ModelStreamingMode.Persistent road.Parent=f
 local grey=Color3.fromRGB(48,52,57) local pale=Color3.fromRGB(175,182,177)
 local function p(name,size,cf,col,collide)
  return box(f,name,size,cf,col,Enum.Material.SmoothPlastic,{CanCollide=collide==true,CanQuery=collide==true,CastShadow=false})
 end
 -- Non-colliding bay: falling into water is recovered server-side, not a hidden floor.
 p('Bay',V(1150,2,780),V(1520,-9,0),Color3.fromRGB(36,109,126),false)
 p('Ocean',V(2700,2,450),V(700,-9,-570),Color3.fromRGB(43,133,151),false)
 box(f,'Beach',V(1320,2,90),V(390,-1,-285),Color3.fromRGB(196,181,142),Enum.Material.Sand)
 box(road,'CoastRoad',V(1300,1,32),V(390,-.5,-224),grey,Enum.Material.Asphalt)
 box(road,'InnerBoulevard',V(1240,1,34),V(390,-.5,220),grey,Enum.Material.Asphalt)
 local function tree(at,palm)
  p('Trunk',V(1.6,palm and 19 or 14,1.6),at+V(0,palm and 9.5 or 7,0),Color3.fromRGB(83,69,49),false)
  if palm then
   for j=0,3 do p('PalmFrond',V(17,1,3),CFrame.new(at+V(0,19,0))*CFrame.Angles(0,j*math.pi/2,.15),Color3.fromRGB(43,89,60),false) end
  else
   local canopy=p('Canopy',V(27,14,24),at+V(0,18,0),Color3.fromRGB(45,83,60),false) canopy.Shape=Enum.PartType.Ball
  end
 end
 for x=-160,920,120 do
  tree(V(x,0,-264),true) tree(V(x,0,241),true)
  for _,z in ipairs({-205,205}) do
   local at=V(x,0,z)
   p('LampPole',V(.8,21,.8),at+V(0,10.5,0),grey,false)
   local lamp=p('RoadLamp',V(4,.5,2),at+V(0,21,0),pale,false)
   local l=Instance.new('PointLight') l.Brightness=1.2 l.Range=38 l.Shadows=false l.Enabled=false l.Color=Color3.fromRGB(255,222,176) l.Parent=lamp
   table.insert(City.lights,l)
  end
 end
 -- Layered tower row beyond accessible parking alleys; facade bands are matte.
 for x=-100,900,200 do
  for _,z in ipairs({-350,310}) do
   local h=85+((x+100)/200%3)*28
   p('Podium',V(116,12,68),V(x,6,z),pale,false)
   p('Tower',V(76,h,48),V(x,h/2+12,z),Color3.fromRGB(93,116,124),false)
   for y=24,h,18 do p('FacadeBand',V(78,1.2,50),V(x,y,z),pale,false) end
   p('RoofGarden',V(55,2,35),V(x,h+13,z),Color3.fromRGB(58,89,66),false)
  end
 end
 p('HexRoof',V(76,2,88),V(890,81,-115),pale,false)
 p('HexRoofPlant',V(30,2,30),V(890,83,-115),Color3.fromRGB(58,89,66),false)
 local round=p('CircularLandmark',V(120,80,80),CFrame.new(690,60,115)*CFrame.Angles(0,0,math.pi/2),pale,false) round.Shape=Enum.PartType.Cylinder
 for j=0,5 do p('HexHeadquarters',V(56,80,3),CFrame.new(890,40,-115)*CFrame.Angles(0,j*math.pi/3,0)*CFrame.new(0,0,48),Color3.fromRGB(110,123,132),false) end
 -- Harbor stays empty at the oversized reserved berth: no yacht exterior or gameplay.
 p('ReservedBerth',V(280,1,18),V(530,-.5,270),pale,false)
 for x=380,640,65 do p('Pier',V(10,1,65),V(x,-.5,300),pale,false) end
 for i=2,#R.Points do
  local a,b=R.Points[i-1],R.Points[i] local d=b-a local cf=CFrame.lookAt((a+b)/2,(a+b)/2+d)
  box(road,'RouteDeck',V(R.Width,2,d.Magnitude+8),cf*CFrame.new(0,-1,0),grey,Enum.Material.Asphalt)
  for _,side in ipairs({-1,1}) do box(road,'RouteBarrier',V(1.2,3,d.Magnitude+8),cf*CFrame.new(side*(R.Width/2+.6),1.5,0),pale) end
  local pole=cf.Position+cf.RightVector*(R.Width/2+3)
  p('RouteLampPole',V(.8,18,.8),pole+V(0,9,0),grey,false)
  local head=p('RouteRoadLamp',V(3,.5,2),pole+V(0,18,0),pale,false)
  local lamp=Instance.new('PointLight') lamp.Color=Color3.fromRGB(255,222,176) lamp.Range=38 lamp.Brightness=1.2 lamp.Shadows=false lamp.Enabled=false lamp.Parent=head table.insert(City.lights,lamp)
  p('RouteStripe',V(.4,.08,d.Magnitude),cf*CFrame.new(0,.08,0),Color3.fromRGB(220,202,138),false)
  if i<=3 then
   p('BridgePier',V(10,25,12),V((a.X+b.X)/2,-12,0),pale,false)
  else
   for _,side in ipairs({-1,1}) do tree((a+b)/2+V(side*23,0,0),false) end
  end
 end
 box(road,'SafeApron',V(100,2,100),V(2110,47,35),grey)
 p('SafeGarageRoof',V(80,2,65),V(2130,66,35),pale,false)
 p('SafeGarageBack',V(2,18,65),V(2168,57,35),grey,false)
 f:SetAttribute('RouteLength',R.length()) f:SetAttribute('StreetlightCount',#City.lights)
 return f
end
return City
