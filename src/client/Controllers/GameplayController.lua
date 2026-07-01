--!strict
local DeviceScaleService = require(script:FindFirstAncestor("VTRClient").Services.DeviceScaleService)

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local LiteConfig = require(ReplicatedStorage.VTR.Shared.VTRLiteConfig)
local Remotes = require(ReplicatedStorage.VTR.Shared.Remotes)
local InputController = require(script.Parent.InputController)
local CameraController = require(script.Parent.CameraController)

local GameplayController = {}
GameplayController.__index = GameplayController

function GameplayController.new()
	return setmetatable({ Move = Vector3.zero, Stamina = Config.Stamina.Maximum, ServerSprinting = false, Prediction = nil, PredictionSpin = 0, SuspendPredictionUntil = 0, TacticalMode = false, TacticalPanelOpen = true, TacticalSide = "Home", RuntimeTactics = {Home = LiteConfig.DefaultTactics(), Away = LiteConfig.DefaultTactics()} }, GameplayController)
end

function GameplayController:Start()
	local player = Players.LocalPlayer
	local actionRemote, stateRemote = Remotes.Wait()
	self.Player = player
	self.ActionRemote = actionRemote
	self.StateRemote = stateRemote
	local match = workspace:WaitForChild("VTRTestMatch")
	self.Ball = match:WaitForChild(Config.Ball.Name) :: BasePart
	self.ScoreFolder = match:WaitForChild("Score")
	self:_inferPitch(match)
	local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	playerModule:GetControls():Disable()

	self.CameraController = CameraController.new()
	self.InputController = InputController.new(actionRemote, function() return self.CameraController:GetAimDirection() end)
	self.InputController.ActionCallback = function(payload)
		if payload.Type == "Pass" or payload.Type == "Shot" or payload.Type == "Skill" then
			self.SuspendPredictionUntil = os.clock() + 0.28
			self:_clearPrediction()
		end
	end
	self.InputController:Start()
	self.TacticalInput = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Six then
			self:_toggleTacticalMode()
		end
	end)
	self:_createHUD()
	local homeScore = self.ScoreFolder:WaitForChild("Home") :: IntValue
	local awayScore = self.ScoreFolder:WaitForChild("Away") :: IntValue
	local function syncScore()
		self.Score.Text = tostring(homeScore.Value) .. "  —  " .. tostring(awayScore.Value)
	end
	homeScore.Changed:Connect(syncScore)
	awayScore.Changed:Connect(syncScore)
	syncScore()
	self:_bindCharacter(player.Character or player.CharacterAdded:Wait())
	player.CharacterAdded:Connect(function(character) self:_bindCharacter(character) end)
	stateRemote.OnClientEvent:Connect(function(payload) self:_onState(payload) end)
	self.Ball:GetAttributeChangedSignal("OwnerUserId"):Connect(function() self:_updatePrediction() end)
	RunService:BindToRenderStep("VTRGameplay", Enum.RenderPriority.Camera.Value + 1, function(delta) self:_update(delta) end)
end

function GameplayController:_bindCharacter(character: Model)
	self.Character = character
	self.Humanoid = character:WaitForChild("Humanoid") :: Humanoid
	self.RootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	self.Humanoid.AutoRotate = false
	self.CameraController:Start(character)
	self:_updatePrediction()
end

function GameplayController:_inferPitch(match: Instance)
	local pitch = match:FindFirstChild("Pitch")
	if not pitch then
		for _, tagged in CollectionService:GetTagged("VTRPitch") do
			if tagged:IsA("BasePart") then
				pitch = tagged
				break
			end
		end
	end
	if pitch and pitch:IsA("BasePart") then
		local width = math.min(pitch.Size.X, pitch.Size.Z)
		local length = math.max(pitch.Size.X, pitch.Size.Z)
		self.PitchCFrame = pitch.CFrame
		self.PitchWidth = width
		self.PitchLength = length
	end
end

