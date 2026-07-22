--!strict

local HttpService = game:GetService("HttpService")

local Bridge = {}
Bridge.__index = Bridge

function Bridge.new(matchSetup: any?, matchRuntime: any?)
	return setmetatable({MatchSetup = matchSetup, MatchRuntime = matchRuntime}, Bridge)
end

function Bridge:StartCareerMatch(player: Player, career: any, payload: any): (boolean, string, any?)
	if career.Condition and career.Condition.Injury then return false, "Player is not medically cleared.", nil end
	career.MatchState = type(career.MatchState) == "table" and career.MatchState or {}
	if career.MatchState.PendingMatchToken then return true, "Career match already pending.", {Token = career.MatchState.PendingMatchToken} end
	local token = "pcm_"..HttpService:GenerateGUID(false)
	career.MatchState.PendingMatchToken = token
	career.MatchState.LaunchState = "Pending"
	career.MatchState.PlayerLockState = "PreMatch"
	career.MatchState.PendingFixture = tostring(type(payload) == "table" and payload.FixtureId or career.Calendar and career.Calendar.NextActivity or "")
	return true, "Career match prepared.", {
		PlayerCareer = true,
		CareerId = career.CareerId,
		CareerSlot = career.Slot,
		CareerPlayerId = career.CareerId,
		CareerFixtureId = career.MatchState.PendingFixture,
		CareerMatchToken = token,
		PlayerLocked = true,
		CareerPosition = career.Identity and career.Identity.PrimaryPosition or "ST",
		CareerRole = career.ClubState and career.ClubState.SquadRole or "Development Player",
		CareerSelectionStatus = "Starting",
		MatchMode = "PlayerCareer",
	}
end

function Bridge:ConsumeResult(career: any, resultId: string, result: any): (boolean, string, any?)
	career.Ledgers = type(career.Ledgers) == "table" and career.Ledgers or {}
	career.Ledgers.ProcessedMatchResultIds = type(career.Ledgers.ProcessedMatchResultIds) == "table" and career.Ledgers.ProcessedMatchResultIds or {}
	if career.Ledgers.ProcessedMatchResultIds[resultId] then return true, "Result already consumed.", nil end
	career.Ledgers.ProcessedMatchResultIds[resultId] = true
	career.MatchState = career.MatchState or {}
	career.MatchState.LastConsumedResult = resultId
	career.MatchState.PendingMatchToken = nil
	career.MatchState.LaunchState = "Complete"
	career.MatchState.PlayerLockState = "MatchComplete"
	return true, "Career result consumed.", result
end

return Bridge
