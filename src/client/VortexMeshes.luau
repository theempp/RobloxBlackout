-- Cached articulated mesh groups preserve all approved named pieces, reused across karts. Local curved art;
-- replicated carriers retain every motor/pivot and physical interaction. No upload or per-kart mesh allocation.
local CS=game:GetService('CollectionService')
local AS=game:GetService('AssetService')
local RS=game:GetService('ReplicatedStorage')
local Data=require(RS.BlackoutCrew.VortexArt)
local Config=require(RS.BlackoutCrew.Config)
local M={status='loading',templates={}}
local attached=setmetatable({},{__mode='k'})
local live={}
local groups={}
local function groupName(spec)
 local n=spec.name
 local suffix=n:match('_([FR][LR])')
 if suffix and (n:match('^Wheel_') or n:match('^Rim_') or n:match('^BrakeDisc_') or n:match('^Hub_')) then return 'Wheel_'..suffix,'Wheel_'..suffix end
 if n:match('^Steer') then return 'Steer','Steer' end
 local side=n:match('^Door_([LR])_')
 local led=n:match('^NoseRail_') or n:match('^Headlight_') or n:match('^IntakeRim_') or n:match('^Door_[LR]_Rim$') or n:match('^TailLED_') or n=='WingLED' or n=='DashScreen'
 if led then return side and 'Door_'..side..'_LED' or 'Body_LED',side and 'Door_'..side..'_Shell' or 'Chassis' end
 local glass=n:find('Glass') or n=='Windshield'
 if side then return 'Door_'..side..(glass and '_GlassGroup' or '_OpaqueGroup'),'Door_'..side..'_Shell' end
 return glass and 'FixedGlass' or 'Body','Chassis'
end
for _,spec in ipairs(Data.pieces) do
 local key,host=groupName(spec)
 groups[key]=groups[key] or {name=key,host=host,pieces={},glass=key:find('Glass')~=nil}
 table.insert(groups[key].pieces,spec)
end
local function install(model)
 if attached[model] or not model.Parent or model:GetAttribute('Visual')~='vortex' then return end
 attached[model]=true
 local root=model.PrimaryPart if not root then return end
 local frame=root.CFrame*CFrame.new(-Config.Kart.Geo.Collider.Center)
 local folder=Instance.new('Folder') folder.Name='ApprovedCurvedArt' folder.Parent=model
 for key,group in pairs(groups) do
  local host=model:FindFirstChild(group.host)
  local template=M.templates[key]
  if host and template then
   local mp=template:Clone() mp.Name=key..'_Art'
   if mp:GetAttribute('VortexLED') then mp.Color=model:GetAttribute('LightsOn')~=false and Color3.fromRGB(243,248,255) or Color3.fromRGB(23,25,28) end
   mp.CFrame=frame*CFrame.new(group.center)
   local weld=Instance.new('Weld') weld.Part0=host weld.Part1=mp weld.C0=host.CFrame:ToObjectSpace(mp.CFrame) weld.Parent=mp
   mp.Parent=folder
  end
 end
 for _,spec in ipairs(Data.pieces) do local host=model:FindFirstChild(spec.name) if host then host.LocalTransparencyModifier=1 end end
 model:SetAttribute('LocalArt','approved-curved')
end
function M.init(ctx)
 task.spawn(function()
  local ok,err=pcall(function()
   for key,group in pairs(groups) do
    local em=AS:CreateEditableMesh() assert(em,'device mesh memory budget') table.insert(live,em)
    local lo,hi=Vector3.one*math.huge,-Vector3.one*math.huge
    for _,spec in ipairs(group.pieces) do for _,v in ipairs(spec.vertices) do local p=v+spec.center lo=lo:Min(p) hi=hi:Max(p) end end
    group.center=(lo+hi)/2
    for _,spec in ipairs(group.pieces) do
     local ids={} local color=em:AddColor(spec.color,1)
     for i,v in ipairs(spec.vertices) do ids[i]=em:AddVertex(v+spec.center-group.center) end
     if spec.name~='Chassis' then
      for _,t in ipairs(spec.faces) do local face=em:AddTriangle(ids[t[1]],ids[t[2]],ids[t[3]]) em:SetFaceColors(face,{color,color,color}) end
     end
    end
    local fixed=AS:CreateEditableMeshAsync(Content.fromObject(em),{FixedSize=true})
    assert(fixed,'fixed mesh memory budget')
    em:Destroy() live[#live]=fixed
    local mp=AS:CreateMeshPartAsync(Content.fromObject(fixed),{CollisionFidelity=Enum.CollisionFidelity.Box})
    mp.Color=Color3.new(1,1,1) mp.Material=Enum.Material.SmoothPlastic
    if key:match('_LED$') then mp:SetAttribute('VortexLED',true) end
    mp.Transparency=group.glass and .55 or 0
    mp.Anchored=false mp.Massless=true mp.CanCollide=false mp.CanTouch=false mp.CanQuery=false mp.CastShadow=false
    M.templates[key]=mp
   end
  end)
  if not ok then
   M.status='fallback: '..tostring(err)
   for _,mp in pairs(M.templates) do mp:Destroy() end table.clear(M.templates)
   for _,em in ipairs(live) do em:Destroy() end table.clear(live)
   warn('BC_WARN Vortex curved art unavailable: '..tostring(err)) return
  end
  M.status='mesh'
  for _,m in ipairs(CS:GetTagged('BC_KartVisual')) do install(m) end
  CS:GetInstanceAddedSignal('BC_KartVisual'):Connect(function(m) task.defer(install,m) end)
 end)
 ctx.probe=ctx.probe or {} ctx.probe.vortexArt=function() return {status=M.status,tris=Data.tris,pieces=#Data.pieces} end
 ctx.probe.vortexLights=function(model)
  local groups,lit=0,0
  local art=model:FindFirstChild('ApprovedCurvedArt')
  if art then for _,p in ipairs(art:GetChildren()) do if p:GetAttribute('VortexLED') then groups+=1 if p.Color.R>.8 then lit+=1 end end end end
  return {groups=groups,lit=lit}
 end
 ctx.probe.vortexMeasure=function(model)
  local cam=workspace.CurrentCamera local savedCF,savedType=cam.CFrame,cam.CameraType
  cam.CameraType=Enum.CameraType.Scriptable
  cam.CFrame=CFrame.lookAt(model.PrimaryPart.Position+Vector3.new(12,7,-15),model.PrimaryPart.Position)
  local art=model:WaitForChild('ApprovedCurvedArt',5) if not art then return {parts=0,tris=0} end
  local stats=game:GetService('Stats') local run=game:GetService('RunService')
  for i=1,8 do run.RenderStepped:Wait() end local shown=stats.SceneTriangleCount
  local parts=art:GetChildren()
  for _,p in ipairs(parts) do p.LocalTransparencyModifier=1 end
  for i=1,8 do run.RenderStepped:Wait() end local hidden=stats.SceneTriangleCount
  for _,p in ipairs(parts) do p.LocalTransparencyModifier=0 end
  cam.CFrame=savedCF cam.CameraType=savedType
  return {parts=#Data.pieces,groups=#parts,tris=shown-hidden}
 end
end
return M
