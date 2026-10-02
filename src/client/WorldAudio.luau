-- Built-in placeholder cues and two bounded continuous voices. Production audio replacement is Config-only.
local SoundService=game:GetService('SoundService')
local RunService=game:GetService('RunService')
local CS=game:GetService('CollectionService')
local Audio={played=0}
function Audio.init(ctx)
 local C=ctx.Config.WorldAudio
 local folder=Instance.new('Folder') folder.Name='BCWorldAudio' folder.Parent=SoundService
 local function sound(id,loop)
  local s=Instance.new('Sound') s.SoundId=id s.Volume=0 s.Looped=loop s.Parent=folder return s
 end
 local rolling=sound(C.Roll,true) local drone=sound(C.Drone,true) local cues={}
 for i=1,C.CuePool do cues[i]=sound(C.Cue,false) end local nextCue=0
 local function cue()
  if ctx.settings.sfx==false then return end
  nextCue=nextCue%#cues+1 local s=cues[nextCue] s.Volume=C.CueVolume s.TimePosition=0 s:Play() Audio.played+=1
 end
 ctx.on('menu',function(name) if name then cue() end end)
 ctx.remotes.GarageEvent.OnClientEvent:Connect(function(kind) if kind=='ack' then cue() end end)
 ctx.remotes.HeistEvent.OnClientEvent:Connect(function(kind,data)
  if kind=='results' or (kind=='action' and data.ok) or (kind=='repair' and data.done) then cue() end
 end)
 local acc=0
 RunService.Heartbeat:Connect(function(dt)
  acc+=dt if acc<C.UpdateSeconds then return end acc=0
  local enabled=ctx.settings.sfx~=false
  local speed=ctx.KartClient and ctx.KartClient.speed or 0
  rolling.Volume=enabled and ctx.driving and C.RollVolume*math.clamp(math.abs(speed)/30,0,1) or 0
  rolling.PlaybackSpeed=.7+math.min(math.abs(speed)/80,.6)
  if rolling.Volume>0 and not rolling.IsPlaying then rolling:Play() elseif rolling.Volume==0 then rolling:Stop() end
  local nearest=math.huge local cam=workspace.CurrentCamera
  for _,m in ipairs(CS:GetTagged('BC_Drone')) do if m.PrimaryPart then nearest=math.min(nearest,(m.PrimaryPart.Position-cam.CFrame.Position).Magnitude) end end
  drone.Volume=enabled and C.DroneVolume*math.clamp(1-nearest/C.Range,0,1) or 0
  if drone.Volume>0 and not drone.IsPlaying then drone:Play() elseif drone.Volume==0 then drone:Stop() end
 end)
 ctx.probe.worldAudio=function() return {played=Audio.played,voices=#folder:GetChildren(),rolling=rolling.Volume,drone=drone.Volume} end
end
return Audio
