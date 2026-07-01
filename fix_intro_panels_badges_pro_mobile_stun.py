from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

prematch_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
prematch = prematch_path.read_text(encoding="utf-8")

if 'local UserInputService = game:GetService("UserInputService")' not in prematch:
    prematch = prematch.replace(
        'local SoundService = game:GetService("SoundService")',
        'local SoundService = game:GetService("SoundService")\nlocal UserInputService = game:GetService("UserInputService")',
        1
    )

if 'local UISoundService = require(script.Parent.Parent.Services.UISoundService)' not in prematch:
    prematch = prematch.replace(
        'local PlayerPortraitService = require(script.Parent.Parent.Services.PlayerPortraitService)',
        'local PlayerPortraitService = require(script.Parent.Parent.Services.PlayerPortraitService)\nlocal UISoundService = require(script.Parent.Parent.Services.UISoundService)\nlocal Remotes = require(ReplicatedStorage.VTR.Shared.Remotes)',
        1
    )

prematch = replace_once(
prematch,
'''local function slideIn(item: GuiObject, pos: UDim2, from: UDim2, duration: number?)
	item.Position = from
	item.Visible = true''',
'''local function slideIn(item: GuiObject, pos: UDim2, from: UDim2, duration: number?)
	UISoundService.PlayTransition()
	item.Position = from
	item.Visible = true''',
"panel transition sound"
)

prematch = replace_once(
prematch,
'''			task.delay((order - 1) * 0.08, function()
				if not slot.Parent then return end''',
'''			task.delay((order - 1) * 0.08, function()
				if not slot.Parent then return end
				UISoundService.PlayTransition()''',
"lineup player transition sound"
)

prematch = replace_once(
prematch,
'''	outline.Thickness = 1
	outline.Parent = shield
end''',
'''	outline.Thickness = 1
	outline.Parent = shield
	local logoValue = tostring(logoText or "")
	local imageId = ""
	if string.match(logoValue, "^rbxassetid://") then
		imageId = logoValue
	elseif tonumber(logoValue) then
		imageId = "rbxassetid://" .. logoValue
	end
	if imageId ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "LogoImage"
		image.BackgroundTransparency = 1
		image.Image = imageId
		image.ScaleType = Enum.ScaleType.Fit
		image.Position = UDim2.fromScale(.16, .17)
		image.Size = UDim2.fromScale(.68, .66)
		image.ZIndex = shield.ZIndex + 4
		image.Parent = shield
	else
		local mark = Instance.new("TextLabel")
		mark.Name = "LogoText"
		mark.BackgroundTransparency = 1
		mark.Text = logoValue ~= "" and string.sub(string.upper(logoValue), 1, 4) or "VTR"
		mark.TextColor3 = accent
		mark.TextSize = 22
		mark.Font = Enum.Font.GothamBlack
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.TextYAlignment = Enum.TextYAlignment.Center
		mark.Position = UDim2.fromScale(.12, .22)
		mark.Size = UDim2.fromScale(.76, .52)
		mark.ZIndex = shield.ZIndex + 4
		mark.Parent = shield
	end
end''',
"real badge logo"
)

prematch = replace_once(
prematch,
'''	root.ZIndex = 200
	root.Parent = gui''',
'''	root.ZIndex = 200
	root.Parent = gui
	if UserInputService.TouchEnabled then
		local actionRemote: RemoteEvent? = nil
		task.spawn(function()
			pcall(function()
				actionRemote = select(1, Remotes.Wait())
			end)
		end)
		local skip = Instance.new("TextButton")
		skip.Name = "MobileSkipIntro"
		skip.AnchorPoint = Vector2.new(1, 0)
		skip.Position = UDim2.new(1, -18, 0, 18)
		skip.Size = UDim2.fromOffset(128, 42)
		skip.BackgroundColor3 = Theme.Colors.Black
		skip.BackgroundTransparency = .12
		skip.BorderSizePixel = 0
		skip.AutoButtonColor = false
		skip.Text = "SKIP"
		skip.TextColor3 = Theme.Colors.White
		skip.TextSize = 14
		skip.Font = Theme.Fonts.Display
		skip.ZIndex = 260
		skip.Parent = root
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = skip
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.Electric
		stroke.Transparency = .25
		stroke.Thickness = 1.5
		stroke.Parent = skip
		skip.Activated:Connect(function()
			UISoundService.PlayTransition()
			if actionRemote then
				actionRemote:FireServer({Type = "PrematchSkip"})
			end
			skip.Text = "SKIP SENT"
		end)
	end''',
"mobile skip button"
)

prematch_path.write_text(prematch, encoding="utf-8", newline="\n")

