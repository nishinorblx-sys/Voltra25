from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

penalty_path = Path("src/client/Gameplay/PenaltyAimController.lua")
if penalty_path.exists():
    penalty = penalty_path.read_text(encoding="utf-8")

    if "function Controller:_correctedAimPoint" not in penalty:
        penalty = penalty.replace(
'''local Controller = {}
Controller.__index = Controller''',
'''local Controller = {}
Controller.__index = Controller

function Controller:_correctedAimPoint(rawPoint: Vector3): Vector3
	local data = self.Data or {}
	local pitch = data.PitchCFrame
	local width = tonumber(data.GoalWidth) or tonumber(data.Width) or 44
	local goalSign = tonumber(data.GoalSign) or 1
	local location = data.Location or data.BallPosition or rawPoint
	if typeof(pitch) ~= "CFrame" then return rawPoint end
	local localPoint = pitch:PointToObjectSpace(rawPoint)
	local localLocation = pitch:PointToObjectSpace(location)
	local dx = localPoint.X - localLocation.X
	local dy = localPoint.Y - localLocation.Y
	local targetX = math.clamp(dx * goalSign, -width * .48, width * .48)
	local targetY = math.clamp(dy, -7, 13)
	local goalZ = goalSign * ((tonumber(data.PitchLength) or 700) * .5)
	return pitch:PointToWorldSpace(Vector3.new(targetX, 7 + targetY, goalZ))
end

function Controller:_sendAimUpdate()
	if not self.Remote then return end
	local target = self:GetTarget()
	target = self:_correctedAimPoint(target)
	if os.clock() - (self.LastAimUpdate or 0) < .08 then return end
	self.LastAimUpdate = os.clock()
	self.Remote:FireServer({Type = "PenaltyAimUpdate", Target = target, AimPosition = target})
end''',
1
        )

    penalty = re.sub(
r'''function Controller:Update\((.*?)\)
(.*?)
end''',
lambda m: f'''function Controller:Update({m.group(1)})
{m.group(2)}
	self:_sendAimUpdate()
end''' if "_sendAimUpdate" not in m.group(2) else m.group(0),
penalty,
count=1,
flags=re.S
    )

    penalty = penalty.replace(
'''self.Remote:FireServer({Type="PenaltyKick",''',
'''local correctedPenaltyTarget = self:_correctedAimPoint(self:GetTarget())
self.Remote:FireServer({Type="PenaltyAimUpdate",Target=correctedPenaltyTarget,AimPosition=correctedPenaltyTarget})
self.Remote:FireServer({Type="PenaltyKick",AimPosition=correctedPenaltyTarget,Target=correctedPenaltyTarget,''',
1
    )

    penalty = penalty.replace(
'''Target=self:GetTarget()''',
'''Target=self:_correctedAimPoint(self:GetTarget())'''
    )

    penalty = penalty.replace(
'''AimPosition=self:GetTarget()''',
'''AimPosition=self:_correctedAimPoint(self:GetTarget())'''
    )

    penalty_path.write_text(penalty, encoding="utf-8", newline="\n")
else:
    print("skipped missing PenaltyAimController.lua")

keeper_candidates = [
    Path("src/client/Gameplay/PenaltyKeeperController.lua"),
    Path("src/client/Gameplay/PenaltyKeeperAimController.lua"),
    Path("src/client/Gameplay/GoalkeeperPenaltyController.lua"),
]

for path in keeper_candidates:
    if path.exists():
        text = path.read_text(encoding="utf-8")
        text = text.replace("Theme.Colors.Electric", "Color3.fromRGB(45, 155, 255)")
        text = text.replace('Color3.fromHex("B7FF1A")', "Color3.fromRGB(45, 155, 255)")
        text = text.replace('Color3.fromRGB(183, 255, 26)', "Color3.fromRGB(45, 155, 255)")
        text = text.replace('Color3.fromRGB(196, 255, 48)', "Color3.fromRGB(45, 155, 255)")
        text = text.replace('Color3.fromRGB(188, 255, 33)', "Color3.fromRGB(45, 155, 255)")
        path.write_text(text, encoding="utf-8", newline="\n")

team_path = Path("src/server/Gameplay/TeamControlService.lua")
team = team_path.read_text(encoding="utf-8")

if 'kind == "PenaltyAimUpdate"' not in team:
    team = team.replace(
'''	local kind = tostring(payload.Type or "")''',
'''	local kind = tostring(payload.Type or "")
	if kind == "PenaltyAimUpdate" then
		local target = payload.Target or payload.AimPosition
		if typeof(target) == "Vector3" then
			player:SetAttribute("VTRPenaltyAimX", target.X)
			player:SetAttribute("VTRPenaltyAimY", target.Y)
			player:SetAttribute("VTRPenaltyAimZ", target.Z)
			player:SetAttribute("VTRPenaltyAimUpdatedAt", os.clock())
			local activePenalty = self.Active[player]
			if activePenalty then
				activePenalty:SetAttribute("VTRPenaltyAimX", target.X)
				activePenalty:SetAttribute("VTRPenaltyAimY", target.Y)
				activePenalty:SetAttribute("VTRPenaltyAimZ", target.Z)
				activePenalty:SetAttribute("VTRPenaltyAimUpdatedAt", os.clock())
			end
		end
		return
	end''',
1
    )

