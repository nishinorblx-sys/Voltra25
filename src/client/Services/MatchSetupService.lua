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
local function request(action:string,payload:any?):any
	local attempts=(action=="GetConfig"or action=="GetTeams"or action=="GetRoster"or action=="GetRankedLeaderboards")and 18 or 3
	local lastMessage="Match setup service unavailable."
	for attempt=1,attempts do
		local ok,response=pcall(function()return remote:InvokeServer(action,payload or{})end)
		if ok and type(response)=="table"then
			if response.Success or attempt==attempts then return response end
			lastMessage=response.Message or response.Error or lastMessage
		elseif not ok then
			lastMessage=tostring(response)
		end
		task.wait(math.min(.18*attempt,1))
	end
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
		return request("StartShootingPractice",{PracticeMode="Shooting"})
	end)
end
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
	return request("JoinRankedQueue",{DeviceType=deviceType()})
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
function Service:GetRankedLeaderboards():any return request("GetRankedLeaderboards")end
function Service:ClaimRankedPathReward():any return request("ClaimRankedPathReward")end
function Service:DebugCompleteRankedPath():any return request("DebugCompleteRankedPath")end
function Service:ReturnToMenu():any return request("ReturnToMenu")end
return Service
