--!strict
local VTRPendingPackAnimation = require(script.Parent:WaitForChild("PendingPackAnimationService"))
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local HttpService=game:GetService("HttpService")
local Catalog=require(ReplicatedStorage.VTR.Shared.Catalog)
local ClubIdentityConfig=require(ReplicatedStorage.VTR.Shared.ClubIdentityConfig)
local Schema=require(ReplicatedStorage.VTR.Shared.UIStateSchema)
local PlayerDatabase=require(script.Parent.Parent.Data.PlayerDatabase)
local RunService=game:GetService("RunService")
local EconomyConfig=require(ReplicatedStorage.VTR.Shared.EconomyConfig)
local DeveloperConfig=require(ReplicatedStorage.VTR.Shared.DeveloperConfig)
local DeveloperAccessService=require(script.Parent.DeveloperAccessService)
local ProClubsConfig=require(ReplicatedStorage.VTR.Shared.ProClubsConfig)
local AITacticConfig=require(ReplicatedStorage.VTR.Shared.AITacticConfig)
local AIBehaviorTuningConfig=require(ReplicatedStorage.VTR.Shared.AIBehaviorTuningConfig)
local AIPlaystyleConfig=require(ReplicatedStorage.VTR.Shared.AIPlaystyleConfig)
local AIPlaystyleResolver=require(ReplicatedStorage.VTR.Shared.AIPlaystyleResolver)
local ClubNameFilterService=require(script.Parent.ClubNameFilterService)
local LaunchService={};LaunchService.__index=LaunchService
local function find(list:any,id:string):any? for _,item in list do if item.Id==id then return item end end;return nil end
local function has(list:any,value:string):boolean return table.find(list,value)~=nil end
local function recordItem(profile:any,id:string,kind:string,quantity:number) profile.Inventory=profile.Inventory or {Items={}};for _,item in profile.Inventory.Items do if item.Id==id and item.Kind==kind then item.Quantity+=quantity;return end end;table.insert(profile.Inventory.Items,{Id=id,Kind=kind,Quantity=quantity,AcquiredAt=os.time()}) end
local function setObjectiveProgress(profile:any,id:string,value:number)
	for _,objective in profile.Objectives do if objective.objectiveId==id and objective.status~="claimed" then objective.progress=math.min(objective.target,value);if objective.status=="active" and objective.progress>=objective.target then objective.status="claimable" end;return end end
end
local function cleanClubName(player:Player,value:any):(boolean,string) return ClubNameFilterService.Validate(player,value,20) end
local function cleanClubTag(player:Player,value:any):(boolean,string) return ClubNameFilterService.ValidateTag(player,value) end
local function identityDesign(payload:any):(boolean,any)
	local primary=ClubIdentityConfig.ColorId(payload.PrimaryColor);local secondary=ClubIdentityConfig.ColorId(payload.SecondaryColor);local accent=ClubIdentityConfig.ColorId(payload.AccentColor)
	if not primary or not secondary or not accent or primary==secondary or primary==accent or secondary==accent then return false,"Choose three different approved club colors."end
	local style=ClubIdentityConfig.ResolveStyle(payload.KitStyle)
	if not ClubIdentityConfig.IsChoice(ClubIdentityConfig.KitStyles,style)then return false,"Invalid kit style."end
	if not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgePresets,payload.BadgePreset)or not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgeShapes,payload.BadgeShape)or not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgeSymbols,payload.BadgeSymbol)or not ClubIdentityConfig.IsChoice(ClubIdentityConfig.BadgeColorBehaviors,payload.BadgeColorBehavior)then return false,"Invalid badge design."end
	return true,{PrimaryColor=primary,SecondaryColor=secondary,AccentColor=accent,KitStyle=style,BadgePreset=payload.BadgePreset,BadgeShape=payload.BadgeShape,BadgeSymbol=payload.BadgeSymbol,BadgeColorBehavior=payload.BadgeColorBehavior}
end
local function applyIdentity(target:any,design:any)for key,value in design do target[key]=value end end
local function autoFill(profile:any)
	local slots={{"GK","GK"},{"LB","LB"},{"CB1","CB"},{"CB2","CB"},{"RB","RB"},{"CDM","CM"},{"CM1","CM"},{"CM2","CM"},{"LW","LW"},{"ST","ST"},{"RW","RW"}};local used={}
	for _,slot in slots do local best=nil;for _,card in profile.PlayerCardInventory do if not used[card.Id] and card.Position==slot[2] and (not best or card.Rating>best.Rating) then best=card end end;if not best then for _,card in profile.PlayerCardInventory do if not used[card.Id] and (not best or card.Rating>best.Rating) then best=card end end end;if best then used[best.Id]=true;profile.UIState.SelectedSquad[slot[1]]=best.Name;profile.Squad[slot[1]]=best.Name end end
	profile.Bench={};profile.Reserves={};local remaining={};for _,card in profile.PlayerCardInventory do if not used[card.Id] then table.insert(remaining,card) end end;table.sort(remaining,function(a,b) return a.Rating>b.Rating end);for index,card in remaining do if index<=7 then profile.Bench[index]=card.Id else table.insert(profile.Reserves,card.Id) end end
