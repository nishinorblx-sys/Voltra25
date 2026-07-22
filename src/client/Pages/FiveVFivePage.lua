--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local PageBase = require(script.Parent.PageBase)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)

local Page = {}

local function text(parent: Instance, value: string, pos: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = pos
	label.Size = size
	label.Text = value
	label.TextColor3 = color
	label.TextSize = textSize
	label.Font = font
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function box(parent: Instance, value: string, pos: UDim2, size: UDim2): TextBox
	local item = Instance.new("TextBox")
	item.BackgroundColor3 = Theme.Colors.Gunmetal
	item.BorderSizePixel = 0
	item.ClearTextOnFocus = false
	item.Position = pos
	item.Size = size
	item.Font = Theme.Fonts.Strong
	item.Text = value
	item.PlaceholderText = value
	item.TextColor3 = Theme.Colors.White
	item.TextSize = 11
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = item
	return item
end

local function toast(context: any, message: string, kind: string?)
	if context and context.Toast then context.Toast({Title = "5V5", Message = message, Kind = kind or "Info"}) end
end

local function displayName(entry: any): string
	return tostring(type(entry) == "table" and (entry.DisplayName or entry.Name) or entry or "Player")
end

local function teamText(lobby: any, team: string): string
	local assigned = lobby and lobby[team]
	local players = lobby and lobby.Players or {}
	local names = {}
	for _, player in players do
		local userId = tonumber(player.UserId)
		if type(assigned) == "table" and userId and (assigned[userId] or assigned[tostring(userId)]) then table.insert(names, displayName(player)) end
	end
	return #names > 0 and table.concat(names, " / ") or "None assigned"
end

local function assignedTeam(lobby: any, userId: any): string?
	local id = tonumber(userId)
	if not id then return nil end
	local home = type(lobby and lobby.Home) == "table" and lobby.Home or {}
	local away = type(lobby and lobby.Away) == "table" and lobby.Away or {}
	if home[id] or home[tostring(id)] then return "Home" end
	if away[id] or away[tostring(id)] then return "Away" end
	return nil
end

local function teamCount(lobby: any, team: string): number
	local assigned = type(lobby and lobby[team]) == "table" and lobby[team] or {}
	local players = type(lobby and lobby.Players) == "table" and lobby.Players or {}
	local count = 0
	for _, player in players do
		local userId = tonumber(player.UserId)
		if userId and (assigned[userId] or assigned[tostring(userId)]) then count += 1 end
	end
	return count
end

local function canStartLobby(lobby: any): boolean
	local teamSize = tonumber(lobby and lobby.TeamSize) or 5
	return teamCount(lobby, "Home") == teamSize and teamCount(lobby, "Away") == teamSize
end

local function currentLobbyId(current: any): string
	local status = tostring(current and current.Status or "")
	if status ~= "Hosting" and status ~= "InLobby" then
		return ""
	end
	return tostring(current.LobbyId or "")
end

function Page.new(context: any): Frame
	local group, scroll = PageBase.new("FiveVFive", 900)
	PageBase.heading(scroll, "ONLINE MODE", "PLAY", "Host 3v3/4v4/5v5 lobbies, browse servers, assign teams, and start when ready.")

	local busy = false
	local selectedSize = 5
	local openJoin = true
	local current: any = {}
	local lobbyList: {any} = {}
	local refresh: (() -> ())? = nil

	local host = Panel.new({Name = "FiveVFiveHost", Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 178)})
	host.Parent = scroll
	text(host, "HOST LOBBY", UDim2.fromOffset(22, 16), UDim2.new(.3, 0, 0, 30), 22, Theme.Colors.White, Theme.Fonts.Display)
	local nameBox = box(host, "My 5v5 Lobby", UDim2.fromOffset(22, 62), UDim2.fromOffset(220, 36))
	local passBox = box(host, "", UDim2.fromOffset(254, 62), UDim2.fromOffset(150, 36))
	passBox.PlaceholderText = "PASSWORD"
	local sizeButton = Button.new({Text = "5V5", Variant = "Secondary", Size = UDim2.fromOffset(88, 36)})
	sizeButton.Position = UDim2.fromOffset(416, 62)
	sizeButton.Parent = host
	local openButton = Button.new({Text = "OPEN", Variant = "Secondary", Size = UDim2.fromOffset(104, 36)})
	openButton.Position = UDim2.fromOffset(516, 62)
	openButton.Parent = host
	local createButton = Button.new({Text = "CREATE", Variant = "Primary", Size = UDim2.fromOffset(130, 40)})
	createButton.Position = UDim2.new(1, -154, 0, 60)
	createButton.Parent = host
	text(host, "Open lobbies allow instant join. Password lobbies require the password before joining.", UDim2.fromOffset(22, 112), UDim2.new(1, -44, 0, 34), 10, Theme.Colors.Muted, Theme.Fonts.Strong)

	local browser = Panel.new({Name = "FiveVFiveBrowser", Position = UDim2.fromOffset(0, 292), Size = UDim2.new(.48, -8, 0, 560)})
	browser.Parent = scroll
	text(browser, "AVAILABLE SERVERS", UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 28), 20, Theme.Colors.White, Theme.Fonts.Display)
	local searchBox = box(browser, "", UDim2.fromOffset(18, 52), UDim2.new(1, -154, 0, 34))
	searchBox.PlaceholderText = "SEARCH SERVER"
	local searchButton = Button.new({Text = "SEARCH", Variant = "Secondary", Size = UDim2.fromOffset(112, 34)})
	searchButton.Position = UDim2.new(1, -126, 0, 52)
	searchButton.Parent = browser
	local randomButton = Button.new({Text = "RANDOM QUEUE", Variant = "Primary", Size = UDim2.new(1, -36, 0, 38)})
	randomButton.Position = UDim2.fromOffset(18, 96)
	randomButton.Parent = browser
	local listFrame = Instance.new("Frame")
	listFrame.BackgroundTransparency = 1
	listFrame.Position = UDim2.fromOffset(18, 146)
	listFrame.Size = UDim2.new(1, -36, 1, -164)
	listFrame.Parent = browser

	local lobbyPanel = Panel.new({Name = "FiveVFiveLobby", Position = UDim2.new(.48, 8, 0, 292), Size = UDim2.new(.52, -8, 0, 560)})
	lobbyPanel.Parent = scroll
	text(lobbyPanel, "YOUR LOBBY", UDim2.fromOffset(18, 14), UDim2.new(1, -36, 0, 28), 20, Theme.Colors.White, Theme.Fonts.Display)
	local lobbyStatus = text(lobbyPanel, "Not in a lobby.", UDim2.fromOffset(18, 48), UDim2.new(1, -36, 0, 42), 12, Theme.Colors.Silver, Theme.Fonts.Strong)
	local homeLabel = text(lobbyPanel, "HOME: NONE", UDim2.fromOffset(18, 98), UDim2.new(1, -36, 0, 34), 11, Theme.Colors.Electric, Theme.Fonts.Strong)
	local awayLabel = text(lobbyPanel, "AWAY: NONE", UDim2.fromOffset(18, 134), UDim2.new(1, -36, 0, 34), 11, Theme.Colors.White, Theme.Fonts.Strong)
	local playersFrame = Instance.new("Frame")
	playersFrame.BackgroundTransparency = 1
	playersFrame.Position = UDim2.fromOffset(18, 178)
	playersFrame.Size = UDim2.new(1, -36, 0, 260)
	playersFrame.Parent = lobbyPanel
	local leaveButton = Button.new({Text = "LEAVE", Variant = "Secondary", Size = UDim2.fromOffset(120, 40)})
	leaveButton.Position = UDim2.new(1, -270, 1, -58)
	leaveButton.Parent = lobbyPanel
	local startButton = Button.new({Text = "START MATCH", Variant = "Primary", Size = UDim2.fromOffset(140, 40)})
	startButton.Position = UDim2.new(1, -142, 1, -58)
	startButton.Parent = lobbyPanel

	local function renderCurrent(_data: any?) end
	local function renderPlayers()
		for _, child in playersFrame:GetChildren() do child:Destroy() end
		local players = type(current.Players) == "table" and current.Players or {}
		for index, player in ipairs(players) do
			local team = assignedTeam(current, player.UserId)
			local row = Instance.new("Frame")
			row.BackgroundColor3 = team == "Home" and Color3.fromHex("20330D") or team == "Away" and Color3.fromHex("102448") or index % 2 == 0 and Theme.Colors.Gunmetal or Color3.fromHex("101414")
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(0, (index - 1) * 38)
			row.Size = UDim2.new(1, 0, 0, 34)
			row.Parent = playersFrame
			text(row, displayName(player), UDim2.fromOffset(10, 0), UDim2.new(1, -300, 1, 0), 10, Theme.Colors.White, Theme.Fonts.Strong)
			text(row, team and string.upper(team) or "UNASSIGNED", UDim2.new(1, -296, 0, 0), UDim2.fromOffset(78, 34), 8, team == "Home" and Theme.Colors.Electric or team == "Away" and Color3.fromHex("7EB1FF") or Theme.Colors.Muted, Theme.Fonts.Strong)
			if current.IsHost == true then
				local home = Button.new({Text = "HOME", Variant = team == "Home" and "Primary" or "Secondary", Size = UDim2.fromOffset(62, 26)})
				home.Position = UDim2.new(1, -208, 0, 4)
				home.Parent = row
				home.Activated:Connect(function()
					local result = MatchSetupService:AssignFiveVFiveLobbyPlayer({UserId = player.UserId, Team = "Home"})
					if type(result) == "table" then renderCurrent(result.Data) end
				end)
				local away = Button.new({Text = "AWAY", Variant = team == "Away" and "Primary" or "Secondary", Size = UDim2.fromOffset(62, 26)})
				away.Position = UDim2.new(1, -140, 0, 4)
				away.Parent = row
				away.Activated:Connect(function()
					local result = MatchSetupService:AssignFiveVFiveLobbyPlayer({UserId = player.UserId, Team = "Away"})
					if type(result) == "table" then renderCurrent(result.Data) end
				end)
				if tonumber(player.UserId) ~= Players.LocalPlayer.UserId then
					local kick = Button.new({Text = "KICK", Variant = "Danger", Size = UDim2.fromOffset(60, 26)})
					kick.Position = UDim2.new(1, -66, 0, 4)
					kick.Parent = row
					kick.Activated:Connect(function()
						local result = MatchSetupService:KickFiveVFiveLobbyPlayer({UserId = player.UserId})
						if type(result) == "table" then toast(context, result.Message or "Kick updated.", result.Success and "Info" or "Error"); renderCurrent(result.Data) end
					end)
				end
			end
		end
	end

	renderCurrent = function(data: any?)
		current = data or current or {}
		local status = tostring(current.Status or "Idle")
		local homeCount = teamCount(current, "Home")
		local awayCount = teamCount(current, "Away")
		local teamSize = tonumber(current.TeamSize) or 5
		local canStart = current.IsHost == true and canStartLobby(current)
		if status == "Hosting" or status == "InLobby" then
			lobbyStatus.Text = string.format("%s  /  %s  /  %d/%d", tostring(current.Name or "Lobby"), string.upper(status), tonumber(current.PlayerCount) or 0, tonumber(current.RequiredPlayers) or 0)
			homeLabel.Text = "HOME " .. tostring(homeCount) .. "/" .. tostring(teamSize) .. ": " .. string.upper(teamText(current, "Home"))
			awayLabel.Text = "AWAY " .. tostring(awayCount) .. "/" .. tostring(teamSize) .. ": " .. string.upper(teamText(current, "Away"))
		elseif status == "Rejoin" then
			lobbyStatus.Text = "Active match found. Rejoin from this page."
		else
			lobbyStatus.Text = "Not in a lobby."
			homeLabel.Text = "HOME: NONE"
			awayLabel.Text = "AWAY: NONE"
		end
		startButton.Visible = current.IsHost == true
		startButton.Active = canStart
		startButton.Text = canStart and "START MATCH" or ("NEED " .. tostring(teamSize) .. "V" .. tostring(teamSize))
		Button.setPrimary(startButton, canStart)
		renderPlayers()
	end

	local function renderList()
		for _, child in listFrame:GetChildren() do child:Destroy() end
		for index, lobby in ipairs(lobbyList) do
			if index > 9 then break end
			local row = Instance.new("Frame")
			row.BackgroundColor3 = index % 2 == 0 and Theme.Colors.Gunmetal or Color3.fromHex("101414")
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(0, (index - 1) * 42)
			row.Size = UDim2.new(1, 0, 0, 38)
			row.Parent = listFrame
			text(row, string.format("%s  /  %dv%d  /  %d/%d%s", tostring(lobby.Name or "Lobby"), tonumber(lobby.TeamSize) or 5, tonumber(lobby.TeamSize) or 5, tonumber(lobby.PlayerCount) or 0, tonumber(lobby.RequiredPlayers) or 10, lobby.HasPassword and "  /  LOCKED" or ""), UDim2.fromOffset(8, 0), UDim2.new(1, -96, 1, 0), 9, Theme.Colors.White, Theme.Fonts.Strong)
			local alreadyInLobby = currentLobbyId(current) == tostring(lobby.LobbyId or "")
			local inOtherLobby = currentLobbyId(current) ~= "" and not alreadyInLobby
			local join = Button.new({Text = alreadyInLobby and "HERE" or inOtherLobby and "BUSY" or "JOIN", Variant = (alreadyInLobby or inOtherLobby) and "Secondary" or "Primary", Size = UDim2.fromOffset(76, 28)})
			join.Position = UDim2.new(1, -82, 0, 5)
			join.Active = not alreadyInLobby and not inOtherLobby
			join.AutoButtonColor = false
			if inOtherLobby then
				join.TextTransparency = 0.25
			end
			join.Parent = row
			join.Activated:Connect(function()
				if alreadyInLobby then return end
				if inOtherLobby then
					toast(context, "Leave your current PLAY lobby before joining another.", "Info")
					return
				end
				local result = MatchSetupService:JoinFiveVFiveLobby({LobbyId = lobby.LobbyId, JobId = lobby.JobId, Password = passBox.Text})
				if type(result) == "table" then toast(context, result.Message or "Join requested.", result.Success and "Info" or "Error"); renderCurrent(result.Data) end
			end)
		end
	end

	refresh = function()
		local status = MatchSetupService:GetFiveVFiveQueue()
		if type(status) == "table" and status.Success then renderCurrent(status.Data) end
		local listed = MatchSetupService:ListFiveVFiveLobbies(searchBox.Text)
		if type(listed) == "table" and listed.Success and type(listed.Data) == "table" then
			lobbyList = listed.Data.Lobbies or {}
			renderList()
		end
	end

	sizeButton.Activated:Connect(function()
		selectedSize = selectedSize == 5 and 3 or selectedSize + 1
		sizeButton.Text = tostring(selectedSize) .. "V" .. tostring(selectedSize)
	end)
	openButton.Activated:Connect(function()
		openJoin = not openJoin
		openButton.Text = openJoin and "OPEN" or "PASSWORD"
	end)
	createButton.Activated:Connect(function()
		if busy then return end
		busy = true
		local result = MatchSetupService:CreateFiveVFiveLobby({Name = nameBox.Text, TeamSize = selectedSize, OpenJoin = openJoin, Password = passBox.Text})
		busy = false
		if type(result) == "table" then toast(context, result.Message or "Lobby created.", result.Success and "Info" or "Error"); renderCurrent(result.Data); if refresh then refresh() end end
	end)
	searchButton.Activated:Connect(refresh)
	randomButton.Activated:Connect(function()
		local result = MatchSetupService:RandomFiveVFiveLobby()
		if type(result) == "table" then toast(context, result.Message or "Random queue updated.", result.Success and "Info" or "Error"); renderCurrent(result.Data); if refresh then refresh() end end
	end)
	leaveButton.Activated:Connect(function()
		local result = MatchSetupService:LeaveFiveVFiveQueue()
		if type(result) == "table" then toast(context, result.Message or "Left lobby.", result.Success and "Info" or "Error"); renderCurrent(result.Data); if refresh then refresh() end end
	end)
	startButton.Activated:Connect(function()
		if not canStartLobby(current) then
			toast(context, "Fill both teams evenly before starting.", "Error")
			return
		end
		local result = MatchSetupService:StartFiveVFiveLobby()
		if type(result) == "table" then toast(context, result.Message or "Start requested.", result.Success and "Reward" or "Error"); renderCurrent(result.Data) end
	end)

	local alive = true
	group.Destroying:Connect(function() alive = false end)
	task.spawn(function()
		while alive do
			if group.Visible and (not context.IsCurrentPage or context.IsCurrentPage("FiveVFive")) and refresh then refresh() end
			task.wait(3)
		end
	end)
	if refresh then refresh() end
	return group
end

return Page
