from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

ranked_profile_path = Path("src/server/Services/RankedProfileService.lua")
ranked_profile = ranked_profile_path.read_text(encoding="utf-8")

ranked_profile = ranked_profile.replace(
'''function Service:RecordServerResult(player:Player,result:string,_legacyDelta:number,opponent:string,score:string,matchStats:any?):boolean
	if result=="ForfeitWin"then result="Win"elseif result=="ForfeitLoss"then result="Loss"end;if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;p.Ranked=p.Ranked or{};local r=p.Ranked;r.Wins=tonumber(r.Wins)or 0;r.Draws=tonumber(r.Draws)or 0;r.Losses=tonumber(r.Losses)or 0;r.DivisionWins=tonumber(r.DivisionWins)or 0;r.ProtectedWins=tonumber(r.ProtectedWins)or 0;r.DivisionNumber=tonumber(r.DivisionNumber)or 7;r.VoltraRating=tonumber(r.VoltraRating)or 1000;r.WinStreak=tonumber(r.WinStreak)or 0;r.History=r.History or{};r.PlayerStats=r.PlayerStats or{MatchesPlayed=0,AverageRating=0,Goals=0,Assists=0,MOTM=0,HatTricks=0};local delta=0''',
'''function Service:RecordServerResult(player:Player,result:string,_legacyDelta:number,opponent:string,score:string,matchStats:any?):boolean
	if result=="ForfeitWin"then result="Win"elseif result=="ForfeitLoss"then result="Loss"end;if result~="Win"and result~="Draw"and result~="Loss"then return false end;local p=self.Profiles:GetProfile(player);if not p then return false end;p.Ranked=p.Ranked or{};local r=p.Ranked;r.Wins=tonumber(r.Wins)or 0;r.Draws=tonumber(r.Draws)or 0;r.Losses=tonumber(r.Losses)or 0;r.DivisionWins=tonumber(r.DivisionWins)or 0;r.ProtectedWins=tonumber(r.ProtectedWins)or 0;r.DivisionNumber=tonumber(r.DivisionNumber)or 7;r.VoltraRating=tonumber(r.VoltraRating)or 1000;r.WinStreak=tonumber(r.WinStreak)or 0;r.History=r.History or{};r.PlayerStats=r.PlayerStats or{MatchesPlayed=0,AverageRating=0,Goals=0,Assists=0,MOTM=0,HatTricks=0};local resultId=type(matchStats)=="table"and tostring(matchStats.ResultId or "")or"";if resultId~=""then for _,entry in r.History do if tostring(entry.Id or "")==resultId then self.Publish(player,"Ranked",self:GetClientData(player));return false end end end;local delta=0''',
1
)

ranked_profile = ranked_profile.replace(
'''	table.insert(r.History,1,{Result=result,Opponent=string.sub(opponent,1,32),Score=string.sub(score,1,12),RPDelta=delta,At=os.time(),Stats=matchStats});while#r.History>20 do table.remove(r.History)end;self.Publish(player,"Ranked",self:GetClientData(player));return true''',
'''	table.insert(r.History,1,{Id=resultId~=""and resultId or nil,Result=result,Opponent=string.sub(opponent,1,32),Score=string.sub(score,1,12),RPDelta=delta,At=os.time(),Stats=matchStats});while#r.History>20 do table.remove(r.History)end;self.Publish(player,"Ranked",self:GetClientData(player));return true''',
1
)

ranked_profile_path.write_text(ranked_profile, encoding="utf-8", newline="\n")

ranked_queue_path = Path("src/server/Services/RankedQueueService.lua")
ranked_queue = ranked_queue_path.read_text(encoding="utf-8")

ranked_queue = ranked_queue.replace(
'''local MATCH_MAP = "VTR25_GlobalRankedMatches_v1"''',
'''local MATCH_MAP = "VTR25_GlobalRankedMatches_v1"
local RESULT_MAP = "VTR25_GlobalRankedResults_v1"''',
1
)

if "function Service:_resultMap()" not in ranked_queue:
    ranked_queue = ranked_queue.replace(
'''function Service:_matchMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(MATCH_MAP)
	end)
	return ok and map or nil
end''',
'''function Service:_matchMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(MATCH_MAP)
	end)
	return ok and map or nil
end

function Service:_resultMap(): any?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(RESULT_MAP)
	end)
	return ok and map or nil
end

function Service:_resultKey(player: Player): string
	return "ranked-result:" .. tostring(player.UserId)
end''',
1
    )

