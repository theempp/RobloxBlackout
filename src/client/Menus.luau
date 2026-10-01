-- One menu at a time (armory, locker, settings, wheel). While a menu is open: firing and kart input are
-- suppressed (ctx.cursorFree), proximity prompts are off, and Back (Backspace / gamepad B) closes it.
-- Closing, death and respawn restore everything. Gamepad users get the first button selected.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Menus = { current = nil }
local ctx, C
local closer

local function setPrompts(on)
	pcall(function()
		ProximityPromptService.Enabled = on
	end)
end

-- Open `name`; `close` is that menu's own close function (it must call Menus.closed(name)).
function Menus.open(name, close)
	if Menus.current and Menus.current ~= name then
		local prev = closer
		closer = nil
		if prev then
			prev()
		end
		if Menus.current then -- the previous close did not report back: clear it here
			Menus.closed(Menus.current)
		end
	end
	Menus.current, closer = name, close
	ctx.cursorFree = true
	setPrompts(false)
	ContextActionService:BindActionAtPriority("BCMenuBack", function(_, state)
		if state == Enum.UserInputState.Begin and Menus.current then
			Menus.closeCurrent()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 50, C.Keys.MenuBack, C.Keys.PadMenuBack)
	ctx.emit("menu", name)
end

-- Report that `name` closed (idempotent).
function Menus.closed(name)
	if Menus.current ~= name then
		return
	end
	Menus.current, closer = nil, nil
	ctx.cursorFree = false
	setPrompts(true)
	ContextActionService:UnbindAction("BCMenuBack")
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
	end
	ctx.emit("menu", nil)
end

function Menus.closeCurrent()
	local fn = closer
	if fn then
		fn()
	end
	if Menus.current then
		Menus.closed(Menus.current)
	end
end

-- Gamepad: select a button so A activates it and the stick moves between buttons.
function Menus.focus(button)
	if button and ctx.inputKind == "Gamepad" then
		GuiService.SelectedObject = button
	end
end

function Menus.init(c)
	ctx, C = c, c.Config
	local lp = Players.LocalPlayer
	local function onCharacter(char)
		Menus.closeCurrent()
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(Menus.closeCurrent)
		end
	end
	lp.CharacterAdded:Connect(onCharacter)
	if lp.Character then
		task.spawn(onCharacter, lp.Character)
	end
	ctx.on("inputKind", function(kind)
		if kind ~= "Gamepad" and GuiService.SelectedObject then
			GuiService.SelectedObject = nil
		end
	end)
end

return Menus
