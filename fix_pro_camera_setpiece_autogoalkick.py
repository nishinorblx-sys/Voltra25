from pathlib import Path
import re

camera_path = Path("src/client/Gameplay/BroadcastCameraController.lua")
camera = camera_path.read_text(encoding="utf-8")

camera_function = '''function Controller:_updatePro(dt: number, root: BasePart)
	local side = tostring(self.Active and self.Active:GetAttribute("VTRTeam") or "Home")
	local half = tonumber(workspace:GetAttribute("VTRMatchHalf")) or 1
	local attackSign = side == "Home" and (half >= 2 and 1 or -1) or (half >= 2 and -1 or 1)
	local attackDirection = self.PitchCFrame:VectorToWorldSpace(Vector3.new(0, 0, attackSign))
	attackDirection = Vector3.new(attackDirection.X, 0, attackDirection.Z)
	attackDirection = attackDirection.Magnitude > .1 and attackDirection.Unit or Vector3.zAxis
	local right = self.PitchCFrame.RightVector
	right = Vector3.new(right.X, 0, right.Z)
	right = right.Magnitude > .1 and right.Unit or Vector3.xAxis
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local speed = velocity.Magnitude
	local forwardSpeed = velocity:Dot(attackDirection)
	local backRun = math.clamp(-forwardSpeed, 0, 36)
	local ballOffset = Vector3.new(self.Ball.Position.X - root.Position.X, 0, self.Ball.Position.Z - root.Position.Z)
	local ballForward = math.clamp(ballOffset:Dot(attackDirection), -8, 90)
	local ballSide = math.clamp(ballOffset:Dot(right), -34, 34)
	local distance = math.clamp(78 + speed * .22 + backRun * 1.15, 76, 128)
	local height = math.clamp(34 + speed * .07 + backRun * .16, 32, 56)
	local desired = root.Position - attackDirection * distance + right * math.clamp(ballSide * .16, -8, 8) + Vector3.new(0, height, 0)
	local targetAhead = math.clamp(56 + ballForward * .22, 48, 80)
	local target = root.Position + attackDirection * targetAhead + right * math.clamp(ballSide * .36, -14, 14) + Vector3.new(0, 6.5, 0)
	if ballForward > 2 and ballOffset.Magnitude < 58 then
		target = target:Lerp(self.Ball.Position + Vector3.new(0, 3.4, 0), .34)
	end
	self.ProCameraPosition = self.ProCameraPosition and self.ProCameraPosition:Lerp(desired, 1 - math.exp(-dt / .17)) or desired
	self.ProCameraTarget = self.ProCameraTarget and self.ProCameraTarget:Lerp(target, 1 - math.exp(-dt / .12)) or target
	self.Camera.CFrame = CFrame.lookAt(self.ProCameraPosition, self.ProCameraTarget, self.PitchCFrame.UpVector)
	local fov = math.clamp(47 + speed * .04 + backRun * .08, 47, 54)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / .18))
end'''

camera, count = re.subn(
	r'''function Controller:_updatePro\(dt: number, root: BasePart\)
.*?
end

function Controller:CycleMode''',
	camera_function + "\n\nfunction Controller:CycleMode",
	camera,
	count=1,
	flags=re.S
)

if count != 1:
	raise SystemExit("Could not replace Pro camera function.")

