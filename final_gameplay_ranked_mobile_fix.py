from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

input_path = Path("src/client/Gameplay/InputController.lua")
text = input_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''		local autoSwitch = isMobile and "Off" or (isManual and "Off" or self.AutoSwitch)
		local receiverAssist = isMobile and "Off" or (isManual and "Off" or self.ReceiverAssist)''',
'''		local autoSwitch = isMobile and "Instant" or (isManual and "Off" or self.AutoSwitch)
		local receiverAssist = isMobile and "Assisted" or (isManual and "Off" or self.ReceiverAssist)''',
    "mobile pass receiver switch"
)

input_path.write_text(text, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
text = gameplay_path.read_text(encoding="utf-8")

text = text.replace(
'''self.Trainer:SetActive(model);''',
'''if self.Trainer and not UserInputService.TouchEnabled then self.Trainer:SetActive(model)end;'''
)

text = text.replace(
'''self.Trainer:SetBusy(chargeKind~=""or self.ActiveModel:GetAttribute("VTRSprinting")==true);self.Trainer:Update();''',
'''if self.Trainer and not UserInputService.TouchEnabled then self.Trainer:SetBusy(chargeKind~=""or self.ActiveModel:GetAttribute("VTRSprinting")==true);self.Trainer:Update()end;'''
)

text = text.replace(
'''self.Trainer:SetMatchActive(visible);''',
'''if self.Trainer then self.Trainer:SetMatchActive(not UserInputService.TouchEnabled and visible)end;'''
)

text = text.replace(
'''self.Trainer:SetMatchActive(false);''',
'''if self.Trainer then self.Trainer:SetMatchActive(false)end;'''
)

text = text.replace(
'''self.Trainer:SetMatchActive(self.MatchInPlay and self.WatchMode~=true);''',
'''if self.Trainer then self.Trainer:SetMatchActive(not UserInputService.TouchEnabled and self.MatchInPlay and self.WatchMode~=true)end;'''
)

text = text.replace(
'''if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Pass")end''',
'''if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Pass")end'''
)

text = text.replace(
'''if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Shoot")end''',
'''if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Shoot")end'''
)

text = text.replace(
'''if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Tackle")end''',
'''if payload.Actor==self.ActiveModel and self.Trainer and not UserInputService.TouchEnabled then self.Trainer:NotifyAction("Tackle")end'''
)

text = text.replace(
'''self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function() return self.ActiveModel end)''',
'''self.ControlledIndicator=VoltraControlledPlayerIndicator.new(function()
			if self.WatchMode or not self.MatchInPlay or self.PrematchActive then return nil end
			return self.ActiveModel
		end)'''
)

text = text.replace(
'''self.Input:SetAutoSwitch(settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(settings.ReceiverAssist or "Light");''',
'''self.Input:SetAutoSwitch(UserInputService.TouchEnabled and "Instant" or settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(UserInputService.TouchEnabled and "Assisted" or settings.ReceiverAssist or "Light");'''
)

text = text.replace(
'''if chosenDot>.42 and chosenDistance<=170 then''',
'''if chosenDistance<=172 and chosenDot>-0.08 then'''
)

gameplay_path.write_text(text, encoding="utf-8", newline="\n")

team_control_path = Path("src/server/Gameplay/TeamControlService.lua")
text = team_control_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''			local smoothed, penalty = self.Smoothing:Update(active, raw, ownsBall, sprinting)
			local now = os.clock()''',
'''			local smoothed, penalty = self.Smoothing:Update(active, raw, ownsBall, sprinting)
			if active:GetAttribute("controlledByUser")==true then
				smoothed = magnitude > 0.05 and raw.Unit * magnitude or Vector3.zero
				penalty = 1
			end
			local now = os.clock()''',
    "direct user movement"
)

text = replace_once(
    text,
'''			active:SetAttribute("VTRMoveMagnitude", magnitude)''',
'''			active:SetAttribute("VTRMoveMagnitude", magnitude)
			if magnitude>.08 then active:SetAttribute("VTRImmediateControlUntil",os.clock()+.22)end''',
    "continuous immediate control"
)

team_control_path.write_text(text, encoding="utf-8", newline="\n")

smoothing_path = Path("src/server/Gameplay/MovementSmoothingService.lua")
text = smoothing_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''	local smoothing = hasBall and Tuning.InputSmoothingTime * (1.18 - agility * 0.38) or Tuning.InputSmoothingNoBall
	if sprinting and hasBall then smoothing *= 1.35 end''',
