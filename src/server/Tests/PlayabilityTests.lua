--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.VTR.Shared
local ActionTuning = require(Shared.ActionTuningConfig)
local AIBehaviorTuning = require(Shared.AIBehaviorTuningConfig)
local AITactic = require(Shared.AITacticConfig)
local AIPlaystyleConfig = require(Shared.AIPlaystyleConfig)
local AIPlaystyleResolver = require(Shared.AIPlaystyleResolver)
local AIMovementProfiles = require(Shared.AIMovementProfileConfig)
local BallContact = require(Shared.BallContactResolver)
local PassFlightModel = require(Shared.PassFlightModel)
local DefensiveSwitch = require(Shared.DefensiveSwitchConfig)
local DeviceGameplay = require(Shared.DeviceGameplayConfig)
local Difficulty = require(Shared.DifficultyConfig)
local DribbleTarget = require(Shared.DribbleTargetResolver)
local Gameplay = require(Shared.GameplayConfig)
local MatchExperience = require(Shared.MatchExperienceConfig)
local MatchFormat = require(Shared.MatchFormatConfig)
local MobileControlLayout = require(Shared.MobileControlLayout)
local Movement = require(Shared.MovementTuningConfig)
local PlayabilitySettings = require(Shared.PlayabilitySettingsConfig)
local PlayabilityUnlocks = require(Shared.PlayabilityUnlockConfig)
local PassError = require(Shared.PassErrorResolver)
local PassReception = require(Shared.PassReceptionConfig)
local ReceiverAssist = require(Shared.ReceiverAssistConfig)
local ReceptionIntercept = require(Shared.ReceptionInterceptResolver)
local ReceiverSwitch = require(Shared.ReceiverSwitchResolver)
local ShotPower = require(Shared.ShotPowerModel)
local Stamina = require(Shared.StaminaConfig)
local Tackle = require(Shared.TackleResolver)
local DebugPolicy = require(script.Parent.Parent.Gameplay.GameplayDebugPolicy)
local AIDifficulty = require(script.Parent.Parent.Gameplay.AIDifficultyService)
local AIMovementExecutor = require(script.Parent.Parent.Gameplay.AIMovementExecutor)
local PitchConfig = require(script.Parent.Parent.Gameplay.PitchConfig)
local AISpatialControlMap = require(script.Parent.Parent.Gameplay.TeamAI.AISpatialControlMap)
local AITacticalIntentDirector = require(script.Parent.Parent.Gameplay.TeamAI.AITacticalIntentDirector)
local AIPositionalStructurePlanner = require(script.Parent.Parent.Gameplay.TeamAI.AIPositionalStructurePlanner)
local AITacticalSlotAssignment = require(script.Parent.Parent.Gameplay.TeamAI.AITacticalSlotAssignment)
local AIPossessionDirector = require(script.Parent.Parent.Gameplay.TeamAI.AIPossessionDirector)
local AITeamMemory = require(script.Parent.Parent.Gameplay.TeamAI.AITeamMemory)
local AIDefensiveBlockPlanner = require(script.Parent.Parent.Gameplay.TeamAI.AIDefensiveBlockPlanner)
local AIDefensivePlan = require(script.Parent.Parent.Gameplay.TeamAI.AIDefensivePlan)
local AITacticalContract = require(script.Parent.Parent.Gameplay.TeamAI.AITacticalContract)
local AIRunCoordinator = require(script.Parent.Parent.Gameplay.TeamAI.AIRunCoordinator)
local AIShapeTemplateService = require(script.Parent.Parent.Gameplay.TeamAI.AIShapeTemplateService)
local AITeamBrain = require(script.Parent.Parent.Gameplay.TeamAI.AITeamBrain)
local AIMovementService = require(script.Parent.Parent.Gameplay.AIMovementService)
local AIPlayerBrain = require(script.Parent.Parent.Gameplay.AIPlayerBrain)
local AIStyleProfileService = require(script.Parent.Parent.Gameplay.TeamAI.AIStyleProfileService)
local AIOpponentObservationService = require(script.Parent.Parent.Gameplay.TeamAI.AIOpponentObservationService)
local AITacticalReactionService = require(script.Parent.Parent.Gameplay.TeamAI.AITacticalReactionService)
local AIPlaystyleRuleService = require(script.Parent.Parent.Gameplay.TeamAI.AIPlaystyleRuleService)
local AITeamMetrics = require(script.Parent.Parent.Gameplay.TeamAI.AITeamMetrics)
local AITacticalStyleService = require(script.Parent.Parent.Gameplay.AITacticalStyleService)
local AIPassExecutionPlanner = require(script.Parent.Parent.Gameplay.AIPassExecutionPlanner)
local PassArrivalPlanner = require(script.Parent.Parent.Gameplay.PassArrivalPlanner)
local MatchClock = require(script.Parent.Parent.Gameplay.MatchClockService)
local PassReceptionRuntime = require(script.Parent.Parent.Gameplay.PassReceptionService)
local ReplayRestartGate = require(script.Parent.Parent.Gameplay.ReplayRestartGate)
local StaminaService = require(script.Parent.Parent.Gameplay.StaminaService)
local PenaltyBoxService = require(script.Parent.Parent.Gameplay.PenaltyBoxService)
local DefaultProfile = require(script.Parent.Parent.Data.DefaultProfile)
local ProfileService = require(script.Parent.Parent.Services.ProfileService)

local Tests = {}

local function expect(condition: any, message: string)
	if not condition then error(message, 2) end
end

