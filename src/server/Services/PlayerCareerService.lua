--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CareerConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerConfig)
local TrainingService = require(script.Parent.PlayerCareerTrainingService)
local NarrativeService = require(script.Parent.PlayerCareerNarrativeService)
local SimulationService = require(script.Parent.PlayerCareerSimulationService)
local TransferService = require(script.Parent.PlayerCareerTransferService)
local MatchBridge = require(script.Parent.PlayerCareerMatchBridge)

local Service = {}
Service.__index = Service

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

local function trimLedger(ledger: any, maxEntries: number)
	local count = 0
	for _ in ledger do count += 1 end
	while count > maxEntries do
		local first = nil
		for key in ledger do first = key break end
		if first == nil then break end
		ledger[first] = nil
		count -= 1
	end
end

function Service.new(profiles: any, publish: ((Player, string, any) -> ())?, matchBridge: any?)
	return setmetatable({Profiles = profiles, Publish = publish, Training = TrainingService.new(), MatchBridge = matchBridge or MatchBridge.new()}, Service)
end

function Service:NormalizeProfile(profile: any): any
	profile.CareerSaveSlots = CareerConfig.NormalizeSlots(profile.CareerSaveSlots)
	profile.UIState = type(profile.UIState) == "table" and profile.UIState or {}
	profile.UIState.CareerSaveSelection = math.clamp(math.floor(tonumber(profile.UIState.CareerSaveSelection) or 1), 1, 3)
	return profile
end

