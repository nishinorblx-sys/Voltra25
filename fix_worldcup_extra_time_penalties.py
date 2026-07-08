from pathlib import Path
import re

root = Path.cwd()
path = root / "src/server/Gameplay/MatchRuntimeService.lua"

text = path.read_text(encoding="utf-8", errors="ignore")

if "local EXTRA_TIME_TOTAL_SECONDS" not in text:
	text = text.replace(
		"local POST_MATCH_WORLD_CLEANUP_DELAY=8.0",
		"local POST_MATCH_WORLD_CLEANUP_DELAY=8.0\nlocal EXTRA_TIME_TOTAL_SECONDS=180\nlocal EXTRA_TIME_HALF_PAUSE_SECONDS=30"
	)

helper = r'''
function Service:_isWorldCupKnockoutTiebreakMatch(session:any):boolean
	if not session or session.Ranked or session.ShootingPractice then
		return false
	end

	local setup=session.Setup or{}
	local mode=tostring(setup.MatchType or setup.MatchMode or setup.Mode or setup.Type or setup.Competition or "")
	local stage=tostring(setup.WorldCupStage or setup.Stage or setup.Round or setup.KnockoutRound or "")
	local lowerMode=string.lower(mode)
	local lowerStage=string.lower(stage)

	local worldCup=session.PrivateWorldCupMatch==true or setup.WorldCup==true or setup.WorldCupSolo==true or string.find(lowerMode,"worldcup",1,true)~=nil or string.find(lowerMode,"world cup",1,true)~=nil
	if not worldCup then
		return false
	end

	if setup.WorldCupKnockout==true or setup.Knockout==true or setup.IsKnockout==true then
		return true
	end

	if lowerStage~="" and not string.find(lowerStage,"group",1,true) then
		return true
	end

	return session.PrivateWorldCupMatch==true and setup.WorldCupGroup~=true and setup.GroupStage~=true
end

function Service:_scoreTied(session:any):boolean
	return session and session.World and session.World.HomeScore.Value==session.World.AwayScore.Value
end

function Service:_resetForExtraTimeKickoff(session:any)
	session.PendingReplayRestart=nil
	session.FinalChance=nil
	session.PendingAIPenalty=nil
	session.PendingGoalRestart=nil
	session.SetPieceAutoSeq=(session.SetPieceAutoSeq or 0)+1
	session.ManualPaused=false
	session.Paused=false
	session.PauseRequester=nil
	session.PauseResumeVotes={}
	session.HalfTimeTriggered=false
	session.HalfTimeBreak=false
	session.HalfTimeBreakEndsAt=nil
	session.HalfTimeResumeVotes={}
	session.HalfTimeResuming=nil
	if session.SetPieces and session.SetPieces.Cancel then session.SetPieces:Cancel()end
	if session.OutOfBounds and session.OutOfBounds.Reset then session.OutOfBounds:Reset()end
	if session.Goals and session.Goals.Unlock then session.Goals:Unlock()end
	if session.Possession then session.Possession:Reset()end
	if session.TeamControl and session.TeamControl.Receiving then session.TeamControl.Receiving:Clear()end
	if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase(nil)end
	if session.BallService then
		session.BallService:ClearGoalkeeperHoldState(nil)
		session.BallService.MotionKind="Loose"
		session.BallService.MotionStarted=os.clock()
		session.BallService.ShotPlan=nil
		session.BallService.PassPlan=nil
		session.BallService.PassTargetPoint=nil
		session.BallService.ExpectedReceiver=nil
		session.BallService.PendingCurve=nil
		if session.BallService.Curve then session.BallService.Curve:Stop()end
	end

	local ball=session.World and session.World.Ball
	if ball then
		ball.Anchored=false
		ball.CanCollide=true
		ball.CanTouch=true
		ball.Massless=false
		ball.CFrame=CFrame.new(session.World.PitchCFrame.Position+Vector3.new(0,Config.Ball.Radius+.15,0))
		ball.AssemblyLinearVelocity=Vector3.zero
		ball.AssemblyAngularVelocity=Vector3.zero
		setServerNetworkOwner(ball)
		for _,attribute in{"VTRWorldPaused","VTRPauseSavedVelocity","VTRPauseSavedAngularVelocity","VTRPostGoalPhysicsUntil","VTRPostGoalVelocity","VTRPostGoalAngularVelocity","VTRGoalCalledAt","VTRGoalEntryVelocity","VTRGoalEntryAngularVelocity","VTRGoalEntryPosition","VTRGoalEntryNormal","VTRPenaltyShotActive","VTRGoalkeeperHeld","VTRGoalkeeperTracking","VTRPassTarget","VTRPassStartedAt","VTRPassTeam","VTRPassReceiver","VTRLobTarget","VTRLobPassActive","VTRSetPieceReady","VTRSetPieceKind","VTRSetPieceTeam","VTRCornerTarget"}do
			ball:SetAttribute(attribute,nil)
		end
	end

	for _,model in session.Models or{}do
		for _,attribute in{"VTRGoalkeeperHolding","VTRGoalkeeperHoldingSince","VTRKeeperMustDistributeUntil","VTRGoalkeeperSaving","VTRKeeperDiveAnimationLocked","VTRBlocking","VTRBlockUntil","VTRDribbleMoveUntil","VTRPostSkillVulnerableUntil","VTRStunnedUntil","VTRCannotRecoverBallUntil","VTRReceiverAssist","VTRPreparingReceive","VTRReceiveUntil","VTRReceiveTarget","VTRSetPieceWall","VTRWallJumpUntil","VTRPenaltyGuessSlot","VTRPenaltyGuessPoint","VTRSetPieceTaker","VTRForceIdle","VTRKickoffReady","VTRCornerTaker","VTRThrowInTaker"}do
			model:SetAttribute(attribute,nil)
		end
		local humanoid=model:FindFirstChildOfClass("Humanoid")
		local root=model:FindFirstChild("HumanoidRootPart")::BasePart?
		if humanoid then
			humanoid.PlatformStand=false
			humanoid.Sit=false
			humanoid.AutoRotate=true
			humanoid:Move(Vector3.zero,false)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		if root then
			root.Anchored=false
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
		session.MovementSpeeds[model]=0
	end

	self:_releasePlayersForLive(session)
	self:_stabilizePlayers(session)
	self:_syncPositions(session)
end

function Service:_startWorldCupExtraTime(session:any):boolean
	if not self:_isWorldCupKnockoutTiebreakMatch(session) or not self:_scoreTied(session) or session.ExtraTimeStarted==true then
		return false
	end

	session.ExtraTimeStarted=true
	session.ExtraTimeActive=true
	session.ExtraTimeCompleted=false
	session.ExtraTimeHalfPauseSeconds=EXTRA_TIME_HALF_PAUSE_SECONDS
	session.Clock=MatchClockService.new(EXTRA_TIME_TOTAL_SECONDS)
	session.Running=false
	session.Phase="EXTRA TIME"
	session.Paused=false
	session.ManualPaused=false
	session.HalfTimeTriggered=false

	self:_resetForExtraTimeKickoff(session)
	broadcast(self.State,session,{Type="ExtraTime",Phase="EXTRA TIME",Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,Duration=EXTRA_TIME_TOTAL_SECONDS,HalfPause=EXTRA_TIME_HALF_PAUSE_SECONDS})
	task.delay(2.25,function()
		if session.Ended or not session.ExtraTimeActive then return end
		self:_startSetPiece(session,"Kickoff","Home",session.World.PitchCFrame.Position)
	end)

	return true
end

function Service:_takeShootoutPenalty(session:any,side:string,round:number):boolean
	local team=session.Teams and session.Teams[side]
	local taker=team and team[((round-1)%math.max(1,#team))+1]
	local overall=tonumber(taker and taker:GetAttribute("overall"))or 72
	local sho=tonumber(taker and taker:GetAttribute("SHO"))or overall
	local pressure=round>5 and -4 or 0
	local chance=math.clamp(.58+(sho-70)*.006+pressure*.01,.48,.86)
	return math.random()<chance
end

function Service:_startWorldCupPenaltyShootout(session:any):boolean
	if not self:_isWorldCupKnockoutTiebreakMatch(session) or not self:_scoreTied(session) or session.PenaltyShootoutStarted==true then
		return false
	end

	session.PenaltyShootoutStarted=true
	session.Running=false
	session.Paused=false
	session.ManualPaused=false
	session.Phase="PENALTY SHOOTOUT"
	self:_setPlayersFrozen(session,true)
	if session.AI and session.AI.SetExternalPhase then session.AI:SetExternalPhase("PENALTY SHOOTOUT")end
	if session.Possession then session.Possession:Reset()end
	if session.World and session.World.Ball then
		session.World.Ball.AssemblyLinearVelocity=Vector3.zero
		session.World.Ball.AssemblyAngularVelocity=Vector3.zero
		session.World.Ball.Anchored=true
		session.World.Ball:SetAttribute("VTRWorldPaused",true)
	end

	local homePens=0
	local awayPens=0
	local rounds={}

	for round=1,5 do
		local homeScored=self:_takeShootoutPenalty(session,"Home",round)
		local awayScored=self:_takeShootoutPenalty(session,"Away",round)
		if homeScored then homePens+=1 end
		if awayScored then awayPens+=1 end
		table.insert(rounds,{Round=round,Home=homeScored,Away=awayScored,HomeTotal=homePens,AwayTotal=awayPens})
		local remaining=5-round
		if homePens>awayPens+remaining or awayPens>homePens+remaining then
			break
		end
	end

	local round=5
	while homePens==awayPens and round<12 do
		round+=1
		local homeScored=self:_takeShootoutPenalty(session,"Home",round)
		local awayScored=self:_takeShootoutPenalty(session,"Away",round)
		if homeScored then homePens+=1 end
		if awayScored then awayPens+=1 end
		table.insert(rounds,{Round=round,Home=homeScored,Away=awayScored,HomeTotal=homePens,AwayTotal=awayPens})
	end

	if homePens==awayPens then
		if math.random()<.5 then homePens+=1 else awayPens+=1 end
	end

	session.PenaltyShootout={Home=homePens,Away=awayPens,Rounds=rounds}
	session.PenaltyShootoutWinner=homePens>awayPens and"Home"or"Away"
	session.World.Ball:SetAttribute("VTRWorldPaused",nil)

	broadcast(self.State,session,{Type="PenaltyShootout",Phase="PENALTY SHOOTOUT",Home=session.World.HomeScore.Value,Away=session.World.AwayScore.Value,PenaltyHome=homePens,PenaltyAway=awayPens,Winner=session.PenaltyShootoutWinner,Rounds=rounds})
	task.delay(4.5,function()
		if not session.Ended then
			self:EndMatch(session.StepOwner,true)
		end
	end)

	return true
end

function Service:_resolveWorldCupKnockoutTiebreak(session:any):boolean
	if not self:_isWorldCupKnockoutTiebreakMatch(session) then
		return false
	end

	if not self:_scoreTied(session) then
		return false
	end

	if session.ExtraTimeStarted~=true then
		return self:_startWorldCupExtraTime(session)
	end

	session.ExtraTimeCompleted=true
	return self:_startWorldCupPenaltyShootout(session)
end
'''

