--!strict

local MockProfileStore = {}
MockProfileStore.__index = MockProfileStore
local DataStoreService = game:GetService("DataStoreService")

local function deepCopy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[deepCopy(key)] = deepCopy(child) end
	return result
end

local function reconcile(data:any,template:any)
	for key,value in template do
		if data[key]==nil then data[key]=deepCopy(value)
		elseif type(value)=="table" and type(data[key])=="table" then reconcile(data[key],value) end
	end
	return data
end

function MockProfileStore.new(template: any, dataStoreName: string?)
	return setmetatable({ Template = template, Sessions = {}, Saved = {}, DataStore = dataStoreName and DataStoreService:GetDataStore(dataStoreName) or nil }, MockProfileStore)
end

function MockProfileStore:LoadAsync(userId: number): any
	assert(type(userId) == "number" and userId ~= 0, "Invalid userId")
	local data = self.Saved[userId] and deepCopy(self.Saved[userId]) or nil
	if not data and self.DataStore and userId > 0 then
		local ok,stored=pcall(function() return self.DataStore:GetAsync("player_"..userId) end)
		if ok and type(stored)=="table" then data=stored end
	end
	data=reconcile(data or deepCopy(self.Template),self.Template)
	self.Sessions[userId] = data
	return data
end

function MockProfileStore:Get(userId: number): any?
	return self.Sessions[userId]
end

function MockProfileStore:SaveAsync(userId: number): boolean
	local session = self.Sessions[userId]
	if not session then return false end
	self.Saved[userId] = deepCopy(session)
	if self.DataStore and userId > 0 then
		local snapshot=deepCopy(session)
		local ok=pcall(function() self.DataStore:UpdateAsync("player_"..userId,function() return snapshot end) end)
		if not ok then return false end
	end
	return true
end

function MockProfileStore:Release(userId: number)
	self:SaveAsync(userId)
	self.Sessions[userId] = nil
end

return MockProfileStore
