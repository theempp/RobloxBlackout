-- Dresses a character model with equipped cosmetics: the server's real character and the locker's client
-- preview clone use the same code. Idempotent: apply() rebuilds every BC piece. Outfits stash avatar
-- clothing (restored when the outfit comes off) and recolour torso/arms/legs, remembering the originals.
-- Pieces are massless, non-colliding, unqueryable matte parts: purely visual (no stealth effect).
local Config = require(script.Parent.Config)
local Kit = { TAG = "BCCosmetic", STASH = "BCClothingStash", ORIGINAL = "BCOrigColor", APPLIED = "BCSetColor" }

local GROUPS = {
	torso = { "UpperTorso", "LowerTorso", "Torso" },
	arms = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "Left Arm", "Right Arm" },
	legs = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Left Leg", "Right Leg" },
}
local ATTACH = { Head = { "Head" }, Torso = { "UpperTorso", "Torso" } }

local function bodyPart(char, at)
	for _, name in ipairs(ATTACH[at] or {}) do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
	end
	return nil
end

local function isClothing(x)
	return x:IsA("Clothing") or x:IsA("ShirtGraphic")
end
Kit.isClothing = isClothing

local function wear(char, outfit)
	local stash = char:FindFirstChild(Kit.STASH)
	if outfit then
		if not stash then
			stash = Instance.new("Folder")
			stash.Name, stash.Parent = Kit.STASH, char
		end
		for _, x in ipairs(char:GetChildren()) do
			if isClothing(x) then
				x.Parent = stash
			end
		end
	elseif stash then
		for _, x in ipairs(stash:GetChildren()) do
			x.Parent = char
		end
		stash:Destroy()
	end
	for group, names in pairs(GROUPS) do
		for _, name in ipairs(names) do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				-- Anything that recoloured the part since we did (e.g. the avatar finishing loading) is the
				-- new original; otherwise keep the first original through outfit swaps.
				local original, mine = p:GetAttribute(Kit.ORIGINAL), p:GetAttribute(Kit.APPLIED)
				local ours = original ~= nil and mine == p.Color
				if outfit then
					p:SetAttribute(Kit.ORIGINAL, ours and original or p.Color)
					p.Color = outfit.colors[group]
					p:SetAttribute(Kit.APPLIED, p.Color)
				elseif original ~= nil then
					if ours then
						p.Color = original
					end
					p:SetAttribute(Kit.ORIGINAL, nil)
					p:SetAttribute(Kit.APPLIED, nil)
				end
			end
		end
	end
end

local function build(char, def)
	local n = 0
	for i, spec in ipairs(def.parts or {}) do
		local body = bodyPart(char, spec.at)
		if body then
			local p = Instance.new("Part")
			p.Name = "BC_" .. def.slot .. i
			p.Shape = Enum.PartType[spec.kind]
			p.Size = spec.size * body.Size
			p.Material, p.Color = Enum.Material.SmoothPlastic, spec.color
			p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, false
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			local r = spec.rot or Vector3.zero
			local offset = CFrame.new(spec.pos * body.Size) * CFrame.Angles(math.rad(r.X), math.rad(r.Y), math.rad(r.Z))
			p.CFrame = body.CFrame * offset -- placed directly too: the preview clone has no physics to solve welds
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = body, p, offset
			w.Parent = p
			p:SetAttribute(Kit.TAG, def.slot)
			p.Parent = char
			n += 1
		end
	end
	return n
end

-- Remove every BC piece and undo the outfit.
function Kit.clear(char)
	Kit.apply(char, {})
end

-- equipped: slot -> id (already validated by Rules on the server; ids are re-checked here).
function Kit.apply(char, equipped)
	if not char then
		return 0
	end
	for _, x in ipairs(char:GetChildren()) do
		if x:GetAttribute(Kit.TAG) then
			x:Destroy()
		end
	end
	equipped = type(equipped) == "table" and equipped or {}
	local count = 0
	local outfit = Config.CosmeticsById[equipped.outfit or ""]
	wear(char, outfit and outfit.slot == "outfit" and outfit or nil)
	for _, slot in ipairs(Config.CosmeticSlots) do
		local def = Config.CosmeticsById[equipped[slot] or ""]
		if def and def.slot == slot and def.parts then
			count += build(char, def)
		end
	end
	return count
end

-- BC pieces currently on a model (tests, preview).
function Kit.pieces(char)
	local out = {}
	for _, x in ipairs(char and char:GetChildren() or {}) do
		if x:GetAttribute(Kit.TAG) then
			table.insert(out, x)
		end
	end
	return out
end

return Kit
