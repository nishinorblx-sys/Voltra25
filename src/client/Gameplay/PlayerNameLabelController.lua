--!strict
local Controller = {}
Controller.__index = Controller

local function root(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function createLabel(model: Model): BillboardGui?
	local adornee = model:FindFirstChild("Head") or root(model)
	if not adornee or not adornee:IsA("BasePart") then return nil end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VTRRelevantName"
	gui.Size = UDim2.fromOffset(128, 25)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Adornee = adornee
	local text = Instance.new("TextLabel")
	text.Name = "Name"
	text.Size = UDim2.new(1, 0, 0, 18)
	text.BackgroundTransparency = 1
	text.Text = string.upper(tostring(model:GetAttribute("DisplayName") or model.Name))
	text.TextColor3 = Color3.fromHex("F4F5F1")
	text.TextStrokeColor3 = Color3.fromHex("050505")
	text.TextStrokeTransparency = 0.35
	text.Font = Enum.Font.GothamBold
	text.TextSize = 10
	text.Parent = gui
	local stamina = Instance.new("Frame")
	stamina.Name = "Stamina"
	stamina.Position = UDim2.fromOffset(24, 20)
	stamina.Size = UDim2.new(1, -48, 0, 3)
	stamina.BackgroundColor3 = Color3.fromHex("252A25")
	stamina.BorderSizePixel = 0
	stamina.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "StaminaFill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromHex("B7FF1A")
	fill.BorderSizePixel = 0
	fill.Parent = stamina
	gui.Parent = workspace.CurrentCamera
	return gui
end

function Controller.new(teams: any, mode: string?)
	local labels = {}
	for _, side in teams do
		for _, model in side do labels[model] = createLabel(model) end
	end
	return setmetatable({Teams = teams, Labels = labels, Mode = mode or "Active Only", Clock = 0, Alpha = {}}, Controller)
end

function Controller:SetActive(model: Model?) self.Active = model end
function Controller:SetBallCarrier(model: Model?) self.BallCarrier = model end
function Controller:SetPassTarget(model: Model?) self.PassTarget = model end

function Controller:_nearest(side: string, origin: Vector3, count: number, relevant: {[Model]: boolean})
	local candidates = {}
	for _, model in self.Teams[side] or {} do
		local modelRoot = root(model)
		if modelRoot and model ~= self.Active then table.insert(candidates, {Model = model, Distance = (modelRoot.Position - origin).Magnitude}) end
	end
	table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
	for index = 1, math.min(count, #candidates) do relevant[candidates[index].Model] = true end
end

function Controller:Update(dt: number)
	self.Clock += dt
	if self.Clock < 0.08 then return end
	self.Clock = 0
	local activeRoot = root(self.Active)
	local relevant: {[Model]: boolean} = {}
	if self.Mode ~= "Off" and activeRoot then
		relevant[self.Active] = true
		local side = tostring(self.Active:GetAttribute("VTRTeam") or "Home")
		self:_nearest(side == "Home" and "Away" or "Home", activeRoot.Position, 1, relevant)
	end
	for model, gui in self.Labels do
		if not gui then continue end
		local old = model:FindFirstChild("PlayerNameplate", true)
		if old and old:IsA("BillboardGui") then old.Enabled = false end
		local modelRoot = root(model)
		local distance = activeRoot and modelRoot and (modelRoot.Position - activeRoot.Position).Magnitude or math.huge
		local visible = relevant[model] == true and distance <= 60
		local targetAlpha = visible and math.clamp((distance - 35) / 25, 0, 1) or 1
		local current = self.Alpha[model] or 1
		current += (targetAlpha - current) * 0.38
		self.Alpha[model] = current
		gui.Enabled = current < 0.98
		local text = gui:FindFirstChild("Name") :: TextLabel?
		if text then text.TextTransparency = current; text.TextStrokeTransparency = 0.35 + current * 0.65 end
		local stamina = gui:FindFirstChild("Stamina") :: Frame?
		local fill = stamina and stamina:FindFirstChild("StaminaFill") :: Frame?
		if stamina then stamina.BackgroundTransparency = current end
		if fill then
			local ratio = math.clamp((tonumber(model:GetAttribute("VTRStamina")) or 100) / 100, 0, 1)
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundTransparency = current
			fill.BackgroundColor3 = ratio < 0.2 and Color3.fromHex("FF594D") or ratio < 0.4 and Color3.fromHex("FFD84A") or Color3.fromHex("B7FF1A")
		end
	end
end

function Controller:Destroy()
	for _, gui in self.Labels do if gui then gui:Destroy() end end
end

return Controller
