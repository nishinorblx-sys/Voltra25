--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local EVENTS: {[string]: boolean} = {
	playability_join_ready = true,
	playability_first_menu_visible = true,
	playability_match_requested = true,
	playability_teleport_requested = true,
	playability_destination_joined = true,
	playability_runtime_creation_started = true,
	playability_runtime_ready = true,
	playability_presentation_started = true,
	playability_presentation_skipped = true,
	playability_active_player_assigned = true,
	playability_control_enabled = true,
	playability_first_move = true,
	playability_first_pass_attempt = true,
	playability_first_pass_completed = true,
	playability_first_shot = true,
	playability_first_goal = true,
	playability_first_tackle = true,
	playability_tutorial_complete = true,
	playability_halftime = true,
	playability_match_complete = true,
	playability_next_match = true,
	playability_abandoned = true,
	playability_mobile_action_cancelled = true,
	playability_ball_hard_correction = true,
	playability_action_queue_cancelled = true,
	playability_manager_input_error = true,
	playability_debug_action_rejected = true,
}

local CLIENT_HINTS: {[string]: string} = {
	FirstMenuVisible = "playability_first_menu_visible",
	TeleportRequested = "playability_teleport_requested",
	DestinationJoined = "playability_destination_joined",
}

local Service = {}
Service.__index = Service

local function sanitize(properties: any): {[string]: any}
	local result: {[string]: any} = {}
	if type(properties) ~= "table" then return result end
	local count = 0
	for key, value in properties do
		if count >= 16 then break end
		if type(key) == "string" and #key <= 32 then
			local valueType = type(value)
			if valueType == "string" then
				result[key] = string.sub(value, 1, 64)
				count += 1
			elseif valueType == "number" and value == value and math.abs(value) < 1e9 then
				result[key] = math.floor(value * 1000 + .5) / 1000
				count += 1
			elseif valueType == "boolean" then
				result[key] = value
				count += 1
			end
		end
	end
	return result
end

function Service.new(profiles: any)
	return setmetatable({Profiles = profiles, JoinedAt = {}, MatchRequestedAt = {}, Once = {}, Diagnostics = {}}, Service)
end

function Service:_join(player: Player)
	self.JoinedAt[player] = os.clock()
	task.spawn(function()
		local deadline = os.clock() + 12
		while player.Parent == Players and player:GetAttribute("VTRProfileReady") ~= true and os.clock() < deadline do task.wait(.05) end
		if player.Parent == Players then self:TrackOnce(player, "join", "playability_join_ready", {}) end
	end)
end

function Service:Start()
	Players.PlayerAdded:Connect(function(player) self:_join(player) end)
	for _, player in Players:GetPlayers() do self:_join(player) end
end

function Service:Track(player: Player, eventName: string, properties: any?)
	if not player or player.Parent ~= Players or EVENTS[eventName] ~= true then return end
	local fields = sanitize(properties)
	local joined = self.JoinedAt[player]
	if joined then fields.timeSinceJoin = math.max(0, os.clock() - joined) end
	local requested = self.MatchRequestedAt[player]
	if requested then fields.timeSinceMatchRequest = math.max(0, os.clock() - requested) end
	self.Diagnostics[player] = self.Diagnostics[player] or {}
	self.Diagnostics[player][eventName] = {At = os.clock(), Properties = fields}
	if RunService:IsStudio() then return end
	pcall(function() AnalyticsService:LogCustomEvent(player, eventName, 1, fields) end)
end

function Service:TrackOnce(player: Player, scope: string, eventName: string, properties: any?)
	local key = tostring(player.UserId) .. ":" .. string.sub(tostring(scope), 1, 80) .. ":" .. eventName
	if self.Once[key] then return end
	self.Once[key] = true
	self:Track(player, eventName, properties)
end

function Service:MarkMatchRequested(player: Player, properties: any?)
	local previous = self.MatchRequestedAt[player]
	self.MatchRequestedAt[player] = os.clock()
	self:Track(player, previous and "playability_next_match" or "playability_match_requested", properties)
end

function Service:HandleClientHint(player: Player, payload: any): boolean
	if type(payload) ~= "table" then return false end
	local eventName = CLIENT_HINTS[tostring(payload.Event or "")]
	if not eventName then return false end
	self:TrackOnce(player, tostring(payload.Scope or "session"), eventName, payload.Properties)
	return true
end

function Service:GetSummary(player: Player): any
	local joined = self.JoinedAt[player]
	local requested = self.MatchRequestedAt[player]
	return {
		TimeSinceJoin = joined and math.max(0, os.clock() - joined) or 0,
		TimeSinceMatchRequest = requested and math.max(0, os.clock() - requested) or 0,
		Events = self.Diagnostics[player] or {},
	}
end

function Service:PlayerRemoving(player: Player)
	self.JoinedAt[player] = nil
	self.MatchRequestedAt[player] = nil
	self.Diagnostics[player] = nil
end

return Service