if "function Service:_publishMenuData(player: Player)" not in ranked_queue:
    ranked_queue = ranked_queue.replace(
'''function Service:_removeGlobal(player: Player)''',
'''function Service:_publishMenuData(player: Player)
	if self.Publish and self.RankedProfiles and self.RankedProfiles.GetClientData then
		pcall(function()
			self.Publish(player, "Ranked", self.RankedProfiles:GetClientData(player))
		end)
	end
	if self.Publish and self.Progression then
		if self.Progression.GetClientData then
			pcall(function()
				self.Publish(player, "Progression", self.Progression:GetClientData(player))
			end)
		end
		if self.Progression.Inventory and self.Progression.Inventory.GetClientData then
			pcall(function()
				self.Publish(player, "Inventory", self.Progression.Inventory:GetClientData(player))
			end)
		end
	end
end

function Service:_grantSpecificRankedPack(player: Player, packId: string?): boolean
	local id = tostring(packId or "bronze_pack")
	local granted = false
	if self.Progression and self.Progression.Inventory and self.Progression.Inventory.AddPack then
		local ok, result = pcall(function()
			return self.Progression.Inventory:AddPack(player, id, id, "RankedWin", 1)
		end)
		granted = ok and result ~= nil and result ~= false
	end
	if not granted then
		local reward = RankedWinPackReward.Grant(self.Progression, player, self.Publish)
		granted = type(reward) == "table" and reward.PackGranted == true
	end
	self:_publishMenuData(player)
	return granted
end

function Service:_writePendingRankedResult(player: Player, payload: any)
	local map = self:_resultMap()
	if not map then return end
	pcall(function()
		map:SetAsync(self:_resultKey(player), payload, 900, os.time())
	end)
end

function Service:_consumePendingRankedResult(player: Player)
	local map = self:_resultMap()
	if not map then return end
	local ok, payload = pcall(function()
		return map:GetAsync(self:_resultKey(player))
	end)
	if not ok or type(payload) ~= "table" then return end
	local profile = self.Profiles:GetProfile(player)
	if not profile then return end
	local result = tostring(payload.Result or "")
	local opponent = tostring(payload.Opponent or "Opponent")
	local score = tostring(payload.Score or "0-0")
	local resultId = tostring(payload.ResultId or payload.MatchId or "")
	local matchStats = type(payload.MatchStats) == "table" and payload.MatchStats or {}
	matchStats.ResultId = resultId
	local applied = self.RankedProfiles:RecordServerResult(player, result, 0, opponent, score, matchStats)
	if applied and (result == "Win" or result == "ForfeitWin") then
		self:_grantSpecificRankedPack(player, tostring(payload.PackId or "bronze_pack"))
	end
	self:_publishMenuData(player)
	pcall(function()
		map:RemoveAsync(self:_resultKey(player))
	end)
end

function Service:_removeGlobal(player: Player)''',
1
    )

ranked_queue = ranked_queue.replace(
'''	local function personal(side: string): any
			local best = nil''',
'''	session.MatchId = tostring(session.MatchId or HttpService:GenerateGUID(false))
	local function personal(side: string): any
			local best = nil''',
1
)

ranked_queue = ranked_queue.replace(
'''			return {
				PlayerRating = best and best.Rating or 6,
				Team = side,
				Match = side == "Home" and serialized.Home or serialized.Away,
				Full = serialized,
				MOTM = serialized.MOTM,
			}''',
'''			return {
				ResultId = session.MatchId .. ":" .. side,
				PlayerRating = best and best.Rating or 6,
				Team = side,
				Match = side == "Home" and serialized.Home or serialized.Away,
				Full = serialized,
				MOTM = serialized.MOTM,
			}''',
1
)

