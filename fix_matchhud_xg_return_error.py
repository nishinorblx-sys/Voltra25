from pathlib import Path
import re

path = Path("src/client/Gameplay/MatchHUDController.lua")
text = path.read_text(encoding="utf-8")

return_index = text.find("\nreturn Controller")
if return_index != -1:
    text = text[:return_index]

text = re.sub(r'\nfunction Controller:ShowShotChance\(.*?\nfunction Controller:', '\nfunction Controller:', text, count=1, flags=re.S)
text = re.sub(r'\nfunction Controller:ResolveShotChance\(.*?\nfunction Controller:', '\nfunction Controller:', text, count=1, flags=re.S)

show_shot = '''
function Controller:ShowShotChance(chance:any, actor:Model?)
	if self.ShotChancePopup then
		local oldRoot = self.ShotChancePopup.Root or self.ShotChancePopup
		if oldRoot and oldRoot.Destroy then oldRoot:Destroy() end
		self.ShotChancePopup = nil
	end
	local number = tonumber(chance) or 0
	if number > 1 then number /= 100 end
	number = math.clamp(number, 0, 1)
	local root = Instance.new("Frame")
	root.Name = "ShotChancePopup"
	root.AnchorPoint = Vector2.new(.5, 0)
	root.Position = UDim2.fromScale(.5, .12)
	root.Size = UDim2.fromOffset(260, 62)
	root.BackgroundColor3 = Theme.Colors.Black
	root.BackgroundTransparency = .08
	root.BorderSizePixel = 0
	root.ZIndex = 62
	root.Parent = self.Gui
	corner(root, 10)
	stroke(root, Theme.Colors.Electric, .18)
	local title = Instance.new("TextLabel")
	title.Name = "XGText"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 6)
	title.Size = UDim2.new(1, -32, 0, 32)
	title.Text = string.format("%.2f xG", number)
	title.TextColor3 = Theme.Colors.Electric
	title.TextSize = 25
	title.Font = Theme.Fonts.Display
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 63
	title.Parent = root
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(16, 36)
	subtitle.Size = UDim2.new(1, -32, 0, 18)
	subtitle.Text = "SHOT QUALITY"
	subtitle.TextColor3 = Theme.Colors.White
	subtitle.TextSize = 9
	subtitle.Font = Theme.Fonts.Strong
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.ZIndex = 63
	subtitle.Parent = root
	local scale = Instance.new("UIScale")
	scale.Scale = .82
	scale.Parent = root
	TweenService:Create(scale, TweenInfo.new(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	self.ShotChancePopup = {Root = root, XG = number}
	task.delay(3.2, function()
		if self.ShotChancePopup and self.ShotChancePopup.Root == root and root.Parent then
			TweenService:Create(root, TweenInfo.new(.2), {BackgroundTransparency = 1}):Play()
			for _, child in root:GetDescendants() do
				if child:IsA("TextLabel") then
					TweenService:Create(child, TweenInfo.new(.18), {TextTransparency = 1}):Play()
				elseif child:IsA("UIStroke") then
					TweenService:Create(child, TweenInfo.new(.18), {Transparency = 1}):Play()
				end
			end
			task.delay(.22, function()
				if root.Parent then root:Destroy() end
			end)
			if self.ShotChancePopup and self.ShotChancePopup.Root == root then self.ShotChancePopup = nil end
		end
	end)
end

function Controller:ResolveShotChance(scored:boolean)
	local state = self.ShotChancePopup
	if not state then return end
	self.ShotChancePopup = nil
	local root = state.Root or state
	if not root or not root.Parent then return end
	local resultColor = scored and Theme.Colors.Electric or Color3.fromHex("FF4056")
	local title = root:FindFirstChild("XGText")
	local subtitle = root:FindFirstChild("Subtitle")
	if title and title:IsA("TextLabel") then
		title.TextColor3 = resultColor
	end
	if subtitle and subtitle:IsA("TextLabel") then
		subtitle.Text = scored and "GOAL" or "NO GOAL"
		subtitle.TextColor3 = resultColor
	end
	local line = root:FindFirstChildOfClass("UIStroke")
	if line then line.Color = resultColor end
	task.delay(1.05, function()
		if not root.Parent then return end
		TweenService:Create(root, TweenInfo.new(.18), {BackgroundTransparency = 1}):Play()
		for _, child in root:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(.18), {TextTransparency = 1}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(.18), {Transparency = 1}):Play()
			end
		end
		task.delay(.2, function()
			if root.Parent then root:Destroy() end
		end)
	end)
end

'''

insert = text.find("\nfunction Controller:ShowResult")
if insert == -1:
    insert = text.find("\nfunction Controller:Destroy")

if insert != -1 and "function Controller:ShowShotChance" not in text:
    text = text[:insert] + "\n" + show_shot + text[insert:]

text = text.rstrip() + "\n\nreturn Controller\n"

path.write_text(text, encoding="utf-8", newline="\n")
print("fixed MatchHUDController xG popup placement")