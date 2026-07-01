--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local ProgressBar = {}

function ProgressBar.new(value: number, color: Color3?): Frame
	local track = Instance.new("Frame")
	track.Name = "ProgressBar"
	track.BackgroundColor3 = Color3.fromHex("2B2E29")
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, 6)
	track:SetAttribute("Value", math.clamp(value, 0, 1))

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color or Theme.Colors.White
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	local fillCorner = trackCorner:Clone()
	fillCorner.Parent = fill
	task.defer(function()
		if track.Parent then ProgressBar.set(track, value, true) end
	end)

	return track
end

function ProgressBar.set(track: Frame, value: number, animate: boolean?)
	value = math.clamp(value, 0, 1)
	track:SetAttribute("Value", value)
	local fill = track:FindFirstChild("Fill") :: Frame?
	if not fill then return end
	if animate == false then
		fill.Size = UDim2.fromScale(value, 1)
	else
		TweenService:Create(fill, TweenInfo.new(Theme.Animation.Standard, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), { Size = UDim2.fromScale(value, 1) }):Play()
	end
end

return ProgressBar
