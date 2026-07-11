local MATCHUP_PANEL_DELAY = 0.85
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local RemoteResolver=require(script.Parent.RemoteResolver)
local AIMatchModePrompt=require(script:FindFirstAncestor("VTRClient").Components.AIMatchModePrompt)
local VoltraMatchTeleport=require(script:FindFirstAncestor("VTRClient").Components.VoltraMatchTeleport)
local remote=RemoteResolver.WaitForFunction(NetworkConfig.MatchFunction)
local Service={}
local lockedUntil:{[string]:number}={}
local loadingActions={
	StartMatch=true,
	WatchMatch=true,
	StartShootingPractice=true,
	StartWorldCupMatch=true,
	JoinRankedQueue=true,
	StartFiveVFiveLobby=true,
}
local function request(action:string,payload:any?):any
	if loadingActions[action] and (lockedUntil[action] or 0)>os.clock() then
		return{Success=false,Message="Already loading.",Data={AlreadyStarting=true}}
	end
	if loadingActions[action] then lockedUntil[action]=os.clock()+4 end
	local attempts=(action=="GetConfig"or action=="GetTeams"or action=="GetRoster"or action=="GetRankedLeaderboards")and 18 or 3
	local lastMessage="Match setup service unavailable."
	for attempt=1,attempts do
		local ok,response=pcall(function()return remote:InvokeServer(action,payload or{})end)
		if ok and type(response)=="table"then
			if loadingActions[action] and not response.Success then lockedUntil[action]=nil end
			if response.Success or attempt==attempts then return response end
			lastMessage=response.Message or response.Error or lastMessage
		elseif not ok then
			lastMessage=tostring(response)
		end
		task.wait(math.min(.18*attempt,1))
	end
	if loadingActions[action] then lockedUntil[action]=nil end
	return{Success=false,Message=lastMessage}
end
local function responseData(response:any):any
	if type(response)~="table"then return nil end
	return response.Data or response.Setup and response or response
end
local function isCampaignSetup():boolean
	local response=request("GetConfig")
	local data=responseData(response)
	local setup=data and data.Setup or data
	return type(setup)=="table" and type(setup.CampaignTeamId)=="string" and setup.CampaignTeamId~=""
end
local function startCampaignChoice():any
	local choice=AIMatchModePrompt.Choose()
	if choice=="Manual"then
		return VoltraMatchTeleport.Run("Manual Campaign Match",function()
			return request("StartMatch",{AIMatchTeleport=true,CampaignMode="Manual"})
		end)
	elseif choice=="Manage"then
		return VoltraMatchTeleport.Run("Manage Campaign Match",function()
			return request("WatchMatch",{AIMatchTeleport=true,CampaignMode="Manage"})
		end)
	end
	return{Success=false,Message="Match cancelled."}
end
function Service:GetConfig():any return request("GetConfig")end
function Service:GetRoster(teamId:string):any return request("GetRoster",{TeamId=teamId})end
function Service:GetTeams(country:string,league:string):any return request("GetTeams",{Country=country,League=league})end
function Service:Save(setup:any):any return request("SaveSetup",setup)end
function Service:StartMatch():any
	if isCampaignSetup()then
		return startCampaignChoice()
	end
	return VoltraMatchTeleport.Run("Loading Match",function()
		return request("StartMatch",{AIMatchTeleport=true,CampaignMode="Manual"})
	end)
end
function Service:WatchMatch():any
	if isCampaignSetup()then
		return startCampaignChoice()
	end
	return VoltraMatchTeleport.Run("Loading AI Match",function()
		return request("WatchMatch",{AIMatchTeleport=true,CampaignMode="Manage"})
	end)
end
function Service:StartShootingPractice():any
	return VoltraMatchTeleport.Run("Shooting Practice",function()
		return request("StartShootingPractice",{AIMatchTeleport=true})
	end)