'''	local smoothing = hasBall and Tuning.InputSmoothingTime * (1.18 - agility * 0.38) or Tuning.InputSmoothingNoBall
	if model:GetAttribute("controlledByUser")==true then smoothing *= hasBall and .34 or .22 end
	if sprinting and hasBall then smoothing *= 1.08 end''',
    "faster user smoothing"
)

smoothing_path.write_text(text, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
text = ball_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''	self.Possession:Block(owner,slide and 1.5 or.5);owner:SetAttribute("VTRStunnedUntil",now+(slide and 1.5 or.5))''',
'''	self.Possession:Block(owner,slide and 1.5 or 1.0);owner:SetAttribute("VTRStunnedUntil",now+(slide and 1.5 or 1.0));owner:SetAttribute("VTRCannotRecoverBallUntil",now+(slide and 1.5 or 1.0))''',
    "tackle stun"
)

ball_path.write_text(text, encoding="utf-8", newline="\n")

possession_path = Path("src/server/Gameplay/PossessionService.lua")
text = possession_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''function Service:CanPickup(model:Model):boolean local root=model:FindFirstChild("HumanoidRootPart");local hum=model:FindFirstChildOfClass("Humanoid");return self.Owner==nil and root~=nil and hum~=nil and hum.Health>0 and(self.Blocked[model]or 0)<=os.clock()and(root.Position-self.Ball.Position).Magnitude<=Config.Ball.PossessionRange end''',
'''function Service:CanPickup(model:Model):boolean local root=model:FindFirstChild("HumanoidRootPart");local hum=model:FindFirstChildOfClass("Humanoid");return self.Owner==nil and root~=nil and hum~=nil and hum.Health>0 and(self.Blocked[model]or 0)<=os.clock()and(tonumber(model:GetAttribute("VTRCannotRecoverBallUntil"))or 0)<=os.clock()and(root.Position-self.Ball.Position).Magnitude<=Config.Ball.PossessionRange end''',
    "cannot recover after tackle"
)

possession_path.write_text(text, encoding="utf-8", newline="\n")

anim_path = Path("src/server/Gameplay/MatchAnimationService.lua")
text = anim_path.read_text(encoding="utf-8")

if 'local ContentProvider = game:GetService("ContentProvider")' not in text:
    text = text.replace(
'''local ReplicatedStorage = game:GetService("ReplicatedStorage")''',
'''local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")''',
1
    )

text = replace_once(
    text,
'''		local animation=Instance.new("Animation");animation.Name="VTR_"..name;animation.AnimationId=id;state.Animations[name]=animation
		local ok,result=pcall(function()return animator:LoadAnimation(animation)end)''',
'''		local animation=Instance.new("Animation");animation.Name="VTR_"..name;animation.AnimationId=id;state.Animations[name]=animation
		pcall(function()ContentProvider:PreloadAsync({animation})end)
		local ok,result=pcall(function()return animator:LoadAnimation(animation)end)''',
    "server preload animations"
)

text = text.replace(
'''track.Priority=(name=="Shoot"or name=="Pass"or name=="Tackle")and Enum.AnimationPriority.Action4 or ACTION[name]and Enum.AnimationPriority.Action or(name=="Idle"or name=="GoalkeeperIdle")and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement''',
'''track.Priority=(name=="Shoot"or name=="Pass"or name=="Tackle"or name=="GoalkeeperDive"or name=="SlideTackle")and Enum.AnimationPriority.Action4 or ACTION[name]and Enum.AnimationPriority.Action or(name=="Idle"or name=="GoalkeeperIdle")and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement'''
)

