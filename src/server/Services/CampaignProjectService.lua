--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.VTR.Shared.CampaignAscensionConfig)
local Resolver = require(ReplicatedStorage.VTR.Shared.CardProgressionResolver)
local PlayerDatabase = require(script.Parent.Parent.Data.PlayerDatabase)

local Service = {}

local function copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in value do result[key] = copy(child) end
	return result
end

local function findCard(profile: any, cardId: string): any?
	for _, card in profile.PlayerCardInventory or {} do
		if card.Id == cardId or card.cardInstanceId == cardId then return card end
	end
	return nil
end

local function positionRole(position: string): string
	if position == "GK" then return "GK" end
	if table.find({ "CB", "LB", "RB", "LWB", "RWB", "CDM" }, position) then return "Defender" end
	if table.find({ "CM", "CAM", "LM", "RM" }, position) then return "Creator" end
	return "Attacker"
end

local function protectedClass(value: any): boolean
	local normalized = string.lower(tostring(value or ""))
	for name in Config.Project.ProtectedCardTypes do
		if string.lower(tostring(name)) == normalized then return true end
	end
	return false
end

local function normalizeLifetime(value: any, progression: any): any
	local lifetime = type(value) == "table" and value or {}
	lifetime.XP = math.max(0, math.floor(tonumber(lifetime.XP) or 0))
	lifetime.OverallBoost = math.max(tonumber(lifetime.OverallBoost) or 0, tonumber(progression.OverallBoost) or 0)
	lifetime.AppliedNodes = type(lifetime.AppliedNodes) == "table" and lifetime.AppliedNodes or {}
	lifetime.PromotedSeasons = math.max(0, math.floor(tonumber(lifetime.PromotedSeasons) or 0))
	return lifetime
end

local function progressionMeta(profile: any, cardId: string): any
	profile.PlayerCardMeta = type(profile.PlayerCardMeta) == "table" and profile.PlayerCardMeta or {}
	profile.PlayerCardMeta[cardId] = profile.PlayerCardMeta[cardId] or {}
	local meta = profile.PlayerCardMeta[cardId]
	meta.CampaignProgression = meta.CampaignProgression or {
		Version = 1, OverallBoost = 0, MainStatBoosts = {}, DetailedStatBoosts = {}, AddedPositions = {}, WeakFootBoost = 0,
		SkillMovesBoost = 0, PlayStyles = {}, VisualTier = nil, SeasonsCompleted = 0, CampaignBound = false,
	}
	local progression = meta.CampaignProgression
	progression.MainStatBoosts = type(progression.MainStatBoosts) == "table" and progression.MainStatBoosts or {}
	progression.DetailedStatBoosts = type(progression.DetailedStatBoosts) == "table" and progression.DetailedStatBoosts or {}
	progression.AddedPositions = type(progression.AddedPositions) == "table" and progression.AddedPositions or {}
	progression.PlayStyles = type(progression.PlayStyles) == "table" and progression.PlayStyles or {}
	return meta, progression
end

function Service.IsEligible(profile: any, card: any): (boolean, string)
	if type(card) ~= "table" then return false, "Player card is unavailable." end
	local cardId = tostring(card.cardInstanceId or card.Id or "")
	local definition = PlayerDatabase.Get(card.playerId or card.PlayerId or "")
	if cardId == "" or not definition then return false, "Player definition is unavailable." end
	local meta = profile.PlayerCardMeta[cardId] or {}
	if meta.Loan == true or meta.Temporary == true or card.Temporary == true then return false, "Loan and temporary cards cannot become Club Projects." end
	if profile.CampaignProgress.ActiveProject and profile.CampaignProgress.ActiveProject.CardInstanceId == cardId then return false, "This player is already your active Club Project." end
	local baseOverall = tonumber(card.BaseOverall or card.overall or card.Rating or definition.overall) or 99
	if baseOverall > Config.Project.MaximumBaseOverall then return false, "Club Projects must begin at 82 OVR or lower." end
	local cardType = tostring(card.cardType or card.CardType or definition.cardType or "")
	local rarity = tostring(card.rarity or card.Rarity or definition.rarity or "")
	if protectedClass(cardType) or protectedClass(rarity) then return false, "Top-end special cards are not eligible for Club Projects." end
	local resolved = Resolver.Resolve(card, meta)
	if (tonumber(resolved.Rating) or 99) >= Config.Project.MaximumEffectiveOverall then return false, "This card has reached the Campaign OVR cap." end
	return true, "Eligible"
