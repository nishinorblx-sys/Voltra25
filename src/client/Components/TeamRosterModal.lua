--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local MatchSetupService = require(script.Parent.Parent.Services.MatchSetupService)
local Button = require(script.Parent.Button)
local Panel = require(script.Parent.Panel)
local CompactPlayerCard = require(script.Parent.CompactPlayerCard)

local TeamRosterModal = {}
local formationCoordinates = {
	Vector2.new(.5, .86), Vector2.new(.16, .68), Vector2.new(.38, .70), Vector2.new(.62, .70), Vector2.new(.84, .68),
	Vector2.new(.3, .47), Vector2.new(.5, .54), Vector2.new(.7, .47), Vector2.new(.17, .20), Vector2.new(.5, .14), Vector2.new(.83, .20),
}

local function label(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local item = Instance.new("TextLabel"); item.BackgroundTransparency = 1; item.Position = position; item.Size = size
	item.Text = value; item.TextColor3 = color; item.TextSize = textSize; item.Font = font; item.TextXAlignment = Enum.TextXAlignment.Left
	item.ZIndex = 164; item.Parent = parent; return item
end

function TeamRosterModal.open(teamId: string, onError: (string) -> ())
	local response = MatchSetupService:GetRoster(teamId)
	if not response.Success then onError(response.Message or "Roster unavailable."); return end
	local data = response.Data
	local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	local screen = playerGui:FindFirstChild("VTR25")
	if not screen then return end
	local responsiveRoot = screen:FindFirstChild("Root") or screen

	local overlay = Instance.new("TextButton")
	overlay.Name = "RosterOverlay"; overlay.AutoButtonColor = false; overlay.Selectable = false; overlay.Text = ""
	overlay.BackgroundColor3 = Theme.Colors.Black; overlay.BackgroundTransparency = .08; overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1); overlay.ZIndex = 160; overlay.Parent = responsiveRoot
	local modal = Panel.new({ Name = "RosterModal", Size = UDim2.fromOffset(960, 610) })
	modal.AnchorPoint = Vector2.new(.5, .5); modal.Position = UDim2.fromScale(.5, .5); modal.ZIndex = 161; modal.Parent = overlay
	local sizeConstraint = Instance.new("UISizeConstraint"); sizeConstraint.MaxSize = Vector2.new(960, 610); sizeConstraint.MinSize = Vector2.new(620, 470); sizeConstraint.Parent = modal
	modal.Size = UDim2.new(.82, 0, .82, 0)
	label(modal, data.Team.teamName, UDim2.fromOffset(24, 17), UDim2.new(1, -170, 0, 30), 22, Theme.Colors.White, Theme.Fonts.Display)
	label(modal, string.format("%s  /  %s  /  %s", data.Team.country, data.Team.league, data.Formation), UDim2.fromOffset(24, 50), UDim2.new(1, -48, 0, 18), 9, Theme.Colors.White, Theme.Fonts.Strong)
	local close = Button.new({ Text = "CLOSE", Variant = "Secondary", Size = UDim2.fromOffset(110, 36), OnActivated = function() overlay:Destroy() end })
	close.Position = UDim2.new(1, -134, 0, 20); close.ZIndex = 165; close.Parent = modal

	local tabs = { "FORMATION", "STARTING XI", "BENCH", "RESERVES" }
	local active = "FORMATION"
	local tabBar = Instance.new("Frame"); tabBar.BackgroundTransparency = 1; tabBar.Position = UDim2.fromOffset(24, 78); tabBar.Size = UDim2.new(1, -48, 0, 36); tabBar.ZIndex = 163; tabBar.Parent = modal
	local tabLayout = Instance.new("UIListLayout"); tabLayout.FillDirection = Enum.FillDirection.Horizontal; tabLayout.Padding = UDim.new(0, 8); tabLayout.Parent = tabBar
	local content = Instance.new("Frame"); content.BackgroundTransparency = 1; content.Position = UDim2.fromOffset(24, 126); content.Size = UDim2.new(1, -48, 1, -148); content.ZIndex = 163; content.Parent = modal
	local tabButtons: { [string]: TextButton } = {}
	local render: () -> ()

	local function renderCards(players: { any }, emptyMessage: string)
		if #players == 0 then label(content, emptyMessage, UDim2.fromScale(0, .35), UDim2.fromScale(1, .2), 15, Theme.Colors.Muted, Theme.Fonts.Strong).TextXAlignment = Enum.TextXAlignment.Center; return end
		local scroll = Instance.new("ScrollingFrame"); scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0; scroll.Size = UDim2.fromScale(1, 1)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; scroll.CanvasSize = UDim2.new(); scroll.ScrollBarThickness = 3; scroll.ScrollBarImageColor3 = Theme.Colors.White; scroll.ZIndex = 163; scroll.Parent = content
		local grid = Instance.new("UIGridLayout"); grid.CellSize = UDim2.new(.333, -8, 0, 82); grid.CellPadding = UDim2.fromOffset(10, 10); grid.Parent = scroll
		for index, player in players do
			local card = CompactPlayerCard.new({ Parent = scroll, Card = player, Size = UDim2.new(1, 0, 1, 0), Horizontal = true, ZIndex = 164 })
			card.LayoutOrder = index; card.Active = false; card.Selectable = false
		end
	end

	render = function()
		for tabName, tabButton in tabButtons do Button.setPrimary(tabButton, tabName == active) end
		for _, child in content:GetChildren() do child:Destroy() end
		if active == "FORMATION" then
			local pitch = Instance.new("Frame"); pitch.BackgroundColor3 = Theme.Colors.Pitch; pitch.BorderSizePixel = 0; pitch.Size = UDim2.fromScale(.67, 1); pitch.ZIndex = 163; pitch.Parent = content
			local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = pitch
			local stroke = Instance.new("UIStroke"); stroke.Color = Theme.Colors.White; stroke.Transparency = .7; stroke.Thickness = 1; stroke.Parent = pitch
			local centerLine = Instance.new("Frame"); centerLine.BackgroundColor3 = Theme.Colors.White; centerLine.BackgroundTransparency = .78; centerLine.BorderSizePixel = 0; centerLine.Position = UDim2.fromScale(0, .5); centerLine.Size = UDim2.new(1, 0, 0, 1); centerLine.ZIndex = 164; centerLine.Parent = pitch
			for index, player in data.StartingXI do
				local card = CompactPlayerCard.new({ Parent = pitch, Card = player, Size = UDim2.fromOffset(68, 86), ZIndex = 166 })
				card.AnchorPoint = Vector2.new(.5, .5); card.Position = UDim2.fromScale(formationCoordinates[index].X, formationCoordinates[index].Y); card.ZIndex = 166; card.Active = false; card.Selectable = false
			end
			local summary = Panel.new({ Name = "RosterSummary", Position = UDim2.new(.7, 0, 0, 0), Size = UDim2.new(.3, 0, 1, 0) }); summary.ZIndex = 163; summary.Parent = content
			label(summary, "TEAM RATINGS", UDim2.fromOffset(16, 16), UDim2.new(1, -32, 0, 20), 9, Theme.Colors.White, Theme.Fonts.Strong)
			label(summary, string.format("%d\nOVERALL", data.Team.overall), UDim2.fromOffset(16, 48), UDim2.new(1, -32, 0, 62), 22, Theme.Colors.White, Theme.Fonts.Display)
			label(summary, string.format("ATT  %d\nMID  %d\nDEF  %d", data.Team.attack, data.Team.midfield, data.Team.defense), UDim2.fromOffset(16, 126), UDim2.new(1, -32, 0, 82), 13, Theme.Colors.Silver, Theme.Fonts.Strong)
			label(summary, "STAR PLAYERS", UDim2.fromOffset(16, 230), UDim2.new(1, -32, 0, 20), 8, Theme.Colors.White, Theme.Fonts.Strong)
			local names = {}; for _, player in data.BestPlayers do table.insert(names, string.format("%d  %s", player.overall, player.displayName)) end
			label(summary, table.concat(names, "\n"), UDim2.fromOffset(16, 254), UDim2.new(1, -32, 0, 100), 10, Theme.Colors.White, Theme.Fonts.Strong)
		elseif active == "STARTING XI" then renderCards(data.StartingXI, "No starting players")
		elseif active == "BENCH" then renderCards(data.Bench, "No bench players")
		else renderCards(data.Reserves or {}, "No reserve players available") end
	end

	for _, tabName in tabs do
		local tab = Button.new({ Text = tabName, Variant = tabName == active and "Primary" or "Secondary", Size = UDim2.fromOffset(140, 34), OnActivated = function() active = tabName; render() end })
		tab.ZIndex = 165; tab.Parent = tabBar; tabButtons[tabName] = tab
	end
	render()
end

return TeamRosterModal