team = team.replace(
'''elseif kind=="PenaltyKick"then''',
'''elseif kind=="PenaltyKick"then
		local penaltyAim = payload.Target or payload.AimPosition
		if typeof(penaltyAim) == "Vector3" then
			player:SetAttribute("VTRPenaltyAimX", penaltyAim.X)
			player:SetAttribute("VTRPenaltyAimY", penaltyAim.Y)
			player:SetAttribute("VTRPenaltyAimZ", penaltyAim.Z)
			player:SetAttribute("VTRPenaltyAimUpdatedAt", os.clock())
			active:SetAttribute("VTRPenaltyAimX", penaltyAim.X)
			active:SetAttribute("VTRPenaltyAimY", penaltyAim.Y)
			active:SetAttribute("VTRPenaltyAimZ", penaltyAim.Z)
			active:SetAttribute("VTRPenaltyAimUpdatedAt", os.clock())
		end''',
1
)

team_path.write_text(team, encoding="utf-8", newline="\n")

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

if "function Service:_latestPenaltyAim" not in runtime:
    runtime = runtime.replace(
'''function Service:_releaseAIPenalty(session:any)''',
'''function Service:_latestPenaltyAim(session:any, taker:Model?): Vector3?
	local source = taker
	local player = nil
	if taker then
		for participant, model in session.TeamControl.Active do
			if model == taker then
				player = participant
				break
			end
		end
	end
	local updated = source and tonumber(source:GetAttribute("VTRPenaltyAimUpdatedAt")) or 0
	if player then
		updated = math.max(updated, tonumber(player:GetAttribute("VTRPenaltyAimUpdatedAt")) or 0)
	end
	if os.clock() - updated > 12 then return nil end
	local x = source and tonumber(source:GetAttribute("VTRPenaltyAimX")) or nil
	local y = source and tonumber(source:GetAttribute("VTRPenaltyAimY")) or nil
	local z = source and tonumber(source:GetAttribute("VTRPenaltyAimZ")) or nil
	if player then
		x = tonumber(player:GetAttribute("VTRPenaltyAimX")) or x
		y = tonumber(player:GetAttribute("VTRPenaltyAimY")) or y
		z = tonumber(player:GetAttribute("VTRPenaltyAimZ")) or z
	end
	if x and y and z then
		return Vector3.new(x, y, z)
	end
	return nil
end

function Service:_releaseAIPenalty(session:any)''',
1
    )

runtime = re.sub(
r'''function Service:_releaseAIPenalty\(session:any\)
(.*?)
end

function Service:_releaseGoalKickClearance''',
lambda m: '''function Service:_releaseAIPenalty(session:any)
	local pending = session.PendingAIPenalty
	local taker = pending and pending.Taker or session.SetPieces and session.SetPieces.RestartTaker
	local aim = self:_latestPenaltyAim(session, taker)
	if aim and taker and taker.Parent then
		session.Possession:ForcePickup(taker)
		local direction = aim - ((taker:FindFirstChild("HumanoidRootPart") :: BasePart).Position)
		session.BallService:Kick(taker, "Shot", direction, 1, nil, "Penalty", direction.Magnitude, aim)
		if session.SetPieces and session.SetPieces.ReleaseRestartTaker then session.SetPieces:ReleaseRestartTaker() end
		session.PendingAIPenalty = nil
		session.OutOfBounds:Reset()
		session.Goals:Unlock()
		session.Phase = "IN PLAY"
		session.AI:SetExternalPhase(nil)
		self:_setPlayersFrozen(session, session.Paused == true)
		if not session.Paused then self:_releasePlayersForLive(session); self:_stabilizePlayers(session) end
		session.Running = true
		self:_syncPositions(session)
		broadcast(self.State, session, {Type = "Phase", Phase = "IN PLAY"})
		return
	end
''' + m.group(1) + '''
end

function Service:_releaseGoalKickClearance''',
runtime,
count=1,
flags=re.S
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

setpiece_path = Path("src/server/Gameplay/SetPieceService.lua")
setpiece = setpiece_path.read_text(encoding="utf-8")

if "VTRPenaltyGoalSign" not in setpiece:
    setpiece = setpiece.replace(
'''self.Remote:FireClient(player,{Type="PenaltyMode"''',
'''taker:SetAttribute("VTRPenaltyGoalSign", data.GoalSign or 1)
self.Remote:FireClient(player,{Type="PenaltyMode"''',
1
    )

setpiece = setpiece.replace(
'''GoalSign=data.GoalSign''',
'''GoalSign=data.GoalSign'''
)

setpiece_path.write_text(setpiece, encoding="utf-8", newline="\n")

print("fixed penalty aim side correction, blue keeper save reticle, and auto penalty uses current aim")