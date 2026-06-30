--!strict

local NetworkClient = require(script.Parent.NetworkClient)

local ServiceClient = {}

function ServiceClient.create(serviceName: string)
	return table.freeze({
		Get = function(_: any) return NetworkClient:Request(serviceName) end,
		Observe = function(_: any, callback: (any) -> ()) return NetworkClient:Observe(serviceName, callback) end,
		GetCached = function(_: any) return NetworkClient.Cache[serviceName] end,
	})
end

return ServiceClient