end

function Service.GetEligible(profile: any): any
	local result = {}
	for _, card in profile.PlayerCardInventory or {} do
		local eligible, reason = Service.IsEligible(profile, card)
		if eligible then
			local cardId = card.cardInstanceId or card.Id
			local resolved = Resolver.Resolve(card, profile.PlayerCardMeta[cardId])
			table.insert(result, {
				CardInstanceId = cardId,
				PlayerId = resolved.playerId or resolved.PlayerId,
				Name = resolved.displayName or resolved.Name,
				Overall = resolved.overall or resolved.Rating,
				Position = resolved.bestPosition or resolved.Position,
				Rarity = resolved.rarity or resolved.Rarity,
				CardType = resolved.cardType or resolved.CardType,
				portraitSeed = resolved.portraitSeed or resolved.PortraitSeed,
				appearance = copy(resolved.appearance or {}),
			})
		else
			local _ = reason
		end
	end
	table.sort(result, function(a, b) if a.Overall ~= b.Overall then return a.Overall > b.Overall end return a.Name < b.Name end)
	return result
end

function Service.GetPublicCard(profile: any, cardId: string): any?
	local card = findCard(profile, cardId)
	if not card then return nil end
	local resolved = Resolver.Resolve(card, profile.PlayerCardMeta[card.cardInstanceId or card.Id])
	return {
		Id = resolved.cardInstanceId or resolved.Id, cardInstanceId = resolved.cardInstanceId or resolved.Id,
		playerId = resolved.playerId or resolved.PlayerId, Name = resolved.Name or resolved.displayName,
		displayName = resolved.displayName or resolved.Name, Rating = resolved.Rating or resolved.overall,
		overall = resolved.overall or resolved.Rating, Position = resolved.Position or resolved.bestPosition,
		bestPosition = resolved.bestPosition or resolved.Position, Rarity = resolved.Rarity or resolved.rarity,
		rarity = resolved.rarity or resolved.Rarity, CardType = resolved.CardType or resolved.cardType,
		cardType = resolved.cardType or resolved.CardType, mainStats = copy(resolved.mainStats or resolved.MainStats or {}),
		appearance = copy(resolved.appearance or {}), portraitSeed = resolved.portraitSeed,
		CampaignVariant = resolved.CampaignVariant, CampaignVisualTier = resolved.CampaignVisualTier,
		CampaignBound = resolved.CampaignBound, Meta = copy(resolved.Meta or {}),
	}
end

function Service.Select(profile: any, cardId: string, seasonId: string): (boolean, string, any?)
	if type(cardId) ~= "string" or #cardId > 96 then return false, "Invalid Club Project player.", nil end
	local active = profile.CampaignProgress.ActiveProject
	if active then return false, "Retire or abandon the current Club Project first.", nil end
	local card = findCard(profile, cardId)
	local eligible, reason = Service.IsEligible(profile, card)
	if not eligible then return false, reason, nil end
	local id = card.cardInstanceId or card.Id
	local definition = PlayerDatabase.Get(card.playerId or card.PlayerId)
	local _, progression = progressionMeta(profile, id)
	local lifetime = normalizeLifetime(profile.CampaignProgress.ProjectLifetimeByCard[id], progression)
	profile.CampaignProgress.ProjectLifetimeByCard[id] = lifetime
	local project = {
		CardInstanceId = id, BasePlayerId = card.basePlayerId or card.BasePlayerId or card.playerId or card.PlayerId,
		PlayerName = definition.displayName, Position = definition.bestPosition, StartTime = os.time(), StartSeason = seasonId,
		XP = 0, LifetimeXP = tonumber(lifetime.XP) or 0, CurrentMilestone = 0, PendingUpgradeChoice = nil,
		AppliedNodeIds = copy(lifetime.AppliedNodes), SeasonsCompleted = tonumber(progression.SeasonsCompleted) or 0,
		PromotedSeasons = tonumber(lifetime.PromotedSeasons) or 0, OVRBoost = tonumber(progression.OverallBoost) or 0,
		VisualTier = progression.VisualTier, LastXPGrantKey = "", XPGrantLedger = {}, BoundStatus = progression.CampaignBound == true,
	}
	profile.CampaignProgress.ActiveProject = project
	return true, definition.displayName .. " is now your Club Project.", copy(project)
