--!strict

local Lighting = game:GetService("Lighting")

local Service = {}

local function resetEffects(container: Instance)
	for _, instance in container:GetDescendants() do
		if instance:IsA("ColorCorrectionEffect") then
			local tint = instance.TintColor
			local name = string.lower(instance.Name)
			if tint.G > tint.R + .06 and tint.G > tint.B + .06 or string.find(name, "green", 1, true) or string.find(name, "setpiece", 1, true) then
				instance.Enabled = false
				instance.TintColor = Color3.new(1, 1, 1)
				instance.Saturation = 0
				instance.Contrast = 0
				instance.Brightness = 0
			end
		elseif instance:IsA("Atmosphere") then
			local tint = instance.Color
			if tint.G > tint.R + .06 and tint.G > tint.B + .06 then instance.Color = Color3.fromRGB(198, 198, 198) end
		end
	end
end

function Service.Apply(world: Instance?)
	if world then
		for _, item in world:GetDescendants() do
			if item.Name == "VTRControlledPlayerHighlight" or item.Name == "VTRControlledPlayerRing" then item:Destroy() end
		end
	end
	resetEffects(Lighting)
	if workspace.CurrentCamera then resetEffects(workspace.CurrentCamera) end
	local top = Lighting.ColorShift_Top
	local bottom = Lighting.ColorShift_Bottom
	if top.G > top.R + .08 and top.G > top.B + .08 then Lighting.ColorShift_Top = Color3.new(0, 0, 0) end
	if bottom.G > bottom.R + .08 and bottom.G > bottom.B + .08 then Lighting.ColorShift_Bottom = Color3.new(0, 0, 0) end
end

return Service