anim_path.write_text(text, encoding="utf-8", newline="\n")

gk_path = Path("src/server/Gameplay/GoalkeeperService.lua")
text = gk_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''		self.Animations:PlayActionTimed(save.Keeper,"GoalkeeperDive",math.max(.22,flightTime+.04))''',
'''		save.Keeper:SetAttribute("VTRForceIdle",nil)
		if self.Animations then
			self.Animations:StopAction(save.Keeper,.02)
			self.Animations:PlayActionTimed(save.Keeper,"GoalkeeperDive",math.max(.34,flightTime+.14))
		end''',
    "goalkeeper dive animation force"
)

gk_path.write_text(text, encoding="utf-8", newline="\n")

ranked_profile_path = Path("src/server/Services/RankedProfileService.lua")
text = ranked_profile_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''	if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;local r=p.Ranked;local delta=0''',
'''	if result=="ForfeitWin"then result="Win"elseif result=="ForfeitLoss"then result="Loss"end;if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;local r=p.Ranked;local delta=0''',
    "ranked forfeit result accepted"
)

ranked_profile_path.write_text(text, encoding="utf-8", newline="\n")

ranked_queue_path = Path("src/server/Services/RankedQueueService.lua")
text = ranked_queue_path.read_text(encoding="utf-8")

text = replace_once(
    text,
'''	session.RankedWinPackGrant=function(_,winner:Player)
		return RankedWinPackReward.Grant(self.Progression,winner,self.Publish)
	end''',
'''	session.RankedWinRewards=session.RankedWinRewards or{}
	session.RankedWinPackGrant=function(_,winner:Player)
		session.RankedWinRewards=session.RankedWinRewards or{}
		local existing=session.RankedWinRewards[winner.UserId]
		if existing then return existing end
		local reward=RankedWinPackReward.Grant(self.Progression,winner,self.Publish)
		session.RankedWinRewards[winner.UserId]=reward
		return reward
	end''',
    "ranked pack memo grant"
)

text = replace_once(
    text,
'''			if won then
				local packReward=RankedWinPackReward.Grant(self.Progression,participant,self.Publish)
				reward=reward or{}
				for key,value in packReward do
					reward[key]=value
				end
				reward.Title="RANKED VICTORY"
			end''',
'''			if won then
				session.RankedWinRewards=session.RankedWinRewards or{}
				local packReward=session.RankedWinRewards[participant.UserId]
				if not packReward then
					packReward=RankedWinPackReward.Grant(self.Progression,participant,self.Publish)
					session.RankedWinRewards[participant.UserId]=packReward
				end
				reward=reward or{}
				for key,value in packReward do
					reward[key]=value
				end
				reward.Title="RANKED VICTORY"
			end''',
    "ranked pack exact reward payload"
)

ranked_queue_path.write_text(text, encoding="utf-8", newline="\n")

setup_path = Path("src/server/Services/MatchSetupService.lua")
text = setup_path.read_text(encoding="utf-8")

if 'local Players=game:GetService("Players")' not in text:
    text = text.replace(
'''local ReplicatedStorage=game:GetService("ReplicatedStorage")''',
'''local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TeleportService=game:GetService("TeleportService")''',
1
    )

text = replace_once(
    text,
'''function Service.new(profiles:any,publish:(Player,string,any)->(),progression:any,runtime:any,rankedSquads:any?)return setmetatable({Profiles=profiles,Publish=publish,Progression=progression,Runtime=runtime,RankedSquads=rankedSquads},Service)end''',
'''function Service.new(profiles:any,publish:(Player,string,any)->(),progression:any,runtime:any,rankedSquads:any?)
	local self=setmetatable({Profiles=profiles,Publish=publish,Progression=progression,Runtime=runtime,RankedSquads=rankedSquads,SoloTeleportConnections={}},Service)
	task.defer(function()
		for _,player in Players:GetPlayers()do self:HandleSoloCampaignTeleport(player)end
		table.insert(self.SoloTeleportConnections,Players.PlayerAdded:Connect(function(player)task.defer(function()self:HandleSoloCampaignTeleport(player)end)end))
	end)
	return self
end''',
    "solo campaign service new"
)

