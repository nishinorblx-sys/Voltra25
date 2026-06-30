from pathlib import Path
import re

def read(path):
    return Path(path).read_text(encoding="utf-8")

def write(path, text):
    Path(path).write_text(text, encoding="utf-8", newline="\n")
    print("updated", path)

def replace_once(path, old, new):
    text = read(path)
    if new in text:
        print("already applied", path)
        return
    if old not in text:
        raise RuntimeError("missing target in " + path)
    write(path, text.replace(old, new, 1))

def insert_before(path, marker, insert, exists):
    text = read(path)
    if exists in text:
        print("already applied", path)
        return
    if marker not in text:
        raise RuntimeError("missing marker in " + path)
    write(path, text.replace(marker, insert + "\n" + marker, 1))

def insert_after(path, marker, insert, exists):
    text = read(path)
    if exists in text:
        print("already applied", path)
        return
    if marker not in text:
        raise RuntimeError("missing marker in " + path)
    write(path, text.replace(marker, marker + "\n" + insert, 1))

path = "src/server/Gameplay/OutOfBoundsService.lua"
text = read(path)
if "Half" not in text.split("function Service.new", 1)[1].split("end", 1)[0]:
    text = re.sub(r"Locked\s*=\s*false,\s*Pending\s*=\s*nil\}", "Locked = false, Pending = nil, Half = 1}", text, count=1)
    text = re.sub(r"Locked\s*=\s*false,\s*Pending\s*=\s*nil", "Locked = false, Pending = nil, Half = 1", text, count=1)
write(path, text)

insert_after(
    path,
    "function Service:Reset()\n\tself.Locked = false\n\tself.Pending=nil\nend",
    "\nfunction Service:SetHalf(half: number?)\n\tself.Half = half or 1\nend",
    "function Service:SetHalf"
)

replace_once(
    path,
    "\tlocal attacking = localPosition.Z < 0 and \"Home\" or \"Away\"\n\tlocal defending = attacking == \"Home\" and \"Away\" or \"Home\"",
    "\tlocal attacking\n\tif (self.Half or 1) >= 2 then\n\t\tattacking = localPosition.Z < 0 and \"Away\" or \"Home\"\n\telse\n\t\tattacking = localPosition.Z < 0 and \"Home\" or \"Away\"\n\tend\n\tlocal defending = attacking == \"Home\" and \"Away\" or \"Home\""
)

replace_once(
    "src/server/Gameplay/MatchRuntimeService.lua",
    "session.Clock:StartSecondHalf();if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end;self:_startSetPiece(session,\"Kickoff\",\"Away\",session.World.PitchCFrame.Position)",
    "session.Clock:StartSecondHalf();if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end;if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end;self:_startSetPiece(session,\"Kickoff\",\"Away\",session.World.PitchCFrame.Position)"
)

replace_once(
    "src/server/Gameplay/AIPlayerBrain.lua",
    "\tif self.Random:NextNumber() > 0.1 then\n\t\treturn false\n\tend",
    "\tif self.Random:NextNumber() > 0.05 then\n\t\treturn false\n\tend"
)

insert_before(
    "src/server/Gameplay/SetPieceService.lua",
    "function Service:_releaseCorner(player:Player,payload:any)",
    "local function cornerDangerReceiver(data:any,teams:any,restartTeam:string): Model?\n\tlocal best: Model? = nil\n\tlocal bestScore = -math.huge\n\tlocal goalSign = tonumber(data.GoalSign) or 1\n\tfor _,candidate in teams[restartTeam] or {} do\n\t\tif candidate ~= data.Taker and not isKeeper(candidate) and candidate:GetAttribute(\"VTRSentOff\") ~= true then\n\t\t\tlocal candidateRoot = root(candidate)\n\t\t\tif candidateRoot then\n\t\t\t\tlocal localPosition = data.PitchCFrame:PointToObjectSpace(candidateRoot.Position)\n\t\t\t\tlocal inDangerZ = goalSign > 0 and localPosition.Z >= data.Length * 0.5 - 115 or localPosition.Z <= -data.Length * 0.5 + 115\n\t\t\t\tlocal central = math.abs(localPosition.X) <= data.Width * 0.32\n\t\t\t\tif inDangerZ and central then\n\t\t\t\t\tlocal role = tostring(candidate:GetAttribute(\"position\") or \"\")\n\t\t\t\t\tlocal score = (tonumber(candidate:GetAttribute(\"overall\")) or 60) + ((role == \"ST\" or role == \"CB\") and 16 or role == \"CAM\" and 10 or 0) - math.abs(localPosition.X) * 0.04\n\t\t\t\t\tif score > bestScore then\n\t\t\t\t\t\tbest = candidate\n\t\t\t\t\t\tbestScore = score\n\t\t\t\t\tend\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\tend\n\treturn best\nend\n",
    "cornerDangerReceiver"
)

