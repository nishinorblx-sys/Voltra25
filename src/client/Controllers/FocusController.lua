--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local FocusStyle = require(script.Parent.Parent.Components.FocusStyle)
local UISoundService = require(script.Parent.Parent.Services.UISoundService)

local FocusController = {}
FocusController.__index = FocusController

local function suppressDefaultSelection(guiObject: GuiObject)
	if guiObject:GetAttribute("VTRSelectionSuppressed") then return end
	guiObject:SetAttribute("VTRSelectionSuppressed", true)
	local legacySuppressor = guiObject:FindFirstChild("VTRTransparentSelection")
	if legacySuppressor then legacySuppressor:Destroy() end
	guiObject.SelectionImageObject = nil
end

local function configure(instance: Instance)
	if not instance:IsA("GuiObject") then return end
	suppressDefaultSelection(instance)

	if instance:IsA("GuiButton") then
		instance.AutoButtonColor = false
		local text = instance:IsA("TextButton") and instance.Text or ""
		local fullScreenShield = instance.AbsoluteSize.X > 900 and instance.AbsoluteSize.Y > 500 and instance.BackgroundTransparency >= 0.92 and text == ""
		local lowerName = string.lower(instance.Name)
		local namedShield = string.find(lowerName, "shield") ~= nil or string.find(lowerName, "blocker") ~= nil or string.find(lowerName, "overlay") ~= nil
		instance.Selectable = not (fullScreenShield or namedShield)
		FocusStyle.apply(instance)
	else
		instance.Selectable = false
	end
end

local function visibleButton(root: Instance): GuiButton?
	local best: GuiButton? = nil
	local bestScore = math.huge
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("GuiButton") or not descendant.Selectable or not descendant.Visible then continue end
		local object: GuiObject = descendant
		local ancestor = object.Parent
		local blocked = false
		while ancestor and ancestor ~= root do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then
				blocked = true
				break
			end
			ancestor = ancestor.Parent
		end
		if blocked or object.AbsoluteSize.X < 8 or object.AbsoluteSize.Y < 8 then continue end
		local position = object.AbsolutePosition
		local score = position.Y * 10000 + position.X
		if score < bestScore then
			best = descendant
			bestScore = score
		end
	end
	return best
end

local function selectableButtons(root: Instance): {GuiButton}
	local buttons = {}
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("GuiButton") or not descendant.Selectable or not descendant.Visible then continue end
		local object: GuiObject = descendant
		local ancestor = object.Parent
		local blocked = false
		while ancestor and ancestor ~= root do
			if ancestor:IsA("GuiObject") and not ancestor.Visible then
				blocked = true
				break
			end
			ancestor = ancestor.Parent
		end
		if not blocked and object.AbsoluteSize.X >= 8 and object.AbsoluteSize.Y >= 8 then
			table.insert(buttons, descendant)
		end
	end
	return buttons
end

local function centerOf(object: GuiObject): Vector2
	return object.AbsolutePosition + object.AbsoluteSize * 0.5
end

local function bestDirectionalButton(root: Instance, current: GuiObject?, direction: Vector2): GuiButton?
	local buttons = selectableButtons(root)
	if #buttons == 0 then return nil end
	if not current or not current:IsDescendantOf(root) or not current.Visible then
		return visibleButton(root)
	end
	local origin = centerOf(current)
	local best: GuiButton? = nil
	local bestScore = math.huge
	for _, button in buttons do
		if button == current then continue end
		local offset = centerOf(button) - origin
		local distance = offset.Magnitude
		if distance < 1 then continue end
		local unit = offset.Unit
		local dot = unit:Dot(direction)
		if dot <= 0.35 then continue end
		local cross = math.abs(unit.X * direction.Y - unit.Y * direction.X)
		local score = distance * (1 + cross * 2.4) - dot * 90
		if score < bestScore then
			best = button
			bestScore = score
		end
	end
	return best
end

local function topMostCloseButton(container: Instance): GuiButton?
	local best: GuiButton? = nil
	local bestZ = -math.huge
	for _, descendant in container:GetDescendants() do
		if not descendant:IsA("GuiButton") or not descendant.Visible then continue end
		local object: GuiObject = descendant
		local text = descendant:IsA("TextButton") and string.upper(descendant.Text) or ""
		local name = string.upper(descendant.Name)
		local closes = string.find(text, "BACK") ~= nil
			or string.find(text, "CLOSE") ~= nil
			or string.find(text, "CANCEL") ~= nil
			or string.find(name, "BACK") ~= nil
			or string.find(name, "CLOSE") ~= nil
			or string.find(name, "CANCEL") ~= nil
		if closes and object.ZIndex >= bestZ then
			best = descendant
			bestZ = object.ZIndex
		end
	end
	return best
end

