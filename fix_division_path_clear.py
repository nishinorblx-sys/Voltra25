from pathlib import Path
import re

root = Path.cwd()

ranked = root / "src/client/Pages/RankedPage.lua"
if ranked.exists():
	text = ranked.read_text(encoding="utf-8", errors="ignore")
	original = text

	for old in [
		"SEVEN-GAME PATH",
		"7-GAME PATH",
		"SEVEN GAME PATH",
		"7 GAME PATH",
		"SEVEN-MATCH PATH",
		"7-MATCH PATH",
		"SEVEN MATCH PATH",
		"7 MATCH PATH",
	]:
		if old in text:
			text = text.replace(old, "DIVISION PATH", 1)
			break

	for old in [
		"Seven-Game Path",
		"7-Game Path",
		"Seven Game Path",
		"7 Game Path",
		"Seven-Match Path",
		"7-Match Path",
		"Seven Match Path",
		"7 Match Path",
	]:
		if old in text:
			text = text.replace(old, "Division Path", 1)
			break

	if text != original:
		ranked.write_text(text.strip() + "\n", encoding="utf-8")
		print("patched src/client/Pages/RankedPage.lua")

service = root / "src/server/Services/RankedDivisionPathService.lua"
service.parent.mkdir(parents=True, exist_ok=True)

service.write_text(r'''
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local RankedDivisionPathService = {}

local store = DataStoreService:GetDataStore("RankedDivisionPath_v1")
local stateByUserId = {}
local started = false

local function valueFromLeaderstats(player, name)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)

	if value and value:IsA("ValueBase") then
		return tonumber(value.Value) or 0
	end

	return 0
end

local function stat(player, names)
	for _, name in ipairs(names) do
		local attr = player:GetAttribute(name)
		if typeof(attr) == "number" then
			return math.max(0, math.floor(attr))
		end
	end

	for _, name in ipairs(names) do
		local value = valueFromLeaderstats(player, name)
		if value > 0 then
			return math.max(0, math.floor(value))
		end
	end

	return 0
end

local function totalWins(player)
	return stat(player, { "RankedWins", "Wins", "TotalWins" })
end

local function totalLosses(player)
	return stat(player, { "RankedLosses", "Losses", "TotalLosses" })
end

local function loadState(player)
	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)

	if ok and typeof(data) == "table" then
		return {
			baseWins = tonumber(data.baseWins) or 0,
			baseLosses = tonumber(data.baseLosses) or 0,
			division = tonumber(data.division) or tonumber(player:GetAttribute("Division")) or 10,
			clearSeq = tonumber(data.clearSeq) or 0,
		}
	end

	return {
		baseWins = totalWins(player),
		baseLosses = totalLosses(player),
		division = tonumber(player:GetAttribute("Division")) or 10,
		clearSeq = 0,
	}
end

local function saveState(player, state)
	pcall(function()
		store:SetAsync(tostring(player.UserId), state)
	end)
end

local function publish(player, state, pathWins, pathLosses)
	local pathGames = math.clamp(pathWins + pathLosses, 0, 7)

	player:SetAttribute("Division", state.division)
	player:SetAttribute("PathWins", pathWins)
	player:SetAttribute("PathLosses", pathLosses)
	player:SetAttribute("PathGames", pathGames)
	player:SetAttribute("DivisionPathWins", pathWins)
	player:SetAttribute("DivisionPathLosses", pathLosses)
	player:SetAttribute("DivisionPathGames", pathGames)
	player:SetAttribute("DivisionPathRequiredWins", 4)
	player:SetAttribute("DivisionPathMaxGames", 7)
	player:SetAttribute("VTRDivisionPathClearSeq", state.clearSeq)
end

function RankedDivisionPathService.Recalculate(player)
	local state = stateByUserId[player.UserId]
	if not state then
		state = loadState(player)
		stateByUserId[player.UserId] = state
	end

	local wins = totalWins(player)
	local losses = totalLosses(player)

	if state.baseWins > wins then
		state.baseWins = wins
	end

	if state.baseLosses > losses then
		state.baseLosses = losses
	end

	local pathWins = math.max(0, wins - state.baseWins)
	local pathLosses = math.max(0, losses - state.baseLosses)
	local pathGames = pathWins + pathLosses

	if pathGames >= 7 then
		local promoted = pathWins >= 4

		if promoted then
			state.division = math.max(1, state.division - 1)
			state.clearSeq += 1
			player:SetAttribute("VTRDivisionPathCleared", true)
			player:SetAttribute("VTRDivisionPathPromoted", true)
			player:SetAttribute("VTRDivisionPathClearedWins", pathWins)
			player:SetAttribute("VTRDivisionPathClearedLosses", pathLosses)
		else
			player:SetAttribute("VTRDivisionPathCleared", true)
			player:SetAttribute("VTRDivisionPathPromoted", false)
			player:SetAttribute("VTRDivisionPathClearedWins", pathWins)
			player:SetAttribute("VTRDivisionPathClearedLosses", pathLosses)
		end

		state.baseWins = wins
		state.baseLosses = losses
		pathWins = 0
		pathLosses = 0
		saveState(player, state)
	end

	publish(player, state, pathWins, pathLosses)
end

local function bindValue(player, value)
	if value and value:IsA("ValueBase") then
		value.Changed:Connect(function()
			RankedDivisionPathService.Recalculate(player)
		end)
	end
end

local function bindPlayer(player)
	stateByUserId[player.UserId] = loadState(player)

	task.defer(function()
		task.wait(1)
		RankedDivisionPathService.Recalculate(player)
	end)

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, name in ipairs({ "Wins", "Losses", "RankedWins", "RankedLosses", "TotalWins", "TotalLosses" }) do
			bindValue(player, leaderstats:FindFirstChild(name))
		end

		leaderstats.ChildAdded:Connect(function(child)
			bindValue(player, child)
			RankedDivisionPathService.Recalculate(player)
		end)
	end

	for _, name in ipairs({ "Wins", "Losses", "RankedWins", "RankedLosses", "TotalWins", "TotalLosses" }) do
		player:GetAttributeChangedSignal(name):Connect(function()
			RankedDivisionPathService.Recalculate(player)
		end)
	end
end

function RankedDivisionPathService.Start()
	if started then
		return
	end

	started = true

	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local state = stateByUserId[player.UserId]
		if state then
			saveState(player, state)
		end

		stateByUserId[player.UserId] = nil
	end)
end

RankedDivisionPathService.Start()

return RankedDivisionPathService
'''.strip() + "\n", encoding="utf-8")

