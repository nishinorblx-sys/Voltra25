--!strict
local Service = {}
Service.__index = Service

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatMagnitude(vector: Vector3): number
	return Vector3.new(vector.X, 0, vector.Z).Magnitude
end

local function enabled(): boolean
	return workspace:GetAttribute("VTRLinkDebug") == true or workspace:GetAttribute("VTRGameplayDebug") == true
end

local function visualsEnabled(): boolean
	return workspace:GetAttribute("VTRLinkDebugVisuals") == true
end

local function marker(parent: Folder, name: string, position: Vector3, color: Color3, size: number)
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
	part.CFrame = CFrame.new(position + Vector3.new(0, 0.55, 0))
end

local function segment(parent: Folder, name: string, a: Vector3, b: Vector3, color: Color3)
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
		part.Transparency = 0.28
		part.Parent = parent
	end
	local distance = (b - a).Magnitude
	part.Color = color
	part.Size = Vector3.new(0.16, 0.16, math.max(0.1, distance))
	part.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
end

function Service.new()
	return setmetatable({Accumulator = 0, PrintAt = 0, IssueCounts = {}, LastIssues = {}, Folder = nil}, Service)
end

function Service:_folder(): Folder
	if self.Folder and self.Folder.Parent then
		return self.Folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "VTRLinkDebug"
	folder.Parent = workspace
	self.Folder = folder
	return folder
end

function Service:_clearVisuals()
	if self.Folder then
		self.Folder:Destroy()
		self.Folder = nil
	end
end

function Service:_add(issues: {string}, code: string, message: string, subject: Instance?)
	table.insert(issues, code .. ": " .. message)
	self.IssueCounts[code] = (self.IssueCounts[code] or 0) + 1
	if subject then
		subject:SetAttribute("VTRLinkIssue", code)
		subject:SetAttribute("VTRLinkIssueText", message)
		subject:SetAttribute("VTRLinkIssueAt", os.clock())
	end
end

function Service:_clearModelIssue(model: Model)
	local issueAt = tonumber(model:GetAttribute("VTRLinkIssueAt")) or 0
	if issueAt > 0 and os.clock() - issueAt > 1.5 then
		model:SetAttribute("VTRLinkIssue", nil)
		model:SetAttribute("VTRLinkIssueText", nil)
	end
end

function Service:_passState(session: any, issues: {string})
	local ball = session.World and session.World.Ball
	if not ball then
		return
	end
	local owner = session.Possession:GetOwner()
	local motionKind = tostring(ball:GetAttribute("VTRMotionKind") or "Loose")
	local lastTouchTeam = tostring(ball:GetAttribute("LastTouchTeam") or "")
	local passStartedAt = tonumber(ball:GetAttribute("VTRPassStartedAt")) or 0
	local passTarget = ball:GetAttribute("VTRPassTarget")
	local passAge = passStartedAt > 0 and os.clock() - passStartedAt or 0
	local passInFlight = owner == nil and motionKind == "Pass" and passStartedAt > 0 and passAge < 4
	local expectedReceiver = session.BallService and session.BallService.ExpectedReceiver
	local expectedRoot = expectedReceiver and root(expectedReceiver)

	ball:SetAttribute("VTRDebugOwner", owner and owner.Name or "")
	ball:SetAttribute("VTRDebugMotionKind", motionKind)
	ball:SetAttribute("VTRDebugLastTouchTeam", lastTouchTeam)
	ball:SetAttribute("VTRDebugPassInFlight", passInFlight)
	ball:SetAttribute("VTRDebugPassAge", passAge)
	ball:SetAttribute("VTRDebugExpectedReceiver", expectedReceiver and expectedReceiver.Name or "")
	ball:SetAttribute("VTRDebugBallSpeed", flatMagnitude(ball.AssemblyLinearVelocity))

	if motionKind == "Pass" then
		if passStartedAt <= 0 then
			self:_add(issues, "PASS_NO_START", "Ball motion is Pass but VTRPassStartedAt is missing.", ball)
		end
		if lastTouchTeam ~= "Home" and lastTouchTeam ~= "Away" then
			self:_add(issues, "PASS_NO_TEAM", "Ball motion is Pass but LastTouchTeam is not Home/Away.", ball)
		end
		if typeof(passTarget) ~= "Vector3" then
			self:_add(issues, "PASS_NO_TARGET", "Ball motion is Pass but VTRPassTarget is missing.", ball)
		end
	end

	if passInFlight then
		if not expectedReceiver then
			self:_add(issues, "PASS_NO_RECEIVER", "Pass in flight has no BallService.ExpectedReceiver.", ball)
		elseif expectedReceiver:GetAttribute("VTRPreparingReceive") ~= true then
			self:_add(issues, "RECEIVER_NOT_PREPARING", expectedReceiver.Name .. " is expected receiver but VTRPreparingReceive is false.", expectedReceiver)
		elseif typeof(expectedReceiver:GetAttribute("VTRReceiveTarget")) ~= "Vector3" then
			self:_add(issues, "RECEIVER_NO_TARGET", expectedReceiver.Name .. " is preparing to receive without VTRReceiveTarget.", expectedReceiver)
		end
		if flatMagnitude(ball.AssemblyLinearVelocity) < 4 and passAge > 0.7 then
			self:_add(issues, "PASS_STALLED", "Pass is in flight but ball speed is almost stopped.", ball)
		end
	end

	if owner and owner:GetAttribute("VTRHasBall") ~= true then
		self:_add(issues, "OWNER_FLAG_MISSING", "Possession owner exists but VTRHasBall is false on owner.", owner)
	end
	local ownersWithFlag = 0
	for _, model in ipairs(session.Models or {}) do
		if model:GetAttribute("VTRHasBall") == true then
			ownersWithFlag += 1
			if model ~= owner then
				self:_add(issues, "EXTRA_HAS_BALL", model.Name .. " has VTRHasBall but is not possession owner.", model)
			end
		end
	end
	if ownersWithFlag > 1 then
		self:_add(issues, "MULTIPLE_HAS_BALL", tostring(ownersWithFlag) .. " players have VTRHasBall.", ball)
	end

	if visualsEnabled() then
		local folder = self:_folder()
		if typeof(passTarget) == "Vector3" then
			marker(folder, "PassTarget", passTarget, passInFlight and Color3.fromRGB(75, 170, 255) or Color3.fromRGB(255, 90, 70), 1.8)
			segment(folder, "BallToPassTarget", ball.Position, passTarget, passInFlight and Color3.fromRGB(75, 170, 255) or Color3.fromRGB(255, 90, 70))
		end
		if expectedRoot then
			marker(folder, "ExpectedReceiver", expectedRoot.Position, Color3.fromRGB(185, 255, 40), 1.5)
		end
	end
