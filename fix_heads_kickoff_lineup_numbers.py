from pathlib import Path
import re

root = Path.cwd()

block_path = root / "src/server/Gameplay/BlockHeadService.lua"
block_path.parent.mkdir(parents=True, exist_ok=True)

block_path.write_text(r'''
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BlockHeadService = {}

local fixed = {}
local started = false
local cachedHeadSize = nil

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function hasHumanoid(model)
	return model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function isPresentationContainer(inst)
	local current = inst

	while current do
		local name = lower(current.Name)
		if string.find(name, "presentation") or string.find(name, "prematch") or string.find(name, "lineup") or string.find(name, "broadcast") then
			return true
		end
		current = current.Parent
	end

	return false
end

local function findPresentationHeadSize()
	if cachedHeadSize then
		return cachedHeadSize
	end

	for _, rootInst in ipairs({ ReplicatedStorage, Workspace }) do
		for _, inst in ipairs(rootInst:GetDescendants()) do
			if inst.Name == "Head" and inst:IsA("Part") and isPresentationContainer(inst) then
				local s = inst.Size
				if s.X > 0.5 and s.Y > 0.5 and s.Z > 0.5 then
					cachedHeadSize = s
					return cachedHeadSize
				end
			end
		end
	end

	cachedHeadSize = Vector3.new(2, 1, 1)
	return cachedHeadSize
end

local function isMatchCharacter(model)
	if not hasHumanoid(model) then
		return false
	end

	if Players:GetPlayerFromCharacter(model) then
		return true
	end

	if model:GetAttribute("VTRPlayer") == true or model:GetAttribute("FieldPlayer") == true or model:GetAttribute("IsGoalkeeper") == true then
		return true
	end

	for _, attr in ipairs({ "Team", "TeamSide", "Role", "Position", "PlayerPosition", "SquadId" }) do
		if model:GetAttribute(attr) ~= nil then
			return true
		end
	end

	local current = model.Parent
	while current and current ~= Workspace do
		local name = lower(current.Name)
		if string.find(name, "match") or string.find(name, "field") or string.find(name, "team") or string.find(name, "squad") or string.find(name, "players") then
			return true
		end
		current = current.Parent
	end

	return false
end

local function applyBlockScales(humanoid)
	if not humanoid then
		return
	end

	for _, name in ipairs({ "HeadScale", "BodyTypeScale", "ProportionScale" }) do
		local value = humanoid:FindFirstChild(name)
		if value and value:IsA("NumberValue") then
			if name == "HeadScale" then
				value.Value = 1
			else
				value.Value = 0
			end
		end
	end
end

local function moveHeadChildren(oldHead, newHead)
	for _, child in ipairs(oldHead:GetChildren()) do
		if child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance") or child:IsA("WrapTarget") or child:IsA("WrapLayer") then
			child:Destroy()
		else
			pcall(function()
				child.Parent = newHead
			end)
		end
	end
end

local function replacePartReferences(model, oldHead, newHead)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("JointInstance") then
			if obj.Part0 == oldHead then
				obj.Part0 = newHead
			end
			if obj.Part1 == oldHead then
				obj.Part1 = newHead
			end
		elseif obj:IsA("WeldConstraint") then
			if obj.Part0 == oldHead then
				obj.Part0 = newHead
			end
			if obj.Part1 == oldHead then
				obj.Part1 = newHead
			end
		end
	end
end

local function squarePartHead(head)
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance") or child:IsA("WrapTarget") or child:IsA("WrapLayer") then
			child:Destroy()
		end
	end

	head.Shape = Enum.PartType.Block
	head.Size = findPresentationHeadSize()
	head:SetAttribute("VTRBlockHeadFixed", true)
end

local function replaceMeshHead(model, head)
	local newHead = Instance.new("Part")
	newHead.Name = "Head"
	newHead.Size = findPresentationHeadSize()
	newHead.CFrame = head.CFrame
	newHead.Color = head.Color
	newHead.Material = head.Material
	newHead.Transparency = head.Transparency
	newHead.Reflectance = head.Reflectance
	newHead.Anchored = head.Anchored
	newHead.CanCollide = head.CanCollide
	newHead.CanTouch = head.CanTouch
	newHead.CanQuery = head.CanQuery
	newHead.Massless = head.Massless
	newHead.CastShadow = head.CastShadow
	newHead.TopSurface = Enum.SurfaceType.Smooth
	newHead.BottomSurface = Enum.SurfaceType.Smooth
	newHead:SetAttribute("VTRBlockHeadFixed", true)

	head.Name = "VTROriginalHead"
	head.Transparency = 1
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false

	newHead.Parent = model
	moveHeadChildren(head, newHead)
	replacePartReferences(model, head, newHead)

	task.defer(function()
		if head.Parent then
			head:Destroy()
		end
	end)
end

function BlockHeadService.FixCharacter(model)
	if fixed[model] then
		return
	end

	if not isMatchCharacter(model) then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")

	if not humanoid or not head or not head:IsA("BasePart") then
		return
	end

	fixed[model] = true
	applyBlockScales(humanoid)

	if head:IsA("MeshPart") then
		replaceMeshHead(model, head)
	else
		squarePartHead(head)
	end
end

function BlockHeadService.Scan()
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") then
			BlockHeadService.FixCharacter(inst)
		end
	end
end

function BlockHeadService.Start()
	if started then
		return
	end

	started = true
	BlockHeadService.Scan()

	Workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("Model") then
			task.defer(function()
				BlockHeadService.FixCharacter(inst)
			end)
		elseif inst.Name == "Head" and inst:IsA("BasePart") then
			task.defer(function()
				local model = inst:FindFirstAncestorOfClass("Model")
				if model then
					fixed[model] = nil
					BlockHeadService.FixCharacter(model)
				end
			end)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.defer(function()
				BlockHeadService.FixCharacter(player.Character)
			end)
		end

		player.CharacterAdded:Connect(function(character)
			task.wait(0.35)
			fixed[character] = nil
			BlockHeadService.FixCharacter(character)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.35)
			fixed[character] = nil
			BlockHeadService.FixCharacter(character)
		end)
	end)
end

BlockHeadService.Start()

return BlockHeadService
'''.strip() + "\n", encoding="utf-8")

