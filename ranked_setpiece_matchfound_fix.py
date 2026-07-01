from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

if "function Service:_autoReleaseSetPiece" not in runtime:
    runtime = runtime.replace(
'''function Service:_startSetPiece(session:any,kind:string,restartTeam:string,location:Vector3,forcedTaker:Model?)''',
'''function Service:_autoReleaseSetPiece(session:any,controller:Player?)
	if not session or session.Ended or session.Running then return end
	local phase=session.Phase
	if phase=="Corner" then
		local active=session.SetPieces and session.SetPieces.ActiveCorner
		if active and session.SetPieces._releaseCorner then
			local data=active.Data
			local target=data and data.PitchCFrame and data.PitchCFrame:PointToWorldSpace(Vector3.new(0,.15,(tonumber(data.GoalSign)or 1)*((tonumber(data.Length)or session.World.Length)*.5-18))) or session.World.Ball.Position
			session.SetPieces:_releaseCorner(active.Player,{Delivery="Cross",Power=.65,Target=target,ServerAI=true})
		end
	elseif phase=="FreeKick" then
		self:_releaseAIFieldRestart(session)
	elseif phase=="GoalKick" then
		self:_releaseGoalKickClearance(session,controller or session.StepOwner)
	elseif phase=="ThrowIn" then
		self:_releaseAIThrowIn(session)
	elseif phase=="Penalty" then
		self:_releaseAIPenalty(session)
	end
end

function Service:_startSetPiece(session:any,kind:string,restartTeam:string,location:Vector3,forcedTaker:Model?)''',
1
    )

runtime = replace_once(
    runtime,
'''	session.SetPieces:Start(controller,kind,restartTeam,location,function()
		if session.Ended then return end''',
'''	session.SetPieceAutoSeq=(session.SetPieceAutoSeq or 0)+1
	local setPieceAutoSeq=session.SetPieceAutoSeq
	session.SetPieces:Start(controller,kind,restartTeam,location,function()
		if session.Ended then return end''',
    "set piece sequence"
)

runtime = replace_once(
    runtime,
'''	end,sideController~=nil,forcedTaker)
	if kind=="Corner"and session.SetPieces.ActiveCorner then session.Animations:ForceIdle(session.SetPieces.ActiveCorner.Data.Taker)end''',
'''	end,sideController~=nil,forcedTaker)
	if kind~="Kickoff" then
		task.delay(10,function()
			if session.Ended or session.Running or session.SetPieceAutoSeq~=setPieceAutoSeq then return end
			if session.Phase==kind then
				self:_autoReleaseSetPiece(session,controller)
			end
		end)
	end
	if kind=="Corner"and session.SetPieces.ActiveCorner then session.Animations:ForceIdle(session.SetPieces.ActiveCorner.Data.Taker)end''',
    "10 second auto set piece"
)