local function topMostDismissible(root: Instance): GuiObject?
	local best: GuiObject? = nil
	local bestZ = -math.huge
	for _, descendant in root:GetDescendants() do
		if not descendant:IsA("GuiObject") or not descendant.Visible then continue end
		local object: GuiObject = descendant
		local lowerName = string.lower(object.Name)
		local dismissibleName = string.find(lowerName, "modal") ~= nil
			or string.find(lowerName, "overlay") ~= nil
			or string.find(lowerName, "preview") ~= nil
			or string.find(lowerName, "playeractions") ~= nil
			or string.find(lowerName, "playerdetails") ~= nil
			or string.find(lowerName, "roster") ~= nil
		local safeKind = object:IsA("CanvasGroup") or object:IsA("Frame") or object:IsA("TextButton")
		local fullScreen = object.AbsoluteSize.X >= 420 and object.AbsoluteSize.Y >= 300
		if safeKind and dismissibleName and fullScreen and object.ZIndex >= 50 and object.ZIndex >= bestZ then
			best = object
			bestZ = object.ZIndex
		end
	end
	return best
end

local function dismissTop(root: Instance): boolean
	local target = topMostDismissible(root)
	if not target then return false end
	local closeButton = topMostCloseButton(target)
	if closeButton then
		local ok = pcall(function()
			closeButton:Activate()
		end)
		if ok then
			return true
		end
	end
	local destroyTarget: Instance = target
	if string.find(string.lower(target.Name), "shield") or string.find(string.lower(target.Name), "inputshield") then
		destroyTarget = target.Parent or target
	end
	destroyTarget:Destroy()
	GuiService.SelectedObject = nil
	return true
end

local function isGamepadInput(input: InputObject): boolean
	return input.UserInputType.Name:find("Gamepad") ~= nil
end

local function isMatchHud(root: ScreenGui?): boolean
	return root ~= nil and root.Name == "VTRMatchHUD"
end

local function blocksJoystickUiNavigation(root: ScreenGui?): boolean
	return isMatchHud(root) and root:FindFirstChild("PauseOverlay") == nil
end

function FocusController.new()
	return setmetatable({Root = nil :: ScreenGui?, LastStickMoveAt = 0, LastStickDirection = Vector2.zero}, FocusController)
end

function FocusController:Start(playerGui: PlayerGui)
	local function attach(screenGui: Instance)
		if not screenGui:IsA("ScreenGui") or (screenGui.Name ~= "VTR25" and screenGui.Name ~= "VTRMatchHUD") then return end
		if screenGui:GetAttribute("VTRFocusControllerAttached") then return end
		screenGui:SetAttribute("VTRFocusControllerAttached", true)
		self.Root = screenGui
		for _, descendant in screenGui:GetDescendants() do configure(descendant) end
		screenGui.DescendantAdded:Connect(function(descendant)
			task.defer(function()
				if descendant.Parent then configure(descendant) end
			end)
		end)
	end

	-- Never mutate Roblox-owned PlayerGui descendants such as ChatScript.
	-- Global focus styling means global to the VTR application ScreenGui.
	for _, child in playerGui:GetChildren() do attach(child) end
	playerGui.ChildAdded:Connect(attach)

	-- Switching back to mouse or touch immediately releases controller focus.
	-- Players never need Escape just to remove a stale focus highlight.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.Touch then
			GuiService.SelectedObject = nil
		elseif input.KeyCode == Enum.KeyCode.ButtonB and self.Root then
			if dismissTop(self.Root) then
				return
			end
		elseif isGamepadInput(input) and not blocksJoystickUiNavigation(self.Root) and not GuiService.SelectedObject and self.Root then
			GuiService.SelectedObject = visibleButton(self.Root)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement and input.Delta.Magnitude > 0 then
			GuiService.SelectedObject = nil
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 and self.Root then
			if blocksJoystickUiNavigation(self.Root) then
				if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Root) then
					GuiService.SelectedObject = nil
				end
				self.LastStickDirection = Vector2.zero
				return
			end
			local direction = Vector2.new(input.Position.X, -input.Position.Y)
			if direction.Magnitude < 0.72 then
				self.LastStickDirection = Vector2.zero
				return
			end
			direction = direction.Unit
			local now = os.clock()
			local changedDirection = self.LastStickDirection.Magnitude < 0.1 or direction:Dot(self.LastStickDirection) < 0.58
			if not changedDirection and now - (self.LastStickMoveAt or 0) < 0.38 then
				return
			end
			self.LastStickMoveAt = now
			self.LastStickDirection = direction
			local selected = GuiService.SelectedObject
			local target = bestDirectionalButton(self.Root, selected, direction)
			if target then
				GuiService.SelectedObject = target
			end
		end
	end)
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsA("GuiButton") then
			UISoundService.PlayHover()
		end
	end)
end

function FocusController:SelectFirst()
	if self.Root then
		GuiService.SelectedObject = visibleButton(self.Root)
	end
end

return FocusController