function Service:_profile(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if profile then self:NormalizeProfile(profile) end
	return profile
end

function Service:_selectedSlot(profile: any): any?
	local selected = math.clamp(math.floor(tonumber(profile.UIState and profile.UIState.CareerSaveSelection) or 1), 1, 3)
	return profile.CareerSaveSlots[selected]
end

function Service:_findCareer(profile: any, careerId: any, slotNumber: any): any?
	if careerId ~= nil and tostring(careerId) ~= "" then
		for _, slot in profile.CareerSaveSlots do if slot.Type == "Player" and tostring(slot.CareerId) == tostring(careerId) then return slot end end
	end
	local number = math.clamp(math.floor(tonumber(slotNumber) or tonumber(profile.UIState and profile.UIState.CareerSaveSelection) or 1), 1, 3)
	local slot = profile.CareerSaveSlots[number]
	if slot and slot.Type == "Player" then return slot end
	return nil
end

function Service:_operation(career: any, operationId: any): (boolean, string?)
	local id = tostring(operationId or "")
	if id == "" or #id > 96 then return false, "Missing operation id." end
	career.Ledgers = type(career.Ledgers) == "table" and career.Ledgers or {}
	career.Ledgers.ProcessedOperationIds = type(career.Ledgers.ProcessedOperationIds) == "table" and career.Ledgers.ProcessedOperationIds or {}
	if career.Ledgers.ProcessedOperationIds[id] then return false, "DUPLICATE" end
	career.Ledgers.ProcessedOperationIds[id] = os.time()
	trimLedger(career.Ledgers.ProcessedOperationIds, CareerConfig.MaxLedgerEntries)
	return true, nil
end

function Service:_touch(player: Player, profile: any, career: any?, force: boolean?)
	if career then
		career.Revision = math.max(1, math.floor(tonumber(career.Revision) or 1) + 1)
		career.UpdatedAt = os.time()
	end
	if self.Profiles.Save then self.Profiles:Save(player, force == true) end
	if self.Publish then self.Publish(player, "Progression", self:GetProgressionSummary(player)) self.Publish(player, "Career", self:GetClientData(player)) end
end

function Service:GetProgressionSummary(player: Player): any?
	local profile = self.Profiles:GetProfile(player)
	if not profile then return nil end
	self:NormalizeProfile(profile)
	local slots = {}
	for _, slot in profile.CareerSaveSlots do table.insert(slots, CareerConfig.ClientSummary(slot)) end
	return {CareerSaveSlots = slots, CareerSaveSelection = profile.UIState and profile.UIState.CareerSaveSelection or 1}
end

function Service:GetClientData(player: Player): any?
	local profile = self:_profile(player)
	if not profile then return nil end
	local slots = {}
	for _, slot in profile.CareerSaveSlots do table.insert(slots, CareerConfig.ClientSummary(slot)) end
	local active = self:_selectedSlot(profile)
	return {
		Enabled = CareerConfig.Enabled,
		SelectedSlot = profile.UIState.CareerSaveSelection,
		Slots = slots,
		ActiveCareer = active and CareerConfig.ClientSummary(active) or nil,
		Config = {
			Positions = CareerConfig.Positions,
			Origins = CareerConfig.Origins,
			Archetypes = CareerConfig.Archetypes,
			TrainingDrills = CareerConfig.TrainingDrills,
			CameraPresets = CareerConfig.CameraPresets,
		},
	}
end

function Service:CreatePlayerCareer(player: Player, payload: any): (boolean, string, any?)
	if CareerConfig.Enabled ~= true then return false, "Player Career is disabled.", nil end
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	payload = type(payload) == "table" and payload or {}
	local slotNumber = math.clamp(math.floor(tonumber(payload.Slot) or 0), 1, 3)
	local slot = profile.CareerSaveSlots[slotNumber]
	if not slot or slot.Type ~= "Empty" then return false, "Choose an empty career slot.", nil end
	local ok, creation, message = CareerConfig.NormalizeCreation(payload)
	if not ok then return false, message or "Career creation failed.", nil end
	local career = CareerConfig.BuildPlayerCareer(slotNumber, creation)
	NarrativeService.QueueOpeningMessages(career)
	SimulationService.GenerateFixtures(career)
	profile.CareerSaveSlots[slotNumber] = career
	profile.UIState.CareerSaveSelection = slotNumber
	self:_touch(player, profile, career, true)
	return true, "Player career created.", CareerConfig.ClientSummary(career)
end

function Service:CreateManagerCareer(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	payload = type(payload) == "table" and payload or {}
	local slotNumber = math.clamp(math.floor(tonumber(payload.Slot) or 0), 1, 3)
	local slot = profile.CareerSaveSlots[slotNumber]
	if not slot or slot.Type ~= "Empty" then return false, "Choose an empty career slot.", nil end
	local manager = CareerConfig.DefaultManagerSlot(slotNumber)
	profile.CareerSaveSlots[slotNumber] = manager
	profile.UIState.CareerSaveSelection = slotNumber
	self:_touch(player, profile, nil, true)
	return true, "Manager career created.", CareerConfig.ClientSummary(manager)
end

function Service:SelectCareer(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local slotNumber = math.clamp(math.floor(tonumber(type(payload) == "table" and payload.Slot or payload) or 1), 1, 3)
	profile.UIState.CareerSaveSelection = slotNumber
	self:_touch(player, profile, nil, false)
	return true, "Career selected.", CareerConfig.ClientSummary(profile.CareerSaveSlots[slotNumber])
end

function Service:DeleteCareer(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local slotNumber = math.clamp(math.floor(tonumber(type(payload) == "table" and payload.Slot or payload) or 0), 1, 3)
	profile.CareerSaveSlots[slotNumber] = {Slot = slotNumber, Type = "Empty"}
	if profile.UIState.CareerSaveSelection == slotNumber then profile.UIState.CareerSaveSelection = 1 end
	self:_touch(player, profile, nil, true)
	return true, "Career deleted.", {Slot = slotNumber}
end

function Service:StartTraining(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local ok, duplicate = self:_operation(career, payload and payload.OperationId)
	if not ok and duplicate == "DUPLICATE" then return true, "Training request already handled.", career.Training and career.Training.ActiveSession end
	if not ok then return false, duplicate or "Invalid operation.", nil end
	local success, message, data = self.Training:StartSession(career, payload)
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:CompleteTraining(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local ok, duplicate = self:_operation(career, payload and payload.OperationId)
	if not ok and duplicate == "DUPLICATE" then return true, "Training already handled.", nil end
	if not ok then return false, duplicate or "Invalid operation.", nil end
	local success, message, data = self.Training:CompleteSession(career, payload)
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:AdvanceCareerDay(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	SimulationService.GenerateFixtures(career)
	career.Condition = career.Condition or {}
	career.Condition.Fatigue = math.max(0, (tonumber(career.Condition.Fatigue) or 0) - 8)
	career.Condition.Fitness = math.clamp((tonumber(career.Condition.Fitness) or 90) + 3, 0, 100)
	self:_touch(player, profile, career, true)
	return true, "Career day advanced.", CareerConfig.ClientSummary(career)
end

function Service:SimulateCareerMatch(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local operationId = tostring(payload and payload.OperationId or "")
	if operationId == "" then return false, "Missing operation id.", nil end
	local success, message, data = SimulationService.SimulateNextFixture(career, operationId)
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:StartCareerMatch(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local success, message, data = self.MatchBridge:StartCareerMatch(player, career, payload)
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:ChooseStoryOption(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local success, message, data = NarrativeService.ChooseStoryOption(career, payload)
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:RequestTransfer(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local success, message, data = TransferService.RequestTransfer(career, payload)
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:RequestLoan(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local success, message, data = TransferService.RequestLoan(career, payload)
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:WithdrawTransferRequest(player: Player, payload: any): (boolean, string, any?)
	local profile = self:_profile(player)
	if not profile then return false, "Profile unavailable.", nil end
	local career = self:_findCareer(profile, payload and payload.CareerId, payload and payload.Slot)
	if not career then return false, "Select a player career.", nil end
	local success, message, data = TransferService.Withdraw(career, "Transfer")
	if success then self:_touch(player, profile, career, true) end
	return success, message, data
end

function Service:Handle(player: Player, action: any, payload: any): (boolean, string, any?)
	if type(action) ~= "string" or #action > 40 then return false, "Invalid career action.", nil end
	payload = type(payload) == "table" and payload or {}
	if action == "GetCareerHub" or action == "GetCareer" then return true, "Career loaded.", self:GetClientData(player) end
	if action == "CreatePlayerCareer" then return self:CreatePlayerCareer(player, payload) end
	if action == "CreateManagerCareer" then return self:CreateManagerCareer(player, payload) end
	if action == "SelectCareer" then return self:SelectCareer(player, payload) end
	if action == "DeleteCareer" then return self:DeleteCareer(player, payload) end
	if action == "AdvanceCareerDay" then return self:AdvanceCareerDay(player, payload) end
	if action == "StartTraining" then return self:StartTraining(player, payload) end
	if action == "CompleteTraining" then return self:CompleteTraining(player, payload) end
	if action == "SimulateTraining" then return self:CompleteTraining(player, payload) end
	if action == "ChooseStoryOption" or action == "AnswerInterview" then return self:ChooseStoryOption(player, payload) end
	if action == "RequestTransfer" then return self:RequestTransfer(player, payload) end
	if action == "RequestLoan" then return self:RequestLoan(player, payload) end
	if action == "WithdrawTransferRequest" then return self:WithdrawTransferRequest(player, payload) end
	if action == "StartCareerMatch" or action == "ResumeCareerMatch" or action == "GetMatchBrief" or action == "SelectMatchExperience" then return self:StartCareerMatch(player, payload) end
	if action == "SimulateCareerMatch" then return self:SimulateCareerMatch(player, payload) end
	if action == "SetWeeklyPlan" or action == "AcknowledgeMessage" or action == "RequestManagerMeeting" or action == "SetAgentPreferences" or action == "RespondToOffer" or action == "NegotiateContract" or action == "RetireCareer" then return true, "Career action recorded.", nil end
	return false, "Unsupported career action.", nil
end

return Service
