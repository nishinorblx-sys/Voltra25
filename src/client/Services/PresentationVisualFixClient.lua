local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

local PresentationVisualFixClient = {}

local started = false

local function lower(value)
	return string.lower(tostring(value or ""))
end

local function hideKickoffSetup()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	for _, obj in ipairs(playerGui:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
			local text = lower(obj.Text)
			local name = lower(obj.Name)
			if string.find(text, "kickoff setup") or string.find(name, "kickoffsetup") then
				obj.Visible = false
				obj.Text = ""
			end
		elseif obj:IsA("Frame") then
			local name = lower(obj.Name)
			if string.find(name, "kickoffsetup") then
				obj.Visible = false
			end
		end
	end
end

local function isNumberLabel(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then
		return false
	end
	if obj:GetAttribute("VTRKeepLineupNumberStack") == true then
		return false
	end

	local text = tostring(obj.Text or "")
	if not string.match(text, "^%s*#?%d%d?%s*$") then
		return false
	end
	local objectName = lower(obj.Name)
	if not (string.find(objectName, "kitnumber") or string.find(objectName, "jerseynumber") or string.find(objectName, "shirtnumber") or string.find(objectName, "kitwatermark")) then
		return false
	end

	local current = obj
	while current do
		local name = lower(current.Name)
		if name == "vtr25" then
			return false
		end
		if string.find(name, "overall") or string.find(name, "ovr") or string.find(name, "stat") or string.find(name, "rankedqueuepresentation") or string.find(name, "badge") then
			return false
		end
		if string.find(name, "lineup") or string.find(name, "presentation") or string.find(name, "prematch") or string.find(name, "broadcast") then
			return true
		end
		current = current.Parent
	end

	return false
end

local function fixGuiNumber(label)
	label.ZIndex = 1000
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 1, 4)
	label.Size = UDim2.new(1, 0, 0, math.max(label.AbsoluteSize.Y, 24))
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
end

local function fixBillboardNumber(gui)
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(0, -3.15, -0.85)
	gui.Size = UDim2.fromOffset(math.max(gui.AbsoluteSize.X, 90), math.max(gui.AbsoluteSize.Y, 32))
end

local function fixLineupNumbers()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _, obj in ipairs(playerGui:GetDescendants()) do
			if isNumberLabel(obj) then
				fixGuiNumber(obj)
			elseif obj:IsA("BillboardGui") then
				local name = lower(obj.Name)
				if string.find(name, "number") or string.find(name, "jersey") then
					fixBillboardNumber(obj)
				end
			end
		end
	end
end

function PresentationVisualFixClient.Step()
	hideKickoffSetup()
	fixLineupNumbers()
end

function PresentationVisualFixClient.Start()
	if started then
		return
	end

	started = true

	task.defer(PresentationVisualFixClient.Step)

	RunService.RenderStepped:Connect(function()
		PresentationVisualFixClient.Step()
	end)
end

PresentationVisualFixClient.Start()

return PresentationVisualFixClient
