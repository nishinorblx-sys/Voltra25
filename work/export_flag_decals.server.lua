-- Run this in Roblox Studio Command Bar, or paste into a temporary ServerScript.
-- It scans a Workspace model that contains flag parts with Decals and prints a Lua table.

local FLAG_MODEL_NAME = "" -- Optional: put the exact Workspace model name here, e.g. "Flags"
local CREATE_MODULE = true -- Creates ReplicatedStorage.CountryFlagDecals with the generated table
local MODULE_NAME = "CountryFlagDecals"

local function normalizeKey(name: string): string
	local key = tostring(name or "")
	key = key:gsub("^%s+", ""):gsub("%s+$", "")
	key = key:gsub("[_%-%s]+Flag$", "")
	key = key:gsub("^Flag[_%-%s]+", "")
	key = key:gsub("_", " ")
	key = key:gsub("%s+", " ")
	return key
end

local function textureToAssetId(texture: string): string?
	texture = tostring(texture or "")
	if texture == "" then
		return nil
	end
	local id = texture:match("id=(%d+)") or texture:match("rbxassetid://(%d+)") or texture:match("(%d+)")
	if not id then
		return texture
	end
	return "rbxassetid://" .. id
end

local function findBestFlagModel(): Instance?
	if FLAG_MODEL_NAME ~= "" then
		return workspace:FindFirstChild(FLAG_MODEL_NAME, true)
	end

	local best: Instance? = nil
	local bestCount = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") or inst:IsA("Folder") then
			local decalCount = 0
			for _, child in ipairs(inst:GetDescendants()) do
				if child:IsA("Decal") or child:IsA("Texture") then
					decalCount += 1
				end
			end
			if decalCount > bestCount then
				best = inst
				bestCount = decalCount
			end
		end
	end
	return best
end

local function findCountryName(decal: Instance): string
	local parent = decal.Parent
	if parent and parent:IsA("BasePart") then
		return normalizeKey(parent.Name)
	end
	return normalizeKey(decal.Name)
end

local flagRoot = findBestFlagModel()
assert(flagRoot, "Could not find a Workspace model/folder with flag decals. Set FLAG_MODEL_NAME at the top.")

local flags = {}
for _, inst in ipairs(flagRoot:GetDescendants()) do
	if inst:IsA("Decal") or inst:IsA("Texture") then
		local assetId = textureToAssetId(inst.Texture)
		local country = findCountryName(inst)
		if assetId and country ~= "" then
			flags[country] = assetId
		end
	end
end

local keys = {}
for country in pairs(flags) do
	table.insert(keys, country)
end
table.sort(keys)

local lines = {
	"-- Generated from " .. flagRoot:GetFullName(),
	"return {",
}
for _, country in ipairs(keys) do
	table.insert(lines, string.format("\t[%q] = %q,", country, flags[country]))
end
table.insert(lines, "}")

local output = table.concat(lines, "\n")
print(output)
print(string.format("[Flag Export] Exported %d flags from %s", #keys, flagRoot:GetFullName()))

if typeof(setclipboard) == "function" then
	setclipboard(output)
	print("[Flag Export] Copied table to clipboard.")
end

if CREATE_MODULE then
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local old = ReplicatedStorage:FindFirstChild(MODULE_NAME)
	if old then
		old:Destroy()
	end
	local module = Instance.new("ModuleScript")
	module.Name = MODULE_NAME
	module.Source = output
	module.Parent = ReplicatedStorage
	print("[Flag Export] Created ReplicatedStorage." .. MODULE_NAME)
end
