--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local MatchPresentationService = require(script.Parent.Parent.Services.MatchPresentationService)

local Teleport = {}

function Teleport.Run(title: string, callback: () -> any): any
	local handle = MatchPresentationService.BeginLoading(title, "BUILDING MATCH RUNTIME")
	TweenService:Create(handle.Fill, TweenInfo.new(.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(.72, 1)}):Play()
	task.wait(.12)
	local result = callback()
	local data = type(result) == "table" and (result.Data or result) or nil
	local runtimeStarted = type(data) == "table" and type(data.WorldName) == "string" and data.WorldName ~= ""
	if runtimeStarted then handle:SetProgress(1);handle:SetStatus("RUNTIME READY  /  LOADING ESSENTIALS") else MatchPresentationService.Complete(false) end
	return result
end

return Teleport
