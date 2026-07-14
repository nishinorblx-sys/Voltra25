--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)

local Evaluator = {}

local function projectEntry(stats: any, cardInstanceId: string?): any?
	if type(cardInstanceId) ~= "string" or cardInstanceId == "" then return nil end
	for _, entry in stats.PlayerRatings or {} do
		if entry.cardInstanceId == cardInstanceId or entry.CardInstanceId == cardInstanceId then return entry end
	end
	return nil
end

function Evaluator.Progress(fixture: any, teamStats: any, scoreFor: number, scoreAgainst: number, context: any): (number, boolean)
	local metric = fixture.ObjectiveMetric
	local target = tonumber(fixture.ObjectiveTarget) or 1
	local project = projectEntry(context.Stats or {}, context.ProjectCardInstanceId)
	local manager = context.Manager or {}
	local won = context.Result == "Win" or scoreFor > scoreAgainst
	local value = 0
	if metric == "PassesCompleted" then value = tonumber(teamStats.PassesCompleted) or 0
	elseif metric == "ShotsOnTarget" then value = tonumber(teamStats.ShotsOnTarget) or 0
	elseif metric == "Goals" then value = scoreFor
	elseif metric == "TacklesCompleted" then value = tonumber(teamStats.TacklesCompleted) or 0
	elseif metric == "Possession" then value = tonumber(teamStats.Possession) or 0
	elseif metric == "GoalsConcededMaximum" then value = scoreAgainst
	elseif metric == "Corners" then value = tonumber(teamStats.Corners) or 0
	elseif metric == "FoulsMaximum" then value = tonumber(teamStats.Fouls) or 0
	elseif metric == "GoalDifference" then value = scoreFor - scoreAgainst
	elseif metric == "ProjectGoals" then value = project and (tonumber(project.Goals) or 0) or 0
	elseif metric == "ProjectAssists" then value = project and (tonumber(project.Assists) or 0) or 0
	elseif metric == "ProjectRating" then value = project and (tonumber(project.Rating) or 0) or 0
	elseif metric == "ManagerTacticalChanges" then value = tonumber(manager.TacticalChanges) or 0
	elseif metric == "ManagerSubstitutions" then value = tonumber(manager.Substitutions) or 0
	elseif metric == "SecondHalfImprovement" then value = manager.SecondHalfImprovement == true and 1 or 0
	elseif metric == "WinAfterMentalityChange" then value = won and (tonumber(manager.MentalityChanges) or 0) > 0 and 1 or 0
	end
	local completed = if metric == "GoalsConcededMaximum" or metric == "FoulsMaximum" then value <= target else value >= target
	return value, completed
end

function Evaluator.ManagerQualified(manager: any): boolean
	return type(manager) == "table" and (tonumber(manager.Total) or 0) >= Config.Manager.RequiredInteractions and manager.AfterHalf == true
end

function Evaluator.EvaluateStars(fixture: any, stats: any, context: any): any
	local teamStats = stats.Home or {}
	local scoreFor = tonumber(stats.HomeScore) or 0
	local scoreAgainst = tonumber(stats.AwayScore) or 0
	local mode = context.Mode == "Manage" and "Manage" or "Manual"
	local won = context.Result == "Win" or scoreFor > scoreAgainst
	local managerQualified = mode ~= "Manage" or Evaluator.ManagerQualified(context.Manager)
	local meaningful = (tonumber(teamStats.PassesCompleted) or 0) + (tonumber(teamStats.Shots) or 0) + (tonumber(teamStats.TacklesCompleted) or 0) >= 2
	local completed = context.ValidFinish == true and context.Forfeit ~= true and managerQualified and (mode == "Manage" or meaningful)
	local progress, objectiveCompleted = Evaluator.Progress(fixture, teamStats, scoreFor, scoreAgainst, context)
	return {
		{ Id = "completion", Label = mode == "Manage" and "ACTIVE MANAGEMENT" or "MATCH PARTICIPATION", Earned = completed, Progress = completed and 1 or 0, Target = 1, Reason = completed and "Valid match completion" or mode == "Manage" and "Two valid changes, including one after halftime, were required" or "Complete the match with meaningful actions" },
		{ Id = "result", Label = "WIN THE FIXTURE", Earned = won, Progress = won and 1 or 0, Target = 1, Reason = won and "Fixture won" or "A win is required" },
		{ Id = "objective", Label = fixture.ObjectiveTitle, Earned = completed and objectiveCompleted, Progress = progress, Target = tonumber(fixture.ObjectiveTarget) or 1, Reason = completed and objectiveCompleted and fixture.ObjectiveDescription or "Objective not completed" },
	}
end

return Evaluator
