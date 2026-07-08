local PackInventoryConsumeService = {}

local consumed = setmetatable({}, { __mode = "k" })

local function str(value)
	if value == nil then
		return ""
	end
	return tostring(value)
end

local function nonempty(value)
	local s = str(value)
	return s ~= ""
end

local function dataOf(profile)
	if typeof(profile) == "table" and typeof(profile.Data) == "table" then
		return profile.Data
	end
	return profile
end

local function tableLooksLikeProfile(value)
	if typeof(value) ~= "table" then
		return false
	end

	return typeof(value.PackInventory) == "table"
		or typeof(value.Packs) == "table"
		or typeof(value.OwnedPacks) == "table"
		or typeof(value.Inventory) == "table"
		or typeof(value.Data) == "table"
end

local function packInstanceIdOf(pack)
	if typeof(pack) ~= "table" then
		return ""
	end

	return str(pack.packInstanceId or pack.PackInstanceId or pack.instanceId or pack.InstanceId or pack.guid or pack.Guid or pack.uid or pack.UID)
end

local function packIdOf(pack)
	if typeof(pack) == "string" then
		return pack
	end

	if typeof(pack) ~= "table" then
		return ""
	end

	return str(pack.packId or pack.PackId or pack.id or pack.Id or pack.name or pack.Name or pack.packName or pack.PackName)
end

local function matchesPack(pack, packInstanceId, packId)
	local wantedInstance = str(packInstanceId)
	local wantedPack = str(packId)

	if nonempty(wantedInstance) then
		local actualInstance = packInstanceIdOf(pack)
		if actualInstance ~= "" and actualInstance == wantedInstance then
			return true
		end

		if typeof(pack) == "string" and pack == wantedInstance then
			return true
		end
	end

	if nonempty(wantedPack) then
		local actualPack = packIdOf(pack)
		if actualPack ~= "" and actualPack == wantedPack then
			return true
		end

		if typeof(pack) == "string" and pack == wantedPack then
			return true
		end
	end

	return false
end

local function removeFromArray(list, packInstanceId, packId)
	if typeof(list) ~= "table" then
		return false
	end

	for index = #list, 1, -1 do
		if matchesPack(list[index], packInstanceId, packId) then
			table.remove(list, index)
			return true
		end
	end

	return false
end

local function removeFromMap(map, packInstanceId, packId)
	if typeof(map) ~= "table" then
		return false
	end

	local keys = {}

	if nonempty(packInstanceId) then
		table.insert(keys, str(packInstanceId))
	end

	if nonempty(packId) then
		table.insert(keys, str(packId))
	end

	for _, key in ipairs(keys) do
		local value = map[key]

		if typeof(value) == "number" then
			if value > 1 then
				map[key] = value - 1
			else
				map[key] = nil
			end
			return true
		elseif typeof(value) == "table" then
			local count = tonumber(value.Count or value.count or value.Quantity or value.quantity or value.Amount or value.amount)
			if count then
				if count > 1 then
					value.Count = count - 1
					value.count = value.count and count - 1 or value.count
					value.Quantity = value.Quantity and count - 1 or value.Quantity
					value.quantity = value.quantity and count - 1 or value.quantity
				else
					map[key] = nil
				end
				return true
			end
		elseif value ~= nil then
			map[key] = nil
			return true
		end
	end

	for key, value in pairs(map) do
		if matchesPack(value, packInstanceId, packId) then
			map[key] = nil
			return true
		end
	end

	return false
end

local function markConsumed(profile, token)
	if not nonempty(token) then
		return true
	end

	local data = dataOf(profile)
	if typeof(data) ~= "table" then
		return false
	end

	local now = os.clock()
	local bucket = consumed[data]

	if not bucket then
		bucket = {}
		consumed[data] = bucket
	end

	if bucket[token] and now - bucket[token] < 2 then
		return false
	end

	bucket[token] = now
	return true
end