mobile_path = Path("src/client/Components/VoltraLiteMobileControls.lua")
mobile = mobile_path.read_text(encoding="utf-8")

mobile = replace_once(
mobile,
'''	self.Gui.Parent = Players.LocalPlayer.PlayerGui''',
'''	self.Gui.Parent = Players.LocalPlayer.PlayerGui
	self.Gui.Enabled = false''',
"mobile hidden initially"
)

if "function Controls:SetVisible" not in mobile:
    mobile = mobile.replace(
'''function Controls:SetDefending(defending: boolean)''',
'''function Controls:SetVisible(visible: boolean)
	if self.Gui then
		self.Gui.Enabled = visible == true
	end
end

function Controls:SetDefending(defending: boolean)''',
1
    )

mobile_path.write_text(mobile, encoding="utf-8", newline="\n")

camera_path = Path("src/client/Gameplay/BroadcastCameraController.lua")
camera = camera_path.read_text(encoding="utf-8")

camera = re.sub(
r'''function Controller:_updatePro\(dt: number, root: BasePart\)
.*?
end

function Controller:CycleMode''',
'''function Controller:_updatePro(dt: number, root: BasePart)
	local ballOffset = Vector3.new(self.Ball.Position.X - root.Position.X, 0, self.Ball.Position.Z - root.Position.Z)
	local side = tostring(self.Active and self.Active:GetAttribute("VTRTeam") or "Home")
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local attackSign = side == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
	local attackDirection = self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, attackSign))
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local lookDirection = ballOffset.Magnitude > 2.5 and ballOffset.Unit or Vector3.new(attackDirection.X, 0, attackDirection.Z).Unit
	if lookDirection.Magnitude < .1 then
		lookDirection = facing.Magnitude > .1 and facing.Unit or self.PitchCFrame.LookVector
	end
	local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	local ballDistance = ballOffset.Magnitude
	local distance = math.clamp(31 + speed * .26 + math.clamp(ballDistance - 10, 0, 46) * .07, 30, 42)
	local height = math.clamp(12 + speed * .04, 12, 16)
	local sideOffset = self.PitchCFrame.RightVector * math.clamp(ballOffset:Dot(self.PitchCFrame.RightVector) * .035, -2.2, 2.2)
	local desired = root.Position - lookDirection * distance + Vector3.new(0, height, 0) + sideOffset
	local target = self.Ball.Position + Vector3.new(0, 2.7, 0)
	if ballDistance > 45 then
		target = target:Lerp(root.Position + lookDirection * 22 + Vector3.new(0, 4.8, 0), .24)
	end
	local alpha = 1 - math.exp(-dt / .078)
	local position = self.Camera.CFrame.Position:Lerp(desired, alpha)
	self.Camera.CFrame = CFrame.lookAt(position, target, self.PitchCFrame.UpVector)
	local fov = math.clamp(55 + speed * .04 + math.clamp(ballDistance / 34, 0, 3), 55, 60)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / .13))
end

function Controller:CycleMode''',
camera,
count=1,
flags=re.S
)

