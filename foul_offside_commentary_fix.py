from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

ref_path = Path("src/server/Gameplay/RefereeService.lua")
ref = ref_path.read_text(encoding="utf-8")

ref = ref.replace(
'''function Service.new(remote:RemoteEvent,stats:any,onRestart:any,pitchCFrame:CFrame?,width:number?,length:number?)
	return setmetatable({Remote=remote,Stats=stats,OnRestart=onRestart,Fouls={},Yellows={},Random=Random.new(),PitchCFrame=pitchCFrame,Width=width or 0,Length=length or 0},Service)
end''',
'''function Service.new(remote:RemoteEvent,stats:any,onRestart:any,pitchCFrame:CFrame?,width:number?,length:number?)
	return setmetatable({Remote=remote,Stats=stats,OnRestart=onRestart,Fouls={},Yellows={},Random=Random.new(),PitchCFrame=pitchCFrame,Width=width or 0,Length=length or 0,Half=1},Service)
end
function Service:SetHalf(half:number?)self.Half=half or 1 end'''
)

ref = re.sub(
    r'function Service:_isInsidePenaltyArea\(team:string,location:Vector3\):boolean.*?end\nfunction Service:CallFoul',
'''function Service:_penaltyBoxOwner(location:Vector3):string?
	if not self.PitchCFrame or self.Width<=0 or self.Length<=0 then return nil end
	local localPoint=self.PitchCFrame:PointToObjectSpace(location)
	local inWidth=math.abs(localPoint.X)<=22
	if not inWidth then return nil end
	local nearPositive=math.abs((self.Length*.5)-localPoint.Z)<=18
	local nearNegative=math.abs((-self.Length*.5)-localPoint.Z)<=18
	if not nearPositive and not nearNegative then return nil end
	local positiveOwner=(self.Half or 1)>=2 and "Away" or "Home"
	local negativeOwner=(self.Half or 1)>=2 and "Home" or "Away"
	return nearPositive and positiveOwner or negativeOwner
end
function Service:CallFoul''',
    ref,
    count=1,
    flags=re.S
)

ref = ref.replace(
'''	local restartKind=self:_isInsidePenaltyArea(team,location)and"Penalty"or"FreeKick"''',
'''	local victimTeam=tostring(victim:GetAttribute("VTRTeam")or restartTeam)
	local boxOwner=self:_penaltyBoxOwner(location)
	local restartKind=(boxOwner~=nil and boxOwner==team and victimTeam==restartTeam)and"Penalty"or"FreeKick"'''
)

