from pathlib import Path

root = Path.cwd()

service = root / "src/server/Services/HeadShapeService.lua"
service.parent.mkdir(parents=True, exist_ok=True)
service.write_text(r'''
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HeadShapeService = {}

local processed = setmetatable({}, { __mode = "k" })

local function isCharacter(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if not model:FindFirstChildOfClass("Humanoid") then
		return false
	end

	return model:FindFirstChild("Head") ~= nil
end

local function cleanHeadDecor(head)
	for _, child in ipairs(head:GetChildren()) do
		if child:IsA("SpecialMesh")
			or child:IsA("BlockMesh")
			or child:IsA("CylinderMesh")
			or child:IsA("FileMesh")
			or child:IsA("SurfaceAppearance")
			or child:IsA("WrapLayer")
			or child:IsA("WrapTarget")
			or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
end

local function copyChildren(fromHead, toHead)
	for _, child in ipairs(fromHead:GetChildren()) do
		if child:IsA("Attachment") or child:IsA("Decal") or child:IsA("Texture") then
			child:Clone().Parent = toHead
		end
	end
end

local function replaceMeshHead(character, oldHead)
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return oldHead
	end

	local newHead = Instance.new("Part")
	newHead.Name = "Head"
	newHead.Size = Vector3.new(2, 1, 1)
	newHead.CFrame = oldHead.CFrame
	newHead.Color = oldHead.Color
	newHead.Material = oldHead.Material
	newHead.Transparency = oldHead.Transparency
	newHead.Reflectance = oldHead.Reflectance
	newHead.CanCollide = false
	newHead.CanTouch = oldHead.CanTouch
	newHead.CanQuery = oldHead.CanQuery
	newHead.Massless = oldHead.Massless
	newHead.Parent = character

	copyChildren(oldHead, newHead)

	local oldNeck = oldHead:FindFirstChild("Neck") or torso:FindFirstChild("Neck")
	local neck = oldNeck and oldNeck:Clone() or Instance.new("Motor6D")
	neck.Name = "Neck"
	neck.Part0 = torso
	neck.Part1 = newHead
	neck.Parent = torso

	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle then
				local attachment = handle:FindFirstChildWhichIsA("Attachment")
				if attachment and newHead:FindFirstChild(attachment.Name) then
					handle.CFrame = newHead.CFrame * newHead[attachment.Name].CFrame * attachment.CFrame:Inverse()
				end
			end
		end
	end

	oldHead.Name = "OldNonSquareHead"
	oldHead:Destroy()

	if root then
		character.PrimaryPart = root
	end

	return newHead
end

local function applyDescription(humanoid)
	local description
	local ok = pcall(function()
		description = humanoid:GetAppliedDescription()
	end)

	if not ok or not description then
		return
	end

	description.Head = 0
	description.HeadScale = 1
	description.BodyTypeScale = 0
	description.ProportionScale = 0

	pcall(function()
		humanoid:ApplyDescription(description)
	end)
end

function HeadShapeService.Normalize(character)
	if not isCharacter(character) then
		return
	end

	if processed[character] then
		return
	end

	processed[character] = true

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		applyDescription(humanoid)
	end

	task.defer(function()
		if not character.Parent then
			return
		end

		local head = character:FindFirstChild("Head")
		if not head then
			return
		end

		if head:IsA("MeshPart") then
			head = replaceMeshHead(character, head)
		end

		if head and head:IsA("Part") then
			head.Shape = Enum.PartType.Block
			head.Size = Vector3.new(2, 1, 1)
			head.CanCollide = false
			cleanHeadDecor(head)
		end
	end)
end

local function bindCharacter(character)
	task.wait(0.15)
	HeadShapeService.Normalize(character)

	task.delay(1, function()
		HeadShapeService.Normalize(character)
	end)
end

function HeadShapeService.Start()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(bindCharacter, player.Character)
		end

		player.CharacterAdded:Connect(bindCharacter)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(bindCharacter)
	end)

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and isCharacter(inst) then
			task.spawn(bindCharacter, inst)
		end
	end

	Workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("Model") then
			task.delay(0.25, function()
				if isCharacter(inst) then
					bindCharacter(inst)
				end
			end)
		end
	end)
end

HeadShapeService.Start()

return HeadShapeService
'''.strip() + "\n", encoding="utf-8")

runner = root / "src/server/HeadShape.server.lua"
runner.write_text('require(script.Parent.Services.HeadShapeService)\n', encoding="utf-8")

print("created src/server/Services/HeadShapeService.lua")
print("created src/server/HeadShape.server.lua")