runtime = replace_once(
    runtime,
'''		if releaseAction then
			if session.Phase=="FreeKick" and session.SetPieces and session.SetPieces.RestartMode=="LongFreeKick" and payload.Type~="Pass" then''',
'''		if releaseAction then
			local restartTeam=session.SetPieces and session.SetPieces.RestartTeam
			local playerSide=session.PlayerSides[player]or"Home"
			local penaltyKeeperAction=session.Phase=="Penalty" and payload.Type=="Shot" and restartTeam and playerSide~=restartTeam
			if restartTeam and playerSide~=restartTeam and not penaltyKeeperAction then
				self.State:FireClient(player,{Type="Info",Message="Opponent set piece. Waiting for their decision.",Important=true})
				return
			end
			if session.Phase=="FreeKick" and session.SetPieces and session.SetPieces.RestartMode=="LongFreeKick" and payload.Type~="Pass" then''',
    "set piece ownership guard"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

ranked_path = Path("src/server/Services/RankedQueueService.lua")
ranked = ranked_path.read_text(encoding="utf-8")

if 'local ReplicatedStorage = game:GetService("ReplicatedStorage")' not in ranked:
    ranked = ranked.replace(
        'local TeleportService = game:GetService("TeleportService")',
        'local TeleportService = game:GetService("TeleportService")\nlocal ReplicatedStorage = game:GetService("ReplicatedStorage")',
        1
    )

if "local function rankedFoundRemote" not in ranked:
    ranked = ranked.replace(
'''local TIMES = { "Day", "Evening", "Night" }''',
'''local TIMES = { "Day", "Evening", "Night" }

local function rankedFoundRemote(): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local remote = folder:FindFirstChild("RankedMatchFound")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "RankedMatchFound"
		remote.Parent = folder
	end
	return remote :: RemoteEvent
end''',
        1
    )

ranked = re.sub(
    r'function Service:_attachResultHandlers\(session: any, home: Player, away: Player\).*?end\n\nfunction Service:_pair',
'''function Service:_attachResultHandlers(session: any, home: Player, away: Player)
	session.RankedWinPackGrant=function(_,winner:Player)
		return RankedWinPackReward.Grant(self.Progression,winner,self.Publish)
	end
	local function resultFor(player: Player, side: string, homeScore: number, awayScore: number): string
		if session.RankedForceLossUserId==player.UserId or session.ForfeitBy==player.UserId then
			return "ForfeitLoss"
		elseif session.ForfeitBy then
			return "ForfeitWin"
		end
		if homeScore==awayScore then return "Draw" end
		local won=(side=="Home" and homeScore>awayScore)or(side=="Away" and awayScore>homeScore)
		return won and "Win" or "Loss"
	end
	local function rpFor(result: string): number
		if result=="Win" or result=="ForfeitWin" then return 35 end
		if result=="Draw" then return 12 end
		return -20
	end
	session.OnRankedEnded = function(ended: any)
		local homeScore = ended.World.HomeScore.Value
		local awayScore = ended.World.AwayScore.Value
		local homeResult = resultFor(home,"Home",homeScore,awayScore)
		local awayResult = resultFor(away,"Away",homeScore,awayScore)
		local score = tostring(homeScore) .. "-" .. tostring(awayScore)
		local serialized = ended.Stats:Serialize(homeScore, awayScore, ended.Clock:Payload().GameSeconds)
		local function updateObjectives(target: Player, side: string)
			local team = side == "Home" and serialized.Home or serialized.Away
			if self.Progression then self.Progression:UpdateObjectivesFromMatch(target, team) end
		end
		updateObjectives(home, "Home")
		updateObjectives(away, "Away")
		local function personal(side: string): any
			local best = nil
			for _, entry in serialized.PlayerRatings or {} do
				if entry.Team == side and (not best or entry.Rating > best.Rating) then best = entry end
			end
			return {
				PlayerRating = best and best.Rating or 6,
				Team = side,
				Match = side == "Home" and serialized.Home or serialized.Away,
				Full = serialized,
				MOTM = serialized.MOTM,
			}
		end
		self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, personal("Home"))
		self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), personal("Away"))
		if self.Publish and self.RankedProfiles.GetClientData then
			pcall(function()self.Publish(home,"Ranked",self.RankedProfiles:GetClientData(home))end)
			pcall(function()self.Publish(away,"Ranked",self.RankedProfiles:GetClientData(away))end)
		end
	end
	session.OnBeforeResult = function(ended: any)
		local rewards = {}
		local homeScore=ended.World.HomeScore.Value
		local awayScore=ended.World.AwayScore.Value
		local homeResult=resultFor(home,"Home",homeScore,awayScore)
		local awayResult=resultFor(away,"Away",homeScore,awayScore)
		for participant, result in {[home]=homeResult,[away]=awayResult} do
			local won=result=="Win" or result=="ForfeitWin"
			local draw=result=="Draw"
			local coins = 900 + (won and 900 or draw and 450 or 225)
			local xp = 140 + (won and 110 or draw and 55 or 25)
			local reward=nil
			if self.Progression then
				reward = self.Progression:GrantMatchRewards(participant, {
					Title = won and "RANKED VICTORY" or draw and "RANKED DRAW" or "RANKED MATCH",
					Coins = coins,
					XP = xp,
				})
			end
			if won then
				local packReward=RankedWinPackReward.Grant(self.Progression,participant,self.Publish)
				reward=reward or{}
				for key,value in packReward do
					reward[key]=value
				end
				reward.Title="RANKED VICTORY"
			end
			if reward then rewards[participant.UserId] = reward end
		end
		return rewards
	end
end

function Service:_pair''',
    ranked,
    count=1,
    flags=re.S
)

ranked = replace_once(
    ranked,
'''	self.Notifications:Send(player, "OPPONENT FOUND", "Reserved 1v1 match server ready.", "Info")
	local options = Instance.new("TeleportOptions")''',
'''	self.Notifications:Send(player, "OPPONENT FOUND", "Reserved 1v1 match server ready.", "Info")
	rankedFoundRemote():FireClient(player,{
		Opponent = player.UserId == tonumber(assignment.HomeUserId) and assignment.AwayName or assignment.HomeName,
		HomeName = assignment.HomeName,
		AwayName = assignment.AwayName,
		HomeTeamName = assignment.HomeTeamName,
		AwayTeamName = assignment.AwayTeamName,
		HomeOverall = assignment.HomeOverall,
		AwayOverall = assignment.AwayOverall,
		Role = assignment.Role,
		MatchId = assignment.MatchId,
	})
	task.wait(3.15)
	local options = Instance.new("TeleportOptions")''',
    "ranked match found before teleport"
)

ranked_path.write_text(ranked, encoding="utf-8", newline="\n")

app_path = Path("src/client/App.client.lua")
app = app_path.read_text(encoding="utf-8")

if 'local TweenService = game:GetService("TweenService")' not in app:
    app = app.replace(
        'local TeleportService = game:GetService("TeleportService")',
        'local TeleportService = game:GetService("TeleportService")\nlocal TweenService = game:GetService("TweenService")',
        1
    )

if "local function showRankedMatchFoundTeleport" not in app:
    app = app.replace(
'''FocusController.new():Start(Players.LocalPlayer:WaitForChild("PlayerGui"))
MatchGameplayController.new():Start()''',
'''FocusController.new():Start(Players.LocalPlayer:WaitForChild("PlayerGui"))
MatchGameplayController.new():Start()

local function showRankedMatchFoundTeleport(data:any)
	local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	local old=playerGui:FindFirstChild("VTRRankedTeleportFound")
	if old then old:Destroy()end
	local gui=Instance.new("ScreenGui")
	gui.Name="VTRRankedTeleportFound"
	gui.IgnoreGuiInset=true
	gui.ResetOnSpawn=false
	gui.DisplayOrder=500
	gui.Parent=playerGui
	local overlay=Instance.new("CanvasGroup")
	overlay.Size=UDim2.fromScale(1,1)
	overlay.BackgroundColor3=Theme.Colors.Black
	overlay.GroupTransparency=1
	overlay.ZIndex=500
	overlay.Parent=gui
	local title=Instance.new("TextLabel")
	title.BackgroundTransparency=1
	title.AnchorPoint=Vector2.new(.5,.5)
	title.Position=UDim2.fromScale(.5,.3)
	title.Size=UDim2.fromScale(.86,.1)
	title.Font=Theme.Fonts.Display
	title.Text="MATCH FOUND"
	title.TextColor3=Theme.Colors.Electric
	title.TextSize=46
	title.ZIndex=505
	title.Parent=overlay
	local sub=Instance.new("TextLabel")
	sub.BackgroundTransparency=1
	sub.AnchorPoint=Vector2.new(.5,.5)
	sub.Position=UDim2.fromScale(.5,.39)
	sub.Size=UDim2.fromScale(.8,.05)
	sub.Font=Theme.Fonts.Strong
	sub.Text="RANKED 1V1  /  VOLTRA SERVER LOCKED"
	sub.TextColor3=Theme.Colors.White
	sub.TextSize=12
	sub.ZIndex=505
	sub.Parent=overlay
	local vs=Instance.new("TextLabel")
	vs.BackgroundTransparency=1
	vs.AnchorPoint=Vector2.new(.5,.5)
	vs.Position=UDim2.fromScale(.5,.55)
	vs.Size=UDim2.fromScale(.82,.1)
	vs.Font=Theme.Fonts.Display
	vs.Text=string.upper(tostring(data.HomeTeamName or data.HomeName or"HOME")).."   VS   "..string.upper(tostring(data.AwayTeamName or data.AwayName or"AWAY"))
	vs.TextColor3=Theme.Colors.White
	vs.TextSize=28
	vs.ZIndex=505
	vs.Parent=overlay
	local core=Instance.new("Frame")
	core.AnchorPoint=Vector2.new(.5,.5)
	core.Position=UDim2.fromScale(.5,.55)
	core.Size=UDim2.fromOffset(28,28)
	core.BackgroundColor3=Theme.Colors.Electric
	core.BorderSizePixel=0
	core.Rotation=45
	core.ZIndex=504
	core.Parent=overlay
	local coreStroke=Instance.new("UIStroke")
	coreStroke.Color=Theme.Colors.White
	coreStroke.Thickness=2
	coreStroke.Transparency=.1
	coreStroke.Parent=core
	for index=1,28 do
		local ray=Instance.new("Frame")
		ray.AnchorPoint=Vector2.new(.5,.5)
		ray.Position=UDim2.fromScale(.5,.55)
		ray.Size=UDim2.fromOffset(math.random(8,22),math.random(80,180))
		ray.BackgroundColor3=index%3==0 and Theme.Colors.White or Theme.Colors.Electric
		ray.BackgroundTransparency=.22
		ray.BorderSizePixel=0
		ray.Rotation=(360/28)*index
		ray.ZIndex=502
		ray.Parent=overlay
		TweenService:Create(ray,TweenInfo.new(.78,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(.5,math.cos(math.rad(ray.Rotation))*math.random(180,470),.55,math.sin(math.rad(ray.Rotation))*math.random(80,260)),BackgroundTransparency=1,Size=UDim2.fromOffset(2,18)}):Play()
	end
	TweenService:Create(overlay,TweenInfo.new(.18),{GroupTransparency=0}):Play()
	TweenService:Create(core,TweenInfo.new(.8,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=UDim2.fromOffset(190,190),BackgroundTransparency=.88,Rotation=405}):Play()
	task.delay(2.8,function()
		if overlay.Parent then TweenService:Create(overlay,TweenInfo.new(.28),{GroupTransparency=1}):Play()end
		task.delay(.3,function()if gui.Parent then gui:Destroy()end end)
	end)
end

task.defer(function()
	local remotes=ReplicatedStorage:WaitForChild("Remotes",10)
	local rankedFound=remotes and remotes:WaitForChild("RankedMatchFound",10)
	if rankedFound and rankedFound:IsA("RemoteEvent")then
		rankedFound.OnClientEvent:Connect(showRankedMatchFoundTeleport)
	end
end)''',
        1
    )

app_path.write_text(app, encoding="utf-8", newline="\n")

print("patched set piece ownership, 10 second auto set pieces, ranked win/loss rewards, and pre-teleport match found animation")