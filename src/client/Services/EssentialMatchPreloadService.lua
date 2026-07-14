--!strict

local ContentProvider = game:GetService("ContentProvider")

local loaded: {[string]: boolean} = {}

local function addAsset(output: {string}, seen: {[string]: boolean}, value: any)
	if type(value) ~= "string" or value == "" then return end
	if string.find(value, "rbxassetid://", 1, true) ~= 1 and string.find(value, "rbxasset://", 1, true) ~= 1 and string.find(value, "http", 1, true) ~= 1 then return end
	if seen[value] or loaded[value] then return end
	seen[value] = true
	table.insert(output, value)
end

local function collectInstance(output: {string}, seen: {[string]: boolean}, instance: Instance)
	local targets = {instance}
	for _, descendant in instance:GetDescendants() do table.insert(targets, descendant) end
	for _, item in targets do
		if item:IsA("Animation") then
			addAsset(output, seen, item.AnimationId)
		elseif item:IsA("Sound") then
			addAsset(output, seen, item.SoundId)
		elseif item:IsA("Decal") or item:IsA("Texture") then
			addAsset(output, seen, item.Texture)
		elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
			addAsset(output, seen, item.Image)
		elseif item:IsA("MeshPart") then
			addAsset(output, seen, item.MeshId)
			addAsset(output, seen, item.TextureID)
		elseif item:IsA("SpecialMesh") then
			addAsset(output, seen, item.MeshId)
			addAsset(output, seen, item.TextureId)
		elseif item:IsA("SurfaceAppearance") then
			addAsset(output, seen, item.ColorMap)
			addAsset(output, seen, item.MetalnessMap)
			addAsset(output, seen, item.NormalMap)
			addAsset(output, seen, item.RoughnessMap)
		end
	end
end

local function collectValue(output: {string}, seen: {[string]: boolean}, value: any, visited: {[any]: boolean}, depth: number)
	if depth > 7 then return end
	if typeof(value) == "Instance" then
		collectInstance(output, seen, value)
	elseif type(value) == "string" then
		addAsset(output, seen, value)
	elseif type(value) == "table" and not visited[value] then
		visited[value] = true
		for _, nested in value do collectValue(output, seen, nested, visited, depth + 1) end
	end
end

local Service = {}

function Service.Collect(values: {any}): {string}
	local output: {string} = {}
	local seen: {[string]: boolean} = {}
	local visited: {[any]: boolean} = {}
	for _, value in values do collectValue(output, seen, value, visited, 0) end
	return output
end

function Service.Begin(values: {any}, onProgress: ((number, number, number) -> ())?)
	local assets = Service.Collect(values)
	local completed = false
	local cancelled = false
	local processed: {[string]: boolean} = {}
	local processedCount = 0
	local total = #assets
	local function publish()
		if onProgress and not cancelled then onProgress(if total == 0 then 1 else processedCount / total, processedCount, total) end
	end
	publish()
	if total == 0 then
		completed = true
	else
		task.spawn(function()
			local ok = pcall(function()
				ContentProvider:PreloadAsync(assets, function(assetId: string, status: Enum.AssetFetchStatus)
					if cancelled or processed[assetId] then return end
					processed[assetId] = true
					processedCount += 1
					if status == Enum.AssetFetchStatus.Success then loaded[assetId] = true end
					publish()
				end)
			end)
			if not cancelled then
				if ok then
					for _, assetId in assets do
						if not processed[assetId] then
							processed[assetId] = true
							processedCount += 1
						end
					end
				end
				completed = true
				publish()
			end
		end)
	end
	local handle = {}
	function handle:Wait(timeout: number?): boolean
		local deadline = os.clock() + math.max(.1, tonumber(timeout) or 6)
		while not completed and not cancelled and os.clock() < deadline do task.wait(.03) end
		return completed
	end
	function handle:Cancel()
		cancelled = true
	end
	function handle:IsComplete(): boolean
		return completed
	end
	return handle
end

return Service
