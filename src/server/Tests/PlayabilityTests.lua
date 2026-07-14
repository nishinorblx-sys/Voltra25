--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.VTR.Shared
local ActionTuning = require(Shared.ActionTuningConfig)
local BallContact = require(Shared.BallContactResolver)
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
local MatchClock = require(script.Parent.Parent.Gameplay.MatchClockService)
local PassReceptionRuntime = require(script.Parent.Parent.Gameplay.PassReceptionService)
local ReplayRestartGate = require(script.Parent.Parent.Gameplay.ReplayRestartGate)
local StaminaService = require(script.Parent.Parent.Gameplay.StaminaService)
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
		expectEqual(MatchFormat.Ranked.ExtraTimeSeconds, 120, "Ranked competitive extra time")
		expect(MatchFormat.Ranked.ExtraTimeMidpointBreakSeconds >= 6 and MatchFormat.Ranked.ExtraTimeMidpointBreakSeconds <= 8, "Ranked midpoint break")
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
		expect(Gameplay.Ball.StandingTackleRange >= 4.8 and Gameplay.Ball.StandingTackleRange <= 5.8, "Standing tackle range")
		expect(Gameplay.Ball.SlideTackleRange >= 6.5 and Gameplay.Ball.SlideTackleRange <= 7.5, "Slide tackle range")
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
		expect(forward and reverse and forward.Outcome == "Loose" and reverse.Outcome == "Loose", "Contested contact became automatic possession")
		expectEqual(forward.Candidate.Key, reverse.Candidate.Key, "Contact winner depended on iteration order")
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
		local miss = Tackle.Resolve({Slide = false, StartPosition = Vector3.zero, EndPosition = Vector3.zero, BallPosition = Vector3.new(0, 0, 8), OwnerPosition = Vector3.new(0, 0, 8), Facing = Vector3.zAxis, OwnerFacing = -Vector3.zAxis, Tackle = 99, Dribbling = 1, Strength = 99, OwnerBalance = 1, Stamina = 100, Exposure = 1})
		expectEqual(miss.Outcome, "TackleMiss", "Standing miss became a successful outcome")
		local clean = Tackle.Resolve({Slide = false, StartPosition = Vector3.zero, EndPosition = Vector3.zero, BallPosition = Vector3.new(0, 0, 1), OwnerPosition = Vector3.new(0, 0, 1.4), Facing = Vector3.zAxis, OwnerFacing = Vector3.zAxis, Tackle = 99, Dribbling = 1, Strength = 99, OwnerBalance = 1, Stamina = 100, Exposure = 1})
		expectEqual(clean.Outcome, "TackleWonPossession", "Clean standing tackle did not resolve once as a win")
		local slide = Tackle.Resolve({Slide = true, StartPosition = Vector3.new(-6, 0, 0), EndPosition = Vector3.new(6, 0, 0), BallPosition = Vector3.zero, OwnerPosition = Vector3.new(0, 0, 1), Facing = -Vector3.xAxis, OwnerFacing = Vector3.zAxis, Tackle = 90, Dribbling = 20, Strength = 90, OwnerBalance = 30, Stamina = 100, Exposure = 1})
		expect(slide.Outcome ~= "TackleMiss", "Slide path ignored contact between start and end")
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
		local inputs = {0, .25, .5, .75, .89, .9, 1}
		local previousSpeed = -math.huge
		local previousOverhit = -math.huge
		for _, input in inputs do
			local speed = ShotPower.SpeedScale(input)
			local overhit = ShotPower.OverhitAmount(input)
			expect(speed >= previousSpeed and overhit >= previousOverhit, "Shot curve is not monotonic")
			previousSpeed = speed;previousOverhit = overhit
		end
		expect(not ShotPower.IsOverhit(.9) and ShotPower.IsOverhit(.9001), "Overhit threshold moved")
		expect(ShotPower.OverhitAmount(.9001) < .001, "Overhit curve jumps at threshold")
		expectEqual(ShotPower.ApplyToVelocity(Vector3.zero, .9), Vector3.zero, "Accidental lift at accurate maximum")
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
