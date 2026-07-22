--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TrainingConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerTrainingConfig)
local Progression = require(script.Parent.PlayerCareerProgressionService)

local Service = {}
Service.__index = Service

function Service.new()
	return setmetatable({}, Service)
end

function Service:StartSession(career: any, payload: any): (boolean, string, any?)
	local drillId = tostring(type(payload) == "table" and payload.DrillId or "film_room")
	local drill = TrainingConfig.Drills[drillId]
	if not drill then return false, "Choose a supported drill.", nil end
	if career.Condition and career.Condition.Injury and drillId ~= "recovery_rehab" then return false, "Only rehabilitation is available while injured.", nil end
	local now = os.time()
	local session = {
		TrainingSessionId = "tr_"..HttpService:GenerateGUID(false),
		CareerId = career.CareerId,
		DrillId = drillId,
		Difficulty = tostring(type(payload) == "table" and payload.Difficulty or "Normal"),
		Seed = math.abs((now * 1103515245 + career.Revision * 97) % 2147483647),
		IssuedAt = now,
		ExpiresAt = now + TrainingConfig.SessionExpirySeconds,
		AllowedObjectives = drill.Channels,
		MaxScore = 1000,
		Consumed = false,
	}
	career.Training = type(career.Training) == "table" and career.Training or {}
	career.Training.ActiveSession = session
	return true, "Training session created.", session
end

function Service:CompleteSession(career: any, payload: any): (boolean, string, any?)
	payload = type(payload) == "table" and payload or {}
	local session = career.Training and career.Training.ActiveSession
	if type(session) ~= "table" or tostring(payload.TrainingSessionId or "") ~= tostring(session.TrainingSessionId or "") then return false, "Training session not found.", nil end
	if session.Consumed == true then return false, "Training already consumed.", nil end
	if os.time() > (tonumber(session.ExpiresAt) or 0) then career.Training.ActiveSession = nil return false, "Training session expired.", nil end
	local score = math.clamp(math.floor(tonumber(payload.Score) or 0), 0, tonumber(session.MaxScore) or 1000)
	local grade = TrainingConfig.ScoreToGrade(score, tonumber(session.MaxScore) or 1000)
	local mastery = career.Training.DrillMastery or {}
	career.Training.DrillMastery = mastery
	local drillState = type(mastery[session.DrillId]) == "table" and mastery[session.DrillId] or {}
	local repetitions = math.max(0, tonumber(drillState.RepetitionsThisWeek) or 0)
	local granted = Progression.ApplyTrainingXP(career, session.AllowedObjectives, grade, repetitions)
	drillState.BestGrade = drillState.BestGrade or grade
	if (TrainingConfig.Grades[grade] or 0) > (TrainingConfig.Grades[drillState.BestGrade] or 0) then drillState.BestGrade = grade end
	drillState.RecentGrade = grade
	drillState.Mastery = math.clamp((tonumber(drillState.Mastery) or 0) + (TrainingConfig.Grades[grade] or 0) * 2, 0, 100)
	drillState.RepetitionsThisWeek = repetitions + 1
	drillState.FatigueCost = math.clamp(3 + (TrainingConfig.Grades[grade] or 0), 1, 12)
	drillState.Channels = session.AllowedObjectives
	drillState.LastPlayedAt = os.time()
	mastery[session.DrillId] = drillState
	session.Consumed = true
	career.Training.ActiveSession = nil
	career.Training.CompletedSessionIds = career.Training.CompletedSessionIds or {}
	table.insert(career.Training.CompletedSessionIds, 1, session.TrainingSessionId)
	while #career.Training.CompletedSessionIds > 80 do table.remove(career.Training.CompletedSessionIds) end
	career.Condition = career.Condition or {}
	career.Condition.Fatigue = math.clamp((tonumber(career.Condition.Fatigue) or 0) + drillState.FatigueCost, 0, 100)
	career.Condition.Sharpness = math.clamp((tonumber(career.Condition.Sharpness) or 50) + (TrainingConfig.Grades[grade] or 0), 0, 100)
	return true, "Training completed.", {Grade = grade, Score = score, XP = granted, Drill = drillState}
end

return Service