end

local function repeatChoiceOptions(profile: any, project: any, milestone: number, index: number): any
	local card = findCard(profile, project.CardInstanceId)
	local definition = card and PlayerDatabase.Get(card.playerId or card.PlayerId)
	if not definition then return {} end
	local packages = Config.Project.AttributePackages[positionRole(definition.bestPosition)] or {}
	local options = {}
	for _, package in packages do
		table.insert(options, {
			Id = "repeat" .. index .. ":" .. package.Id,
			Name = package.Name .. " + OVR",
			Kind = "AscensionRepeat",
			Package = copy(package),
			Overall = 1,
			VisualTier = "AscendedII",
			Milestone = milestone,
		})
	end
	return options
end

local function choiceOptions(profile: any, project: any, milestone: number): any
	local card = findCard(profile, project.CardInstanceId)
	if not card then return {} end
	local definition = PlayerDatabase.Get(card.playerId or card.PlayerId)
	if not definition then return {} end
	local role = positionRole(definition.bestPosition)
	local packages = Config.Project.AttributePackages[role]
	local options = {}
	if milestone == 3 then
		for _, package in packages do table.insert(options, { Id = "m3:" .. package.Id, Name = package.Name, Kind = "Attribute", Package = copy(package) }) end
	elseif milestone == 7 then
		local meta = profile.PlayerCardMeta[project.CardInstanceId] or {}
		local progression = meta.CampaignProgression or {}
		local owned = progression.PlayStyles or {}
		local pool = Config.Project.RolePlayStyles[role]
		for _, playStyle in pool do
			if not table.find(owned, playStyle) then table.insert(options, { Id = "m7:" .. string.lower(playStyle):gsub("%s+", "_"), Name = playStyle, Kind = "PlayStyle", PlayStyle = playStyle }) end
			if #options >= 3 then break end
		end
	elseif milestone == 12 then
		table.insert(options, { Id = "m12:weak_foot", Name = "WEAK FOOT +1", Kind = "WeakFoot", Amount = 1 })
		table.insert(options, { Id = "m12:skill_moves", Name = "SKILL MOVES +1", Kind = "SkillMoves", Amount = 1 })
		table.insert(options, { Id = "m12:" .. packages[1].Id, Name = packages[1].Name, Kind = "Attribute", Package = copy(packages[1]) })
		if (tonumber(profile.CampaignProgress.Facilities.academy) or 0) >= 2 then
			local valid = Config.Project.ValidAddedPositions[definition.bestPosition] or {}
			for _, position in valid do
				if not table.find(definition.positions, position) then table.insert(options, { Id = "m12:position:" .. position, Name = "ADD " .. position, Kind = "Position", Position = position }) end
			end
		end
	elseif milestone == 18 or milestone == 26 then
		if milestone == 26 and (tonumber(profile.CampaignProgress.Facilities.academy) or 0) < 3 then return {} end
		for _, package in packages do
			table.insert(options, { Id = "m" .. milestone .. ":" .. package.Id, Name = package.Name, Kind = "Ascension", Package = copy(package), Overall = 1, VisualTier = milestone == 18 and "AscendedI" or "AscendedII" })
		end
	end
	return options
end