camera_path.write_text(camera, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = replace_once(
gameplay,
'''self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))''',
'''self.Camera:Start();if self.Camera.BeginStadiumIntro then self.Camera:BeginStadiumIntro(6.2)end;self.Cutscenes:StadiumIntro(data);self.InputLock:Start();self.Input:Start();if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(false)end;if self.WatchMode then self.Input:SetSuppressed(true);if self.Input.MobileControls then self.Input.MobileControls:Destroy();self.Input.MobileControls=nil end end;self:_bindFootballer(active,active:GetAttribute("DisplayName"),active:GetAttribute("position"))''',
"hide mobile controls during intro"
)

gameplay = gameplay.replace(
'''if payload.Kind=="Kickoff"and self.MatchSounds then self.MatchSounds:PlayKickoff()end;if payload.Kind=="Kickoff"and self.HUD then''',
'''if payload.Kind=="Kickoff"then self.PendingKickoffSound=true end;if payload.Kind=="Kickoff"and self.HUD then''',
1
)

gameplay = gameplay.replace(
'''self.MatchInPlay=payload.Phase=="IN PLAY";if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;''',
'''self.MatchInPlay=payload.Phase=="IN PLAY";if self.MatchInPlay and self.PendingKickoffSound and self.MatchSounds then self.PendingKickoffSound=false;self.MatchSounds:PlayKickoff()end;if self.Input and self.Input.MobileControls and self.Input.MobileControls.SetVisible then self.Input.MobileControls:SetVisible(self.MatchInPlay and self.WatchMode~=true)end;if self.CrowdAmbience then self.CrowdAmbience:SetMatchActive(self.MatchInPlay)end;''',
1
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

sound_path = Path("src/client/Gameplay/MatchSoundController.lua")
sound = sound_path.read_text(encoding="utf-8")

sound = sound.replace(
'''	self.LastGoalSfxAt = 0
	self.Connection = nil''',
'''	self.LastGoalSfxAt = 0
	self.LastKickoffAt = 0
	self.Connection = nil''',
1
)

sound = re.sub(
r'''function Controller:PlayKickoff\(\)
.*?
end''',
'''function Controller:PlayKickoff()
	if os.clock() - (self.LastKickoffAt or 0) < 1.2 then return end
	self.LastKickoffAt = os.clock()
	playOneShot(KICKOFF_SOUND, 0.62, 1)
end''',
sound,
count=1,
flags=re.S
)

sound_path.write_text(sound, encoding="utf-8", newline="\n")

possession_path = Path("src/server/Gameplay/PossessionService.lua")
possession = possession_path.read_text(encoding="utf-8")

possession = possession.replace(
'''function Service:ForcePickup(model:Model):boolean if self.Owner and self.Owner~=model then self.Owner:SetAttribute("VTRHasBall",false)end;self.Owner=model;model:SetAttribute("VTRHasBall",true);table.clear(self.Blocked);local displayName=model:GetAttribute("DisplayName")or model.Name;self.Ball:SetAttribute("OwnerModel",model.Name);self.Ball:SetAttribute("OwnerUserId",model:GetAttribute("VTRUserId")or 0);self.Remote:FireAllClients({Type="Possession",Owner=displayName,OwnerUserId=model:GetAttribute("VTRUserId")or 0,Model=model,Team=model:GetAttribute("VTRTeam")});return true end''',
'''function Service:ForcePickup(model:Model):boolean if model:GetAttribute("VTRSetPieceTaker")~=true and ((tonumber(model:GetAttribute("VTRCannotRecoverBallUntil"))or 0)>os.clock() or (tonumber(model:GetAttribute("VTRStunnedUntil"))or 0)>os.clock()) then return false end;if self.Owner and self.Owner~=model then self.Owner:SetAttribute("VTRHasBall",false)end;self.Owner=model;model:SetAttribute("VTRHasBall",true);table.clear(self.Blocked);local displayName=model:GetAttribute("DisplayName")or model.Name;self.Ball:SetAttribute("OwnerModel",model.Name);self.Ball:SetAttribute("OwnerUserId",model:GetAttribute("VTRUserId")or 0);self.Remote:FireAllClients({Type="Possession",Owner=displayName,OwnerUserId=model:GetAttribute("VTRUserId")or 0,Model=model,Team=model:GetAttribute("VTRTeam")});return true end''',
1
)

possession_path.write_text(possession, encoding="utf-8", newline="\n")

receive_path = Path("src/server/Gameplay/ReceiveBallService.lua")
receive = receive_path.read_text(encoding="utf-8")

receive = replace_once(
receive,
'''function Service:Expect(player: Player, receiver: Model, receivePoint: Vector3)
	local receiverRoot = root(receiver)
	if not receiverRoot then return end''',
'''function Service:Expect(player: Player, receiver: Model, receivePoint: Vector3)
	if (tonumber(receiver:GetAttribute("VTRCannotRecoverBallUntil")) or 0) > os.clock() or (tonumber(receiver:GetAttribute("VTRStunnedUntil")) or 0) > os.clock() then return end
	local receiverRoot = root(receiver)
	if not receiverRoot then return end''',
"stunned receiver expect"
)

receive = replace_once(
receive,
'''		if not receiver.Parent or os.clock() - entry.Started > 4.2 then''',
'''		if not receiver.Parent or os.clock() - entry.Started > 4.2 or (tonumber(receiver:GetAttribute("VTRCannotRecoverBallUntil")) or 0) > os.clock() or (tonumber(receiver:GetAttribute("VTRStunnedUntil")) or 0) > os.clock() then''',
"stunned receiver clear"
)

receive_path.write_text(receive, encoding="utf-8", newline="\n")

team_path = Path("src/server/Gameplay/TeamControlService.lua")
team = team_path.read_text(encoding="utf-8")

team = replace_once(
team,
'''function Service:_set(player: Player, model: Model, reason: string)
	local previous = self.Active[player]''',
'''function Service:_set(player: Player, model: Model, reason: string)
	if (tonumber(model:GetAttribute("VTRStunnedUntil")) or 0) > os.clock() then return end
	local previous = self.Active[player]''',
"no control stunned player"
)

team_path.write_text(team, encoding="utf-8", newline="\n")

print("fixed match panel transition sounds, prematch badges, pro camera, mobile intro skip, kickoff timing, and tackle stun receiving")