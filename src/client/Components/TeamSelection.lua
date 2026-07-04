--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)
local Button = require(script.Parent.Button)
local Panel = require(script.Parent.Panel)
local BadgePreview = require(script.Parent.BadgePreview)
local TeamRosterModal = require(script.Parent.TeamRosterModal)

local TeamSelection = {}

local function label(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local item = Instance.new("TextLabel"); item.BackgroundTransparency = 1; item.Position = position; item.Size = size
	item.Text = value; item.TextColor3 = color; item.TextSize = textSize; item.Font = font; item.TextXAlignment = Enum.TextXAlignment.Left; item.Parent = parent; return item
end

local function findTeam(teams: { any }, id: string): any?
	for _, team in teams do if team.teamId == id then return team end end; return nil
end

local function badgeIdentity(team: any): any
	local colors = team.colors or {}
	local identity = team.BadgeIdentity or team.badgeIdentity or {}
	return {
		PrimaryColor = identity.PrimaryColor or colors.Primary or "B7FF1A",
		SecondaryColor = identity.SecondaryColor or colors.Secondary or "050505",
		AccentColor = identity.AccentColor or colors.Accent or colors.Secondary or "D9D9D9",
		BadgePreset = identity.BadgePreset or team.badgePreset or "Modern",
		BadgeShape = identity.BadgeShape or (team.badgePreset == "GeneratedHex" and "Hex" or "Shield"),
		BadgeSymbol = identity.BadgeSymbol or "Volt V",
		BadgeColorBehavior = identity.BadgeColorBehavior or "Tri Color",
	}
end

function TeamSelection.new(parent: Instance, props: any): Frame
	local root = Instance.new("Frame"); root.Name = "CountryLeagueTeamSelection"; root.BackgroundTransparency = 1; root.Size = UDim2.new(1, 0, 0, 500); root.Parent = parent
	local allKnownTeams = table.clone(props.Teams)
	local currentSide = "HOME"
	local selectedBySide = { HOME = findTeam(allKnownTeams, props.Setup.HomeTeamId), AWAY = findTeam(allKnownTeams, props.Setup.AwayTeamId) }
	local defaultCountryRecord = props.Countries[1]
	for _, record in props.Countries do
		if record.Country == "England" then defaultCountryRecord = record; break end
	end
	local defaultCountry = defaultCountryRecord and defaultCountryRecord.Country or props.Countries[1].Country
	local defaultLeague = defaultCountryRecord and defaultCountryRecord.Leagues[1] or props.Countries[1].Leagues[1]
	local countryBySide = { HOME = selectedBySide.HOME and selectedBySide.HOME.country or defaultCountry, AWAY = selectedBySide.AWAY and selectedBySide.AWAY.country or defaultCountry }
	local leagueBySide = { HOME = selectedBySide.HOME and selectedBySide.HOME.league or defaultLeague, AWAY = selectedBySide.AWAY and selectedBySide.AWAY.league or defaultLeague }
	local catalogs: { [string]: { any } } = {}; local searchText = ""; local sortMode = "RATING"; local preview = selectedBySide.HOME
	local content = Instance.new("Frame"); content.BackgroundTransparency = 1; content.Position = UDim2.fromOffset(0, 48); content.Size = UDim2.new(1, 0, 1, -48); content.Parent = root
	local render: () -> ()

	local function countryRecord(country: string): any?
		for _, record in props.Countries do if record.Country == country then return record end end; return nil
	end
	local function load(country: string, league: string): { any }
		local key = country .. "\0" .. league
		if catalogs[key] then return catalogs[key] end
		local response = MatchSetupService:GetTeams(country, league)
		if not response.Success then props.OnError(response.Message or "Team catalog unavailable."); return {} end
		catalogs[key] = response.Data
		for _, team in response.Data do if not findTeam(allKnownTeams, team.teamId) then table.insert(allKnownTeams, team) end end
		return catalogs[key]
	end

	local function choiceModal(title: string, values: { string }, onChoose: (string) -> ())
		local overlay = Instance.new("TextButton"); overlay.AutoButtonColor = false; overlay.Selectable = false; overlay.Text = ""; overlay.BackgroundColor3 = Theme.Colors.Black; overlay.BackgroundTransparency = .18; overlay.BorderSizePixel = 0; overlay.Size = UDim2.fromScale(1, 1); overlay.ZIndex = 120; overlay.Parent = root
		local modal = Panel.new({ Name = "ChoiceModal", Size = UDim2.fromOffset(430, 410) }); modal.AnchorPoint = Vector2.new(.5, .5); modal.Position = UDim2.fromScale(.5, .5); modal.ZIndex = 121; modal.Parent = overlay
		label(modal, title, UDim2.fromOffset(18, 14), UDim2.new(1, -128, 0, 28), 17, Theme.Colors.White, Theme.Fonts.Display).ZIndex = 123
		local close = Button.new({ Text = "CLOSE", Variant = "Secondary", Size = UDim2.fromOffset(90, 32), OnActivated = function() overlay:Destroy() end }); close.Position = UDim2.new(1, -108, 0, 14); close.ZIndex = 124; close.Parent = modal
		local search = Instance.new("TextBox"); search.PlaceholderText = "SEARCH"; search.Text = ""; search.ClearTextOnFocus = false; search.BackgroundColor3 = Theme.Colors.Gunmetal; search.BorderSizePixel = 0; search.TextColor3 = Theme.Colors.White; search.PlaceholderColor3 = Theme.Colors.Muted; search.Font = Theme.Fonts.Strong; search.TextSize = 10; search.Position = UDim2.fromOffset(18, 58); search.Size = UDim2.new(1, -36, 0, 36); search.ZIndex = 124; search.Parent = modal
		local list = Instance.new("ScrollingFrame"); list.BackgroundTransparency = 1; list.BorderSizePixel = 0; list.Position = UDim2.fromOffset(18, 106); list.Size = UDim2.new(1, -36, 1, -124); list.AutomaticCanvasSize = Enum.AutomaticSize.Y; list.CanvasSize = UDim2.new(); list.ScrollBarThickness = 3; list.ScrollBarImageColor3 = Theme.Colors.Electric; list.ZIndex = 123; list.Parent = modal
		local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = list
		local function populate()
			for _, child in list:GetChildren() do if child:IsA("GuiButton") then child:Destroy() end end
			local query = string.lower(search.Text)
			for _, value in values do if query == "" or string.find(string.lower(value), query, 1, true) then
				local choice = Button.new({ Text = value, Variant = "Secondary", Size = UDim2.new(1, -6, 0, 34), OnActivated = function() overlay:Destroy(); onChoose(value) end }); choice.ZIndex = 124; choice.Parent = list
			end end
		end
		search:GetPropertyChangedSignal("Text"):Connect(populate); populate()
	end

	local function sideButton(side: string, position: UDim2)
		local selected = side == currentSide
		local team = selectedBySide[side]
		local button = Button.new({ Text = side .. "  /  " .. (team and team.teamName or "SELECT TEAM"), Variant = selected and "Primary" or "Secondary", Size = UDim2.new(.5, -5, 0, 38), OnActivated = function() currentSide = side; preview = selectedBySide[side]; render() end })
		button.Position = position; button.Parent = root
	end

	render = function()
		for _, child in content:GetChildren() do child:Destroy() end
		for _, child in root:GetChildren() do if child:IsA("GuiButton") and child.Name ~= "RosterOverlay" then child:Destroy() end end
		sideButton("HOME", UDim2.fromOffset(0, 0)); sideButton("AWAY", UDim2.new(.5, 5, 0, 0))
		local country = countryBySide[currentSide]; local league = leagueBySide[currentSide]
		local countryButton = Button.new({ Text = "COUNTRY  /  " .. country, Variant = "Secondary", Size = UDim2.new(.34, -6, 0, 38), OnActivated = function()
			local values = {}; for _, record in props.Countries do table.insert(values, record.Country) end
			choiceModal("SELECT COUNTRY", values, function(value)
				countryBySide[currentSide] = value; local record = countryRecord(value); leagueBySide[currentSide] = record and record.Leagues[1] or ""; searchText = ""; preview = nil; render()
			end)
		end }); countryButton.Position = UDim2.fromOffset(0, 0); countryButton.Parent = content
		local leagueButton = Button.new({ Text = "LEAGUE  /  " .. league, Variant = "Secondary", Size = UDim2.new(.34, -6, 0, 38), OnActivated = function()
			local record = countryRecord(country); choiceModal("SELECT LEAGUE / CIRCUIT", record and record.Leagues or {}, function(value) leagueBySide[currentSide] = value; searchText = ""; preview = nil; render() end)
		end }); leagueButton.Position = UDim2.new(.34, 6, 0, 0); leagueButton.Parent = content
		local sort = Button.new({ Text = "SORT  /  " .. sortMode, Variant = "Secondary", Size = UDim2.new(.32, -6, 0, 38), OnActivated = function() sortMode = sortMode == "RATING" and "NAME" or "RATING"; render() end }); sort.Position = UDim2.new(.68, 12, 0, 0); sort.Parent = content

		local search = Instance.new("TextBox"); search.Name = "TeamSearch"; search.PlaceholderText = "SEARCH TEAM"; search.Text = searchText; search.ClearTextOnFocus = false; search.BackgroundColor3 = Theme.Colors.Gunmetal; search.BorderSizePixel = 0; search.TextColor3 = Theme.Colors.White; search.PlaceholderColor3 = Theme.Colors.Muted; search.Font = Theme.Fonts.Strong; search.TextSize = 10; search.Position = UDim2.fromOffset(0, 50); search.Size = UDim2.new(.54, -8, 0, 36); search.Parent = content
		local listPanel = Panel.new({ Name = "TeamList", Position = UDim2.fromOffset(0, 98), Size = UDim2.new(.54, -8, 1, -98) }); listPanel.Parent = content
		local scroll = Instance.new("ScrollingFrame"); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.Position = UDim2.fromOffset(10, 10); scroll.Size = UDim2.new(1, -20, 1, -20); scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(); scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = Theme.Colors.Electric; scroll.Parent = listPanel
		local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = scroll
		local catalog = table.clone(load(country, league)); local query = string.lower(searchText)
		table.sort(catalog, function(a, b) if sortMode == "NAME" then return a.teamName < b.teamName elseif a.overall == b.overall then return a.teamName < b.teamName else return a.overall > b.overall end end)
		for _, team in catalog do if query == "" or string.find(string.lower(team.teamName), query, 1, true) then
			local row = Button.new({ Text = string.format("%s     OVR %d", team.teamName, team.overall), Variant = preview and preview.teamId == team.teamId and "Primary" or "Secondary", Size = UDim2.new(1, -5, 0, 38), OnActivated = function() preview = team; render() end }); row.Parent = scroll
		end end
		search.FocusLost:Connect(function() searchText = search.Text; render() end)

		local details = Panel.new({ Name = "TeamDetails", Position = UDim2.new(.54, 8, 0, 50), Size = UDim2.new(.46, -8, 1, -50) }); details.Parent = content
		if not preview then label(details, "SELECT A TEAM", UDim2.fromScale(0, .35), UDim2.fromScale(1, .2), 16, Theme.Colors.Muted, Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Center; return end
		local badge = BadgePreview.new(details, badgeIdentity(preview), UDim2.fromOffset(86, 86))
		badge.Position = UDim2.fromOffset(18, 16)
		badge.ZIndex = 6
		local logo = label(badge, preview.logo or "", UDim2.fromScale(.18, .37), UDim2.fromScale(.64, .22), 10, Theme.Colors.White, Theme.Fonts.Display)
		logo.TextXAlignment = Enum.TextXAlignment.Center
		logo.ZIndex = 8
		label(details, preview.teamName, UDim2.fromOffset(124, 18), UDim2.new(1, -142, 0, 42), 18, Theme.Colors.White, Theme.Fonts.Display)
		label(details, preview.country .. "  /  " .. preview.league, UDim2.fromOffset(124, 62), UDim2.new(1, -142, 0, 20), 8, Theme.Colors.Muted, Theme.Fonts.Strong)
		label(details, string.format("OVR  %d     ATT  %d     MID  %d     DEF  %d", preview.overall, preview.attack, preview.midfield, preview.defense), UDim2.fromOffset(18, 112), UDim2.new(1, -36, 0, 30), 12, Theme.Colors.White, Theme.Fonts.Display)
		label(details, "FORMATION  /  " .. preview.formation, UDim2.fromOffset(18, 150), UDim2.new(1, -36, 0, 20), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
		local stars = {}; for _, player in preview.starPlayers do table.insert(stars, string.format("%d  %s  /  %s", player.overall, player.displayName, player.bestPosition)) end
		label(details, "STAR PLAYERS", UDim2.fromOffset(18, 192), UDim2.new(1, -36, 0, 18), 8, Theme.Colors.Electric, Theme.Fonts.Strong)
		label(details, table.concat(stars, "\n"), UDim2.fromOffset(18, 216), UDim2.new(1, -36, 0, 74), 9, Theme.Colors.Silver, Theme.Fonts.Strong)
		local roster = Button.new({ Text = "VIEW FULL ROSTER", Variant = "Secondary", Size = UDim2.new(1, -36, 0, 38), OnActivated = function() TeamRosterModal.open(preview.teamId, props.OnError) end }); roster.Position = UDim2.new(0, 18, 1, -92); roster.Parent = details
		local selectButton = Button.new({ Text = "SELECT AS " .. currentSide, Variant = "Primary", Size = UDim2.new(1, -36, 0, 40), OnActivated = function()
			local other = currentSide == "HOME" and selectedBySide.AWAY or selectedBySide.HOME
			if other and other.teamId == preview.teamId and props.Setup.MatchType ~= "Friendly" then props.OnError("Mirror matches are only available in Friendly mode."); return end
			selectedBySide[currentSide] = preview; props.OnSelect(currentSide, preview)
		end }); selectButton.Position = UDim2.new(0, 18, 1, -46); selectButton.Parent = details
	end

	render(); return root
end

return TeamSelection
