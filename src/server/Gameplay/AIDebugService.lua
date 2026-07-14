--!strict
local RunService = game:GetService("RunService")
local PitchConfig = require(script.Parent.PitchConfig)
local AIContextBuilder = require(script.Parent.AIContextBuilder)

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
		part.Transparency = 0.34
		part.Parent = parent
	end
	local distance = (b - a).Magnitude
	part.Color = color
	part.Size = Vector3.new(thickness, thickness, math.max(0.1, distance))
	part.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
end

local function dot(parent: Folder, name: string, position: Vector3, color: Color3, size: number)
	local part = parent:FindFirstChild(name) :: Part?
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Parent = parent
	end
	part.Color = color
	part.Size = Vector3.new(size, size, size)
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0))
end

local function circle(parent: Folder, name: string, center: Vector3, radius: number, color: Color3, thickness: number)
	local steps = 24
	for index = 1, steps do
		local a0 = ((index - 1) / steps) * math.pi * 2
		local a1 = (index / steps) * math.pi * 2
		local a = center + Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
		local b = center + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
		segment(parent, name .. "_" .. index, a, b, color, thickness)
	end
end

local function pitchBox(parent: Folder, name: string, points: {Vector3}, color: Color3, thickness: number)
	for index = 1, #points do
		local nextIndex = index == #points and 1 or index + 1
		segment(parent, name .. "_" .. index, points[index], points[nextIndex], color, thickness)
	end
end

function Service.new()
	return setmetatable({Folder = nil, LastSummaryAt = 0}, Service)
end

function Service:_clear()
	if self.Folder then
		self.Folder:Destroy()
		self.Folder = nil
	end
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "VTRAIDebugLabel" then
			descendant:Destroy()
		end
	end
end

