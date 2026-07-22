--!strict

local Service = {}

function Service.RequestTransfer(career: any, payload: any): (boolean, string, any?)
	payload = type(payload) == "table" and payload or {}
	career.Agent = type(career.Agent) == "table" and career.Agent or {}
	career.Agent.Requests = type(career.Agent.Requests) == "table" and career.Agent.Requests or {}
	local request = {Type = "Transfer", State = "Open", Reason = tostring(payload.Reason or "Playing time"), CreatedAt = os.time(), Window = "Next available"}
	career.Agent.Requests.Transfer = request
	career.Relationships = type(career.Relationships) == "table" and career.Relationships or {}
	career.Relationships.Agent = math.clamp((tonumber(career.Relationships.Agent) or 50) + 2, 0, 100)
	return true, "Transfer request submitted.", request
end

function Service.RequestLoan(career: any, payload: any): (boolean, string, any?)
	payload = type(payload) == "table" and payload or {}
	career.Agent = type(career.Agent) == "table" and career.Agent or {}
	career.Agent.Requests = type(career.Agent.Requests) == "table" and career.Agent.Requests or {}
	local request = {Type = "Loan", State = "Open", Reason = tostring(payload.Reason or "Development minutes"), CreatedAt = os.time(), Window = "Next available"}
	career.Agent.Requests.Loan = request
	return true, "Loan request submitted.", request
end

function Service.Withdraw(career: any, requestType: string): (boolean, string, any?)
	if not career.Agent or type(career.Agent.Requests) ~= "table" then return false, "No request to withdraw.", nil end
	local request = career.Agent.Requests[requestType]
	if type(request) ~= "table" or request.State ~= "Open" then return false, "No open request to withdraw.", nil end
	request.State = "Withdrawn"
	request.UpdatedAt = os.time()
	return true, requestType.." request withdrawn.", request
end

return Service