function GameplayController:_update(delta: number)
	if not self.Humanoid or self.Humanoid.Health <= 0 or not self.RootPart then return end
	local input = self.InputController:GetMoveVector()
	local desired = self.CameraController:GetRight() * input.X + self.CameraController:GetForward() * input.Y
	if desired.Magnitude > 1 then desired = desired.Unit end
	self.Move = self.Move:Lerp(desired, 1 - math.exp(-Config.Movement.Acceleration * delta))
	self.Humanoid:Move(self.Move, false)
	local wantsSprint = self.InputController:IsSprinting() and self.Stamina >= Config.Stamina.MinimumToSprint and input.Magnitude > 0.1
	self.Humanoid.WalkSpeed = wantsSprint and Config.Movement.SprintSpeed or Config.Movement.WalkSpeed
	if self.Move.Magnitude > 0.12 then
		local target = CFrame.lookAt(self.RootPart.Position, self.RootPart.Position + self.Move)
		self.RootPart.CFrame = self.RootPart.CFrame:Lerp(target, 1 - math.exp(-Config.Movement.TurnResponsiveness * delta))
	end
	self.CameraController:Update(delta, wantsSprint)
	self:_updateHUD()
	self:_updatePredictedBall(delta)
end

function GameplayController:_updatePrediction()
	local owns = self.Ball:GetAttribute("OwnerUserId") == self.Player.UserId and os.clock() >= self.SuspendPredictionUntil
	if owns and not self.Prediction then
		local visual = self.Ball:Clone()
		visual.Name = "PredictedBall"
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
		visual.CFrame = self.Ball.CFrame
		visual.Parent = workspace
		self.Prediction = visual
		self.Ball.LocalTransparencyModifier = 1
	elseif not owns then
		self:_clearPrediction()
	end
end

function GameplayController:_clearPrediction()
	if self.Prediction then self.Prediction:Destroy(); self.Prediction = nil end
	if self.Ball then self.Ball.LocalTransparencyModifier = 0 end
end

function GameplayController:_updatePredictedBall(delta: number)
	if os.clock() >= self.SuspendPredictionUntil and not self.Prediction then self:_updatePrediction() end
	if not self.Prediction or not self.RootPart then return end
	local direction = if self.Move.Magnitude > 0.1 then self.Move.Unit else self.CameraController:GetForward()
	local target = self.RootPart.Position + direction * Config.Ball.DribbleDistance - Vector3.new(0, Config.Ball.DribbleVerticalOffset, 0)
	self.PredictionSpin += self.Move.Magnitude * delta * 7
	local targetCFrame = CFrame.new(target) * CFrame.Angles(self.PredictionSpin, 0, self.PredictionSpin * 0.55)
	self.Prediction.CFrame = self.Prediction.CFrame:Lerp(targetCFrame, 1 - math.exp(-18 * delta))
end

function GameplayController:_onState(payload: any)
	if type(payload) ~= "table" then return end
	if payload.Type == "Stamina" and type(payload.Value) == "number" then
		self.Stamina = math.clamp(payload.Value, 0, Config.Stamina.Maximum)
		self.ServerSprinting = payload.Sprinting == true
	elseif payload.Type == "Goal" then
		self.Score.Text = tostring(payload.Home) .. "  —  " .. tostring(payload.Away)
		self.GoalBanner.Text = string.upper(payload.Team) .. " GOAL"
		self.GoalBanner.Visible = true
		task.delay(1.5, function() if self.GoalBanner then self.GoalBanner.Visible = false end end)
	elseif payload.Type == "MatchStarted" then
		self.PitchCFrame = payload.PitchCFrame
		self.PitchWidth = tonumber(payload.PitchWidth) or Config.Pitch.Width
		self.PitchLength = tonumber(payload.PitchLength) or Config.Pitch.Length
	elseif payload.Type == "AITacticsDebugApplied" and type(payload.Tactics) == "table" then
		local side = payload.Side == "Away" and "Away" or "Home"
		self.RuntimeTactics[side] = payload.Tactics
		if self.TacticalStatus then
			self.TacticalStatus.Text = side .. " APPLIED"
		end
	end
end