ranked_queue = ranked_queue.replace(
'''		self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, personal("Home"))
		self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), personal("Away"))
		if homeResult=="Win" or homeResult=="ForfeitWin" then session.RankedWinPackGrant(session,home) end
		if awayResult=="Win" or awayResult=="ForfeitWin" then session.RankedWinPackGrant(session,away) end''',
'''		local homePersonal = personal("Home")
		local awayPersonal = personal("Away")
		local homeApplied = self.RankedProfiles:RecordServerResult(home, homeResult, rpFor(homeResult), away.Name, score, homePersonal)
		local awayApplied = self.RankedProfiles:RecordServerResult(away, awayResult, rpFor(awayResult), home.Name, tostring(awayScore) .. "-" .. tostring(homeScore), awayPersonal)
		local homePack = nil
		local awayPack = nil
		if homeResult=="Win" or homeResult=="ForfeitWin" then homePack = session.RankedWinPackGrant(session,home) end
		if awayResult=="Win" or awayResult=="ForfeitWin" then awayPack = session.RankedWinPackGrant(session,away) end
		self:_writePendingRankedResult(home,{MatchId=session.MatchId,ResultId=homePersonal.ResultId,Result=homeResult,Opponent=away.Name,Score=score,MatchStats=homePersonal,PackId=homePack and homePack.PackId or nil,AppliedInMatchServer=homeApplied})
		self:_writePendingRankedResult(away,{MatchId=session.MatchId,ResultId=awayPersonal.ResultId,Result=awayResult,Opponent=home.Name,Score=tostring(awayScore).."-"..tostring(homeScore),MatchStats=awayPersonal,PackId=awayPack and awayPack.PackId or nil,AppliedInMatchServer=awayApplied})''',
1
)

ranked_queue = ranked_queue.replace(
'''			local serialized=ended.Stats:Serialize(homeScore,awayScore,ended.Clock:Payload().GameSeconds)''',
'''			ended.MatchId = tostring(ended.MatchId or session.MatchId or HttpService:GenerateGUID(false))
			session.MatchId = ended.MatchId
			local serialized=ended.Stats:Serialize(homeScore,awayScore,ended.Clock:Payload().GameSeconds)''',
1
)

ranked_queue = ranked_queue.replace(
'''				return{PlayerRating=best and best.Rating or 6,Team=side,Match=side=="Home"and serialized.Home or serialized.Away,Full=serialized,MOTM=serialized.MOTM}''',
'''				return{ResultId=session.MatchId..":"..side,PlayerRating=best and best.Rating or 6,Team=side,Match=side=="Home"and serialized.Home or serialized.Away,Full=serialized,MOTM=serialized.MOTM}''',
1
)

ranked_queue = ranked_queue.replace(
'''			self.RankedProfiles:RecordServerResult(home,homeResult,rpFor(homeResult),away.Name,score,personal("Home"))
			self.RankedProfiles:RecordServerResult(away,awayResult,rpFor(awayResult),home.Name,tostring(awayScore).."-"..tostring(homeScore),personal("Away"))''',
'''			local homePersonal=personal("Home")
			local awayPersonal=personal("Away")
			local homeApplied=self.RankedProfiles:RecordServerResult(home,homeResult,rpFor(homeResult),away.Name,score,homePersonal)
			local awayApplied=self.RankedProfiles:RecordServerResult(away,awayResult,rpFor(awayResult),home.Name,tostring(awayScore).."-"..tostring(homeScore),awayPersonal)
			self:_writePendingRankedResult(home,{MatchId=session.MatchId,ResultId=homePersonal.ResultId,Result=homeResult,Opponent=away.Name,Score=score,MatchStats=homePersonal,AppliedInMatchServer=homeApplied})
			self:_writePendingRankedResult(away,{MatchId=session.MatchId,ResultId=awayPersonal.ResultId,Result=awayResult,Opponent=home.Name,Score=tostring(awayScore).."-"..tostring(homeScore),MatchStats=awayPersonal,AppliedInMatchServer=awayApplied})''',
1
)

ranked_queue = ranked_queue.replace(
'''				if self.Progression then
					reward = self.Progression:GrantMatchRewards(participant, {
						Title = won and "RANKED VICTORY" or draw and "RANKED DRAW" or "RANKED MATCH",
						Coins = coins,
						XP = xp,
					})
				end''',
'''				if self.Progression then
					reward = self.Progression:GrantMatchRewards(participant, {
						Title = won and "RANKED VICTORY" or draw and "RANKED DRAW" or "RANKED MATCH",
						Coins = coins,
						XP = xp,
					})
				end''',
1
)

ranked_queue = ranked_queue.replace(
'''				local packReward=session.RankedWinRewards[participant.UserId]
				if not packReward then
					packReward=RankedWinPackReward.Grant(self.Progression,participant,self.Publish)
					session.RankedWinRewards[participant.UserId]=packReward
				end''',
'''				local packReward=session.RankedWinRewards[participant.UserId]
				if not packReward then
					packReward=RankedWinPackReward.Grant(self.Progression,participant,self.Publish)
					session.RankedWinRewards[participant.UserId]=packReward
				end
				local side = participant == home and "Home" or "Away"
				local resultId = tostring(session.MatchId or ended.MatchId or HttpService:GenerateGUID(false)) .. ":" .. side
				self:_writePendingRankedResult(participant,{MatchId=tostring(session.MatchId or ended.MatchId or ""),ResultId=resultId,Result=result,Opponent=participant==home and away.Name or home.Name,Score=participant==home and tostring(homeScore).."-"..tostring(awayScore) or tostring(awayScore).."-"..tostring(homeScore),MatchStats={ResultId=resultId,Team=side},PackId=packReward and packReward.PackId or nil})''',
1
)