runner = root / "src/server/BlockHead.server.lua"
runner.write_text('require(script.Parent.Gameplay.BlockHeadService)\n', encoding="utf-8")

client_service = root / "src/client/Services/PresentationVisualFixClient.lua"
client_service.parent.mkdir(parents=True, exist_ok=True)

client_service.write_text(r'''
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local PresentationVisualFixClient = {}

local started = false

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function hideKickoffSetup()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			local text = lower(obj.Text)
			local name = lower(obj.Name)
			if string.find(text, "kickoff setup") or string.find(name, "kickoffsetup") then
				obj.Visible = false
				obj.Text = ""
			end
		elseif obj:IsA("Frame") then
			local name = lower(obj.Name)
			if string.find(name, "kickoffsetup") then
				obj.Visible = false
			end
		end
	end
end

local function isNumberLabel(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
		return false
	end

	local text = tostring(obj.Text or "")
	if not string.match(text, "^%s*#?%d%d?%s*$") then
		return false
	end

	local current = obj
	while current do
		local name = lower(current.Name)
		if string.find(name, "lineup") or string.find(name, "presentation") or string.find(name, "prematch") or string.find(name, "broadcast") or string.find(name, "player") then
			return true
		end
		current = current.Parent
	end

	return false
end

local function fixGuiNumber(label)
	label.ZIndex = 1000
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 4)
	label.Size = UDim2.new(1, 0, 0, math.max(label.AbsoluteSize.Y, 24))
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function fixBillboardNumber(gui)
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(0, -3.15, -0.85)
	gui.Size = UDim2.fromOffset(math.max(gui.AbsoluteSize.X, 90), math.max(gui.AbsoluteSize.Y, 32))
end

local function fixLineupNumbers()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, obj in ipairs(playerGui:GetDescendants()) do
			if isNumberLabel(obj) then
				fixGuiNumber(obj)
			elseif obj:IsA("BillboardGui") then
				local name = lower(obj.Name)
				if string.find(name, "number") or string.find(name, "jersey") then
					fixBillboardNumber(obj)
				end
			end
		end
	end
end

function PresentationVisualFixClient.Step()
	hideKickoffSetup()
	fixLineupNumbers()
end

function PresentationVisualFixClient.Start()
	if started then
		return
	end

	started = true

	task.defer(PresentationVisualFixClient.Step)

	RunService.RenderStepped:Connect(function()
		PresentationVisualFixClient.Step()
	end)
end

PresentationVisualFixClient.Start()

return PresentationVisualFixClient
'''.strip() + "\n", encoding="utf-8")

client_runner = root / "src/client/PresentationVisualFix.client.lua"
client_runner.write_text('require(script.Parent.Services.PresentationVisualFixClient)\n', encoding="utf-8")

for path in (root / "src/client").rglob("*.lua"):
	text = path.read_text(encoding="utf-8", errors="ignore")
	original = text
	text = text.replace('"KICKOFF SETUP"', '""')
	text = text.replace("'KICKOFF SETUP'", "''")
	text = text.replace("KICKOFF SETUP", "")
	if text != original:
		path.write_text(text.strip() + "\n", encoding="utf-8")
		print("patched", path.relative_to(root).as_posix())

print("patched src/server/Gameplay/BlockHeadService.lua")
print("patched src/client/Services/PresentationVisualFixClient.lua")
print("patched src/client/PresentationVisualFix.client.lua")