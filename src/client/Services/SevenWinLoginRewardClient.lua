local ReplicatedStorage = game:GetService("ReplicatedStorage")

local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
local Config = require(sharedFolder and sharedFolder:WaitForChild("SevenWinLoginRewardConfig") or ReplicatedStorage:WaitForChild("SevenWinLoginRewardConfig"))
local Panel = require(script.Parent.Parent.Components.SevenWinLoginRewardPanel)

local remotes = ReplicatedStorage:WaitForChild(Config.RemoteFolderName)
local pendingRemote = remotes:WaitForChild(Config.PendingRemoteName)
local confirmRemote = remotes:WaitForChild(Config.ConfirmRemoteName)

local started = false

local SevenWinLoginRewardClient = {}

function SevenWinLoginRewardClient.Start()
	if started then
		return
	end

	started = true

	pendingRemote.OnClientEvent:Connect(function(rewards, wins)
		if typeof(rewards) ~= "table" or #rewards == 0 then
			return
		end

		Panel.Show(rewards, wins, function()
			local ok = false
			local success = pcall(function()
				ok = confirmRemote:InvokeServer()
			end)

			return success and ok == true
		end)
	end)
end

SevenWinLoginRewardClient.Start()

return SevenWinLoginRewardClient
