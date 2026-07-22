--!strict

local Service = {}

local function nextDate(day: number): string
	local base = os.time({year = 2026, month = 7, day = 1 + day, hour = 12})
	return os.date("!%Y-%m-%d", base)
end

function Service.GenerateFixtures(career: any)
	career.Calendar = type(career.Calendar) == "table" and career.Calendar or {}
	if type(career.Calendar.Fixtures) == "table" and #career.Calendar.Fixtures > 0 then return career.Calendar.Fixtures end
	local opponents = {"Neon Forge","Aurora City","Harbor Union","Metro Pulse","Northline FC","Cobalt Rovers","Summit Athletic","Eastgate"}
	local fixtures = {}
	for index, opponent in opponents do
		table.insert(fixtures, {Id = "lg_2026_"..tostring(index), Date = nextDate(index * 7), Home = index % 2 == 0 and career.Club or opponent, Away = index % 2 == 0 and opponent or career.Club, Opponent = opponent, Competition = "Voltra League", Completed = false})
	end
	career.Calendar.Fixtures = fixtures
	career.Calendar.NextActivity = fixtures[1] and fixtures[1].Id or "training"
	return fixtures
end

function Service.SimulateNextFixture(career: any, operationId: string): (boolean, string, any?)
	career.Ledgers = type(career.Ledgers) == "table" and career.Ledgers or {}
	career.Ledgers.ProcessedMatchResultIds = type(career.Ledgers.ProcessedMatchResultIds) == "table" and career.Ledgers.ProcessedMatchResultIds or {}
	if career.Ledgers.ProcessedMatchResultIds[operationId] then return true, "Fixture already simulated.", nil end
	local fixtures = Service.GenerateFixtures(career)
	local fixture = nil
	for _, item in fixtures do if item.Completed ~= true then fixture = item break end end
	if not fixture then return false, "No fixture available.", nil end
	local seed = math.abs((tonumber(career.Revision) or 1) * 7919 + #fixtures * 97)
	local rng = Random.new(seed)
	local homeGoals = rng:NextInteger(0, 3)
	local awayGoals = rng:NextInteger(0, 3)
	fixture.Completed = true
	fixture.Score = tostring(homeGoals).." - "..tostring(awayGoals)
	fixture.ResultId = operationId
	career.Ledgers.ProcessedMatchResultIds[operationId] = true
	career.Statistics = type(career.Statistics) == "table" and career.Statistics or {}
	career.Statistics.Career = type(career.Statistics.Career) == "table" and career.Statistics.Career or {}
	local stats = career.Statistics.Career
	stats.Appearances = (tonumber(stats.Appearances) or 0) + 1
	stats.Starts = (tonumber(stats.Starts) or 0) + 1
	stats.Minutes = (tonumber(stats.Minutes) or 0) + 90
	stats.AverageRating = math.clamp(((tonumber(stats.AverageRating) or 6) + rng:NextNumber(5.8, 8.2)) / 2, 1, 10)
	career.Stats = career.Stats or {}
	career.Stats.Appearances = stats.Appearances
	career.Calendar.CompletedFixtureIds = career.Calendar.CompletedFixtureIds or {}
	career.Calendar.CompletedFixtureIds[fixture.Id] = true
	for _, item in fixtures do if item.Completed ~= true then career.Calendar.NextActivity = item.Id return true, "Fixture simulated.", fixture end end
	career.Calendar.NextActivity = "season_review"
	return true, "Fixture simulated.", fixture
end

return Service
