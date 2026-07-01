local MATCHUP_PANEL_DELAY = 0.85
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local RankedQueuePresentation = require(script.Parent.Parent.Components.RankedQueuePresentation)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)
local PageBase = require(script.Parent.PageBase)

local RankedPage = {}

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = value
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = font
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function stat(parent: Instance, title: string, value: string, xScale: number)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(xScale, 0, 0, 92)
	holder.Size = UDim2.new(.25, -16, 0, 58)
	holder.Parent = parent
	text(holder, title, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	text(holder, value, UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 34), 20, Theme.Colors.White, Theme.Fonts.Display)
	return holder
end

local function addMarker(parent: Instance, index: number, wins: number)
	local x = (index - 1) / 6
	local reached = wins >= index
	local marker = Instance.new("Frame")
	marker.Name = "Win" .. tostring(index)
	marker.AnchorPoint = Vector2.new(.5, .5)
	marker.BackgroundColor3 = reached and Theme.Colors.White or Theme.Colors.Gunmetal
	marker.BorderSizePixel = 0
	marker.Position = UDim2.fromScale(x, .5)
	marker.Size = index == 7 and UDim2.fromOffset(44, 44) or UDim2.fromOffset(34, 34)
	marker.ZIndex = 4
	marker.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = marker
	local stroke = Instance.new("UIStroke")
	stroke.Color = index == 7 and Theme.Colors.White or Theme.Colors.Border
	stroke.Transparency = reached and .1 or .18
	stroke.Thickness = index == 7 and 2 or 1
	stroke.Parent = marker
	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromScale(1, 1)
	number.Text = index == 7 and "7" or tostring(index)
	number.TextColor3 = reached and Theme.Colors.Black or Theme.Colors.White
	number.TextSize = index == 7 and 16 or 12
	number.Font = Theme.Fonts.Display
	number.TextXAlignment = Enum.TextXAlignment.Center
	number.TextYAlignment = Enum.TextYAlignment.Center
	number.ZIndex = 5
	number.Parent = marker
	local caption = Instance.new("TextLabel")
	caption.AnchorPoint = Vector2.new(.5, 0)
	caption.BackgroundTransparency = 1
	caption.Position = UDim2.new(x, 0, .5, 30)
	caption.Size = UDim2.fromOffset(index == 7 and 108 or 72, 30)
	caption.Text = index == 7 and "FINAL PACK" or ("WIN " .. tostring(index))
	caption.TextColor3 = index == 7 and Theme.Colors.White or Theme.Colors.Muted
	caption.TextSize = 8
	caption.Font = Theme.Fonts.Strong
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextYAlignment = Enum.TextYAlignment.Top
	caption.ZIndex = 5
	caption.Parent = parent
end

local function rankedWins(context: any): (number, number)
	local progression = context.Data.Progression or {}
	local run = progression.RankedRun or {}
	local ranked = context.Data.Ranked or progression.Ranked or {}
	local wins = tonumber(run.Wins or ranked.DivisionWins or ranked.Wins) or 0
	local losses = tonumber(run.Losses or ranked.RunLosses or 0) or 0
	return math.clamp(math.floor(wins), 0, 7), math.max(0, math.floor(losses))
end