function Service:Update(context: any, assignmentsBySide: any)
	if not RunService:IsStudio() and game.PrivateServerId == "" then
		if self.Folder then self:_clear() end
		return
	end
	local fullDebug=workspace:GetAttribute("VTRAIDebug")==true
	local debugWidth=workspace:GetAttribute("TacticalDebugWidth")==true
	local debugDepth=workspace:GetAttribute("TacticalDebugDepth")==true
	local debugPress=workspace:GetAttribute("TacticalDebugPress")==true
	local debugPassing=workspace:GetAttribute("TacticalDebugPassing")==true
	local debugRuns=workspace:GetAttribute("TacticalDebugRuns")==true
	local debugShape=workspace:GetAttribute("TacticalDebugShape")==true
	local debugKeeper=workspace:GetAttribute("TacticalDebugKeeper")==true
	if not fullDebug and not debugWidth and not debugDepth and not debugPress and not debugPassing and not debugRuns and not debugShape and not debugKeeper then
		if self.Folder then
			self:_clear()
		end
		return
	end
	if not self.Folder then
		self.Folder = Instance.new("Folder")
		self.Folder.Name = "VTRAIDebug"
		self.Folder.Parent = workspace
	end
	self.Folder:ClearAllChildren()
	if not fullDebug then
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant.Name == "VTRAIDebugLabel" then
				descendant:Destroy()
			end
		end
	end
	local function tactic(side:string,name:string,fallback:number):number
		return math.clamp(tonumber(workspace:GetAttribute("VTRTactic_"..side.."_"..name))or fallback,0,100)
	end
	local function teamWorld(side:string,x:number,z:number):Vector3
		return PitchConfig.TeamPitchPositionToWorld(Vector3.new(x,3,z),side,context.Options)
	end
	if debugWidth then
		for _,side in ipairs({"Home","Away"})do
			local color=side=="Home"and Color3.fromHex("B7FF1A")or Color3.fromHex("7AE2FF")
			local width=tactic(side,"AttackingWidth",50)/100
			local left=45+(1-width)*55
			local right=PitchConfig.PITCH_WIDTH-left
			segment(self.Folder,side.."_WidthLeft",teamWorld(side,left,0),teamWorld(side,left,PitchConfig.PITCH_LENGTH),color,0.22)
			segment(self.Folder,side.."_WidthRight",teamWorld(side,right,0),teamWorld(side,right,PitchConfig.PITCH_LENGTH),color,0.22)
		end
	end
	if debugDepth then
		for _,side in ipairs({"Home","Away"})do
			local color=side=="Home"and Color3.fromRGB(255,220,40)or Color3.fromRGB(255,135,70)
			local depth=tactic(side,"DefensiveDepth",50)/100
			local z=85+depth*245
			segment(self.Folder,side.."_DepthLine",teamWorld(side,0,z),teamWorld(side,PitchConfig.PITCH_WIDTH,z),color,0.24)
		end
	end
	if debugPress then
		for _,side in ipairs({"Home","Away"})do
			local color=side=="Home"and Color3.fromRGB(255,90,90)or Color3.fromRGB(255,155,95)
			local radius=8+tactic(side,"PressTriggerDistance",50)*0.32
			circle(self.Folder,side.."_PressRadius",context.BallWorld+Vector3.new(0,0.9,0),radius,color,0.1)
		end
	end
	if debugKeeper then
		for _,side in ipairs({"Home","Away"})do
			local color=side=="Home"and Color3.fromRGB(80,255,180)or Color3.fromRGB(80,190,255)
			pitchBox(self.Folder,side.."_KeeperBox",{
				teamWorld(side,106,0),
				teamWorld(side,318,0),
				teamWorld(side,318,132),
				teamWorld(side,106,132),
			},color,0.16)
		end
	end
	local summary: any = {
		Home = {Pressing = 0, Supporting = 0, RunningBehind = 0, Holding = 0, Stuck = 0, Phase = ""},
		Away = {Pressing = 0, Supporting = 0, RunningBehind = 0, Holding = 0, Stuck = 0, Phase = ""},
	}
	for _, side in ipairs({"Home", "Away"}) do
		local sideColor = side == "Home" and Color3.fromHex("B7FF1A") or Color3.fromHex("7AE2FF")
		for model, assignment in pairs(assignmentsBySide[side] or {}) do
			local info = context.Players[model]
			if info and info.Root then
				local target = assignment.TargetWorld or assignment.MovementTarget or info.World
				local pressure = AIContextBuilder.Pressure(context, info)
				local action = tostring(model:GetAttribute("AIChosenAction") or "")
				local stamina = math.floor(info.Stamina or 0)
				model:SetAttribute("AIPhase", assignment.Phase or "")
				model:SetAttribute("AIAssignment", assignment.PrimaryAssignment or "RecoverShape")
				model:SetAttribute("AIPressure", pressure.Under)
				model:SetAttribute("AIDebugTargetDistance", PitchConfig.GetDistanceStuds(info.World, target))
				local assignmentName=assignment.PrimaryAssignment or"RecoverShape"
				if fullDebug or debugShape or assignmentName=="ReceivePass"and debugPassing or assignmentName=="GoalkeeperPosition"and debugKeeper then
					dot(self.Folder, "TargetDot_" .. model.Name, target, Color3.fromRGB(70, 255, 90), 1.0)
					segment(self.Folder, "TargetLine_" .. model.Name, info.World + Vector3.new(0, 0.25, 0), target, sideColor, 0.08)
				end
				if debugShape then
					dot(self.Folder,"BaseDot_"..model.Name,info.BaseWorld,Color3.fromRGB(180,180,180),0.7)
					segment(self.Folder,"ShapeHold_"..model.Name,info.World+Vector3.new(0,0.45,0),info.BaseWorld+Vector3.new(0,0.45,0),Color3.fromRGB(120,120,120),0.055)
				end
				if debugPassing and context.Owner and context.Owner==model then
					for _,teammate in ipairs(context.Teams[side].List)do
						if teammate.Model~=model and teammate.Root then
							local clear=AIContextBuilder.PassingLaneClear(context,info,teammate.World,"Ground")
							local laneColor=clear and Color3.fromRGB(65,255,115)or Color3.fromRGB(255,60,60)
							segment(self.Folder,"PassLane_"..model.Name.."_"..teammate.Model.Name,info.World+Vector3.new(0,1.7,0),teammate.World+Vector3.new(0,1.7,0),laneColor,clear and 0.08 or 0.05)
						end
					end
				end
				if (fullDebug or debugRuns) and (assignment.PrimaryAssignment == "RunBehind" or assignment.PrimaryAssignment == "CounterSprint") then
					segment(self.Folder, "Run_" .. model.Name, info.World + Vector3.new(0, 0.8, 0), target + Vector3.new(0, 0.8, 0), Color3.fromRGB(255, 220, 40), 0.14)
				elseif (fullDebug or debugRuns) and (assignment.PrimaryAssignment == "OverlapRun" or assignment.PrimaryAssignment == "UnderlapRun") then
					segment(self.Folder, "Overlap_" .. model.Name, info.World + Vector3.new(0, 1.1, 0), target + Vector3.new(0, 1.1, 0), Color3.fromRGB(190, 80, 255), 0.14)
				elseif debugRuns and (assignmentName=="ForwardSupport" or assignmentName=="ShortSupport") then
					segment(self.Folder,"SupportRun_"..model.Name,info.World+Vector3.new(0,1.0,0),target+Vector3.new(0,1.0,0),Color3.fromRGB(80,220,255),0.1)
				end
				if (fullDebug or debugPress) and (assignmentName=="PressBallCarrier"or assignmentName=="ContainBallCarrier") then
					segment(self.Folder,"Press_"..model.Name,info.World+Vector3.new(0,1.25,0),context.BallWorld+Vector3.new(0,1.25,0),Color3.fromRGB(255,80,80),0.16)
				end
				local head = model:FindFirstChild("Head") :: BasePart?
				if fullDebug and head then
					local gui = model:FindFirstChild("VTRAIDebugLabel") :: BillboardGui?
					if not gui then
						gui = Instance.new("BillboardGui")
						gui.Name = "VTRAIDebugLabel"
						gui.Size = UDim2.fromOffset(150, 52)
						gui.StudsOffsetWorldSpace = Vector3.new(0, 2.75, 0)
						gui.AlwaysOnTop = true
						gui.Adornee = head
						gui.Parent = model
						local text = Instance.new("TextLabel")
						text.Name = "Text"
						text.Size = UDim2.fromScale(1, 1)
						text.BackgroundColor3 = Color3.fromRGB(3, 3, 3)
						text.BackgroundTransparency = 0.28
						text.TextColor3 = sideColor
						text.TextSize = 7
						text.Font = Enum.Font.Code
						text.TextWrapped = true
						text.Parent = gui
					end
					gui.Size = UDim2.fromOffset(150, 52)
					gui.StudsOffsetWorldSpace = Vector3.new(0, 2.75, 0)
					local text = gui:FindFirstChild("Text") :: TextLabel?
					if text then
						text.TextSize = 7
						text.BackgroundTransparency = 0.28
						text.Text = string.format("%s %s\n%s\nD %.1f B %s P %s\n%s S%d",
							tostring(model:GetAttribute("DisplayName") or model.Name),
							info.Role,
							assignment.PrimaryAssignment or "RecoverShape",
							PitchConfig.GetDistanceStuds(info.World, target),
							tostring(info.HasBall),
							tostring(pressure.Under),
							action,
							stamina
						)
						if info.HasBall then
							text.Text ..= string.format("\nP %.1f S %.1f D %.1f -> %s",
								tonumber(model:GetAttribute("AIPassScore")) or -999,
								tonumber(model:GetAttribute("AIShotScore")) or -999,
								tonumber(model:GetAttribute("AIDribbleScore")) or -999,
								tostring(model:GetAttribute("AIPassReceiver") or "")
							)
						elseif model:GetAttribute("AIDebugExpectedPass") == true then
							text.Text ..= string.format("\nRECEIVE %.1f %s",
								tonumber(model:GetAttribute("AIDebugPassScore")) or 0,
								tostring(model:GetAttribute("AIDebugPassKind") or "")
							)
						end
					end
				end
				local sideSummary = summary[side]
				sideSummary.Phase = assignment.Phase or sideSummary.Phase
				local name = assignment.PrimaryAssignment or ""
				if name == "PressBallCarrier" then sideSummary.Pressing += 1 end
				if name == "ShortSupport" or name == "ForwardSupport" or name == "RecycleSupport" then sideSummary.Supporting += 1 end
				if name == "RunBehind" or name == "CounterSprint" then sideSummary.RunningBehind += 1 end
				if name == "HoldShape" or name == "StayBackCover" or name == "RecoverShape" then sideSummary.Holding += 1 end
				if model:GetAttribute("AIStuck") == true then sideSummary.Stuck += 1 end
			end
		end
	end
	local now = context.Now or os.clock()
	if fullDebug and now - self.LastSummaryAt >= 5 then
		self.LastSummaryAt = now
		for _, side in ipairs({"Home", "Away"}) do
			local s = summary[side]
			print(string.format("[VTR AI] %s phase=%s press=%d support=%d runs=%d hold=%d stuck=%d", side, s.Phase, s.Pressing, s.Supporting, s.RunningBehind, s.Holding, s.Stuck))
		end
	end
end

function Service:Destroy()
	self:_clear()
end

return Service