function Service.GeneratePendingUpgrade(profile: any): any?
	local project = profile.CampaignProgress.ActiveProject
	if not project or project.PendingUpgradeChoice then return project and project.PendingUpgradeChoice or nil end
	for _, milestone in Config.Project.Milestones do
		local nodeId = "milestone:" .. milestone
		if project.XP >= milestone and not table.find(project.AppliedNodeIds, nodeId) then
			local options = choiceOptions(profile, project, milestone)
			if #options == 0 then return nil end
			project.PendingUpgradeChoice = { ChoiceId = project.CardInstanceId .. ":" .. nodeId, Milestone = milestone, Options = options, GeneratedAt = os.time() }
			return project.PendingUpgradeChoice
		end
	end
	for index, milestone in Config.Project.RepeatOverallMilestones do
		local nodeId = "repeat_overall:" .. index
		if project.XP >= milestone and (tonumber(project.PromotedSeasons) or 0) >= index and not table.find(project.AppliedNodeIds, nodeId) then
			local options = repeatChoiceOptions(profile, project, milestone, index)
			if #options == 0 then return nil end
			project.PendingUpgradeChoice = {
				ChoiceId = project.CardInstanceId .. ":" .. nodeId,
				Milestone = milestone,
				NodeId = nodeId,
				Options = options,
				GeneratedAt = os.time(),
			}
			return project.PendingUpgradeChoice
		end
	end
	return nil
end

function Service.GrantXP(profile: any, amount: number, grantKey: string): (number, any?)
	local project = profile.CampaignProgress.ActiveProject
	if not project or type(grantKey) ~= "string" or grantKey == "" or #grantKey > 160 then return 0, nil end
	project.XPGrantLedger = type(project.XPGrantLedger) == "table" and project.XPGrantLedger or {}
	if project.XPGrantLedger[grantKey] == true then return 0, nil end
	amount = math.clamp(math.floor(tonumber(amount) or 0), 0, 8)
	if amount <= 0 then return 0, nil end
	project.LastXPGrantKey = grantKey
	project.XPGrantLedger[grantKey] = true
	project.XP = math.min(999, (tonumber(project.XP) or 0) + amount)
	project.LifetimeXP = math.min(9999, (tonumber(project.LifetimeXP) or 0) + amount)
	local lifetime = normalizeLifetime(profile.CampaignProgress.ProjectLifetimeByCard[project.CardInstanceId], {})
	lifetime.XP = math.min(9999, (tonumber(lifetime.XP) or 0) + amount)
	profile.CampaignProgress.ProjectLifetimeByCard[project.CardInstanceId] = lifetime
	return amount, Service.GeneratePendingUpgrade(profile)
end

local function applyPackage(progression: any, package: any)
	for key, amount in package.Main or {} do progression.MainStatBoosts[key] = math.clamp((tonumber(progression.MainStatBoosts[key]) or 0) + amount, 0, 30) end
	for key, amount in package.Detailed or {} do progression.DetailedStatBoosts[key] = math.clamp((tonumber(progression.DetailedStatBoosts[key]) or 0) + amount, 0, 30) end
end