if "_resolveWorldCupKnockoutTiebreak" not in text:
	m = re.search(r"\nfunction Service:_forceSecondHalfKickoffLive\(session:any\)[\s\S]*?\nend\n", text)
	if not m:
		raise SystemExit("could not find _forceSecondHalfKickoffLive")
	text = text[:m.end()] + helper + text[m.end():]

text = text.replace(
	"local halfTimeBreakSeconds=45",
	"local halfTimeBreakSeconds=session.ExtraTimeActive==true and (tonumber(session.ExtraTimeHalfPauseSeconds) or EXTRA_TIME_HALF_PAUSE_SECONDS) or 45"
)

text = text.replace(
	'payload.Type="HalfTime";payload.HalfTime=true;payload.PauseRemaining=halfTimeBreakSeconds;payload.Home=session.World.HomeScore.Value;payload.Away=session.World.AwayScore.Value;payload.Stats=session.Stats:Serialize(session.World.HomeScore.Value,session.World.AwayScore.Value,gameSeconds)',
	'payload.Type="HalfTime";payload.HalfTime=true;payload.ExtraTime=session.ExtraTimeActive==true;payload.PauseRemaining=halfTimeBreakSeconds;payload.Home=session.World.HomeScore.Value;payload.Away=session.World.AwayScore.Value;payload.Stats=session.Stats:Serialize(session.World.HomeScore.Value,session.World.AwayScore.Value,gameSeconds)'
)

