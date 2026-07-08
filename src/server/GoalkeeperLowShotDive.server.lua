local ServerScriptService = game:GetService("ServerScriptService")

task.defer(function()
	local vtrServer = ServerScriptService:FindFirstChild("VTRServer")
	local gameplay = vtrServer and vtrServer:FindFirstChild("Gameplay")
	local module = gameplay and gameplay:FindFirstChild("GoalkeeperLowShotDiveService")

	if module and module:IsA("ModuleScript") then
		local ok, service = pcall(require, module)
		if ok and type(service) == "table" and service.Start then
			service:Start()
		end
	end
end)