local function expectEqual(actual: any, expected: any, message: string)
	if actual ~= expected then error(message .. " | expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

function Tests.Run(): any
	local results = {Passed = 0, Failed = 0, Failures = {}, Names = {}}
	local function test(name: string, callback: () -> ())
		local ok, message = pcall(callback)
		table.insert(results.Names, name)
		if ok then results.Passed += 1 else results.Failed += 1 table.insert(results.Failures, name .. ": " .. tostring(message)) end
	end

	test("presentation profile resolution", function()
		expectEqual(MatchExperience.Resolve({FirstPlayableMatch = true}, {Onboarding = {Complete = true}}), "Acquisition", "First match profile")
		expectEqual(MatchExperience.Resolve({Mode = "Ranked"}, {Onboarding = {Complete = true}}), "Broadcast", "Ranked profile")
		expectEqual(MatchExperience.Resolve({}, {Onboarding = {Complete = true}}), "Standard", "Returning profile")
	end)

	test("presentation budgets", function()
		local acquisition = MatchExperience.Get("Acquisition")
		expect(acquisition.Duration >= 3 and acquisition.Duration <= 5, "Acquisition duration escaped budget")
		expect(acquisition.SkipLock == 0 and acquisition.Tunnel == false and acquisition.Lineup == false, "Acquisition contains blocking stages")
		expect(MatchExperience.Get("Standard").Duration <= 10, "Standard duration escaped budget")
		expect(MatchExperience.Get("Broadcast").Duration <= 25, "Broadcast duration escaped budget")
		expect(MatchExperience.Get("Acquisition").Duration ~= 66, "Legacy 66-second path remains")
	end)

	test("AI LAB playstyle schema normalizes high-impact controls", function()
		local draft = AIPlaystyleConfig.DraftFromTactics("Aggressive Stage Test", {PresetId = "high_press", Sliders = {PressingIntensity = 93, DefensiveDepth = 82, LooseBallAggression = 88}}, 123)
		expectEqual(draft.Status, "Draft", "Draft status changed")
		expectEqual(draft.Tactics.PresetId, "high_press", "Draft preset changed")
		expectEqual(draft.Tactics.Sliders.PressingIntensity, 93, "Pressing value did not normalize")
		local metadata = AIPlaystyleConfig.ClientMetadata()
		expectEqual(#metadata.HighImpactSettings, 10, "AI LAB does not expose exactly 10 high-impact settings")
	end)

	test("AI LAB published versions resolve immutably by side", function()
		local first = AIPlaystyleConfig.Normalize({Name = "Stage Build", PlaystyleId = "stage_build", Status = "Published", Version = 1, Tactics = {PresetId = "short_possession"}}, 456)
		local second = AIPlaystyleConfig.Normalize({Name = "Stage Build", PlaystyleId = "stage_build", Status = "Published", Version = 2, Tactics = {PresetId = "vertical_combination"}}, 456)
		local repository = {Published = {stage_build = {["1"] = first, ["2"] = second}}, Assignments = {Home = {PlaystyleId = "stage_build", Version = 1}, Away = {PlaystyleId = "stage_build", Version = 2}}}
		local home = AIPlaystyleResolver.ResolveSide("Home", repository)
		local away = AIPlaystyleResolver.ResolveSide("Away", repository)
		expectEqual(home.PlaystyleVersion, 1, "Home did not resolve assigned immutable version")
		expectEqual(home.PresetId, "short_possession", "Home resolved wrong version tactic")
		expectEqual(away.PlaystyleVersion, 2, "Away did not resolve assigned immutable version")
		expectEqual(away.PresetId, "vertical_combination", "Away resolved wrong version tactic")
	end)

	test("movement ranges", function()
		expect(Movement.JogMin >= 15 and Movement.JogMax <= 21, "Jog speed range")
		expect(Movement.SprintMin >= 21 and Movement.SprintMax <= 32, "Sprint speed range")
		expect(Movement.DribbleSprintMinMultiplier >= .84 and Movement.DribbleSprintMaxMultiplier <= .88, "On-ball sprint range")
		expect(Movement.SprintTurnPenalty >= .82 and Movement.SprintTurnPenalty <= .87, "Turn penalty range")
	end)

	test("stamina timing configuration", function()
		expect(100 / Stamina.SprintDrainLowRating >= 8 and 100 / Stamina.SprintDrainHighRating <= 12.5, "Sprint duration range")
		expect(100 / Stamina.JogRecoveryLowRating <= 18 and 100 / Stamina.JogRecoveryHighRating >= 12, "Jog recovery range")
		expect(100 / Stamina.IdleRecoveryLowRating <= 10 and 100 / Stamina.IdleRecoveryHighRating >= 7, "Idle recovery range")
		expect(Stamina.ExhaustedRecoveryThreshold >= 22 and Stamina.ExhaustedRecoveryThreshold <= 25, "Unlock hysteresis")
	end)

	test("stamina service aliases and freeze", function()
		local model = Instance.new("Model")
		model:SetAttribute("Stamina", 65)
		local service = StaminaService.new()
		local energy, _, actual = service:Step(model, 1, {SprintRequested = false, SprintAllowed = true, MoveMagnitude = 1, CurrentSpeed = 15})
		expect(actual == false and energy == 100, "No-input sprint activated")
		local drained = service:Step(model, 1, {SprintRequested = true, SprintAllowed = true, MoveMagnitude = 1, CurrentSpeed = 25})
		expect(drained < 100, "Requested sprint did not drain")
		local before = model:GetAttribute("VTRSprintEnergy")
		service:Step(model, 1, {SprintRequested = true, SprintAllowed = true, MoveMagnitude = 1, CurrentSpeed = 25, Frozen = true, SimulationPaused = true})
		expectEqual(model:GetAttribute("VTRSprintEnergy"), before, "Frozen simulation drained energy")
		expectEqual(model:GetAttribute("VTRSprintEnergy"), model:GetAttribute("VTRSprintStamina"), "Sprint alias diverged")
		expectEqual(model:GetAttribute("VTRSprintEnergy"), model:GetAttribute("VTREndurance"), "Endurance alias diverged")
		model:Destroy()
	end)

	test("per-footballer stamina recovery and substitution reset", function()
		local service = StaminaService.new()
		local playerA = Instance.new("Model")
		local playerB = Instance.new("Model")
		local substitute = Instance.new("Model")
		for _, model in {playerA, playerB, substitute} do model:SetAttribute("Stamina", 70);service:Reset(model) end
		for _ = 1, 80 do service:Step(playerA, .1, {SprintRequested = true, SprintAllowed = true, MoveMagnitude = 1, CurrentSpeed = 25}) end
		local drained = tonumber(playerA:GetAttribute("VTRSprintEnergy")) or 100
		expect(drained < 25, "Player A did not drain independently")
		for _ = 1, 100 do
			service:Step(playerA, .1, {SprintRequested = false, SprintAllowed = true, MoveMagnitude = 1, CurrentSpeed = 16})
			service:Step(playerB, .1, {SprintRequested = false, SprintAllowed = true, MoveMagnitude = 1, CurrentSpeed = 16})
		end
		expect((tonumber(playerA:GetAttribute("VTRSprintEnergy")) or 0) > drained, "Switched-away player did not recover")
		expectEqual(playerB:GetAttribute("VTRSprintEnergy"), Stamina.Maximum, "Player B inherited Player A energy")
		service:Reset(substitute)
		expectEqual(substitute:GetAttribute("VTRSprintEnergy"), Stamina.Maximum, "Substitute did not start full")
		expectEqual(substitute:GetAttribute("VTRSprintDuration"), 0, "Substitute sprint duration persisted")
		expect(substitute:GetAttribute("VTRSprintLocked") ~= true and substitute:GetAttribute("VTRSprinting") ~= true, "Substitute inherited sprint state")
		playerA:Destroy();playerB:Destroy();substitute:Destroy()
	end)

	test("AI stamina uses explicit sprint requests", function()
		local service = StaminaService.new()
		local model = Instance.new("Model")
		model:SetAttribute("Stamina", 80)
		service:Reset(model)
		for _ = 1, 30 do service:Step(model, .1, {SprintRequested = true, SprintAllowed = true, MoveMagnitude = 1, CurrentSpeed = 24}) end
		local drained = tonumber(model:GetAttribute("VTRSprintEnergy")) or 100
		for _ = 1, 30 do service:Step(model, .1, {SprintRequested = false, SprintAllowed = true, MoveMagnitude = 0, CurrentSpeed = 0}) end
		expect(drained < Stamina.Maximum and (tonumber(model:GetAttribute("VTRSprintEnergy")) or 0) > drained, "AI sprint did not drain and recover")
		model:Destroy()
	end)

	test("team intelligence spatial map resolves controlled far-side space", function()
		local function player(side: string, role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Anchored = true
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = side, Role = role, Pitch = pitch, World = pitch, Stats = {pace = 70}, Stamina = 80}
		end
		local homeA = player("Home", "Winger", Vector3.new(58, 3, 420))
		local homeB = player("Home", "CM", Vector3.new(190, 3, 320))
		local awayA = player("Away", "CB", Vector3.new(74, 3, 420))
		local awayB = player("Away", "Fullback", Vector3.new(112, 3, 390))
		local context = {
			Now = 10,
			BallTeam = {Home = Vector3.new(70, 3, 390), Away = Vector3.new(354, 3, 314)},
			Teams = {
				Home = {List = {homeA, homeB}},
				Away = {List = {awayA, awayB}},
			},
		}
		local map = AISpatialControlMap.new()
		map:Update(context)
		expectEqual(#map.Cells, 273, "Spatial map cell count changed")
		local far = map:BestCell("Home", 360, true)
		expect(far ~= nil, "Far-side space was not found")
		expect(far.Point.X > PitchConfig.HALF_WIDTH, "Far-side best cell did not switch away from pressure")
		for _, info in {homeA, homeB, awayA, awayB} do info.Model:Destroy() end
	end)

	test("team intelligence intent persists across minor owner movement", function()
		local style = {Ratio = function(_, key: string) if key == "PassingDirectness" then return .3 elseif key == "CounterAttackFrequency" then return .2 elseif key == "AttackingWidth" then return .55 elseif key == "PressingIntensity" then return .4 elseif key == "DefensiveDepth" then return .5 end return .5 end}
		local director = AITacticalIntentDirector.new()
		local memory = AITeamMemory.new()
		local context = {Now = 5, OwnerSide = "Home", Owner = nil, LooseBall = false, MatchState = "HomePossession", BallTeam = {Home = Vector3.new(210, 3, 130), Away = Vector3.new(214, 3, 574)}, DefensivePress = {Home = {}, Away = {Active = false}}}
		local first = director:Update(context, {Home = style, Away = style}, nil, memory)
		expectEqual(first.Home.Intent, "BuildOut", "Initial build-out intent")
		context.Now = 5.2
		context.BallTeam.Home = Vector3.new(216, 3, 146)
		local second = director:Update(context, {Home = style, Away = style}, nil, memory)
		expectEqual(second.Home.Intent, "BuildOut", "Intent switched inside commitment window")
	end)

	test("team intelligence slot assignment preserves user and fills rest defense", function()
		local function info(name: string, role: string, pitch: Vector3, user: boolean?): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRTeam", "Home")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Anchored = true
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = "Home", Role = role, Pitch = pitch, World = pitch, BasePitch = pitch, Stats = {pace = 65}, Stamina = 80, IsUserControlled = user == true}
		end
		local players = {
			info("User", "CM", Vector3.new(210, 3, 230), true),
			info("CB1", "CB", Vector3.new(120, 3, 95)),
			info("CB2", "CB", Vector3.new(300, 3, 95)),
			info("DM", "CDM", Vector3.new(210, 3, 155)),
			info("W", "Winger", Vector3.new(52, 3, 310)),
			info("ST", "ST", Vector3.new(210, 3, 440)),
		}
		local style = {Ratio = function(_, key: string) if key == "AttackingWidth" then return .75 elseif key == "SupportDistance" then return .45 elseif key == "DefensiveDepth" then return .5 end return .5 end}
		local context = {OwnerSide = "Home", BallTeam = {Home = Vector3.new(185, 3, 210)}, BallWorld = Vector3.new(185, 3, 210), Teams = {Home = {List = players}}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		local slots = AIPositionalStructurePlanner.Build(context, "Home", style, {Intent = "BuildOut"}, nil)
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", slots)
		expect(assignments[players[1].Model] ~= nil and assignments[players[1].Model].ReservedByUser == true, "User-controlled footballer did not reserve a tactical slot")
		expectEqual(#slots, #players, "Shape did not create one function per active footballer")
		local rest = false
		for model, assignment in pairs(assignments) do
			if assignment.TacticalSlot and assignment.TacticalSlot.RestDefense == true then rest = true end
			expect(model:GetAttribute("AITacticalSlot") ~= nil, "Assigned player missing tactical slot attribute")
		end
		expect(rest, "No rest-defense slot assigned")
		for _, playerInfo in players do playerInfo.Model:Destroy() end
	end)

	test("team tactical contract schema exposes football control fields", function()
		local target = Vector3.new(210, 3, 420)
		local slot = AITacticalContract.Slot({Id = "central-forward", Function = "Finisher", RoleFamily = "ST", TargetPitch = target, Priority = 80, SprintAllowed = true})
		local step = AITacticalContract.PlanStep({Id = "runner", RequiredOccupations = {"rest-defense", "central-forward"}, PreferredReceiver = "central-forward", PassBias = "ForwardEarly", RunRequests = {"central-forward"}})
		local run = AITacticalContract.Run({Id = "Run:central-forward", Kind = "DepthRun", TargetRegion = slot.TargetRegion, StartTime = 4, Expiry = 6})
		local player = AITacticalContract.Player({SlotId = slot.Id, TargetRegion = slot.TargetRegion, PreferredTarget = target, AllowedActions = slot.AllowedActions, ForbiddenActions = {"RiskDribble"}, PlanStep = step, RunContract = run, MinimumHoldUntil = 4.2})
		expectEqual(slot.Function, "Finisher", "Slot function missing")
		expectEqual(slot.TargetRegion.Center, target, "Slot target region missing")
		expectEqual(step.PreferredReceiver, "central-forward", "Plan preferred receiver missing")
		expectEqual(run.Kind, "DepthRun", "Run contract kind missing")
		expectEqual(player.SlotId, "central-forward", "Player contract slot id missing")
		expect(AITacticalContract.ActionAllowed(player, "Shoot"), "Allowed action was blocked")
		expect(not AITacticalContract.ActionAllowed(player, "RiskDribble"), "Forbidden action was allowed")
	end)

	test("team run coordinator preserves rest-defense contracts", function()
		local restModel = Instance.new("Model")
		local runnerModel = Instance.new("Model")
		local restSlot = AITacticalContract.Slot({Id = "rest-defense", Function = "RestDefense", RoleFamily = "CB", TargetPitch = Vector3.new(212, 3, 120), RestDefense = true})
		local runnerSlot = AITacticalContract.Slot({Id = "central-forward", Function = "Finisher", RoleFamily = "ST", TargetPitch = Vector3.new(212, 3, 620), SprintAllowed = true})
		local assignments = {
			[restModel] = {TacticalSlot = restSlot, PlayerContract = AITacticalContract.Player({SlotId = restSlot.Id, AllowedActions = restSlot.AllowedActions})},
			[runnerModel] = {TacticalSlot = runnerSlot, PlayerContract = AITacticalContract.Player({SlotId = runnerSlot.Id, AllowedActions = runnerSlot.AllowedActions}), MovementUrgency = .7},
		}
		AIRunCoordinator.Apply({Now = 10, TeamBrain = {Home = {AttackingRunners = 2}}}, "Home", assignments, {Intent = "DirectRelease", PlanStep = AITacticalContract.PlanStep({Id = "runner"})}, {Ratio = function() return .7 end})
		expect(restModel:GetAttribute("VTRRunApproved") == false, "Rest-defense slot was approved for a run")
		expect(assignments[restModel].PlayerContract.ReplacementRequirement == "HoldRestDefense", "Rest-defense replacement requirement missing")
		expect(runnerModel:GetAttribute("VTRRunApproved") == true, "Runner was not approved")
		expect(assignments[runnerModel].RunContract ~= nil, "Runner missing run contract")
		expect(assignments[runnerModel].PlayerContract.ReplacementRequirement == "RestDefenseCoverage", "Runner did not demand replacement coverage")
		restModel:Destroy()
		runnerModel:Destroy()
	end)

	test("canonical mirrored spatial control uses one physical pitch frame", function()
		local function player(side: string, canonical: Vector3): any
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Anchored = true
			root.Position = canonical
			root.Parent = model
			local pitch = PitchConfig.CanonicalPitchToTeamPitchPosition(canonical, side, {AttackSigns = {Home = 1, Away = -1}})
			return {Model = model, Root = root, Side = side, Role = "CM", Pitch = pitch, CanonicalPitch = canonical, World = canonical, Stats = {pace = 70}, Stamina = 80}
		end
		local homeNear = Vector3.new(98, 3, 520)
		local awayNear = Vector3.new(PitchConfig.PITCH_WIDTH - 98, 3, PitchConfig.PITCH_LENGTH - 520)
		local context = {
			Now = 1,
			Options = {AttackSigns = {Home = 1, Away = -1}},
			BallCanonical = Vector3.new(PitchConfig.HALF_WIDTH, 3, PitchConfig.HALF_LENGTH),
			BallTeam = {Home = Vector3.new(PitchConfig.HALF_WIDTH, 3, PitchConfig.HALF_LENGTH)},
			Teams = {
				Home = {List = {player("Home", homeNear), player("Home", Vector3.new(330, 3, 150))}},
				Away = {List = {player("Away", awayNear), player("Away", Vector3.new(90, 3, 600))}},
			},
		}
		local map = AISpatialControlMap.new()
		map:Update(context)
		local function nearestCell(target: Vector3): any
			local best = nil
			local distance = math.huge
			for _, cell in ipairs(map.Cells) do
				local d = PitchConfig.GetDistanceStuds(cell.CanonicalPoint, target)
				if d < distance then best = cell;distance = d end
			end
			return best
		end
		local homeCell = nearestCell(homeNear)
		local awayCell = nearestCell(awayNear)
		expect(homeCell.HomeAdvantage > 0, "Home did not own the physically near cell")
		expect(awayCell.AwayAdvantage > 0, "Away did not own the mirrored physical cell")
		expect(math.abs(homeCell.HomeAdvantage - awayCell.AwayAdvantage) < .45, "Mirrored spatial advantages diverged")
		for _, team in pairs(context.Teams) do for _, info in ipairs(team.List) do info.Model:Destroy() end end
	end)

	test("5v5 possession shape creates exactly six occupied tactical functions", function()
		local players = {}
		for index, role in ipairs({"GK", "CB", "CM", "CM", "ST", "ST"}) do
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = model
			table.insert(players, {Model = model, Root = root, Side = "Home", Index = index, Role = role, Pitch = Vector3.new(80 + index * 38, 3, 170 + index * 25), World = Vector3.new(80 + index * 38, 3, 170 + index * 25), Stats = {pace = 70}, Stamina = 80, IsGoalkeeper = role == "GK"})
		end
		local style = {Ratio = function() return .5 end}
		local context = {OwnerSide = "Home", Formations = {Home = "4-3-3"}, BallTeam = {Home = Vector3.new(210, 3, 260)}, BallWorld = Vector3.new(210, 3, 260), TeamBrain = {Home = {AttackingIdentity = "PositionalControl"}}, Teams = {Home = {List = players}, Away = {List = {}}}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		local slots = AIShapeTemplateService.Build(context, "Home", style, {Intent = "BuildOut"}, nil, nil)
		expectEqual(#slots, 6, "5V5 shape did not create six functions")
		local functions = {}
		for _, slot in ipairs(slots) do functions[slot.Function] = true end
		expect(functions["Goalkeeper outlet"], "5V5 missing goalkeeper function")
		expect(functions["Central rest defender"], "5V5 missing rest-defence function")
		expect(functions["Left support midfielder"] or functions["Right support midfielder"], "5V5 missing midfield support")
		expect(functions["Left forward depth"] and functions["Right forward depth"], "5V5 missing forward depth")
		for _, info in ipairs(players) do info.Model:Destroy() end
	end)

	test("formation templates preserve required tactical functions", function()
		local function contextFor(formation: string): any
			local players = {}
			for index = 1, 11 do
				local role = index == 1 and "GK" or index <= 5 and "CB" or index <= 8 and "CM" or index <= 10 and "Winger" or "ST"
				local model = Instance.new("Model")
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Parent = model
				table.insert(players, {Model = model, Root = root, Side = "Home", Index = index, Role = role, Pitch = Vector3.new(70 + index * 22, 3, 140 + index * 28), World = Vector3.new(70 + index * 22, 3, 140 + index * 28), Stats = {pace = 70}, Stamina = 80, IsGoalkeeper = index == 1})
			end
			return {PlayersList = players, Context = {OwnerSide = "Home", Formations = {Home = formation}, BallTeam = {Home = Vector3.new(212, 3, 310)}, BallWorld = Vector3.new(212, 3, 310), TeamBrain = {Home = {AttackingIdentity = "Balanced"}}, Teams = {Home = {List = players}, Away = {List = {}}}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}}
		end
		local style = {Ratio = function() return .5 end}
		local function count(slots: {any}, predicate: (any) -> boolean): number
			local total = 0
			for _, slot in ipairs(slots) do if predicate(slot) then total += 1 end end
			return total
		end
		local fourTwoThreeOne = contextFor("4-2-3-1")
		local slots4231 = AIShapeTemplateService.Build(fourTwoThreeOne.Context, "Home", style, nil, nil, nil)
		expectEqual(count(slots4231, function(slot: any) return slot.Function == "Ball-side pivot" or slot.Function == "Far-side pivot" end), 2, "4-2-3-1 did not keep two pivots")
		expectEqual(count(slots4231, function(slot: any) return slot.Function == "Between-lines receiver" end), 1, "4-2-3-1 missing attacking midfielder")
		local fourFourTwo = contextFor("4-4-2")
		local slots442 = AIShapeTemplateService.Build(fourFourTwo.Context, "Home", style, nil, nil, nil)
		expectEqual(count(slots442, function(slot: any) return slot.Line == "Forward" end), 2, "4-4-2 did not keep two forwards")
		local threeFiveTwo = contextFor("3-5-2")
		local slots352 = AIShapeTemplateService.Build(threeFiveTwo.Context, "Home", style, nil, nil, nil)
		expectEqual(count(slots352, function(slot: any) return slot.Line == "Back" and slot.RoleFamily == "CB" end), 3, "3-5-2 did not keep three back-line functions")
		expect(count(slots352, function(slot: any) return slot.Function == "Ball-side width" or slot.Function == "Far-side width" end) >= 2, "3-5-2 did not keep two wide functions")
		expectEqual(count(slots352, function(slot: any) return slot.Line == "Forward" end), 2, "3-5-2 did not keep two forwards")
		for _, pack in {fourTwoThreeOne, fourFourTwo, threeFiveTwo} do for _, info in ipairs(pack.PlayersList) do info.Model:Destroy() end end
	end)

	test("user-controlled player reserves function and remaining functions fill", function()
		local players = {}
		for index, role in ipairs({"GK", "CB", "CM", "CM", "ST", "ST"}) do
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = model
			table.insert(players, {Model = model, Root = root, Side = "Home", Index = index, Role = role, Pitch = Vector3.new(80 + index * 40, 3, 180 + index * 30), World = Vector3.new(80 + index * 40, 3, 180 + index * 30), Stats = {pace = 70}, Stamina = 80, IsGoalkeeper = role == "GK", IsUserControlled = index == 3})
		end
		local context = {Now = 5, OwnerSide = "Home", Formations = {Home = "4-3-3"}, BallTeam = {Home = Vector3.new(212, 3, 280)}, BallWorld = Vector3.new(212, 3, 280), TeamBrain = {Home = {AttackingIdentity = "PositionalControl"}}, TeamPlans = {Home = {PlanStep = AITacticalContract.PlanStep({Id = "reset"})}}, Teams = {Home = {List = players}, Away = {List = {}}}, Players = {}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		for _, info in ipairs(players) do context.Players[info.Model] = info end
		local slots = AIShapeTemplateService.Build(context, "Home", {Ratio = function() return .5 end}, nil, nil, context.TeamPlans.Home)
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", slots)
		local assigned = 0
		for _ in pairs(assignments) do assigned += 1 end
		expectEqual(assigned, #players, "Not every active player occupied a function")
		expect(assignments[players[3].Model] and assignments[players[3].Model].ReservedByUser == true, "Human did not reserve a function")
		for _, info in ipairs(players) do info.Model:Destroy() end
	end)

	test("team intelligence possession plan survives owner change", function()
		local director = AIPossessionDirector.new()
		local memory = AITeamMemory.new()
		local context = {Now = 20, Owner = Instance.new("Model")}
		local first = director:Update(context, "Home", {Intent = "SwitchPlay"}, nil, memory)
		context.Now = 21
		context.Owner = Instance.new("Model")
		local second = director:Update(context, "Home", {Intent = "SwitchPlay"}, nil, memory)
		expect(first == second, "Possession plan reset on owner change")
		expectEqual(second.Route[2], "far-side-switch", "Switch route changed")
		first.Owner:Destroy()
		context.Owner:Destroy()
	end)

	test("defensive block planner keeps compact line gaps and tactic differences", function()
		local style = {Ratio = function(_, key: string) if key == "DefensiveWidth" then return .45 elseif key == "DefensiveDepth" then return .5 elseif key == "BackLineCompactness" then return .75 elseif key == "ZoneDiscipline" then return .7 elseif key == "BoxProtection" then return .65 elseif key == "LaneBlocking" then return .75 elseif key == "PressingIntensity" then return .45 end return .5 end}
		local highStyle = {Ratio = function(_, key: string) if key == "DefensiveDepth" then return .9 elseif key == "PressingIntensity" then return .95 elseif key == "BackLineCompactness" then return .55 end return .55 end}
		local function defender(role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = "Away", Role = role, Pitch = pitch, World = pitch, Stats = {pace = 65}, Stamina = 80}
		end
		local list = {defender("ST", Vector3.new(210, 3, 500)), defender("CM", Vector3.new(180, 3, 360)), defender("CDM", Vector3.new(220, 3, 310)), defender("CB", Vector3.new(150, 3, 170)), defender("CB", Vector3.new(270, 3, 170)), defender("Fullback", Vector3.new(70, 3, 185)), defender("Fullback", Vector3.new(350, 3, 185))}
		local context = {Now = 1, BallTeam = {Away = Vector3.new(75, 3, 360)}, Teams = {Away = {List = list}}}
		local planner = AIDefensiveBlockPlanner.new()
		local mid = planner:Build(context, "Away", style, {Intent = "MidBlock"})
		local high = planner:Build(context, "Away", highStyle, {Intent = "HighPress"})
		expect(mid.MidfieldLineZ - mid.BackLineZ >= 36 and mid.MidfieldLineZ - mid.BackLineZ <= 58, "Mid-block back-to-mid gap escaped range")
		expect(mid.ForwardLineZ - mid.MidfieldLineZ >= 40 and mid.ForwardLineZ - mid.MidfieldLineZ <= 68, "Mid-block mid-to-forward gap escaped range")
		expect(high.BackLineZ > mid.BackLineZ, "High press did not raise the back line")
		expect(mid.FarSideTuck >= 20, "Far-side tuck missing")
		expect(mid.ConcededLane == "SideOrBack", "Safe circulation lane not conceded")
		for _, item in list do item.Model:Destroy() end
	end)

	test("goalkeeper outlet stays inside settled possession envelope", function()
		local keeper = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = keeper
		local players = {{Model = keeper, Root = root, Side = "Home", Index = 1, Role = "GK", Pitch = Vector3.new(212, 3, 32), World = Vector3.new(212, 3, 32), Stats = {pace = 60}, Stamina = 80, IsGoalkeeper = true}}
		for index = 2, 11 do
			local model = Instance.new("Model")
			local part = Instance.new("Part")
			part.Name = "HumanoidRootPart"
			part.Parent = model
			table.insert(players, {Model = model, Root = part, Side = "Home", Index = index, Role = index <= 5 and "CB" or index <= 8 and "CM" or index <= 10 and "Winger" or "ST", Pitch = Vector3.new(70 + index * 24, 3, 120 + index * 22), World = Vector3.new(70 + index * 24, 3, 120 + index * 22), Stats = {pace = 70}, Stamina = 80})
		end
		local context = {OwnerSide = "Home", Formations = {Home = "4-3-3"}, BallTeam = {Home = Vector3.new(212, 3, 260)}, BallWorld = Vector3.new(212, 3, 260), TeamBrain = {Home = {AttackingIdentity = "PositionalControl"}}, Teams = {Home = {List = players}, Away = {List = {}}}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		local slots = AIShapeTemplateService.Build(context, "Home", {Ratio = function() return .45 end}, nil, nil, nil)
		local keeperSlot = nil
		for _, slot in ipairs(slots) do if slot.Line == "Goalkeeper" then keeperSlot = slot end end
		expect(keeperSlot ~= nil, "Shape missing goalkeeper slot")
		expect(keeperSlot.TargetPitch.Z >= 24 and keeperSlot.TargetPitch.Z <= 65, "Settled possession goalkeeper escaped envelope")
		for _, info in ipairs(players) do info.Model:Destroy() end
	end)

	test("minor ball movement preserves assignment continuity", function()
		local players = {}
		for index, role in ipairs({"GK", "CB", "CB", "Fullback", "Fullback", "CDM", "CM", "CAM", "Winger", "Winger", "ST"}) do
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Parent = model
			table.insert(players, {Model = model, Root = root, Side = "Home", Index = index, Role = role, Lane = "Central", Pitch = Vector3.new(52 + index * 30, 3, 110 + index * 30), World = Vector3.new(52 + index * 30, 3, 110 + index * 30), Stats = {pace = 70}, Stamina = 80, IsGoalkeeper = role == "GK"})
		end
		local baseContext = {Now = 10, OwnerSide = "Home", Formations = {Home = "4-2-3-1"}, BallTeam = {Home = Vector3.new(210, 3, 300)}, BallWorld = Vector3.new(210, 3, 300), TeamBrain = {Home = {AttackingIdentity = "PositionalControl"}}, TeamPlans = {Home = {PlanStep = AITacticalContract.PlanStep({Id = "reset"})}}, Teams = {Home = {List = players}, Away = {List = {}}}, Players = {}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		for _, info in ipairs(players) do baseContext.Players[info.Model] = info end
		local slots = AIShapeTemplateService.Build(baseContext, "Home", {Ratio = function() return .5 end}, nil, nil, baseContext.TeamPlans.Home)
		local first = AITacticalSlotAssignment.Assign(baseContext, "Home", slots)
		local nextContext = table.clone(baseContext)
		nextContext.Now = 10.2
		nextContext.PreviousAssignments = {Home = first}
		nextContext.BallTeam = {Home = Vector3.new(214, 3, 304)}
		local nextSlots = AIShapeTemplateService.Build(nextContext, "Home", {Ratio = function() return .5 end}, nil, nil, nextContext.TeamPlans.Home)
		local second = AITacticalSlotAssignment.Assign(nextContext, "Home", nextSlots)
		local same = 0
		for model, assignment in pairs(first) do
			if second[model] and second[model].TacticalSlot and assignment.TacticalSlot and second[model].TacticalSlot.Id == assignment.TacticalSlot.Id then
				same += 1
			end
		end
		expect(same >= #players - 2, "Minor ball movement caused excessive assignment churn")
		for _, info in ipairs(players) do info.Model:Destroy() end
	end)

	test("run tickets survive movement application", function()
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(0, 3, 0)
		root.Parent = model
		local commands = {}
		local movement = AIMovementService.new({SetCommand = function(_, targetModel: Model, command: any) commands[targetModel] = command end, Step = function() end, Clear = function() end})
		local assignment = {PrimaryAssignment = "central-forward", TargetWorld = Vector3.new(25, 3, 0), MovementTarget = Vector3.new(25, 3, 0), MovementUrgency = 1, SprintAllowed = true, RunApproved = true, RunTicketId = "Run:central-forward", RunKind = "DepthRun", RunTarget = Vector3.new(25, 3, 0), RunTrigger = "runner", RunExpiry = 13}
		local context = {Now = 10, BallWorld = Vector3.new(0, 3, 0), PitchCFrame = CFrame.new(), BallVelocity = Vector3.zero, OwnerSide = "Home"}
		local info = {Model = model, Root = root, Side = "Home", Role = "ST", World = root.Position, Pitch = root.Position, Stats = {pace = 70}, Stamina = 80}
		movement:Apply(info, assignment, context, .05)
		expectEqual(model:GetAttribute("VTRRunTicketId"), "Run:central-forward", "Movement wiped run ticket")
		expectEqual(model:GetAttribute("VTRRunKind"), "DepthRun", "Movement wiped run kind")
		expectEqual(model:GetAttribute("VTRRunTrigger"), "runner", "Movement wiped run trigger")
		expect(commands[model] and commands[model].RunTicketId == "Run:central-forward", "Executor command lost run ticket")
		model:Destroy()
	end)

	test("team brain AfterGain is always a string", function()
		local style = {Ratio = function(_, key: string) if key == "PassingDirectness" then return 1 elseif key == "PassTempo" then return 1 elseif key == "RunsInBehind" then return 1 elseif key == "CounterAttackFrequency" then return 1 end return .2 end}
		local brain = AITeamBrain.new(nil, {Home = style, Away = style}, {})
		local function info(side: string): any
			local model = Instance.new("Model")
			return {Model = model, Root = Instance.new("Part"), Side = side, Pitch = Vector3.new(212, 3, 300), World = Vector3.new(212, 3, 300), Stats = {pace = 70}, Stamina = 80}
		end
		local home = info("Home")
		local away = info("Away")
		local context = {BallWorld = Vector3.new(212, 3, 300), Teams = {Home = {List = {home}}, Away = {List = {away}}}}
		local declarations = brain:Declare(context)
		expect(type(declarations.Home.AfterGain) == "string", "Home AfterGain was not a string")
		expect(type(declarations.Away.AfterGain) == "string", "Away AfterGain was not a string")
		expectEqual(declarations.Home.AfterGain, "ForwardFirst", "Direct or counter style did not produce ForwardFirst")
		home.Model:Destroy()
		away.Model:Destroy()
	end)

	test("built-in style profiles expose explicit attacking blends", function()
		local vertical = AIStyleProfileService.Blends({PresetId = "vertical_combination"})
		local central = AIStyleProfileService.Blends({PresetId = "central_overload"})
		local counter = AIStyleProfileService.Blends({PresetId = "counter_attack"})
		local verticalLead = AIStyleProfileService.Leading(vertical.Attack)
		local centralLead = AIStyleProfileService.Leading(central.Attack)
		expectEqual(verticalLead, "VerticalCombination", "vertical_combination preset did not lead with VerticalCombination")
		expectEqual(centralLead, "CentralDomination", "central_overload preset did not lead with CentralDomination")
		expect((counter.Attack.CounterattackingTrap or 0) >= .45, "counter_attack did not make CounterattackingTrap a major attack identity")
	end)

	test("opponent observation separates attack and defence confidence with hysteresis", function()
		local observer = AIOpponentObservationService.new()
		local function info(side: string, name: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model.Name = name
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = "CM", Pitch = pitch, World = pitch, Stats = {pace = 70}, Stamina = 80}
		end
		local awayA = info("Away", "AwayA", Vector3.new(180, 3, 180))
		local awayB = info("Away", "AwayB", Vector3.new(210, 3, 360))
		local awayWide = info("Away", "AwayWide", Vector3.new(50, 3, 430))
		local homeA = info("Home", "HomeA", Vector3.new(212, 3, 330))
		local context = {Now = 1, Owner = awayA.Model, OwnerSide = "Away", BallWorld = awayA.World, BallTeam = {Home = Vector3.new(212, 3, 560), Away = Vector3.new(212, 3, 180)}, Teams = {Home = {List = {homeA}}, Away = {List = {awayA, awayB, awayWide}}}, Players = {[awayA.Model] = awayA, [awayB.Model] = awayB, [awayWide.Model] = awayWide, [homeA.Model] = homeA}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		observer:Observe(context, nil)
		context.Now = 1.2
		context.Owner = awayB.Model
		context.BallWorld = awayB.World
		context.BallTeam.Away = awayB.Pitch
		local oneFrame = observer:Observe(context, nil).Home
		expect(oneFrame.OpponentAttackIdentity ~= "DirectAssault", "Single direct frame switched observed attack identity")
		for step = 1, 10 do
			context.Now += .25
			context.Owner = step % 2 == 0 and awayA.Model or awayB.Model
			context.BallWorld = context.Players[context.Owner].World
			context.BallTeam.Away = context.Players[context.Owner].Pitch
			observer:Observe(context, nil)
		end
		local sustainedDirect = observer:ForSide("Home")
		expect((sustainedDirect.OpponentAttackConfidence.DirectAssault or 0) > (sustainedDirect.OpponentAttackConfidence.PositionalControl or 0), "Sustained direct play did not increase DirectAssault confidence")
		for step = 1, 12 do
			context.Now += .25
			context.Owner = awayWide.Model
			context.BallWorld = awayWide.World
			context.BallTeam.Away = awayWide.Pitch
			observer:Observe(context, nil)
		end
		local wide = observer:ForSide("Home")
		expect((wide.OpponentAttackConfidence.WideOverload or 0) > .13, "Sustained wide occupation did not increase WideOverload confidence")
		context.Owner = homeA.Model
		context.OwnerSide = "Home"
		context.BallWorld = homeA.World
		context.BallTeam.Home = homeA.Pitch
		for index, away in ipairs({awayA, awayB, awayWide}) do
			away.Pitch = Vector3.new(170 + index * 12, 3, 500 + index * 8)
			away.World = away.Pitch
			away.Root.Position = away.Pitch
		end
		for step = 1, 10 do
			context.Now += .25
			observer:Observe(context, nil)
		end
		local defended = observer:ForSide("Home")
		expect((defended.OpponentDefenseConfidence.CollectiveHunt or 0) > (defended.OpponentDefenseConfidence.BoxProtection or 0), "Sustained high pressing did not increase CollectiveHunt defence confidence")
		expect(defended.OpponentAttackConfidence ~= defended.OpponentDefenseConfidence, "Opponent attack and defence confidence were not separate tables")
		for _, item in {awayA, awayB, awayWide, homeA} do item.Model:Destroy() end
	end)

	test("observed reactions alter defensive block shape", function()
		local style = {Ratio = function(_, key: string) if key == "DefensiveWidth" then return .5 elseif key == "DefensiveDepth" then return .55 elseif key == "BackLineCompactness" then return .52 elseif key == "ZoneDiscipline" then return .55 elseif key == "BoxProtection" then return .45 elseif key == "LaneBlocking" then return .42 elseif key == "PressingIntensity" then return .45 end return .5 end}
		local function defender(role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = "Home", Role = role, Pitch = pitch, World = pitch, Stats = {pace = 65}, Stamina = 80}
		end
		local list = {defender("ST", Vector3.new(210, 3, 500)), defender("CM", Vector3.new(180, 3, 360)), defender("CDM", Vector3.new(220, 3, 310)), defender("CB", Vector3.new(150, 3, 170)), defender("CB", Vector3.new(270, 3, 170)), defender("Fullback", Vector3.new(70, 3, 185)), defender("Fullback", Vector3.new(350, 3, 185))}
		local planner = AIDefensiveBlockPlanner.new()
		local baseContext = {Now = 1, BallTeam = {Home = Vector3.new(212, 3, 360)}, Teams = {Home = {List = list}}}
		local base = planner:Build(baseContext, "Home", style, {Intent = "MidBlock"})
		local directContext = {Now = 2, BallTeam = baseContext.BallTeam, Teams = baseContext.Teams, TeamReactions = {Home = {AgainstOpponentAttack = {LineHeight = -.28, DepthCover = .3}}}}
		local direct = planner:Build(directContext, "Home", style, {Intent = "MidBlock"})
		expect(direct.BackLineZ < base.BackLineZ, "DirectAssault reaction did not lower defensive line")
		local centralContext = {Now = 3, BallTeam = baseContext.BallTeam, Teams = baseContext.Teams, TeamReactions = {Home = {AgainstOpponentAttack = {BlockWidth = -.22, LaneProtection = .3, CentralScreens = .3}}}}
		local central = planner:Build(centralContext, "Home", style, {Intent = "MidBlock"})
		expect(central.BlockWidth < base.BlockWidth and central.BlockedLane == "CentralPivot", "CentralDomination reaction did not narrow block and protect lane")
		local wideContext = {Now = 4, BallTeam = baseContext.BallTeam, Teams = baseContext.Teams, TeamReactions = {Home = {AgainstOpponentAttack = {CutbackProtection = .28, FarPostProtection = .28, SwitchDefender = .18}}}}
		local wide = planner:Build(wideContext, "Home", style, {Intent = "MidBlock"})
		expect(wide.FarSideTuck > base.FarSideTuck and wide.Compactness >= base.Compactness, "WideOverload reaction did not increase far-post or cutback protection")
		for _, item in list do item.Model:Destroy() end
	end)

	test("reaction matrix blends top two behaviours", function()
		local context = {OwnerSide = "Away", OpponentObservation = {Home = {OpponentAttackConfidence = {DirectAssault = .42, WideOverload = .36}, OpponentDefenseConfidence = {}, OpponentAttackIdentity = "DirectAssault", OpponentDefenseIdentity = "StructuredContainment"}}}
		local reaction = AITacticalReactionService.ForSide(context, "Home").AgainstOpponentAttack
		expect(reaction.Blended == true, "Top two observed attack behaviours did not blend")
		expect((reaction.DepthCover or 0) > 0 and (reaction.CutbackProtection or 0) > 0, "Blended reaction did not include both DirectAssault and WideOverload responses")
	end)

	test("CollectiveHunt defence reaction creates close support and direct outlet route", function()
		local director = AIPossessionDirector.new()
		local context = {Now = 1, OwnerSide = "Home", Owner = Instance.new("Model"), BallTeam = {Home = Vector3.new(212, 3, 330)}, BallWorld = Vector3.new(212, 3, 330), TeamBrain = {Home = {AttackingIdentity = "PositionalControl", AttackCorridor = "Balanced"}}, TeamReactions = {Home = {AgainstOpponentDefense = {CloseEscapeSupport = .32, DirectOutlet = .3, SupportDistance = -.18}}}, TeamStructures = {Home = {{Id = "checking-striker"}, {Id = "ball-side-pivot"}, {Id = "between-lines-receiver"}, {Id = "second-ball-midfielder"}, {Id = "central-forward"}}}, Teams = {Home = {List = {}}, Away = {List = {}}}, Players = {}}
		local plan = director:Update(context, "Home", {Intent = "BuildOut"}, nil, nil)
		expectEqual(plan.Route[1], "bounce-pass", "CollectiveHunt reaction did not select close escape/direct outlet route")
		local model = Instance.new("Model")
		local slot = AITacticalContract.Slot({Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(212, 3, 340)})
		local assignments = {[model] = {TacticalSlot = slot, TargetPitch = slot.TargetPitch, TargetWorld = slot.TargetPitch, MovementUrgency = .7, PlayerContract = AITacticalContract.Player({SlotId = slot.Id})}}
		AISupportCoordinator.Apply(context, "Home", assignments, plan)
		expect(model:GetAttribute("VTRSupportKind") == "NearPassingTriangle", "CollectiveHunt reaction did not create close support")
		context.Owner:Destroy();model:Destroy()
	end)

	test("configured opponent tactic is only a weak prior", function()
		local observer = AIOpponentObservationService.new({Away = {PresetId = "low_block_counter"}, Home = {PresetId = "balanced_control"}})
		local function info(side: string, name: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model.Name = name
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = "CM", Pitch = pitch, World = pitch, Stats = {pace = 70}, Stamina = 80}
		end
		local awayA = info("Away", "AwayA", Vector3.new(60, 3, 500))
		local awayB = info("Away", "AwayB", Vector3.new(75, 3, 530))
		local homeA = info("Home", "HomeA", Vector3.new(212, 3, 300))
		local context = {Now = 1, Owner = awayA.Model, OwnerSide = "Away", BallWorld = awayA.World, BallTeam = {Home = Vector3.new(212, 3, 240), Away = awayA.Pitch}, Teams = {Home = {List = {homeA}}, Away = {List = {awayA, awayB}}}, Players = {[awayA.Model] = awayA, [awayB.Model] = awayB, [homeA.Model] = homeA}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		for step = 1, 12 do
			context.Now += .25
			context.Owner = step % 2 == 0 and awayA.Model or awayB.Model
			context.BallWorld = context.Players[context.Owner].World
			context.BallTeam.Away = context.Players[context.Owner].Pitch
			observer:Observe(context, {Away = {PresetId = "low_block_counter"}, Home = {PresetId = "balanced_control"}})
		end
		local observed = observer:ForSide("Home")
		expect((observed.OpponentAttackConfidence.WideOverload or 0) > .16, "Observed wide behavior did not overcome configured low-block prior")
		expect((observed.OpponentAttackConfidence.CounterattackingTrap or 0) < .75, "Configured preset was treated as perfect behavioral truth")
		for _, item in {awayA, awayB, homeA} do item.Model:Destroy() end
	end)

	test("context-aware style resolution and AI Lab rules execute safely", function()
		local style = AITacticalStyleService.new({
			PresetId = "balanced_control",
			GlobalOverrides = {AttackingWidth = 60},
			PhaseOverrides = {InPossession = {SupportDistance = 35}},
			RoleOverrides = {ST = {RunsInBehind = 88}},
			MatchStateOverrides = {ProtectLead = {RiskLevel = 12}},
			ExecutionOverrides = {PassTempo = 78},
			PositioningRules = {{Phase = "InPossession", Width = .18, RestDefense = 1, AllowedFunction = "central-forward"}, "bad"},
			PassRules = {{Phase = "InPossession", PreferredReceiverFunction = "central-forward", PassFamily = "Through", MinimumLaneQuality = .6}},
			PressRules = {{Phase = "OutOfPossession", PressDirection = "Outside", PressHeight = .2}},
			SequenceRules = {{Phase = "InPossession", PlanStep = "reset", NextStep = "triangle", RequiredOccupation = "ball-side-pivot"}},
			RoleInstructions = {{Phase = "InPossession", Role = "ST", RunType = "RunBehind", ForbiddenAction = "RiskDribble"}},
			MetricsTargets = {Possession = 58},
		})
		local context = {OwnerSide = "Home", MatchState = "ProtectLead", TeamPlans = {Home = {PlanStep = AITacticalContract.PlanStep({Id = "reset"})}}, BallTeam = {Home = Vector3.new(212, 3, 320)}, Teams = {Home = {List = {}}, Away = {List = {}}}}
		local value = style:GetForContext("RiskLevel", {Phase = "InPossession", Role = "ST", MatchState = "ProtectLead", Sequence = {CounterAttackFrequency = 64}, Emergency = {RiskLevel = 8}})
		expectEqual(value, 8, "Context-aware emergency override did not win")
		local effects = AIPlaystyleRuleService.Evaluate(style, context, "Home", {Role = "ST", Function = "central-forward"})
		expect((effects.Positioning.Width or 0) > 0 and effects.Positioning.AllowedFunctions["central-forward"] == true, "Positioning rule did not apply")
		expectEqual(effects.Pass.PreferredReceiverFunction, "central-forward", "Pass rule did not apply")
		expectEqual(effects.Sequence.NextStep, "triangle", "Sequence rule did not apply")
		expect(effects.Role.ForbiddenActions.RiskDribble == true and effects.IgnoredRules >= 1, "Role instruction or malformed-rule handling failed")
	end)

	test("tactical metrics track structural violations and plan progress", function()
		local metrics = AITeamMetrics.new()
		local function model(name: string): Model
			local item = Instance.new("Model")
			item.Name = name
			return item
		end
		local a = model("A")
		local b = model("B")
		local c = model("C")
		local assignments = {
			Home = {
				[a] = {TacticalSlot = AITacticalContract.Slot({Id = "rest-defense", Function = "Central rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(212, 3, 120), RestDefense = true}), TargetPitch = Vector3.new(212, 3, 120)},
				[b] = {TacticalSlot = AITacticalContract.Slot({Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CM", TargetPitch = Vector3.new(212, 3, 310)}), TargetPitch = Vector3.new(212, 3, 310)},
				[c] = {TacticalSlot = AITacticalContract.Slot({Id = "central-forward", Function = "Depth striker", RoleFamily = "ST", TargetPitch = Vector3.new(212, 3, 610)}), TargetPitch = Vector3.new(212, 3, 610), RunApproved = true, TargetWorld = Vector3.new(212, 3, 610), PlayerContract = AITacticalContract.Player({SlotId = "central-forward"})},
			},
			Away = {},
		}
		local context = {Now = 1, OwnerSide = "Home", Owner = b, BallWorld = Vector3.new(212, 3, 310), BallTeam = {Home = Vector3.new(212, 3, 310)}, TeamBrain = {Home = {RestDefense = 2}}, TeamPlans = {Home = {StepId = "triangle", LastEvent = "CompletedPass"}}, TeamReactions = {Home = {Active = {Blended = true}}}, TeamStageResetUntil = {Home = 2}, Players = {[a] = {Model = a, Pitch = Vector3.new(260, 3, 160), World = Vector3.new(260, 3, 160)}, [b] = {Model = b, Pitch = Vector3.new(212, 3, 310), World = Vector3.new(212, 3, 310), OpponentSide = "Away"}, [c] = {Model = c, Pitch = Vector3.new(212, 3, 540), World = Vector3.new(212, 3, 540)}}, Teams = {Home = {List = {}}, Away = {List = {}}}}
		metrics.LastPlans.Home = {StepId = "reset", LastEvent = "Hold"}
		metrics:Analyze(context, assignments)
		expect(metrics.Tactical.Home.AverageBackToMidfieldGap > 0, "Line gap metric did not update")
		expect(metrics.Tactical.Home.RestDefenseViolations > 0, "Rest-defence violation metric did not update")
		expect(metrics.Tactical.Home.UnsupportedAttackingRuns > 0, "Unsupported run metric did not update")
		expect(metrics.Tactical.Home.PlanStepsCompleted >= 1, "Plan completion metric did not update")
		a:Destroy();b:Destroy();c:Destroy()
	end)

	test("scenario structures differ by formation identity and match state", function()
		local function players(count: number): {any}
			local list = {}
			for index = 1, count do
				local role = index == 1 and "GK" or index <= 4 and "CB" or index <= 7 and "CM" or index <= 9 and "Winger" or "ST"
				local model = Instance.new("Model")
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Position = Vector3.new(60 + index * 28, 3, 100 + index * 34)
				root.Parent = model
				table.insert(list, {Model = model, Root = root, Side = "Home", Index = index, Role = role, Pitch = root.Position, World = root.Position, Stats = {pace = 70}, Stamina = 80, IsGoalkeeper = index == 1})
			end
			return list
		end
		local function context(formation: string, identity: string, defenseIdentity: string, count: number, matchState: string?): any
			local list = players(count)
			return {List = list, Context = {Now = 1, OwnerSide = "Home", MatchState = matchState or "Live", Formations = {Home = formation}, BallTeam = {Home = Vector3.new(212, 3, 330)}, BallWorld = Vector3.new(212, 3, 330), TeamBrain = {Home = {AttackingIdentity = identity, AttackCorridor = identity == "WideOverload" and "Wide" or identity == "CentralDomination" and "Central" or "Balanced", RestDefense = defenseIdentity == "CollectiveHunt" and 2 or 3}}, OpponentObservation = {Home = {OpponentDefenseConfidence = {[defenseIdentity] = .8}, OpponentAttackConfidence = {}, OpponentDefenseIdentity = defenseIdentity, OpponentAttackIdentity = "PositionalControl"}}, TeamReactions = {Home = AITacticalReactionService.ForSide({OwnerSide = "Home", OpponentObservation = {Home = {OpponentDefenseConfidence = {[defenseIdentity] = .8}, OpponentAttackConfidence = {}, OpponentDefenseIdentity = defenseIdentity, OpponentAttackIdentity = "PositionalControl"}}}, "Home")}, Teams = {Home = {List = list}, Away = {List = {}}}, Players = {}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}}
		end
		local pc = context("4-3-3", "PositionalControl", "CollectiveHunt", 11)
		local central = context("4-2-3-1", "CentralDomination", "CentralLock", 11)
		local counter = context("4-4-2", "CounterattackingTrap", "DepthProtection", 11)
		local wide = context("3-5-2", "WideOverload", "FlankIsolation", 11)
		local low = context("5-3-2", "LowBlockFortress", "BoxProtection", 11)
		local small = context("4-3-3", "PositionalControl", "StructuredContainment", 6)
		local lead = context("5-3-2", "PositionalControl", "BoxProtection", 11, "ProtectLead")
		local trail = context("3-5-2", "DirectAssault", "CollectiveHunt", 11, "AllOutAttack")
		local pcSlots = AIShapeTemplateService.Build(pc.Context, "Home", AITacticalStyleService.new({PresetId = "short_possession"}), nil, nil, nil)
		local centralSlots = AIShapeTemplateService.Build(central.Context, "Home", AITacticalStyleService.new({PresetId = "central_overload"}), nil, nil, nil)
		local wideSlots = AIShapeTemplateService.Build(wide.Context, "Home", AITacticalStyleService.new({PresetId = "wing_overload"}), nil, nil, nil)
		local smallSlots = AIShapeTemplateService.Build(small.Context, "Home", AITacticalStyleService.new({PresetId = "balanced_control"}), nil, nil, nil)
		local leadSlots = AIShapeTemplateService.Build(lead.Context, "Home", AITacticalStyleService.new({PresetId = "protect_lead"}), nil, nil, nil)
		local trailSlots = AIShapeTemplateService.Build(trail.Context, "Home", AITacticalStyleService.new({PresetId = "all_out_attack"}), nil, nil, nil)
		local function width(slots: {any}): number
			local minX = math.huge
			local maxX = -math.huge
			for _, slot in ipairs(slots) do minX = math.min(minX, slot.TargetPitch.X);maxX = math.max(maxX, slot.TargetPitch.X) end
			return maxX - minX
		end
		local function rest(slots: {any}): number
			local total = 0
			for _, slot in ipairs(slots) do if slot.RestDefense then total += 1 end end
			return total
		end
		expectEqual(#smallSlots, 6, "5V5 scenario did not preserve six functions")
		expect(width(wideSlots) > width(centralSlots), "WideOverload 3-5-2 was not wider than CentralDomination 4-2-3-1")
		expect(rest(leadSlots) >= rest(trailSlots), "Protect Lead did not preserve more rest defence than All-Out Attack")
		expect(width(pcSlots) ~= width(centralSlots), "CollectiveHunt and CentralLock scenarios did not create structural width difference")
		local director = AIPossessionDirector.new()
		local counterPlan = director:Update(counter.Context, "Home", {Intent = "CounterAttack"}, nil, nil)
		local lowPlan = director:Update(low.Context, "Home", {Intent = "BuildOut"}, nil, nil)
		expect(counterPlan.Route[1] ~= lowPlan.Route[1], "Counter trap and low-block scenarios selected the same route")
		for _, pack in {pc, central, counter, wide, low, small, lead, trail} do for _, info in ipairs(pack.List) do info.Model:Destroy() end end
	end)

	test("possession plan advances beyond step one from completed pass event", function()
		local director = AIPossessionDirector.new()
		local passer = Instance.new("Model")
		local receiver = Instance.new("Model")
		receiver:SetAttribute("AILastPassReceivedAt", 12)
		local context = {Now = 10, Owner = passer, OwnerSide = "Home", BallTeam = {Home = Vector3.new(212, 3, 250)}, TeamBrain = {Home = {AttackingIdentity = "PositionalControl", AttackCorridor = "Balanced"}}, TeamStructures = {Home = {{Id = "goalkeeper-outlet"}, {Id = "rest-defense"}, {Id = "ball-side-pivot"}, {Id = "left-support"}, {Id = "right-support"}}}, Teams = {Home = {List = {}}, Away = {List = {}}}, Players = {}}
		local first = director:Update(context, "Home", {Intent = "BuildOut"}, nil, nil)
		expectEqual(first.Step, 1, "Initial positional plan did not start at step one")
		context.Now = 12
		context.Owner = receiver
		local second = director:Update(context, "Home", {Intent = "BuildOut"}, nil, nil)
		expect(second.Step > 1 and second.StepId == "triangle", "Completed pass did not advance plan beyond step one")
		passer:Destroy()
		receiver:Destroy()
	end)

	test("wide overload advances and blocked overload switches far side", function()
		local director = AIPossessionDirector.new()
		local passer = Instance.new("Model")
		local receiver = Instance.new("Model")
		receiver:SetAttribute("AILastPassReceivedAt", 22)
		local carrierRoot = Instance.new("Part")
		carrierRoot.Position = Vector3.new(70, 3, 430)
		carrierRoot.Parent = receiver
		local function opponentAt(x: number, z: number): any
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = Vector3.new(x, 3, z)
			root.Parent = model
			return {Model = model, Root = root, Side = "Away", World = root.Position, Pitch = root.Position, Stats = {pace = 70}, Stamina = 80}
		end
		local context = {Now = 20, Owner = passer, OwnerSide = "Home", BallTeam = {Home = Vector3.new(72, 3, 420)}, BallWorld = Vector3.new(72, 3, 420), TeamBrain = {Home = {AttackingIdentity = "WideOverload", AttackCorridor = "Wide"}}, TeamStructures = {Home = {{Id = "ball-side-width"}, {Id = "ball-side-pivot"}, {Id = "left-support"}, {Id = "far-side-width"}, {Id = "rest-defense"}}}, Teams = {Home = {List = {}}, Away = {List = {opponentAt(68, 418), opponentAt(88, 430), opponentAt(60, 452)}}}, Players = {[receiver] = {Model = receiver, Root = carrierRoot, Side = "Home", OpponentSide = "Away", World = carrierRoot.Position, Pitch = Vector3.new(72, 3, 420)}}}
		local first = director:Update(context, "Home", {Intent = "CreateChance"}, nil, nil)
		context.Now = 22
		context.Owner = receiver
		local second = director:Update(context, "Home", {Intent = "CreateChance"}, nil, nil)
		expectEqual(second.StepId, "overlap-underlap", "Completed wide pass did not advance wide overload")
		context.Now = 22.2
		local blocked = director:Update(context, "Home", {Intent = "CreateChance"}, nil, nil)
		expectEqual(blocked.StepId, "far-side-switch", "Blocked wide overload did not transition to far-side switch")
		passer:Destroy();receiver:Destroy()
		for _, info in ipairs(context.Teams.Away.List) do info.Model:Destroy() end
	end)

	test("vertical combination route exposes bounce third-man and depth-run sequence", function()
		local director = AIPossessionDirector.new()
		local owners = {Instance.new("Model"), Instance.new("Model"), Instance.new("Model"), Instance.new("Model")}
		for index, model in ipairs(owners) do model:SetAttribute("AILastPassReceivedAt", 30 + index) end
		local context = {Now = 30, Owner = owners[1], OwnerSide = "Home", BallTeam = {Home = Vector3.new(212, 3, 370)}, TeamBrain = {Home = {AttackingIdentity = "VerticalCombination", AttackCorridor = "Balanced"}}, TeamStructures = {Home = {{Id = "checking-striker"}, {Id = "ball-side-pivot"}, {Id = "between-lines-receiver"}, {Id = "second-ball-midfielder"}, {Id = "central-forward"}}}, Teams = {Home = {List = {}}, Away = {List = {}}}, Players = {}}
		local first = director:Update(context, "Home", {Intent = "BuildOut"}, nil, nil)
		expectEqual(first.StepId, "bounce-pass", "Vertical combination did not start with bounce pass")
		context.Now = 31;context.Owner = owners[2]
		local second = director:Update(context, "Home", {Intent = "BuildOut"}, nil, nil)
		context.Now = 32;context.Owner = owners[3]
		local third = director:Update(context, "Home", {Intent = "BuildOut"}, nil, nil)
		context.Now = 33;context.Owner = owners[4]
		local fourth = director:Update(context, "Home", {Intent = "BuildOut"}, nil, nil)
		expectEqual(second.StepId, "line-breaking-receiver", "Vertical route missed line-breaking receiver")
		expectEqual(third.StepId, "third-man-support", "Vertical route missed third-man support")
		expectEqual(fourth.StepId, "runner-behind", "Vertical route missed depth runner")
		for _, model in ipairs(owners) do model:Destroy() end
	end)

	test("run contracts are explicit and lanes do not duplicate", function()
		local function modelInfo(name: string, slot: any, pitch: Vector3): (Model, any)
			local model = Instance.new("Model")
			model.Name = name
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			local assignment = {TacticalSlot = slot, TargetPitch = pitch, TargetWorld = pitch, MovementUrgency = .7, PlayerContract = AITacticalContract.Player({SlotId = slot.Id, AllowedActions = slot.AllowedActions})}
			return model, assignment
		end
		local restSlot = AITacticalContract.Slot({Id = "rest-defense", Function = "Central rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(212, 3, 130), RestDefense = true})
		local leftSlot = AITacticalContract.Slot({Id = "left-width", Function = "Ball-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(72, 3, 480), SprintAllowed = true})
		local rightSlot = AITacticalContract.Slot({Id = "right-width", Function = "Far-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(352, 3, 480), SprintAllowed = true})
		local carrier = Instance.new("Model")
		local carrierRoot = Instance.new("Part")
		carrierRoot.Name = "HumanoidRootPart"
		carrierRoot.Position = Vector3.new(212, 3, 390)
		carrierRoot.Parent = carrier
		local restModel, restAssignment = modelInfo("Rest", restSlot, Vector3.new(212, 3, 130))
		local leftModel, leftAssignment = modelInfo("Left", leftSlot, Vector3.new(72, 3, 480))
		local rightModel, rightAssignment = modelInfo("Right", rightSlot, Vector3.new(352, 3, 480))
		local assignments = {[restModel] = restAssignment, [leftModel] = leftAssignment, [rightModel] = rightAssignment}
		local context = {Now = 40, Owner = carrier, OwnerSide = "Home", BallTeam = {Home = Vector3.new(212, 3, 390)}, TeamBrain = {Home = {AttackingRunners = 3, RestDefense = 1}}, Teams = {Home = {List = {}}, Away = {List = {}}}, Players = {[carrier] = {Model = carrier, Root = carrierRoot, Side = "Home", OpponentSide = "Away", World = carrierRoot.Position, Pitch = carrierRoot.Position}}}
		local step = AITacticalContract.PlanStep({Id = "depth-runner", RunRequests = {"left-width", "right-width"}, PassBias = "ForwardEarly"})
		AIRunCoordinator.Apply(context, "Home", assignments, {Intent = "DirectRelease", PlanStep = step}, {Ratio = function() return .9 end})
		local approved = 0
		local lanes = {}
		for _, assignment in pairs(assignments) do
			if assignment.RunApproved then
				approved += 1
				expect(assignment.RunContract and assignment.RunContract.Trigger ~= nil and assignment.RunContract.Expiry > context.Now and assignment.RunContract.TargetRegion ~= nil and assignment.RunContract.ReplacementSlot ~= nil, "Run contract missing explicit fields")
				local lane = assignment.RunContract.TargetRegion.Lane
				expect(lanes[lane] ~= true, "Two approved runs occupied the same lane")
				lanes[lane] = true
			end
		end
		expect(approved >= 1, "No explicit run was approved")
		carrier:Destroy();restModel:Destroy();leftModel:Destroy();rightModel:Destroy()
	end)

	test("overlap rejected when rest defence is insufficient and far-side width waits before cross", function()
		local restSlot = AITacticalContract.Slot({Id = "rest-defense", Function = "Central rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(212, 3, 110), RestDefense = true})
		local widthSlot = AITacticalContract.Slot({Id = "right-width", Function = "Far-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(360, 3, 430), SprintAllowed = true})
		local rest = Instance.new("Model")
		local width = Instance.new("Model")
		local assignments = {
			[rest] = {TacticalSlot = restSlot, TargetPitch = restSlot.TargetPitch, PlayerContract = AITacticalContract.Player({SlotId = restSlot.Id})},
			[width] = {TacticalSlot = widthSlot, TargetPitch = widthSlot.TargetPitch, TargetWorld = widthSlot.TargetPitch, MovementUrgency = .7, PlayerContract = AITacticalContract.Player({SlotId = widthSlot.Id})},
		}
		local context = {Now = 50, OwnerSide = "Home", BallTeam = {Home = Vector3.new(80, 3, 360)}, TeamBrain = {Home = {AttackingRunners = 3, RestDefense = 2}}, Teams = {Home = {List = {}}, Away = {List = {}}}, Players = {}}
		AIRunCoordinator.Apply(context, "Home", assignments, {Intent = "WideOverload", PlanStep = AITacticalContract.PlanStep({Id = "overlap-underlap", RunRequests = {"overlap"}, PassBias = "WideCombination"})}, {Ratio = function() return .9 end})
		expect(width:GetAttribute("VTRRunApproved") ~= true, "Overlap was approved despite insufficient rest defence")
		context.TeamBrain.Home.RestDefense = 1
		AIRunCoordinator.Apply(context, "Home", assignments, {Intent = "WideOverload", PlanStep = AITacticalContract.PlanStep({Id = "wide-triangle", RunRequests = {"far-post"}, PassBias = "WideTriangle"})}, {Ratio = function() return .9 end})
		expect(width:GetAttribute("VTRRunApproved") ~= true, "Far-side width became box run before cross/final-third trigger")
		rest:Destroy();width:Destroy()
	end)

	test("pivot is protected when it is the only central screen", function()
		local pivot = Instance.new("Model")
		local pivotSlot = AITacticalContract.Slot({Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(212, 3, 330)})
		local assignments = {
			[pivot] = {TacticalSlot = pivotSlot, TargetPitch = pivotSlot.TargetPitch, TargetWorld = pivotSlot.TargetPitch, MovementUrgency = .7, PlayerContract = AITacticalContract.Player({SlotId = pivotSlot.Id})},
		}
		local context = {Now = 55, OwnerSide = "Home", BallTeam = {Home = Vector3.new(212, 3, 360)}, TeamBrain = {Home = {AttackingRunners = 2, RestDefense = 0}}, Teams = {Home = {List = {}}, Away = {List = {}}}, Players = {}}
		AIRunCoordinator.Apply(context, "Home", assignments, {Intent = "Counter", PlanStep = AITacticalContract.PlanStep({Id = "second-wave", RunRequests = {"second-wave"}, PassBias = "SecondWave"})}, {Ratio = function() return .9 end})
		expect(pivot:GetAttribute("VTRRunApproved") ~= true, "Only central pivot was approved for a run")
		expect(assignments[pivot].PlayerContract.ReplacementRequirement == "OnlyCentralScreenProtected" or assignments[pivot].PlayerContract.ReplacementRequirement == "RejectedRestDefenseBreak", "Pivot protection reason missing")
		pivot:Destroy()
	end)

	test("AI player brain rejects forbidden contract action", function()
		local brain = AIPlayerBrain.new({} :: any, {Ratio = function() return .5 end, Get = function() return .5 end, Directness = function() return .5 end, Risk = function() return .5 end}, {})
		local contract = AITacticalContract.Player({AllowedActions = {"Pass", "Clear"}, ForbiddenActions = {"Shoot", "Dribble"}})
		expect(not brain:ContractAllows({PlayerContract = contract}, "Shoot"), "Forbidden shot was allowed")
		expect(brain:ContractAllows({PlayerContract = contract}, "Pass"), "Allowed pass was blocked")
	end)

	test("only one alternate pass chaser is approved", function()
		local function makeInfo(name: string, role: string, position: Vector3): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRSprintEnergy", 100)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = position
			root.Parent = model
			return {Model = model, Root = root, Side = "Home", OpponentSide = "Away", Role = role, Pitch = position, World = position, Stats = {pace = 72, reception = 70, passQuality = 70}, Stamina = 90}
		end
		local passer = makeInfo("Passer", "CM", Vector3.new(0, 3, 0))
		local receiver = makeInfo("Receiver", "ST", Vector3.new(42, 3, 0))
		local alternateA = makeInfo("AlternateA", "CM", Vector3.new(22, 3, 4))
		local alternateB = makeInfo("AlternateB", "Winger", Vector3.new(28, 3, -5))
		local protected = makeInfo("Protected", "CB", Vector3.new(18, 3, 2))
		protected.Model:SetAttribute("AIRestDefense", true)
		local kickedPayload = nil
		local ballService = {Kick = function(_, model: Model, action: string, direction: Vector3, power: number, targetModel: Model)
			kickedPayload = {Model = model, Action = action, Direction = direction, Power = power, Target = targetModel}
			return true
		end}
		local style = {Ratio = function() return .5 end, Get = function() return .5 end, Directness = function() return .5 end, Risk = function() return .5 end}
		local brain = AIPlayerBrain.new(ballService, style, {PassRisk = .2})
		local context = {Now = 60, BallWorld = passer.World, BallVelocity = Vector3.zero, PitchCFrame = CFrame.new(), AttackSigns = {Home = 1}, Teams = {Home = {List = {passer, receiver, alternateA, alternateB, protected}}, Away = {List = {}}}, Players = {[passer.Model] = passer, [receiver.Model] = receiver, [alternateA.Model] = alternateA, [alternateB.Model] = alternateB, [protected.Model] = protected}}
		local kicked = brain:_kickPass(context, passer, {Receiver = receiver, Target = receiver.World, PassKind = "Ground", Distance = 42, LaneClear = true, Safe = true, Score = 100})
		expect(kicked and kickedPayload ~= nil, "Test pass did not execute")
		expectEqual(receiver.Model:GetAttribute("AIPassAlternateChasers"), 1, "More than one alternate pass chaser was approved")
		expect(protected.Model:GetAttribute("VTRAIAlternatePassChaser") ~= true, "Protected rest defender became alternate chaser")
		for _, info in {passer, receiver, alternateA, alternateB, protected} do info.Model:Destroy() end
	end)

	test("incoming pass defense creates coordinated single duties", function()
		local function makeInfo(side: string, role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = side, Role = role, Pitch = pitch, World = pitch, Stats = {pace = 70}, Stamina = 85}
		end
		local receiver = makeInfo("Home", "CM", Vector3.new(210, 3, 360))
		receiver.Model:SetAttribute("VTRReceiveIntercept", Vector3.new(212, 3, 362))
		receiver.Model:SetAttribute("VTRReceiveUntil", 12)
		local defenders = {makeInfo("Away", "CDM", Vector3.new(210, 3, 330)), makeInfo("Away", "CB", Vector3.new(185, 3, 250)), makeInfo("Away", "CM", Vector3.new(245, 3, 335)), makeInfo("Away", "Fullback", Vector3.new(330, 3, 275))}
		local players: any = {[receiver.Model] = receiver}
		local assignments = {}
		for _, info in defenders do
			players[info.Model] = info
			assignments[info.Model] = {PrimaryAssignment = "HoldBackLineZone", TargetWorld = info.World, MovementTarget = info.World, MovementUrgency = .7, SprintAllowed = false}
		end
		local context = {Now = 10, PassInFlight = true, BallWorld = Vector3.new(180, 3, 330), Teams = {Home = {List = {receiver}}, Away = {List = defenders}}, Players = players, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH}}
		AIDefensivePlan.ApplyIncomingPass(context, "Away", assignments, {})
		local counts = {AttackPassTrajectory = 0, TrackIncomingReceiver = 0, BlockReturnPass = 0, PreserveDeepestCover = 0}
		local dutyModels = {}
		for model, assignment in pairs(assignments) do
			if counts[assignment.PrimaryAssignment] ~= nil then counts[assignment.PrimaryAssignment] += 1 end
			if counts[assignment.PrimaryAssignment] ~= nil then dutyModels[assignment.PrimaryAssignment] = model end
		end
		expect(counts.AttackPassTrajectory == 1, "Incoming pass did not create one trajectory attacker")
		expect(counts.TrackIncomingReceiver == 1, "Incoming pass did not create one receiver tracker")
		expect(counts.BlockReturnPass == 1, "Incoming pass did not create one return blocker")
		expect(counts.PreserveDeepestCover == 1, "Incoming pass did not preserve deepest cover")
		expect(dutyModels.AttackPassTrajectory ~= dutyModels.TrackIncomingReceiver and dutyModels.AttackPassTrajectory ~= dutyModels.BlockReturnPass and dutyModels.AttackPassTrajectory ~= dutyModels.PreserveDeepestCover, "Trajectory defender reused another incoming-pass duty")
		expect(dutyModels.TrackIncomingReceiver ~= dutyModels.BlockReturnPass and dutyModels.TrackIncomingReceiver ~= dutyModels.PreserveDeepestCover and dutyModels.BlockReturnPass ~= dutyModels.PreserveDeepestCover, "Incoming-pass duties reused a defender")
		receiver.Model:Destroy()
		for _, info in defenders do info.Model:Destroy() end
	end)

	test("pass arrival planner selects locomotion from timing deficit", function()
		local receiver = Instance.new("Model")
		receiver:SetAttribute("PAC", 70)
		receiver:SetAttribute("BallControl", 72)
		receiver:SetAttribute("VTRSprintEnergy", 100)
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Position = Vector3.new(0, 3, 0)
		root.Parent = receiver
		local jog = PassArrivalPlanner.Solve({ReceiverModel = receiver, Target = Vector3.new(8, 3, 0), BallETA = 1.4, PassFamily = "Ground"})
		local run = PassArrivalPlanner.Solve({ReceiverModel = receiver, Target = Vector3.new(18, 3, 0), BallETA = 1.0, PassFamily = "Ground"})
		local sprint = PassArrivalPlanner.Solve({ReceiverModel = receiver, Target = Vector3.new(30, 3, 0), BallETA = 1.0, PassFamily = "Through"})
		local impossible = PassArrivalPlanner.Solve({ReceiverModel = receiver, Target = Vector3.new(85, 3, 0), BallETA = .6, PassFamily = "Ground"})
		expect(jog and jog.SelectedLocomotionMode == "Jog", "Jog-reachable pass did not select Jog")
		expect(run and run.SelectedLocomotionMode == "Run", "Run-reachable pass did not select Run")
		expect(sprint and sprint.SelectedLocomotionMode == "SprintBurst", "Sprint-required pass did not select SprintBurst")
		expect(impossible and impossible.Reachable == false, "Impossible pass was marked reachable")
		expect(jog.BrakingDistance >= 0 and jog.FirstTouchIntent ~= nil, "Ground route missing braking or touch state")
		receiver:Destroy()
	end)

	test("AI sprint bursts recover after cooldown", function()
		local executor = AIMovementExecutor.new()
		local model = Instance.new("Model")
		model:SetAttribute("VTRSprintEnergy", 100)
		model:SetAttribute("VTRSprintLocked", false)
		local command = {LocomotionMode = "SprintBurst", SprintAllowed = true, SprintRequired = true, RunTicketId = "run-1", MinimumEnergy = 20, BurstMaximumSeconds = .5, RecoveryMinimumSeconds = 1}
		expect(executor:_sprint(model, command, 10, true), "AI burst did not start")
		expect(not executor:_sprint(model, command, 10.6, true), "AI burst ignored its maximum")
		expect(not executor:_sprint(model, command, 11.2, true), "AI burst ignored cooldown")
		expect(executor:_sprint(model, command, 11.7, true), "AI burst never recovered from cooldown")
		executor:Destroy()
		model:Destroy()
	end)

	test("action charge timing", function()
		expect(ActionTuning.Profile("Ground").FullChargeSeconds >= .6 and ActionTuning.Profile("Ground").FullChargeSeconds <= .7, "Ground charge timing")
		expect(ActionTuning.Profile("Through").FullChargeSeconds >= .7 and ActionTuning.Profile("Through").FullChargeSeconds <= .8, "Through charge timing")
		expect(ActionTuning.Profile("Lob").FullChargeSeconds >= .75 and ActionTuning.Profile("Lob").FullChargeSeconds <= .9, "Lob charge timing")
		expect(ActionTuning.Profile("Shot").FullChargeSeconds >= .85 and ActionTuning.Profile("Shot").FullChargeSeconds <= 1, "Shot charge timing")
	end)

	test("action curves and queue", function()
		local tap = ActionTuning.EvaluateNormalized("Ground", 0)
		local middle = ActionTuning.EvaluateNormalized("Ground", .5)
		local full = ActionTuning.EvaluateNormalized("Ground", 1)
		expect(tap >= .2 and tap < middle and middle < full and full == 1, "Charge curve is not useful and monotonic")
		expect(ActionTuning.QueueNormalSeconds >= .25 and ActionTuning.QueueNormalSeconds <= .4, "Normal queue duration")
		expect(ActionTuning.QueueImminentSeconds <= .6, "Imminent queue duration")
	end)

	test("possession action cancellation clears stale charges", function()
		local Input = require(StarterPlayer.StarterPlayerScripts.VTRClient.Gameplay.InputController)
		local sent = {}
		local remote = {FireServer = function(_, payload: any) table.insert(sent, payload) end}
		local controller = Input.new(remote :: any, function() return {Direction = Vector3.zAxis} end)
		local playerA = Instance.new("Model")
		local playerB = Instance.new("Model")
		controller:SetActiveModel(playerA)
		controller.Charge = {Kind = "Shot", ContextToken = controller.ActionContextToken, Model = playerA}
		controller.PendingAction = {Payload = {ActionFamily = "Shot"}}
		local cancelledReason = ""
		controller:SetCancellationCallback(function(reason: string) cancelledReason = reason end)
		controller:SetActiveModel(playerB)
		expect(controller.Charge == nil and controller.PendingAction == nil, "Active-player switch kept a stale action")
		expectEqual(cancelledReason, "active_player_changed", "Cancellation used the wrong reason")
		expect(#sent == 1 and sent[1].Type == "ActionQueueCancelled", "Stale cancellation was not reported once")
		for _, reason in {"pause", "set_piece", "goal", "cleanup"} do
			controller.Charge = {Kind = "Pass"};controller.PendingAction = {Payload = {ActionFamily = "Ground"}}
			controller:CancelPossessionActions(reason, false)
			expect(controller.Charge == nil and controller.PendingAction == nil, reason .. " cancellation retained action state")
		end
		controller:Destroy();playerA:Destroy();playerB:Destroy()
	end)

	test("mobile permits one charge while preserving sprint and block lifecycle", function()
		local Input = require(StarterPlayer.StarterPlayerScripts.VTRClient.Gameplay.InputController)
		local sent = {}
		local remote = {FireServer = function(_, payload: any) table.insert(sent, payload) end}
		local controller = Input.new(remote :: any, function() return {Direction = Vector3.zAxis} end)
		controller.SprintAllowed = true
		expect(controller:BeginMobileAction("Pass", {PassMode = "Ground"}, 11), "First mobile charge was rejected")
		expect(not controller:BeginMobileAction("Shot", {}, 12), "Second mobile charge overwrote the first")
		controller:SetSprintRequested(true)
		expect(controller.SprintRequested and controller.Charge and controller.Charge.Kind == "Pass", "Sprint cancelled the active mobile charge")
		controller:CancelMobileAction("Pass", 12, "wrong_touch")
		expect(controller.Charge ~= nil, "Wrong touch token cancelled the charge")
		controller:CancelMobileAction("Pass", 11, "touch_cancelled")
		expect(controller.Charge == nil, "Owning touch failed to cancel the charge")
		controller:TriggerMobileAction("Block")
		controller:TriggerMobileAction("BlockEnd")
		local beginBlock = sent[#sent - 1]
		local endBlock = sent[#sent]
		expect(beginBlock.Type == "Block" and beginBlock.Active == true and endBlock.Type == "Block" and endBlock.Active == false, "Mobile Block did not send begin and end")
		controller:Destroy()
	end)

	test("explicit pass families", function()
		expectEqual(ActionTuning.NormalizeAction("Pass"), "Ground", "Ground alias")
		expectEqual(ActionTuning.NormalizeAction("ThroughPass"), "Through", "Through alias")
		expectEqual(ActionTuning.NormalizeAction("Cross"), "Lob", "Lob alias")
		expectEqual(ActionTuning.NormalizeAction("W"), "Ground", "Movement input changed pass family")
	end)

	test("receiver assist modes", function()
		local newcomer = ReceiverAssist.Get("Newcomer")
		local standard = ReceiverAssist.Get("Standard")
		local manual = ReceiverAssist.Get("Manual")
		expect(newcomer.SwitchProgress >= .55 and newcomer.SwitchProgress <= .7, "Newcomer switch threshold")
		expect(standard.SwitchProgress >= .7 and standard.SwitchProgress <= .85, "Standard switch threshold")
		expect(manual.GuidanceSeconds == 0 and manual.SwitchProgress > 1, "Manual mode still assists")
		expect(newcomer.TrapRadius > standard.TrapRadius and standard.TrapRadius > manual.TrapRadius, "Trap envelopes are not ordered")
	end)

	test("receiver switching uses live ETA and trajectory", function()
		local base = {
			Mode = "Standard", MotionKind = "Pass", BallPosition = Vector3.zero, BallVelocity = Vector3.new(0, 0, 24), ReceivePoint = Vector3.new(0, 0, 48), InterceptionPoint = Vector3.new(0, 0, 48), InitialDirection = Vector3.new(0, 0, 24), ReceiverPosition = Vector3.new(0, 0, 38), ReceiverVelocity = Vector3.zero, ReceiverSpeed = 20,
		}
		local longPass = ReceiverSwitch.Evaluate(base)
		expect(longPass.Reachable and not longPass.Transfer, "Long pass switched before its ETA window")
		local near = table.clone(base);near.BallPosition = Vector3.new(0, 0, 40)
		expect(ReceiverSwitch.Evaluate(near).Transfer, "Reachable near pass did not transfer")
		local deflected = table.clone(base);deflected.BallVelocity = Vector3.new(20, 0, 0)
		local deflectedResult = ReceiverSwitch.Evaluate(deflected)
		expect(deflectedResult.Diverged and not deflectedResult.Transfer, "Deflected pass retained receiver transfer")
		local manual = table.clone(near);manual.Mode = "Manual";manual.ActualCollector = false
		expect(not ReceiverSwitch.Evaluate(manual).Transfer, "Manual mode switched before possession")
		manual.ActualCollector = true
		expect(ReceiverSwitch.Evaluate(manual).Transfer, "Manual mode did not recognize actual possession")
	end)

	test("receiver collector selection is deterministic", function()
		local a = {Key = "A", Position = Vector3.new(-4, 0, 20), Velocity = Vector3.zero, Speed = 20, Valid = true}
		local b = {Key = "B", Position = Vector3.new(4, 0, 20), Velocity = Vector3.zero, Speed = 20, Valid = true}
		expectEqual(ReceiverSwitch.SelectCollector({b, a}, Vector3.new(0, 0, 20)).Key, "A", "Collector depended on model order")
	end)

	test("committed reception mode contract", function()
		local newcomer = PassReception.Get("Newcomer")
		local standard = PassReception.Get("Standard")
		local manual = PassReception.Get("Manual")
		expect(newcomer.PreSwitchRouteWeight == 1 and newcomer.PostSwitchRouteWeight == 1 and newcomer.UserRouteInfluence == 0, "Newcomer route is not committed")
		expect(standard.PreSwitchRouteWeight == 1 and standard.PostSwitchRouteWeight >= .75 and standard.UserRouteInfluence >= .15, "Standard route blend escaped range")
		expect(manual.PreSwitchRouteWeight == 1 and manual.PostSwitchRouteWeight == 0 and manual.UserRouteInfluence == 1, "Manual route ownership is invalid")
		expect(newcomer.ControlTransferETA > standard.ControlTransferETA and manual.ControlTransferETA < 0, "ETA transfer modes are not ordered")
		expect(newcomer.AutoSprint == "Required" and standard.AutoSprint == "ClearlyRequired" and manual.AutoSprint == "PreSwitchOnly", "Auto-sprint policies changed")
		expectEqual(PassReception.NormalizeFamily("Lofted"), "Lob", "Lofted family normalization")
		expectEqual(PassReception.NormalizeFamily("ManualLobbed"), "Lob", "Manual lob family normalization")
		for _, phase in {"Anticipating", "Committed", "ControlPrepared", "ContactWindow", "FirstTouch", "Completed", "Cancelled"} do
			expect(PassReception.PhaseSet[phase] == true, "Missing reception phase " .. phase)
		end
	end)

	test("reception contract lifecycle is idempotent", function()
		local function footballer(name: string, team: string, position: Vector3): Model
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRTeam", team)
			local modelRoot = Instance.new("Part")
			modelRoot.Name = "HumanoidRootPart"
			modelRoot.Anchored = true
			modelRoot.Position = position
			modelRoot.Parent = model
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = model
			model.Parent = workspace
			return model
		end
		local passer = footballer("ReceptionPasser", "Home", Vector3.new(0, 3, 0))
		local receiver = footballer("ReceptionReceiver", "Home", Vector3.new(0, 3, 18))
		local ball = Instance.new("Part")
		ball.Anchored = true
		ball.Position = Vector3.new(0, 1, 1)
		ball.Parent = workspace
		local remote = {FireClient = function() end, FireAllClients = function() end} :: any
		local possession = {GetOwner = function() return nil end} :: any
		local ballService = {ActiveTrajectory = nil} :: any
		local reception = PassReceptionRuntime.new(remote, {Home = {passer, receiver}, Away = {}}, ball, possession, ballService, CFrame.identity, 140, 220)
		local first = reception:OnPassLaunched({PassId = 1, TrajectoryId = 0, Passer = passer, Receiver = receiver, PassFamily = "Ground", InitialReceivePoint = Vector3.new(0, 1, 20), InitialVelocity = Vector3.new(0, 0, 30), Duration = 1.2})
		expect(first and first.Phase == "Committed" and first.ControlTransferred == false, "Reception did not commit before control transfer")
		expect(receiver:GetAttribute("VTRPreparingReceive") == true and receiver:GetAttribute("VTRReceptionContractId") == first.Id, "Receiver route did not start at pass launch")
		local second = reception:OnPassLaunched({PassId = 2, TrajectoryId = 0, Passer = passer, Receiver = receiver, PassFamily = "Through", InitialReceivePoint = Vector3.new(2, 1, 25), InitialVelocity = Vector3.new(2, 0, 34), Duration = 1.5})
		expect(second and second.Id ~= first.Id and first.Terminal == true and first.CancelReason == "NewPassReplacedContract", "New pass did not replace the old contract")
		expect(reception:Cancel("Goal") and not reception:Cancel("Goal"), "Reception cancellation was not idempotent")
		expect(receiver:GetAttribute("VTRReceptionContractId") == nil and receiver:GetAttribute("VTRReceiveTarget") == nil, "Terminal reception leaked route state")
		local expiring = reception:OnPassLaunched({PassId = 3, TrajectoryId = 0, Passer = passer, Receiver = receiver, PassFamily = "Manual", InitialReceivePoint = Vector3.new(0, 1, 22), InitialVelocity = Vector3.new(0, 0, 20), Duration = 1})
		expect(expiring and expiring.AssistanceMode == "Manual" and receiver:GetAttribute("VTRPreparingReceive") == true, "Manual pass lost its off-ball route")
		expiring.ExpiresAt = 0
		reception:Step(1)
		expect(expiring.Terminal == true and expiring.CancelReason == "ContractExpired", "Expired reception remained active")
		expect(reception:OnPassLaunched({Passer = passer, Receiver = nil}) == nil and reception.Active == nil, "Invalid launch created a reception contract")
		reception:Destroy()
		passer:Destroy()
		receiver:Destroy()
		ball:Destroy()
	end)

	test("live reception intercept follows reachability", function()
		local receiver = {Position = Vector3.zero, Velocity = Vector3.zero, Facing = Vector3.zAxis, MaximumSpeed = 22, Acceleration = 20, MaximumTurnPenalty = .34, ContactTolerance = 2.6}
		local direct = ReceptionIntercept.Resolve({
			PassFamily = "Ground",
			Receiver = receiver,
			Samples = {
				{Time = .35, Position = Vector3.new(0, 1, 8), Velocity = Vector3.new(0, 0, 24), InsideBounds = true, Confidence = 1},
				{Time = 1.35, Position = Vector3.new(0, 1, 16), Velocity = Vector3.new(0, 0, 16), InsideBounds = true, Confidence = .9},
			},
			GroundY = 0,
			AllowedControlHeight = 5.8,
			ReachSafetySeconds = .1,
		})
		expect(direct.Point == Vector3.new(0, 1, 16) and direct.Reachable, "Stationary receiver did not select the reachable Ground intercept")
		local movingReceiver = table.clone(receiver)
		movingReceiver.Velocity = Vector3.new(0, 0, 11)
		local moving = ReceptionIntercept.Resolve({PassFamily = "Through", Receiver = movingReceiver, Samples = {{Time = 1.35, Position = Vector3.new(0, 1, 24), Velocity = Vector3.new(0, 0, 20), InsideBounds = true, Confidence = .95}}, GroundY = 0, AllowedControlHeight = 5.8, ReachSafetySeconds = .1})
		expect(moving.Reachable and moving.ReceiverETA < moving.BallETA, "Moving receiver did not accelerate into a Through pass")
		local slow = ReceptionIntercept.Resolve({PassFamily = "Ground", Receiver = receiver, Samples = {{Time = .4, Position = Vector3.new(0, 1, 12), Velocity = Vector3.new(0, 0, 18), InsideBounds = true}, {Time = 1.4, Position = Vector3.new(0, 1, 17), Velocity = Vector3.new(0, 0, 3), InsideBounds = true}}, GroundY = 0, AllowedControlHeight = 5.8, ReachSafetySeconds = .1})
		expect(slow.Point == Vector3.new(0, 1, 17), "Slowing pass retained an unreachable early endpoint")
	end)

	test("reception intercept rejects illegal candidates", function()
		local receiver = {Position = Vector3.zero, Velocity = Vector3.zero, Facing = Vector3.zAxis, MaximumSpeed = 20, Acceleration = 18, MaximumTurnPenalty = .34, ContactTolerance = 2.6}
		local legal = ReceptionIntercept.Resolve({Receiver = receiver, Samples = {{Time = 1.2, Position = Vector3.new(0, 4.5, 12), Velocity = Vector3.zero, InsideBounds = true}}, GroundY = 0, AllowedControlHeight = 5.8})
		expect(legal.Point ~= nil and legal.ControllableHeight == 4.5, "Controllable body-height ball was rejected")
		local rejected = ReceptionIntercept.Resolve({Receiver = receiver, Samples = {{Time = 1.2, Position = Vector3.new(0, 8, 12), Velocity = Vector3.zero, InsideBounds = true}, {Time = 1.4, Position = Vector3.new(0, 1, 15), Velocity = Vector3.zero, InsideBounds = false}}, GroundY = 0, AllowedControlHeight = 5.8})
		expect(rejected.Point == nil, "Aerial or out-of-bounds candidate was accepted")
		local defender = {Model = "Defender", Position = Vector3.new(0, 0, 12), Velocity = Vector3.zero, Facing = -Vector3.zAxis, MaximumSpeed = 20, Acceleration = 18, ContactTolerance = 2.4}
		local contested = ReceptionIntercept.Resolve({Receiver = receiver, Opponents = {defender}, Samples = {{Time = 1.4, Position = Vector3.new(0, 1, 12), Velocity = Vector3.new(0, 0, 12), InsideBounds = true}}, GroundY = 0, AllowedControlHeight = 5.8, OpponentWinMargin = .08})
		expect(contested.OpponentWinning and contested.LikelyOpponent == "Defender", "Defender-first intercept was hidden by assistance")
	end)

	test("reception reach model preserves movement constraints", function()
		local forward = ReceptionIntercept.EstimateReachTime({Position = Vector3.zero, Target = Vector3.new(0, 0, 18), Velocity = Vector3.zero, Facing = Vector3.zAxis, MaximumSpeed = 22, Acceleration = 18, MaximumTurnPenalty = .34, ContactTolerance = 2.5})
		local turning = ReceptionIntercept.EstimateReachTime({Position = Vector3.zero, Target = Vector3.new(0, 0, 18), Velocity = Vector3.zero, Facing = -Vector3.zAxis, MaximumSpeed = 22, Acceleration = 18, MaximumTurnPenalty = .34, ContactTolerance = 2.5})
		local lowEnergy = ReceptionIntercept.EstimateReachTime({Position = Vector3.zero, Target = Vector3.new(0, 0, 18), Velocity = Vector3.zero, Facing = Vector3.zAxis, MaximumSpeed = 12, Acceleration = 12, MaximumTurnPenalty = .34, ContactTolerance = 2.5})
		expect(turning > forward and lowEnergy > forward, "Turn or low-energy movement penalty was ignored")
		local smoothed = ReceptionIntercept.Smooth(Vector3.zero, Vector3.new(30, 0, 0), .1, .02, 20)
		expect(smoothed.Magnitude <= 2.001, "Live target smoothing exceeded legal target speed")
		expect(ReceptionIntercept.DirectionDivergence(Vector3.zAxis, Vector3.xAxis) > .9, "Major trajectory deflection was not detected")
	end)

	test("defensive switch modes preserve manual control", function()
		expectEqual(DefensiveSwitch.Normalize("Off"), "Manual", "Defensive Off alias")
		expectEqual(DefensiveSwitch.Normalize("Assisted"), "Newcomer", "Defensive Assisted alias")
		expect(DefensiveSwitch.Get("Manual").MinimumAdvantage == math.huge, "Manual defensive mode can force-switch")
		expect(DefensiveSwitch.Get("Standard").PreviewSeconds > DefensiveSwitch.Get("Newcomer").PreviewSeconds, "Standard preview does not respect manual reaction time")
	end)

	test("match format duration and migration", function()
		expectEqual(MatchFormat.Get("Quick").RealSeconds, 180, "Quick duration")
		expectEqual(MatchFormat.Get("Standard").RealSeconds, 300, "Standard duration")
		expectEqual(MatchFormat.Get("Extended").RealSeconds, 480, "Extended duration")
		expectEqual(MatchFormat.Normalize(4), "Quick", "Numeric quick migration")
		expectEqual(MatchFormat.Normalize(6), "Standard", "Numeric standard migration")
		expectEqual(MatchFormat.Normalize(8), "Extended", "Numeric extended migration")
	end)

	test("match clock halftime and fulltime", function()
		for _, formatName in MatchFormat.Names do
			local duration = MatchFormat.Get(formatName).RealSeconds
			local clock = MatchClock.new(duration)
			clock:Step(duration / 2)
			expect(clock:ShouldHalfTime(), formatName .. " did not reach halftime")
			clock:StartSecondHalf()
			clock:Step(duration / 2)
			expect(clock:ShouldEndMatch(), formatName .. " did not reach fulltime")
		end
	end)

	test("interruption budgets", function()
		for _, name in MatchFormat.Names do
			local format = MatchFormat.Get(name)
			expect(format.ReplaySeconds <= format.ReplayMaximumSeconds, name .. " replay exceeds maximum")
			expect(format.ReplayMaximumSeconds <= 6, name .. " multiplayer replay maximum")
			expect(format.SetPieceDecisionSeconds >= 3 and format.SetPieceDecisionSeconds <= 5, name .. " set-piece decision budget")
			expect(format.SetPieceCameraTransitionSeconds <= .6, name .. " set-piece camera transition")
			expect(format.FinalWhistleFreezeSeconds >= 1 and format.FinalWhistleFreezeSeconds <= 1.5, name .. " final-whistle freeze")
			expect(format.ResultsVisibleSeconds <= 4 and format.NextMatchInputSeconds <= 8, name .. " post-match budget")
			expect(format.SetPieceSeconds <= 5 and format.FullTimeSeconds <= 8 and format.FinalChanceSeconds <= 14, name .. " interruption budget")
		end
		expect(MatchFormat.Get("Quick").ExtraTimeSeconds >= 60 and MatchFormat.Get("Quick").ExtraTimeSeconds <= 90, "Quick extra time")
		expectEqual(MatchFormat.Get("Standard").ExtraTimeSeconds, 120, "Standard extra time")
		expectEqual(MatchFormat.Get("Extended").ExtraTimeSeconds, 180, "Extended extra time")
		expectEqual(MatchFormat.Ranked.StraightToPenalties, true, "Ranked ties go straight to penalties")
		expectEqual(MatchFormat.Ranked.ExtraTimeSeconds, 0, "Ranked extra time disabled")
	end)

	test("replay restart participant gate", function()
		local home = Instance.new("Folder")
		local away = Instance.new("Folder")
		local gate = ReplayRestartGate.new(12, {home, away})
		expect(not gate:IsComplete(), "Replay gate started complete with active players")
		expect(not gate:Acknowledge(home, 11), "Stale replay acknowledgement was accepted")
		expect(not gate:IsComplete(), "Stale acknowledgement released replay gate")
		expect(gate:Acknowledge(home, 12), "Home replay completion was rejected")
		expect(not gate:IsComplete(), "One player released a two-player replay gate")
		expect(gate:Acknowledge(away, 12), "Away replay completion was rejected")
		expect(gate:IsComplete(), "Both replay completions did not release the gate")
		local disconnectGate = ReplayRestartGate.new(13, {home, away})
		disconnectGate:Acknowledge(home, 13)
		expect(disconnectGate:IsComplete(function(participant: Instance): boolean return participant ~= away end), "Disconnected player kept replay gate locked")
		expect(ReplayRestartGate.new(14, {}):IsComplete(), "AI-only side did not resolve automatically")
		home:Destroy()
		away:Destroy()
	end)

	test("AI reaction floor", function()
		for name, values in Difficulty.Definitions do
			expect(values.Reaction >= .18, name .. " reaction below floor")
			expect(values.DecisionMin >= .18, name .. " decision delay below floor")
			expect(values.DecisionMax >= values.DecisionMin, name .. " decision range invalid")
			expect(values.Positioning >= 0 and values.Positioning <= 1, name .. " positioning invalid")
			expect(values.PassAccuracy > 0 and values.ShotAccuracy > 0, name .. " accuracy invalid")
		end
		expectEqual(Difficulty.ResolveName("Professional"), "Regional Pro", "Professional AI alias")
		expectEqual(Difficulty.ResolveName("Legendary"), "Voltra Masters", "Legendary AI alias")
		local restoreSeconds = Difficulty.FirstMatch.RestoreSeconds
		expectEqual(AIDifficulty.FirstMatchBlend(nil, 100), 1, "First-match assistance did not begin fully active")
		expectEqual(AIDifficulty.FirstMatchBlend(100, 100 + restoreSeconds), 0, "First-match assistance did not restore fully")
		local midpoint = AIDifficulty.FirstMatchBlend(100, 100 + restoreSeconds * .5)
		expect(math.abs(midpoint - .5) < .001, "First-match restoration is not gradual")
		expect(math.abs(AIDifficulty.FirstMatchPassTempoCap(1) - Difficulty.FirstMatch.MaximumOneTouchTempo) < .001, "First-match pass tempo cap was ignored")
		expect(math.abs(AIDifficulty.FirstMatchPassTempoCap(0) - 1) < .001, "Returning AI pass tempo remained capped")
	end)

	test("camera device defaults", function()
		expectEqual(DeviceGameplay.Camera.Desktop.Preset, "Tactical", "Desktop camera")
		expectEqual(DeviceGameplay.Camera.Gamepad.Preset, "Pro", "Gamepad camera")
		expectEqual(DeviceGameplay.Camera.Mobile.Preset, "Pro", "Mobile camera")
		expectEqual(DeviceGameplay.Camera.Mobile.ZoomMode, "Close", "Mobile framing")
	end)

	test("mobile safe-area layouts", function()
		local function verify(viewport: Vector2, insets: any, handedness: string)
			local layout = MobileControlLayout.Resolve(viewport, insets, handedness)
			expect(layout.NormalSize >= 56 and layout.PrimarySize >= 64, "Touch target below physical minimum")
			local points = {{layout.Primary, layout.PrimarySize}, {layout.Secondary, layout.PrimarySize}, {layout.Sprint, layout.NormalSize}, {layout.Context, layout.NormalSize}}
			for _, entry in points do
				local point, size = entry[1], entry[2]
				expect(point.X - size * .5 >= insets.Left and point.X + size * .5 <= viewport.X - insets.Right, "Action escaped horizontal safe area")
				expect(point.Y - size * .5 >= insets.Top and point.Y + size * .5 <= viewport.Y - insets.Bottom, "Action escaped vertical safe area")
			end
			local rowDistance = math.abs(layout.Primary.X - layout.Sprint.X) - (layout.PrimarySize + layout.NormalSize) * .5
			expect(rowDistance >= 10, "Action separation below minimum")
			return layout
		end
		local narrow = verify(Vector2.new(360, 780), {Left = 0, Top = 44, Right = 0, Bottom = 24}, "Right")
		local wide = verify(Vector2.new(844, 390), {Left = 34, Top = 0, Right = 34, Bottom = 20}, "Right")
		local tablet = verify(Vector2.new(1024, 1366), {Left = 0, Top = 36, Right = 0, Bottom = 20}, "Right")
		local left = verify(Vector2.new(844, 390), {Left = 34, Top = 0, Right = 34, Bottom = 20}, "Left")
		expect(narrow.Joystick.Y ~= wide.Joystick.Y and tablet.PrimarySize >= narrow.PrimarySize, "Orientation or tablet layout did not recalculate")
		expect(left.Primary.X < 422 and left.Joystick.X > 422 and wide.Primary.X > 422 and wide.Joystick.X < 422, "Handedness did not mirror control sides")
	end)

	test("settings migration idempotence", function()
		local migrated = PlayabilitySettings.Normalize({CameraPreset = "Wide Broadcast", ReceiverAssist = "Assisted", MatchLength = 4, SprintToggle = false, ReducedMotion = true})
		expectEqual(migrated.CameraPreset, "Tactical", "Camera alias")
		expectEqual(migrated.ReceiverAssistMode, "Newcomer", "Receiver alias")
		expectEqual(migrated.MatchFormat, "Quick", "Match length alias")
		expectEqual(migrated.MobileSprintMode, "Hold", "Sprint toggle alias")
		local twice = PlayabilitySettings.Normalize(migrated)
		for key, value in migrated do expectEqual(twice[key], value, "Migration changed " .. key) end
	end)

	test("debug security policy", function()
		local base = {OptIn = true, Authorized = true, IsStudio = true, IsPrivateServer = false, Ranked = false, WorldCup = false, ShootingPractice = true, RateReady = true}
		expect(DebugPolicy.CanUse("DebugCorner", base), "Authorized Studio rejected")
		local disabled = table.clone(base) disabled.OptIn = false
		expect(not DebugPolicy.CanUse("DebugCorner", disabled), "Disabled debug accepted")
		local public = table.clone(base) public.IsStudio = false
		expect(not DebugPolicy.CanUse("DebugCorner", public), "Public debug accepted")
		local unauthorized = table.clone(base) unauthorized.Authorized = false
		expect(not DebugPolicy.CanUse("DebugCorner", unauthorized), "Unauthorized debug accepted")
		local ranked = table.clone(base) ranked.Ranked = true
		expect(not DebugPolicy.CanUse("DebugCorner", ranked), "Ranked debug accepted")
		local worldCup = table.clone(base) worldCup.WorldCup = true
		expect(not DebugPolicy.CanUse("DebugCorner", worldCup), "World Cup debug accepted")
		local throttled = table.clone(base) throttled.RateReady = false
		expect(not DebugPolicy.CanUse("DebugCorner", throttled), "Throttled debug accepted")
	end)

	test("ball and tackle envelopes", function()
		expect(Gameplay.Ball.DribbleNaturalDistance <= 2, "Natural correction zone")
		expect(Gameplay.Ball.DribbleControlledDistance <= 6 and Gameplay.Ball.DribbleHardRecoveryDistance <= 7, "Hard correction envelope")
		expect(Gameplay.Ball.DribbleMaximumCorrection <= 2.5, "Hard correction is unbounded")
		expectEqual(Gameplay.Ball.StandingTackleRange, 10.8, "Standing tackle range doubled")
		expectEqual(Gameplay.Ball.SlideTackleRange, 14, "Slide tackle range doubled")
	end)

	test("contested possession is order independent", function()
		local function candidate(key: string, x: number): any
			return {Key = key, RootPosition = Vector3.new(x, 2.2, 0), RootVelocity = Vector3.zero, MoveDirection = Vector3.zero, Facing = Vector3.new(-x, 0, 0), ContactPoints = {Vector3.new(x, 0, 0)}, ContactReach = 2.4, ControlHeight = 2.2, Control = 70, Balance = 70, Strength = 70, Valid = true}
		end
		local ball = {Position = Vector3.new(0, 1, 0), Velocity = Vector3.zero, Radius = 1}
		local a = candidate("A", -1.5)
		local b = candidate("B", 1.5)
		local forward = BallContact.Resolve({a, b}, ball)
		local reverse = BallContact.Resolve({b, a}, ball)
		expect(forward and reverse and forward.Outcome == "Deflected" and reverse.Outcome == "Deflected", "Contested contact became automatic possession")
		expectEqual(forward.Candidate.Key, reverse.Candidate.Key, "Contact winner depended on iteration order")
	end)

	test("swept contact catches a frame crossing", function()
		local candidate = {Key = "Foot", RootPosition = Vector3.new(0, 2.2, 0), RootVelocity = Vector3.zero, MoveDirection = Vector3.zero, Facing = Vector3.zAxis, ContactPoints = {{PreviousPosition = Vector3.new(0, 1, 0), Position = Vector3.new(0, 1, 0), Kind = "RightFoot"}}, ContactReach = 1.75, ControlHeight = 2.2, Control = 75, Balance = 70, Agility = 72, Strength = 65, PreferredFoot = "Right", Valid = true}
		local contact = BallContact.ResolveSwept({candidate}, {PreviousPosition = Vector3.new(-7, 1, 0), Position = Vector3.new(7, 1, 0), Velocity = Vector3.new(90, 0, 0), Radius = 1, Duration = .1})
		expect(contact and contact.Valid and contact.ContactTime > 0 and contact.ContactTime < .1, "Swept crossing missed the physical foot")
	end)

	test("controlled player body contact traps from every direction", function()
		local candidate = {Key = "Controlled", RootPosition = Vector3.new(0, 2.2, 0), RootVelocity = Vector3.zero, MoveDirection = Vector3.zero, Facing = Vector3.zAxis, ContactPoints = {{PreviousPosition = Vector3.new(0, 1, 0), Position = Vector3.new(0, 1, 0), Kind = "LeftFoot"}}, ContactReach = 1.75, ControlHeight = 2.2, Control = 40, Balance = 40, Agility = 40, Strength = 40, UserControlled = true, CanControl = true, Valid = true}
		local contact = BallContact.ResolveSwept({candidate}, {PreviousPosition = Vector3.new(0, 1, -6), Position = Vector3.new(0, 1, 6), Velocity = Vector3.new(0, 0, 110), Radius = 1, Duration = .1})
		expect(contact and contact.Valid and contact.Outcome == "Controlled", "Controlled player contact did not trap the ball")
		candidate.CanControl = false
		local locked = BallContact.ResolveSwept({candidate}, {PreviousPosition = Vector3.new(0, 1, -6), Position = Vector3.new(0, 1, 6), Velocity = Vector3.new(0, 0, 110), Radius = 1, Duration = .1})
		expect(locked and locked.Valid and locked.Outcome == "Deflected", "Recovery lock allowed the ball through or granted possession")
	end)

	test("AI pass timing uses the authoritative flight curve", function()
		local flight = Gameplay.Ball.Flight
		local short = PassFlightModel.Duration(flight, 22, .3, "Ground")
		local long = PassFlightModel.Duration(flight, 105, .3, "Ground")
		local driven = PassFlightModel.Duration(flight, 105, .7, "Through")
		expect(short > 0 and long > short and driven > 0, "Pass flight duration is not distance aware")
	end)

	test("AI movement profile catalog is complete", function()
		expect(AIMovementProfiles.IsValid(AIMovementProfiles.Default), "Default movement profile is invalid")
		for _, profileId in AIMovementProfiles.Order do
			local definition = AIMovementProfiles.Profiles[profileId]
			expect(AIMovementProfiles.IsValid(profileId) and type(definition.Name) == "string" and type(definition.Description) == "string", "Movement profile metadata missing for " .. profileId)
		end
		expect(not AIMovementProfiles.IsValid("Exploit"), "Unknown movement profile was accepted")
	end)

	test("tactic presets are complete and migrate legacy ids", function()
		expectEqual(#AITactic.Order, 10, "Tactic preset count")
		for _, id in AITactic.Order do
			local preset = AITactic.Get(id)
			expect(preset.Id == id and preset.MaxMajorRuns >= 1 and preset.MaxPressers >= 1, "Tactic metadata missing for " .. id)
			for _, name in AITactic.SliderNames do expect(type(preset.Sliders[name]) == "number", id .. " omitted " .. name) end
		end
		expectEqual(AITactic.Normalize({Identity = "Tiki Taka"}).PresetId, "short_possession", "Legacy possession migration")
		expectEqual(AITactic.Normalize({Identity = "Park The Bus"}).PresetId, "low_block_counter", "Legacy low-block migration")
	end)

	test("AI behavior tuning metadata is valid", function()
		local seen: any = {}
		local categories: any = {}
		for _, category in AIBehaviorTuning.Categories do categories[category] = true end
		for _, meta in AIBehaviorTuning.All() do
			expect(not seen[meta.Id], "Duplicate AI behavior setting " .. meta.Id)
			seen[meta.Id] = true
			expect(type(meta.Label) == "string" and #meta.Label > 0, "Missing label for " .. meta.Id)
			expect(categories[meta.Category] == true, "Unknown category for " .. meta.Id)
			expect(type(meta.Min) == "number" and type(meta.Max) == "number" and meta.Min < meta.Max, "Invalid range for " .. meta.Id)
			expect(type(meta.Step) == "number" and meta.Step > 0, "Invalid step for " .. meta.Id)
			expect(meta.Default >= meta.Min and meta.Default <= meta.Max, "Default outside range for " .. meta.Id)
			expect(meta.Visibility == "Public" or meta.Visibility == "Developer", "Invalid visibility for " .. meta.Id)
			expect(type(meta.Scopes) == "table" and #meta.Scopes > 0, "Missing scopes for " .. meta.Id)
			expect(type(meta.Systems) == "table" and #meta.Systems > 0, "Missing consumers for " .. meta.Id)
		end
		for _, id in {"ForwardPassBias", "LateralPassBias", "BackPassBias", "BackPassSafety", "RecycleBias", "PossessionPatience", "MinimumHoldTime", "OneTouchPassing", "SwitchPlayFrequency", "PassToFeetBias", "LeadRunBias", "RetentionProbabilityWeight", "ReceiverNextOptionsWeight", "ReceiverIsolationPenalty", "AerialContestPenalty", "ImmediateSupportDistance", "TriangleStrength", "MaxMajorRuns", "RestDefenseMinimum", "CounterAttackFrequency", "MaxPressers", "DefensiveDepth", "SprintConservation", "ReceiverTrapAggression", "ShotPatience", "SequencePersistence", "ThirdManSequenceBias", "LookaheadPasses"} do
			expect(seen[id] == true, "Critical AI behavior setting missing " .. id)
		end
	end)

	test("AI behavior resolver precedence and migration are idempotent", function()
		local preset = AITactic.Get("balanced_control")
		local profile = {
			PresetId = "balanced_control",
			GlobalOverrides = {ForwardPassBias = 11, MinimumHoldTime = 0.25},
			PhaseOverrides = {BuildUp = {ForwardPassBias = 22}},
			RoleOverrides = {CM = {ForwardPassBias = 33}},
			MatchStateOverrides = {Trailing = {ForwardPassBias = 44}},
			ExecutionOverrides = {LookaheadPasses = 2},
		}
		local resolved = AIBehaviorTuning.Resolve(preset.Sliders, profile, {Phase = "BuildUp", Role = "CM", MatchState = "Trailing", Sequence = {ForwardPassBias = 55}, Emergency = {ForwardPassBias = 66}})
		expectEqual(resolved.ForwardPassBias, 66, "Emergency precedence")
		expectEqual(resolved.MinimumHoldTime, 0.25, "Global timing override")
		expectEqual(resolved.LookaheadPasses, 2, "Execution override")
		local migrated = AITactic.Normalize({Identity = "Balanced", Sliders = {PassTempo = 64, BackPassSafety = 71}})
		local migratedAgain = AITactic.Normalize(migrated)
		expectEqual(migratedAgain.Sliders.PassTempo, migrated.Sliders.PassTempo, "Second tactic migration changed pass tempo")
		expectEqual(migratedAgain.Sliders.BackPassSafety, migrated.Sliders.BackPassSafety, "Second tactic migration changed back-pass safety")
		local ok = AIBehaviorTuning.ValidateSettingValue("ForwardPassBias", math.huge)
		expect(ok == false, "Infinity was accepted")
		ok = AIBehaviorTuning.ValidateSettingValue("ForwardPassBias", 140)
		local _, clamped = AIBehaviorTuning.ValidateSettingValue("ForwardPassBias", 140)
		expect(ok == true and clamped == 100, "Out-of-range setting did not clamp")
	end)

	test("pass trail visibility defaults and validates", function()
		expectEqual(PlayabilitySettings.Normalize({}).PassTrailVisibility, "UserOnly", "Pass trail default")
		expectEqual(PlayabilitySettings.Normalize({PassTrailVisibility = "All"}).PassTrailVisibility, "All", "Pass trail selection")
		expectEqual(PlayabilitySettings.Normalize({PassTrailVisibility = "Invalid"}).PassTrailVisibility, "UserOnly", "Pass trail validation")
	end)

	test("aerial ball is not vacuumed by a ground player", function()
		local contact = BallContact.Evaluate({Key = "Ground", RootPosition = Vector3.new(0, 2.2, 0), RootVelocity = Vector3.zero, Facing = Vector3.zAxis, ContactPoints = {Vector3.zero}, ContactReach = 2.4, ControlHeight = 2.2, Valid = true}, {Position = Vector3.new(0, 9, 0), Velocity = Vector3.new(0, 0, 20), Radius = 1})
		expect(not contact.Valid, "Ground contact vacuumed an aerial ball")
	end)

	test("reception contact requires a physical body point", function()
		local ball = {Position = Vector3.new(0, 1, 1), Velocity = Vector3.new(0, 0, 12), Radius = 1}
		local rootOnly = BallContact.Evaluate({Key = "RootOnly", RootPosition = Vector3.new(0, 2.2, 1), RootVelocity = Vector3.zero, Facing = Vector3.zAxis, ContactPoints = {Vector3.new(8, 0, 1)}, ContactReach = 2.4, ControlHeight = 5.8, Valid = true}, ball)
		expect(not rootOnly.Valid, "Root proximity bypassed the body contact point")
		local intended = {Key = "Intended", RootPosition = Vector3.new(0, 2.2, 0), RootVelocity = Vector3.zero, MoveDirection = Vector3.zAxis, Facing = Vector3.zAxis, ContactPoints = {Vector3.new(0, 1, .9)}, ContactReach = 2.4, ControlHeight = 5.8, Control = 88, Balance = 82, Strength = 72, ExpectedReceiver = true, Valid = true}
		local alternate = table.clone(intended)
		alternate.Key = "Alternate"
		alternate.ContactPoints = {Vector3.new(.8, 1, .9)}
		alternate.ExpectedReceiver = false
		local defender = table.clone(intended)
		defender.Key = "Defender"
		defender.ContactPoints = {Vector3.new(0, 1, 1)}
		defender.Control = 94
		local intendedContact = BallContact.Resolve({alternate, intended}, ball)
		expect(intendedContact and intendedContact.Candidate.Key == "Intended" and intendedContact.Valid, "Intended foot contact was not selected")
		local defenderFirst = BallContact.Resolve({intended, defender}, ball)
		expect(defenderFirst and defenderFirst.Candidate.Key == "Defender", "Defender contact did not remain authoritative")
	end)

	test("tackle geometry separates misses clean wins and slide paths", function()
		local miss = Tackle.Resolve({Slide = false, StartPosition = Vector3.zero, EndPosition = Vector3.zero, BallPosition = Vector3.new(0, 0, 16), OwnerPosition = Vector3.new(0, 0, 16), Facing = Vector3.zAxis, OwnerFacing = -Vector3.zAxis, Tackle = 99, Dribbling = 1, Strength = 99, OwnerBalance = 1, Stamina = 100, Exposure = 1})
		expectEqual(miss.Outcome, "TackleMiss", "Standing miss became a successful outcome")
		local clean = Tackle.Resolve({Slide = false, StartPosition = Vector3.zero, EndPosition = Vector3.zero, BallPosition = Vector3.new(0, 0, 1), OwnerPosition = Vector3.new(0, 0, 1.4), Facing = Vector3.zAxis, OwnerFacing = Vector3.zAxis, Tackle = 99, Dribbling = 1, Strength = 99, OwnerBalance = 1, Stamina = 100, Exposure = 1})
		expectEqual(clean.Outcome, "TackleWonPossession", "Clean standing tackle did not resolve once as a win")
		local slide = Tackle.Resolve({Slide = true, StartPosition = Vector3.new(-6, 0, 0), EndPosition = Vector3.new(6, 0, 0), BallPosition = Vector3.zero, OwnerPosition = Vector3.new(0, 0, 1), Facing = -Vector3.xAxis, OwnerFacing = Vector3.zAxis, Tackle = 90, Dribbling = 20, Strength = 90, OwnerBalance = 30, Stamina = 100, Exposure = 1})
		expect(slide.Outcome ~= "TackleMiss", "Slide path ignored contact between start and end")
		local crossing = Tackle.Resolve({Slide = false, StartPosition = Vector3.new(-5, 0, 0), EndPosition = Vector3.new(5, 0, 0), BallStartPosition = Vector3.new(0, 0, -5), BallPosition = Vector3.new(0, 0, 5), OwnerStartPosition = Vector3.new(0, 0, -4), OwnerPosition = Vector3.new(0, 0, 6), Facing = Vector3.xAxis, OwnerFacing = Vector3.zAxis, Tackle = 90, Dribbling = 20, Strength = 90, OwnerBalance = 30, Stamina = 100, Exposure = 1})
		expect(crossing.Outcome ~= "TackleMiss", "Synchronized standing-tackle sweep missed a crossing carrier")
	end)

	test("shared dribble target remains inside its legal envelope", function()
		local result = DribbleTarget.Resolve({RootPosition = Vector3.new(10, 4, 20), RootLookVector = Vector3.zAxis, MoveVector = Vector3.new(1, 0, 1), HorizontalVelocity = Vector3.new(12, 0, 12), Sprinting = true, CloseControl = false, BallControl = 82, TurnDot = .7, TouchPhase = .35, BallRadius = 1, VerticalOffset = 2.45, ActionLocked = false})
		expectEqual(result.Target, result.PredictedVisualTarget, "Client and server dribble targets diverged")
		local horizontal = Vector3.new(result.Target.X - 10, 0, result.Target.Z - 20).Magnitude
		expect(horizontal <= result.LegalEnvelope and result.HardRecoveryDistance <= 10, "Dribble target escaped legal correction envelope")
	end)

	test("ball visual destruction restores exact original state", function()
		local root = StarterPlayer.StarterPlayerScripts.VTRClient
		local BallVisual = require(root.Gameplay.BallVisualController)
		local model = Instance.new("Model")
		model.Name = "VTRBallModel"
		local ball = Instance.new("Part")
		ball.Name = "Ball"
		ball.Size = Vector3.new(2, 2, 2)
		ball.Transparency = .31
		ball.LocalTransparencyModifier = .22
		ball.Parent = model
		model.PrimaryPart = ball
		local decal = Instance.new("Decal")
		decal.Transparency = .47
		decal.Parent = ball
		local emitter = Instance.new("ParticleEmitter")
		emitter.Enabled = true
		emitter.Parent = ball
		model.Parent = workspace
		local owner = Instance.new("Model")
		owner.Name = "VisualOwner"
		owner.Parent = workspace
		local visual = BallVisual.new(ball, owner)
		local proxy = visual.VisualModel or visual.Visual
		local shadow = visual.Shadow
		expect(ball.LocalTransparencyModifier == 1 and decal.Transparency == 1 and emitter.Enabled == false, "Original visuals were not hidden")
		visual:Destroy()
		expectEqual(ball.Transparency, .31, "Ball transparency was not restored")
		expectEqual(ball.LocalTransparencyModifier, .22, "Ball local transparency was not restored")
		expectEqual(decal.Transparency, .47, "Decal transparency was not restored")
		expect(emitter.Enabled == true, "Emitter enabled state was not restored")
		expect((not proxy or proxy.Parent == nil) and (not shadow or shadow.Parent == nil), "Predicted visuals survived destruction")
		owner:Destroy();model:Destroy()
	end)

	test("shot overhit curve is continuous", function()
		local inputs = {0, .25, .5, .75, .94, .95, 1}
		local previousSpeed = -math.huge
		local previousOverhit = -math.huge
		for _, input in inputs do
			local speed = ShotPower.SpeedScale(input)
			local overhit = ShotPower.OverhitAmount(input)
			expect(speed >= previousSpeed and overhit >= previousOverhit, "Shot curve is not monotonic")
			previousSpeed = speed;previousOverhit = overhit
		end
		expect(not ShotPower.IsOverhit(.95) and ShotPower.IsOverhit(.9501), "Overhit threshold moved")
		expect(ShotPower.OverhitAmount(.9501) < .001, "Overhit curve jumps at threshold")
		expect(ShotPower.SpeedScale(1) > ShotPower.SpeedScale(.95), "Overhit no longer adds excess speed")
		expect(ShotPower.PlacementMultiplier(1) < .5, "Overhit accuracy penalty is too weak")
		expectEqual(ShotPower.ApplyToVelocity(Vector3.zero, .95), Vector3.zero, "Accidental lift at accurate maximum")
		local overhitTarget=ShotPower.ApplyToTarget(Vector3.zero,Vector3.new(0,5,-100),1)
		expect(overhitTarget.Y>=30 and overhitTarget.Z < -150,"Maximum-power shot no longer clears the goal")
	end)

	test("lofted pass does not gain free accuracy", function()
		local input = {Passing = 82, WeakFoot = 3, Balance = 76, Distance = 55, Pressure = .2, BodyDot = .8, MovementSpeed = 8, PreferredFoot = "Right", SelectedFoot = "Right", Sprinting = false}
		local groundInput = table.clone(input);groundInput.PassFamily = "Ground"
		local loftedInput = table.clone(input);loftedInput.PassFamily = "Lofted"
		local ground = PassError.Resolve(groundInput)
		local lofted = PassError.Resolve(loftedInput)
		expect(lofted.Radius >= ground.Radius, "Lofted pass became automatically more accurate")
		expectEqual(PassError.Resolve(groundInput).Radius, ground.Radius, "Pass error resolver is not deterministic")
	end)

	test("profile progression schema", function()
		expectEqual(DefaultProfile.Version, 15, "Profile version")
		expectEqual(DefaultProfile.PlayabilityProgress.Version, 2, "Playability gate version")
		expect(DefaultProfile.PlayabilityProgress.CompletedMatches == 0 and DefaultProfile.PlayabilityProgress.LegacyAccessGranted == false, "Fresh profile is not fresh")
		expectEqual(DefaultProfile.Settings.ReceiverAssistMode, "Newcomer", "Fresh receiver default")
		expectEqual(DefaultProfile.Settings.PassReceiverAutoSwitch, "Newcomer", "Fresh switch default")
	end)

	test("three-match progression unlocks", function()
		local fresh = {CompletedMatches = 0, FirstWorldCupRunCompleted = false, LegacyAccessGranted = false}
		expect(PlayabilityUnlocks.RouteUnlocked(fresh, "WorldCup"), "Fresh World Cup route was locked")
		expect(not PlayabilityUnlocks.FeatureUnlocked(fresh, "PlayerDetails"), "Fresh reward details unlocked early")
		fresh.CompletedMatches = 1
		expect(PlayabilityUnlocks.FeatureUnlocked(fresh, "PlayerDetails"), "First-match reward details remained locked")
		expect(not PlayabilityUnlocks.RouteUnlocked(fresh, "Inventory"), "Inventory unlocked before match two")
		fresh.CompletedMatches = 2
		expect(PlayabilityUnlocks.RouteUnlocked(fresh, "UltimateTeam") and PlayabilityUnlocks.RouteUnlocked(fresh, "Inventory"), "Match-two squad access remained locked")
		expect(not PlayabilityUnlocks.FeatureUnlocked(fresh, "Packs"), "Packs unlocked before match three")
		fresh.CompletedMatches = 3
		expect(PlayabilityUnlocks.FeatureUnlocked(fresh, "Packs") and PlayabilityUnlocks.FeatureUnlocked(fresh, "Chemistry"), "Match-three systems remained locked")
		expect(PlayabilityUnlocks.RouteUnlocked(fresh, "Campaign"), "Ascension remained locked after match three")
		expect(not PlayabilityUnlocks.RouteUnlocked(fresh, "Ranked"), "Ranked unlocked before the first World Cup run")
		fresh.FirstWorldCupRunCompleted = true
		expect(PlayabilityUnlocks.RouteUnlocked(fresh, "Ranked") and PlayabilityUnlocks.FeatureUnlocked(fresh, "AdvancedCompetitiveSettings"), "World Cup completion did not unlock competitive systems")
		local legacy = {CompletedMatches = 0, FirstWorldCupRunCompleted = false, LegacyAccessGranted = true}
		expect(PlayabilityUnlocks.RouteUnlocked(legacy, "Ranked") and PlayabilityUnlocks.FeatureUnlocked(legacy, "Packs"), "Legacy access was removed")
	end)

	test("profile migration fresh returning and idempotent", function()
		local service = ProfileService.new({})
		local fresh = copy(DefaultProfile)
		fresh.Settings = {ReceiverAssist = "Assisted", CameraPreset = "Wide Broadcast", SprintToggle = false}
		fresh.UIState.Settings = {}
		fresh.MatchSetup.MatchFormat = nil
		fresh.MatchSetup.MatchLength = 4
		service:_migrate(fresh)
		expect(fresh.PlayabilityProgress.LegacyAccessGranted == false and fresh.PlayabilityProgress.CompletedMatches == 0, "Fresh profile was grandfathered")
		expectEqual(fresh.Settings.ReceiverAssistMode, "Newcomer", "Fresh receiver alias")
		expectEqual(fresh.Settings.CameraPreset, "Tactical", "Fresh camera alias")
		expectEqual(fresh.MatchSetup.MatchFormat, "Quick", "Fresh numeric match length")

		local returning = copy(DefaultProfile)
		returning.Version = 14
		returning.SchemaVersion = 14
		returning.Settings = {ReceiverAssistMode = "Manual", CameraPreset = "Pro", MatchFormat = "Extended"}
		returning.UIState.Settings = {}
		returning.MatchStats.Overall.Played = 12
		service:_migrate(returning)
		expect(returning.PlayabilityProgress.LegacyAccessGranted and returning.PlayabilityProgress.CompletedMatches >= 12, "Returning profile lost access")
		expectEqual(returning.Settings.ReceiverAssistMode, "Manual", "Explicit receiver preference changed")
		expectEqual(returning.Settings.CameraPreset, "Pro", "Explicit camera preference changed")
		local before = copy(returning.PlayabilityProgress)
		service:_migrate(returning)
		for key, value in before do expectEqual(returning.PlayabilityProgress[key], value, "Second profile migration changed " .. key) end
	end)

	test("defensive intent only high presses in high zones", function()
		local director = AITacticalIntentDirector.new()
		local style = {Ratio = function(_, key: string)
			if key == "PressingIntensity" then return .92 end
			if key == "PressTriggerDistance" then return .9 end
			if key == "CounterPress" then return .7 end
			if key == "DefensiveDepth" then return .55 end
			return .5
		end}
		local context = {Now = 1, OwnerSide = "Away", LooseBall = false, MatchState = "Live", BallTeam = {Home = Vector3.new(212, 3, 250), Away = Vector3.new(212, 3, 492)}, DefensivePress = {Home = {}, Away = {}}}
		local first = director:Update(context, {Home = style, Away = style}, nil, nil)
		expect(first.Home.Intent ~= "HighPress", "Home high pressed in a middle-zone defensive state")
		context.Now = 2
		context.BallTeam.Home = Vector3.new(212, 3, 486)
		local second = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(second.Home.Intent, "HighPress", "Home did not high press in the correct high zone")
		context.Now = 3
		context.BallTeam.Home = Vector3.new(212, 3, 160)
		local third = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(third.Home.Intent, "ProtectBox", "Box-zone defence did not protect the box")
	end)

	test("defensive block locks chosen pressers and keeps cover goal-side", function()
		local function player(role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = "Home", Role = role, Pitch = pitch, World = pitch, Stats = {pace = 70}, Stamina = 80}
		end
		local list = {player("ST", Vector3.new(210, 3, 430)), player("Winger", Vector3.new(70, 3, 420)), player("CM", Vector3.new(200, 3, 350)), player("CDM", Vector3.new(214, 3, 310)), player("CB", Vector3.new(150, 3, 180)), player("CB", Vector3.new(270, 3, 180))}
		local style = {Ratio = function(_, key: string) if key == "PressingIntensity" then return .9 elseif key == "DefensiveDepth" then return .8 elseif key == "BackLineCompactness" then return .55 end return .5 end}
		local context = {Now = 1, BallTeam = {Home = Vector3.new(212, 3, 430)}, Teams = {Home = {List = list}, Away = {List = {}}}}
		local block = AIDefensiveBlockPlanner.new():Build(context, "Home", style, {Intent = "HighPress"})
		local primary = nil
		local cover = nil
		local support = nil
		for _, slot in ipairs(block.Slots) do
			if slot.Id == "primary-presser" then primary = slot elseif slot.Id == "cover-presser" then cover = slot elseif slot.Id == "midfield-press-support" then support = slot end
		end
		expect(primary and primary.LockedModel == list[1].Model, "Primary press slot did not lock the chosen attacker")
		expect(cover and cover.LockedModel == list[3].Model, "Cover press slot did not lock the chosen central midfielder")
		expect(support ~= nil, "Midfield press support slot was not created")
		expect(primary.TargetPitch.Z <= context.BallTeam.Home.Z and cover.TargetPitch.Z < context.BallTeam.Home.Z, "Press targets were not goal-side of the ball")
		for _, info in ipairs(list) do info.Model:Destroy() end
	end)

	test("attacking shape caps forward slots to onside line", function()
		local function info(side: string, role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = side, Role = role, Pitch = pitch, World = pitch, Stats = {pace = 70}, Stamina = 80, IsGoalkeeper = role == "GK"}
		end
		local home = {}
		for index, role in ipairs({"GK", "CB", "CB", "Fullback", "Fullback", "CDM", "CM", "CAM", "Winger", "Winger", "ST"}) do
			table.insert(home, info("Home", role, Vector3.new(52 + index * 30, 3, 160 + index * 34)))
		end
		local away = {info("Away", "GK", Vector3.new(212, 3, 700)), info("Away", "CB", Vector3.new(170, 3, 590)), info("Away", "CB", Vector3.new(254, 3, 585))}
		local context = {OwnerSide = "Home", Formations = {Home = "4-3-3"}, BallTeam = {Home = Vector3.new(212, 3, 520)}, BallWorld = Vector3.new(212, 3, 520), TeamBrain = {Home = {AttackingIdentity = "DirectAssault"}}, Teams = {Home = {List = home}, Away = {List = away}}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}}
		local slots = AIShapeTemplateService.Build(context, "Home", AITacticalStyleService.new({PresetId = "vertical_combination"}), nil, nil, nil)
		for _, slot in ipairs(slots) do
			if slot.Line == "Forward" then
				expect(slot.TargetPitch.Z <= 583, "Forward slot was left beyond the second-last defender onside cap")
			end
		end
		for _, team in {home, away} do for _, item in ipairs(team) do item.Model:Destroy() end end
	end)

	test("AI pass planner rejects receiver offside at kick moment", function()
		local function player(side: string, role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = pitch
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = pitch, World = pitch, Stats = {pace = 70, passQuality = 70, reception = 70}, Stamina = 80}
		end
		local passer = player("Home", "CM", Vector3.new(212, 3, 520))
		local receiver = player("Home", "ST", Vector3.new(212, 3, 650))
		local defenderA = player("Away", "CB", Vector3.new(190, 3, 600))
		local defenderB = player("Away", "CB", Vector3.new(235, 3, 590))
		local context = {Now = 1, BallWorld = passer.World, BallTeam = {Home = passer.Pitch}, Teams = {Home = {List = {passer, receiver}}, Away = {List = {defenderA, defenderB}}}, Options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}}
		local result = AIPassExecutionPlanner.Plan(context, passer, {Receiver = receiver, Target = receiver.World, PassKind = "Ground"}, AITacticalStyleService.new({PresetId = "balanced_control"}), {PassRisk = 0})
		expect(result == nil, "Offside receiver was accepted by pass execution planner")
		expect(receiver.Model:GetAttribute("AIPassRejectedOffside") == true, "Offside pass rejection attribute was not set")
		for _, item in {passer, receiver, defenderA, defenderB} do item.Model:Destroy() end
	end)

	test("team pass memory penalizes repeated same-lane forward loops", function()
		local memory = AITeamMemory.new()
		local receiver = Instance.new("Model")
		memory:RememberPass("Home", "Winger", "ST", receiver, "Center", 520, 1)
		local loopPenalty = memory:RecentPassPenalty("Home", "ST", "Winger", receiver, "Center", 530, "progress")
		local switchPenalty = memory:RecentPassPenalty("Home", "CM", "Fullback", nil, "RightWide", 360, "switch")
		expect(loopPenalty >= 80, "Forward loop memory penalty was too weak")
		expect(switchPenalty == 0, "Safe switch route was penalized by pass memory")
		receiver:Destroy()
	end)

	test("tactical action profiles allow attackers to finish and restrict rest defence", function()
		local depth = AITacticalContract.Slot({Id = "central-forward", Function = "Depth striker", RoleFamily = "ST", TargetPitch = Vector3.new(212, 3, 620), Line = "Forward"})
		local checking = AITacticalContract.Slot({Id = "checking-striker", Function = "Checking striker", RoleFamily = "ST", TargetPitch = Vector3.new(190, 3, 590), Line = "Forward"})
		local ballSide = AITacticalContract.Slot({Id = "left-width", Function = "Ball-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(54, 3, 590), Line = "Forward"})
		local farSide = AITacticalContract.Slot({Id = "right-width", Function = "Far-side width", RoleFamily = "Winger", TargetPitch = Vector3.new(370, 3, 590), Line = "Forward"})
		local rest = AITacticalContract.Slot({Id = "rest-defense", Function = "Central rest defender", RoleFamily = "CB", TargetPitch = Vector3.new(212, 3, 120), RestDefense = true})
		local pivot = AITacticalContract.Slot({Id = "ball-side-pivot", Function = "Ball-side pivot", RoleFamily = "CDM", TargetPitch = Vector3.new(212, 3, 360), Line = "Midfield", ForbiddenActions = {"BoxRun"}})
		expect(AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = depth.AllowedActions}), "Shoot"), "Depth striker cannot shoot")
		expect(AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = checking.AllowedActions}), "Shoot"), "Checking striker cannot shoot")
		expect(AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = ballSide.AllowedActions}), "Shoot") and AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = ballSide.AllowedActions}), "Cross"), "Ball-side winger cannot shoot and cross")
		expect(AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = farSide.AllowedActions}), "Shoot") and AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = farSide.AllowedActions}), "Cross"), "Far-side winger cannot shoot and cross")
		expect(not AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = rest.AllowedActions, ForbiddenActions = rest.ForbiddenActions}), "Shoot"), "Rest defender can shoot")
		expect(not AITacticalContract.ActionAllowed(AITacticalContract.Player({AllowedActions = pivot.AllowedActions, ForbiddenActions = pivot.ForbiddenActions}), "BoxRun"), "Pivot can make unsupported box run")
	end)

	test("central carrier breach creates contain cover and deep-cover assignments", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local function player(side: string, role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = PitchConfig.TeamPitchPositionToWorld(pitch, side, options)
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = pitch, World = root.Position, Stats = {pace = 70, defending = 70, tackleSkill = 70}, Stamina = 80}
		end
		local home = {player("Home", "ST", Vector3.new(212, 3, 470)), player("Home", "CM", Vector3.new(192, 3, 335)), player("Home", "CDM", Vector3.new(212, 3, 290)), player("Home", "CB", Vector3.new(160, 3, 190)), player("Home", "CB", Vector3.new(264, 3, 190)), player("Home", "Fullback", Vector3.new(80, 3, 205))}
		local carrierWorld = PitchConfig.TeamPitchPositionToWorld(Vector3.new(212, 3, 245), "Home", options)
		local carrier = player("Away", "CM", PitchConfig.WorldToTeamPitchPosition(carrierWorld, "Away", options))
		carrier.World = carrierWorld
		carrier.Root.Position = carrierWorld
		local context = {Now = 1, Owner = carrier.Model, OwnerSide = "Away", BallWorld = carrier.World, BallTeam = {Home = Vector3.new(212, 3, 245), Away = carrier.Pitch}, Teams = {Home = {List = home}, Away = {List = {carrier}}}, Players = {[carrier.Model] = carrier}, Options = options}
		for _, info in ipairs(home) do context.Players[info.Model] = info end
		local block = AIDefensiveBlockPlanner.new():Build(context, "Home", {Ratio = function(_, key: string) if key == "DefensiveDepth" then return .55 elseif key == "PressingIntensity" then return .72 end return .55 end}, {Intent = "MidBlock"})
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", block.Slots)
		AIDefensivePlan.Apply(context, "Home", assignments, {Intent = "MidBlock"}, block, {})
		local roles = {}
		for _, assignment in pairs(assignments) do roles[assignment.PrimaryAssignment] = (roles[assignment.PrimaryAssignment] or 0) + 1 end
		expect((roles.CarrierBreachPress or roles.ContainBallCarrier or 0) >= 1, "No midfielder or defender contained the central breach")
		expect((roles.CoverStep or 0) >= 1, "No cover step assigned behind breach contain")
		expect((roles.DeepCover or 0) == 1, "Exactly one far-side center-back was not assigned deep cover")
		expect((roles.HoldBackLineZone or 0) < 4, "Back line remained entirely passive during breach")
		for _, info in ipairs(home) do info.Model:Destroy() end
		carrier.Model:Destroy()
	end)

	test("obvious central box chance is classified before backward pass", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local shooterModel = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		local shooterPitch = Vector3.new(212, 3, 660)
		local shooterWorld = PitchConfig.TeamPitchPositionToWorld(shooterPitch, "Home", options)
		local goalWorld = PitchConfig.TeamPitchPositionToWorld(Vector3.new(212, 3, 742), "Home", options)
		root.CFrame = CFrame.lookAt(shooterWorld, goalWorld)
		root.Parent = shooterModel
		local shooter = {Model = shooterModel, Root = root, Side = "Home", OpponentSide = "Away", Role = "CAM", Pitch = shooterPitch, World = root.Position, Stats = {shooting = 76, shootingIQ = 78, longShots = 70}, Stamina = 80}
		local keeper = Instance.new("Model")
		local keeperRoot = Instance.new("Part")
		keeperRoot.Name = "HumanoidRootPart"
		keeperRoot.Position = PitchConfig.TeamPitchPositionToWorld(Vector3.new(212, 3, 712), "Home", options)
		keeperRoot.Parent = keeper
		local context = {Now = 1, PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}, Options = options, BallWorld = shooter.World, BallTeam = {Home = shooter.Pitch}, Teams = {Home = {List = {shooter}}, Away = {List = {{Model = keeper, Root = keeperRoot, Side = "Away", Role = "GK", Pitch = Vector3.new(212, 3, 30), World = keeperRoot.Position, Stats = {pace = 60}, Stamina = 80}}}}}
		local shot = AIShootingDecisionService.Evaluate(context, shooter, AITacticalStyleService.new({PresetId = "balanced_control"}), {ShotSelect = .5})
		local contract = AITacticalContract.Player({AllowedActions = AITacticalContract.Slot({Id = "between-lines-receiver", RoleFamily = "CAM", Line = "Midfield", TargetPitch = shooter.Pitch}).AllowedActions})
		expect(AITacticalContract.ActionAllowed(contract, "Shoot"), "Creator contract suppresses obvious shot")
		expect(shot.Obvious == true and shot.ClearAngle == true and shot.Good == true, "Central box chance was not classified as obvious")
		shooterModel:Destroy();keeper:Destroy()
	end)

	test("offside cluster recovers while legal timed through option remains possible", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local function player(side: string, role: string, pitch: Vector3): any
			local model = Instance.new("Model")
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = PitchConfig.TeamPitchPositionToWorld(pitch, side, options)
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = pitch, World = root.Position, Stats = {pace = 78, passQuality = 76, reception = 76}, Stamina = 80}
		end
		local passer = player("Home", "CM", Vector3.new(212, 3, 540))
		local offsideForward = player("Home", "ST", Vector3.new(212, 3, 650))
		local legalRunner = player("Home", "ST", Vector3.new(180, 3, 582))
		local defenderA = player("Away", "CB", Vector3.new(170, 3, 600))
		local defenderB = player("Away", "CB", Vector3.new(250, 3, 592))
		local context = {Now = 1, BallWorld = passer.World, BallTeam = {Home = passer.Pitch}, Teams = {Home = {List = {passer, offsideForward, legalRunner}}, Away = {List = {defenderA, defenderB}}}, Options = options}
		local style = AITacticalStyleService.new({PresetId = "vertical_combination"})
		local rejected = AIPassExecutionPlanner.Plan(context, passer, {Receiver = offsideForward, Target = offsideForward.World, PassKind = "Through"}, style, {PassRisk = .5})
		local legal = AIPassExecutionPlanner.Plan(context, passer, {Receiver = legalRunner, Target = PitchConfig.TeamPitchPositionToWorld(Vector3.new(180, 3, 620), "Home", options), PassKind = "Through"}, style, {PassRisk = .5})
		expect(rejected == nil and offsideForward.Model:GetAttribute("AIPassRejectedOffside") == true, "Offside forward was not rejected")
		expect(legal ~= nil, "Legal timed through-ball option was rejected")
		for _, item in {passer, offsideForward, legalRunner, defenderA, defenderB} do item.Model:Destroy() end
	end)

	test("opponent defensive-third possession activates collective high press", function()
		local style = {Ratio = function(_, key: string)
			if key == "PressingIntensity" then return .78 end
			if key == "PressTriggerDistance" then return .72 end
			if key == "DefensiveDepth" then return .62 end
			return .55
		end}
		local director = AITacticalIntentDirector.new()
		local context = {Now = 1, OwnerSide = "Away", Owner = Instance.new("Model"), LooseBall = false, MatchState = "Live", BallTeam = {Home = Vector3.new(212, 3, 555), Away = Vector3.new(212, 3, 187)}, DefensivePress = {Home = {}, Away = {}}}
		local intents = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(intents.Home.Intent, "HighPressBuildUp", "Defensive-third buildup did not activate high press")
		context.Owner:Destroy()
	end)

	test("collective high press distributes outlet midfield screen and depth duties", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local function info(side: string, role: string, pitch: Vector3, name: string): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = PitchConfig.TeamPitchPositionToWorld(pitch, side, options)
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = pitch, World = root.Position, Stats = {pace = 72, defending = 70}, Stamina = 82, IsGoalkeeper = role == "GK"}
		end
		local home = {
			info("Home", "ST", Vector3.new(212, 3, 500), "ST"),
			info("Home", "Winger", Vector3.new(80, 3, 480), "LW"),
			info("Home", "Winger", Vector3.new(344, 3, 478), "RW"),
			info("Home", "CAM", Vector3.new(212, 3, 456), "CAM"),
			info("Home", "CM", Vector3.new(172, 3, 425), "CM1"),
			info("Home", "CM", Vector3.new(252, 3, 418), "CM2"),
			info("Home", "CDM", Vector3.new(212, 3, 390), "DM"),
			info("Home", "CB", Vector3.new(160, 3, 325), "CB1"),
			info("Home", "CB", Vector3.new(264, 3, 325), "CB2"),
			info("Home", "Fullback", Vector3.new(70, 3, 335), "LB"),
			info("Home", "Fullback", Vector3.new(354, 3, 335), "RB"),
		}
		local awayCarrier = info("Away", "CB", Vector3.new(212, 3, 185), "AwayCB")
		local awayFB = info("Away", "Fullback", Vector3.new(78, 3, 190), "AwayFB")
		local awayDM = info("Away", "CDM", Vector3.new(212, 3, 245), "AwayDM")
		local context = {Now = 1, Owner = awayCarrier.Model, OwnerSide = "Away", BallWorld = awayCarrier.World, BallTeam = {Home = Vector3.new(212, 3, 557), Away = awayCarrier.Pitch}, Teams = {Home = {List = home}, Away = {List = {awayCarrier, awayFB, awayDM}}}, Players = {}, Options = options}
		for _, item in ipairs(home) do context.Players[item.Model] = item end
		for _, item in ipairs({awayCarrier, awayFB, awayDM}) do context.Players[item.Model] = item end
		local planner = AIDefensiveBlockPlanner.new()
		local block = planner:Build(context, "Home", {Ratio = function(_, key: string)
			if key == "PressingIntensity" then return .86 end
			if key == "DefensiveDepth" then return .78 end
			if key == "BackLineCompactness" then return .76 end
			if key == "ZoneDiscipline" then return .72 end
			return .58
		end}, {Intent = "HighPressBuildUp"})
		expect(block.ForwardLineZ > block.MidfieldLineZ and block.MidfieldLineZ > block.BackLineZ, "High-press line ordering invalid")
		expect(block.HighPressBlockDepth >= 70 and block.HighPressBlockDepth <= 130, "High-press block depth escaped collective range")
		local slots = {}
		for _, slot in ipairs(block.Slots) do slots[slot.Id] = slot end
		for _, id in ipairs({"primary-presser", "ball-side-outlet-presser", "central-outlet-presser", "ball-side-midfield-squeezer", "central-midfield-squeezer", "pivot-screen", "deep-cover-defender"}) do
			expect(slots[id] ~= nil, "Missing collective press slot " .. id)
			expect(slots[id].LockedModel ~= nil, "Collective press slot was not locked: " .. id)
		end
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", block.Slots)
		AIDefensivePlan.Apply(context, "Home", assignments, {Intent = "HighPressBuildUp"}, block, {})
		local active = 0
		local wingerPress = false
		local midfieldPress = false
		local deepCover = 0
		for model, assignment in pairs(assignments) do
			local primary = tostring(assignment.PrimaryAssignment or "")
			if primary == "PressBallCarrier" or primary == "PressOutletLane" or primary == "PressCentralOutlet" or primary == "MidfieldPressSupport" or primary == "CentralMidfieldSqueeze" or primary == "BlockFarReturn" then active += 1 end
			local role = context.Players[model] and context.Players[model].Role
			if role == "Winger" and primary == "PressOutletLane" then wingerPress = true end
			if (role == "CM" or role == "CAM") and (primary == "MidfieldPressSupport" or primary == "CentralMidfieldSqueeze" or primary == "PressCentralOutlet") then midfieldPress = true end
			if primary == "DeepCover" then deepCover += 1 end
		end
		expect(active >= 4, "High press did not create at least four active pressure responsibilities")
		expect(wingerPress, "No winger received an active outlet pressing target")
		expect(midfieldPress, "No midfielder received an active pressing target")
		expectEqual(deepCover, 1, "High press did not preserve exactly one deepest cover")
		for _, item in ipairs(home) do item.Model:Destroy() end
		for _, item in ipairs({awayCarrier, awayFB, awayDM}) do item.Model:Destroy() end
	end)

	test("approaching pressers create faster pressure bands", function()
		local carrier = Instance.new("Model")
		local carrierRoot = Instance.new("Part")
		carrierRoot.Name = "HumanoidRootPart"
		carrierRoot.Position = Vector3.new(0, 3, 0)
		carrierRoot.Parent = carrier
		local function presser(name: string, position: Vector3): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("currentAssignment", "PressBallCarrier")
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.CFrame = CFrame.lookAt(position, carrierRoot.Position)
			root.AssemblyLinearVelocity = (carrierRoot.Position - position).Unit * 12
			root.Parent = model
			return {Model = model, Root = root, Side = "Away", OpponentSide = "Home", Role = "ST", Pitch = position, World = position, Stats = {pace = 70}, Stamina = 80}
		end
		local carrierInfo = {Model = carrier, Root = carrierRoot, Side = "Home", OpponentSide = "Away", Role = "CM", Pitch = carrierRoot.Position, World = carrierRoot.Position, Stats = {pace = 70}, Stamina = 80}
		local one = presser("P1", Vector3.new(0, 3, 48))
		local two = presser("P2", Vector3.new(26, 3, 46))
		local context = {Teams = {Home = {List = {carrierInfo}}, Away = {List = {one}}}}
		local single = AIContextBuilder.Pressure(context, carrierInfo)
		context.Teams.Away.List = {one, two}
		local double = AIContextBuilder.Pressure(context, carrierInfo)
		expectEqual(single.Band, "ApproachingPressure", "Single approaching presser did not create approaching pressure")
		expect(double.ApproachingCount > single.ApproachingCount, "Second approaching presser was not counted")
		carrier:Destroy();one.Model:Destroy();two.Model:Destroy()
	end)

	test("committed pre-pass rotates defensive receiver pressure before launch", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local function info(side: string, role: string, pitch: Vector3, name: string): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = PitchConfig.TeamPitchPositionToWorld(pitch, side, options)
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = pitch, World = root.Position, Stats = {pace = 70}, Stamina = 80}
		end
		local receiver = info("Away", "Fullback", Vector3.new(84, 3, 205), "AwayFB")
		local carrier = info("Away", "CB", Vector3.new(212, 3, 182), "AwayCB")
		local winger = info("Home", "Winger", Vector3.new(70, 3, 480), "HomeW")
		local cm = info("Home", "CM", Vector3.new(180, 3, 430), "HomeCM")
		local cb = info("Home", "CB", Vector3.new(212, 3, 340), "HomeCB")
		local target = receiver.World + Vector3.new(0, 0, 8)
		receiver.Model:SetAttribute("VTRPrePassPhase", "Committed")
		receiver.Model:SetAttribute("VTRPrePassTarget", target)
		receiver.Model:SetAttribute("VTRPrePassExpiresAt", 10)
		local context = {Now = 2, Owner = carrier.Model, OwnerSide = "Away", BallWorld = carrier.World, BallTeam = {Home = Vector3.new(212, 3, 560), Away = carrier.Pitch}, Teams = {Home = {List = {winger, cm, cb}}, Away = {List = {carrier, receiver}}}, Players = {[winger.Model] = winger, [cm.Model] = cm, [cb.Model] = cb, [carrier.Model] = carrier, [receiver.Model] = receiver}, Options = options}
		local block = AIDefensiveBlockPlanner.new():Build(context, "Home", {Ratio = function() return .8 end}, {Intent = "HighPressBuildUp"})
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", block.Slots)
		AIDefensivePlan.Apply(context, "Home", assignments, {Intent = "HighPressBuildUp"}, block, {})
		local tracker = false
		for model, assignment in pairs(assignments) do
			if tostring(assignment.PrimaryAssignment or "") == "PressOutletLane" and model:GetAttribute("AIPressTrigger") == "CommittedPass" then
				tracker = true
			end
		end
		expect(tracker, "Committed pass did not rotate an outlet presser before launch")
		for _, item in {receiver, carrier, winger, cm, cb} do item.Model:Destroy() end
	end)

	test("high press compression pulls back line and keeper behind the press", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local function info(side: string, role: string, pitch: Vector3, name: string, pace: number?): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = PitchConfig.TeamPitchPositionToWorld(pitch, side, options)
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = pitch, World = root.Position, Stats = {pace = pace or 70, defending = 72}, Stamina = 84, IsGoalkeeper = role == "GK"}
		end
		local home = {
			info("Home", "GK", Vector3.new(212, 3, 24), "HGK", 64),
			info("Home", "ST", Vector3.new(212, 3, 560), "HST", 76),
			info("Home", "Winger", Vector3.new(70, 3, 535), "HLW", 78),
			info("Home", "Winger", Vector3.new(350, 3, 532), "HRW", 77),
			info("Home", "CAM", Vector3.new(212, 3, 520), "HCAM", 74),
			info("Home", "CM", Vector3.new(170, 3, 500), "HCM1", 72),
			info("Home", "CM", Vector3.new(252, 3, 496), "HCM2", 72),
			info("Home", "CDM", Vector3.new(212, 3, 470), "HDM", 70),
			info("Home", "CB", Vector3.new(152, 3, 130), "HCB1", 80),
			info("Home", "CB", Vector3.new(272, 3, 128), "HCB2", 70),
			info("Home", "Fullback", Vector3.new(72, 3, 145), "HLB", 74),
			info("Home", "Fullback", Vector3.new(352, 3, 145), "HRB", 74),
		}
		local awayCB = info("Away", "CB", Vector3.new(212, 3, 178), "ACB", 66)
		local awayGK = info("Away", "GK", Vector3.new(212, 3, 40), "AGK", 60)
		local awayST = info("Away", "ST", Vector3.new(212, 3, 430), "AST", 88)
		local context = {Now = 1, Owner = awayCB.Model, OwnerSide = "Away", BallWorld = awayCB.World, BallTeam = {Home = Vector3.new(212, 3, 564), Away = awayCB.Pitch}, Teams = {Home = {List = home}, Away = {List = {awayCB, awayGK, awayST}}}, Players = {}, Options = options, PassInFlight = false, PassTargetTeam = {Home = nil, Away = nil}}
		for _, item in ipairs(home) do context.Players[item.Model] = item end
		for _, item in ipairs({awayCB, awayGK, awayST}) do context.Players[item.Model] = item end
		local style = {Ratio = function(_, key: string)
			if key == "PressingIntensity" then return .86 end
			if key == "DefensiveDepth" then return .78 end
			if key == "BackLineCompactness" then return .82 end
			if key == "ZoneDiscipline" then return .75 end
			if key == "PressTriggerDistance" then return .78 end
			return .58
		end}
		local block = AIDefensiveBlockPlanner.new():Build(context, "Home", style, {Intent = "HighPressCompression"})
		expect(block.BackLineZ > 405, "Compressed back line did not move significantly upward")
		expect(block.MidBackGap <= 58 and block.ForwardMidGap <= 48, "Compressed line gaps exceeded maximum")
		expect(block.TeamBlockDepth <= 145, "Compressed team block depth exceeded maximum")
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", block.Slots)
		AIDefensivePlan.Apply(context, "Home", assignments, {Intent = "HighPressCompression"}, block, {})
		local highDefenders = 0
		local deepCoverZ = nil
		local otherDefenderZ = {}
		local keeperZ = nil
		for model, assignment in pairs(assignments) do
			local role = context.Players[model] and context.Players[model].Role
			if role == "CB" or role == "Fullback" then
				if assignment.PrimaryAssignment == "DeepCover" then
					deepCoverZ = assignment.TargetPitch.Z
				else
					table.insert(otherDefenderZ, assignment.TargetPitch.Z)
					if assignment.TargetPitch.Z >= 390 then highDefenders += 1 end
				end
			elseif role == "GK" then
				keeperZ = assignment.TargetPitch.Z
			end
		end
		expect(highDefenders >= 3, "At least three defenders did not move toward the halfway line")
		expect(deepCoverZ ~= nil, "No deep-cover defender assigned")
		for _, z in ipairs(otherDefenderZ) do
			expect(deepCoverZ <= z - 6, "Deep cover was not held behind the high line")
		end
		expect(keeperZ ~= nil and keeperZ > 250 and keeperZ < block.BackLineZ, "Goalkeeper did not advance as sweeper behind compressed line")
		local director = AITacticalIntentDirector.new()
		local baseIntent = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(baseIntent.Home.Intent, "HighPressCompression", "Initial buildup did not enter compression")
		context.Now = 1.3
		context.PassInFlight = true
		context.PassTargetTeam = {Home = Vector3.new(260, 3, 566), Away = Vector3.new(164, 3, 176)}
		local sideways = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(sideways.Home.Intent, "HighPressCompression", "Sideways center-back pass dropped the high line")
		context.Now = 2.8
		context.PassTargetTeam = {Home = Vector3.new(212, 3, 615), Away = Vector3.new(212, 3, 127)}
		local backward = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(backward.Home.Intent, "HighPressCompression", "Backward pass to goalkeeper did not preserve compression")
		context.Now = 4.4
		context.PassTargetTeam = {Home = Vector3.new(212, 3, 410), Away = Vector3.new(212, 3, 332)}
		local broken = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(broken.Home.Intent, "PressBroken", "Forward line-breaking pass did not trigger PressBroken")
		for _, item in ipairs(home) do item.Model:Destroy() end
		for _, item in ipairs({awayCB, awayGK, awayST}) do item.Model:Destroy() end
	end)

	test("defensive line holds edge against central carrier and only drops for real depth threat", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local box = PenaltyBoxService.DefensiveBoxMetrics("Home", options)
		local edge = box.BoxEdgeZ
		local function info(side: string, role: string, homeFramePitch: Vector3, name: string): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.CFrame = CFrame.new(PitchConfig.TeamPitchPositionToWorld(homeFramePitch, "Home", options))
			root.Parent = model
			local ownPitch = PitchConfig.WorldToTeamPitchPosition(root.Position, side, options)
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = ownPitch, World = root.Position, Stats = {pace = 72, defending = 74}, Stamina = 86, IsGoalkeeper = role == "GK"}
		end
		local home = {
			info("Home", "GK", Vector3.new(212, 3, 30), "HGK"),
			info("Home", "CB", Vector3.new(154, 3, edge + 8), "HCB1"),
			info("Home", "CB", Vector3.new(270, 3, edge + 8), "HCB2"),
			info("Home", "Fullback", Vector3.new(74, 3, edge + 12), "HLB"),
			info("Home", "Fullback", Vector3.new(350, 3, edge + 12), "HRB"),
			info("Home", "CDM", Vector3.new(212, 3, edge + 42), "HCDM"),
			info("Home", "CM", Vector3.new(172, 3, edge + 74), "HCM1"),
			info("Home", "CM", Vector3.new(252, 3, edge + 74), "HCM2"),
			info("Home", "Winger", Vector3.new(80, 3, edge + 120), "HLW"),
			info("Home", "Winger", Vector3.new(344, 3, edge + 120), "HRW"),
			info("Home", "ST", Vector3.new(212, 3, edge + 150), "HST"),
		}
		local carrier = info("Away", "CAM", Vector3.new(212, 3, edge + 62), "ACarrier")
		local outlet = info("Away", "ST", Vector3.new(244, 3, edge + 36), "AOutlet")
		local context = {Now = 10, Owner = carrier.Model, OwnerSide = "Away", BallWorld = carrier.World, BallTeam = {Home = Vector3.new(212, 3, edge + 62), Away = PitchConfig.WorldToTeamPitchPosition(carrier.World, "Away", options)}, Teams = {Home = {List = home}, Away = {List = {carrier, outlet}}}, Players = {}, Options = options, PassInFlight = false, PassTargetTeam = {Home = nil, Away = nil}}
		for _, item in ipairs(home) do context.Players[item.Model] = item end
		for _, item in ipairs({carrier, outlet}) do context.Players[item.Model] = item end
		local style = {Ratio = function(_, key: string)
			if key == "DefensiveDepth" then return .48 end
			if key == "BackLineCompactness" then return .74 end
			if key == "BoxProtection" then return .64 end
			if key == "PressingIntensity" then return .5 end
			return .55
		end}
		local planner = AIDefensiveBlockPlanner.new()
		local hold = planner:Build(context, "Home", style, {Intent = "ProtectBox"})
		expectEqual(hold.DefensiveLineState, "StepToCarrier", "Central carrier outside box did not trigger step state")
		expect(hold.BackLineZ >= edge + 8, "Back line retreated below edge anchor against carrier")
		expect(hold.BackLineMinimumZ >= edge + 4, "Minimum line height did not protect box edge")
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", hold.Slots)
		AIDefensivePlan.Apply(context, "Home", assignments, {Intent = "ProtectBox"}, hold, {})
		local stepCount = 0
		local insideCount = 0
		local farCount = 0
		local deepCount = 0
		local deepest = math.huge
		local cdmScreen = false
		for model, assignment in pairs(assignments) do
			local role = context.Players[model] and context.Players[model].Role
			if role == "CB" or role == "Fullback" or role == "CDM" then
				deepest = math.min(deepest, assignment.TargetPitch.Z)
			end
			if assignment.PrimaryAssignment == "StepToCarrier" or assignment.PrimaryAssignment == "EdgeOfBoxPress" then stepCount += 1 end
			if assignment.PrimaryAssignment == "InsideCover" then insideCount += 1 end
			if assignment.PrimaryAssignment == "FarSideCover" then farCount += 1 end
			if assignment.PrimaryAssignment == "DeepCover" or assignment.PrimaryAssignment == "RunnerTrack" then deepCount += 1 end
			if role == "CDM" and assignment.TargetPitch.Z >= edge + 4 and assignment.TargetPitch.Z <= edge + 48 then cdmScreen = true end
		end
		expect(stepCount == 1, "Exactly one defender did not step to the carrier")
		expect(insideCount >= 1, "No inside cover defender assigned")
		expect(farCount >= 1, "No far-side cover defender assigned")
		expect(deepCount <= 1, "More than one defender became deep cover")
		expect(deepest >= edge - 18, "Deepest cover collapsed too close to the six-yard area")
		expect(cdmScreen, "CDM did not protect space in front of the back line")
		context.PassInFlight = true
		context.PassTargetTeam = {Home = Vector3.new(212, 3, edge - 24), Away = PitchConfig.WorldToTeamPitchPosition(PitchConfig.TeamPitchPositionToWorld(Vector3.new(212, 3, edge - 24), "Home", options), "Away", options)}
		local emergency = planner:Build(context, "Home", style, {Intent = "PressBroken"})
		expectEqual(emergency.DefensiveLineState, "EmergencyDrop", "Through ball behind line did not trigger emergency drop")
		expect(emergency.BackLineZ < hold.BackLineZ, "Emergency line did not drop below hold line")
		local emergencyAssignments = AITacticalSlotAssignment.Assign(context, "Home", emergency.Slots)
		AIDefensivePlan.Apply(context, "Home", emergencyAssignments, {Intent = "PressBroken"}, emergency, {})
		local runnerTracked = false
		local keeperDropped = false
		for model, assignment in pairs(emergencyAssignments) do
			local role = context.Players[model] and context.Players[model].Role
			if assignment.PrimaryAssignment == "RunnerTrack" or assignment.PrimaryAssignment == "DeepCover" then runnerTracked = true end
			if role == "GK" and assignment.TargetPitch.Z < hold.BackLineZ then keeperDropped = true end
		end
		expect(runnerTracked, "Emergency drop did not assign depth tracking")
		expect(keeperDropped, "Goalkeeper did not adjust behind emergency line")
		context.Now = 11.4
		context.PassTargetTeam = {Home = Vector3.new(212, 3, edge + 92), Away = PitchConfig.WorldToTeamPitchPosition(PitchConfig.TeamPitchPositionToWorld(Vector3.new(212, 3, edge + 92), "Home", options), "Away", options)}
		local recovered = planner:Build(context, "Home", style, {Intent = "ProtectBox"})
		expect(recovered.DefensiveLineState ~= "EmergencyDrop", "Line stayed in emergency drop after threat was resolved")
		expect(recovered.BackLineZ >= edge + 4, "Recovered line did not return toward box edge")
		local low = planner:Build(context, "Home", style, {Intent = "LowBlock"})
		expectEqual(low.DefensiveLineState, "LowBlock", "Low-block tactic did not set low-block line state")
		expect(low.BackLineZ < recovered.BackLineZ, "Low block was not deeper than recovered medium block")
		expect(low.BackLineZ >= edge - 16, "Low block collapsed unnecessarily toward six-yard box")
		for _, item in ipairs(home) do item.Model:Destroy() end
		for _, item in ipairs({carrier, outlet}) do item.Model:Destroy() end
	end)

	test("opponent reset press raises whole block before receiver control", function()
		local options = {PitchCFrame = CFrame.new(), Width = PitchConfig.PITCH_WIDTH, Length = PitchConfig.PITCH_LENGTH, AttackSigns = {Home = 1, Away = -1}}
		local function info(side: string, role: string, ownPitch: Vector3, name: string, pace: number?): any
			local model = Instance.new("Model")
			model.Name = name
			model:SetAttribute("VTRTeam", side)
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Position = PitchConfig.TeamPitchPositionToWorld(ownPitch, side, options)
			root.Parent = model
			return {Model = model, Root = root, Side = side, OpponentSide = side == "Home" and "Away" or "Home", Role = role, Pitch = ownPitch, World = root.Position, Stats = {pace = pace or 72, defending = 72}, Stamina = 86, IsGoalkeeper = role == "GK"}
		end
		local home = {
			info("Home", "GK", Vector3.new(212, 3, 44), "HGK", 66),
			info("Home", "ST", Vector3.new(212, 3, 408), "HST", 78),
			info("Home", "Winger", Vector3.new(78, 3, 394), "HLW", 76),
			info("Home", "Winger", Vector3.new(348, 3, 392), "HRW", 76),
			info("Home", "CAM", Vector3.new(212, 3, 374), "HCAM", 74),
			info("Home", "CM", Vector3.new(170, 3, 326), "HCM1", 72),
			info("Home", "CM", Vector3.new(252, 3, 322), "HCM2", 72),
			info("Home", "CDM", Vector3.new(212, 3, 286), "HCDM", 72),
			info("Home", "CB", Vector3.new(154, 3, 220), "HCB1", 76),
			info("Home", "CB", Vector3.new(270, 3, 218), "HCB2", 70),
			info("Home", "Fullback", Vector3.new(76, 3, 232), "HLB", 74),
			info("Home", "Fullback", Vector3.new(350, 3, 232), "HRB", 74),
		}
		local awayCM = info("Away", "CM", Vector3.new(212, 3, 360), "AwayCM", 70)
		local awayCB1 = info("Away", "CB", Vector3.new(164, 3, 185), "AwayCB1", 68)
		local awayCB2 = info("Away", "CB", Vector3.new(260, 3, 182), "AwayCB2", 68)
		local awayGK = info("Away", "GK", Vector3.new(212, 3, 42), "AwayGK", 60)
		local awayFB = info("Away", "Fullback", Vector3.new(76, 3, 206), "AwayFB", 72)
		local awayDM = info("Away", "CDM", Vector3.new(212, 3, 245), "AwayDM", 70)
		local awayST = info("Away", "ST", Vector3.new(212, 3, 430), "AwayST", 84)
		local away = {awayCM, awayCB1, awayCB2, awayGK, awayFB, awayDM, awayST}
		local context = {Now = 30, Owner = awayCM.Model, OwnerSide = "Away", BallWorld = awayCM.World, BallTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayCM.World, "Home", options), Away = awayCM.Pitch}, Teams = {Home = {List = home}, Away = {List = away}}, Players = {}, Options = options, PassInFlight = true, PassTargetTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayCB1.World, "Home", options), Away = awayCB1.Pitch}, LooseBall = false}
		for _, item in ipairs(home) do context.Players[item.Model] = item end
		for _, item in ipairs(away) do context.Players[item.Model] = item end
		local style = {Ratio = function(_, key: string)
			if key == "PressingIntensity" then return .82 end
			if key == "DefensiveDepth" then return .72 end
			if key == "BackLineCompactness" then return .78 end
			if key == "ZoneDiscipline" then return .7 end
			if key == "PressTriggerDistance" then return .76 end
			return .58
		end}
		local director = AITacticalIntentDirector.new()
		local intents = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(intents.Home.Intent, "OpponentResetPress", "Backward pass to center-back did not trigger reset press")
		expect(context.OpponentResetPress and context.OpponentResetPress.Home and context.OpponentResetPress.Home.Active == true, "Reset press context was not exposed")
		local planner = AIDefensiveBlockPlanner.new()
		local block = planner:Build(context, "Home", style, intents.Home)
		expect(block.OpponentResetPress == true, "Defensive block did not receive reset press")
		expect(block.BackLineZ >= PitchConfig.HALF_LENGTH - 24, "Reset press back line did not rise toward halfway")
		expect(block.MidBackGap >= 38 and block.MidBackGap <= 58, "Reset press midfield-back gap escaped range")
		expect(block.ForwardMidGap >= 34 and block.ForwardMidGap <= 52, "Reset press forward-mid gap escaped range")
		expect(block.TeamBlockDepth <= 145, "Reset press block stayed too stretched")
		local assignments = AITacticalSlotAssignment.Assign(context, "Home", block.Slots)
		AIDefensivePlan.Apply(context, "Home", assignments, intents.Home, block, {})
		local active = 0
		local midfieldUp = 0
		local defendersHigh = 0
		local deepCoverZ = nil
		local otherBackZ = {}
		local keeperZ = nil
		local primaryTargetZ = nil
		for model, assignment in pairs(assignments) do
			local role = context.Players[model] and context.Players[model].Role
			local primary = tostring(assignment.PrimaryAssignment or "")
			if primary == "PressBallCarrier" then primaryTargetZ = assignment.TargetPitch.Z end
			if primary == "PressBallCarrier" or primary == "PressOutletLane" or primary == "PressCentralOutlet" or primary == "MidfieldPressSupport" or primary == "CentralMidfieldSqueeze" or primary == "BlockFarReturn" then active += 1 end
			if role == "CM" or role == "CDM" or role == "CAM" then
				if assignment.TargetPitch.Z >= PitchConfig.HALF_LENGTH + 2 then midfieldUp += 1 end
			elseif role == "CB" or role == "Fullback" then
				if primary == "DeepCover" then
					deepCoverZ = assignment.TargetPitch.Z
				else
					table.insert(otherBackZ, assignment.TargetPitch.Z)
					if assignment.TargetPitch.Z >= PitchConfig.HALF_LENGTH - 24 then defendersHigh += 1 end
				end
			elseif role == "GK" then
				keeperZ = assignment.TargetPitch.Z
			end
		end
		expect(primaryTargetZ ~= nil and primaryTargetZ >= context.PassTargetTeam.Home.Z - 14, "Primary presser did not target reset receiver before control")
		expect(active >= 3, "Reset press did not assign enough active pressure and outlet-blocking duties")
		expect(midfieldUp >= 2, "Midfield line did not move upward behind press")
		expect(defendersHigh >= 3, "At least three defenders did not rise toward halfway")
		expect(deepCoverZ ~= nil, "Reset press did not keep one deep cover")
		for _, z in ipairs(otherBackZ) do expect(deepCoverZ <= z - 6, "Deep cover was not slightly behind the raised line") end
		expect(keeperZ ~= nil and keeperZ >= block.BackLineZ - 90 and keeperZ < block.BackLineZ, "Goalkeeper did not advance behind reset high line")
		context.Now = 30.7
		context.Owner = awayCB1.Model
		context.BallWorld = awayCB1.World
		context.BallTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayCB1.World, "Home", options), Away = awayCB1.Pitch}
		context.PassTargetTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayCB2.World, "Home", options), Away = awayCB2.Pitch}
		local sidewaysIntent = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(sidewaysIntent.Home.Intent, "OpponentResetPress", "Sideways center-back pass incorrectly released reset press")
		local sideways = planner:Build(context, "Home", style, sidewaysIntent.Home)
		expect(sideways.BackLineZ >= PitchConfig.HALF_LENGTH - 24, "Line retreated after sideways center-back recycle")
		expect(math.abs(sideways.BlockCenter.X - block.BlockCenter.X) > 4, "Block did not shift sideways with reset circulation")
		context.Now = 31.4
		context.Owner = awayCB2.Model
		context.BallWorld = awayCB2.World
		context.BallTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayCB2.World, "Home", options), Away = awayCB2.Pitch}
		context.PassTargetTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayGK.World, "Home", options), Away = awayGK.Pitch}
		local keeperIntent = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(keeperIntent.Home.Intent, "OpponentResetPress", "Backward pass to goalkeeper did not preserve reset press")
		local keeperBlock = planner:Build(context, "Home", style, keeperIntent.Home)
		expect(keeperBlock.BackLineZ >= sideways.BackLineZ - 2, "Line dropped before goalkeeper received reset")
		context.Now = 32.2
		context.Owner = awayGK.Model
		context.BallWorld = awayGK.World
		context.BallTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayGK.World, "Home", options), Away = awayGK.Pitch}
		context.PassTargetTeam = {Home = Vector3.new(212, 3, PitchConfig.HALF_LENGTH - 34), Away = PitchConfig.WorldToTeamPitchPosition(PitchConfig.TeamPitchPositionToWorld(Vector3.new(212, 3, PitchConfig.HALF_LENGTH - 34), "Home", options), "Away", options)}
		local brokenIntent = director:Update(context, {Home = style, Away = style}, nil, nil)
		expectEqual(brokenIntent.Home.Intent, "PressBroken", "Long pass behind high line did not break reset press")
		local brokenBlock = planner:Build(context, "Home", style, brokenIntent.Home)
		expect(brokenBlock.DefensiveLineState == "EmergencyDrop", "Broken reset press did not coordinate recovery")
		context.Now = 34
		context.PassInFlight = false
		context.Owner = awayDM.Model
		context.BallWorld = awayDM.World
		context.BallTeam = {Home = PitchConfig.WorldToTeamPitchPosition(awayDM.World, "Home", options), Away = awayDM.Pitch}
		context.PassTargetTeam = {Home = nil, Away = nil}
		local throughIntent = director:Update(context, {Home = style, Away = style}, nil, nil)
		expect(throughIntent.Home.Intent ~= "OpponentResetPress", "Completed midfield escape kept reset press locked")
		for _, item in ipairs(home) do item.Model:Destroy() end
		for _, item in ipairs(away) do item.Model:Destroy() end
	end)

	test("client gameplay modules load", function()
		local root = StarterPlayer.StarterPlayerScripts.VTRClient
		local input = require(root.Gameplay.InputController)
		local lifecycle = require(root.Gameplay.MatchLifecycleController)
		local mobile = require(root.Components.VoltraLiteMobileControls)
		local hud = require(root.Gameplay.MatchHUDController)
		expect(type(input.new) == "function" and type(lifecycle.new) == "function" and type(mobile.new) == "function" and type(hud.new) == "function", "Client gameplay module failed to load")
	end)

	test("ten lifecycle cycles return owned resources to zero", function()
		local root = StarterPlayer.StarterPlayerScripts.VTRClient
		local Lifecycle = require(root.Gameplay.MatchLifecycleController)
		for index = 1, 10 do
			local lifecycle = Lifecycle.new("Test" .. tostring(index))
			local event = Instance.new("BindableEvent")
			local temporary = Instance.new("Folder")
			temporary.Parent = workspace
			lifecycle:TrackConnection(event.Event:Connect(function() end), "State")
			lifecycle:TrackTemporary(temporary)
			local active = lifecycle:Snapshot()
			expect(active.StateConnections == 1 and active.TemporaryInstances == 1, "Lifecycle did not register owned resources")
			local _, after = lifecycle:Destroy()
			expect(after.StateConnections == 0 and after.InputConnections == 0 and after.RenderBindings == 0 and after.ActionBindings == 0 and after.TemporaryInstances == 0 and after.Tasks == 0, "Lifecycle left resources after destroy")
			expect(temporary.Parent == nil, "Lifecycle temporary survived destroy")
			event:Destroy()
		end
	end)

	return results
end

return Tests
