--!strict
local RunService = game:GetService("RunService")
local Service = {}
Service.__index = Service

local function segment(parent: Folder, name: string, a: Vector3, b: Vector3, color: Color3, thickness: number)
	local part = parent:FindFirstChild(name) :: Part?
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Transparency = 0.35
		part.Parent = parent
	end
	local distance = (b - a).Magnitude
	part.Color = color
	part.Size = Vector3.new(thickness, thickness, math.max(0.1, distance))
	part.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
end

function Service.new()
	return setmetatable({Folder = nil}, Service)
end

function Service:_clear()
	if self.Folder then
		self.Folder:Destroy()
		self.Folder = nil
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant.Name == "VTRTacticalLabel" then
			descendant:Destroy()
		end
	end
end

function Service:Update(assignmentsBySide: any)
	if (not RunService:IsStudio() and game.PrivateServerId == "") or workspace:GetAttribute("TacticalDebug") ~= true then
		if self.Folder then
			self:_clear()
		end
		return
	end
	if not self.Folder then
		self.Folder = Instance.new("Folder")
		self.Folder.Name = "VTRTacticalDebug"
		self.Folder.Parent = workspace
	end
	for side, assignments in assignmentsBySide do
		local color = side == "Home" and Color3.fromHex("B7FF1A") or Color3.fromHex("FF594D")
		local defenders = {}
		for model, assignment in assignments do
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			local head = model:FindFirstChild("Head") :: BasePart?
			if root then
				segment(self.Folder, "Target_" .. model.Name, root.Position - Vector3.new(0, 2.7, 0), assignment.MovementTarget, color, 0.08)
			end
			if head then
				local gui = model:FindFirstChild("VTRTacticalLabel") :: BillboardGui?
				if not gui then
					gui = Instance.new("BillboardGui")
					gui.Name = "VTRTacticalLabel"
					gui.Size = UDim2.fromOffset(190, 54)
					gui.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
					gui.AlwaysOnTop = true
					gui.Adornee = head
					gui.Parent = model
					local text = Instance.new("TextLabel")
					text.Name = "Text"
					text.Size = UDim2.fromScale(1, 1)
					text.BackgroundColor3 = Color3.fromHex("050505")
					text.BackgroundTransparency = 0.25
					text.TextColor3 = color
					text.TextSize = 10
					text.Font = Enum.Font.Code
					text.Parent = gui
				end
				local text = gui:FindFirstChild("Text") :: TextLabel?
				if text then
					local mark = assignment.MarkTarget and assignment.MarkTarget.Name or "ZONE"
					text.Text = assignment.Role .. " / " .. assignment.Phase .. "\n" .. assignment.Zone .. " / " .. assignment.PressAssignment .. "\nMARK: " .. mark
				end
			end
			if assignment.Role == "Fullback" or assignment.Role == "CB" then
				table.insert(defenders, assignment.MovementTarget)
			end
		end
		table.sort(defenders, function(a, b)
			return a.X < b.X
		end)
		for index = 1, #defenders - 1 do
			segment(self.Folder, side .. "_DefensiveLine_" .. index, defenders[index], defenders[index + 1], color, 0.12)
		end
	end
end

function Service:Destroy()
	self:_clear()
end

return Service
