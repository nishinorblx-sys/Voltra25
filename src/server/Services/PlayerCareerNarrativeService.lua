--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StoryConfig = require(ReplicatedStorage.VTR.Shared.PlayerCareerStoryConfig)

local Service = {}

function Service.QueueOpeningMessages(career: any)
	career.Story = type(career.Story) == "table" and career.Story or {}
	career.Story.Inbox = type(career.Story.Inbox) == "table" and career.Story.Inbox or {}
	career.Story.SocialFeed = type(career.Story.SocialFeed) == "table" and career.Story.SocialFeed or {}
	if #career.Story.Inbox == 0 then
		table.insert(career.Story.Inbox, 1, {Id = "welcome_coach", From = "Assistant Coach", Subject = "First Week Plan", Body = StoryConfig.CoachMessages[1], At = os.time(), Read = false})
	end
	if #career.Story.SocialFeed == 0 then
		table.insert(career.Story.SocialFeed, 1, {Id = "first_feed", Body = StoryConfig.SocialTemplates[1], At = os.time()})
	end
end

function Service.ChooseStoryOption(career: any, payload: any): (boolean, string, any?)
	payload = type(payload) == "table" and payload or {}
	local eventId = tostring(payload.EventId or "")
	local choiceId = tostring(payload.ChoiceId or "")
	local operationId = tostring(payload.OperationId or "")
	if eventId == "" or choiceId == "" or operationId == "" then return false, "Invalid story choice.", nil end
	career.Ledgers = type(career.Ledgers) == "table" and career.Ledgers or {}
	career.Ledgers.ProcessedStoryChoiceIds = type(career.Ledgers.ProcessedStoryChoiceIds) == "table" and career.Ledgers.ProcessedStoryChoiceIds or {}
	if career.Ledgers.ProcessedStoryChoiceIds[operationId] then return true, "Story choice already handled.", nil end
	local found = nil
	for _, event in StoryConfig.Events do if event.Id == eventId then found = event break end end
	if not found then return false, "Story event expired.", nil end
	local valid = false
	for _, choice in found.Choices do if choice.Id == choiceId then valid = true break end end
	if not valid then return false, "Choose a valid response.", nil end
	career.Ledgers.ProcessedStoryChoiceIds[operationId] = true
	career.Relationships = type(career.Relationships) == "table" and career.Relationships or {}
	career.Relationships.Manager = math.clamp((tonumber(career.Relationships.Manager) or 50) + (choiceId == "team_first" and 2 or 1), 0, 100)
	career.Story.CompletedNodes = type(career.Story.CompletedNodes) == "table" and career.Story.CompletedNodes or {}
	career.Story.CompletedNodes[eventId] = {ChoiceId = choiceId, At = os.time()}
	return true, "Response recorded.", {Manager = career.Relationships.Manager}
end

return Service
