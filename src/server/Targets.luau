-- Damageable things: Models tagged BC_Target with Health/MaxHealth attributes; a part named "Head" = headshot.
-- Robotic (no blood). Build 2 enemies reuse this tag.
local CollectionService = game:GetService("CollectionService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("BlackoutCrew")
local Config = require(shared.Config)

local Targets = { TAG = "BC_Target" }

function Targets.fromPart(part)
	local m = part:FindFirstAncestorOfClass("Model")
	while m do
		if CollectionService:HasTag(m, Targets.TAG) then
			return m
		end
		m = m:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function setBar(model)
	local bar = model:FindFirstChild("Bar", true)
	if bar then
		bar.Size = UDim2.fromScale(math.clamp(model:GetAttribute("Health") / model:GetAttribute("MaxHealth"), 0, 1), 1)
	end
end

function Targets.setDown(model, down)
	model:SetAttribute("Down", down)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Hitbox" then
			p.Transparency = down and 0.75 or (p:GetAttribute("BaseTransparency") or 0)
		end
	end
	if not down then
		model:SetAttribute("Health", model:GetAttribute("MaxHealth"))
		setBar(model)
	end
end

-- Returns damage dealt, killed.
function Targets.damage(model, amount)
	if model:GetAttribute("Down") or amount <= 0 then
		return 0, false
	end
	local h = model:GetAttribute("Health") or 0
	local dealt = math.min(h, amount)
	h -= dealt
	model:SetAttribute("Health", h)
	setBar(model)
	if h <= 0 then
		Targets.setDown(model, true)
		if model:GetAttribute("NoRespawn") then
			return dealt, true -- heist enemies stay down for the run
		end
		task.delay(model:GetAttribute("RespawnTime") or Config.Range.RespawnTime, function()
			if model.Parent then
				Targets.setDown(model, false)
			end
		end)
		return dealt, true
	end
	return dealt, false
end

local function block(model, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CastShadow = false
	p.Parent = model
	return p
end

-- Primitive robot dummy standing on the ground at cf (feet). opts: health, name, parent, respawn
function Targets.makeDummy(cf, opts)
	opts = opts or {}
	local m = Instance.new("Model")
	m.Name = opts.name or "Dummy"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local grey, dark = Color3.fromRGB(120, 124, 136), Color3.fromRGB(40, 42, 50)
	local base = block(m, "Base", Vector3.new(1.6, 0.4, 1.6), cf * CFrame.new(0, 0.2, 0), dark)
	block(m, "Leg", Vector3.new(0.6, 2.4, 0.6), cf * CFrame.new(0, 1.6, 0), dark)
	block(m, "Body", Vector3.new(2, 2.2, 1), cf * CFrame.new(0, 3.9, 0), grey)
	local head = block(m, "Head", Vector3.new(1.2, 1.1, 1.1), cf * CFrame.new(0, 5.6, 0), grey)
	block(m, "Eye", Vector3.new(0.9, 0.18, 0.1), cf * CFrame.new(0, 5.7, -0.56), Config.Colors.Accent, Enum.Material.SmoothPlastic).CanQuery = false
	m.PrimaryPart = base
	local hp = opts.health or Config.Range.DummyHealth
	m:SetAttribute("MaxHealth", hp)
	m:SetAttribute("Health", hp)
	m:SetAttribute("Down", false)
	if opts.respawn then
		m:SetAttribute("RespawnTime", opts.respawn)
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 6)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.MaxDistance = 120
	gui.Adornee = head
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0, 0, 0)
	bg.BackgroundTransparency = 0.4
	bg.BorderSizePixel = 0
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(90, 230, 120)
	bar.BorderSizePixel = 0
	bar.Parent = bg
	bg.Parent = gui
	gui.Parent = head
	CollectionService:AddTag(m, Targets.TAG)
	m.Parent = opts.parent or workspace
	return m
end

return Targets