runner = root / "src/server/RankedDivisionPath.server.lua"
runner.write_text('require(script.Parent.Services.RankedDivisionPathService)\n', encoding="utf-8")

defaults = root / "src/shared/VTRDataDefaults.lua"
if defaults.exists():
	text = defaults.read_text(encoding="utf-8", errors="ignore")
	original = text

	text = text.replace(
		'''if key == "Ranked" then
		return {
			Rank = rank,
			Division = stat(player, "Division", 1),
			Rating = stat(player, "Rating", 0),
			Wins = wins,
			Losses = stat(player, "Losses", 0),
		}
	end''',
		'''if key == "Ranked" then
		local losses = stat(player, "Losses", 0)
		local pathWins = stat(player, "PathWins", 0)
		local pathLosses = stat(player, "PathLosses", 0)
		local pathGames = stat(player, "PathGames", pathWins + pathLosses)

		return {
			Rank = rank,
			Division = stat(player, "Division", 10),
			Rating = stat(player, "Rating", 0),
			Wins = wins,
			Losses = losses,
			PathWins = pathWins,
			PathLosses = pathLosses,
			PathDraws = 0,
			PathGames = pathGames,
			PathRecordText = tostring(pathWins) .. "W / 0D / " .. tostring(pathLosses) .. "L",
			RequiredWins = 4,
			MaxGames = 7,
		}
	end'''
	)

	if text != original:
		defaults.write_text(text.strip() + "\n", encoding="utf-8")
		print("patched src/shared/VTRDataDefaults.lua")

client = root / "src/client/Services/DivisionPathClearAnimationClient.lua"
client.parent.mkdir(parents=True, exist_ok=True)

