local ServerScriptService = game:GetService("ServerScriptService")

task.defer(function()
	local vtrServer = ServerScriptService:FindFirstChild("VTRServer")
	local services = vtrServer and vtrServer:FindFirstChild("Services")

	if not services then
		return
	end

	local module = services:FindFirstChild("WorldCampaignWinProgressService")
	if not module then
		return
	end

	pcall(require, module)
end)
