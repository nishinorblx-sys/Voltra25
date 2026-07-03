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
local function vtrSafeRankNumber(value)
	local n = tonumber(value) or 0
	return tostring(math.floor(n))
end

local function vtrRankedPathData(value)
	value = typeof(value) == "table" and value or {}

	local wins = tonumber(value.PathWins or value.Wins or value.SeasonWins or value.QueueWins or value.RecordWins) or 0
	local draws = tonumber(value.PathDraws or value.Draws or value.SeasonDraws or value.QueueDraws or value.RecordDraws) or 0
	local losses = tonumber(value.PathLosses or value.Losses or value.SeasonLosses or value.QueueLosses or value.RecordLosses) or 0

	value.PathWins = wins
	value.PathDraws = draws
	value.PathLosses = losses
	value.PathRecordText = tostring(math.floor(wins)) .. "W / " .. tostring(math.floor(draws)) .. "D / " .. tostring(math.floor(losses)) .. "L"

	return value
end

local function vtrFixPathStatText(root, rankedData)
	if not root then
		return
	end

	rankedData = vtrRankedPathData(rankedData)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			local name = string.lower(tostring(obj.Name or ""))
			local textValue = string.lower(tostring(obj.Text or ""))

			if string.find(name, "pathwins") or string.find(name, "path_wins") or textValue == "path wins" then
				local valueLabel = obj.Parent and obj.Parent:FindFirstChild("Value")
				if valueLabel and (valueLabel:IsA("TextLabel") or valueLabel:IsA("TextButton")) then
					valueLabel.Text = vtrSafeRankNumber(rankedData.PathWins)
				end
			elseif string.find(name, "pathlosses") or string.find(name, "path_losses") or textValue == "path losses" then
				local valueLabel = obj.Parent and obj.Parent:FindFirstChild("Value")
				if valueLabel and (valueLabel:IsA("TextLabel") or valueLabel:IsA("TextButton")) then
					valueLabel.Text = vtrSafeRankNumber(rankedData.PathLosses)
				end
			elseif string.find(name, "pathrecord") or string.find(name, "path_record") or textValue == "path record" then
				local valueLabel = obj.Parent and obj.Parent:FindFirstChild("Value")
				if valueLabel and (valueLabel:IsA("TextLabel") or valueLabel:IsA("TextButton")) then
					valueLabel.Text = rankedData.PathRecordText
				end
			end
		end
	end
end

local function vtrRewardClaimed(value)
	if typeof(value) ~= "table" then
		return {}
	end

	if typeof(vtrRewardClaimed(value)) ~= "table" then
		value.RewardClaimed = {}
	end

	return vtrRewardClaimed(value)
end

local function vtrRankedSafe(value)
	if typeof(value) ~= "table" then
		value = {}
	end

	if typeof(vtrRewardClaimed(value)) ~= "table" then
		value.RewardClaimed = {}
	end

	if typeof(value.Rewards) ~= "table" then
		value.Rewards = {}
	end

	if typeof(value.Rank) ~= "string" then
		value.Rank = tostring(value.Rank or "Bronze")
	end

	value.Division = tonumber(value.Division) or 1
	value.Rating = tonumber(value.Rating) or 0
	value.Wins = tonumber(value.Wins) or 0
	value.Losses = tonumber(value.Losses) or 0

	return value
end


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

local LEADERBOARD_SECTIONS = {
	{Key = "Wins", Label = "WINS"},
	{Key = "Losses", Label = "LOSSES"},
	{Key = "Goals", Label = "GOALS"},
	{Key = "WinRatio", Label = "WIN RATIO"},
	{Key = "Flawless", Label = "FLAWLESS"},
	{Key = "CleanSheets", Label = "CLEAN SHEETS"},
	{Key = "BestStreak", Label = "WIN STREAK"},
	{Key = "PackRating", Label = "PACK RATING"},
}

local function formatLeaderboardValue(key: string, value: any): string
	local number = tonumber(value) or 0
	if key == "WinRatio" then
		return tostring(math.floor(number / 100 + .5)) .. "%"
	end
	return tostring(math.floor(number))
end

