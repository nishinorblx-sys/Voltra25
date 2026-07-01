--!strict
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Service = {}
local BASE = Vector2.new(1920, 1080)

function Service.GetScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or BASE
	local topLeft = GuiService:GetGuiInset()
	local usable = Vector2.new(math.max(1, viewport.X), math.max(1, viewport.Y - topLeft.Y))
	local scale = math.min(usable.X / BASE.X, usable.Y / BASE.Y)
	return math.clamp(scale, 0.42, 1)
end

function Service.Apply(root: Instance, name: string?): UIScale
	local scaleName = name or "VTRDeviceScale"
	local scale = root:FindFirstChild(scaleName)
	if not scale or not scale:IsA("UIScale") then
		scale = Instance.new("UIScale")
		scale.Name = scaleName
		scale.Parent = root
	end
	scale.Scale = Service.GetScale()
	local camera = Workspace.CurrentCamera
	if camera and root:GetAttribute("VTRDeviceScaleBound") ~= true then
		root:SetAttribute("VTRDeviceScaleBound", true)
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if scale.Parent then
				scale.Scale = Service.GetScale()
			end
		end)
	end
	return scale
end

return Service
