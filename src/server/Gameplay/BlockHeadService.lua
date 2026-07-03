local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BlockHeadService = {}

local fixed = {}
local started = false

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function hasHumanoid(model)
	return model and model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") ~= nil
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
			value.Value = name == "HeadScale" and 1 or 0
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
	head.Size = Vector3.new(math.max(head.Size.X, 1.6), math.max(head.Size.Y, 1), math.max(head.Size.Z, 1.6))
	head:SetAttribute("VTRBlockHeadFixed", true)
end

local function replaceMeshHead(model, head)
	local newHead = Instance.new("Part")
	newHead.Name = "Head"
	newHead.Size = Vector3.new(math.max(head.Size.X, 1.6), math.max(head.Size.Y, 1), math.max(head.Size.Z, 1.6))
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

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.35)
			fixed[character] = nil
			BlockHeadService.FixCharacter(character)
		end)
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
end

BlockHeadService.Start()

return BlockHeadService