replace_once(
    "src/server/Gameplay/SetPieceService.lua",
    "if delivery~=\"Short\"then\n\t\tlocal goalSign=tonumber(active.Data.GoalSign)or 1\n\t\ttarget=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,goalSign*(self.World.Length*.5-18)))\n\t\tlocal distance=(Vector3.new(target.X,0,target.Z)-Vector3.new(self.World.Ball.Position.X,0,self.World.Ball.Position.Z)).Magnitude\n\t\tpower=math.clamp((distance-48)/95,.42,.86)\n\tend",
    "if delivery~=\"Short\"then\n\t\tlocal receiver = cornerDangerReceiver(active.Data,self.Teams,active.Data.Team or tostring(active.Data.Taker:GetAttribute(\"VTRTeam\") or \"Home\"))\n\t\tlocal receiverRoot = receiver and root(receiver)\n\t\tif receiverRoot then\n\t\t\ttarget = receiverRoot.Position\n\t\t\tdelivery = \"Lob\"\n\t\telse\n\t\t\tlocal goalSign=tonumber(active.Data.GoalSign)or 1\n\t\t\ttarget=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,goalSign*(self.World.Length*.5-58)))\n\t\t\tdelivery = \"Lob\"\n\t\tend\n\t\tlocal distance=(Vector3.new(target.X,0,target.Z)-Vector3.new(self.World.Ball.Position.X,0,self.World.Ball.Position.Z)).Magnitude\n\t\tpower=math.clamp((distance-34)/92,.46,.82)\n\tend"
)

replace_once(
    "src/server/Gameplay/SetPieceService.lua",
    "local cornerData=CornerPositioningService.Position(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,self.World.Ball.Size.X*.5);cornerData.PitchCFrame=self.World.PitchCFrame;taker=cornerData.Taker;self.ActiveCorner={Player=player,Data=cornerData,OnReady=onReady,Sequence=sequence}",
    "local cornerData=CornerPositioningService.Position(self.Teams,restartTeam,location,self.World.PitchCFrame,self.World.Width,self.World.Length,self.World.Ball.Size.X*.5);cornerData.PitchCFrame=self.World.PitchCFrame;cornerData.Width=self.World.Width;cornerData.Length=self.World.Length;cornerData.Team=restartTeam;taker=cornerData.Taker;self.ActiveCorner={Player=player,Data=cornerData,OnReady=onReady,Sequence=sequence}"
)

replace_once(
    "src/server/Gameplay/SetPieceService.lua",
    "else task.delay(1.25,function()if self.ActiveCorner and self.ActiveCorner.Sequence==sequence then local target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,data.GoalSign*(self.World.Length*.5-18)));self:_releaseCorner(player,{Delivery=\"Cross\",Power=.65,Target=target,ServerAI=true})end end)end",
    "else task.delay(1.25,function()if self.ActiveCorner and self.ActiveCorner.Sequence==sequence then local target=self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,data.GoalSign*(self.World.Length*.5-58)));self:_releaseCorner(player,{Delivery=\"Lob\",Power=.65,Target=target,ServerAI=true})end end)end"
)

insert_after(
    "src/server/Gameplay/AIAssignmentService.lua",
    "local function pressureRank(context: any, info: any, ownerInfo: any): number\n\tlocal rank = 1\n\tlocal distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)\n\tfor _, teammate in ipairs(context.Teams[info.Side].List) do\n\t\tif teammate.Model ~= info.Model and teammate.Root and not teammate.IsGoalkeeper then\n\t\t\tlocal teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)\n\t\t\tif teammateDistance < distance then\n\t\t\t\trank += 1\n\t\t\tend\n\t\tend\n\tend\n\treturn rank\nend",
    "\nlocal function midfieldPressRank(context: any, info: any, ownerInfo: any): number\n\tlocal rank = 1\n\tlocal distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)\n\tfor _, teammate in ipairs(context.Teams[info.Side].List) do\n\t\tif teammate.Model ~= info.Model and teammate.Root and (teammate.Role == \"CDM\" or teammate.Role == \"CM\" or teammate.Role == \"CAM\") then\n\t\t\tlocal teammateDistance = PitchConfig.GetDistanceStuds(teammate.World, ownerInfo.World)\n\t\t\tif teammateDistance < distance then\n\t\t\t\trank += 1\n\t\t\tend\n\t\tend\n\tend\n\treturn rank\nend",
    "midfieldPressRank"
)

insert_after(
    "src/server/Gameplay/AIAssignmentService.lua",
    "\tlocal carrierHasCarriedIntoSpace = ownerInfo and ownerInfo.Model:GetAttribute(\"AICarryIntoSpace\") == true and (tonumber(ownerInfo.Model:GetAttribute(\"AICarriedFor\")) or 0) >= 2",
    "\tif ownerInfo and not pressPaused and not boxThreat and (info.Role == \"CDM\" or info.Role == \"CM\" or info.Role == \"CAM\") then\n\t\tlocal rank = midfieldPressRank(context, info, ownerInfo)\n\t\tlocal distance = PitchConfig.GetDistanceStuds(info.World, ownerInfo.World)\n\t\tif rank == 1 and distance <= 70 then\n\t\t\treturn \"MidfieldPressRotation\", AIDefensiveDecisionService.ContainTarget(ownerPitch), 1, true, faceModel\n\t\telseif rank == 2 and distance <= 92 then\n\t\t\treturn \"SecondMidfielderCover\", AIDefensiveDecisionService.CoverPresserTarget(ownerPitch), 0.9, true, faceModel\n\t\telse\n\t\t\tlocal screenX = info.BasePitch.X + (ballPitch.X - info.BasePitch.X) * 0.28\n\t\t\treturn \"OrganizeMidfieldPress\", Vector3.new(screenX, 3, math.clamp(ballPitch.Z + 26, 155, 430)), 0.84, true, faceModel\n\t\tend\n\tend",
    "MidfieldPressRotation"
)

