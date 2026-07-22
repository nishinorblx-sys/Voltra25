local Players = game:GetService("Players")
require(script.Parent.Services.VTRRemoteBootstrapService)
local ServerApp = require(script.Parent.ServerApp)

ServerApp.Start()

-- The UI kit is often tested in a completely empty place. Provide a safe,
-- invisible lobby only when the developer has not supplied a spawn of their own.
local existingSpawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)

if not existingSpawn then
	local lobby = Instance.new("Folder")
	lobby.Name = "VTR25FallbackLobby"
	lobby.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "SafetyFloor"
	floor.Anchored = true
	floor.CanCollide = true
	floor.Transparency = 1
	floor.Size = Vector3.new(512, 2, 512)
	floor.Position = Vector3.new(0, -2, 0)
	floor.Parent = lobby

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MenuSpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 1, 0)
	spawn.Parent = lobby

	local function keepCharacterSafe(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then return end

		root.CFrame = spawn.CFrame * CFrame.new(0, 4, 0)

		-- Catch a player if physics manages to push them beyond the fallback floor.
		local connection
		connection = root:GetPropertyChangedSignal("Position"):Connect(function()
			if not root.Parent then
				connection:Disconnect()
			elseif root.Position.Y < -20 then
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = spawn.CFrame * CFrame.new(0, 4, 0)
			end
		end)
	end

	local function bindPlayer(player)
		player.CharacterAdded:Connect(keepCharacterSafe)
		if player.Character then task.spawn(keepCharacterSafe, player.Character) end
	end

	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in Players:GetPlayers() do bindPlayer(player) end
end