function Service.ChooseUpgrade(profile: any, optionId: string): (boolean, string, any?)
	local project = profile.CampaignProgress.ActiveProject
	local pending = project and project.PendingUpgradeChoice
	if not project or type(pending) ~= "table" then return false, "No Club Project upgrade is waiting.", nil end
	if type(optionId) ~= "string" or #optionId > 96 then return false, "Invalid Project choice.", nil end
	local selected = nil
	for _, option in pending.Options or {} do if option.Id == optionId then selected = option break end end
	if not selected then return false, "Select one of the persisted Project options.", nil end
	local nodeId = tostring(pending.NodeId or "milestone:" .. tostring(pending.Milestone))
	if table.find(project.AppliedNodeIds, nodeId) then return false, "This Project node is already applied.", nil end
	local meta, progression = progressionMeta(profile, project.CardInstanceId)
	if selected.Kind == "Attribute" then applyPackage(progression, selected.Package)
	elseif selected.Kind == "PlayStyle" then if not table.find(progression.PlayStyles, selected.PlayStyle) then table.insert(progression.PlayStyles, selected.PlayStyle) end
	elseif selected.Kind == "WeakFoot" then progression.WeakFootBoost = math.clamp((tonumber(progression.WeakFootBoost) or 0) + 1, 0, 4)
	elseif selected.Kind == "SkillMoves" then progression.SkillMovesBoost = math.clamp((tonumber(progression.SkillMovesBoost) or 0) + 1, 0, 4)
	elseif selected.Kind == "Position" then
		local definition = PlayerDatabase.Get((findCard(profile, project.CardInstanceId) or {}).playerId or "")
		local valid = definition and Config.Project.ValidAddedPositions[definition.bestPosition] or {}
		if not table.find(valid, selected.Position) then return false, "That secondary position is not valid for this player.", nil end
		if not table.find(progression.AddedPositions, selected.Position) then table.insert(progression.AddedPositions, selected.Position) end
	elseif selected.Kind == "Ascension" or selected.Kind == "AscensionRepeat" then
		if (tonumber(progression.OverallBoost) or 0) >= Config.Project.MaximumOverallBoost then return false, "This card reached its Campaign OVR cap.", nil end
		local resolved = Resolver.Resolve(findCard(profile, project.CardInstanceId), meta)
		if (tonumber(resolved.Rating) or 90) >= Config.Project.MaximumEffectiveOverall then return false, "This card reached 90 OVR.", nil end
		progression.OverallBoost = (tonumber(progression.OverallBoost) or 0) + 1
		progression.VisualTier = selected.VisualTier
		applyPackage(progression, selected.Package)
	end
	progression.CampaignBound = true
	progression.Version = 1
	meta.CampaignBound = true
	meta.QuickSellBlocked = true
	meta.TransferBlocked = true
	meta.CampaignVariant = "Ascension"
	meta.CampaignVisualTier = progression.VisualTier
	project.BoundStatus = true
	project.OVRBoost = progression.OverallBoost
	project.VisualTier = progression.VisualTier
	project.CurrentMilestone = pending.Milestone
	table.insert(project.AppliedNodeIds, nodeId)
	project.PendingUpgradeChoice = nil
	local lifetime = profile.CampaignProgress.ProjectLifetimeByCard[project.CardInstanceId]
	lifetime = normalizeLifetime(lifetime, progression)
	profile.CampaignProgress.ProjectLifetimeByCard[project.CardInstanceId] = lifetime
	lifetime.OverallBoost = progression.OverallBoost
	if not table.find(lifetime.AppliedNodes, nodeId) then table.insert(lifetime.AppliedNodes, nodeId) end
	Service.GeneratePendingUpgrade(profile)
	return true, selected.Name .. " applied to your Club Project.", copy(project)
end

function Service.Retire(profile: any, seasonBoundary: boolean): (boolean, string, any?)
	local project = profile.CampaignProgress.ActiveProject
	if not project then return false, "No active Club Project.", nil end
	if not seasonBoundary then return false, "A Club Project can only retire between seasons.", nil end
	if project.PendingUpgradeChoice then return false, "Resolve the pending Club Project upgrade before retiring.", nil end
	local hasPermanentUpgrade = #project.AppliedNodeIds > 0
	local meta, progression = progressionMeta(profile, project.CardInstanceId)
	if hasPermanentUpgrade then
		progression.CampaignBound = true
		meta.CampaignBound = true
		meta.QuickSellBlocked = true
		meta.TransferBlocked = true
		project.RetiredAt = os.time()
		table.insert(profile.CampaignProgress.ProjectHistory, 1, copy(project))
		while #profile.CampaignProgress.ProjectHistory > 30 do table.remove(profile.CampaignProgress.ProjectHistory) end
	end
	profile.CampaignProgress.ActiveProject = nil
	return true, hasPermanentUpgrade and "Club Project retired. Permanent upgrades remain." or "Club Project abandoned.", nil
end

return Service
