-- Uploaded Blender pieces, shared by world/display and first-person models. No runtime EditableMesh.
-- Config.GunMeshes.UseUploaded=false selects procedural boxes of the same new guns for diagnostics.
local Config = require(script.Parent.Config)
local Assets = require(script.Parent.GunAssets)
local AssetService = game:GetService("AssetService")
local GunModel = { fpStatus = {} }
local templates, loading = {}, {}

function GunModel.art(id)
	return Assets[id]
end

local function settle(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, false, true, false
end

local function assemble(gun, uploaded)
	local art = assert(Assets[gun.id], "Unknown gun art: " .. gun.id)
	local model = Instance.new("Model")
	model.Name = gun.id
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "Root", Vector3.one * Config.GunMeshes.MinPartSize, 1
	settle(root)
	root.Parent = model
	model.PrimaryPart = root
	local function point(name, pos)
		local a = Instance.new("Attachment")
		a.Name, a.Position, a.Parent = name, pos, root
	end
	point("Muzzle", art.muzzle)
	for name, pos in pairs(art.points) do point(name, pos) end
	local ok, err = pcall(function()
		for _, spec in ipairs(art.pieces) do
			local p
			if uploaded then
				p = AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. spec.assetId), {
					CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise,
				})
			else
				p = Instance.new("Part")
			end
			p.Parent = model
			p.Name = spec.name
			p.Size = spec.size:Max(Vector3.one * Config.GunMeshes.MinPartSize)
			p.Color, p.Material = spec.color, Enum.Material.SmoothPlastic
			p.CFrame = CFrame.new(spec.center) * (uploaded and CFrame.Angles(math.rad(spec.rotation.X), math.rad(spec.rotation.Y), math.rad(spec.rotation.Z)) or CFrame.identity)
			p.PivotOffset = CFrame.new(p.CFrame:PointToObjectSpace(spec.pivot))
			settle(p)
			local group = (spec.piece == "Slide" or spec.piece == "Pump") and "Mover" or spec.piece == "Mag" and "Mag" or "Receiver"
			p:SetAttribute("Group", group)
			p:SetAttribute("Tris", spec.tris)
			p:SetAttribute("Piece", spec.piece)
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = root, p, p.CFrame
			w.Parent = p
		end
	end)
	if not ok then model:Destroy(); error(err, 0) end
	model:SetAttribute("Tris", uploaded and art.tris or #art.pieces * Config.TriEstimate.Block)
	model:SetAttribute("GunArt", uploaded and "uploaded" or "procedural")
	return model
end

function GunModel.build(gun)
	if not Config.GunMeshes.UseUploaded then
		return assemble(gun, false), "primitive"
	end
	-- A single cached template per gun per VM; concurrent equips share the same load.
	while loading[gun.id] do loading[gun.id].Event:Wait() end
	if templates[gun.id] then return templates[gun.id]:Clone(), "mesh" end
	local signal = Instance.new("BindableEvent")
	loading[gun.id] = signal
	local ok, model = pcall(assemble, gun, true)
	if ok then templates[gun.id] = model end
	loading[gun.id] = nil
	signal:Fire()
	signal:Destroy()
	if not ok then
		GunModel.fpStatus[gun.id] = "fallback: " .. tostring(model)
		warn("BC_WARN gun mesh unavailable", gun.id, model)
		return assemble(gun, false), "fallback"
	end
	return model:Clone(), "mesh"
end

function GunModel.buildFirstPerson(gun)
	local model, kind = GunModel.build(gun)
	if kind ~= "fallback" then GunModel.fpStatus[gun.id] = kind end
	return model, kind
end

return GunModel
