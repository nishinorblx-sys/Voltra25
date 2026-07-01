from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
gk = gk_path.read_text(encoding="utf-8")

gk = re.sub(
r'''local function diveCatchFrame\(position:Vector3,lookVector:Vector3,upAxis:Vector3,fallbackForward:Vector3\):CFrame
.*?
end''',
'''local function diveCatchFrame(position:Vector3,lookVector:Vector3,upAxis:Vector3,fallbackForward:Vector3):CFrame
	local forward=fallbackForward.Magnitude>.05 and fallbackForward.Unit or Vector3.zAxis
	local aim=lookVector.Magnitude>.05 and lookVector.Unit or forward
	local lateral=aim-forward*aim:Dot(forward)-upAxis*aim:Dot(upAxis)
	if lateral.Magnitude<.05 then
		lateral=upAxis:Cross(forward)
	end
	if lateral.Magnitude<.05 then
		lateral=Vector3.xAxis
	end
	local lateralDirection=lateral.Unit
	local lift=math.abs(aim:Dot(upAxis))
	local bodyUp=(lateralDirection+upAxis*math.clamp(.08+lift*.18,.08,.26)).Unit
	local bodyLook=(forward*.74+aim*.26)
	bodyLook-=bodyUp*bodyLook:Dot(bodyUp)
	if bodyLook.Magnitude<.05 then
		bodyLook=forward-bodyUp*forward:Dot(bodyUp)
	end
	if bodyLook.Magnitude<.05 then
		bodyLook=bodyUp:Cross(upAxis)
	end
	bodyLook=bodyLook.Magnitude>.05 and bodyLook.Unit or forward
	return CFrame.lookAt(position,position+bodyLook,bodyUp)
end''',
gk,
count=1,
flags=re.S
)

gk = replace_once(
gk,
'''		local desiredFrame=diveCatchFrame(position,blend,upAxis,forward)
		save.Keeper:PivotTo(desiredFrame)''',
'''		local desiredFrame=diveCatchFrame(position,blend,upAxis,forward)
		save.Keeper:SetAttribute("VTRSidewaysDive",true)
		save.Keeper:SetAttribute("VTRDiveBodyAngle",math.floor(math.deg(math.acos(math.clamp(desiredFrame.UpVector:Dot(upAxis),-1,1)))+.5))
		save.Keeper:PivotTo(desiredFrame)''',
"sideways dive attrs"
)

gk_path.write_text(gk, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
ball,
'''		eventPayload.ScoringChance=self.LastShotChance
		eventPayload.ScoringChancePercent=self.LastShotChancePercent
		eventPayload.ShotXG=self.LastShotXG''',
'''		eventPayload.ScoringChance=self.LastShotChance
		eventPayload.ScoringChancePercent=self.LastShotChancePercent
		eventPayload.ShotXG=self.LastShotChance
		eventPayload.StatsXG=self.LastShotXG''',
"shot xg payload"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = replace_once(
gameplay,
'''elseif payload.Type=="Shot"then if self.ReplayController then self.ReplayController:MarkShot(payload.Actor)end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance(payload.ScoringChance or payload.ScoringChancePercent,payload.Actor)end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Shoot")end''',
'''elseif payload.Type=="Shot"then if self.ReplayController then self.ReplayController:MarkShot(payload.Actor)end;local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance(payload.ShotXG or payload.ScoringChance or payload.ScoringChancePercent,payload.Actor)end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Shoot")end''',
"xg popup source"
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

hud_path = Path("src/client/Gameplay/MatchHUDController.lua")
hud = hud_path.read_text(encoding="utf-8")

new_show = '''
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
	self.ShotChancePopup = {Root = root, XG = number, Resolved = false}
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

'''

new_resolve = '''
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

start = hud.find("\\nfunction Controller:ShowShotChance")
if start != -1:
	finish = hud.find("\\nfunction Controller:ResolveShotChance", start)
	if finish != -1:
		hud = hud[:start] + "\\n" + new_show + hud[finish:]

start = hud.find("\\nfunction Controller:ResolveShotChance")
if start != -1:
	finish = hud.find("\\nfunction Controller:", start + 1)
	if finish != -1:
		hud = hud[:start] + "\\n" + new_resolve + hud[finish:]
	else:
		hud = hud[:start] + "\\n" + new_resolve
else:
	insert = hud.find("\\nfunction Controller:ShowFoulBanner")
	if insert != -1:
		hud = hud[:insert] + "\\n" + new_show + new_resolve + hud[insert:]
	else:
		hud += "\\n" + new_show + new_resolve

hud_path.write_text(hud, encoding="utf-8", newline="\n")

print("patched sideways goalkeeper dives and xG shot popup")