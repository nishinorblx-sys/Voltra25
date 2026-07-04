local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local RankedDivisionPathService = {}

local store = DataStoreService:GetDataStore("RankedDivisionPath_v2")
local stateByUserId = {}
local started = false
local MIN_DIVISION = 1
local MAX_DIVISION = 10
local ELITE_DIVISION = 0

local function normalizeDivision(value)
	local division = math.floor(tonumber(value) or MAX_DIVISION)
	if division <= ELITE_DIVISION then
		return ELITE_DIVISION
	end

	return math.clamp(division, MIN_DIVISION, MAX_DIVISION)
end

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
			division = normalizeDivision(data.division or player:GetAttribute("Division")),
			clearSeq = tonumber(data.clearSeq) or 0,
		}
	end

	return {
		baseWins = totalWins(player),
		baseLosses = totalLosses(player),
		division = normalizeDivision(player:GetAttribute("Division")),
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

	state.division = normalizeDivision(state.division)
	player:SetAttribute("Division", state.division)
	player:SetAttribute("DivisionName", state.division == ELITE_DIVISION and "ELITE DIVISION" or ("DIVISION " .. tostring(state.division)))
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
			state.division = state.division <= MIN_DIVISION and ELITE_DIVISION or math.max(MIN_DIVISION, state.division - 1)
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
