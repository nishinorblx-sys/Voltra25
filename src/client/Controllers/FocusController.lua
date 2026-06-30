--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local FocusStyle = require(script.Parent.Parent.Components.FocusStyle)

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
	instance.Selectable = false

	if instance:IsA("GuiButton") then
		instance.AutoButtonColor = false
		FocusStyle.apply(instance)
	end
end

function FocusController.new()
	return setmetatable({}, FocusController)
end

function FocusController:Start(playerGui: PlayerGui)
	local function attach(screenGui: Instance)
		if not screenGui:IsA("ScreenGui") or screenGui.Name ~= "VTR25" then return end
		if screenGui:GetAttribute("VTRFocusControllerAttached") then return end
		screenGui:SetAttribute("VTRFocusControllerAttached", true)
		for _, descendant in screenGui:GetDescendants() do configure(descendant) end
		screenGui.DescendantAdded:Connect(configure)
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
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement and input.Delta.Magnitude > 0 then
			GuiService.SelectedObject = nil
		end
	end)
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		if GuiService.SelectedObject then GuiService.SelectedObject = nil end
	end)
end

return FocusController