function GameplayController:_createHUD()
	local old = self.Player.PlayerGui:FindFirstChild("VTRGameplayHUD")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VTRGameplayHUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = self.Player.PlayerGui
	local score = Instance.new("TextLabel")
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.BackgroundColor3 = Color3.fromHex("111111")
	score.BackgroundTransparency = 0.08
	score.BorderSizePixel = 0
	score.Position = UDim2.fromScale(0.5, 0.045)
	score.Size = UDim2.fromOffset(180, 46)
	score.Text = "0  —  0"
	score.TextColor3 = Color3.fromHex("F5F7F2")
	score.TextSize = 18
	score.Font = Enum.Font.GothamBlack
	score.Parent = gui
	local scoreCorner = Instance.new("UICorner")
	scoreCorner.CornerRadius = UDim.new(0, 8)
	scoreCorner.Parent = score
	self.Score = score
	local goal = score:Clone()
	goal.Name = "GoalBanner"
	goal.Position = UDim2.fromScale(0.5, 0.13)
	goal.Size = UDim2.fromOffset(260, 54)
	goal.Text = "GOAL"
	goal.TextColor3 = Color3.fromHex("FFFFFF")
	goal.Visible = false
	goal.Parent = gui
	self.GoalBanner = goal
	local crosshair = Instance.new("Frame")
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.BackgroundColor3 = Color3.fromHex("FFFFFF")
	crosshair.BorderSizePixel = 0
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(5, 5)
	crosshair.Parent = gui
	local crossCorner = Instance.new("UICorner")
	crossCorner.CornerRadius = UDim.new(1, 0)
	crossCorner.Parent = crosshair
	local stamina = Instance.new("Frame")
	stamina.AnchorPoint = Vector2.new(0.5, 1)
	stamina.BackgroundColor3 = Color3.fromHex("242620")
	stamina.BorderSizePixel = 0
	stamina.Position = UDim2.fromScale(0.5, 0.95)
	stamina.Size = UDim2.fromOffset(250, 7)
	stamina.Parent = gui
	local staminaFill = Instance.new("Frame")
	staminaFill.BackgroundColor3 = Color3.fromHex("FFFFFF")
	staminaFill.BorderSizePixel = 0
	staminaFill.Size = UDim2.fromScale(1, 1)
	staminaFill.Parent = stamina
	self.StaminaFill = staminaFill
	local charge = stamina:Clone()
	charge.Name = "ShotCharge"
	charge.Position = UDim2.fromScale(0.5, 0.925)
	charge.Visible = false
	charge.Parent = gui
	local chargeFill = charge:FindFirstChildOfClass("Frame") :: Frame
	chargeFill.BackgroundColor3 = Color3.fromHex("F5F7F2")
	chargeFill.Size = UDim2.fromScale(0, 1)
	self.Charge = charge
	self.ChargeFill = chargeFill
	local help = Instance.new("TextLabel")
	help.AnchorPoint = Vector2.new(1, 1)
	help.BackgroundTransparency = 1
	help.Position = UDim2.fromScale(0.98, 0.97)
	help.Size = UDim2.fromOffset(430, 26)
	help.Text = "WASD MOVE  •  SHIFT SPRINT  •  LMB SHOOT  •  RMB PASS  •  ALT+RMB LOB  •  CTRL+RMB MANUAL  •  ALT+CTRL+RMB MANUAL LOB  •  Q SWITCH  •  E TACKLE  •  F SLIDE  •  R BLOCK  •  C DRIBBLE"
	help.TextColor3 = Color3.fromHex("D9D9D9")
	help.TextTransparency = 0.2
	help.TextSize = 9
	help.Font = Enum.Font.GothamBold
	help.TextXAlignment = Enum.TextXAlignment.Right
	help.Parent = gui
	self.Gui = gui
	self:_createTacticalPanel(gui)
end

function GameplayController:_createTacticalPanel(gui: ScreenGui)
	local overlay = Instance.new("Frame")
	overlay.Name = "AITacticalTuner"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 100
	overlay.Parent = gui
	self.TacticalOverlay = overlay

	local hint = Instance.new("TextLabel")
	hint.BackgroundColor3 = Color3.fromHex("0A0D08")
	hint.BackgroundTransparency = 0.12
	hint.BorderSizePixel = 0
	hint.Position = UDim2.fromOffset(18, 104)
	hint.Size = UDim2.fromOffset(390, 34)
	hint.Text = "AI TUNER CAMERA  /  PRESS 6 TO EXIT"
	hint.TextColor3 = Color3.fromHex("FFFFFF")
	hint.TextSize = 12
	hint.Font = Enum.Font.GothamBlack
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.ZIndex = 101
	hint.Parent = overlay
	local hintPad = Instance.new("UIPadding")
	hintPad.PaddingLeft = UDim.new(0, 14)
	hintPad.Parent = hint

	local toggle = Instance.new("TextButton")
	toggle.AnchorPoint = Vector2.new(1, 0)
	toggle.BackgroundColor3 = Color3.fromHex("FFFFFF")
	toggle.BorderSizePixel = 0
	toggle.Position = UDim2.new(1, -18, 0, 104)
	toggle.Size = UDim2.fromOffset(112, 34)
	toggle.Text = "HIDE PANEL"
	toggle.TextColor3 = Color3.fromHex("111111")
	toggle.TextSize = 11
	toggle.Font = Enum.Font.GothamBlack
	toggle.ZIndex = 104
	toggle.Parent = overlay
	self.TacticalToggle = toggle

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.BackgroundColor3 = Color3.fromHex("070A06")
	panel.BackgroundTransparency = 0.06
	panel.BorderSizePixel = 0
	panel.Position = UDim2.new(1, -18, 0.5, 24)
	panel.Size = UDim2.fromOffset(405, 620)
	panel.ZIndex = 102
	panel.Parent = overlay
	self.TacticalPanel = panel
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("FFFFFF")
	stroke.Thickness = 1
	stroke.Transparency = 0.25
	stroke.Parent = panel

	toggle.Activated:Connect(function()
		self.TacticalPanelOpen = not self.TacticalPanelOpen
		panel.Visible = self.TacticalPanelOpen
		toggle.Text = self.TacticalPanelOpen and "HIDE PANEL" or "SHOW PANEL"
	end)
	self:_renderTacticalPanel()
