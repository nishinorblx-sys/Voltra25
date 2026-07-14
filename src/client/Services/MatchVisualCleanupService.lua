--!strict

local CollectionService = game:GetService("CollectionService")

local Service = {}
local TAG = "VTRMatchOwnedVisual"
local snapshots: {[Instance]: {[string]: any}} = setmetatable({}, {__mode = "k"}) :: any

function Service.RegisterTemporary(instance: Instance): Instance
	instance:SetAttribute("VTRMatchVisualTemporary", true)
	CollectionService:AddTag(instance, TAG)
	return instance
end

function Service.RegisterModified(instance: Instance, properties: {string})
	local snapshot = snapshots[instance]
	if not snapshot then
		snapshot = {}
		snapshots[instance] = snapshot
	end
	for _, property in properties do
		if snapshot[property] == nil then
			local ok, value = pcall(function()
				return (instance :: any)[property]
			end)
			if ok then snapshot[property] = value end
		end
	end
	instance:SetAttribute("VTRMatchVisualTemporary", false)
	CollectionService:AddTag(instance, TAG)
end

function Service.Apply(_world: Instance?)
	for _, instance in CollectionService:GetTagged(TAG) do
		local snapshot = snapshots[instance]
		if snapshot and instance.Parent then
			for property, value in snapshot do
				pcall(function()
					(instance :: any)[property] = value
				end)
			end
			snapshots[instance] = nil
			CollectionService:RemoveTag(instance, TAG)
			instance:SetAttribute("VTRMatchVisualTemporary", nil)
		elseif instance:GetAttribute("VTRMatchVisualTemporary") == true then
			snapshots[instance] = nil
			instance:Destroy()
		else
			CollectionService:RemoveTag(instance, TAG)
		end
	end
end

return Service