if "function Service:_isCampaignMatch" not in text:
    text = text.replace(
'''function Service:GetClientData(player:Player):any?''',
'''function Service:_isCampaignMatch(setup:any):boolean
	return type(setup)=="table" and type(setup.CampaignTeamId)=="string" and setup.CampaignTeamId~=""
end

function Service:_teleportSoloCampaign(player:Player,action:string):(boolean,string,any?)
	if RunService:IsStudio() or game.PrivateServerId~="" or player:GetAttribute("VTRAICampaignSoloServer")==true then return false,"",nil end
	local code=nil
	local ok,err=pcall(function()code=TeleportService:ReserveServer(game.PlaceId)end)
	if not ok or not code then return false,"Could not reserve a solo campaign server.",nil end
	local options=Instance.new("TeleportOptions")
	options.ReservedServerAccessCode=code
	options:SetTeleportData({MatchMode="AICampaignSolo",Action=action,ReturnPlaceId=game.PlaceId})
	local sent,teleportErr=pcall(function()TeleportService:TeleportAsync(game.PlaceId,{player},options)end)
	if not sent then return false,tostring(teleportErr),nil end
	return true,"Teleporting to solo campaign server.",{Teleporting=true,SoloCampaign=true,Action=action}
end

function Service:HandleSoloCampaignTeleport(player:Player):boolean
	local joinData=player:GetJoinData()
	local teleportData=joinData and joinData.TeleportData
	if type(teleportData)~="table" or teleportData.MatchMode~="AICampaignSolo" then return false end
	player:SetAttribute("VTRAICampaignSoloServer",true)
	task.spawn(function()
		local started=os.clock()
		while player.Parent==Players and os.clock()-started<35 do
			if self.Profiles:GetProfile(player) and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				if teleportData.Action=="Manage" then
					self:WatchMatch(player)
				else
					self:StartMatch(player)
				end
				return
			end
			task.wait(.25)
		end
	end)
	return true
end

function Service:GetClientData(player:Player):any?''',
1
    )

text = replace_once(
    text,
'''	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	local success,text,data=self.Runtime:StartMatch(player,setup);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manual"end''',
'''	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	if self:_isCampaignMatch(setup) and player:GetAttribute("VTRAICampaignSoloServer")~=true then
		local teleporting,teleportMessage,teleportData=self:_teleportSoloCampaign(player,"Manual")
		if teleporting then return true,teleportMessage,teleportData end
	end
	local success,text,data=self.Runtime:StartMatch(player,setup);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manual"end''',
    "manual solo campaign teleport"
)

text = replace_once(
    text,
'''	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	local watchSetup=table.clone(setup);watchSetup.WatchMode=true;watchSetup.TeamTactics=profile.TeamTactics''',
'''	local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;local setup=self:_ensure(profile);local valid,message=self:_validate(setup);if not valid or not setup.Completed then return false,message,nil end
	if self:_isCampaignMatch(setup) and player:GetAttribute("VTRAICampaignSoloServer")~=true then
		local teleporting,teleportMessage,teleportData=self:_teleportSoloCampaign(player,"Manage")
		if teleporting then return true,teleportMessage,teleportData end
	end
	local watchSetup=table.clone(setup);watchSetup.WatchMode=true;watchSetup.TeamTactics=profile.TeamTactics''',
    "watch solo campaign teleport"
)

setup_path.write_text(text, encoding="utf-8", newline="\n")

prematch_path = Path("src/client/Components/PrematchBroadcastPresentation.lua")
text = prematch_path.read_text(encoding="utf-8")

