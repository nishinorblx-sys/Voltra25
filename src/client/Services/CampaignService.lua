--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local NetworkConfig = require(ReplicatedStorage.VTR.Shared.NetworkConfig)
local RemoteResolver = require(script.Parent.RemoteResolver)
local VoltraMatchTeleport = require(script:FindFirstAncestor("VTRClient").Components.VoltraMatchTeleport)

local remote = RemoteResolver.WaitForFunction(NetworkConfig.MatchFunction)
local Service = {}
local locks: { [string]: number } = {}

local readActions = {
	GetCampaignState = true,
	GetCampaignEligibleProjects = true,
	GetCampaignHistory = true,
	GetCampaignMastery = true,
}

local loadingActions = {
	StartCampaignPlacement = true,
	StartCampaignFixture = true,
	StartCampaignMasteryFixture = true,
	ResumeCampaignMatch = true,
}

local function normalize(response: any, fallback: string): any
	if type(response) ~= "table" then return { Success = false, Message = fallback } end
	return { Success = response.Success == true, Message = tostring(response.Message or fallback), Data = response.Data }
end

local function request(action: string, payload: any?): any
	local now = os.clock()
	if loadingActions[action] and (locks[action] or 0) > now then return { Success = false, Message = "Already loading.", Data = { AlreadyStarting = true } } end
	if locks[action] and locks[action] > now then return { Success = false, Message = "Please wait." } end
	locks[action] = now + (loadingActions[action] and 4 or readActions[action] and 0.1 or 0.35)
	local attempts = readActions[action] and 5 or 2
	local fallback = "Ascension service unavailable."
	for attempt = 1, attempts do
		local ok, response = pcall(function() return remote:InvokeServer(action, payload or {}) end)
		if ok and type(response) == "table" then
			local result = normalize(response, fallback)
			if result.Success or attempt == attempts then
				if not result.Success then locks[action] = nil end
				return result
			end
			fallback = result.Message
		elseif not ok then
			fallback = tostring(response)
		end
		task.wait(readActions[action] and math.min(0.15 * attempt, 0.6) or 0.4)
	end
	locks[action] = nil
	return { Success = false, Message = fallback }
end

local function launch(title: string, action: string, payload: any): any
	return VoltraMatchTeleport.Run(title, function() return request(action, payload) end)
end

function Service:GetState(): any return request("GetCampaignState") end
function Service:GetEligibleProjects(): any return request("GetCampaignEligibleProjects") end
function Service:StartPlacement(): any return launch("Ascension Placement", "StartCampaignPlacement", { Mode = "Manual" }) end
function Service:StartSeason(): any return request("StartCampaignSeason") end
function Service:ChooseScoutingFocus(focus: string): any return request("ChooseCampaignScoutingFocus", { Focus = focus }) end
function Service:SelectProject(cardInstanceId: string): any return request("SelectCampaignProject", { CardInstanceId = cardInstanceId }) end
function Service:SkipProject(): any return request("SkipCampaignProject") end
function Service:RetireProject(): any return request("RetireCampaignProject") end
function Service:StartFixture(mode: string): any return launch(mode == "Manage" and "Manage Ascension Match" or "Ascension Match", "StartCampaignFixture", { Mode = mode }) end
function Service:ResumeMatch(): any return launch("Resume Ascension Match", "ResumeCampaignMatch", {}) end
function Service:ChooseProjectUpgrade(optionId: string): any return request("ChooseCampaignProjectUpgrade", { OptionId = optionId }) end
function Service:GeneratePromotionChoice(): any return request("GenerateCampaignPromotionChoice") end
function Service:RerollPromotionChoice(): any return request("RerollCampaignPromotionChoice") end
function Service:ChoosePromotionPlayer(playerId: string): any return request("ChooseCampaignPromotionPlayer", { PlayerId = playerId }) end
function Service:UpgradeFacility(facilityId: string): any return request("UpgradeCampaignFacility", { FacilityId = facilityId, RequestId = HttpService:GenerateGUID(false) }) end
function Service:ApplyCounterPlan(): any return request("ApplyCampaignCounterPlan") end
function Service:AcknowledgePresentation(presentationId: string): any return request("AcknowledgeCampaignPresentation", { PresentationId = presentationId }) end
function Service:GetHistory(): any return request("GetCampaignHistory") end
function Service:GetMastery(): any return request("GetCampaignMastery") end
function Service:StartMastery(contractId: string): any return request("StartCampaignMastery", { ContractId = contractId }) end
function Service:StartMasteryFixture(mode: string): any return launch("Ascension Mastery", "StartCampaignMasteryFixture", { Mode = mode }) end

return Service
