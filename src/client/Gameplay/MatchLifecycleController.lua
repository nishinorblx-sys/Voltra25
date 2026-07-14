--!strict

local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Controller = {}
Controller.__index = Controller

local function countMap(values: {[any]: any}): number
	local count = 0
	for _ in values do count += 1 end
	return count
end

function Controller.new(label: string)
	return setmetatable({
		Label = label,
		Destroyed = false,
		Connections = {},
		RenderBindings = {},
		ActionBindings = {},
		TemporaryInstances = {},
		Tasks = {},
	}, Controller)
end

function Controller:TrackConnection(connection: RBXScriptConnection, category: string?): RBXScriptConnection
	if self.Destroyed then
		connection:Disconnect()
		return connection
	end
	self.Connections[connection] = category or "State"
	return connection
end

function Controller:TrackTemporary(instance: Instance): Instance
	if self.Destroyed then
		instance:Destroy()
		return instance
	end
	self.TemporaryInstances[instance] = true
	return instance
end

function Controller:BindRenderStep(name: string, priority: number, callback: (number) -> ())
	if self.Destroyed then return end
	RunService:UnbindFromRenderStep(name)
	self.RenderBindings[name] = true
	RunService:BindToRenderStep(name, priority, callback)
end

function Controller:UnbindRenderStep(name: string)
	RunService:UnbindFromRenderStep(name)
	self.RenderBindings[name] = nil
end

function Controller:BindActionAtPriority(name: string, callback: any, createTouchButton: boolean, priority: number, ...: Enum.KeyCode)
	if self.Destroyed then return end
	ContextActionService:UnbindAction(name)
	self.ActionBindings[name] = true
	ContextActionService:BindActionAtPriority(name, callback, createTouchButton, priority, ...)
end

function Controller:UnbindAction(name: string)
	ContextActionService:UnbindAction(name)
	self.ActionBindings[name] = nil
end

function Controller:Spawn(callback: (isCancelled: () -> boolean) -> ()): thread?
	if self.Destroyed then return nil end
	local job: thread
	job = task.defer(function()
		callback(function() return self.Destroyed end)
		self.Tasks[job] = nil
	end)
	self.Tasks[job] = true
	return job
end

function Controller:Delay(seconds: number, callback: () -> ()): thread?
	return self:Spawn(function(isCancelled)
		task.wait(math.max(0, seconds))
		if not isCancelled() then callback() end
	end)
end

function Controller:Snapshot(): any
	local inputConnections = 0
	local stateConnections = 0
	for connection, category in self.Connections do
		if connection.Connected then
			if category == "Input" then inputConnections += 1 else stateConnections += 1 end
		end
	end
	local temporaryGuis = 0
	local temporaryInstances = 0
	for instance in self.TemporaryInstances do
		if instance.Parent then
			temporaryInstances += 1
			if instance:IsA("LayerCollector") or instance:IsA("GuiObject") then temporaryGuis += 1 end
		end
	end
	return {
		StateConnections = stateConnections,
		InputConnections = inputConnections,
		RenderBindings = countMap(self.RenderBindings),
		ActionBindings = countMap(self.ActionBindings),
		TemporaryGuis = temporaryGuis,
		TemporaryInstances = temporaryInstances,
		Tasks = countMap(self.Tasks),
	}
end

function Controller:Destroy(): (any, any)
	local before = self:Snapshot()
	if self.Destroyed then return before, before end
	self.Destroyed = true
	local current = coroutine.running()
	for job in self.Tasks do if job ~= current then pcall(task.cancel, job) end end
	table.clear(self.Tasks)
	for connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
	for name in self.RenderBindings do RunService:UnbindFromRenderStep(name) end
	table.clear(self.RenderBindings)
	for name in self.ActionBindings do ContextActionService:UnbindAction(name) end
	table.clear(self.ActionBindings)
	for instance in self.TemporaryInstances do instance:Destroy() end
	table.clear(self.TemporaryInstances)
	local after = self:Snapshot()
	if workspace:GetAttribute("VTRLifecycleDiagnostics") == true and (RunService:IsStudio() or game.PrivateServerId ~= "") then
		warn(string.format("[VTR LIFECYCLE] %s before=%s after=%s", self.Label, game:GetService("HttpService"):JSONEncode(before), game:GetService("HttpService"):JSONEncode(after)))
	end
	return before, after
end

return Controller