text = text.replace(
	'broadcast(self.State,session,{Type="HalfTimeResume"})',
	'broadcast(self.State,session,{Type=session.ExtraTimeActive==true and "ExtraTimeResume" or "HalfTimeResume",ExtraTime=session.ExtraTimeActive==true})'
)

text = text.replace(
	'if target=="HalfTime"then\n\t\t\t\t\t\tself:_halfTime(session)\n\t\t\t\t\telse\n\t\t\t\t\t\tself:EndMatch(session.StepOwner,true)\n\t\t\t\t\tend',
	'if target=="HalfTime"then\n\t\t\t\t\t\tself:_halfTime(session)\n\t\t\t\t\telse\n\t\t\t\t\t\tif not self:_resolveWorldCupKnockoutTiebreak(session) then self:EndMatch(session.StepOwner,true) end\n\t\t\t\t\tend'
)

text = text.replace(
	"self:EndMatch(session.StepOwner,true)\n\t\t\t\t\tend\n\t\t\t\t\treturn\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\t\tif kind~=\"Kickoff\"then session.Clock:Record(kind)end",
	"if not self:_resolveWorldCupKnockoutTiebreak(session) then self:EndMatch(session.StepOwner,true) end\n\t\t\t\t\tend\n\t\t\t\t\treturn\n\t\t\t\tend\n\t\t\tend\n\t\tend\n\t\tif kind~=\"Kickoff\"then session.Clock:Record(kind)end"
)