end
local function copy(value:any):any
	if type(value)~="table"then return value end
	local result={}
	for key,child in pairs(value)do result[key]=copy(child)end
	return result
end
local function sanitizeTactics(payload:any):any
	local normalized=AITacticConfig.Normalize(payload)
	if type(payload)~="table"then return normalized end
	for _,key in {"Formation","PlaystyleId","PlaystyleVersion","PlaystyleName","PlaystyleStatus","PassRules","PositioningRules","PressRules","RoleInstructions","SequenceRules","MetricsTargets"}do
		if payload[key]~=nil then normalized[key]=copy(payload[key])end
	end
	if type(payload.Sliders)=="table"then
		normalized.Sliders=normalized.Sliders or{}
		for _,key in {"LobPassBias","FreeKickLongPass","LongGKDistribution"}do
			local value=tonumber(payload.Sliders[key])
			if value and value==value and value~=math.huge and value~=-math.huge then
				normalized.Sliders[key]=math.clamp(value,0,100)
			end
		end
	end
	return normalized
end
local function developerLabAllowed(player:Player):boolean
	if DeveloperAccessService.IsLabDeveloper then return DeveloperAccessService.IsLabDeveloper(player) end
	return DeveloperAccessService.IsOwner(player)
end
local function ensureAIProfileStorage(profile:any):any
	profile.CustomTactics=type(profile.CustomTactics)=="table"and profile.CustomTactics or{}
	profile.CustomTactics.Version=AIBehaviorTuningConfig.Version
	profile.CustomTactics.AIProfiles=type(profile.CustomTactics.AIProfiles)=="table"and profile.CustomTactics.AIProfiles or{}
	profile.CustomTactics.AITuningTargets=type(profile.CustomTactics.AITuningTargets)=="table"and profile.CustomTactics.AITuningTargets or{}
	profile.CustomTactics.AIPlaystyles=type(profile.CustomTactics.AIPlaystyles)=="table"and profile.CustomTactics.AIPlaystyles or{}
	local playstyles=profile.CustomTactics.AIPlaystyles
	playstyles.SchemaVersion=AIPlaystyleConfig.SchemaVersion
	playstyles.Drafts=type(playstyles.Drafts)=="table"and playstyles.Drafts or{}
	playstyles.Published=type(playstyles.Published)=="table"and playstyles.Published or{}
	playstyles.Assignments=type(playstyles.Assignments)=="table"and playstyles.Assignments or{Home={PlaystyleId=AIPlaystyleConfig.BasicPlaystyleId,Version=1},Away={PlaystyleId=AIPlaystyleConfig.BasicPlaystyleId,Version=1}}
	playstyles.Revision=tonumber(playstyles.Revision)or 0
	return profile.CustomTactics
end
local function profileCount(profiles:any):number
	local count=0
	for _ in pairs(profiles or{})do count+=1 end
	return count
end
local function profileId():string
	return "ai_"..HttpService:GenerateGUID(false):gsub("%-",""):sub(1,18)
end
local function normalizeAIProfile(payload:any, base:any):any
	local tactic=sanitizeTactics(payload)
	local behavior=AIBehaviorTuningConfig.NormalizeProfile(tactic, AITacticConfig.Get(tactic.PresetId).Sliders)
	tactic.GlobalOverrides=behavior.GlobalOverrides
	tactic.PhaseOverrides=behavior.PhaseOverrides
	tactic.RoleOverrides=behavior.RoleOverrides
	tactic.MatchStateOverrides=behavior.MatchStateOverrides
	tactic.ExecutionOverrides=behavior.ExecutionOverrides
	return tactic
end
local function playstyleStorage(profile:any):any
	return ensureAIProfileStorage(profile).AIPlaystyles
end
local function publicPlaystyleState(profile:any, allowed:boolean):any
	local storage=playstyleStorage(profile)
	return{
		DeveloperAllowed=allowed,
		Metadata=AIPlaystyleConfig.ClientMetadata(),
		BuiltIns=AIPlaystyleConfig.BuiltIns,
		BuiltInOrder=AIPlaystyleConfig.BuiltInOrder,
		Drafts=allowed and storage.Drafts or{},
		Published=allowed and storage.Published or{},
		Assignments=allowed and storage.Assignments or{},
		LastDraftId=allowed and storage.LastDraftId or nil,
		Revision=storage.Revision,
	}
end
local function draftFromPayload(player:Player,payload:any,existing:any?):any
	local source=type(payload.Playstyle)=="table"and payload.Playstyle or payload
	return AIPlaystyleConfig.Normalize(source, player.UserId, existing)
end
local function assignedRef(playstyle:any):any
	return{PlaystyleId=playstyle.PlaystyleId,Version=playstyle.Version,Name=playstyle.Name}
end

