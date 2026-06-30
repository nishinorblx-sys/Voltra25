--!strict
local FormationService = require(script.Parent.FormationService)

local Service = {}

local function root(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function overlapLaneOpen(model: Model, opponents: {Model}, pitchCFrame: CFrame): boolean
	local modelRoot = root(model);if not modelRoot then return false end
	local modelLocal = pitchCFrame:PointToObjectSpace(modelRoot.Position)
	local attackSign = model:GetAttribute("VTRTeam") == "Home" and -1 or 1
	for _, opponent in opponents do
		local opponentRoot = root(opponent)
		if opponentRoot then
			local opponentLocal = pitchCFrame:PointToObjectSpace(opponentRoot.Position)
			local forward = (opponentLocal.Z - modelLocal.Z) * attackSign
			if forward > -3 and forward < 30 and math.abs(opponentLocal.X - modelLocal.X) < 11 then return false end
		end
	end
	return true
end

function Service.Assign(team: {Model}, owner: Model?, formationName: string, pitchCFrame: CFrame, positioning: number, opponents: {Model}?): {[Model]: string}
	local result: {[Model]: string} = {}
	if not owner then return result end
	local ownerRoot = root(owner)
	if not ownerRoot then return result end
	local ownerLocal = pitchCFrame:PointToObjectSpace(ownerRoot.Position)
	local candidates = {}
	local midfielders = {}
	for index, model in team do
		if model ~= owner then
			local modelRoot = root(model)
			local role = FormationService.GetAssignment(formationName, index).Role
			if modelRoot and role ~= "GK" then
				local distance = (modelRoot.Position - ownerRoot.Position).Magnitude
				table.insert(candidates, {Model = model, Role = role, Distance = distance, Index = index})
				if role == "CM" or role == "CAM" or role == "CDM" then table.insert(midfielders, candidates[#candidates]) end
			end
		end
	end
	table.sort(candidates, function(a, b) return a.Distance < b.Distance end)
	table.sort(midfielders, function(a, b) return a.Distance < b.Distance end)
	if midfielders[1] then result[midfielders[1].Model] = "ShortSupport" end
	if midfielders[2] then result[midfielders[2].Model] = "DiagonalSupport" end
	for _, entry in candidates do
		if result[entry.Model] then continue end
		local modelRoot = root(entry.Model) :: BasePart
		local localPosition = pitchCFrame:PointToObjectSpace(modelRoot.Position)
		if entry.Role == "ST" then
			result[entry.Model] = "ThroughRun"
		elseif entry.Role == "Winger" then
			result[entry.Model] = math.sign(localPosition.X) == math.sign(ownerLocal.X) and "WideRun" or "FarPostRun"
		elseif entry.Role == "Fullback" then
			result[entry.Model] = math.sign(localPosition.X) == math.sign(ownerLocal.X) and overlapLaneOpen(entry.Model, opponents or {}, pitchCFrame) and "Overlap" or "HoldWidth"
		elseif entry.Role == "CDM" then
			result[entry.Model] = "RecycleOption"
		elseif entry.Role == "CM" or entry.Role == "CAM" then
			result[entry.Model] = "DiagonalSupport"
		elseif entry.Role == "CB" then
			result[entry.Model] = "RecycleOption"
		else
			result[entry.Model] = "HoldShape"
		end
	end
	if not midfielders[1] and candidates[1] then result[candidates[1].Model] = "ShortSupport" end
	if not midfielders[2] and candidates[2] and result[candidates[2].Model] ~= "ShortSupport" then result[candidates[2].Model] = positioning > 0.58 and "DiagonalSupport" or "RecycleOption" end
	return result
end

return Service