text = text.replace(
	"self:EndMatch(session.StepOwner,true)\n\t\t\t\t\tend\n\t\t\t\t\treturn\n\t\t\t\tend\n\t\t\t\tself:_startSetPiece(session,pending.Kind,pending.Team,pending.Location)",
	"if not self:_resolveWorldCupKnockoutTiebreak(session) then self:EndMatch(session.StepOwner,true) end\n\t\t\t\t\tend\n\t\t\t\t\treturn\n\t\t\t\tend\n\t\t\t\tself:_startSetPiece(session,pending.Kind,pending.Team,pending.Location)"
)

text = text.replace(
	"self:EndMatch(session.StepOwner,true)\n\t\t\t\t\telseif session.FinalChance then",
	"if not self:_resolveWorldCupKnockoutTiebreak(session) then self:EndMatch(session.StepOwner,true) end\n\t\t\t\t\telseif session.FinalChance then"
)

text = text.replace(
	'elseif not self:_startFinalChance(session,"FullTime")then\n\t\t\t\t\t\t\tself:EndMatch(session.StepOwner,true)\n\t\t\t\t\t\tend',
	'elseif not self:_startFinalChance(session,"FullTime")then\n\t\t\t\t\t\t\tif not self:_resolveWorldCupKnockoutTiebreak(session) then self:EndMatch(session.StepOwner,true) end\n\t\t\t\t\t\tend'
)

text = text.replace(
	'local result="Draw"\n\t\t\t\t\tif session.RankedForceLossUserId==participant.UserId or session.ForfeitBy==participant.UserId then',
	'local result="Draw"\n\t\t\t\t\tlocal shootoutWinner=session.PenaltyShootoutWinner\n\t\t\t\t\tif shootoutWinner and homeScore==awayScore then\n\t\t\t\t\t\tresult=side==shootoutWinner and "Win" or "Loss"\n\t\t\t\t\telseif session.RankedForceLossUserId==participant.UserId or session.ForfeitBy==participant.UserId then'
)

text = text.replace(
	'RankedLossUserId=session.RankedForceLossUserId,Home=homeScore,Away=awayScore,Stats=resultStats,Reward=rewardPayload',
	'RankedLossUserId=session.RankedForceLossUserId,Home=homeScore,Away=awayScore,PenaltyShootout=session.PenaltyShootout,PenaltyShootoutWinner=session.PenaltyShootoutWinner,ExtraTime=session.ExtraTimeStarted==true,Stats=resultStats,Reward=rewardPayload'
)

path.write_text(text.strip() + "\n", encoding="utf-8")

print("patched src/server/Gameplay/MatchRuntimeService.lua")