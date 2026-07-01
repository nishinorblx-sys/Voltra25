--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local LiteConfig = require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local ProgressBar = require(script.Parent.Parent.Components.ProgressBar)
local SquadService = require(script.Parent.Parent.Services.SquadService)
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
	text(card, value, UDim2.fromOffset(14, 38), UDim2.new(1, -28, 0, 36), 24, Theme.Colors.White, Theme.Fonts.Display)
	return card
end

function HomePage.new(context: any): CanvasGroup
	local profile = context.Data.Profile
	local progression = context.Data.Progression
	local campaign = progression.CampaignProgress or {UnlockedDifficulty = 1, CompletedTeams = {}}
	local rankedRun = progression.RankedRun or {Wins = 0, Losses = 0}
	local squadResponse = SquadService:GetSquad()
	local squad = squadResponse.Success and squadResponse.Data or {Rating = 0, Chemistry = 0, TeamName = "NO CLUB"}
	local unopened = 0
	for _, pack in progression.PackInventory or {} do if (pack.status or pack.Status) == "unopened" then unopened += 1 end end
	local difficulty = LiteConfig.CampaignDifficulties[math.clamp(tonumber(campaign.UnlockedDifficulty) or 1, 1, #LiteConfig.CampaignDifficulties)]
	local group, scroll = PageBase.new("Home", 720)
	PageBase.heading(scroll, "VTR LITE", "WELCOME BACK, " .. string.upper(profile.Username), "Build your squad through Campaign, open packs, then chase the seven-win Ranked tournament.")

	local hero = Panel.new({Name = "LiteDashboard", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 242)})
	hero.Parent = scroll
	text(hero, string.upper(squad.TeamName or progression.ClubMembership.Name or "YOUR CLUB"), UDim2.fromOffset(24, 20), UDim2.new(.55, 0, 0, 36), 28, Theme.Colors.White, Theme.Fonts.Display)
	text(hero, "VTR LITE CLUB DASHBOARD", UDim2.fromOffset(26, 60), UDim2.new(.5, 0, 0, 18), 9, Theme.Colors.White, Theme.Fonts.Strong)
	stat(hero, "TEAM OVR", tostring(squad.Rating or 0), UDim2.fromOffset(24, 100))
	stat(hero, "CHEMISTRY", tostring(squad.Chemistry or 0), UDim2.new(.25, 24, 0, 100))
	stat(hero, "CAMPAIGN", difficulty.Name, UDim2.new(.5, 24, 0, 100))
	stat(hero, "PACKS", tostring(unopened), UDim2.new(.75, 24, 0, 100))
	local ranked = text(hero, "RANKED RUN  " .. tostring(rankedRun.Wins or 0) .. "W - " .. tostring(rankedRun.Losses or 0) .. "L", UDim2.new(.62, 0, 0, 26), UDim2.new(.34, 0, 0, 24), 11, Theme.Colors.White, Theme.Fonts.Strong)
	ranked.TextXAlignment = Enum.TextXAlignment.Right
	local runBar = ProgressBar.new((tonumber(rankedRun.Wins) or 0) / 7)
	runBar.Position = UDim2.new(.62, 0, 0, 58)
	runBar.Size = UDim2.new(.34, 0, 0, 7)
	runBar.Parent = hero

	local quick = Panel.new({Name = "QuickButtons", Position = UDim2.fromOffset(0, 356), Size = UDim2.new(.46, -8, 0, 220)})
	quick.Parent = scroll
	text(quick, "QUICK START", UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 22), 12, Theme.Colors.White, Theme.Fonts.Strong)
	local actions = {
		{"CONTINUE CAMPAIGN", "Play"},
		{"OPEN PACKS", "Inventory"},
		{"EDIT SQUAD", "UltimateTeam"},
		{"ENTER RANKED", "Ranked"},
	}
	for index, action in actions do
		local button = Button.new({Text = action[1], Variant = index == 1 and "Primary" or "Secondary", Size = UDim2.new(.5, -25, 0, 44), OnActivated = function()
			if action[2] == "Inventory" then context.Data.UIState.SelectedTabs.Inventory = "Packs"; context.StateService:SetTab("Inventory", "Packs") end
			context.Navigate(action[2])
		end})
		button.Position = UDim2.new((index - 1) % 2 * .5, 18, 0, 52 + math.floor((index - 1) / 2) * 58)
		button.Parent = quick
	end

	local objectives = Panel.new({Name = "StarterObjectives", Position = UDim2.new(.46, 8, 0, 356), Size = UDim2.new(.54, -8, 0, 220)})
	objectives.Parent = scroll
	text(objectives, "STARTER OBJECTIVES", UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 22), 12, Theme.Colors.White, Theme.Fonts.Strong)
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
