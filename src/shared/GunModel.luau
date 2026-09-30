-- Placeholder foam-tactical blasters from primitives (Config.Guns[].shape): matte black body, neon accents,
-- foam dart tip. One swappable engraving layer (Config.Branding). Non-colliding, massless, no shadows.
local Config = require(script.Parent.Config)
local GunModel = {}

function GunModel.estimateTris(gun)
	local n = 0
	for _, p in ipairs(gun.shape) do
		n += Config.TriEstimate[p.kind] or 12
	end
	return n
end

-- The engraving layer: one call site, so a rename or final logo is a Config change.
function GunModel.engrave(part, face)
	local b = Config.Branding
	if b.DecalId ~= "" then
		local d = Instance.new("Decal")
		d.Name = "Engraving"
		d.Texture = b.DecalId
		d.Face = face
		d.Transparency = 0.2
		d.Parent = part
		return d
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "Engraving"
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 60
	g.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = b.Name
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.fromRGB(90, 90, 100)
	t.Parent = g
	g.Parent = part
	return g
end

-- Returns Model with PrimaryPart "Root" at the grip origin; Root has Attachment "Muzzle".
function GunModel.build(gun)
	local model = Instance.new("Model")
	model.Name = gun.id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	local parts = { root }
	local engraved = false
	for i, spec in ipairs(gun.shape) do
		local p = Instance.new("Part")
		p.Name = spec.color .. i
		local cf = CFrame.new(spec.pos)
		if spec.kind == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder -- Roblox cylinders run along X: turn to lie along Z
			p.Size = Vector3.new(spec.size.Z, spec.size.X, spec.size.Y)
			cf *= CFrame.Angles(0, math.rad(90), 0)
		elseif spec.kind == "Wedge" then
			p:Destroy()
			p = Instance.new("WedgePart")
			p.Name = spec.color .. i
			p.Size = spec.size
		else
			p.Size = spec.size
		end
		if spec.color == "Accent" then
			p.Material = Enum.Material.Neon -- emissive, no dynamic lights (mobile)
			p.Color = gun.accent
		else
			p.Material = Enum.Material.SmoothPlastic
			p.Color = Config.Colors[spec.color] or Config.Colors.Body
		end
		p.CFrame = cf
		p.Parent = model
		table.insert(parts, p)
		if not engraved and spec.color == "Body" and spec.size.Z >= 1 then
			GunModel.engrave(p, Enum.NormalId.Left)
			engraved = true
		end
	end
	for _, p in ipairs(parts) do
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		if p ~= root then
			local w = Instance.new("WeldConstraint")
			w.Part0 = root
			w.Part1 = p
			w.Parent = p
		end
	end
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = gun.muzzle
	muzzle.Parent = root
	root.Parent = model
	model.PrimaryPart = root
	return model
end

return GunModel
