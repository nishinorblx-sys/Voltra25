--!strict
local Service = {}
Service.__index = Service

local function pitchParts(): {BasePart}
	local parts = {}
	for _, instance in workspace:GetDescendants() do
		if instance.Name == "Pitch" or instance.Name == "PitchSurface" then
			if instance:IsA("BasePart") then
				table.insert(parts, instance)
			end
			for _, descendant in instance:GetDescendants() do
				if descendant:IsA("BasePart") then
					table.insert(parts, descendant)
				end
			end
		end
	end
	return parts
end

function Service.new(ball: BasePart, pitchCFrame: CFrame, models: {Model})
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: {Instance} = {ball}
	if ball.Parent and ball.Parent:IsA("Model") then table.insert(excluded, ball.Parent) end
	for _, model in models do table.insert(excluded, model) end
	params.FilterDescendantsInstances = excluded
	local pitchRaycast: RaycastParams? = nil
	local floorParts = pitchParts()
	if #floorParts > 0 then
		pitchRaycast = RaycastParams.new()
		pitchRaycast.FilterType = Enum.RaycastFilterType.Include
		pitchRaycast.FilterDescendantsInstances = floorParts
	end
	return setmetatable({Ball = ball, PitchCFrame = pitchCFrame, Raycast = params, PitchRaycast = pitchRaycast, Radius = ball.Size.X * 0.5, LastSafe = ball.CFrame}, Service)
end

function Service:Step()
	local up = self.PitchCFrame.UpVector
	local localPosition = self.PitchCFrame:PointToObjectSpace(self.Ball.Position)
	local velocity = self.Ball.AssemblyLinearVelocity
	if localPosition.Y > self.Radius - 0.05 and localPosition.Y < 14 and velocity.Magnitude < 180 then
		self.LastSafe = self.Ball.CFrame
	end
	if localPosition.Y < -6 or localPosition.Y > 140 or velocity.Magnitude > 320 then
		self.Ball.CFrame = self.LastSafe or (self.PitchCFrame * CFrame.new(0, self.Radius + 0.15, 0))
		self.Ball.AssemblyLinearVelocity = Vector3.zero
		self.Ball.AssemblyAngularVelocity = Vector3.zero
		self.Ball:SetAttribute("VTRBallRecovered", os.clock())
		return
	end
	local hit = self.PitchRaycast and workspace:Raycast(self.Ball.Position + up * 6, -up * 28, self.PitchRaycast) or nil
	if not hit then
		hit = workspace:Raycast(self.Ball.Position + up * 2, -up * 14, self.Raycast)
	end
	if hit then
		local height = (self.Ball.Position - hit.Position):Dot(up)
		if height < self.Radius - 0.18 then
			local v=self.Ball.AssemblyLinearVelocity
			local correction=self.Radius-height+0.025
			self.Ball.CFrame += up * math.max(correction,0)
			local vertical=v:Dot(up)
			local correctedVertical=vertical
			if vertical<0 then
				correctedVertical=0
			elseif vertical<3 then
				correctedVertical=0
			end
			local horizontal=v-up*vertical
			self.Ball.AssemblyLinearVelocity=horizontal+up*correctedVertical
		end
		local ownerName = tostring(self.Ball:GetAttribute("OwnerModel") or "")
		local hoverAllowance = ownerName ~= "" and 0.18 or 0.32
		local slowEnough = self.Ball.AssemblyLinearVelocity.Magnitude < (ownerName ~= "" and 12 or 4.5)
		if height > self.Radius + hoverAllowance and slowEnough then
			self.Ball.CFrame += up * math.clamp(self.Radius - height, ownerName ~= "" and -0.75 or -0.45, 0)
			local v=self.Ball.AssemblyLinearVelocity
			local vertical=v:Dot(up)
			if math.abs(vertical)<2.5 then self.Ball.AssemblyLinearVelocity=v-up*vertical end
		end
	else
		if localPosition.Y < self.Radius - 0.45 then self.Ball.CFrame += up * (self.Radius - localPosition.Y + 0.05) end
	end
end

return Service