end

function Service:_aiState(session: any, issues: {string})
	for _, model in ipairs(session.Models or {}) do
		self:_clearModelIssue(model)
		local modelRoot = root(model)
		if not modelRoot then
			self:_add(issues, "MODEL_NO_ROOT", model.Name .. " has no HumanoidRootPart.", model)
			continue
		end
		local userControlled = model:GetAttribute("controlledByUser") == true or model:GetAttribute("VTRUserId") ~= nil
		local sentOff = model:GetAttribute("VTRSentOff") == true
		local saving = model:GetAttribute("VTRGoalkeeperSaving") == true
		local liveAI = session.Running == true and not userControlled and not sentOff and not saving
		local assignment = tostring(model:GetAttribute("currentAssignment") or model:GetAttribute("AIAssignment") or "")
		local target = model:GetAttribute("targetPosition")
		local speed = flatMagnitude(modelRoot.AssemblyLinearVelocity)
		model:SetAttribute("VTRDebugSpeed", speed)
		model:SetAttribute("VTRDebugLiveAI", liveAI)
		model:SetAttribute("VTRDebugAssignment", assignment)

		if liveAI then
			if assignment == "" or assignment == "None" then
				self:_add(issues, "AI_NO_ASSIGNMENT", model.Name .. " is live AI with no assignment.", model)
			end
			if typeof(target) ~= "Vector3" then
				self:_add(issues, "AI_NO_TARGET", model.Name .. " is live AI with no targetPosition.", model)
			end
			if model:GetAttribute("VTRForceIdle") == true then
				self:_add(issues, "AI_FORCE_IDLE_LIVE", model.Name .. " is live but VTRForceIdle is true.", model)
			end
			if model:GetAttribute("AIStuck") == true and (tonumber(model:GetAttribute("AIStuckSeconds")) or 0) > 2 then
				self:_add(issues, "AI_STUCK", model.Name .. " has been stuck for " .. string.format("%.1f", tonumber(model:GetAttribute("AIStuckSeconds")) or 0) .. "s.", model)
			end
			if typeof(target) == "Vector3" and (target - modelRoot.Position).Magnitude > 10 and speed < 0.6 and model:GetAttribute("VTRForceIdle") ~= true then
				local stoppedSince = tonumber(model:GetAttribute("VTRDebugStoppedSince")) or os.clock()
				model:SetAttribute("VTRDebugStoppedSince", stoppedSince)
				if os.clock() - stoppedSince > 1.1 then
					self:_add(issues, "AI_NOT_MOVING_TO_TARGET", model.Name .. " has a target but is barely moving.", model)
				end
			else
				model:SetAttribute("VTRDebugStoppedSince", nil)
			end
		end

		if model:GetAttribute("VTRPreparingReceive") == true and typeof(model:GetAttribute("VTRReceiveTarget")) ~= "Vector3" then
			self:_add(issues, "RECEIVE_TARGET_MISSING", model.Name .. " is preparing receive with no VTRReceiveTarget.", model)
		end
		if assignment == "ReceivePass" and model:GetAttribute("VTRPreparingReceive") ~= true then
			self:_add(issues, "RECEIVE_ASSIGNMENT_DESYNC", model.Name .. " assignment is ReceivePass but VTRPreparingReceive is false.", model)
		end
	end
end

function Service:_print(issues: {string})
	if os.clock() < self.PrintAt then
		return
	end
	self.PrintAt = os.clock() + 1.5
	local issueCount = #issues
	workspace:SetAttribute("VTRLinkIssueCount", issueCount)
	workspace:SetAttribute("VTRLinkLastIssue", issueCount > 0 and issues[1] or "")
	if issueCount == 0 then
		if workspace:GetAttribute("VTRLinkPrintClean") == true then
			print("[VTR LinkDebug] clean")
		end
		return
	end
	local capped = {}
	for index = 1, math.min(issueCount, 8) do
		capped[index] = issues[index]
	end
	print("[VTR LinkDebug] " .. tostring(issueCount) .. " issue(s): " .. table.concat(capped, " | "))
end

function Service:Step(session: any, dt: number)
	if not enabled() then
		self:_clearVisuals()
		return
	end
	self.Accumulator += dt
	if self.Accumulator < 0.25 then
		return
	end
	self.Accumulator = 0
	local issues = {}
	self:_passState(session, issues)
	self:_aiState(session, issues)
	self:_print(issues)
end

function Service:Destroy()
	self:_clearVisuals()
	table.clear(self.IssueCounts)
	table.clear(self.LastIssues)
end

return Service
