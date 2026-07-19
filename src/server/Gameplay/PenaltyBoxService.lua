--!strict
local Workspace = game:GetService("Workspace")
local PitchConfig = require(script.Parent.PitchConfig)

local Service = {}

local HOME_NAMES = {"HomeBox", "HomePenaltyBox", "HomePenaltyArea", "Home18Box"}
local AWAY_NAMES = {"AwayBox", "AwayPenaltyBox", "AwayPenaltyArea", "Away18Box"}
local cachedHome: BasePart? = nil
local cachedAway: BasePart? = nil

local function findPart(names: {string}): BasePart?
	for _, name in ipairs(names) do
		local direct = Workspace:FindFirstChild(name)
		if direct and direct:IsA("BasePart") then
			return direct
		end
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") then
			for _, name in ipairs(names) do
				if descendant.Name == name then
					return descendant
				end
			end
		end
	end
	return nil
end

local function boxPart(boxId: string): BasePart?
	if boxId == "Home" then
		if cachedHome and cachedHome.Parent then
			return cachedHome
		end
		cachedHome = findPart(HOME_NAMES)
		return cachedHome
	end
	if cachedAway and cachedAway.Parent then
		return cachedAway
	end
	cachedAway = findPart(AWAY_NAMES)
	return cachedAway
end

local function insidePart(part: BasePart?, position: Vector3, padding: number?): boolean
	if not part then
		return false
	end
	local localPosition = part.CFrame:PointToObjectSpace(position)
	local pad = padding or 0
	return math.abs(localPosition.X) <= part.Size.X * 0.5 + pad
		and math.abs(localPosition.Y) <= part.Size.Y * 0.5 + math.max(pad, 8)
		and math.abs(localPosition.Z) <= part.Size.Z * 0.5 + pad
end

local function defensiveBoxId(teamId: string, options: any?): string
	local home = boxPart("Home")
	local away = boxPart("Away")
	if not home then
		return "Away"
	elseif not away then
		return "Home"
	end
	local homePitch = PitchConfig.WorldToTeamPitchPosition(home.Position, teamId, options)
	local awayPitch = PitchConfig.WorldToTeamPitchPosition(away.Position, teamId, options)
	return homePitch.Z < awayPitch.Z and "Home" or "Away"
end

local function fallbackBounds(): any
	local box = PitchConfig.Zones.OwnBox
	return {XMin = box.XMin, XMax = box.XMax, ZMin = box.ZMin, ZMax = box.ZMax}
end

local function partBoundsInTeamPitch(part: BasePart?, teamId: string, options: any?): any
	if not part then
		return fallbackBounds()
	end
	local xMin = math.huge
	local xMax = -math.huge
	local zMin = math.huge
	local zMax = -math.huge
	for _, xSign in ipairs({-1, 1}) do
		for _, zSign in ipairs({-1, 1}) do
			local world = part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X * .5 * xSign, 0, part.Size.Z * .5 * zSign))
			local pitch = PitchConfig.WorldToTeamPitchPosition(world, teamId, options)
			xMin = math.min(xMin, pitch.X)
			xMax = math.max(xMax, pitch.X)
			zMin = math.min(zMin, pitch.Z)
			zMax = math.max(zMax, pitch.Z)
		end
	end
	if xMin == math.huge then
		return fallbackBounds()
	end
	return {XMin = xMin, XMax = xMax, ZMin = zMin, ZMax = zMax}
end

function Service.IsInsideHomeBox(position: Vector3): boolean
	return insidePart(boxPart("Home"), position)
end

function Service.IsInsideAwayBox(position: Vector3): boolean
	return insidePart(boxPart("Away"), position)
end

function Service.IsInsideDefensiveBox(teamId: string, position: Vector3, options: any?): boolean
	return insidePart(boxPart(defensiveBoxId(teamId, options)), position)
end

function Service.IsInsideAttackingBox(teamId: string, position: Vector3, options: any?): boolean
	local defensive = defensiveBoxId(teamId, options)
	return insidePart(boxPart(defensive == "Home" and "Away" or "Home"), position)
end

function Service.IsNearDefensiveBox(teamId: string, position: Vector3, options: any?, padding: number?): boolean
	return insidePart(boxPart(defensiveBoxId(teamId, options)), position, padding or 28)
end

function Service.IsNearAttackingBox(teamId: string, position: Vector3, options: any?, padding: number?): boolean
	local defensive = defensiveBoxId(teamId, options)
	return insidePart(boxPart(defensive == "Home" and "Away" or "Home"), position, padding or 28)
end

function Service.DefensiveBoxMetrics(teamId: string, options: any?): any
	local bounds = partBoundsInTeamPitch(boxPart(defensiveBoxId(teamId, options)), teamId, options)
	local edgeZ = math.max(bounds.ZMin, bounds.ZMax)
	return {
		XMin = bounds.XMin,
		XMax = bounds.XMax,
		ZMin = bounds.ZMin,
		ZMax = bounds.ZMax,
		BoxEdgeZ = edgeZ,
		DefensiveEdgeAnchorZ = math.clamp(edgeZ + 22, edgeZ + 4, edgeZ + 42),
		EmergencyBoxAnchorZ = math.clamp(edgeZ - 48, 24, edgeZ - 10),
		SixYardAnchorZ = math.clamp(edgeZ * .34, 18, edgeZ - 38),
	}
end

return Service
