--!strict
local function vtrLoadPackInventoryConsume()
	local current = script
	while current do
		local services = current:FindFirstChild("Services")
		if services and services:FindFirstChild("PackInventoryConsumeService") then
			return require(services:WaitForChild("PackInventoryConsumeService"))
		end

		if current.Parent then
			local sibling = current.Parent:FindFirstChild("Services")
			if sibling and sibling:FindFirstChild("PackInventoryConsumeService") then
				return require(sibling:WaitForChild("PackInventoryConsumeService"))
			end
		end

		current = current.Parent
	end

	return require(game:GetService("ServerScriptService"):WaitForChild("VTRServer"):WaitForChild("Services"):WaitForChild("PackInventoryConsumeService"))
end

local VTRPackInventoryConsume = vtrLoadPackInventoryConsume()
local VTRPendingPackAnimation = require(script.Parent.Parent.Services:WaitForChild("PendingPackAnimationService"))

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.VTR.Shared.Catalog)

local PackInstanceFactory = {}

function PackInstanceFactory.Create(packId: string, source: string?, purchasedAt: number?): any?
	local definition = Catalog.Packs[packId]
	if not definition then return nil end
	local instanceId = "pack_" .. HttpService:GenerateGUID(false)
	return {
		packInstanceId = instanceId,
		packId = packId,
		name = definition.Name,
		description = definition.Description or "VTR player pack",
		quantity = 1,
		status = "unopened",
		purchasedAt = purchasedAt or os.time(),
		openedAt = 0,
		source = source or "Reward",
		-- Compatibility aliases for older client surfaces.
		Id = packId,
		PackInstanceId = instanceId,
		Name = definition.Name,
		Description = definition.Description or "VTR player pack",
		Count = 1,
		Status = "unopened",
	}
end

function PackInstanceFactory.Hydrate(pack: any): boolean
	local packId = pack.packId or pack.Id
	local definition = Catalog.Packs[packId]
	if not definition then return false end
	pack.packInstanceId = pack.packInstanceId or pack.PackInstanceId or ("pack_" .. HttpService:GenerateGUID(false))
	pack.packId = packId
	pack.name = definition.Name
	pack.description = definition.Description or pack.description or pack.Description or "VTR player pack"
	pack.quantity = 1
	pack.status = pack.status or pack.Status or "unopened"
	if pack.status == "opening" and (tonumber(pack.openedAt) or 0) == 0 then pack.status = "unopened" end
	pack.purchasedAt = tonumber(pack.purchasedAt) or os.time()
	pack.openedAt = tonumber(pack.openedAt) or 0
	pack.source = pack.source or "Legacy"
	pack.Id = packId
	pack.PackInstanceId = pack.packInstanceId
	pack.Name = pack.name
	pack.Description = pack.description
	pack.Count = pack.status == "unopened" and 1 or 0
	pack.Status = pack.status
	return true
end

return PackInstanceFactory
