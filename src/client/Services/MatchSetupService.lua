local MATCHUP_PANEL_DELAY = 0.85
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UserInputService=game:GetService("UserInputService")
local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local remote=ReplicatedStorage.VTR:WaitForChild(NetworkConfig.FolderName):WaitForChild(NetworkConfig.MatchFunction)::RemoteFunction
local Service={}
local function request(action:string,payload:any?):any local ok,response=pcall(function()return remote:InvokeServer(action,payload or{})end);if not ok or type(response)~="table"then return{Success=false,Message="Match setup service unavailable."}end;return response end
function Service:GetConfig():any return request("GetConfig")end
function Service:GetRoster(teamId:string):any return request("GetRoster",{TeamId=teamId})end
function Service:GetTeams(country:string,league:string):any return request("GetTeams",{Country=country,League=league})end
function Service:Save(setup:any):any return request("SaveSetup",setup)end
function Service:StartMatch():any return request("StartMatch")end
function Service:WatchMatch():any return request("WatchMatch")end
local function deviceType():string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return"Touch"end
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then return"Gamepad"end
	return"KeyboardMouse"
end
function Service:JoinRankedQueue():any return request("JoinRankedQueue",{DeviceType=deviceType()})end
function Service:LeaveRankedQueue():any return request("LeaveRankedQueue")end
function Service:GetRankedQueue():any return request("GetRankedQueue")end
function Service:ReturnToMenu():any return request("ReturnToMenu")end
return Service
