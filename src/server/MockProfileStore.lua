--!strict

local MockProfileStore = {}
MockProfileStore.__index = MockProfileStore
local DataStoreService = game:GetService("DataStoreService")
local SAVE_INTERVAL = 8

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
	return setmetatable({ Template = template, Sessions = {}, Saved = {}, DataStore = dataStoreName and DataStoreService:GetDataStore(dataStoreName) or nil, LastSaveAt = {}, PendingSnapshots = {}, SaveScheduled = {} }, MockProfileStore)
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

function MockProfileStore:_hasUpdateBudget(): boolean
	if not self.DataStore then return true end
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
	end)
	return not ok or (tonumber(budget) or 0) > 0
end

function MockProfileStore:_writeSnapshot(userId: number, snapshot: any): boolean
	if not self.DataStore or userId <= 0 then return true end
	if not self:_hasUpdateBudget() then return false end
	local ok = pcall(function()
		self.DataStore:UpdateAsync("player_" .. userId, function()
			return snapshot
		end)
	end)
	if ok then
		self.LastSaveAt[userId] = os.clock()
	end
	return ok
end

function MockProfileStore:_scheduleSave(userId: number)
	if self.SaveScheduled[userId] then return end
	self.SaveScheduled[userId] = true
	task.spawn(function()
		while self.PendingSnapshots[userId] do
			local elapsed = os.clock() - (self.LastSaveAt[userId] or 0)
			task.wait(math.max(1, SAVE_INTERVAL - elapsed))
			local snapshot = self.PendingSnapshots[userId]
			if not snapshot then break end
			if self:_writeSnapshot(userId, snapshot) then
				if self.PendingSnapshots[userId] == snapshot then
					self.PendingSnapshots[userId] = nil
				end
			else
				task.wait(3)
			end
		end
		self.SaveScheduled[userId] = nil
	end)
end

function MockProfileStore:SaveAsync(userId: number, force: boolean?): boolean
	local session = self.Sessions[userId]
	if not session then return false end
	local snapshot = deepCopy(session)
	self.Saved[userId] = snapshot
	if self.DataStore and userId > 0 then
		local elapsed = os.clock() - (self.LastSaveAt[userId] or 0)
		if force ~= true and elapsed < SAVE_INTERVAL then
			self.PendingSnapshots[userId] = snapshot
			self:_scheduleSave(userId)
			return true
		end
		if not self:_writeSnapshot(userId, snapshot) then
			self.PendingSnapshots[userId] = snapshot
			self:_scheduleSave(userId)
			return force ~= true
		end
	end
	return true
end

function MockProfileStore:Release(userId: number)
	self:SaveAsync(userId, true)
	self.Sessions[userId] = nil
end

return MockProfileStore