ref_path.write_text(ref, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

runtime = replace_once(
    runtime,
'''session.Referee=RefereeService.new(self.State,stats,function(restartTeam:string,location:Vector3,restartKind:string?,forcedTaker:Model?)if not session.Ended then self:_startSetPiece(session,restartKind or "FreeKick",restartTeam,location,forcedTaker)end end,world.PitchCFrame,world.Width,world.Length);ballService:SetReferee(session.Referee)
	session.Offside=OffsideService.new(self.State,stats,teams,world.PitchCFrame,function(restartTeam:string,location:Vector3)if not session.Ended then self:_startSetPiece(session,"FreeKick",restartTeam,location)end end);ballService:SetOffsideService(session.Offside)''',
'''session.Referee=RefereeService.new(self.State,stats,function(restartTeam:string,location:Vector3,restartKind:string?,forcedTaker:Model?)if not session.Ended then self:_startSetPiece(session,restartKind or "FreeKick",restartTeam,location,forcedTaker)end end,world.PitchCFrame,world.Width,world.Length);ballService:SetReferee(session.Referee)
	session.Offside=OffsideService.new(self.State,stats,teams,world.PitchCFrame,function(restartTeam:string,location:Vector3)if not session.Ended then session.World.Ball:SetAttribute("VTRRestartDisplayKind","Offside");self:_startSetPiece(session,"FreeKick",restartTeam,location)end end);ballService:SetOffsideService(session.Offside)''',
    "offside display attribute"
)

runtime = replace_once(
    runtime,
'''	if session.AI and session.AI.SetHalf then session.AI:SetHalf(currentHalf)end
	if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(currentHalf)end
	if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(currentHalf)end''',
'''	if session.AI and session.AI.SetHalf then session.AI:SetHalf(currentHalf)end
	if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(currentHalf)end
	if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(currentHalf)end
	if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(currentHalf)end''',
    "set referee half in set piece"
)

runtime = replace_once(
    runtime,
'''session.Clock:StartSecondHalf();if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end;if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end;self:_startSetPiece(session,"Kickoff","Away",session.World.PitchCFrame.Position)''',
'''session.Clock:StartSecondHalf();if session.AI and session.AI.SetHalf then session.AI:SetHalf(2)end;if session.Referee and session.Referee.SetHalf then session.Referee:SetHalf(2)end;if session.Offside and session.Offside.SetHalf then session.Offside:SetHalf(2)end;if session.Goalkeepers and session.Goalkeepers.SetHalf then session.Goalkeepers:SetHalf(2)end;if session.OutOfBounds and session.OutOfBounds.SetHalf then session.OutOfBounds:SetHalf(2)end;self:_startSetPiece(session,"Kickoff","Away",session.World.PitchCFrame.Position)''',
    "set referee second half"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

setpiece_path = Path("src/server/Gameplay/SetPieceService.lua")
setpiece = setpiece_path.read_text(encoding="utf-8")

setpiece = replace_once(
    setpiece,
'''	local goalPosition=payloadGoalSign and self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,payloadGoalSign*self.World.Length*.5))or nil
	self.Remote:FireClient(player, {Type = "SetPiece", Kind = kind, Team = restartTeam, Location = ballPosition, Taker = taker, Duration = duration, GoalSign=payloadGoalSign, GoalPosition=goalPosition, Cutscene=kind=="Penalty"or(kind=="FreeKick"and setPieceCutscene), Mode=self.RestartMode, FouledPlayerName=tostring(taker:GetAttribute("DisplayName") or taker.Name)})''',
'''	local goalPosition=payloadGoalSign and self.World.PitchCFrame:PointToWorldSpace(Vector3.new(0,3,payloadGoalSign*self.World.Length*.5))or nil
	local displayKind=tostring(self.World.Ball:GetAttribute("VTRRestartDisplayKind") or kind)
	self.World.Ball:SetAttribute("VTRRestartDisplayKind",nil)
	self.Remote:FireClient(player, {Type = "SetPiece", Kind = displayKind, ActualKind = kind, Team = restartTeam, Location = ballPosition, Taker = taker, Duration = duration, GoalSign=payloadGoalSign, GoalPosition=goalPosition, Cutscene=kind=="Penalty"or(kind=="FreeKick"and setPieceCutscene), Mode=self.RestartMode, FouledPlayerName=tostring(taker:GetAttribute("DisplayName") or taker.Name)})''',
    "display kind payload"
)

setpiece_path.write_text(setpiece, encoding="utf-8", newline="\n")

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
    ball,
'''	if nearest and (forcedReceiverPickup or self.Possession:Pickup(nearest)) then
		local team = nearest:GetAttribute("VTRTeam")
		if self.OffsideCandidate and nearest==self.OffsideCandidate and self.Offside then self.Offside:Call(nearest);self.OffsideCandidate=nil;self.LastPassTeam=nil;self.LastPasser=nil;self.LastPassOrigin=nil;self.ExpectedReceiver=nil;self.PassPlan=nil;self.Ball:SetAttribute("VTRPassTarget",nil);self.Ball:SetAttribute("VTRPassStartedAt",nil);self.Ball:SetAttribute("VTRPassTeam",nil);self.Ball:SetAttribute("VTRPassReceiver",nil);return end
		if self.LastPassTeam then''',
'''	if nearest and (forcedReceiverPickup or self.Possession:Pickup(nearest)) then
		local team = nearest:GetAttribute("VTRTeam")
		local previousTeam=tostring(self.Ball:GetAttribute("VTRLastPossessionTeam") or "")
		local pickupReason="LooseRecovery"
		if self.LastPassTeam then
			if self.LastPassTeam==team then
				pickupReason=forcedReceiverPickup and "PassReceived" or "TeamPassRecovered"
			else
				pickupReason="Turnover"
			end
		elseif previousTeam~="" and previousTeam~=team then
			pickupReason="Turnover"
		end
		self.Ball:SetAttribute("VTRLastPossessionTeam",team)
		self.Remote:FireAllClients({Type="PossessionContext",Owner=nearest:GetAttribute("DisplayName")or nearest.Name,Model=nearest,Team=team,Reason=pickupReason})
		if self.OffsideCandidate and nearest==self.OffsideCandidate and self.Offside then self.Offside:Call(nearest);self.OffsideCandidate=nil;self.LastPassTeam=nil;self.LastPasser=nil;self.LastPassOrigin=nil;self.ExpectedReceiver=nil;self.PassPlan=nil;self.Ball:SetAttribute("VTRPassTarget",nil);self.Ball:SetAttribute("VTRPassStartedAt",nil);self.Ball:SetAttribute("VTRPassTeam",nil);self.Ball:SetAttribute("VTRPassReceiver",nil);return end
		if self.LastPassTeam then''',
    "possession context"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

possession_path = Path("src/server/Gameplay/PossessionService.lua")
possession = possession_path.read_text(encoding="utf-8")

possession = possession.replace(
'''self.Remote:FireAllClients({Type="Possession",Owner=displayName,OwnerUserId=model:GetAttribute("VTRUserId")or 0,Model=model})''',
'''self.Remote:FireAllClients({Type="Possession",Owner=displayName,OwnerUserId=model:GetAttribute("VTRUserId")or 0,Model=model,Team=model:GetAttribute("VTRTeam")})'''
)

possession_path.write_text(possession, encoding="utf-8", newline="\n")

commentary_path = Path("src/client/Gameplay/CommentaryController.lua")
commentary = commentary_path.read_text(encoding="utf-8")

if "Offside = {" not in commentary:
    commentary = commentary.replace(
'''	FreeKick = {
		"Free kick awarded. This could be dangerous.",
		"A set piece chance now.",
		"The referee gives the free kick.",
		"A good opportunity from this dead-ball situation."
	},''',
'''	FreeKick = {
		"Free kick awarded. This could be dangerous.",
		"A set piece chance now.",
		"The referee gives the free kick.",
		"A good opportunity from this dead-ball situation."
	},

	Offside = {
		"Offside.",
		"The flag is up. Offside.",
		"Offside called by the assistant.",
		"The attack stops for offside."
	},''',
    1
    )

commentary = commentary.replace(
'''	FreeKick = 2,
	Penalty = 0,''',
'''	FreeKick = 2,
	Offside = 1.2,
	Penalty = 0,''',
1
)

commentary = commentary.replace(
'''		elseif setPieceKind == "FreeKick" then
			self:Say("FreeKick", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		elseif setPieceKind == "Corner" or setPieceKind == "CornerKick" then''',
'''		elseif setPieceKind == "Offside" then
			self:Say("Offside", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		elseif setPieceKind == "FreeKick" then
			self:Say("FreeKick", {
				Team = getTeam(payload.Team),
				PlayerName = getName(payload.Actor)
			})
		elseif setPieceKind == "Corner" or setPieceKind == "CornerKick" then''',
1
)

commentary = commentary.replace(
'''	elseif kind == "Possession" and payload.Owner and payload.Owner ~= "" then
		self:Say("PossessionWon", {
			PlayerName = getName(payload.Owner)
		})''',
'''	elseif kind == "PossessionContext" and payload.Owner and payload.Owner ~= "" then
		local reason = tostring(payload.Reason or "")
		if reason == "Turnover" or reason == "LooseRecovery" then
			self:Say("PossessionWon", {
				PlayerName = getName(payload.Owner)
			})
		end

	elseif kind == "Possession" and payload.Owner and payload.Owner ~= "" then'''
)

commentary_path.write_text(commentary, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = replace_once(
    gameplay,
'''elseif payload.Type=="SetPiece"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted(payload.Kind)end;if self.Input and payload.Kind~="Corner" then self.Input:SetSuppressed(self.WatchMode==true)end;if self.Input and self.Input.ResetFreeKickModifiers and payload.Mode=="DirectShotFreeKick"then self.Input:ResetFreeKickModifiers()end;self.MatchInPlay=false;self.SetPieceMode=payload.Mode;self.SetPieceKind=payload.Kind;if payload.Taker and payload.Taker:IsA("Model")then self:_bindFootballer(payload.Taker,payload.Taker:GetAttribute("DisplayName"),payload.Taker:GetAttribute("position"))end;if self.Visual then self.Visual:ClearLock();self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;self.Trainer:SetMatchActive(false);self.Minimap:SetMatchActive(false);local aimingRestart=(payload.Kind=="FreeKick"or payload.Kind=="Penalty")and self.WatchMode~=true;self.AimLine:SetMatchActive(aimingRestart);self.GoalTarget:SetMatchActive(aimingRestart);if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;self.Cutscenes:Play(payload)''',
'''elseif payload.Type=="SetPiece"then if self.ReplayController then self.ReplayController:MarkSetPieceStarted(payload.ActualKind or payload.Kind)end;if self.Input and payload.Kind~="Corner" then self.Input:SetSuppressed(self.WatchMode==true)end;if self.Input and self.Input.ResetFreeKickModifiers and payload.Mode=="DirectShotFreeKick"then self.Input:ResetFreeKickModifiers()end;self.MatchInPlay=false;self.SetPieceMode=payload.Mode;self.SetPieceKind=payload.ActualKind or payload.Kind;if payload.Kind=="Offside"and self.HUD then self.HUD:Flash("OFFSIDE",1.05)end;if payload.Taker and payload.Taker:IsA("Model")then self:_bindFootballer(payload.Taker,payload.Taker:GetAttribute("DisplayName"),payload.Taker:GetAttribute("position"))end;if self.Visual then self.Visual:ClearLock();self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;self.Trainer:SetMatchActive(false);self.Minimap:SetMatchActive(false);local aimingRestart=((payload.ActualKind or payload.Kind)=="FreeKick"or payload.Kind=="Penalty")and self.WatchMode~=true;self.AimLine:SetMatchActive(aimingRestart);self.GoalTarget:SetMatchActive(aimingRestart);if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;self.Cutscenes:Play(payload)''',
    "client offside set piece"
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

print("fixed box foul penalty logic, offside display, and possession commentary")