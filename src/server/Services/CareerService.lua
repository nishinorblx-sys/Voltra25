--!strict

local PlayerCareerService = require(script.Parent.PlayerCareerService)

local CareerService = {}
CareerService.__index = CareerService

function CareerService.new(profiles: any, publish: ((Player, string, any) -> ())?, matchBridge: any?)
	return setmetatable({PlayerCareer = PlayerCareerService.new(profiles, publish, matchBridge)}, CareerService)
end

function CareerService:Create(player: Player, careerType: string): number?
	local data = self.PlayerCareer:GetClientData(player)
	local slotNumber = 1
	if data and type(data.Slots) == "table" then
		for _, slot in data.Slots do if slot.Type == "Empty" then slotNumber = slot.Slot break end end
	end
	local success = false
	if careerType == "Manager" then
		success = self.PlayerCareer:CreateManagerCareer(player, {Slot = slotNumber})
	elseif careerType == "Player" then
		success = self.PlayerCareer:CreatePlayerCareer(player, {Slot = slotNumber})
	end
	return success and slotNumber or nil
end

function CareerService:Select(player: Player, slotNumber: number): boolean
	local success = self.PlayerCareer:SelectCareer(player, {Slot = slotNumber})
	return success == true
end

function CareerService:Delete(player: Player, slotNumber: number): boolean
	local success = self.PlayerCareer:DeleteCareer(player, {Slot = slotNumber})
	return success == true
end

function CareerService:GetClientData(player: Player): any?
	return self.PlayerCareer:GetClientData(player)
end

function CareerService:Handle(player: Player, action: any, payload: any): (boolean, string, any?)
	return self.PlayerCareer:Handle(player, action, payload)
end

function CareerService:NormalizeProfile(profile: any): any
	return self.PlayerCareer:NormalizeProfile(profile)
end

return CareerService