camera_path.write_text(camera, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

goalkick_function = '''function Service:_releaseGoalKickClearance(session:any,player:Player?)
	local setPieces=session.SetPieces
	local restartTaker=setPieces and setPieces.RestartTaker
	local active=player and session.TeamControl and session.TeamControl:GetActive(player)or nil
	local taker=(active and active==restartTaker and active)or restartTaker
	if not taker or not taker.Parent then return false end
	local takerRoot=modelRoot(taker)
	if not takerRoot then return false end
	session.World.Ball.Anchored=false
	session.World.Ball:SetNetworkOwner(nil)
	session.Possession:ForcePickup(taker)
	local pitch=session.World.PitchCFrame
	local localTaker=pitch:PointToObjectSpace(takerRoot.Position)
	local goalSign=localTaker.Z>=0 and 1 or -1
	local team=tostring(taker:GetAttribute("VTRTeam")or"Home")
	local bestReceiver:Model?=nil
	local bestScore=-math.huge
	local fallback:Model?=nil
	local fallbackScore=-math.huge
	for _,candidate in session.Teams[team]or{}do
		if candidate~=taker and candidate:GetAttribute("VTRSentOff")~=true and tostring(candidate:GetAttribute("position")or"")~="GK"then
			local candidateRoot=modelRoot(candidate)
			if candidateRoot then
				local localCandidate=pitch:PointToObjectSpace(candidateRoot.Position)
				local centerScore=120-math.abs(localCandidate.Z)-math.abs(localCandidate.X)*.38
				local role=tostring(candidate:GetAttribute("position")or"")
				local roleBonus=(role=="CDM"or role=="CM"or role=="CAM"or role=="ST")and 18 or 0
				local rating=(tonumber(candidate:GetAttribute("overall"))or 60)*.08
				local score=centerScore+roleBonus+rating
				if score>fallbackScore then
					fallbackScore=score
					fallback=candidate
				end
				if math.abs(localCandidate.Z)<=session.World.Length*.18 and math.abs(localCandidate.X)<=session.World.Width*.34 and score>bestScore then
					bestScore=score
					bestReceiver=candidate
				end
			end
		end
	end
	bestReceiver=bestReceiver or fallback
	local receiverRoot=bestReceiver and modelRoot(bestReceiver)
	local target:Vector3
	local distance:number
	if receiverRoot then
		local receiverLocal=pitch:PointToObjectSpace(receiverRoot.Position)
		local lead=math.clamp((receiverRoot.Position-takerRoot.Position).Magnitude*.10,8,18)
		local targetLocal=Vector3.new(
			math.clamp(receiverLocal.X,-session.World.Width*.30,session.World.Width*.30),
			3.2,
			math.clamp(receiverLocal.Z-goalSign*lead,-session.World.Length*.12,session.World.Length*.12)
		)
		target=pitch:PointToWorldSpace(targetLocal)
	else
		target=pitch:PointToWorldSpace(Vector3.new(0,3.2,-goalSign*session.World.Length*.06))
	end
	local direction=target-takerRoot.Position
	if direction.Magnitude<1 then direction=pitch:VectorToWorldSpace(Vector3.new(0,0,-goalSign))end
	distance=Vector3.new(direction.X,0,direction.Z).Magnitude
	if session.BallService and session.BallService.Last then session.BallService.Last[taker]={}end
	local released=session.BallService:Kick(taker,"Pass",direction,math.clamp(distance/185,.74,.96),bestReceiver,"Lofted",distance,target)
	if bestReceiver and released then
		bestReceiver:SetAttribute("VTRReceiveTarget",target)
		bestReceiver:SetAttribute("VTRPreparingReceive",true)
		bestReceiver:SetAttribute("VTRReceiveUntil",os.clock()+5.2)
		bestReceiver:SetAttribute("VTRReceiveLockedAt",os.clock())
	end
	if setPieces and setPieces.ReleaseRestartTaker then setPieces:ReleaseRestartTaker()end
	session.OutOfBounds:Reset();session.Goals:Unlock();session.Phase="IN PLAY";session.AI:SetExternalPhase(nil);self:_setPlayersFrozen(session,session.Paused==true);if not session.Paused then self:_releasePlayersForLive(session);self:_stabilizePlayers(session)end;session.Running=true;self:_syncPositions(session);broadcast(self.State,session,{Type="Phase",Phase="IN PLAY"})
	return true
end'''

runtime, count = re.subn(
	r'''function Service:_releaseGoalKickClearance\(session:any,player:Player\?\)
.*?
end

function Service:_releaseAIThrowIn''',
	goalkick_function + "\n\nfunction Service:_releaseAIThrowIn",
	runtime,
	count=1,
	flags=re.S
)

if count != 1:
	raise SystemExit("Could not replace goal kick release function.")

if "VTRSetPieceAutoDecisionDelay" not in runtime:
	runtime = runtime.replace(
'''	if kind=="Corner"and session.SetPieces.ActiveCorner then session.Animations:ForceIdle(session.SetPieces.ActiveCorner.Data.Taker)end''',
'''	if kind~="Kickoff"then
		local autoDelay=tonumber(workspace:GetAttribute("VTRSetPieceAutoDecisionDelay"))or 10
		task.delay(autoDelay,function()
			if session.Ended or session.Running or session.SetPieceAutoSeq~=setPieceAutoSeq or session.Phase~=kind then return end
			self:_autoReleaseSetPiece(session,controller)
		end)
	end
	if kind=="Corner"and session.SetPieces.ActiveCorner then session.Animations:ForceIdle(session.SetPieces.ActiveCorner.Data.Taker)end''',
1
	)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

print("fixed smoother zoomed-back pro camera, restored 10 second set-piece auto decision, and made goal kicks lob to a center player")