end
function Service:GetWorldCup():any return request("GetWorldCup")end
function Service:BeginWorldCup(country:string):any return request("BeginWorldCup",{Country=country})end
function Service:ResetWorldCup():any return request("ResetWorldCup")end
function Service:EndWorldCup():any return request("EndWorldCup")end
function Service:ClaimWorldCupRewards():any return request("ClaimWorldCupRewards")end
function Service:ClaimWorldCupQuest(questId:string):any return request("ClaimWorldCupQuest",{QuestId=questId})end
function Service:StartWorldCupMatch():any
	return VoltraMatchTeleport.Run("World Cup Match",function()
		return request("StartWorldCupMatch",{AIMatchTeleport=true})
	end)
end
function Service:SimulateWorldCupMatch():any return request("SimulateWorldCupMatch")end
function Service:SimulateRestOfWorldCup():any return request("SimulateRestOfWorldCup")end
local function deviceType():string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return"Touch"end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then return"Gamepad"end
	return"KeyboardMouse"
end
function Service:JoinRankedQueue():any
	local player=Players.LocalPlayer
	if player and (player:GetAttribute("VTRInMatch")==true or (tonumber(player:GetAttribute("VTRRankedQueueLockedUntil"))or 0)>os.clock()) then
		return{Success=false,Message="Finish the current ranked match first."}
	end
	return VoltraMatchTeleport.Run("Ranked Queue",function()
		return request("JoinRankedQueue",{DeviceType=deviceType()})
	end)
end
function Service:StartCampaignMatch():any
	local choice=AIMatchModePrompt.Choose()
	if choice=="Manual"then
		return VoltraMatchTeleport.Run("Manual Campaign Match",function()
			return request("StartMatch",{AIMatchTeleport=true,CampaignMode="Manual"})
		end)
	elseif choice=="Manage"then
		return VoltraMatchTeleport.Run("Manage Campaign Match",function()
			return request("WatchMatch",{AIMatchTeleport=true,CampaignMode="Manage"})
		end)
	end
	return{Success=false,Message="Match cancelled."}
end
function Service:LeaveRankedQueue():any return request("LeaveRankedQueue")end
function Service:GetRankedQueue():any return request("GetRankedQueue")end
function Service:JoinFiveVFiveQueue():any return request("JoinFiveVFiveQueue",{DeviceType=deviceType()})end
function Service:LeaveFiveVFiveQueue():any return request("LeaveFiveVFiveQueue")end
function Service:RejoinFiveVFive():any return request("RejoinFiveVFive")end
function Service:GetFiveVFiveQueue():any return request("GetFiveVFiveQueue")end
function Service:GetPlayBuilder():any return request("GetPlayBuilder")end
function Service:SavePlayBuilder(payload:any):any return request("SavePlayBuilder",payload)end
function Service:CreateFiveVFiveLobby(payload:any):any return request("CreateFiveVFiveLobby",payload)end
function Service:ListFiveVFiveLobbies(query:string?):any return request("ListFiveVFiveLobbies",{Query=query or ""})end
function Service:JoinFiveVFiveLobby(payload:any):any return request("JoinFiveVFiveLobby",payload)end
function Service:RandomFiveVFiveLobby():any return request("RandomFiveVFiveLobby")end
function Service:AssignFiveVFiveLobbyPlayer(payload:any):any return request("AssignFiveVFiveLobbyPlayer",payload)end
function Service:KickFiveVFiveLobbyPlayer(payload:any):any return request("KickFiveVFiveLobbyPlayer",payload)end
function Service:StartFiveVFiveLobby():any
	return VoltraMatchTeleport.Run("PLAY Match",function()
		return request("StartFiveVFiveLobby")
	end)
end
function Service:GetRankedLeaderboards():any return request("GetRankedLeaderboards")end
function Service:ClaimRankedPathReward():any return request("ClaimRankedPathReward")end
function Service:DebugCompleteRankedPath():any return request("DebugCompleteRankedPath")end
function Service:ReturnToMenu():any return request("ReturnToMenu")end
return Service