client.write_text(r'''
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local DivisionPathClearAnimationClient = {}

local started = false
local lastSeq = -1

local function makeText(parent, name, text, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamBlack
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Text = text
	label.Parent = parent
	return label
end

local function burst(parent)
	for i = 1, 44 do
		local piece = Instance.new("Frame")
		piece.Name = "Burst"
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(0.5, 0.5)
		piece.Size = UDim2.fromOffset(math.random(5, 12), math.random(16, 34))
		piece.Rotation = math.random(0, 360)
		piece.BackgroundColor3 = Color3.fromHSV(math.random(), 0.75, 1)
		piece.BorderSizePixel = 0
		piece.Parent = parent

		local angle = math.rad((i / 44) * 360)
		local distance = math.random(260, 520)
		local target = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance)

		TweenService:Create(piece, TweenInfo.new(0.85, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = target,
			Rotation = piece.Rotation + math.random(180, 620),
			BackgroundTransparency = 1,
		}):Play()

		task.delay(0.95, function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

function DivisionPathClearAnimationClient.Play()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("DivisionPathClearGui")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DivisionPathClearGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20000
	gui.Parent = playerGui

	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BackgroundTransparency = 1
	shade.Size = UDim2.fromScale(1, 1)
	shade.Parent = gui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(720, 280)
	card.BackgroundColor3 = Color3.fromRGB(10, 15, 22)
	card.BackgroundTransparency = 0.05
	card.Parent = shade

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 26)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(140, 255, 45)
	stroke.Parent = card

	local scale = Instance.new("UIScale")
	scale.Scale = 0.78
	scale.Parent = card

	local title = makeText(card, "Title", "DIVISION PATH CLEARED", UDim2.fromOffset(30, 34), UDim2.new(1, -60, 0, 64), 44, Color3.fromRGB(150, 255, 55))
	local sub = makeText(card, "Sub", "4 wins reached — division promoted", UDim2.fromOffset(30, 104), UDim2.new(1, -60, 0, 40), 23, Color3.fromRGB(255, 255, 255))
	local division = tonumber(localPlayer:GetAttribute("Division")) or 0
	local divText = division > 0 and "NEW DIVISION " .. tostring(division) or "NEW DIVISION"
	makeText(card, "Division", divText, UDim2.fromOffset(30, 152), UDim2.new(1, -60, 0, 54), 34, Color3.fromRGB(60, 225, 255))

	TweenService:Create(shade, TweenInfo.new(0.22), {
		BackgroundTransparency = 0.18,
	}):Play()

	TweenService:Create(scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	burst(gui)

	task.wait(2.2)

	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Scale = 0.9,
	}):Play()

	TweenService:Create(shade, TweenInfo.new(0.18), {
		BackgroundTransparency = 1,
	}):Play()

	task.wait(0.2)
	gui:Destroy()
end

local function check()
	local seq = tonumber(localPlayer:GetAttribute("VTRDivisionPathClearSeq")) or 0
	local promoted = localPlayer:GetAttribute("VTRDivisionPathPromoted") == true

	if promoted and seq > lastSeq then
		lastSeq = seq
		DivisionPathClearAnimationClient.Play()
	elseif seq > lastSeq then
		lastSeq = seq
	end
end

function DivisionPathClearAnimationClient.Start()
	if started then
		return
	end

	started = true
	lastSeq = tonumber(localPlayer:GetAttribute("VTRDivisionPathClearSeq")) or 0

	localPlayer:GetAttributeChangedSignal("VTRDivisionPathClearSeq"):Connect(check)
	task.defer(check)
end

DivisionPathClearAnimationClient.Start()

return DivisionPathClearAnimationClient
'''.strip() + "\n", encoding="utf-8")

client_runner = root / "src/client/DivisionPathClearAnimation.client.lua"
client_runner.write_text('require(script.Parent.Services.DivisionPathClearAnimationClient)\n', encoding="utf-8")

print("patched src/server/Services/RankedDivisionPathService.lua")
print("patched src/server/RankedDivisionPath.server.lua")
print("patched src/client/Services/DivisionPathClearAnimationClient.lua")
print("patched src/client/DivisionPathClearAnimation.client.lua")