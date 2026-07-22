--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CareerConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerConfig)
local TrainingConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerTrainingConfig)
local ProgressionConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerProgressionConfig)
local CareerService = require(script.Parent.Parent.Services.PlayerCareerService)

local Tests = {}

local function expect(condition: any, message: string)
	if not condition then error(message, 2) end
end

local function expectEqual(actual: any, expected: any, message: string)
	if actual ~= expected then error(message.." | expected "..tostring(expected)..", got "..tostring(actual), 2) end
end

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

local Store = {}
Store.__index = Store

function Store.new(profile: any)
	return setmetatable({Profile = profile, Saves = 0}, Store)
end

function Store:GetProfile(_player: Player): any
	return self.Profile
end

function Store:Save(_player: Player, _force: boolean?): boolean
	self.Saves += 1
	return true
end

local function profile(): any
	return {UIState = {CareerSaveSelection = 1}, CareerSaveSlots = {{Slot = 1, Type = "Empty"}, {Slot = 2, Type = "Manager", Name = "MORGAN VALE", Season = "2026/27", Club = "NO CLUB", Rating = 50, Stats = {Played = 0}}, {Slot = 3, Type = "Empty"}}}
end

function Tests.Run(): any
	local results = {Passed = 0, Failed = 0, Failures = {}, Names = {}}
	local function test(name: string, callback: () -> ())
		local ok, message = pcall(callback)
		table.insert(results.Names, name)
		if ok then results.Passed += 1 else results.Failed += 1 table.insert(results.Failures, name..": "..tostring(message)) end
	end

	test("all player career positions normalize", function()
		for _, position in CareerConfig.Positions do
			local ok, creation = CareerConfig.NormalizeCreation({FirstName = "Test", LastName = position, PrimaryPosition = position, OriginId = position == "GK" and "keepers_road" or "academy_graduate"})
			expect(ok, "Position rejected: "..position)
			local slot = CareerConfig.BuildPlayerCareer(1, creation)
			expectEqual(slot.Identity.PrimaryPosition, position, "Position changed during creation")
			expect(slot.Overall >= 50 and slot.Overall <= 75, "Starting overall escaped normal band")
		end
	end)

	test("all origins create valid careers", function()
		for originId, origin in CareerConfig.Origins do
			local position = origin.Position or "CM"
			local ok, creation = CareerConfig.NormalizeCreation({FirstName = "Origin", LastName = originId, PrimaryPosition = position, OriginId = originId})
			expect(ok, "Origin rejected: "..originId)
			local slot = CareerConfig.BuildPlayerCareer(1, creation)
			expectEqual(slot.Origin.OriginId, originId, "Origin changed")
			expect(slot.ClubState.ManagerTrust >= 0 and slot.ClubState.ManagerTrust <= 100, "Trust escaped bounds")
		end
	end)

	test("archetype eligibility rejects impossible pairing", function()
		local ok, creation = CareerConfig.NormalizeCreation({PrimaryPosition = "GK", OriginId = "keepers_road", ArchetypeId = "complete_finisher"})
		expect(ok, "Fallback creation should still succeed")
		expect(CareerConfig.ArchetypeEligible(creation.Archetype.ArchetypeId, "GK"), "Fallback archetype is not eligible")
	end)

	test("position overall is weighted and not a simple average", function()
		local attributes = {Goalkeeping = 90, Positioning = 70, Composure = 70, LongPassing = 60, Vision = 60, Aerial = 75, Strength = 60, Agility = 65, Finishing = 20}
		local gk = CareerConfig.PositionOverall("GK", attributes)
		local st = CareerConfig.PositionOverall("ST", attributes)
		expect(gk > st, "Goalkeeper weighted overall did not exceed striker overall")
	end)

	test("attribute cost curve increases with rating", function()
		expect(CareerConfig.AttributeCost(88, 22) > CareerConfig.AttributeCost(55, 22), "High attribute cost should be greater")
		expect(CareerConfig.AttributeCost(80, 32) > CareerConfig.AttributeCost(80, 20), "Older physical development should cost more")
	end)

	test("training grade thresholds normalize", function()
		expectEqual(TrainingConfig.ScoreToGrade(950, 1000), "A+", "A+ threshold failed")
		expectEqual(TrainingConfig.ScoreToGrade(720, 1000), "B", "B threshold failed")
		expectEqual(TrainingConfig.NormalizeGrade("Z"), nil, "Invalid grade accepted")
	end)

	test("repetition penalty is bounded", function()
		expect(ProgressionConfig.RepetitionMultiplier(0) > ProgressionConfig.RepetitionMultiplier(3), "Repetition did not reduce gain")
		expect(ProgressionConfig.RepetitionMultiplier(99) > 0, "Repetition penalty became zero")
	end)

	test("service create select delete preserves manager slot", function()
		local p = profile()
		local service = CareerService.new(Store.new(p), function() end)
		local player = {Name = "Test", Parent = game} :: any
		local success = service:CreatePlayerCareer(player, {Slot = 1, FirstName = "Kai", LastName = "North", PrimaryPosition = "ST", OriginId = "academy_graduate"})
		expect(success, "Player career was not created")
		expectEqual(p.CareerSaveSlots[2].Type, "Manager", "Manager slot was modified")
		local selected = service:SelectCareer(player, {Slot = 1})
		expect(selected, "Career select failed")
		local deleted = service:DeleteCareer(player, {Slot = 1})
		expect(deleted, "Career delete failed")
		expectEqual(p.CareerSaveSlots[1].Type, "Empty", "Player slot was not emptied")
		expectEqual(p.CareerSaveSlots[2].Type, "Manager", "Manager slot did not survive delete")
	end)

	test("training session consumes once", function()
		local p = profile()
		local service = CareerService.new(Store.new(p), function() end)
		local player = {Name = "Test", Parent = game} :: any
		service:CreatePlayerCareer(player, {Slot = 1, FirstName = "Kai", LastName = "North", PrimaryPosition = "CM", OriginId = "academy_graduate"})
		local career = p.CareerSaveSlots[1]
		local startOk, _, session = service:StartTraining(player, {CareerId = career.CareerId, OperationId = "op_start", DrillId = "scan_and_receive"})
		expect(startOk and type(session) == "table", "Training did not start")
		local doneOk = service:CompleteTraining(player, {CareerId = career.CareerId, OperationId = "op_done", TrainingSessionId = session.TrainingSessionId, Score = 800})
		expect(doneOk, "Training did not complete")
		local secondOk, secondMessage = service:CompleteTraining(player, {CareerId = career.CareerId, OperationId = "op_done", TrainingSessionId = session.TrainingSessionId, Score = 800})
		expect(secondOk and string.find(tostring(secondMessage), "already") ~= nil, "Duplicate training was not idempotent")
	end)

	test("fixture simulation is consumed once", function()
		local p = profile()
		local service = CareerService.new(Store.new(p), function() end)
		local player = {Name = "Test", Parent = game} :: any
		service:CreatePlayerCareer(player, {Slot = 1, FirstName = "Kai", LastName = "North", PrimaryPosition = "LW", OriginId = "street_technician"})
		local career = p.CareerSaveSlots[1]
		local ok, _, fixture = service:SimulateCareerMatch(player, {CareerId = career.CareerId, OperationId = "fixture_1"})
		expect(ok and type(fixture) == "table" and fixture.Completed == true, "Fixture did not simulate")
		local appearances = career.Statistics.Career.Appearances
		service:SimulateCareerMatch(player, {CareerId = career.CareerId, OperationId = "fixture_1"})
		expectEqual(career.Statistics.Career.Appearances, appearances, "Duplicate fixture changed stats")
	end)

	test("legacy placeholder player migrates to schema", function()
		local slots = CareerConfig.NormalizeSlots({{Slot = 1, Type = "Player", Name = "ALEX VOLT", Season = "2026/27", Overall = 62, Club = "NO CLUB", Stats = {Appearances = 4, Goals = 2, Assists = 1}}, {Slot = 2, Type = "Empty"}, {Slot = 3, Type = "Empty"}})
		expectEqual(slots[1].Type, "Player", "Legacy player was not preserved")
		expect(slots[1].CareerId ~= nil and slots[1].Identity ~= nil and slots[1].Development ~= nil, "Legacy player was not enriched")
	end)

	test("client summary excludes full ledgers", function()
		local ok, creation = CareerConfig.NormalizeCreation({PrimaryPosition = "ST"})
		expect(ok, "Creation failed")
		local slot = CareerConfig.BuildPlayerCareer(1, creation)
		slot.Ledgers.ProcessedOperationIds.secret = true
		local summary = CareerConfig.ClientSummary(slot)
		expect(summary.Ledgers == nil, "Client summary exposed ledgers")
	end)

	test("fifteen season soak keeps values bounded", function()
		local p = profile()
		local service = CareerService.new(Store.new(p), function() end)
		local player = {Name = "Test", Parent = game} :: any
		service:CreatePlayerCareer(player, {Slot = 1, FirstName = "Mika", LastName = "Stone", PrimaryPosition = "CB", OriginId = "academy_graduate"})
		local career = p.CareerSaveSlots[1]
		for index = 1, 15 * 8 do
			service:SimulateCareerMatch(player, {CareerId = career.CareerId, OperationId = "soak_"..tostring(index)})
			expect(career.Condition.Fitness == nil or career.Condition.Fitness >= 0, "Fitness went negative")
			expect(career.Overall <= 99, "Overall escaped cap")
			expect(career.ClubState.ManagerTrust >= 0 and career.ClubState.ManagerTrust <= 100, "Trust escaped bounds")
		end
	end)

	return results
end

return Tests