ranked_queue = ranked_queue.replace(
'''				for player in self.GlobalQueued do''',
'''				for _, online in Players:GetPlayers() do
					if online:GetAttribute("VTRInMatch") ~= true then
						self:_consumePendingRankedResult(online)
					end
				end
				for player in self.GlobalQueued do''',
1
)

ranked_queue = ranked_queue.replace(
'''		session.PrivateRankedMatch = true
		session.ReturnPlaceId = tonumber(data.ReturnPlaceId) or tonumber(data.PlaceId) or game.PlaceId''',
'''		session.PrivateRankedMatch = true
		session.MatchId = tostring(data.MatchId or HttpService:GenerateGUID(false))
		session.ReturnPlaceId = tonumber(data.ReturnPlaceId) or tonumber(data.PlaceId) or game.PlaceId''',
1
)

ranked_queue_path.write_text(ranked_queue, encoding="utf-8", newline="\n")

camera_path = Path("src/client/Gameplay/BroadcastCameraController.lua")
camera = camera_path.read_text(encoding="utf-8")

camera = camera.replace(
'''	Pro = {Height = 115, Side = 145, Fov = 34, Smooth = 0.10},''',
'''	Pro = {Height = 16, Side = 34, Fov = 55, Smooth = 0.075},''',
1
)

if "function Controller:_updatePro" not in camera:
    camera = camera.replace(
'''function Controller:CycleMode(): string''',
'''function Controller:_updatePro(dt: number, root: BasePart)
	local move = self.CurrentMove or self.LastMove or root.CFrame.LookVector
	local flatMove = Vector3.new(move.X, 0, move.Z)
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local ballOffset = Vector3.new(self.Ball.Position.X - root.Position.X, 0, self.Ball.Position.Z - root.Position.Z)
	local forward = flatMove.Magnitude > .12 and flatMove.Unit or facing.Magnitude > .12 and facing.Unit or self.PitchCFrame.LookVector
	local ballBlend = ballOffset.Magnitude > 10 and math.clamp(ballOffset.Magnitude / 70, 0, .38) or 0
	local lookDirection = (forward * (1 - ballBlend) + (ballOffset.Magnitude > .1 and ballOffset.Unit or forward) * ballBlend)
	if lookDirection.Magnitude < .1 then lookDirection = forward end
	lookDirection = lookDirection.Unit
	local speed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	local distance = math.clamp(28 + speed * .34 + ballOffset.Magnitude * .06, 28, 43)
	local height = math.clamp(11.5 + speed * .05, 11.5, 16.5)
	local side = self.PitchCFrame.RightVector * math.clamp(ballOffset:Dot(self.PitchCFrame.RightVector) * .05, -3.2, 3.2)
	local desired = root.Position - lookDirection * distance + Vector3.new(0, height, 0) + side
	local target = root.Position + lookDirection * math.clamp(17 + speed * .18, 16, 26) + Vector3.new(0, 5.2, 0)
	if ballOffset.Magnitude < 38 then
		target = target:Lerp(self.Ball.Position + Vector3.new(0, 2.4, 0), .34)
	end
	local alpha = 1 - math.exp(-dt / .075)
	local current = self.Camera.CFrame.Position
	local position = current:Lerp(desired, alpha)
	self.Camera.CFrame = CFrame.lookAt(position, target, self.PitchCFrame.UpVector)
	local fov = math.clamp(55 + speed * .05 + math.clamp(ballOffset.Magnitude / 26, 0, 4), 55, 61)
	self.Camera.FieldOfView += (fov - self.Camera.FieldOfView) * (1 - math.exp(-dt / .12))
end

function Controller:CycleMode(): string''',
1
    )

camera = camera.replace(
'''	local preset = PRESETS[self.Mode]
	local ballPosition = self.Ball.Position''',
'''	if self.Mode == "Pro" then
		self:_updatePro(dt, root)
		return
	end
	local preset = PRESETS[self.Mode]
	local ballPosition = self.Ball.Position''',
1
)

camera_path.write_text(camera, encoding="utf-8", newline="\n")

print("fixed ranked teleport rewards and EA-style pro camera")