local function inputShield(parent: Instance, zIndex: number?)
	local shield = Instance.new("TextButton")
	shield.Name = "VTRInputShield"
	shield.BackgroundTransparency = 1
	shield.BorderSizePixel = 0
	shield.Modal = true
	shield.Text = ""
	shield.Size = UDim2.fromScale(1, 1)
	shield.ZIndex = zIndex or 200
	shield.Selectable = false
	shield.Parent = parent
	task.delay(.32, function()
		if shield.Parent then shield:Destroy() end
	end)
end

function RankedPage.new(context: any): CanvasGroup
	local group, scroll = PageBase.new("Ranked", 1180)
	local mainObjects = {}
	local function track<T>(object: T): T
		table.insert(mainObjects, object)
		return object
	end
	local results, wins, draws, losses, games = rankedPath(context)
	local progression = context.Data.Progression or {}
	local ranked = context.Data.Ranked or progression.Ranked or {}
	local division = string.upper(tostring(ranked.Division or ranked.DivisionName or "RANKED RUN"))
	local record = tostring(ranked.Wins or 0) .. "W  /  " .. tostring(ranked.Draws or 0) .. "D  /  " .. tostring(ranked.Losses or 0) .. "L"
	local goalDifference = rankedGoalDifference(ranked)
	local goalDifferenceText = goalDifference > 0 and ("+" .. tostring(goalDifference)) or tostring(goalDifference)
	local goalDifferenceColor = goalDifference > 0 and Theme.Colors.Electric or goalDifference < 0 and Theme.Colors.Danger or Color3.fromHex("2F6BFF")

	PageBase.heading(scroll, "RANKED", "SEVEN-GAME PATH", "Queue your squad into a watch-vs-watch ranked match. Complete seven games and your final record decides the path reward.")

	local path = track(Panel.new({Name = "SevenGamePath", Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 276), ClipsDescendants = false}))
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
	if games >= 7 and vtrRewardClaimed(run) ~= true then
		local claimOverlay = Instance.new("Frame")
		claimOverlay.Name = "RankedPathClaimOverlay"
		claimOverlay.BackgroundColor3 = Color3.fromHex("061205")
		claimOverlay.BackgroundTransparency = .08
		claimOverlay.BorderSizePixel = 0
		claimOverlay.Position = UDim2.fromOffset(14, 86)
		claimOverlay.Size = UDim2.new(1, -28, 0, 154)
		claimOverlay.ZIndex = 30
		claimOverlay.Parent = path
		local claimCorner = Instance.new("UICorner")
		claimCorner.CornerRadius = UDim.new(0, 10)
		claimCorner.Parent = claimOverlay
		local claimButton = Button.new({Text = "CLAIM", Variant = "Primary", Size = UDim2.fromOffset(280, 68), OnActivated = function()
			inputShield(group, 210)
			local response = MatchSetupService:ClaimRankedPathReward()
			if type(response) == "table" and response.Success then
				claimOverlay.Visible = false
				if context.Toast then context.Toast({Title = "RANKED PATH", Message = response.Message or "Path reward claimed.", Kind = "Reward"}) end
			elseif context.Toast then
				context.Toast({Title = "RANKED PATH", Message = type(response) == "table" and response.Message or "Claim failed.", Kind = "Error"})
			end
		end})
		claimButton.AnchorPoint = Vector2.new(.5, .5)
		claimButton.Position = UDim2.fromScale(.5, .5)
		claimButton.ZIndex = 31
		claimButton.Selectable = true
		claimButton.Parent = claimOverlay
	end

	local status = track(Panel.new({Name = "RankedStatus", Position = UDim2.fromOffset(0, 396), Size = UDim2.new(1, 0, 0, 190)}))
	status.Parent = scroll
	text(status, division, UDim2.fromOffset(20, 18), UDim2.new(1, -40, 0, 28), 17, Theme.Colors.White, Theme.Fonts.Display)
	text(status, "WATCH QUEUE FORMAT", UDim2.fromOffset(20, 50), UDim2.new(1, -40, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	stat(status, "PATH WINS", tostring(wins), 0)
	stat(status, "PATH LOSSES", tostring(losses), .2)
	stat(status, "PATH RECORD", tostring(wins) .. "W / " .. tostring(draws) .. "D / " .. tostring(losses) .. "L", .4)
	stat(status, "GOAL DIFFERENCE", goalDifferenceText, .62, goalDifferenceColor)
	stat(status, "GAMES", tostring(games) .. " / 7", .82)

	local historyPanel = track(Panel.new({Name = "RankedHistory", Position = UDim2.fromOffset(0, 610), Size = UDim2.new(1, 0, 0, 500)}))
	historyPanel.Parent = scroll
	text(historyPanel, "MATCH HISTORY", UDim2.fromOffset(20, 18), UDim2.new(1, -40, 0, 28), 18, Theme.Colors.White, Theme.Fonts.Display)
	text(historyPanel, "REWARDS  /  PACKS  /  TEAM STATS  /  SCORERS", UDim2.fromOffset(20, 48), UDim2.new(1, -40, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	local search = Instance.new("TextBox")
	search.Name = "HistorySearch"
	search.BackgroundColor3 = Theme.Colors.Black
	search.BackgroundTransparency = .28
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.Font = Theme.Fonts.Strong
	search.PlaceholderText = "SEARCH USER OR TAG"
	search.PlaceholderColor3 = Theme.Colors.Muted
	search.Position = UDim2.new(1, -246, 0, 18)
	search.Size = UDim2.fromOffset(220, 36)
	search.Text = ""
	search.TextColor3 = Theme.Colors.White
	search.TextSize = 10
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.Parent = historyPanel
	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, 12)
	searchPadding.PaddingRight = UDim.new(0, 10)
	searchPadding.Parent = search
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 8)
	searchCorner.Parent = search
	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = Theme.Colors.Border
	searchStroke.Transparency = .08
	searchStroke.Parent = search
	local historyList = Instance.new("ScrollingFrame")
	historyList.Name = "HistoryRows"
	historyList.BackgroundTransparency = 1
	historyList.BorderSizePixel = 0
	historyList.Position = UDim2.fromOffset(18, 78)
	historyList.Size = UDim2.new(1, -36, 1, -96)
	historyList.ScrollBarThickness = 4
	historyList.ScrollBarImageColor3 = Theme.Colors.Electric
	historyList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	historyList.CanvasSize = UDim2.new()
	historyList.Parent = historyPanel
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
	local function opponentLabel(entry: any): string
		local name = tostring(entry.Opponent or "OPPONENT")
		local tag = tostring(entry.OpponentTag or entry.TeamTag or "")
		local teamName = tostring(entry.OpponentTeamName or entry.TeamName or "")
		if teamName ~= "" and tag ~= "" then
			return name .. " [" .. teamName .. " (" .. string.upper(tag) .. ")]"
		elseif teamName ~= "" then
			return name .. " [" .. teamName .. "]"
		end
		return tag ~= "" and (name .. " [" .. string.upper(tag) .. "]") or name
	end
	local function clearHistoryRows()
		for _, child in historyList:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end
	local function renderHistory()
		clearHistoryRows()
		local query = string.lower(search.Text or "")
		local rowIndex = 0
		for _, entry in ranked.History or {} do
			local opponentText = opponentLabel(entry)
			local searchable = string.lower(opponentText .. " " .. tostring(entry.Opponent or "") .. " " .. tostring(entry.OpponentTag or ""))
			if query == "" or string.find(searchable, query, 1, true) then
				rowIndex += 1
				local statsData = entry.Stats or {}
				local match = statsData.Match or {}
				local full = statsData.Full or {}
				local reward = entry.Reward or statsData.Reward or {}
				local row = Instance.new("Frame")
				row.BackgroundColor3 = rowIndex % 2 == 0 and Theme.Colors.Black or Theme.Colors.Raised
				row.BackgroundTransparency = rowIndex % 2 == 0 and .42 or .24
				row.BorderSizePixel = 0
				row.Position = UDim2.fromOffset(0, (rowIndex - 1) * 62)
				row.Size = UDim2.new(1, -8, 0, 54)
				row.Parent = historyList
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 7)
				corner.Parent = row
				local result = tostring(entry.Result or "")
				text(row, result, UDim2.fromOffset(12, 8), UDim2.fromOffset(66, 20), 10, resultColor(result), Theme.Fonts.Display)
				text(row, tostring(entry.Score or "0-0") .. " vs " .. opponentText, UDim2.fromOffset(84, 8), UDim2.fromOffset(250, 20), 10, Theme.Colors.White, Theme.Fonts.Strong)
				local rewardText = "+" .. tostring(reward.Coins or 0) .. "C +" .. tostring(reward.XP or 0) .. "XP"
				local packText = reward.Pack and (" / " .. tostring(reward.Pack)) or reward.PackId and (" / " .. tostring(reward.PackId)) or ""
				text(row, rewardText .. packText, UDim2.fromOffset(348, 8), UDim2.fromOffset(198, 20), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
				text(row, "SH " .. tostring(match.Shots or 0) .. "  SOT " .. tostring(match.ShotsOnTarget or 0) .. "  xG " .. tostring(match.ExpectedGoals or 0), UDim2.fromOffset(560, 8), UDim2.fromOffset(160, 20), 8, Theme.Colors.Silver, Theme.Fonts.Strong)
				text(row, goalLine(full.Goals), UDim2.fromOffset(84, 30), UDim2.new(1, -100, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
			end
		end
		if rowIndex == 0 then
			local empty = text(historyList, query == "" and "NO MATCH HISTORY YET" or "NO MATCHES FOUND", UDim2.fromOffset(0, 130), UDim2.new(1, -8, 0, 40), 16, Theme.Colors.Muted, Theme.Fonts.Display)
			empty.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(renderHistory)
	renderHistory()

	local leaderboardPanel = Panel.new({Name = "RankedLeaderboards", Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 1010)})
	leaderboardPanel.Visible = false
	leaderboardPanel.Parent = scroll
	text(leaderboardPanel, "RANKED LEADERBOARDS", UDim2.fromOffset(24, 20), UDim2.new(.55, -24, 0, 34), 26, Theme.Colors.White, Theme.Fonts.Display)
	text(leaderboardPanel, "TOP 100 PLAYERS PER SECTION", UDim2.fromOffset(24, 56), UDim2.new(.55, -24, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
	local statusText = text(leaderboardPanel, "OPEN LEADERBOARDS TO LOAD", UDim2.new(.58, 0, 0, 28), UDim2.new(.38, 0, 0, 24), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	statusText.TextXAlignment = Enum.TextXAlignment.Right
	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(22, 92)
	tabs.Size = UDim2.new(1, -44, 0, 92)
	tabs.Parent = leaderboardPanel
	local tabGrid = Instance.new("UIGridLayout")
	tabGrid.CellPadding = UDim2.fromOffset(8, 8)
	tabGrid.CellSize = UDim2.new(1 / 4, -8, 0, 38)
	tabGrid.SortOrder = Enum.SortOrder.LayoutOrder
	tabGrid.Parent = tabs
	local list = Instance.new("ScrollingFrame")
	list.Name = "LeaderboardRows"
	list.BackgroundColor3 = Theme.Colors.Black
	list.BackgroundTransparency = .35
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(22, 204)
	list.Size = UDim2.new(1, -44, 0, 770)
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colors.Electric
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = leaderboardPanel
	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 8)
	listCorner.Parent = list
	local leaderboardData: any = nil
	local activeSection = "Wins"
	local tabButtons: {[string]: TextButton} = {}
	local function clearRows()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
	end
	local function renderBoard(key: string)
		activeSection = key
		for sectionKey, button in tabButtons do
			Button.setPrimary(button, sectionKey == key)
		end
		clearRows()
		local board = leaderboardData and leaderboardData.Boards and leaderboardData.Boards[key]
		local rows = board and board.Rows or {}
		text(list, board and board.Title or "LEADERBOARD", UDim2.fromOffset(16, 14), UDim2.new(.5, 0, 0, 24), 16, Theme.Colors.White, Theme.Fonts.Display)
		local valueLabel = board and board.ValueLabel or "VALUE"
		local valueHeader = text(list, valueLabel, UDim2.new(1, -160, 0, 18), UDim2.fromOffset(130, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
		valueHeader.TextXAlignment = Enum.TextXAlignment.Right
		if not board or board.Error then
			local message = text(list, "LEADERBOARD DATA UNAVAILABLE", UDim2.fromOffset(16, 70), UDim2.new(1, -32, 0, 40), 16, Theme.Colors.Danger, Theme.Fonts.Display)
			message.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		if #rows == 0 then
			local empty = text(list, "NO RANKED RESULTS YET", UDim2.fromOffset(16, 70), UDim2.new(1, -32, 0, 40), 16, Theme.Colors.Muted, Theme.Fonts.Display)
			empty.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		for index, rowData in rows do
			if index > 100 then break end
			local row = Instance.new("Frame")
			row.BackgroundColor3 = index % 2 == 0 and Theme.Colors.Black or Theme.Colors.Raised
			row.BackgroundTransparency = index % 2 == 0 and .45 or .24
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(14, 52 + (index - 1) * 34)
			row.Size = UDim2.new(1, -28, 0, 30)
			row.Parent = list
			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 6)
			rowCorner.Parent = row
			text(row, "#" .. tostring(rowData.Rank or index), UDim2.fromOffset(12, 6), UDim2.fromOffset(54, 18), 9, Theme.Colors.Electric, Theme.Fonts.Display)
			text(row, tostring(rowData.Name or "PLAYER"), UDim2.fromOffset(76, 6), UDim2.new(1, -250, 0, 18), 10, Theme.Colors.White, Theme.Fonts.Strong)
			local value = text(row, formatLeaderboardValue(key, rowData.Value), UDim2.new(1, -146, 0, 6), UDim2.fromOffset(128, 18), 10, Theme.Colors.White, Theme.Fonts.Display)
			value.TextXAlignment = Enum.TextXAlignment.Right
		end
	end
	for index, section in LEADERBOARD_SECTIONS do
		local tab = Button.new({Text = section.Label, Variant = index == 1 and "Primary" or "Secondary", Size = UDim2.new(1, 0, 1, 0), OnActivated = function()
			renderBoard(section.Key)
		end})
		tab.LayoutOrder = index
		tab.Selectable = true
		tab.Parent = tabs
		tabButtons[section.Key] = tab
	end
	local function loadLeaderboards()
		statusText.Text = "LOADING..."
		local response = MatchSetupService:GetRankedLeaderboards()
		if type(response) == "table" and response.Success and type(response.Data) == "table" then
			leaderboardData = response.Data
			statusText.Text = "UPDATED"
			statusText.TextColor3 = Theme.Colors.Muted
		else
			leaderboardData = {Boards = {Wins = {Title = "LEADERBOARDS", Rows = {}, Error = true}}}
			statusText.Text = type(response) == "table" and tostring(response.Message or "UNAVAILABLE") or "UNAVAILABLE"
			statusText.TextColor3 = Theme.Colors.Danger
		end
		renderBoard(activeSection)
	end

	local play = Button.new({Text = "PLAY RANKED", Variant = "Primary", Size = UDim2.fromOffset(218, 54), OnActivated = function()
		inputShield(group, 210)
		local result = MatchSetupService:JoinRankedQueue()
		if type(result) == "table" and result.Success then
			if type(result.Data)=="table" and result.Data.Status=="Matched" then
				RankedQueuePresentation.ShowMatchFound(context.Root,result.Data,function()end)
			else
				RankedQueuePresentation.StartSearching(context.Root)
			end
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
	play.Selectable = true

	local showingLeaderboards = false
	local leaderboardsButton: TextButton
	leaderboardsButton = Button.new({Text = "LEADERBOARDS", Variant = "Secondary", Size = UDim2.fromOffset(218, 54), OnActivated = function()
		showingLeaderboards = not showingLeaderboards
		for _, object in mainObjects do
			object.Visible = not showingLeaderboards
		end
		leaderboardPanel.Visible = showingLeaderboards
		play.Visible = not showingLeaderboards
		leaderboardsButton.Text = showingLeaderboards and "RANKED OVERVIEW" or "LEADERBOARDS"
		if showingLeaderboards and not leaderboardData then
			loadLeaderboards()
		end
	end})
	leaderboardsButton.Name = "RankedLeaderboardsButton"
	leaderboardsButton.AnchorPoint = Vector2.new(0, 1)
	leaderboardsButton.Position = UDim2.new(0, 26, 1, -24)
	leaderboardsButton.ZIndex = 24
	leaderboardsButton.Selectable = true
	leaderboardsButton.Parent = group

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