end

function GameplayController:_sendRuntimeTactics(side: string)
	self.ActionRemote:FireServer({Type = "AITacticsDebug", Side = side, Tactics = self.RuntimeTactics[side]})
end

function GameplayController:_formatRuntimeTactics(): string
	local function sideBlock(side: string): string
		local tactics = self.RuntimeTactics[side]
		local parts = {}
		for _, name in LiteConfig.TacticSliderNames do
			table.insert(parts, name .. "=" .. tostring(math.floor(tonumber(tactics.Sliders[name]) or 50)))
		end
		return side .. "={Identity=\"" .. tostring(tactics.Identity or "Balanced") .. "\",Sliders={" .. table.concat(parts, ",") .. "}}"
	end
	return "RuntimeAITactics={" .. sideBlock("Home") .. "," .. sideBlock("Away") .. "}"
end

function GameplayController:_renderTacticalPanel()
	local panel = self.TacticalPanel
	if not panel then return end
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 14)
	title.Size = UDim2.new(1, -36, 0, 28)
	title.Text = "LIVE AI BEHAVIOR"
	title.TextColor3 = Color3.fromHex("FFFFFF")
	title.TextSize = 18
	title.Font = Enum.Font.GothamBlack
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 103
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(18, 42)
	status.Size = UDim2.new(1, -36, 0, 18)
	status.Text = self.TacticalSide .. " SELECTED"
	status.TextColor3 = Color3.fromHex("FFFFFF")
	status.TextSize = 9
	status.Font = Enum.Font.GothamBold
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.ZIndex = 103
	status.Parent = panel
	self.TacticalStatus = status

	for index, side in ipairs({"Home", "Away"}) do
		local tab = Instance.new("TextButton")
		tab.BackgroundColor3 = side == self.TacticalSide and Color3.fromHex("FFFFFF") or Color3.fromHex("1B2118")
		tab.BorderSizePixel = 0
		tab.Position = UDim2.fromOffset(18 + (index - 1) * 116, 72)
		tab.Size = UDim2.fromOffset(106, 32)
		tab.Text = string.upper(side)
		tab.TextColor3 = side == self.TacticalSide and Color3.fromHex("111111") or Color3.fromHex("F5F7F2")
		tab.TextSize = 11
		tab.Font = Enum.Font.GothamBlack
		tab.ZIndex = 104
		tab.Parent = panel
		tab.Activated:Connect(function()
			self.TacticalSide = side
			self:_renderTacticalPanel()
		end)
	end

	local output = Instance.new("TextButton")
	output.BackgroundColor3 = Color3.fromHex("2A351F")
	output.BorderSizePixel = 0
	output.Position = UDim2.new(1, -148, 0, 72)
	output.Size = UDim2.fromOffset(130, 32)
	output.Text = "OUTPUT"
	output.TextColor3 = Color3.fromHex("FFFFFF")
	output.TextSize = 11
	output.Font = Enum.Font.GothamBlack
	output.ZIndex = 104
	output.Parent = panel
	output.Activated:Connect(function()
		local text = self:_formatRuntimeTactics()
		print("[VTR AI TUNER] " .. text)
		if self.TacticalOutput then
			self.TacticalOutput.Text = text
		end
		if self.TacticalStatus then self.TacticalStatus.Text = "OUTPUT PRINTED BELOW" end
	end)

	local outputBox = Instance.new("TextBox")
	outputBox.BackgroundColor3 = Color3.fromHex("10140E")
	outputBox.BackgroundTransparency = 0.1
	outputBox.BorderSizePixel = 0
	outputBox.ClearTextOnFocus = false
	outputBox.MultiLine = true
	outputBox.Position = UDim2.fromOffset(18, 112)
	outputBox.Size = UDim2.new(1, -36, 0, 54)
	outputBox.Text = "Press OUTPUT to generate current Home/Away settings."
	outputBox.TextColor3 = Color3.fromHex("D9D9D9")
	outputBox.TextSize = 8
	outputBox.Font = Enum.Font.Code
	outputBox.TextXAlignment = Enum.TextXAlignment.Left
	outputBox.TextYAlignment = Enum.TextYAlignment.Top
	outputBox.ZIndex = 104
	outputBox.Parent = panel
	self.TacticalOutput = outputBox

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(18, 180)
	list.Size = UDim2.new(1, -36, 1, -198)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Color3.fromHex("FFFFFF")
	list.ZIndex = 103
	list.Parent = panel

	local y = 0
	for _, name in LiteConfig.TacticSliderNames do
		local tactics = self.RuntimeTactics[self.TacticalSide]
		tactics.Sliders[name] = tonumber(tactics.Sliders[name]) or 50
		local value = math.floor(tactics.Sliders[name])
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, y)
		row.Size = UDim2.new(1, -4, 0, 36)
		row.ZIndex = 104
		row.Parent = list
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, 0)
		label.Size = UDim2.new(1, -116, 0, 16)
		label.Text = string.upper(name:gsub("(%u)", " %1"))
		label.TextColor3 = Color3.fromHex("E8E8E8")
		label.TextSize = 8
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 105
		label.Parent = row
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.fromHex("20251C")
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromOffset(0, 22)
		bar.Size = UDim2.new(1, -126, 0, 6)
		bar.ZIndex = 105
		bar.Parent = row
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.fromHex("FFFFFF")
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(value / 100, 1)
		fill.ZIndex = 106
		fill.Parent = bar
		local function bump(amount: number)
			tactics.Sliders[name] = math.clamp(value + amount, 0, 100)
			self:_sendRuntimeTactics(self.TacticalSide)
			self:_renderTacticalPanel()
		end
		local minus = Instance.new("TextButton")
		minus.BackgroundColor3 = Color3.fromHex("1B2118")
		minus.BorderSizePixel = 0
		minus.Position = UDim2.new(1, -118, 0, 7)
		minus.Size = UDim2.fromOffset(28, 24)
		minus.Text = "-"
		minus.TextColor3 = Color3.fromHex("FFFFFF")
		minus.TextSize = 12
		minus.Font = Enum.Font.GothamBlack
		minus.ZIndex = 106
		minus.Parent = row
		minus.Activated:Connect(function() bump(-5) end)
		local number = Instance.new("TextLabel")
		number.BackgroundTransparency = 1
		number.Position = UDim2.new(1, -86, 0, 8)
		number.Size = UDim2.fromOffset(42, 20)
		number.Text = tostring(value)
		number.TextColor3 = Color3.fromHex("FFFFFF")
		number.TextSize = 10
		number.Font = Enum.Font.GothamBlack
		number.ZIndex = 106
		number.Parent = row
		local plus = minus:Clone()
		plus.Position = UDim2.new(1, -34, 0, 7)
		plus.Text = "+"
		plus.Parent = row
		plus.Activated:Connect(function() bump(5) end)
		y += 40
	end
end

function GameplayController:_toggleTacticalMode()
	self.TacticalMode = not self.TacticalMode
	if self.TacticalOverlay then self.TacticalOverlay.Visible = self.TacticalMode end
	if self.CameraController then
		self.CameraController:SetTacticalView(self.TacticalMode, self.PitchCFrame, self.PitchWidth or Config.Pitch.Width, self.PitchLength or Config.Pitch.Length)
	end
end

function GameplayController:_updateHUD()
	self.StaminaFill.Size = UDim2.fromScale(self.Stamina / Config.Stamina.Maximum, 1)
	local charge = self.InputController:GetCharge()
	self.Charge.Visible = charge > 0
	self.ChargeFill.Size = UDim2.fromScale(charge, 1)
	self.ChargeFill.BackgroundColor3 = Color3.fromHSV(0.25 - charge * 0.18, 0.9, 1)
end

return GameplayController
