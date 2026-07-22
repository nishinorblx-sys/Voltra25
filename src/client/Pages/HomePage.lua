--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local CampaignConfig = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local ProgressBar = require(script.Parent.Parent.Components.ProgressBar)
local SquadService = require(script.Parent.Parent.Services.SquadService)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)
local PageBase = require(script.Parent.PageBase)

local HomePage = {}

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
	label.Parent = parent
	return label
end

local function stat(parent: Instance, title: string, value: string, position: UDim2)
	local card = Panel.new({Name = title, Position = position, Size = UDim2.new(.25, -9, 0, 96)})
	card.Parent = parent
	text(card, title, UDim2.fromOffset(14, 12), UDim2.new(1, -28, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
	local valueLabel = text(card, value, UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 36), 24, Theme.Colors.White, Theme.Fonts.Display)
	valueLabel.TextScaled = true
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 11
	constraint.MaxTextSize = 24
	constraint.Parent = valueLabel
	return card
end

local function ascensionSummary(campaign: any): (string, string, string)
	campaign = type(campaign) == "table" and campaign or {}
	local placement = type(campaign.Placement) == "table" and campaign.Placement or {}
	local season = type(campaign.ActiveSeason) == "table" and campaign.ActiveSeason or nil
	local divisionId = season and season.DivisionId or placement.AssignedDivision
	if not divisionId then
		local division = CampaignConfig.Divisions[math.clamp(tonumber(campaign.HighestUnlockedDivision) or 1, 1, #CampaignConfig.Divisions)]
		divisionId = division and division.Id
	end
	local definition = CampaignConfig.GetDivision(divisionId)
	local divisionName = definition and definition.Name or "PLACEMENT"
	local project = type(campaign.ActiveProject) == "table" and campaign.ActiveProject or nil
	local detail = project and (tostring(project.PlayerName or "PROJECT PLAYER") .. "  /  " .. tostring(project.XP or 0) .. " XP") or "NO ACTIVE CLUB PROJECT"
	if campaign.HasPendingMatch == true then return divisionName, "RESUME MATCH", detail end
	if placement.Completed ~= true then return divisionName, "PLAY PLACEMENT", detail end
	if not season then return divisionName, "START FIRST SEASON", detail end
	if season.PendingProjectUpgrade then return divisionName, "CHOOSE PROJECT UPGRADE", detail end
	if season.PendingPromotionChoice then return divisionName, "CHOOSE YOUR SIGNING", detail end
	if season.Status == "Promoted" then return divisionName, "START NEXT DIVISION", detail end
	if season.Status == "Failed" then return divisionName, "START NEW SEASON", detail end
	if season.Status == "Preseason" and not season.ScoutingFocus then return divisionName, "CHOOSE SCOUTING FOCUS", detail end
	if season.Status == "Preseason" and not season.ProjectDecision then return divisionName, "SELECT CLUB PROJECT", detail end
	local action = season.Status == "PromotionFinal" and "PLAY PROMOTION FINAL" or season.Status == "Recovery" and "PLAY RECOVERY MATCH" or "PLAY NEXT FIXTURE"
	return divisionName, action, tostring(season.Points or 0) .. " PTS  /  " .. detail
end

local function rankedRunSummary(run: any): (string, number)
	local results = type(run.Results) == "table" and run.Results or {}
	local wins = 0
	local draws = 0
	local losses = 0
	for _, value in results do
		if value == "Win" then wins += 1 elseif value == "Draw" then draws += 1 elseif value == "Loss" then losses += 1 end
	end
	if #results == 0 then
		wins = tonumber(run.Wins) or 0
		draws = tonumber(run.Draws) or 0
		losses = tonumber(run.Losses) or 0
	end
	local games = math.clamp(#results > 0 and #results or wins + draws + losses, 0, 7)
	return tostring(games) .. "/7  " .. tostring(wins) .. "W - " .. tostring(draws) .. "D - " .. tostring(losses) .. "L", games / 7
end

local function firstSessionHome(context: any, progression: any): Frame
	local progress = type(progression.PlayabilityProgress) == "table" and progression.PlayabilityProgress or {}
	local worldCup = type(progression.WorldCupSummary) == "table" and progression.WorldCupSummary or {}
	local completed = math.max(0, math.floor(tonumber(progress.CompletedMatches) or 0))
	local country = tostring(worldCup.Country or "")
	local opponent = tostring(worldCup.Opponent or "")
	local group, scroll = PageBase.new("Home", 700)
	PageBase.heading(scroll, "VOLTRA WORLD CUP", "YOUR NEXT FOOTBALL MOMENT", "Choose your country, learn the pitch, and keep the run moving.")

	local hero = Panel.new({Name = "FirstSessionHomeHero", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 310)})
	hero.Parent = scroll
	text(hero, country ~= "" and string.upper(country) or "CHOOSE YOUR COUNTRY", UDim2.fromOffset(28, 28), UDim2.new(.68, -28, 0, 48), 34, Theme.Colors.White, Theme.Fonts.Display)
	text(hero, "VOLTRA WORLD CUP", UDim2.fromOffset(30, 78), UDim2.new(.6, 0, 0, 18), 10, Theme.Colors.Electric, Theme.Fonts.Strong)
	local matchup = if opponent ~= "" then string.upper(country) .. "  VS  " .. string.upper(opponent) else "YOUR WORLD CUP STARTS HERE"
	text(hero, matchup, UDim2.fromOffset(30, 122), UDim2.new(1, -60, 0, 34), 19, Theme.Colors.Silver, Theme.Fonts.Display)
	local stage = tostring(worldCup.Stage or "GROUP STAGE"):gsub("(%l)(%u)", "%1 %2")
	local matchday = tonumber(worldCup.Matchday) or 0
	text(hero, string.upper(stage) .. (matchday > 0 and "  /  MATCHDAY " .. tostring(matchday) or ""), UDim2.fromOffset(30, 160), UDim2.new(1, -60, 0, 20), 10, Theme.Colors.Muted, Theme.Fonts.Strong)
	local objective = if completed == 0 then "MATCH 1  /  EARN YOUR FIRST PLAYER"
		elseif completed == 1 then "MATCH 2  /  UNLOCK SQUAD + INVENTORY"
		elseif completed == 2 then "MATCH 3  /  UNLOCK PACKS + CHEMISTRY + ASCENSION"
		else "CONTINUE THE RUN  /  COMPLETE IT TO UNLOCK RANKED"
	text(hero, objective, UDim2.fromOffset(30, 205), UDim2.new(.58, 0, 0, 22), 11, Theme.Colors.White, Theme.Fonts.Strong)
	local progressBar = ProgressBar.new(math.clamp(completed / 3, 0, 1))
	progressBar.Position = UDim2.fromOffset(30, 240)
	progressBar.Size = UDim2.new(.52, 0, 0, 7)
	progressBar.Parent = hero
	text(hero, tostring(math.min(completed, 3)) .. " / 3 INTRO MATCHES", UDim2.fromOffset(30, 256), UDim2.new(.52, 0, 0, 18), 8, Theme.Colors.Muted, Theme.Fonts.Strong)

	local busy = false
	local playButton: TextButton
	playButton = Button.new({Text = worldCup.Active == true and worldCup.Complete ~= true and "PLAY NEXT WORLD CUP MATCH" or "OPEN WORLD CUP", Variant = "Primary", Size = UDim2.fromOffset(250, 54), OnActivated = function()
		if busy then return end
		if worldCup.Active ~= true or worldCup.Complete == true then context.Navigate("WorldCup"); return end
		busy = true
		playButton.Text = "LOADING MATCH..."
		task.spawn(function()
			local result = MatchSetupService:StartWorldCupMatch()
			if not result or result.Success ~= true then
				busy = false
				playButton.Text = "PLAY NEXT WORLD CUP MATCH"
				context.Toast({Title = "WORLD CUP", Message = result and result.Message or "The match could not start. Try again.", Kind = "Error"})
			end
		end)
	end})
	playButton.AnchorPoint = Vector2.new(1, 1)
	playButton.Position = UDim2.new(1, -28, 1, -28)
	playButton.Parent = hero

	if progress.FirstRewardGranted == true and tostring(progress.FirstRewardCardInstanceId or "") ~= "" then
		local reward = Panel.new({Name = "FirstMatchReward", Position = UDim2.fromOffset(0, 426), Size = UDim2.new(1, 0, 0, 132)})
		reward.Parent = scroll
		text(reward, "FIRST MATCH REWARD", UDim2.fromOffset(22, 18), UDim2.new(.5, 0, 0, 20), 10, Theme.Colors.Electric, Theme.Fonts.Strong)
		text(reward, string.upper(tostring(progress.FirstRewardPlayerName or "STARTER PLAYER")), UDim2.fromOffset(22, 45), UDim2.new(.55, 0, 0, 30), 20, Theme.Colors.White, Theme.Fonts.Display)
		text(reward, "Added to your reserves to improve the club.", UDim2.fromOffset(22, 79), UDim2.new(.62, 0, 0, 22), 9, Theme.Colors.Silver, Theme.Fonts.Strong)
		local view = Button.new({Text = "VIEW PLAYER", Variant = "Secondary", Size = UDim2.fromOffset(170, 42), OnActivated = function()
			context.OpenPlayerDetails(tostring(progress.FirstRewardCardInstanceId))
		end})
		view.AnchorPoint = Vector2.new(1, .5)
		view.Position = UDim2.new(1, -22, .5, 0)
		view.Parent = reward
	end
	return group
end

function HomePage.new(context: any): Frame
	local profile = context.Data.Profile
	local progression = context.Data.Progression
	local playability = type(progression.PlayabilityProgress) == "table" and progression.PlayabilityProgress or {}
	if playability.FirstWorldCupRunCompleted ~= true and playability.LegacyAccessGranted ~= true then
		return firstSessionHome(context, progression)
	end
	local campaign = progression.CampaignProgress or {}
	local ascensionDivision, ascensionAction, ascensionDetail = ascensionSummary(campaign)
	local rankedRun = progression.RankedRun or {Wins = 0, Losses = 0}
	local rankedSummary, rankedProgress = rankedRunSummary(rankedRun)
	local squadResponse = SquadService:GetSquad()
	local squad = squadResponse.Success and squadResponse.Data or {Rating = 0, Chemistry = 0, TeamName = "NO CLUB"}
	local unopened = 0
	for _, pack in progression.PackInventory or {} do if (pack.status or pack.Status) == "unopened" then unopened += 1 end end
	local group, scroll = PageBase.new("Home", 790)
	PageBase.heading(scroll, "VTR X", "WELCOME BACK, " .. string.upper(profile.Username), "Develop your club through Ascension, then prove it on the World Cup and Ranked stages.")

	local hero = Panel.new({Name = "LiteDashboard", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 242)})
	hero.Parent = scroll
	local membership = type(progression.ClubMembership) == "table" and progression.ClubMembership or {}
	text(hero, string.upper(squad.TeamName or membership.Name or "YOUR CLUB"), UDim2.fromOffset(24, 20), UDim2.new(.55, 0, 0, 36), 28, Theme.Colors.White, Theme.Fonts.Display)
	text(hero, "VOLTRA CLUB DASHBOARD", UDim2.fromOffset(26, 60), UDim2.new(.5, 0, 0, 18), 9, Theme.Colors.Electric, Theme.Fonts.Strong)
	stat(hero, "TEAM OVR", tostring(squad.Rating or 0), UDim2.fromOffset(24, 100))
	stat(hero, "CHEMISTRY", tostring(squad.Chemistry or 0), UDim2.new(.25, 24, 0, 100))
	stat(hero, "ASCENSION", ascensionDivision, UDim2.new(.5, 24, 0, 100))
	stat(hero, "PACKS", tostring(unopened), UDim2.new(.75, 24, 0, 100))
	local ranked = text(hero, "RANKED PATH  " .. rankedSummary, UDim2.new(.62, 0, 0, 26), UDim2.new(.34, 0, 0, 24), 11, Theme.Colors.Electric, Theme.Fonts.Strong)
	ranked.TextXAlignment = Enum.TextXAlignment.Right
	local runBar = ProgressBar.new(rankedProgress)
	runBar.Position = UDim2.new(.62, 0, 0, 58)
	runBar.Size = UDim2.new(.34, 0, 0, 7)
	runBar.Parent = hero
	text(hero, ascensionDetail, UDim2.new(.5, 24, 1, -34), UDim2.new(.5, -48, 0, 18), 8, Theme.Colors.Silver, Theme.Fonts.Strong)

	local quick = Panel.new({Name = "QuickButtons", Position = UDim2.fromOffset(0, 356), Size = UDim2.new(.46, -8, 0, 278)})
	quick.Parent = scroll
	text(quick, "QUICK START", UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 22), 12, Theme.Colors.Electric, Theme.Fonts.Strong)
	local actions = {
		{ascensionAction, "Campaign"},
		{"WORLD CUP", "WorldCup"},
		{"ENTER RANKED", "Ranked"},
		{"OPEN PACKS", "Inventory"},
		{"EDIT SQUAD", "UltimateTeam"},
		{"VIEW STORE", "Store"},
	}
	for index, action in actions do
		local button = Button.new({Text = action[1], Variant = index == 1 and "Primary" or "Secondary", Size = UDim2.new(.5, -25, 0, 44), OnActivated = function()
			if action[2] == "Inventory" then context.Data.UIState.SelectedTabs.Inventory = "Packs"; context.StateService:SetTab("Inventory", "Packs") end
			context.Navigate(action[2])
		end})
		button.Position = UDim2.new((index - 1) % 2 * .5, 18, 0, 52 + math.floor((index - 1) / 2) * 58)
		button.Parent = quick
	end

	local objectives = Panel.new({Name = "StarterObjectives", Position = UDim2.new(.46, 8, 0, 356), Size = UDim2.new(.54, -8, 0, 278)})
	objectives.Parent = scroll
	text(objectives, "STARTER OBJECTIVES", UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 22), 12, Theme.Colors.Electric, Theme.Fonts.Strong)
	local y = 48
	for _, objective in context.Data.Objectives do
		if objective.groupId == "starter_journey" then
			local status = string.upper(tostring(objective.status or "active"))
			text(objectives, objective.title .. "  /  " .. status, UDim2.fromOffset(18, y), UDim2.new(.56, 0, 0, 20), 10, Theme.Colors.White, Theme.Fonts.Strong)
			text(objectives, tostring(objective.progress or 0) .. " / " .. tostring(objective.target or 1), UDim2.new(.78, 0, 0, y), UDim2.new(.16, 0, 0, 20), 9, Theme.Colors.Silver, Theme.Fonts.Strong).TextXAlignment = Enum.TextXAlignment.Right
			y += 28
			if y > 180 then break end
		end
	end
	return group
end

return HomePage
