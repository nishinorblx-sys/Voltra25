--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameplayConfig = require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local FocusController = require(script.Parent.Controllers.FocusController)
local MatchGameplayController = require(script.Parent.Gameplay.GameplayController)

FocusController.new():Start(Players.LocalPlayer:WaitForChild("PlayerGui"))
MatchGameplayController.new():Start()

if GameplayConfig.AutoStartTestMatch then
	local GameplayController = require(script.Parent.Controllers.GameplayController)
	GameplayController.new():Start()
else
	local UIController = require(script.Parent.Controllers.UIController)
	UIController.new():Start()
end
