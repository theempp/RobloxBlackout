-- Shared escape geometry: persistent collision, recovery and route timing use the same centreline.
local V = Vector3.new
local R = {}
R.Points = { V(980,0,0), V(1080,0,0), V(1460,0,0), V(1540,4,0), V(1630,12,70), V(1730,22,70), V(1820,32,-35), V(1920,42,-35), V(2020,48,35), V(2110,48,35) }
R.Width = 36
function R.length()
 local n=0 for i=2,#R.Points do n+=(R.Points[i]-R.Points[i-1]).Magnitude end return n
end
function R.nearest(p)
 local best, dist = R.Points[1], math.huge
 for i=2,#R.Points do
  local a,b=R.Points[i-1],R.Points[i]
  local d=b-a local q=a+d*math.clamp((p-a):Dot(d)/d:Dot(d),0,1)
  local n=(p-q).Magnitude if n<dist then best,dist=q,n end
 end
 return best,dist
end
return R
