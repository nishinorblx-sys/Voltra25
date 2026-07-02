local PackRouletteAlignmentService = require(script.Parent.Parent.Services:WaitForChild("PackRouletteAlignmentService"))
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

local function stat(parent: Instance, title: string, value: string, xScale: number, valueColor: Color3?)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.new(xScale, 18, 0, 96)
	holder.Size = UDim2.new(.19, -18, 0, 58)
	holder.Parent = parent
	text(holder, title, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	text(holder, value, UDim2.fromOffset(0, 22), UDim2.new(1, 0, 0, 34), 20, valueColor or Theme.Colors.White, Theme.Fonts.Display)
	return holder
end

local function resultColor(result: string?): Color3
	if result == "Win" then return Theme.Colors.Electric end
	if result == "Loss" then return Theme.Colors.Danger end
	if result == "Draw" then return Color3.fromHex("2F6BFF") end
	return Theme.Colors.Gunmetal
end

local function addMarker(parent: Instance, index: number, result: string?)
	local x = (index - 1) / 6
	local played = result == "Win" or result == "Draw" or result == "Loss"
	local marker = Instance.new("Frame")
	marker.Name = "Game" .. tostring(index)
	marker.AnchorPoint = Vector2.new(.5, .5)
	marker.BackgroundColor3 = resultColor(result)
	marker.BorderSizePixel = 0
	marker.Position = UDim2.fromScale(x, .5)
	marker.Size = index == 7 and UDim2.fromOffset(44, 44) or UDim2.fromOffset(34, 34)
	marker.ZIndex = 4
	marker.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = marker
	local stroke = Instance.new("UIStroke")
	stroke.Color = played and resultColor(result) or (index == 7 and Theme.Colors.Electric or Theme.Colors.Border)
	stroke.Transparency = played and .05 or .18
	stroke.Thickness = index == 7 and 2 or 1
	stroke.Parent = marker
	local number = Instance.new("TextLabel")
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromScale(1, 1)
	number.Text = played and (result == "Draw" and "-" or "✓") or tostring(index)
	number.TextColor3 = (result == "Win") and Theme.Colors.Black or Theme.Colors.White
	if played then
		number.Text = result == "Win" and "✓" or result == "Loss" and "X" or "-"
	end
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
	caption.Text = played and string.upper(result :: string) or ("GAME " .. tostring(index))
	caption.TextColor3 = played and resultColor(result) or Theme.Colors.Muted
	caption.TextSize = 8
	caption.Font = Theme.Fonts.Strong
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextYAlignment = Enum.TextYAlignment.Top
	caption.ZIndex = 5
	caption.Parent = parent
end

local function rankedPath(context: any): ({string}, number, number, number, number)
	local progression = context.Data.Progression or {}
	local ranked = context.Data.Ranked or progression.Ranked or {}
	local run = progression.RankedRun or ranked.RankedRun or ranked.Run or {}
	local results = {}
	if type(run.Results) == "table" then
		for _, value in run.Results do
			local result = tostring(value)
			if result == "Win" or result == "Draw" or result == "Loss" then table.insert(results, result) end
			if #results >= 7 then break end
		end
	end
	if #results == 0 then
		for _ = 1, math.clamp(math.floor(tonumber(run.Wins) or 0), 0, 7) do table.insert(results, "Win") end
		for _ = 1, math.clamp(math.floor(tonumber(run.Draws) or 0), 0, 7 - #results) do table.insert(results, "Draw") end
		for _ = 1, math.clamp(math.floor(tonumber(run.Losses) or 0), 0, 7 - #results) do table.insert(results, "Loss") end
	end
	local wins = 0
	local draws = 0
	local losses = 0
	for _, result in results do
		if result == "Win" then wins += 1 elseif result == "Draw" then draws += 1 elseif result == "Loss" then losses += 1 end
	end
	return results, wins, draws, losses, #results
end

local function rankedGoalDifference(ranked: any): number
	local total = 0
	for _, match in ranked.History or {} do
		local scored, conceded = string.match(tostring(match.Score or ""), "^(%-?%d+)%s*%-%s*(%-?%d+)$")
		if scored and conceded then
			total += (tonumber(scored) or 0) - (tonumber(conceded) or 0)
		end
	end
	return total
end

function RankedPage.new(context: any): CanvasGroup
	local group, scroll = PageBase.new("Ranked", 980)
	local results, wins, draws, losses, games = rankedPath(context)
	local progression = context.Data.Progression or {}
	local ranked = context.Data.Ranked or progression.Ranked or {}
	local division = string.upper(tostring(ranked.Division or ranked.DivisionName or "RANKED RUN"))
	local record = tostring(ranked.Wins or 0) .. "W  /  " .. tostring(ranked.Draws or 0) .. "D  /  " .. tostring(ranked.Losses or 0) .. "L"
	local goalDifference = rankedGoalDifference(ranked)
	local goalDifferenceText = goalDifference > 0 and ("+" .. tostring(goalDifference)) or tostring(goalDifference)
	local goalDifferenceColor = goalDifference > 0 and Theme.Colors.Electric or goalDifference < 0 and Theme.Colors.Danger or Color3.fromHex("2F6BFF")

	PageBase.heading(scroll, "RANKED", "SEVEN-GAME PATH", "Queue your squad into a watch-vs-watch ranked match. Complete seven games and your final record decides the path reward.")

	local path = Panel.new({Name = "SevenGamePath", Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 276), ClipsDescendants = false})
	path.Parent = scroll
	text(path, "7-GAME PATH", UDim2.fromOffset(24, 20), UDim2.new(.5, -24, 0, 34), 26, Theme.Colors.White, Theme.Fonts.Display)
	text(path, tostring(games) .. " / 7 GAMES", UDim2.new(.72, 0, 0, 24), UDim2.new(.24, 0, 0, 30), 18, Theme.Colors.Electric, Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Right
	text(path, tostring(wins) .. "W  /  " .. tostring(draws) .. "D  /  " .. tostring(losses) .. "L", UDim2.new(.72, 0, 0, 58), UDim2.new(.24, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong).TextXAlignment = Enum.TextXAlignment.Right

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
	fill.BackgroundColor3 = games > 0 and resultColor(results[games]) or Theme.Colors.Electric
	fill.BorderSizePixel = 0
	fill.Position = UDim2.fromScale(0, .5)
	fill.Size = UDim2.new(math.clamp(games / 7, 0, 1), 0, 0, 6)
	fill.ZIndex = 3
	fill.Parent = rail
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	for index = 1, 7 do
		addMarker(rail, index, results[index])
	end

	local status = Panel.new({Name = "RankedStatus", Position = UDim2.fromOffset(0, 396), Size = UDim2.new(1, 0, 0, 190)})
	status.Parent = scroll
	text(status, division, UDim2.fromOffset(20, 18), UDim2.new(1, -40, 0, 28), 17, Theme.Colors.White, Theme.Fonts.Display)
	text(status, "WATCH QUEUE FORMAT", UDim2.fromOffset(20, 50), UDim2.new(1, -40, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	stat(status, "PATH WINS", tostring(wins), 0)
	stat(status, "PATH LOSSES", tostring(losses), .2)
	stat(status, "PATH RECORD", tostring(wins) .. "W / " .. tostring(draws) .. "D / " .. tostring(losses) .. "L", .4)
	stat(status, "GOAL DIFFERENCE", goalDifferenceText, .62, goalDifferenceColor)
	stat(status, "GAMES", tostring(games) .. " / 7", .82)

	local historyPanel = Panel.new({Name = "RankedHistory", Position = UDim2.fromOffset(0, 610), Size = UDim2.new(1, 0, 0, 320)})
	historyPanel.Parent = scroll
	text(historyPanel, "MATCH HISTORY", UDim2.fromOffset(20, 18), UDim2.new(1, -40, 0, 28), 18, Theme.Colors.White, Theme.Fonts.Display)
	text(historyPanel, "REWARDS  /  PACKS  /  TEAM STATS  /  SCORERS", UDim2.fromOffset(20, 48), UDim2.new(1, -40, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	local function minute(seconds: any): string
		local value = math.max(0, tonumber(seconds) or 0)
		return tostring(math.max(1, math.floor(value / 60 + 0.5))) .. "'"
	end
	local function goalLine(goals: any): string
		local parts = {}
		if type(goals) == "table" then
			for index, goal in goals do
				if index > 4 then break end
				table.insert(parts, tostring(goal.Scorer or "PLAYER") .. " " .. minute(goal.GameSeconds))
			end
		end
		return #parts > 0 and table.concat(parts, "  /  ") or "NO GOALS"
	end
	for index = 1, math.min(5, #(ranked.History or {})) do
		local entry = ranked.History[index]
		local statsData = entry.Stats or {}
		local match = statsData.Match or {}
		local full = statsData.Full or {}
		local reward = entry.Reward or statsData.Reward or {}
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Theme.Colors.Black
		row.BackgroundTransparency = .36
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(18, 78 + (index - 1) * 45)
		row.Size = UDim2.new(1, -36, 0, 38)
		row.Parent = historyPanel
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row
		local result = tostring(entry.Result or "")
		text(row, result, UDim2.fromOffset(12, 7), UDim2.fromOffset(60, 20), 10, resultColor(result), Theme.Fonts.Display)
		text(row, tostring(entry.Score or "0-0") .. " vs " .. tostring(entry.Opponent or "OPP"), UDim2.fromOffset(82, 7), UDim2.fromOffset(180, 20), 10, Theme.Colors.White, Theme.Fonts.Strong)
		local rewardText = "+" .. tostring(reward.Coins or 0) .. "C +" .. tostring(reward.XP or 0) .. "XP"
		local packText = reward.Pack and (" / " .. tostring(reward.Pack)) or reward.PackId and (" / " .. tostring(reward.PackId)) or ""
		text(row, rewardText .. packText, UDim2.fromOffset(274, 7), UDim2.fromOffset(190, 20), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
		text(row, "SH " .. tostring(match.Shots or 0) .. "  SOT " .. tostring(match.ShotsOnTarget or 0) .. "  xG " .. tostring(match.ExpectedGoals or 0), UDim2.fromOffset(474, 7), UDim2.fromOffset(170, 20), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
		text(row, goalLine(full.Goals), UDim2.fromOffset(650, 7), UDim2.new(1, -660, 0, 20), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	end

	local explainer = Panel.new({Name = "WatchFormat", Position = UDim2.new(.56, 10, 0, 396), Size = UDim2.new(.44, -10, 0, 170)})
	explainer.Parent = scroll
	text(explainer, "GLOBAL WATCH MATCH", UDim2.fromOffset(20, 18), UDim2.new(1, -40, 0, 28), 17, Theme.Colors.White, Theme.Fonts.Display)
	explainer.Visible = false
	text(explainer, "Your built squad queues for a ranked opponent, then both teams play as AI. You watch the match instead of controlling a player.", UDim2.fromOffset(20, 54), UDim2.new(1, -40, 0, 62), 10, Theme.Colors.Silver, Theme.Fonts.Body)
	text(explainer, "BOTTOM-RIGHT PLAY STARTS SEARCH", UDim2.fromOffset(20, 122), UDim2.new(1, -40, 0, 24), 8, Theme.Colors.Electric, Theme.Fonts.Strong)

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

local function vtrFindRouletteGuiObjects(root)
	local scroller
	local container

	if typeof(root) ~= "Instance" then
		return nil, nil
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ScrollingFrame") then
			local n = string.lower(obj.Name)
			if string.find(n, "roulette") or string.find(n, "spin") or string.find(n, "reward") or string.find(n, "pack") then
				scroller = obj
				break
			end
			scroller = scroller or obj
		end
	end

	if scroller then
		for _, obj in ipairs(scroller:GetDescendants()) do
			if obj:IsA("GuiObject") then
				local hasPack = obj:GetAttribute("PackId") or obj:GetAttribute("PackName")
				local n = string.lower(obj.Name)
				if hasPack or string.find(n, "pack") or string.find(n, "card") or string.find(n, "item") then
					container = obj.Parent
					break
				end
			end
		end
	end

	return scroller, container
end

local function vtrForceRouletteWinningCenter(root, winningPack, winningIndex)
	if not winningPack then
		return
	end

	task.defer(function()
		local scroller, container = vtrFindRouletteGuiObjects(root)
		if scroller and container then
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
			task.wait(0.05)
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
		end
	end)
end

return RankedPage