badge_block = '''local function applyPresentationBadge(target: TextLabel, primary: Color3, logoText: string?)
	target.Text = ""
	target.BackgroundTransparency = 1
	target.ClipsDescendants = true
	for _, child in target:GetChildren() do
		if child.Name == "VTRPresentationBadgeArt" or child.Name == "BadgeArt" then child:Destroy() end
	end
	local accent = Color3.fromHex("F5F7F2")
	local art = Instance.new("Frame")
	art.Name = "VTRPresentationBadgeArt"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ZIndex = target.ZIndex + 1
	art.Parent = target
	local shield = Instance.new("Frame")
	shield.Name = "Shield"
	shield.AnchorPoint = Vector2.new(.5, .5)
	shield.Position = UDim2.fromScale(.5, .5)
	shield.Size = UDim2.fromScale(.74, .82)
	shield.BackgroundColor3 = primary
	shield.BorderSizePixel = 0
	shield.ZIndex = art.ZIndex + 1
	shield.Parent = art
	local shieldCorner = Instance.new("UICorner")
	shieldCorner.CornerRadius = UDim.new(.18, 0)
	shieldCorner.Parent = shield
	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.AnchorPoint = Vector2.new(.5, .5)
	stripe.Position = UDim2.fromScale(.5, .5)
	stripe.Size = UDim2.fromScale(.28, 1.12)
	stripe.Rotation = -18
	stripe.BackgroundColor3 = accent
	stripe.BackgroundTransparency = .05
	stripe.BorderSizePixel = 0
	stripe.ZIndex = shield.ZIndex + 1
	stripe.Parent = shield
	local cap = Instance.new("Frame")
	cap.Name = "Cap"
	cap.Position = UDim2.fromScale(.13, .08)
	cap.Size = UDim2.fromScale(.74, .22)
	cap.BackgroundColor3 = accent
	cap.BackgroundTransparency = .08
	cap.BorderSizePixel = 0
	cap.ZIndex = shield.ZIndex + 2
	cap.Parent = shield
	local point = Instance.new("Frame")
	point.Name = "Point"
	point.AnchorPoint = Vector2.new(.5, 1)
	point.Position = UDim2.fromScale(.5, 1.06)
	point.Size = UDim2.fromScale(.42, .28)
	point.Rotation = 45
	point.BackgroundColor3 = primary:Lerp(Color3.fromHex("050505"), .24)
	point.BorderSizePixel = 0
	point.ZIndex = shield.ZIndex
	point.Parent = shield
	local outline = Instance.new("UIStroke")
	outline.Color = accent
	outline.Transparency = .18
	outline.Thickness = 1
	outline.Parent = shield
end
'''

text, count = re.subn(
    r'local function applyPresentationBadge\(target: TextLabel, primary: Color3, logoText: string\?\).*?end\n\nlocal function label',
    badge_block + "\nlocal function label",
    text,
    count=1,
    flags=re.S
)

if count == 0:
    print("skipped prematch badge art replacement")

prematch_path.write_text(text, encoding="utf-8", newline="\n")

roulette_path = Path("src/client/Components/VoltraPackRoulette.lua")
if roulette_path.exists():
    text = roulette_path.read_text(encoding="utf-8")
    text = text.replace(
'''	\t\tlocal pack = i == stopIndex and chosen or PACKS[math.random(1, #PACKS)]''',
'''	\t\tlocal pack = i == stopIndex and chosen or weightedPack()'''
    )
    text = text.replace(
'''	\t\tlabel(overlay, "PACK SECURED", UDim2.fromScale(.2, .80), UDim2.fromScale(.6, .05), 22, chosen.Color, 545)''',
'''	\t\tlocal secured = label(overlay, string.upper(chosen.Name) .. " SECURED", UDim2.fromScale(.14, .80), UDim2.fromScale(.72, .05), 22, chosen.Color, 545)
\t\tsecured.TextWrapped = true'''
    )
    roulette_path.write_text(text, encoding="utf-8", newline="\n")

print("final gameplay, ranked, mobile, animation, campaign solo, and badge fixes applied")