replace_once(
    "src/client/Gameplay/MatchHUDController.lua",
    "\tlocal outcome = payload.Home > payload.Away and \"VICTORY\" or payload.Home < payload.Away and \"DEFEAT\" or \"DRAW\"\n\tlocal title = label(overlay, outcome, UDim2.new(0.2, 0, 0.08, 0), UDim2.new(0.6, 0, 0, 55), 34)\n\ttitle.TextXAlignment = Enum.TextXAlignment.Center\n\ttitle.TextColor3 = Theme.Colors.Electric",
    "\tlocal outcome = payload.Home > payload.Away and \"VICTORY\" or payload.Home < payload.Away and \"DEFEAT\" or \"DRAW\"\n\tlocal won = outcome == \"VICTORY\"\n\tlocal rewardGlow = Instance.new(\"Frame\")\n\trewardGlow.Name = \"RewardGlow\"\n\trewardGlow.AnchorPoint = Vector2.new(.5,.5)\n\trewardGlow.Position = UDim2.fromScale(.5,.22)\n\trewardGlow.Size = UDim2.fromOffset(520,160)\n\trewardGlow.BackgroundColor3 = won and Theme.Colors.Electric or Theme.Colors.Gunmetal\n\trewardGlow.BackgroundTransparency = won and .72 or 1\n\trewardGlow.BorderSizePixel = 0\n\trewardGlow.ZIndex = 41\n\trewardGlow.Parent = overlay\n\tcorner(rewardGlow,80)\n\tlocal glowScale = Instance.new(\"UIScale\")\n\tglowScale.Scale = .74\n\tglowScale.Parent = rewardGlow\n\tif won then\n\t\tTweenService:Create(glowScale,TweenInfo.new(.55,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.12}):Play()\n\t\tTweenService:Create(rewardGlow,TweenInfo.new(.7,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{BackgroundTransparency=.86}):Play()\n\t\tfor i=1,18 do\n\t\t\tlocal shard=Instance.new(\"Frame\")\n\t\t\tshard.AnchorPoint=Vector2.new(.5,.5)\n\t\t\tshard.Position=UDim2.fromScale(.5,.23)\n\t\t\tshard.Size=UDim2.fromOffset(math.random(8,18),math.random(22,46))\n\t\t\tshard.BackgroundColor3=i%3==0 and Theme.Colors.White or Theme.Colors.Electric\n\t\t\tshard.BackgroundTransparency=.08\n\t\t\tshard.BorderSizePixel=0\n\t\t\tshard.Rotation=math.random(-24,24)\n\t\t\tshard.ZIndex=42\n\t\t\tshard.Parent=overlay\n\t\t\tcorner(shard,3)\n\t\t\tlocal angle=(i/18)*math.pi*2\n\t\t\tlocal radius=math.random(150,330)\n\t\t\tTweenService:Create(shard,TweenInfo.new(.72+math.random()*0.35,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(.5,math.cos(angle)*radius,.23,math.sin(angle)*radius*.38),Rotation=shard.Rotation+math.random(-160,160),BackgroundTransparency=1}):Play()\n\t\t\ttask.delay(1.2,function()if shard.Parent then shard:Destroy()end end)\n\t\tend\n\tend\n\tlocal title = label(overlay, outcome, UDim2.new(0.2, 0, 0.08, 0), UDim2.new(0.6, 0, 0, 55), 34)\n\ttitle.TextXAlignment = Enum.TextXAlignment.Center\n\ttitle.TextColor3 = won and Theme.Colors.Electric or Theme.Colors.White\n\tlocal titleScale = Instance.new(\"UIScale\")\n\ttitleScale.Scale = won and .72 or 1\n\ttitleScale.Parent = title\n\tif won then\n\t\tTweenService:Create(titleScale,TweenInfo.new(.44,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1.18}):Play()\n\t\ttask.delay(.46,function()if titleScale.Parent then TweenService:Create(titleScale,TweenInfo.new(.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=1}):Play()end end)\n\t\tlocal reward = label(overlay,\"+750 COINS   +125 XP   WIN BONUS UNLOCKED\",UDim2.new(.2,0,.17,0),UDim2.new(.6,0,0,28),15)\n\t\treward.TextXAlignment=Enum.TextXAlignment.Center\n\t\treward.TextColor3=Theme.Colors.Electric\n\t\treward.TextTransparency=1\n\treward.ZIndex=44\n\t\tTweenService:Create(reward,TweenInfo.new(.38,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{TextTransparency=0,Position=UDim2.new(.2,0,.155,0)}):Play()\n\tend"
)

print("done")