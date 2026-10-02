-- Pure cycle resolution. Blackout wins over every cycle update; removing it resolves the current time.
local T={}
function T.resolve(startHour,elapsed,cfg,blackout)
 local hour=(startHour+elapsed*24/cfg.CycleSeconds)%24
 local night=hour<6 or hour>=18
 local out={ClockTime=hour,Brightness=night and 1.1 or 2,Ambient=Color3.fromRGB(75,80,90),OutdoorAmbient=Color3.fromRGB(105,110,120),FogEnd=1600}
 if blackout then for k,v in pairs(blackout) do out[k]=v end end
 return out,night and not blackout
end
return T
