--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage.VTR.Shared
local ActionTuning = require(Shared.ActionTuningConfig)
local DeviceGameplay = require(Shared.DeviceGameplayConfig)
local Difficulty = require(Shared.DifficultyConfig)
local Gameplay = require(Shared.GameplayConfig)
local MatchExperience = require(Shared.MatchExperienceConfig)
local MatchFormat = require(Shared.MatchFormatConfig)
local Movement = require(Shared.MovementTuningConfig)
local PlayabilitySettings = require(Shared.PlayabilitySettingsConfig)
local ReceiverAssist = require(Shared.ReceiverAssistConfig)
local Stamina = require(Shared.StaminaConfig)
local DebugPolicy = require(script.Parent.Parent.Gameplay.GameplayDebugPolicy)
local MatchClock = require(script.Parent.Parent.Gameplay.MatchClockService)
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
			expect(format.SetPieceSeconds <= 5 and format.FullTimeSeconds <= 8 and format.FinalChanceSeconds <= 14, name .. " interruption budget")
		end
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
		for name, values in Difficulty do
			expect(values.Reaction >= .18, name .. " reaction below floor")
			expect(values.Positioning >= 0 and values.Positioning <= 1, name .. " positioning invalid")
			expect(values.PassAccuracy > 0 and values.ShotAccuracy > 0, name .. " accuracy invalid")
		end
	end)

	test("camera device defaults", function()
		expectEqual(DeviceGameplay.Camera.Desktop.Preset, "Tactical", "Desktop camera")
		expectEqual(DeviceGameplay.Camera.Gamepad.Preset, "Pro", "Gamepad camera")
		expectEqual(DeviceGameplay.Camera.Mobile.Preset, "Pro", "Mobile camera")
		expectEqual(DeviceGameplay.Camera.Mobile.ZoomMode, "Close", "Mobile framing")
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
		local base = {Authorized = true, IsStudio = true, IsPrivateServer = false, Ranked = false, WorldCup = false, ShootingPractice = true, RateReady = true}
		expect(DebugPolicy.CanUse("DebugCorner", base), "Authorized Studio rejected")
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

	test("profile progression schema", function()
		expectEqual(DefaultProfile.Version, 15, "Profile version")
		expectEqual(DefaultProfile.PlayabilityProgress.Version, 2, "Playability gate version")
		expect(DefaultProfile.PlayabilityProgress.CompletedMatches == 0 and DefaultProfile.PlayabilityProgress.LegacyAccessGranted == false, "Fresh profile is not fresh")
		expectEqual(DefaultProfile.Settings.ReceiverAssistMode, "Newcomer", "Fresh receiver default")
		expectEqual(DefaultProfile.Settings.PassReceiverAutoSwitch, "Newcomer", "Fresh switch default")
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
		local mobile = require(root.Components.VoltraLiteMobileControls)
		local hud = require(root.Gameplay.MatchHUDController)
		expect(type(input.new) == "function" and type(mobile.new) == "function" and type(hud.new) == "function", "Client gameplay module failed to load")
	end)

	return results
end

return Tests