function RankedPage.new(context: any): CanvasGroup
	local group, scroll = PageBase.new("Ranked", 680)
	local wins, losses = rankedWins(context)
	local progression = context.Data.Progression or {}
	local ranked = context.Data.Ranked or progression.Ranked or {}
	local division = string.upper(tostring(ranked.Division or ranked.DivisionName or "RANKED RUN"))
	local record = tostring(ranked.Wins or 0) .. "W  /  " .. tostring(ranked.Draws or 0) .. "D  /  " .. tostring(ranked.Losses or 0) .. "L"

	PageBase.heading(scroll, "RANKED", "SEVEN-WIN PATH", "Queue your squad into a watch-vs-watch ranked match. First to seven wins claims the final pack marker.")

	local path = Panel.new({Name = "SevenWinPath", Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 276), ClipsDescendants = false})
	path.Parent = scroll
	text(path, "7-WIN PATH", UDim2.fromOffset(24, 20), UDim2.new(.5, -24, 0, 34), 26, Theme.Colors.White, Theme.Fonts.Display)
	text(path, tostring(wins) .. " / 7 WINS", UDim2.new(.72, 0, 0, 24), UDim2.new(.24, 0, 0, 30), 18, Theme.Colors.White, Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Right
	text(path, tostring(losses) .. " LOSSES  /  RUN ENDS AT 3", UDim2.new(.72, 0, 0, 58), UDim2.new(.24, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong).TextXAlignment = Enum.TextXAlignment.Right

	local rail = Instance.new("Frame")
	rail.Name = "PathRail"
	rail.BackgroundTransparency = 1
	rail.Position = UDim2.new(.08, 0, 0, 120)
	rail.Size = UDim2.new(.84, 0, 0, 96)
	rail.Parent = path
	local line = Instance.new("Frame")
	line.AnchorPoint = Vector2.new(.5, .5)
	line.BackgroundColor3 = Theme.Colors.Border
	line.BorderSizePixel = 0
	line.Position = UDim2.fromScale(.5, .5)
	line.Size = UDim2.new(1, 0, 0, 6)
	line.ZIndex = 2
	line.Parent = rail
	local lineCorner = Instance.new("UICorner")
	lineCorner.CornerRadius = UDim.new(1, 0)
	lineCorner.Parent = line
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0, .5)
	fill.BackgroundColor3 = Theme.Colors.White
	fill.BorderSizePixel = 0
	fill.Position = UDim2.fromScale(0, .5)
	fill.Size = UDim2.new(math.clamp(wins / 7, 0, 1), 0, 0, 6)
	fill.ZIndex = 3
	fill.Parent = rail
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	for index = 1, 7 do
		addMarker(rail, index, wins)
	end

	local status = Panel.new({Name = "RankedStatus", Position = UDim2.fromOffset(0, 396), Size = UDim2.new(.56, -10, 0, 170)})
	status.Parent = scroll
	text(status, division, UDim2.fromOffset(20, 18), UDim2.new(1, -40, 0, 28), 17, Theme.Colors.White, Theme.Fonts.Display)
	text(status, "WATCH QUEUE FORMAT", UDim2.fromOffset(20, 50), UDim2.new(1, -40, 0, 18), 8, Theme.Colors.White, Theme.Fonts.Strong)
	stat(status, "RUN WINS", tostring(wins), 0)
	stat(status, "RUN LOSSES", tostring(losses), .25)
	stat(status, "RECORD", record, .5)
	stat(status, "TARGET", "7", .75)

	local explainer = Panel.new({Name = "WatchFormat", Position = UDim2.new(.56, 10, 0, 396), Size = UDim2.new(.44, -10, 0, 170)})
	explainer.Parent = scroll
	text(explainer, "GLOBAL WATCH MATCH", UDim2.fromOffset(20, 18), UDim2.new(1, -40, 0, 28), 17, Theme.Colors.White, Theme.Fonts.Display)
	explainer.Visible = false
	text(explainer, "Your built squad queues for a ranked opponent, then both teams play as AI. You watch the match instead of controlling a player.", UDim2.fromOffset(20, 54), UDim2.new(1, -40, 0, 62), 10, Theme.Colors.Silver, Theme.Fonts.Body)
	text(explainer, "BOTTOM-RIGHT PLAY STARTS SEARCH", UDim2.fromOffset(20, 122), UDim2.new(1, -40, 0, 24), 8, Theme.Colors.White, Theme.Fonts.Strong)

	local play = Button.new({Text = "PLAY RANKED", Variant = "Primary", Size = UDim2.fromOffset(218, 54), OnActivated = function()
		local result = MatchSetupService:JoinRankedQueue()
		if type(result) == "table" and result.Success then
			RankedQueuePresentation.StartSearching(context.Root)
			if context.Toast then
				context.Toast({Title = "RANKED QUEUE", Message = result.Message or "Searching for a ranked opponent.", Kind = "Info"})
			end
		elseif context.Toast then
			context.Toast({Title = "RANKED QUEUE", Message = type(result) == "table" and result.Message or "Unable to start ranked queue.", Kind = "Error"})
		end
	end})
	play.Name = "RankedPlayButton"
	play.AnchorPoint = Vector2.new(1, 1)
	play.Position = UDim2.new(1, -26, 1, -24)
	play.ZIndex = 24
	play.Parent = group

	return group
end

return RankedPage
