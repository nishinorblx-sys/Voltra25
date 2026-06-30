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

return Service
