local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return { new = function() local f = Instance.new("Frame"); f.Name = "StudioOnlyShootingModeDisabled"; return f end } end
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local PageBase = require(script.Parent.PageBase)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)

local Page = {}

local function label(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = pos
	item.Size = size
	item.Text = value
	item.TextColor3 = color
	item.TextSize = textSize
	item.Font = font
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextYAlignment = Enum.TextYAlignment.Center
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function makeStat(parent: Instance, index: number, title: string, value: string)
	local cell = Panel.new({ Name = title:gsub("%W", "") .. "Stat", Size = UDim2.fromScale(1, 1) })
	cell.LayoutOrder = index
	cell.Parent = parent
	label(cell, title, UDim2.fromOffset(14, 11), UDim2.new(1, -28, 0, 16), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	label(cell, value, UDim2.fromOffset(14, 30), UDim2.new(1, -28, 0, 28), 17, Theme.Colors.White, Theme.Fonts.Display)
end

local function makeGoalScene(parent: Instance)
	local scene = Instance.new("Frame")
	scene.Name = "GoalScene"
	scene.BackgroundTransparency = 1
	scene.Position = UDim2.new(.55, 0, 0, 34)
	scene.Size = UDim2.new(.4, 0, 0, 250)
	scene.Parent = parent

	local goal = Instance.new("Frame")
	goal.Name = "Goal"
	goal.BackgroundTransparency = 1
	goal.Position = UDim2.fromScale(.1, .08)
	goal.Size = UDim2.fromScale(.8, .54)
	goal.Parent = scene
	for _, spec in { { "Top", 0, 0, 1, .04 }, { "Left", 0, 0, .025, 1 }, { "Right", .975, 0, .025, 1 } } do
		local bar = Instance.new("Frame")
		bar.Name = spec[1]
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Theme.Colors.Silver
		bar.Position = UDim2.fromScale(spec[2], spec[3])
		bar.Size = UDim2.fromScale(spec[4], spec[5])
		bar.Parent = goal
	end
	for index = 1, 5 do
		local net = Instance.new("Frame")
		net.Name = "NetLine"
		net.BorderSizePixel = 0
		net.BackgroundColor3 = Theme.Colors.Border
		net.BackgroundTransparency = .18
		net.Position = UDim2.fromScale(index / 6, 0)
		net.Size = UDim2.fromScale(.004, 1)
		net.Parent = goal
	end
	for index = 1, 3 do
		local net = Instance.new("Frame")
		net.Name = "NetCross"
		net.BorderSizePixel = 0
		net.BackgroundColor3 = Theme.Colors.Border
		net.BackgroundTransparency = .18
		net.Position = UDim2.fromScale(0, index / 4)
		net.Size = UDim2.fromScale(1, .006)
		net.Parent = goal
	end

	local keeper = Instance.new("Frame")
	keeper.Name = "Keeper"
	keeper.AnchorPoint = Vector2.new(.5, .5)
	keeper.BackgroundColor3 = Theme.Colors.Electric
	keeper.BorderSizePixel = 0
	keeper.Position = UDim2.fromScale(.5, .43)
	keeper.Size = UDim2.fromOffset(34, 64)
	keeper.Parent = scene
	local keeperCorner = Instance.new("UICorner")
	keeperCorner.CornerRadius = UDim.new(0, 8)
	keeperCorner.Parent = keeper

	local ball = Instance.new("Frame")
	ball.Name = "Ball"
	ball.AnchorPoint = Vector2.new(.5, .5)
	ball.BackgroundColor3 = Theme.Colors.White
	ball.BorderSizePixel = 0
	ball.Position = UDim2.fromScale(.34, .82)
	ball.Size = UDim2.fromOffset(18, 18)
	ball.Parent = scene
	local ballCorner = Instance.new("UICorner")
	ballCorner.CornerRadius = UDim.new(1, 0)
	ballCorner.Parent = ball

	local trail = Instance.new("Frame")
	trail.Name = "ShotTrail"
	trail.AnchorPoint = Vector2.new(.5, .5)
	trail.BackgroundColor3 = Theme.Colors.Electric
	trail.BorderSizePixel = 0
	trail.Position = UDim2.fromScale(.42, .68)
	trail.Rotation = -28
	trail.Size = UDim2.fromOffset(140, 4)
	trail.Parent = scene
	local trailCorner = Instance.new("UICorner")
	trailCorner.CornerRadius = UDim.new(1, 0)
	trailCorner.Parent = trail
end

function Page.new(context: any): CanvasGroup
	local group, scroll = PageBase.new("Shooting", 620)
	PageBase.heading(scroll, "STRIKER LAB", "SHOOTING", "Solo striker reps against an AI goalkeeper.")

	local hero = Panel.new({ Name = "ShootingHero", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 330) })
	hero.Parent = scroll
	label(hero, "SHOOTING PRACTICE", UDim2.fromOffset(24, 24), UDim2.new(.48, 0, 0, 36), 27, Theme.Colors.White, Theme.Fonts.Display)
	label(hero, "CURRENT XI STRIKER  /  AI GOALKEEPER  /  AUTO RESET", UDim2.fromOffset(26, 64), UDim2.new(.5, 0, 0, 20), 9, Theme.Colors.Electric, Theme.Fonts.Strong)
	label(hero, "TEST SHOT POWER, FINESSE CURVE, LOW DRIVEN SHOTS AND KEEPER REACTIONS.", UDim2.fromOffset(26, 104), UDim2.new(.45, 0, 0, 42), 14, Theme.Colors.Silver, Theme.Fonts.Strong)
	makeGoalScene(hero)

	local launching = false
	local start = Button.new({
		Text = "START SHOOTING",
		Variant = "Primary",
		Size = UDim2.fromOffset(210, 48),
		OnActivated = function()
			if launching then return end
			launching = true
			local result = MatchSetupService:StartShootingPractice()
			launching = false
			if type(result) == "table" and result.Success then
				context.Toast({ Title = "SHOOTING", Message = result.Message or "Shooting practice loading.", Kind = "Info" })
			else
				context.Toast({ Title = "SHOOTING", Message = type(result) == "table" and (result.Message or result.Error) or "Shooting practice unavailable.", Kind = "Error" })
			end
		end,
	})
	start.Position = UDim2.fromOffset(26, 164)
	start.Parent = hero

	local stats = Instance.new("Frame")
	stats.Name = "ShootingStats"
	stats.BackgroundTransparency = 1
	stats.Position = UDim2.fromOffset(0, 448)
	stats.Size = UDim2.new(1, 0, 0, 82)
	stats.Parent = scroll
	local statsLayout = Instance.new("UIGridLayout")
	statsLayout.CellPadding = UDim2.fromOffset(12, 0)
	statsLayout.CellSize = UDim2.new(.25, -9, 1, 0)
	statsLayout.FillDirection = Enum.FillDirection.Horizontal
	statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statsLayout.Parent = stats
	makeStat(stats, 1, "PLAYER", "STRIKER")
	makeStat(stats, 2, "PITCH", "SOLO")
	makeStat(stats, 3, "KEEPER", "AI")
	makeStat(stats, 4, "TOOLS", "SLIDERS")
	return group
end

return Page
