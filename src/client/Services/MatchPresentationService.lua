--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local DeviceScaleService = require(script.Parent.DeviceScaleService)

local Service = {}
local GUI_NAME = "VTRPrematchBroadcast"

local function current(): (ScreenGui?, CanvasGroup?, Frame?)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild(GUI_NAME)
	if not gui or not gui:IsA("ScreenGui") then return nil, nil, nil end
	local overlay = gui:FindFirstChild("PersistentOverlay")
	local stage = overlay and overlay:FindFirstChild("PresentationStage")
	return gui, overlay :: CanvasGroup?, stage :: Frame?
end

local function clear(stage: Frame)
	for _, child in stage:GetChildren() do child:Destroy() end
end

local function acquire(): (ScreenGui, CanvasGroup, Frame)
	local gui, overlay, stage = current()
	if gui and overlay and stage then return gui, overlay, stage end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if gui then gui:Destroy() end
	gui = Instance.new("ScreenGui")
	gui.Name = GUI_NAME
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 960
	gui.Parent = playerGui
	DeviceScaleService.Apply(gui)
	overlay = Instance.new("CanvasGroup")
	overlay.Name = "PersistentOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromHex("020402")
	overlay.BackgroundTransparency = 0
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 0
	overlay.Active = true
	overlay.ZIndex = 180
	overlay.Parent = gui
	stage = Instance.new("Frame")
	stage.Name = "PresentationStage"
	stage.BackgroundTransparency = 1
	stage.Size = UDim2.fromScale(1, 1)
	stage.ZIndex = 181
	stage.Parent = overlay
	local player = Players.LocalPlayer
	player:SetAttribute("VTRPresentationLayersCreated", (tonumber(player:GetAttribute("VTRPresentationLayersCreated")) or 0) + 1)
	player:SetAttribute("VTRPresentationLayerCount", 1)
	player:SetAttribute("VTRPresentationOverlayCreatedAt", os.clock())
	gui.Destroying:Connect(function()
		player:SetAttribute("VTRPresentationLayerCount", 0)
	end)
	return gui, overlay, stage
end

function Service.BeginLoading(title: string, detail: string): any
	local gui, overlay, stage = acquire()
	Players.LocalPlayer:SetAttribute("VTRPresentationOverlayCreatedAt", os.clock())
	gui:SetAttribute("VTRRuntimePresentationStarted", nil)
	gui:SetAttribute("VTRPresentationCompleting", nil)
	overlay.GroupTransparency = 0
	overlay.BackgroundTransparency = 0
	clear(stage)
	local heading = Instance.new("TextLabel")
	heading.Name = "LoadingTitle"
	heading.BackgroundTransparency = 1
	heading.AnchorPoint = Vector2.new(0.5, 0.5)
	heading.Position = UDim2.fromScale(0.5, 0.44)
	heading.Size = UDim2.fromScale(0.82, 0.1)
	heading.Text = string.upper(title)
	heading.TextColor3 = Theme.Colors.White
	heading.TextSize = 34
	heading.Font = Theme.Fonts.Display
	heading.ZIndex = 184
	heading.Parent = stage
	local status = Instance.new("TextLabel")
	status.Name = "LoadingStatus"
	status.BackgroundTransparency = 1
	status.AnchorPoint = Vector2.new(0.5, 0.5)
	status.Position = UDim2.fromScale(0.5, 0.54)
	status.Size = UDim2.fromScale(0.8, 0.05)
	status.Text = string.upper(detail)
	status.TextColor3 = Theme.Colors.Electric
	status.TextSize = 11
	status.Font = Theme.Fonts.Strong
	status.ZIndex = 184
	status.Parent = stage
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.fromScale(0.5, 0.61)
	track.Size = UDim2.fromScale(0.38, 0.008)
	track.BackgroundColor3 = Color3.fromHex("111711")
	track.BorderSizePixel = 0
	track.ZIndex = 184
	track.Parent = stage
	local fill = Instance.new("Frame")
	fill.Name = "LoadingFill"
	fill.Size = UDim2.fromScale(0.04, 1)
	fill.BackgroundColor3 = Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.ZIndex = 185
	fill.Parent = track
	local handle = {Gui = gui, Overlay = overlay, Stage = stage, Status = status, Fill = fill}
	function handle:SetStatus(value: string)
		if self.Gui.Parent and self.Gui:GetAttribute("VTRRuntimePresentationStarted") ~= true then self.Status.Text = string.upper(value) end
	end
	function handle:SetProgress(value: number)
		if self.Gui.Parent and self.Gui:GetAttribute("VTRRuntimePresentationStarted") ~= true then self.Fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1) end
	end
	function handle:Clear()
		if self.Gui.Parent and self.Gui:GetAttribute("VTRRuntimePresentationStarted") ~= true then clear(self.Stage) end
	end
	return handle
end

function Service.PrepareRuntime(data: any, profile: string): (ScreenGui, Frame, boolean)
	local gui, overlay, stage = acquire()
	local key = tostring((data and (data.MatchSessionId or data.WorldName)) or "")
	if gui:GetAttribute("VTRRuntimePresentationStarted") == true and gui:GetAttribute("VTRMatchSessionId") == key then return gui, stage, false end
	gui:SetAttribute("VTRRuntimePresentationStarted", true)
	gui:SetAttribute("VTRMatchSessionId", key)
	gui:SetAttribute("VTRPresentationProfile", profile)
	gui:SetAttribute("VTRPresentationCompleting", nil)
	overlay.GroupTransparency = 0
	overlay.BackgroundTransparency = profile == "Broadcast" and 1 or profile == "Standard" and 0.1 or 0
	clear(stage)
	Players.LocalPlayer:SetAttribute("VTRPresentationStartedAt", os.clock())
	return gui, stage, true
end

function Service.Complete(immediate: boolean?): boolean
	local gui, overlay = current()
	if not gui or not overlay or gui:GetAttribute("VTRPresentationCompleting") == true then return false end
	gui:SetAttribute("VTRPresentationCompleting", true)
	Players.LocalPlayer:SetAttribute("VTRPresentationControlHandoffAt", os.clock())
	if immediate then
		gui:Destroy()
	else
		TweenService:Create(overlay, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 1}):Play()
		task.delay(0.22, function() if gui.Parent then gui:Destroy() end end)
	end
	return true
end

function Service.Current(): (ScreenGui?, CanvasGroup?, Frame?)
	return current()
end

return Service
