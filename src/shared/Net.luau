-- Remote names in one place. Server creates them; clients wait for them.
-- Client -> server: Fire(seq, origin, dir, ads), Reload(), Aim(on), Equip(slot), SaveSettings(tbl), ClientReady(report), RangeEquip(gunId)
-- Queue(action, on), Action("start", kind, inst | "stop"), Sneak(on)
-- Server -> client: Hit(list), State(tbl), Profile(tbl), Notify(text), HeistEvent(kind, data);
-- FX is unreliable (others' tracers). Run state travels as attributes, not remotes.
local Net = {}
Net.Events = { "Fire", "Reload", "Aim", "Equip", "SaveSettings", "ClientReady", "RangeEquip", "Queue", "Action", "Sneak",
	"Hit", "State", "Profile", "Notify", "HeistEvent" }
Net.ToClient = { Hit = true, State = true, Profile = true, Notify = true, HeistEvent = true }
Net.Unreliable = { "FX" }

local function folder()
	return script.Parent
end

function Net.server()
	local f = folder():FindFirstChild("Remotes") or Instance.new("Folder")
	f.Name = "Remotes"
	for _, n in ipairs(Net.Events) do
		if not f:FindFirstChild(n) then
			local e = Instance.new("RemoteEvent")
			e.Name = n
			e.Parent = f
		end
	end
	for _, n in ipairs(Net.Unreliable) do
		if not f:FindFirstChild(n) then
			local e = Instance.new("UnreliableRemoteEvent")
			e.Name = n
			e.Parent = f
		end
	end
	f.Parent = folder()
	return Net.map(f)
end

function Net.client()
	local f = folder():WaitForChild("Remotes")
	for _, n in ipairs(Net.Events) do
		f:WaitForChild(n)
	end
	for _, n in ipairs(Net.Unreliable) do
		f:WaitForChild(n)
	end
	return Net.map(f)
end

function Net.map(f)
	local t = {}
	for _, c in ipairs(f:GetChildren()) do
		t[c.Name] = c
	end
	return t
end

return Net