function PackInventoryConsumeService.Remove(profile, packInstanceId, packId)
	local data = dataOf(profile)
	if typeof(data) ~= "table" then
		return false
	end

	packInstanceId = str(packInstanceId)
	packId = str(packId)

	local token = packInstanceId ~= "" and packInstanceId or packId
	if not markConsumed(profile, token) then
		return false
	end

	local removed = false

	removed = removeFromArray(data.PackInventory, packInstanceId, packId) or removed
	removed = removeFromArray(data.OwnedPacks, packInstanceId, packId) or removed
	removed = removeFromArray(data.UnopenedPacks, packInstanceId, packId) or removed
	removed = removeFromArray(data.InventoryPacks, packInstanceId, packId) or removed
	removed = removeFromMap(data.Packs, packInstanceId, packId) or removed
	removed = removeFromMap(data.PackCounts, packInstanceId, packId) or removed

	if typeof(data.Inventory) == "table" then
		removed = removeFromArray(data.Inventory.PackInventory, packInstanceId, packId) or removed
		removed = removeFromArray(data.Inventory.Packs, packInstanceId, packId) or removed
		removed = removeFromArray(data.Inventory.UnopenedPacks, packInstanceId, packId) or removed
		removed = removeFromMap(data.Inventory.PackCounts, packInstanceId, packId) or removed
	end

	if typeof(data.Items) == "table" then
		removed = removeFromMap(data.Items, packInstanceId, packId) or removed
	end

	if removed then
		data.UpdatedAt = os.time()
		data.LastOpenedPackId = packId
		data.LastOpenedPackInstanceId = packInstanceId
	end

	return removed
end

local function profileFromContext(context, player)
	if typeof(context) ~= "table" or not player then
		return nil
	end

	local tries = {
		function()
			return context.Profiles and context.Profiles.GetProfile and context.Profiles:GetProfile(player)
		end,
		function()
			return context.Progression and context.Progression.Profiles and context.Progression.Profiles.GetProfile and context.Progression.Profiles:GetProfile(player)
		end,
		function()
			return context.Inventory and context.Inventory.Profiles and context.Inventory.Profiles.GetProfile and context.Inventory.Profiles:GetProfile(player)
		end,
		function()
			return context.Store and context.Store.GetProfile and context.Store:GetProfile(player)
		end,
		function()
			return context.GetProfile and context:GetProfile(player)
		end,
	}

	for _, fn in ipairs(tries) do
		local ok, result = pcall(fn)
		if ok and typeof(result) == "table" then
			return result
		end
	end

	return nil
end

local function saveContext(context, player)
	if typeof(context) ~= "table" or not player then
		return
	end

	local tries = {
		function()
			if context.Profiles and context.Profiles.Store and context.Profiles.Store.SaveAsync then
				context.Profiles.Store:SaveAsync(player.UserId)
			end
		end,
		function()
			if context.Store and context.Store.SaveAsync then
				context.Store:SaveAsync(player.UserId)
			end
		end,
		function()
			if context.SaveAsync then
				context:SaveAsync(player.UserId)
			end
		end,
		function()
			if context.Save then
				context:Save(player)
			end
		end,
	}

	for _, fn in ipairs(tries) do
		pcall(fn)
	end
end

local function publishContext(context, player)
	if typeof(context) ~= "table" or not player then
		return
	end

	if context.Publish and context.Progression and context.Progression.Inventory and context.Progression.Inventory.GetClientData then
		pcall(function()
			context.Publish(player, "Inventory", context.Progression.Inventory:GetClientData(player))
		end)
	end

	if context.Publish and context.Inventory and context.Inventory.GetClientData then
		pcall(function()
			context.Publish(player, "Inventory", context.Inventory:GetClientData(player))
		end)
	end
end

local function readArg(value, state)
	if typeof(value) == "Instance" and value:IsA("Player") then
		state.player = state.player or value
		return
	end

	if typeof(value) == "table" then
		if not state.profile and tableLooksLikeProfile(value) then
			state.profile = value
		end

		local instanceId = value.packInstanceId or value.PackInstanceId or value.instanceId or value.InstanceId or value.uid or value.UID
		local packId = value.packId or value.PackId or value.id or value.Id or value.packName or value.PackName or value.name or value.Name

		if instanceId and not state.packInstanceId then
			state.packInstanceId = str(instanceId)
		end

		if packId and not state.packId then
			state.packId = str(packId)
		end

		for _, child in pairs(value) do
			if typeof(child) == "table" then
				readArg(child, state)
			end
		end

		return
	end

	if typeof(value) == "string" then
		local s = str(value)
		if s == "" then
			return
		end

		if not state.packInstanceId and (#s >= 10 or string.find(s, "-")) then
			state.packInstanceId = s
		end

		if not state.packId then
			state.packId = s
		end
	end
end

function PackInventoryConsumeService.ConsumeOpen(context, ...)
	local state = {
		player = nil,
		profile = nil,
		packInstanceId = nil,
		packId = nil,
	}

	for index = 1, select("#", ...) do
		readArg(select(index, ...), state)
	end

	if not state.profile then
		state.profile = profileFromContext(context, state.player)
	end

	if not state.profile then
		return false
	end

	local removed = PackInventoryConsumeService.Remove(state.profile, state.packInstanceId, state.packId)

	if removed then
		saveContext(context, state.player)
		publishContext(context, state.player)
	end

	return removed
end

return PackInventoryConsumeService
