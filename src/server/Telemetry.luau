-- Local alpha counters. No outbound custom analytics or persistent per-person event trail.
local Players=game:GetService('Players')
local T={sessions=0,seconds=0,over15=0,runs=0,completed=0}
function T.init(S)
 S.Telemetry=T local starts={}
 table.insert(S.onJoin,function(p) starts[p]=os.clock() end)
 Players.PlayerRemoving:Connect(function(p)
  local start=starts[p] if not start then return end starts[p]=nil
  local seconds=os.clock()-start T.sessions+=1 T.seconds+=seconds
  if seconds>=900 then T.over15+=1 end
 end)
end
function T.started() T.runs+=1 end
function T.finished(success) if success then T.completed+=1 end end
return T
