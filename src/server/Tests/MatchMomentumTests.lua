--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Momentum = require(ReplicatedStorage.VTR.Shared.MatchMomentumService)

local Tests = {}

local function expect(condition: any, message: string)
	if not condition then error(message, 2) end
end

local function sampleAfter(service: any, seconds: number): any
	service:Step(seconds, nil, nil, 1)
	local data = service:Serialize(seconds)
	return data.Samples[#data.Samples]
end

function Tests.Run(): any
	local results = {Passed = 0, Failed = 0, Failures = {}, Names = {}}
	local function test(name: string, callback: () -> ())
		local ok, message = pcall(callback)
		table.insert(results.Names, name)
		if ok then results.Passed += 1 else results.Failed += 1 table.insert(results.Failures, name .. ": " .. tostring(message)) end
	end

	test("safe defensive possession creates low momentum", function()
		local service = Momentum.new(CFrame.new(), 76, 742)
		local owner: any = Instance.new("Folder")
		owner:SetAttribute("VTRTeam", "Home")
		service:Step(90, owner, Vector3.new(0, 0, 330), 1)
		local sample = service:Serialize(90).Samples[1]
		expect(math.abs(sample.Momentum) < 0.08, "Defensive possession should barely move momentum")
	end)

	test("final-third possession creates more momentum than midfield possession", function()
		local midfield = Momentum.new(CFrame.new(), 76, 742)
		local finalThird = Momentum.new(CFrame.new(), 76, 742)
		local owner: any = Instance.new("Folder")
		owner:SetAttribute("VTRTeam", "Home")
		midfield:Step(90, owner, Vector3.new(0, 0, -20), 1)
		finalThird:Step(90, owner, Vector3.new(0, 0, -270), 1)
		expect(finalThird:Serialize(90).Samples[1].Momentum > midfield:Serialize(90).Samples[1].Momentum, "Final third should outscore midfield")
	end)

	test("shot on target and goal create visible spikes", function()
		local shot = Momentum.new(CFrame.new(), 76, 742)
		local goal = Momentum.new(CFrame.new(), 76, 742)
		shot:AddEvent("Home", "ShotOnTarget", 10)
		goal:AddEvent("Home", "Goal", 10)
		local shotSample = sampleAfter(shot, 90)
		local goalSample = sampleAfter(goal, 90)
		expect(shotSample.Momentum > 0.15, "Shot on target should spike")
		expect(goalSample.Momentum > shotSample.Momentum, "Goal should be the strongest spike")
	end)

	test("away pressure creates negative graph values", function()
		local service = Momentum.new(CFrame.new(), 76, 742)
		service:AddEvent("Away", "ShotOnTarget", 10)
		expect(sampleAfter(service, 90).Momentum < 0, "Away pressure should be negative")
	end)

	test("recent events weigh more than older events", function()
		local service = Momentum.new(CFrame.new(), 76, 742)
		service:AddEvent("Home", "Shot", 1)
		service:AddEvent("Away", "Shot", 86)
		local sample = sampleAfter(service, 90)
		expect(sample.Momentum < 0, "Recent away event should outweigh older home event")
	end)

	test("smoothing and major events remain visible", function()
		local service = Momentum.new(CFrame.new(), 76, 742)
		service:AddEvent("Home", "BigChanceCreated", 88)
		local sample = sampleAfter(service, 90)
		expect(sample.Momentum > 0.25 and sample.Momentum < 0.9, "Big chance should be visible without maxing instantly")
	end)

	test("halftime divider and markers serialize", function()
		local service = Momentum.new(CFrame.new(), 76, 742)
		service:AddEvent("Home", "Goal", 600)
		service:AddEvent("Away", "YellowCard", 900, 0)
		local data = service:Serialize(5400)
		expect(#data.Periods >= 1, "Halftime period divider should exist")
		expect(#data.Markers == 2, "Goal and card markers should serialize")
		expect(data.Markers[1].Time == 600 and data.Markers[2].Time == 900, "Markers should keep event time")
	end)

	return results
end

return Tests