function LaunchService.new(profiles:any,progression:any,publish:(Player,string,any)->(),inventory:any,packs:any) return setmetatable({Profiles=profiles,Progression=progression,Publish=publish,Inventory=inventory,Packs=packs,RankedProfiles=nil,MatchRuntime=nil},LaunchService) end
function LaunchService:SetRankedProfiles(rankedProfiles:any) self.RankedProfiles=rankedProfiles end
function LaunchService:SetSquads(squads:any) self.Squads=squads end
function LaunchService:SetMatchRuntime(matchRuntime:any) self.MatchRuntime=matchRuntime end
function LaunchService:_push(player:Player,p:any) if self.Profiles.Save then self.Profiles:Save(player) end;self.Publish(player,"Progression",self.Progression:GetClientData(player));if self.Inventory and self.Inventory.GetClientData then self.Publish(player,"Inventory",self.Inventory:GetClientData(player))end;if self.Packs and self.Packs.GetClientData then self.Publish(player,"PackInventory",self.Packs:GetClientData(player))end;self.Publish(player,"UIState",p.UIState);self.Publish(player,"Currency",{Coins=p.Currency.Coins,Bolts=p.Currency.Bolts,VoltraPoints=p.Currency.VoltraPoints or 0});self.Publish(player,"PlayerProfile",self.Profiles:GetClientData(player)) end
function LaunchService:Handle(player:Player,action:string,payload:any):(boolean,string,any?)
	if action=="DeveloperResetProfile"then if not RunService:IsStudio()then return false,"Developer reset is only available in Studio.",nil end;local reset=self.Profiles:ResetProfile(player);if not reset then return false,"Profile reset failed.",nil end;self:_push(player,reset);return true,"Profile reset to fresh launch state. Restart Play to run onboarding.",{Reset=true}
	elseif action=="DeveloperGrantCoins"then if not DeveloperAccessService.IsAuthorized(player)then return false,"Developer authorization required.",nil end;local profile=self.Profiles:GetProfile(player);if not profile then return false,"Profile unavailable.",nil end;profile.Currency.Coins=math.min(EconomyConfig.MaximumCoins,profile.Currency.Coins+DeveloperConfig.CoinGrantAmount);self:_push(player,profile);return true,"Developer vault added 10,000,000 coins.",{Coins=profile.Currency.Coins}end
	local p=self.Profiles:GetProfile(player);if not p then return false,"Profile unavailable.",nil end;payload=type(payload)=="table" and payload or {};local o=p.Onboarding;local responseData:any=nil;local responseMessage="Profile updated."
	if action=="GetAIBehaviorLabState"then
		local allowed=developerLabAllowed(player)
		local custom=ensureAIProfileStorage(p)
		responseMessage="AI behavior lab loaded."
		responseData={DeveloperAllowed=allowed,Metadata=AIBehaviorTuningConfig.ClientMetadata(allowed),TeamTactics=sanitizeTactics(p.TeamTactics),Profiles=allowed and custom.AIProfiles or{},LastAIProfileId=allowed and custom.LastAIProfileId or nil,Targets=allowed and custom.AITuningTargets or{},Playstyles=publicPlaystyleState(p,allowed)}
		return true,responseMessage,responseData
	elseif action=="GetAILabState"then
		local allowed=developerLabAllowed(player)
		responseMessage="AI LAB loaded."
		responseData=publicPlaystyleState(p,allowed)
		return true,responseMessage,responseData
	elseif action=="StartAILabSession"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		if not self.MatchRuntime or not self.MatchRuntime.StartAILabMatch then return false,"AI LAB match runtime unavailable.",nil end
		local storage=playstyleStorage(p)
		local home=AIPlaystyleResolver.ResolveSide("Home",storage)
		local away=AIPlaystyleResolver.ResolveSide("Away",storage)
		local ok,message,data=self.MatchRuntime:StartAILabMatch(player,{HomeTactics=home,AwayTactics=away,Assignments=storage.Assignments,Revision=storage.Revision})
		return ok,message,data
	elseif action=="SaveAILabDraft"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		local source=type(payload.Playstyle)=="table"and payload.Playstyle or payload
		local id=type(payload.DraftId)=="string"and payload.DraftId or type(source.PlaystyleId)=="string"and source.PlaystyleId or AIPlaystyleConfig.DraftId()
		if not storage.Drafts[id] and AIPlaystyleConfig.Count(storage.Drafts)>=AIPlaystyleConfig.MaxDrafts then return false,"AI LAB draft limit reached.",nil end
		source.PlaystyleId=id
		source.Status="Draft"
		local draft=draftFromPayload(player,source,storage.Drafts[id])
		storage.Drafts[id]=draft
		storage.LastDraftId=id
		storage.Revision+=1
		responseMessage="AI LAB draft saved."
		responseData={Draft=draft,State=publicPlaystyleState(p,true)}
	elseif action=="DuplicateAILabDraft"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		if AIPlaystyleConfig.Count(storage.Drafts)>=AIPlaystyleConfig.MaxDrafts then return false,"AI LAB draft limit reached.",nil end
		local source=storage.Drafts[tostring(payload.DraftId or"")]
		if not source then return false,"Unknown AI LAB draft.",nil end
		local draft=AIPlaystyleConfig.Normalize(source,player.UserId)
		draft.PlaystyleId=AIPlaystyleConfig.DraftId()
		draft.Name=draft.Name.." Copy"
		draft.Status="Draft"
		draft.Version=1
		storage.Drafts[draft.PlaystyleId]=draft
		storage.LastDraftId=draft.PlaystyleId
		storage.Revision+=1
		responseMessage="AI LAB draft duplicated."
		responseData={Draft=draft,State=publicPlaystyleState(p,true)}
	elseif action=="DeleteAILabDraft"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		local id=tostring(payload.DraftId or payload.PlaystyleId or"")
		if not storage.Drafts[id]then return false,"Unknown AI LAB draft.",nil end
		storage.Drafts[id]=nil
		if storage.LastDraftId==id then storage.LastDraftId=nil end
		storage.Revision+=1
		responseMessage="AI LAB draft deleted."
		responseData=publicPlaystyleState(p,true)
	elseif action=="PublishAILabPlaystyle"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		local draftId=tostring(payload.DraftId or payload.PlaystyleId or"")
		local draft=storage.Drafts[draftId] or (type(payload.Playstyle)=="table"and payload.Playstyle or nil)
		if not draft then return false,"Choose a draft to publish.",nil end
		local published=AIPlaystyleConfig.Normalize(draft,player.UserId)
		published.Status="Published"
		published.PlaystyleId=AIPlaystyleConfig.SafeId(payload.PublishId or published.PlaystyleId or published.Name,"playstyle")
		storage.Published[published.PlaystyleId]=type(storage.Published[published.PlaystyleId])=="table"and storage.Published[published.PlaystyleId]or{}
		local version=AIPlaystyleConfig.NextVersion(storage.Published[published.PlaystyleId])
		published.Version=version
		published.PublishedAt=os.time()
		storage.Published[published.PlaystyleId][tostring(version)]=published
		storage.Revision+=1
		responseMessage="AI LAB playstyle published."
		responseData={Playstyle=published,State=publicPlaystyleState(p,true)}
	elseif action=="ArchiveAILabPlaystyle"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		local id=tostring(payload.PlaystyleId or"")
		local version=tostring(payload.Version or"")
		local item=storage.Published[id]and storage.Published[id][version]
		if not item then return false,"Unknown published playstyle.",nil end
		local archived=copy(item)
		archived.Status="Archived"
		storage.Published[id][version]=archived
		storage.Revision+=1
		responseMessage="AI LAB playstyle archived."
		responseData={Playstyle=archived,State=publicPlaystyleState(p,true)}
	elseif action=="ExportAILabPlaystyle"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		local id=tostring(payload.PlaystyleId or payload.DraftId or"")
		local version=tostring(payload.Version or"")
		local item=storage.Drafts[id] or storage.Published[id]and(version~=""and storage.Published[id][version]or nil)
		if not item and storage.Published[id]then item=AIPlaystyleResolver.ResolvePlaystyle({PlaystyleId=id},storage)end
		if not item then return false,"Unknown AI LAB playstyle.",nil end
		responseMessage="AI LAB playstyle exported."
		responseData={Json=AIPlaystyleConfig.Encode(item),Playstyle=item}
		return true,responseMessage,responseData
	elseif action=="ImportAILabPlaystyle"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		if AIPlaystyleConfig.Count(storage.Drafts)>=AIPlaystyleConfig.MaxDrafts then return false,"AI LAB draft limit reached.",nil end
		local ok,decoded=AIPlaystyleConfig.Decode(payload.Json or payload.Text)
		if not ok then return false,tostring(decoded),nil end
		decoded.Status="Draft"
		decoded.PlaystyleId=AIPlaystyleConfig.DraftId()
		decoded.AuthorUserId=player.UserId
		storage.Drafts[decoded.PlaystyleId]=decoded
		storage.LastDraftId=decoded.PlaystyleId
		storage.Revision+=1
		responseMessage="AI LAB playstyle imported as draft."
		responseData={Draft=decoded,State=publicPlaystyleState(p,true)}
	elseif action=="AssignAILabPlaystyle"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		local storage=playstyleStorage(p)
		local side=tostring(payload.Side or"Home")=="Away"and"Away"or"Home"
		local resolved=AIPlaystyleResolver.ResolvePlaystyle(payload,storage)
		storage.Assignments[side]=assignedRef(resolved)
		storage.Revision+=1
		if self.MatchRuntime and self.MatchRuntime.ApplyAIBehaviorLive then
			self.MatchRuntime:ApplyAIBehaviorLive(player,side,AIPlaystyleResolver.ResolveTactics(resolved,storage))
		end
		responseMessage="AI LAB playstyle assigned to "..side.."."
		responseData={Assignment=storage.Assignments[side],State=publicPlaystyleState(p,true)}
	elseif action=="ApplyAILabDraft"then
		if not developerLabAllowed(player)then return false,"Developer AI LAB access required.",nil end
		if not self.MatchRuntime or not self.MatchRuntime.ApplyAIBehaviorLive then return false,"Live match service unavailable.",nil end
		local storage=playstyleStorage(p)
		local side=tostring(payload.Side or"Home")=="Away"and"Away"or"Home"
		local draft=storage.Drafts[tostring(payload.DraftId or"")] or (type(payload.Playstyle)=="table"and payload.Playstyle or nil)
		if not draft then return false,"Choose a draft to apply.",nil end
		local normalized=AIPlaystyleConfig.Normalize(draft,player.UserId)
		local ok,message,data=self.MatchRuntime:ApplyAIBehaviorLive(player,side,AIPlaystyleResolver.ResolveTactics(normalized,storage))
		if ok then storage.Assignments[side]=assignedRef(normalized);storage.Revision+=1 end
		return ok,message,{Runtime=data,State=publicPlaystyleState(p,true)}
	elseif action=="SaveAIBehaviorProfile"then
		if not developerLabAllowed(player)then return false,"Developer AI lab access required.",nil end
		local custom=ensureAIProfileStorage(p)
		local id=type(payload.ProfileId)=="string"and payload.ProfileId or profileId()
		if #id>48 then return false,"Invalid profile id.",nil end
		if not custom.AIProfiles[id] and profileCount(custom.AIProfiles)>=AIBehaviorTuningConfig.MaxProfiles then return false,"AI profile limit reached.",nil end
		local name=AIBehaviorTuningConfig.SanitizeProfileName(payload.Name)
		if not name then return false,"Use a valid profile name.",nil end
		local tactic=normalizeAIProfile(payload.Tactics or payload, p.TeamTactics)
		custom.AIProfiles[id]={Id=id,Name=name,Tactics=tactic,SavedAt=os.time()}
		custom.LastAIProfileId=id
		responseMessage="AI behavior profile saved."
		responseData={Profile=custom.AIProfiles[id],Profiles=custom.AIProfiles,LastAIProfileId=id}
	elseif action=="DeleteAIBehaviorProfile"then
		if not developerLabAllowed(player)then return false,"Developer AI lab access required.",nil end
		local custom=ensureAIProfileStorage(p)
		local id=tostring(payload.ProfileId or"")
		if custom.AIProfiles[id]==nil then return false,"Unknown AI profile.",nil end
		custom.AIProfiles[id]=nil
		if custom.LastAIProfileId==id then custom.LastAIProfileId=nil end
		responseMessage="AI behavior profile deleted."
		responseData={Profiles=custom.AIProfiles,LastAIProfileId=custom.LastAIProfileId}
	elseif action=="ImportAIBehaviorProfile"then
		if not developerLabAllowed(player)then return false,"Developer AI lab access required.",nil end
		local text=tostring(payload.Json or payload.Text or"")
		if #text<2 or #text>AIBehaviorTuningConfig.MaxImportBytes then return false,"Import size is invalid.",nil end
		local ok,decoded=pcall(function()return HttpService:JSONDecode(text)end)
		if not ok or type(decoded)~="table"then return false,"Invalid JSON.",nil end
		local custom=ensureAIProfileStorage(p)
		if profileCount(custom.AIProfiles)>=AIBehaviorTuningConfig.MaxProfiles then return false,"AI profile limit reached.",nil end
		local name=AIBehaviorTuningConfig.SanitizeProfileName(decoded.Name or payload.Name)or"Imported Profile"
		local id=profileId()
		local tactic=normalizeAIProfile(decoded.Tactics or decoded, p.TeamTactics)
		custom.AIProfiles[id]={Id=id,Name=name,Tactics=tactic,SavedAt=os.time(),Imported=true}
		custom.LastAIProfileId=id
		responseMessage="AI behavior profile imported."
		responseData={Profile=custom.AIProfiles[id],Profiles=custom.AIProfiles,LastAIProfileId=id}
	elseif action=="ApplyAIBehaviorLive"then
		if not developerLabAllowed(player)then return false,"Developer AI lab access required.",nil end
		if not self.MatchRuntime or not self.MatchRuntime.ApplyAIBehaviorLive then return false,"Live match service unavailable.",nil end
		local custom=ensureAIProfileStorage(p)
		local tacticPayload=payload.Tactics
		if type(payload.ProfileId)=="string"and custom.AIProfiles[payload.ProfileId]then tacticPayload=custom.AIProfiles[payload.ProfileId].Tactics end
		local tactic=normalizeAIProfile(tacticPayload or payload, p.TeamTactics)
		local ok,message,data=self.MatchRuntime:ApplyAIBehaviorLive(player, tostring(payload.Side or"Home"), tactic)
		return ok,message,data
	elseif action=="SaveTeamTactics"then if payload.PresetId~=nil and not AITacticConfig.IsKnown(payload.PresetId)then return false,"Unknown tactic preset.",nil end;p.TeamTactics=sanitizeTactics(payload);responseMessage="AI tactics saved.";responseData={TeamTactics=p.TeamTactics}
	elseif action=="SetClubName" then if o.Complete or o.StarterPackClaimed then return false,"Club identity is locked.",nil end;local valid,result=cleanClubName(player,payload.Name);if not valid then return false,result,nil end;o.ClubName=result;p.Profile.SelectedClub=result;p.ClubMembership.Name=result;o.Step=math.max(o.Step,2);responseData={Name=result}
	elseif action=="SetAbbreviation" then local tagOk,tag=cleanClubTag(player,payload.Value);if o.ClubName=="" or o.StarterPackClaimed or not tagOk then return false,tag,nil end;o.Abbreviation=tag;p.ClubMembership.Abbreviation=tag;o.Step=math.max(o.Step,3);responseData={Tag=tag}
	elseif action=="SetIdentityDesign"then if o.Abbreviation==""or o.StarterPackClaimed then return false,"Club design cannot be changed during this step.",nil end;local valid,design=identityDesign(payload);if not valid then return false,design,nil end;applyIdentity(o,design);applyIdentity(p.ClubMembership,design);o.IdentityConfigured=true;o.Step=math.max(o.Step,5)
	elseif action=="SaveClubIdentity"then local nameOk,name=cleanClubName(player,payload.Name);local tagOk,abbreviation=cleanClubTag(player,payload.Abbreviation);if not nameOk then return false,name,nil end;if not tagOk then return false,abbreviation,nil end;local designOk,design=identityDesign(payload);if not designOk then return false,design,nil end;p.ClubMembership.ClubId=p.ClubMembership.ClubId~=""and p.ClubMembership.ClubId or("identity_"..player.UserId);p.ClubMembership.Name=name;p.ClubMembership.Abbreviation=abbreviation;p.ClubMembership.Role=p.ClubMembership.Role=="FREE AGENT"and"FOUNDER"or p.ClubMembership.Role;p.ClubMembership.Members=math.max(1,p.ClubMembership.Members or 0);p.ClubMembership.Reputation=p.ClubMembership.Reputation=="UNRANKED"and"ROOKIE"or p.ClubMembership.Reputation;applyIdentity(p.ClubMembership,design);p.Profile.SelectedClub=name;responseMessage="Club identity saved."
	elseif action=="SetColors" then local primary=find(Catalog.ColorPresets,payload.Primary);local secondary=find(Catalog.ColorPresets,payload.Secondary);if not primary or not secondary or primary.Id==secondary.Id or o.Abbreviation=="" or o.StarterPackClaimed then return false,"Choose two different preset colors.",nil end;o.PrimaryColor=primary.Id;o.SecondaryColor=secondary.Id;p.ClubMembership.PrimaryColor=primary.Id;p.ClubMembership.SecondaryColor=secondary.Id;o.Step=math.max(o.Step,4)
	elseif action=="SetKitStyle" then local style=find(Catalog.StarterKitStyles,payload.Id);if not style or o.PrimaryColor=="" or o.StarterPackClaimed then return false,"Invalid starter kit style.",nil end;o.KitStyle=style.Id;p.ClubMembership.KitStyle=style.Id;o.Step=math.max(o.Step,5)
	elseif action=="ClaimStarterPack" then if o.ClubName=="" or o.Abbreviation==""or not o.IdentityConfigured or o.PrimaryColor=="" or o.SecondaryColor==""or o.AccentColor==""or o.BadgeShape==""or o.BadgeSymbol==""or o.KitStyle=="" or o.StarterPackClaimed then return false,"Starter pack unavailable.",nil end;if not self.Inventory:AddPack(player,"starter_launch",Catalog.Packs.starter_launch.Name,"Onboarding",1) then return false,"Starter pack grant failed.",nil end;o.StarterPackClaimed=true;o.Step=6
	elseif action=="OpenStarterPack" then
		if not o.StarterPackClaimed or o.StarterPackOpened then return false,"Starter pack cannot be opened.",nil end;if not self.Inventory:ConsumePack(player,"starter_launch") then return false,"Starter pack missing.",nil end
		local reveals={};local required={"GK","LB","CB","CB","RB","CM","CM","CM","LW","ST","RW"};local usedPlayers={}
		for _,position in required do local candidates={};for _,definition in PlayerDatabase.Pools.Starter do if definition.bestPosition==position and not usedPlayers[definition.playerId] then table.insert(candidates,definition) end end;local definition=candidates[math.random(1,#candidates)];usedPlayers[definition.playerId]=true;local added,instance=self.Inventory:AddCard(player,definition);if added and instance then table.insert(reveals,instance);recordItem(p,instance.cardInstanceId,"PlayerCard",1) end end
		while #reveals<18 do local pool=math.random(1,100)<=94 and PlayerDatabase.Pools.Starter or PlayerDatabase.Pools.Rare;local definition=pool[math.random(1,#pool)];if not usedPlayers[definition.playerId] then usedPlayers[definition.playerId]=true;local added,instance=self.Inventory:AddCard(player,definition);if added and instance then table.insert(reveals,instance);recordItem(p,instance.cardInstanceId,"PlayerCard",1) end end end
		local bestRating=0;for _,card in reveals do bestRating=math.max(bestRating,math.floor(tonumber(card.Rating or card.overall)or 0))end;if self.RankedProfiles and self.RankedProfiles.RecordPackRating then self.RankedProfiles:RecordPackRating(player,bestRating)end;autoFill(p);o.StarterPackOpened=true;o.SquadFilled=true;o.ObjectivesActivated=true;o.Step=8;for _,objective in p.Objectives do if objective.groupId=="starter_journey" then if objective.objectiveId=="build_first_xi" then objective.progress=11;objective.status="claimable" elseif objective.objectiveId=="open_first_pack" then objective.progress=1 end elseif objective.status=="locked" then objective.status=objective.progress>=objective.target and "claimable" or "active" end end;self:_push(player,p);return true,"Starter pack opened and best XI selected.",reveals
	elseif action=="AutoFillSquad" then if not o.StarterPackOpened then return false,"Open the starter pack first.",nil end;autoFill(p);o.SquadFilled=true
	elseif action=="CompleteOnboarding" then if not o.SquadFilled or not o.ObjectivesActivated or o.ClubName=="" or o.Abbreviation=="" or o.PrimaryColor=="" or o.SecondaryColor==""or o.AccentColor==""or o.KitStyle=="" then return false,"Onboarding requirements are incomplete.",nil end;o.Complete=true;o.Step=10;p.OnboardingCompleted=true;p.ClubMembership.ClubId=p.ClubMembership.ClubId~=""and p.ClubMembership.ClubId or("identity_"..player.UserId);p.ClubMembership.Role="FOUNDER";p.ClubMembership.Members=math.max(1,p.ClubMembership.Members or 0);p.ClubMembership.Reputation="ROOKIE"
	elseif action=="ClaimInbox" then local reward=find(p.RewardsInbox,payload.Id);if not reward or reward.Claimed then return false,"Reward unavailable.",nil end;reward.Claimed=true;if reward.Id=="launch_welcome" then p.Currency.Coins+=500;p.Currency.Bolts+=50 end;setObjectiveProgress(p,"claim_daily_reward",1)
	elseif action=="OpenPack" then local opened,result=self.Packs:Open(player,payload.PackInstanceId or payload.Id);if not opened then return false,result,nil end;local reveals=result::any;for _,instance in reveals do instance.location="club";instance.Location="club";instance.RosterLocation="Club";recordItem(p,instance.cardInstanceId,"PlayerCard",1) end;setObjectiveProgress(p,"open_first_pack",1);local squadSnapshot=nil;if self.Squads and self.Squads.GetSquad then squadSnapshot=self.Squads:GetSquad(player);if squadSnapshot then self.Publish(player,"Squad",squadSnapshot)end end;self:_push(player,p);return true,"Pack opened on server.",reveals
	elseif action=="BuyCoins" then local bundle=Catalog.CoinBundles[payload.Id or payload.BundleId];if not bundle then return false,"Unknown coin bundle.",nil end;p.Currency.Coins=math.min(EconomyConfig.MaximumCoins,p.Currency.Coins+(bundle.Coins or 0));recordItem(p,bundle.Id,"Currency",bundle.Coins or 0);self:_push(player,p);return true,(bundle.Coins or 0).." coins added.",{Coins=p.Currency.Coins,Bundle=bundle.Id,Robux=bundle.Robux,ProductId=bundle.ProductId}
	elseif action=="Purchase" then local itemType=payload.ItemType;local itemId=payload.Id;local item;if itemType=="Pack" then item=Catalog.Packs[itemId] elseif itemType=="Kit" then item=find(Catalog.Kits,itemId) elseif itemType=="Stadium" then item=find(Catalog.Stadiums,itemId) elseif itemType=="Cosmetic" then item=find(Catalog.Cosmetics,itemId) end;if not item then return false,"Unknown store item.",nil end;local quantity=itemType=="Pack" and math.clamp(math.floor(tonumber(payload.Quantity)or 1),1,25) or 1;local bucket=nil;if itemType~="Pack" then bucket=itemType=="Kit" and p.StoreOwnership.Kits or itemType=="Stadium" and p.StoreOwnership.Stadiums or p.StoreOwnership.Cosmetics;if has(bucket,itemId) then return false,"Item already owned.",nil end end;local coins=(item.PriceCoins or 0)*quantity;local bolts=(item.PriceBolts or 0)*quantity;local voltraPoints=(item.PriceVoltraPoints or 0)*quantity;p.Currency.VoltraPoints=tonumber(p.Currency.VoltraPoints)or 0;local infiniteCoins=DeveloperConfig.InfiniteCoinsEveryone==true;if (not infiniteCoins and p.Currency.Coins<coins) or p.Currency.Bolts<bolts or p.Currency.VoltraPoints<voltraPoints then return false,"Insufficient currency.",nil end;if infiniteCoins then p.Currency.Coins=EconomyConfig.MaximumCoins else p.Currency.Coins-=coins end;p.Currency.Bolts-=bolts;p.Currency.VoltraPoints-=voltraPoints;if itemType=="Pack" then local delivered,instances=self.Inventory:AddPack(player,itemId,item.Name,"Store",quantity);if not delivered or not instances or not instances[1] then if not infiniteCoins then p.Currency.Coins+=coins end;p.Currency.Bolts+=bolts;p.Currency.VoltraPoints+=voltraPoints;return false,"Pack delivery failed; currency was restored.",nil end;local pack=instances[1];responseData={Pack={packInstanceId=pack.packInstanceId,packId=pack.packId,name=pack.name,description=pack.description,quantity=quantity,status=pack.status,purchasedAt=pack.purchasedAt,openedAt=pack.openedAt},Packs=instances,Quantity=quantity};responseMessage=quantity>1 and(quantity.." packs added to inventory.")or"Pack added to inventory.";recordItem(p,itemId,"Pack",quantity) else table.insert(bucket,itemId);recordItem(p,itemId,itemType=="Stadium" and "StadiumTheme" or itemType,1) end
	if player and typeof(player) == "Instance" and player:IsA("Player") then
		VTRPendingPackAnimation.Queue(player, itemId)
	end
	elseif action=="EquipCard" then return false,"Use the authoritative Squad Builder to change the starting XI.",nil
	elseif action=="EquipCosmetic" then local owned=has(p.StoreOwnership.Kits,payload.Id) or has(p.StoreOwnership.Stadiums,payload.Id) or has(p.StoreOwnership.Cosmetics,payload.Id);if not owned or not Schema.CosmeticSlots[payload.Slot] then return false,"Cosmetic ownership validation failed.",nil end;p.UIState.EquippedCosmetics[payload.Slot]=payload.Id
	elseif action=="CreateCareer" then if payload.Type~="Player" and payload.Type~="Manager" then return false,"Invalid career type.",nil end;local slot=nil;for _,save in p.CareerSaveSlots do if save.Type=="Empty" then slot=save;break end end;if not slot then return false,"No empty career slots.",nil end;slot.Type=payload.Type;slot.Name=payload.Type=="Player" and "ALEX VOLT" or "MORGAN VALE";slot.Season="2026/27";slot.Overall=payload.Type=="Player" and 62 or nil;p.UIState.CareerSaveSelection=slot.Slot
	elseif action=="CreateClub" then if p.ProClubMembership.ClubId~="" then return false,"You already belong to a Pro Club.",nil end;local valid,name=cleanClubName(player,payload.Name);local tagOk,abbreviation=cleanClubTag(player,payload.Tag);if not valid then return false,name,nil end;if not tagOk then return false,abbreviation,nil end;p.ProClubMembership={ClubId="proclub_"..player.UserId,Name=name,Tag=abbreviation,Role="OWNER",Members=1,Capacity=24,Reputation="ROOKIE",LeagueId="",JoinPolicy="InviteOnly",MatchHistory={}}
	elseif action=="CreateProPlayer"then local pro=p.ProClubsPlayer;if pro.Created then return false,"Your Pro already exists.",nil end;local first=type(payload.FirstName)=="string"and string.match(payload.FirstName,"^%s*([%a][%a '%-]+)%s*$")or nil;local last=type(payload.LastName)=="string"and string.match(payload.LastName,"^%s*([%a][%a '%-]+)%s*$")or nil;if not first or#first>18 or not last or#last>18 then return false,"Use valid first and last names (18 characters maximum).",nil end;pro.Created=true;pro.FirstName=first;pro.LastName=last;pro.JerseyName=string.upper(last);pro.Position=type(payload.Position)=="string"and payload.Position or"ST";pro.PreferredFoot=payload.PreferredFoot=="Left"and"Left"or"Right";pro.Attributes={};for _,attributes in ProClubsConfig.Categories do for _,attribute in attributes do pro.Attributes[attribute]=55 end end;responseMessage="Pro created with 20 attribute points.";responseData={Pro=pro}
	elseif action=="SpendProAttribute"then local pro=p.ProClubsPlayer;local attribute=payload.Attribute;local amount=math.floor(tonumber(payload.Amount)or 0);if not pro.Created or type(attribute)~="string"or amount<1 or amount>10 then return false,"Invalid attribute request.",nil end;local valid=false;for _,attributes in ProClubsConfig.Categories do if table.find(attributes,attribute)then valid=true;break end end;if not valid or pro.AttributePointsAvailable<amount then return false,"Not enough attribute points.",nil end;pro.Attributes=pro.Attributes or{};local current=tonumber(pro.Attributes[attribute])or 55;if current+amount>99 then return false,"Attribute cap reached.",nil end;pro.Attributes[attribute]=current+amount;pro.SpentAttributePoints[attribute]=(pro.SpentAttributePoints[attribute]or 0)+amount;pro.AttributePointsAvailable-=amount;local total=0;for _,spent in pro.SpentAttributePoints do total+=spent end;pro.Overall=math.min(99,60+math.floor(total/6));responseMessage=attribute.." upgraded to "..pro.Attributes[attribute]..".";responseData={Pro=pro}
	elseif action=="SelectProBuild"then local pro=p.ProClubsPlayer;local build=payload.Build;if not pro.Created or pro.Level<20 or type(build)~="string"or not table.find(ProClubsConfig.BuildPaths,build)then return false,"Build paths unlock at Level 20.",nil end;pro.BuildPath=build;responseMessage=build.." selected.";responseData={Pro=pro}
	else return false,"Unsupported launch action.",nil end
	self:_push(player,p);return true,responseMessage,responseData
end
return LaunchService
