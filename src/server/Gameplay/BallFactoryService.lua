--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local BallCollisionService = require(script.Parent.BallCollisionService)

local Service = {}

local function configureRoot(root: BasePart, cframe: CFrame)
	root.Name = Config.Ball.Name
	root.CFrame = cframe
	root.Anchored = false
	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.42, 0.55, 1, 1)
	BallCollisionService.ApplyBall(root)
	root:SetNetworkOwner(nil)
end

local function fallback(parent: Instance, cframe: CFrame): BasePart
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.Ball.Radius * 2
	ball.Color = Color3.fromHex("F5F7F2")
	ball.Material = Enum.Material.SmoothPlastic
	ball.Parent = parent
	configureRoot(ball, cframe)
	return ball
end

function Service.Create(parent: Instance, cframe: CFrame): BasePart
	local template = ReplicatedStorage:FindFirstChild("BallTemplate")
	if not template then warn("[VTR BALL] ReplicatedStorage/BallTemplate is missing; using fallback sphere.");return fallback(parent, cframe) end
	if template:IsA("BasePart") then
		local root = template:Clone()
		root.Parent = parent
		configureRoot(root, cframe)
		return root
	end
	if not template:IsA("Model") then warn("[VTR BALL] BallTemplate must be a Model or BasePart; using fallback sphere.");return fallback(parent, cframe) end
	local model = template:Clone()
	model.Name = "VTRBallModel"
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then model:Destroy();warn("[VTR BALL] BallTemplate has no BasePart; using fallback sphere.");return fallback(parent, cframe) end
	model.PrimaryPart = root
	model.Parent = parent
	model:PivotTo(cframe)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then descendant:Destroy();continue end
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			if descendant ~= root then
				descendant.CanCollide = false;descendant.CanTouch = false;descendant.CanQuery = false;descendant.Massless = true
				local weld = Instance.new("WeldConstraint");weld.Name = "VTRBallWeld";weld.Part0 = root;weld.Part1 = descendant;weld.Parent = descendant
			end
		end
	end
	configureRoot(root, cframe)
	root:SetAttribute("BallTemplateModel", model.Name)
	return root
end

return Service
