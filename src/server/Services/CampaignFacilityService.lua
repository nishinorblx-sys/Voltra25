--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)

local Service = {}

function Service.Upgrade(profile: any, facilityId: string, requestId: string): (boolean, string, any?)
	if type(facilityId) ~= "string" or #facilityId > 32 then return false, "Invalid facility.", nil end
	if type(requestId) ~= "string" or requestId == "" or #requestId > 96 then return false, "Invalid facility upgrade request.", nil end
	local definition = Config.Facilities[facilityId]
	if not definition then return false, "Unknown facility.", nil end
	local progress = profile.CampaignProgress
	progress.FacilityLedger = type(progress.FacilityLedger) == "table" and progress.FacilityLedger or {}
	local ledgerKey = "upgrade:" .. requestId
	local previous = progress.FacilityLedger[ledgerKey]
	if type(previous) == "table" and previous.FacilityId == facilityId then
		local data = table.clone(previous.Data)
		data.Replayed = true
		return true, tostring(previous.Message), data
	elseif previous ~= nil then
		return false, "That facility request was already used.", nil
	end
	local current = math.clamp(math.floor(tonumber(progress.Facilities[facilityId]) or 0), 0, 3)
	if current >= 3 then return false, definition.Name .. " is already at maximum level.", nil end
	local nextLevel = current + 1
	local cost = definition.Levels[nextLevel].Cost
	if (tonumber(progress.FacilityPoints) or 0) < cost then return false, "You need " .. cost .. " Facility Points.", nil end
	progress.FacilityPoints = math.max(0, progress.FacilityPoints - cost)
	progress.FacilityPointsSpent = (tonumber(progress.FacilityPointsSpent) or 0) + cost
	progress.Facilities[facilityId] = nextLevel
	table.insert(progress.PendingPresentation, {
		Id = "facility:" .. facilityId .. ":" .. nextLevel .. ":" .. os.time(), Type = "FacilityUpgrade",
		FacilityId = facilityId, FacilityName = definition.Name, Level = nextLevel, Text = definition.Levels[nextLevel].Text,
	})
	local message = definition.Name .. " upgraded to level " .. nextLevel .. "."
	local data = { FacilityId = facilityId, Level = nextLevel, Cost = cost, PointsRemaining = progress.FacilityPoints }
	progress.FacilityLedger[ledgerKey] = { FacilityId = facilityId, Message = message, Data = table.clone(data), AppliedAt = os.time() }
	return true, message, data
end

function Service.Public(profile: any): any
	local progress = profile.CampaignProgress
	local result = {}
	for _, facilityId in Config.FacilityOrder do
		local definition = Config.Facilities[facilityId]
		local level = math.clamp(math.floor(tonumber(progress.Facilities[facilityId]) or 0), 0, 3)
		local nextDefinition = level < 3 and definition.Levels[level + 1] or nil
		table.insert(result, {
			Id = facilityId, Name = definition.Name, Level = level,
			CurrentText = level > 0 and definition.Levels[level].Text or "Not upgraded",
			NextCost = nextDefinition and nextDefinition.Cost or nil,
			NextText = nextDefinition and nextDefinition.Text or nil,
		})
	end
	return result
end

return Service
